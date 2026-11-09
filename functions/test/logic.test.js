'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  leerConfig,
  fechaLocalHoy,
  normalizarEstado,
  estaVigente,
  leerReserva,
  calcularAlertas,
  mensajeAlerta,
  planearRecordatorio,
  correoRecordatorio,
} = require('../src/logic');

// Hora de pared de Ciudad de México (UTC-6) como instante.
const mx = (d, h, mi = 0) => new Date(Date.UTC(2026, 9, d, h + 6, mi));

function reserva(extra = {}) {
  return leerReserva(extra.id || 'a1', {
    restauranteId: 'r1',
    restauranteNombre: 'Miel Test',
    usuarioId: 'u1',
    contacto: { nombre: 'Carlos', correo: 'carlos@test.com', telefono: '4181234567' },
    fechaLocal: '2026-10-30',
    inicio: mx(30, 14),
    duracionMin: 90,
    personas: 4,
    mesasNombres: ['M1'],
    estado: 'confirmada',
    ...extra.data,
  });
}

const config = leerConfig({ zonaHoraria: 'America/Mexico_City' });

test('la configuración usa los mismos valores por defecto que la app', () => {
  const c = leerConfig(undefined);
  assert.equal(c.alertasActivas, true);
  assert.equal(c.umbralAlertaMin, 30);
  assert.equal(c.recordatorioMin, 120);
  assert.equal(c.recordatorioTardioInmediato, false);
  assert.equal(c.procesamientoServidor, false);
  assert.equal(c.zonaHoraria, 'America/Mexico_City');
});

test('umbralAlertaMin en null usa el valor por defecto', () => {
  const c = leerConfig({
    zonaHoraria: 'America/Cancun',
    configuracion: { umbralAlertaMin: null, recordatorioMin: 60, procesamientoServidor: true },
  });
  assert.equal(c.umbralAlertaMin, 30);
  assert.equal(c.recordatorioMin, 60);
  assert.equal(c.procesamientoServidor, true);
  assert.equal(c.zonaHoraria, 'America/Cancun');
});

test('"hoy" es el del restaurante, no el del servidor', () => {
  // 02:00 UTC del 31 todavía son las 20:00 del 30 en México.
  assert.equal(fechaLocalHoy('America/Mexico_City', new Date(Date.UTC(2026, 9, 31, 2))), '2026-10-30');
  assert.equal(fechaLocalHoy('Europe/Madrid', new Date(Date.UTC(2026, 9, 31, 2))), '2026-10-31');
});

test('una zona inválida usa la de México', () => {
  assert.equal(fechaLocalHoy('No/Existe', new Date(Date.UTC(2026, 9, 31, 2))), '2026-10-30');
});

test('los estados se normalizan igual que en la app', () => {
  assert.equal(normalizarEstado('confirmada'), 'pendiente_llegada');
  assert.equal(normalizarEstado('Pendiente de llegada'), 'pendiente_llegada');
  assert.equal(normalizarEstado('cliente llegó'), 'cliente_llego');
  assert.equal(normalizarEstado('NO SHOW'), 'no_show');
  assert.equal(estaVigente('en_servicio'), true);
  assert.equal(estaVigente('cancelada'), false);
  assert.equal(estaVigente('finalizada'), false);
});

test('alerta "proxima" cuando falta el umbral o menos', () => {
  const [a] = calcularAlertas([reserva()], mx(30, 13, 35), config);
  assert.equal(a.tipo, 'proxima');
  assert.equal(a.minutos, 25);
  assert.equal(a.clave, 'a1_proxima_30');
});

test('justo en el umbral alerta y un minuto antes no', () => {
  assert.equal(calcularAlertas([reserva()], mx(30, 13, 30), config).length, 1);
  assert.equal(calcularAlertas([reserva()], mx(30, 13, 29), config).length, 0);
});

test('al pasar la hora cambia a "retraso"', () => {
  const [a] = calcularAlertas([reserva()], mx(30, 14, 12), config);
  assert.equal(a.tipo, 'retraso');
  assert.equal(a.minutos, 12);
  assert.equal(a.clave, 'a1_retraso_30');
});

test('solo alerta reservas pendientes de llegada', () => {
  for (const estado of ['cliente_llego', 'en_servicio', 'finalizada', 'cancelada', 'no_show']) {
    assert.equal(calcularAlertas([reserva({ data: { estado } })], mx(30, 13, 50), config).length, 0, estado);
  }
});

test('solo cuenta las reservas de hoy en la zona del restaurante', () => {
  const ahora = new Date(Date.UTC(2026, 9, 31, 2));
  const inicio = new Date(Date.UTC(2026, 9, 31, 2, 10));
  const deHoy = reserva({ data: { inicio, fechaLocal: '2026-10-30' } });
  const deManana = reserva({ id: 'b', data: { inicio, fechaLocal: '2026-10-31' } });
  assert.deepEqual(calcularAlertas([deHoy, deManana], ahora, config).map((a) => a.reserva.id), ['a1']);
});

test('con las alertas desactivadas no hay ninguna', () => {
  const c = leerConfig({ configuracion: { alertasActivas: false } });
  assert.equal(calcularAlertas([reserva()], mx(30, 13, 50), c).length, 0);
});

test('el mensaje trae cliente, hora, mesa, preorden y alergias', () => {
  const r = reserva({
    data: {
      mesasNombres: ['M1', 'M2'],
      preorden: { items: [{ nombre: 'Pasta' }], estado: 'pendiente' },
      alergias: ['Nueces'],
    },
  });
  const [a] = calcularAlertas([r], mx(30, 13, 50), config);
  const m = mensajeAlerta(a, 'America/Mexico_City');
  assert.match(m.titulo, /Carlos/);
  assert.match(m.cuerpo, /14:00/);
  assert.match(m.cuerpo, /M1 \+ M2/);
  assert.match(m.cuerpo, /Preorden por preparar/);
  assert.match(m.cuerpo, /Alergias/);
  assert.equal(m.datos.tienePreorden, true);
});

test('indica cuando la preorden ya está lista', () => {
  const r = reserva({ data: { preorden: { items: [{ nombre: 'Pasta' }], estado: 'listo' } } });
  const [a] = calcularAlertas([r], mx(30, 13, 50), config);
  assert.match(mensajeAlerta(a, 'America/Mexico_City').cuerpo, /Preorden lista/);
});

test('el recordatorio se programa con la anticipación configurada', () => {
  const p = planearRecordatorio(mx(30, 14), mx(29, 10), config);
  assert.equal(p.estado, 'programado');
  assert.equal(p.programadoPara.getTime(), mx(30, 12).getTime());
});

test('con menos anticipación que el recordatorio se omite', () => {
  const p = planearRecordatorio(mx(30, 14), mx(30, 13), config);
  assert.equal(p.estado, 'omitido');
  assert.equal(p.programadoPara, null);
});

test('con la regla configurable se envía de inmediato', () => {
  const c = leerConfig({ configuracion: { recordatorioTardioInmediato: true } });
  const p = planearRecordatorio(mx(30, 14), mx(30, 13), c);
  assert.equal(p.estado, 'programado');
  assert.equal(p.programadoPara.getTime(), mx(30, 13).getTime());
});

test('una reserva que ya comenzó no recibe recordatorio', () => {
  const c = leerConfig({ configuracion: { recordatorioTardioInmediato: true } });
  assert.equal(planearRecordatorio(mx(30, 14), mx(30, 14, 5), c).estado, 'omitido');
});

test('el correo del recordatorio trae los datos y el enlace de gestión', () => {
  const r = reserva({ data: { tokenGestion: 'ABCDEFGHJKMNPQRSTUVW' } });
  const c = correoRecordatorio(r, { zona: 'America/Mexico_City', enlaceBase: 'https://app.test/' });
  assert.match(c.asunto, /Miel Test/);
  assert.match(c.texto, /Carlos/);
  assert.match(c.texto, /14:00/);
  assert.match(c.texto, /https:\/\/app\.test\/\?reserva=ABCDEFGHJKMNPQRSTUVW/);
});

test('sin enlace base no menciona la gestión', () => {
  const c = correoRecordatorio(reserva({ data: { tokenGestion: 'X' } }), { zona: 'America/Mexico_City' });
  assert.doesNotMatch(c.texto, /reserva=/);
});
