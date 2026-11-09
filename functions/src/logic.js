'use strict';

/**
 * Lógica pura (sin Firebase) de las alertas de llegada y los recordatorios.
 * Es el equivalente en el servidor de lo que hacen ArrivalAlertCalculator y
 * ReminderPolicy en la app (lib/models/arrival_alert.dart, lib/services/reminder_service.dart).
 */

const ZONA_POR_DEFECTO = 'America/Mexico_City';
const UMBRAL_POR_DEFECTO = 30;
const RECORDATORIO_POR_DEFECTO = 120;
const MARGEN_ENTREGA_MS = 5 * 60 * 1000;
const MAX_INTENTOS = 3;

/** Ajustes operativos del restaurante, con los mismos valores por defecto que la app. */
function leerConfig(restaurante) {
  const data = restaurante || {};
  const c = data.configuracion && typeof data.configuracion === 'object' ? data.configuracion : {};
  const umbral = Number(c.umbralAlertaMin);
  const recordatorio = Number(c.recordatorioMin);
  const zona = typeof data.zonaHoraria === 'string' && data.zonaHoraria.trim() ? data.zonaHoraria.trim() : ZONA_POR_DEFECTO;
  return {
    alertasActivas: c.alertasActivas !== false,
    umbralAlertaMin: umbral > 0 ? umbral : UMBRAL_POR_DEFECTO,
    recordatorioMin: recordatorio > 0 ? recordatorio : RECORDATORIO_POR_DEFECTO,
    recordatorioTardioInmediato: c.recordatorioTardioInmediato === true,
    procesamientoServidor: c.procesamientoServidor === true,
    zonaHoraria: zona,
  };
}

/** 'YYYY-MM-DD' de hoy en la zona horaria del restaurante (HU30-RNF01). */
function fechaLocalHoy(zona, ahora) {
  try {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: zona,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(ahora);
  } catch (_) {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: ZONA_POR_DEFECTO,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(ahora);
  }
}

/** Mismo mapa de estados que ReservationModel.normalizeStatus. */
function normalizarEstado(estado) {
  const limpio = String(estado || '').trim().toLowerCase();
  switch (limpio) {
    case 'pendiente de llegada':
    case 'pendiente_de_llegada':
    case 'pendiente_llegada':
    case 'pendiente':
    case 'confirmada':
    case 'confirmado':
      return 'pendiente_llegada';
    case 'cliente llegó':
    case 'cliente llego':
    case 'cliente_llego':
      return 'cliente_llego';
    case 'en servicio':
    case 'en_servicio':
      return 'en_servicio';
    case 'finalizada':
    case 'finalizado':
      return 'finalizada';
    case 'no_show':
    case 'no show':
    case 'no-show':
    case 'noshow':
      return 'no_show';
    case 'cancelada':
    case 'cancelado':
      return 'cancelada';
    default:
      return limpio;
  }
}

/** La reserva sigue vigente (no cancelada, finalizada ni no-show). */
function estaVigente(estado) {
  const e = normalizarEstado(estado);
  return e === 'pendiente_llegada' || e === 'cliente_llego' || e === 'en_servicio';
}

function aFecha(valor) {
  if (!valor) return null;
  if (valor instanceof Date) return valor;
  if (typeof valor.toDate === 'function') return valor.toDate();
  const d = new Date(valor);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Convierte un documento de `reservations` en el objeto que usa esta lógica. */
function leerReserva(id, data) {
  const contacto = data.contacto && typeof data.contacto === 'object' ? data.contacto : {};
  const preorden = data.preorden && typeof data.preorden === 'object' ? data.preorden : {};
  const items = Array.isArray(preorden.items) ? preorden.items : [];
  return {
    id,
    restauranteId: data.restauranteId || '',
    restauranteNombre: data.restauranteNombre || '',
    usuarioId: data.usuarioId || '',
    nombre: contacto.nombre || data.contactoNombre || '',
    correo: contacto.correo || data.contactoCorreo || '',
    telefono: contacto.telefono || data.contactoTelefono || '',
    fechaLocal: data.fechaLocal || '',
    inicio: aFecha(data.inicio),
    duracionMin: Number(data.duracionMin) || 90,
    personas: Number(data.personas || data.cantidadPersonas) || 0,
    mesasNombres: Array.isArray(data.mesasNombres) ? data.mesasNombres : [],
    estado: data.estado || '',
    tienePreorden: items.length > 0 || data.tienePreorden === true,
    estadoPedido: String(data.estadoPreorden || preorden.estado || 'pendiente').toLowerCase(),
    tieneAlergias:
      (Array.isArray(data.alergias) && data.alergias.length > 0) ||
      (typeof data.notasAlergias === 'string' && data.notasAlergias.trim() !== ''),
    tokenGestion: data.tokenGestion || '',
    creadaEn: aFecha(data.creadaEn),
  };
}

/**
 * Alertas de llegada (HU30-RF01): reservas "pendiente de llegada" de hoy. Es "proxima"
 * cuando faltan umbral minutos o menos y "retraso" cuando la hora ya pasó.
 */
function calcularAlertas(reservas, ahora, config) {
  if (!config.alertasActivas) return [];
  const hoy = fechaLocalHoy(config.zonaHoraria, ahora);
  const alertas = [];
  for (const r of reservas) {
    if (normalizarEstado(r.estado) !== 'pendiente_llegada') continue;
    if (!r.inicio || r.fechaLocal !== hoy) continue;
    const segundos = Math.trunc((r.inicio.getTime() - ahora.getTime()) / 1000);
    if (segundos >= 0) {
      const minutos = Math.ceil(segundos / 60);
      if (minutos > config.umbralAlertaMin) continue;
      alertas.push({ reserva: r, tipo: 'proxima', minutos, umbralMin: config.umbralAlertaMin });
    } else {
      const minutos = Math.max(1, Math.ceil(-segundos / 60));
      alertas.push({ reserva: r, tipo: 'retraso', minutos, umbralMin: config.umbralAlertaMin });
    }
  }
  alertas.sort((a, b) => a.reserva.inicio - b.reserva.inicio);
  return alertas.map((a) => ({ ...a, clave: `${a.reserva.id}_${a.tipo}_${a.umbralMin}` }));
}

function hhmm(fecha, zona) {
  return new Intl.DateTimeFormat('es-MX', {
    timeZone: zona || ZONA_POR_DEFECTO,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(fecha);
}

/** Mensaje push: cliente, hora, mesa y si hay preorden o alergias (HU30-RF02). */
function mensajeAlerta(alerta, zona) {
  const r = alerta.reserva;
  const cliente = r.nombre.trim() || 'Cliente';
  const mesa = r.mesasNombres.length ? r.mesasNombres.join(' + ') : 'sin mesa';
  const pedidoListo = r.tienePreorden && r.estadoPedido === 'listo';
  const partes = [`${cliente} · ${hhmm(r.inicio, zona)} · ${mesa}`];
  if (r.tienePreorden) partes.push(pedidoListo ? 'Preorden lista' : 'Preorden por preparar');
  if (r.tieneAlergias) partes.push('Alergias o restricciones');
  return {
    titulo: alerta.tipo === 'retraso' ? `Cliente sin llegar: ${cliente}` : `Llega pronto: ${cliente}`,
    cuerpo: partes.join('\n'),
    datos: {
      tipo: alerta.tipo,
      cliente,
      hora: hhmm(r.inicio, zona),
      mesas: r.mesasNombres,
      tienePreorden: r.tienePreorden,
      pedidoListo,
      tieneAlergias: r.tieneAlergias,
      minutos: alerta.minutos,
    },
  };
}

/** Cuándo enviar el recordatorio (HU21-RF01). */
function planearRecordatorio(inicio, ahora, config) {
  if (inicio.getTime() <= ahora.getTime()) {
    return { estado: 'omitido', programadoPara: null, motivo: 'La reserva ya comenzó.' };
  }
  const programado = new Date(inicio.getTime() - config.recordatorioMin * 60000);
  if (programado.getTime() > ahora.getTime()) {
    return { estado: 'programado', programadoPara: programado, motivo: null };
  }
  if (config.recordatorioTardioInmediato) {
    return { estado: 'programado', programadoPara: ahora, motivo: null };
  }
  return {
    estado: 'omitido',
    programadoPara: null,
    motivo: 'La reserva se hizo con menos anticipación que el recordatorio.',
  };
}

/** Correo del recordatorio. */
function correoRecordatorio(r, { zona, enlaceBase } = {}) {
  const rest = r.restauranteNombre || 'Reservitta';
  const nombre = r.nombre.trim() || 'Comensal';
  const lineas = [
    `¡Hola, ${nombre}! Te recordamos que tienes una reserva programada hoy en ${rest}.`,
    '',
    'Detalles de tu visita:',
    `- Restaurante: ${rest}`,
    `- Fecha: ${r.fechaLocal}`,
    `- Horario: ${hhmm(r.inicio, zona)}`,
    `- Personas: ${r.personas}`,
    `- Mesa(s): ${r.mesasNombres.length ? r.mesasNombres.join(', ') : 'Asignación al llegar'}`,
    `- Código de reservación: ${r.id}`,
  ];
  if (r.tokenGestion && enlaceBase) {
    lineas.push(
      '',
      '¿Necesitas cambiar o cancelar tu reserva? Puedes hacerlo hasta 2 horas antes:',
      `  • Enlace: ${enlaceBase}?reserva=${r.tokenGestion}`,
    );
  }
  lineas.push('', '¡Te esperamos!');
  return { asunto: `Recordatorio: Tu reserva en ${rest} es hoy`, texto: lineas.join('\n') };
}

module.exports = {
  ZONA_POR_DEFECTO,
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
};
