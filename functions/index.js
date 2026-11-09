'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineString } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const {
  MARGEN_ENTREGA_MS,
  MAX_INTENTOS,
  leerConfig,
  fechaLocalHoy,
  normalizarEstado,
  estaVigente,
  leerReserva,
  calcularAlertas,
  mensajeAlerta,
  planearRecordatorio,
  correoRecordatorio,
} = require('./src/logic');

admin.initializeApp();
const db = admin.firestore();
const { Timestamp } = admin.firestore;

const REGION = 'us-central1';

// Clave de Resend para los correos (si está vacía se escribe en la colección `mail`,
// que atiende la extensión "Trigger Email") y dirección pública de la app para el enlace.
const resendApiKey = defineString('RESEND_API_KEY', { default: '' });
const resendSender = defineString('RESEND_SENDER', { default: 'Reservitta <onboarding@resend.dev>' });
const appUrl = defineString('APP_URL', { default: '' });

const ALREADY_EXISTS = 6;

// -----------------------------------------------------------------------------
// Procesamiento programado: alertas de llegada (HU30) y recordatorios (HU21)
// -----------------------------------------------------------------------------

/**
 * Cada minuto, para los restaurantes que activaron `configuracion.procesamientoServidor`:
 * registra las alertas de llegada nuevas (sin duplicarlas) y envía los recordatorios
 * que ya tocan. Si no está activado, lo sigue haciendo la app del administrador.
 */
exports.procesarOperaciones = onSchedule(
  { schedule: 'every 1 minutes', region: REGION, timeoutSeconds: 120, memory: '256MiB' },
  async () => {
    const ahora = new Date();
    const restaurantes = await db
      .collection('restaurants')
      .where('configuracion.procesamientoServidor', '==', true)
      .get();

    for (const doc of restaurantes.docs) {
      const config = leerConfig(doc.data());
      try {
        const hoy = fechaLocalHoy(config.zonaHoraria, ahora);
        const snap = await db
          .collection('reservations')
          .where('restauranteId', '==', doc.id)
          .where('fechaLocal', '==', hoy)
          .get();
        const reservas = snap.docs.map((d) => leerReserva(d.id, d.data()));

        await registrarAlertas(doc.id, reservas, ahora, config);
        await procesarRecordatorios(doc.id, reservas, ahora, config);
      } catch (e) {
        logger.error('Error procesando el restaurante', { restaurante: doc.id, error: String(e) });
      }
    }
  },
);

async function registrarAlertas(restauranteId, reservas, ahora, config) {
  const alertas = calcularAlertas(reservas, ahora, config);
  const vigentes = new Set(alertas.map((a) => a.clave));
  const rest = db.collection('restaurants').doc(restauranteId);

  for (const alerta of alertas) {
    const mensaje = mensajeAlerta(alerta, config.zonaHoraria);
    try {
      // `create` falla si el documento ya existe: así cada reserva, tipo y umbral se
      // avisa una sola vez (HU30-RNF02), aunque la app también esté registrando alertas.
      await rest.collection('alertasAdmin').doc(alerta.clave).create({
        reservaId: alerta.reserva.id,
        tipo: alerta.tipo,
        umbralMin: alerta.umbralMin,
        titulo: mensaje.titulo,
        cuerpo: mensaje.cuerpo,
        datos: mensaje.datos,
        activa: true,
        leida: false,
        pushEnviado: false,
        creadaEn: Timestamp.fromDate(ahora),
      });
    } catch (e) {
      if (e.code === ALREADY_EXISTS) continue;
      throw e;
    }
    // El documento de la cola dispara `enviarPushAdmin`.
    await rest.collection('colaPush').doc(alerta.clave).set({
      canal: 'fcm',
      destino: 'admin',
      titulo: mensaje.titulo,
      cuerpo: mensaje.cuerpo,
      datos: mensaje.datos,
      reservaId: alerta.reserva.id,
      estado: 'pendiente',
      creadoEn: Timestamp.fromDate(ahora),
    });
  }

  const activas = await rest.collection('alertasAdmin').where('activa', '==', true).get();
  for (const doc of activas.docs) {
    if (!vigentes.has(doc.id)) await doc.ref.update({ activa: false });
  }
}

async function procesarRecordatorios(restauranteId, reservas, ahora, config) {
  const rest = db.collection('restaurants').doc(restauranteId);

  for (const r of reservas) {
    if (!r.inicio) continue;
    const ref = rest.collection('recordatorios').doc(r.id);
    const snap = await ref.get();
    const doc = snap.exists ? snap.data() : null;
    const estadoDoc = doc ? doc.estado : null;
    const vigente = normalizarEstado(r.estado) === 'pendiente_llegada' && estaVigente(r.estado);

    if (!vigente) {
      if (estadoDoc === 'programado') {
        await ref.update({ estado: 'cancelado', actualizadoEn: Timestamp.fromDate(ahora) });
      }
      continue;
    }

    const inicioDoc = doc && doc.inicio ? doc.inicio.toDate() : null;
    const cambioHorario = inicioDoc && inicioDoc.getTime() !== r.inicio.getTime();
    const cambioAnticipacion = doc && estadoDoc === 'programado' && doc.minutosAntes !== config.recordatorioMin;

    if (!doc || cambioHorario || cambioAnticipacion) {
      // Sin recordatorio (reserva anterior) o reprogramación por cambio de hora.
      const creada = r.creadaEn || ahora;
      const referencia = !doc ? (creada > ahora ? ahora : creada) : ahora;
      const plan = planearRecordatorio(r.inicio, referencia, config);
      await ref.set({
        reservaId: r.id,
        restauranteId,
        usuarioId: r.usuarioId,
        estado: plan.estado,
        programadoPara: plan.programadoPara ? Timestamp.fromDate(plan.programadoPara) : null,
        inicio: Timestamp.fromDate(r.inicio),
        minutosAntes: config.recordatorioMin,
        ...(plan.motivo ? { motivo: plan.motivo } : {}),
        intentos: 0,
        actualizadoEn: Timestamp.fromDate(ahora),
      });
      if (plan.estado !== 'programado' || plan.programadoPara > ahora) continue;
      await enviarRecordatorio(ref, r, ahora, config);
      continue;
    }

    if (estadoDoc !== 'programado') continue;
    const programadoPara = doc.programadoPara ? doc.programadoPara.toDate() : null;
    if (!programadoPara || programadoPara > ahora) continue;
    await enviarRecordatorio(ref, r, ahora, config);
  }
}

async function enviarRecordatorio(ref, r, ahora, config) {
  // Se reclama el recordatorio dentro de una transacción para que nadie más lo envíe.
  const reclamado = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data();
    if (!d || d.estado !== 'programado') return null;
    const intentos = (d.intentos || 0) + 1;
    tx.update(ref, { estado: 'enviando', intentos });
    return { intentos, programadoPara: d.programadoPara ? d.programadoPara.toDate() : null };
  });
  if (!reclamado) return;

  let error = null;
  if (!r.correo || !r.correo.includes('@')) {
    await ref.update({
      estado: 'omitido',
      motivo: 'La reserva no tiene un correo válido (el servidor solo envía por correo).',
      actualizadoEn: Timestamp.fromDate(ahora),
    });
    return;
  }

  try {
    const correo = correoRecordatorio(r, { zona: config.zonaHoraria, enlaceBase: appUrl.value() });
    await enviarCorreo(r.correo.trim().toLowerCase(), correo.asunto, correo.texto);
  } catch (e) {
    error = String(e);
  }

  if (!error) {
    const retraso = reclamado.programadoPara ? ahora.getTime() - reclamado.programadoPara.getTime() : 0;
    await ref.update({
      estado: 'enviado',
      enviadoEn: Timestamp.fromDate(ahora),
      retrasoSeg: Math.round(retraso / 1000),
      dentroDeMargen: retraso <= MARGEN_ENTREGA_MS,
      actualizadoEn: Timestamp.fromDate(ahora),
    });
    return;
  }

  logger.warn('No se pudo enviar el recordatorio', { reserva: r.id, error });
  await ref.update({
    estado: reclamado.intentos >= MAX_INTENTOS ? 'fallido' : 'programado',
    ultimoError: error,
    actualizadoEn: Timestamp.fromDate(ahora),
  });
}

async function enviarCorreo(para, asunto, texto) {
  const clave = resendApiKey.value();
  if (clave) {
    const respuesta = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${clave}` },
      body: JSON.stringify({ from: resendSender.value(), to: [para], subject: asunto, text: texto }),
    });
    if (!respuesta.ok) {
      throw new Error(`Resend respondió ${respuesta.status}: ${await respuesta.text()}`);
    }
    return;
  }
  // Sin clave de Resend: la extensión "Trigger Email" entrega los documentos de `mail`.
  await db.collection('mail').add({ to: [para], message: { subject: asunto, text: texto } });
}

// -----------------------------------------------------------------------------
// Push (FCM) al administrador (HU30-RF02)
// -----------------------------------------------------------------------------

/** Códigos de error de FCM que indican que el token ya no sirve. */
const TOKEN_INVALIDO = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Cuando la app o `procesarOperaciones` dejan un mensaje en `colaPush`, lo envía por
 * FCM a los dispositivos registrados del administrador de ese restaurante.
 */
exports.enviarPushAdmin = onDocumentCreated(
  { document: 'restaurants/{restauranteId}/colaPush/{mensajeId}', region: REGION },
  async (evento) => {
    const snap = evento.data;
    if (!snap) return;
    const mensaje = snap.data();
    const { restauranteId } = evento.params;

    const dispositivos = await db
      .collection('restaurants')
      .doc(restauranteId)
      .collection('dispositivosAdmin')
      .get();
    const tokens = dispositivos.docs.map((d) => d.id);

    if (tokens.length === 0) {
      await snap.ref.update({ estado: 'sin_dispositivos', procesadoEn: Timestamp.now() });
      return;
    }

    const datos = {};
    for (const [clave, valor] of Object.entries(mensaje.datos || {})) {
      datos[clave] = typeof valor === 'string' ? valor : JSON.stringify(valor);
    }
    datos.reservaId = String(mensaje.reservaId || '');
    datos.restauranteId = restauranteId;

    const respuesta = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: mensaje.titulo, body: mensaje.cuerpo },
      data: datos,
    });

    const invalidos = [];
    respuesta.responses.forEach((r, i) => {
      if (!r.success && r.error && TOKEN_INVALIDO.has(r.error.code)) invalidos.push(tokens[i]);
    });
    await Promise.all(
      invalidos.map((t) =>
        db.collection('restaurants').doc(restauranteId).collection('dispositivosAdmin').doc(t).delete(),
      ),
    );

    await snap.ref.update({
      estado: respuesta.successCount > 0 ? 'enviado' : 'fallido',
      enviados: respuesta.successCount,
      fallidos: respuesta.failureCount,
      procesadoEn: Timestamp.now(),
    });

    // Marca la alerta como enviada por push (la app y esta función usan la misma clave).
    if (respuesta.successCount > 0) {
      const alerta = db
        .collection('restaurants')
        .doc(restauranteId)
        .collection('alertasAdmin')
        .doc(evento.params.mensajeId);
      if ((await alerta.get()).exists) await alerta.update({ pushEnviado: true });
    }
  },
);
