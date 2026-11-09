import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/arrival_alert.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/daily_metrics.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/operations_config.dart';
import 'package:reservitta/models/order_status_flow.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_time.dart';
import 'package:reservitta/models/table_live_status.dart';
import 'package:reservitta/services/admin_alert_service.dart';
import 'package:reservitta/services/confirmation_notification_service.dart';
import 'package:reservitta/services/notification_clients.dart';
import 'package:reservitta/services/operations_config_service.dart';
import 'package:reservitta/services/reminder_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/services/table_status_service.dart';

/// Instante que corresponde a la hora de pared de Ciudad de México (UTC-6),
/// sin depender de la zona del equipo que corre las pruebas.
DateTime mx(int d, int h, [int mi = 0, int month = 10]) =>
    DateTime.utc(2026, month, d, h + 6, mi);

ReservationModel reserva({
  String id = 'a1',
  DateTime? inicio,
  String fecha = '2026-10-30',
  String estado = ReservationModel.estadoConfirmada,
  List<String> mesas = const ['m1'],
  String nombre = 'Carlos',
  bool conPreorden = false,
  String estadoPreorden = 'pendiente',
  List<String> alergias = const [],
  int personas = 4,
  int duracion = 90,
  DateTime? creadaEn,
  String correo = 'carlos@test.com',
}) {
  final i = inicio ?? mx(30, 14);
  return ReservationModel.create(
    id: id,
    restauranteId: 'r1',
    usuarioId: 'u1',
    restauranteNombre: 'Miel Test',
    contactoNombre: nombre,
    contactoCorreo: correo,
    fechaLocal: fecha,
    inicio: i,
    duracionMin: duracion,
    personas: personas,
    mesaIds: mesas,
    mesasNombres: [for (final m in mesas) m.toUpperCase()],
    estado: estado,
    estadoPreorden: estadoPreorden,
    preordenItems: conPreorden
        ? [
            {'platilloId': 'p1', 'nombre': 'Pasta', 'cantidad': 1, 'precio': 100.0},
          ]
        : const [],
    alergias: alergias,
  ).copyWith(creadaEn: creadaEn);
}

class _FakeEmail implements TransactionalEmailClient {
  final enviados = <String>[];
  bool falla = false;

  @override
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (falla) throw Exception('SMTP caído');
    enviados.add('$to|$subject');
    return true;
  }
}

class _FakePush implements AdminPushGateway {
  final mensajes = <AdminPushMessage>[];
  bool falla = false;

  @override
  Future<void> enviar(AdminPushMessage mensaje) async {
    if (falla) throw Exception('FCM caído');
    mensajes.add(mensaje);
  }
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  group('Hora del restaurante (HU30-RNF01)', () {
    test('México usa UTC-6 y su "hoy" no depende del dispositivo', () {
      // 02:00 UTC del 31 es todavía las 20:00 del 30 en la Ciudad de México.
      final instante = DateTime.utc(2026, 10, 31, 2);
      expect(RestaurantTime.fechaLocalHoy('America/Mexico_City', instante), '2026-10-30');
      expect(RestaurantTime.ahoraEnRestaurante('America/Mexico_City', instante).hour, 20);
    });

    test('Nueva York respeta el horario de verano', () {
      expect(RestaurantTime.offsetMinutos('America/New_York', DateTime.utc(2026, 7, 1)), -240);
      expect(RestaurantTime.offsetMinutos('America/New_York', DateTime.utc(2026, 12, 1)), -300);
      // El cambio de 2026 fue el 8 de marzo y el 1 de noviembre.
      expect(RestaurantTime.offsetMinutos('America/New_York', DateTime.utc(2026, 3, 8, 6)), -300);
      expect(RestaurantTime.offsetMinutos('America/New_York', DateTime.utc(2026, 3, 8, 8)), -240);
      expect(RestaurantTime.offsetMinutos('America/New_York', DateTime.utc(2026, 11, 1, 5)), -240);
      expect(RestaurantTime.offsetMinutos('America/New_York', DateTime.utc(2026, 11, 1, 8)), -300);
    });

    test('Madrid respeta el horario de verano europeo', () {
      expect(RestaurantTime.offsetMinutos('Europe/Madrid', DateTime.utc(2026, 7, 1)), 120);
      expect(RestaurantTime.offsetMinutos('Europe/Madrid', DateTime.utc(2026, 1, 1)), 60);
    });

    test('una zona desconocida usa la hora del dispositivo', () {
      final instante = DateTime.utc(2026, 10, 30, 12);
      expect(RestaurantTime.esConocida('Mars/Olympus'), isFalse);
      expect(RestaurantTime.offsetMinutos('Mars/Olympus', instante), isNull);
      expect(RestaurantTime.ahoraEnRestaurante('Mars/Olympus', instante),
          instante.toLocal());
    });
  });

  group('Ajustes operativos', () {
    test('sin configuración se usan los valores por defecto', () {
      final c = OperationsConfig.fromRestaurantData(null);
      expect(c.alertasActivas, isTrue);
      expect(c.umbralAlertaMin, 30);
      expect(c.recordatorioMin, 120);
      expect(c.recordatorioTardioInmediato, isFalse);
      expect(c.zonaHoraria, 'America/Mexico_City');
    });

    test('umbralAlertaMin en null (como en los datos semilla) usa el valor por defecto', () {
      final c = OperationsConfig.fromRestaurantData({
        'zonaHoraria': 'America/Cancun',
        'configuracion': {'umbralAlertaMin': null, 'recordatorioMin': 60},
      });
      expect(c.umbralAlertaMin, 30);
      expect(c.recordatorioMin, 60);
      expect(c.zonaHoraria, 'America/Cancun');
    });

    test('la anticipación se escribe en palabras', () {
      expect(OperationsConfig.textoAnticipacion(120), '2 horas');
      expect(OperationsConfig.textoAnticipacion(60), '1 hora');
      expect(OperationsConfig.textoAnticipacion(90), '1 hora y 30 minutos');
      expect(OperationsConfig.textoAnticipacion(45), '45 minutos');
    });

    test('se guardan y se leen del restaurante', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('restaurants').doc('r1').set({
        'nombre': 'Miel',
        'configuracion': {'limiteCambioMin': 120},
      });
      final svc = OperationsConfigService(firestore: db);
      await svc.guardar(
        'r1',
        const OperationsConfig(alertasActivas: false, umbralAlertaMin: 15, recordatorioMin: 180),
      );
      final c = await svc.cargar('r1');
      expect(c.alertasActivas, isFalse);
      expect(c.umbralAlertaMin, 15);
      expect(c.recordatorioMin, 180);
      // No pisa los demás ajustes.
      final doc = (await db.collection('restaurants').doc('r1').get()).data()!;
      expect(doc['configuracion']['limiteCambioMin'], 120);
    });

    test('rechaza umbrales inválidos', () {
      final svc = OperationsConfigService(firestore: FakeFirebaseFirestore());
      expect(() => svc.guardar('r1', const OperationsConfig(umbralAlertaMin: 0)),
          throwsArgumentError);
    });
  });

  group('HU30-RF01 cálculo de alertas de llegada', () {
    const config = OperationsConfig(umbralAlertaMin: 30);

    List<ArrivalAlert> calcular(List<ReservationModel> rs, DateTime ahora,
            [OperationsConfig c = config]) =>
        ArrivalAlertCalculator.calcular(reservas: rs, ahora: ahora, config: c);

    test('genera alerta cuando falta el umbral o menos', () {
      final alertas = calcular([reserva(inicio: mx(30, 14))], mx(30, 13, 35));
      expect(alertas, hasLength(1));
      expect(alertas.single.tipo, TipoAlertaLlegada.proxima);
      expect(alertas.single.minutos, 25);
      expect(alertas.single.texto, 'Llega en 25 min');
    });

    test('justo en el umbral ya alerta, un minuto antes no', () {
      expect(calcular([reserva()], mx(30, 13, 30)), hasLength(1));
      expect(calcular([reserva()], mx(30, 13, 29)), isEmpty);
    });

    test('cuenta los minutos que faltan sin perder los segundos', () {
      final ahora = mx(30, 13, 45).add(const Duration(seconds: 30));
      expect(calcular([reserva()], ahora).single.minutos, 15);
    });

    test('a la hora exacta dice "Es ahora"', () {
      expect(calcular([reserva()], mx(30, 14)).single.texto, 'Es ahora');
    });

    test('el umbral es configurable', () {
      final r = reserva();
      expect(calcular([r], mx(30, 13, 45), const OperationsConfig(umbralAlertaMin: 15)),
          hasLength(1));
      expect(calcular([r], mx(30, 13, 45), const OperationsConfig(umbralAlertaMin: 10)),
          isEmpty);
    });

    test('solo alerta reservas pendientes de llegada', () {
      final ahora = mx(30, 13, 50);
      for (final estado in [
        ReservationModel.estadoClienteLlego,
        ReservationModel.estadoEnServicio,
        ReservationModel.estadoFinalizada,
        ReservationModel.estadoCancelada,
        ReservationModel.estadoNoShow,
      ]) {
        expect(calcular([reserva(estado: estado)], ahora), isEmpty, reason: estado);
      }
      expect(calcular([reserva(estado: ReservationModel.estadoPendienteLlegada)], ahora),
          hasLength(1));
      // Una reserva "confirmada" es pendiente de llegada.
      expect(calcular([reserva(estado: ReservationModel.estadoConfirmada)], ahora),
          hasLength(1));
    });

    test('al pasar la hora sin que llegue cambia a retraso (posible no-show)', () {
      final alertas = calcular([reserva()], mx(30, 14, 12));
      expect(alertas.single.tipo, TipoAlertaLlegada.retraso);
      expect(alertas.single.esRetraso, isTrue);
      expect(alertas.single.minutos, 12);
      expect(alertas.single.texto, 'Tarde 12 min');
    });

    test('cuando el cliente llega la alerta desaparece', () {
      expect(calcular([reserva(estado: ReservationModel.estadoClienteLlego)], mx(30, 14, 5)),
          isEmpty);
    });

    test('solo cuenta las reservas de hoy en la zona del restaurante', () {
      // 02:00 UTC del 31: en México todavía es 30 → la reserva del 30 es de hoy.
      final ahora = DateTime.utc(2026, 10, 31, 2);
      final de30 = reserva(inicio: DateTime.utc(2026, 10, 31, 2, 10), fecha: '2026-10-30');
      final de31 = reserva(id: 'b', inicio: DateTime.utc(2026, 10, 31, 2, 10), fecha: '2026-10-31');
      final alertas = calcular([de30, de31], ahora);
      expect(alertas.map((a) => a.reserva.id), ['a1']);
    });

    test('con las alertas desactivadas no hay ninguna', () {
      expect(
        calcular([reserva()], mx(30, 13, 50), const OperationsConfig(alertasActivas: false)),
        isEmpty,
      );
    });

    test('ordena por hora de llegada', () {
      final alertas = calcular([
        reserva(id: 'tarde', inicio: mx(30, 14, 20)),
        reserva(id: 'pronto', inicio: mx(30, 14, 5)),
      ], mx(30, 13, 55));
      expect(alertas.map((a) => a.reserva.id), ['pronto', 'tarde']);
    });

    test('la clave identifica reserva, tipo y umbral', () {
      final a = calcular([reserva()], mx(30, 13, 50)).single;
      expect(a.clave, 'a1_proxima_30');
      final b = calcular([reserva()], mx(30, 14, 5)).single;
      expect(b.clave, 'a1_retraso_30');
    });

    test('informa si el pedido ya está listo o por preparar (HU29-RF03)', () {
      final ahora = mx(30, 13, 50);
      final listo =
          calcular([reserva(conPreorden: true, estadoPreorden: 'listo')], ahora).single;
      expect(listo.pedidoListo, isTrue);
      expect(listo.pedidoPorPreparar, isFalse);
      final pendiente = calcular([reserva(conPreorden: true)], ahora).single;
      expect(pendiente.pedidoListo, isFalse);
      expect(pendiente.pedidoPorPreparar, isTrue);
      final sin = calcular([reserva()], ahora).single;
      expect(sin.pedidoListo, isFalse);
      expect(sin.pedidoPorPreparar, isFalse);
    });

    test('deReserva encuentra la alerta de una reserva', () {
      final alertas = calcular([reserva()], mx(30, 13, 50));
      expect(ArrivalAlertCalculator.deReserva(alertas, 'a1'), isNotNull);
      expect(ArrivalAlertCalculator.deReserva(alertas, 'zz'), isNull);
    });
  });

  group('HU30-RF02 envío de la notificación al administrador', () {
    late FakeFirebaseFirestore db;
    late _FakePush push;
    late AdminAlertService servicio;
    const config = OperationsConfig(umbralAlertaMin: 30);

    setUp(() {
      db = FakeFirebaseFirestore();
      push = _FakePush();
      servicio = AdminAlertService(firestore: db, gateway: push);
    });

    test('el mensaje trae cliente, hora, mesa y preorden/alergias', () async {
      final r = reserva(
        nombre: 'Ana López',
        mesas: ['m1', 'm2'],
        conPreorden: true,
        alergias: ['Nueces'],
      );
      await servicio.sincronizar(
          restauranteId: 'r1', reservas: [r], ahora: mx(30, 13, 50), config: config);
      expect(push.mensajes, hasLength(1));
      final m = push.mensajes.single;
      expect(m.titulo, contains('Ana López'));
      expect(m.cuerpo, contains('Ana López'));
      expect(m.cuerpo, contains('M1 + M2'));
      expect(m.cuerpo, contains('Preorden por preparar'));
      expect(m.cuerpo, contains('Alergias'));
      expect(m.datos['tienePreorden'], isTrue);
      expect(m.datos['tieneAlergias'], isTrue);
    });

    test('indica cuando la preorden ya está lista', () async {
      final r = reserva(conPreorden: true, estadoPreorden: 'listo');
      await servicio.sincronizar(
          restauranteId: 'r1', reservas: [r], ahora: mx(30, 13, 50), config: config);
      expect(push.mensajes.single.cuerpo, contains('Preorden lista'));
    });

    test('no duplica la notificación de la misma reserva y umbral', () async {
      final r = reserva();
      for (final minuto in [50, 52, 55, 58]) {
        await servicio.sincronizar(
            restauranteId: 'r1', reservas: [r], ahora: mx(30, 13, minuto), config: config);
      }
      expect(push.mensajes, hasLength(1));
      expect((await db.collection('restaurants').doc('r1').collection('alertasAdmin').get()).docs,
          hasLength(1));
    });

    test('dos dispositivos que sincronizan a la vez avisan una sola vez', () async {
      final otro = AdminAlertService(firestore: db, gateway: push);
      final r = reserva();
      await Future.wait([
        servicio.sincronizar(
            restauranteId: 'r1', reservas: [r], ahora: mx(30, 13, 50), config: config),
        otro.sincronizar(
            restauranteId: 'r1', reservas: [r], ahora: mx(30, 13, 50), config: config),
      ]);
      expect(push.mensajes.length, lessThanOrEqualTo(2));
      final docs = await db.collection('restaurants').doc('r1').collection('alertasAdmin').get();
      expect(docs.docs, hasLength(1));
    });

    test('otro umbral o el retraso sí generan un aviso nuevo', () async {
      final r = reserva();
      await servicio.sincronizar(
          restauranteId: 'r1', reservas: [r], ahora: mx(30, 13, 50), config: config);
      await servicio.sincronizar(
          restauranteId: 'r1',
          reservas: [r],
          ahora: mx(30, 13, 50),
          config: const OperationsConfig(umbralAlertaMin: 60));
      await servicio.sincronizar(
          restauranteId: 'r1', reservas: [r], ahora: mx(30, 14, 10), config: config);
      expect(push.mensajes.map((m) => m.clave),
          ['a1_proxima_30', 'a1_proxima_60', 'a1_retraso_30']);
    });

    test('la alerta se desactiva cuando el cliente llega', () async {
      await servicio.sincronizar(
          restauranteId: 'r1', reservas: [reserva()], ahora: mx(30, 13, 50), config: config);
      final r = await servicio.sincronizar(
        restauranteId: 'r1',
        reservas: [reserva(estado: ReservationModel.estadoClienteLlego)],
        ahora: mx(30, 13, 55),
        config: config,
      );
      expect(r.alertas, isEmpty);
      expect(r.desactivadas, ['a1_proxima_30']);
      final doc = await db
          .collection('restaurants')
          .doc('r1')
          .collection('alertasAdmin')
          .doc('a1_proxima_30')
          .get();
      expect(doc.data()!['activa'], isFalse);
    });

    test('la alerta de próxima cambia a retraso al pasar la hora', () async {
      await servicio.sincronizar(
          restauranteId: 'r1', reservas: [reserva()], ahora: mx(30, 13, 50), config: config);
      final r = await servicio.sincronizar(
          restauranteId: 'r1', reservas: [reserva()], ahora: mx(30, 14, 10), config: config);
      expect(r.desactivadas, ['a1_proxima_30']);
      expect(r.nuevas, ['a1_retraso_30']);
    });

    test('si el push falla la alerta queda registrada para la app y para reintentar', () async {
      push.falla = true;
      final r = await servicio.sincronizar(
          restauranteId: 'r1', reservas: [reserva()], ahora: mx(30, 13, 50), config: config);
      expect(r.nuevas, hasLength(1));
      final doc = await db
          .collection('restaurants')
          .doc('r1')
          .collection('alertasAdmin')
          .doc('a1_proxima_30')
          .get();
      expect(doc.data()!['pushEnviado'], isFalse);
      expect(doc.data()!['activa'], isTrue);
    });

    test('la cola de push guarda el mensaje una sola vez por clave', () async {
      final cola = FirestorePushQueue(firestore: db);
      final real = AdminAlertService(firestore: db, gateway: cola);
      for (var i = 0; i < 3; i++) {
        await real.sincronizar(
            restauranteId: 'r1', reservas: [reserva()], ahora: mx(30, 13, 50), config: config);
      }
      final docs = await db.collection('restaurants').doc('r1').collection('colaPush').get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.single.data()['canal'], 'fcm');
      expect(docs.docs.single.data()['estado'], 'pendiente');
    });

    test('las alertas activas se pueden escuchar y marcar como leídas', () async {
      await servicio.sincronizar(
          restauranteId: 'r1', reservas: [reserva()], ahora: mx(30, 13, 50), config: config);
      var lista = await servicio.alertasActivas('r1').first;
      expect(lista, hasLength(1));
      expect(lista.single['leida'], isFalse);
      await servicio.marcarLeida('r1', 'a1_proxima_30');
      lista = await servicio.alertasActivas('r1').first;
      expect(lista.single['leida'], isTrue);
    });
  });

  group('HU29-RF01 estado del pedido preordenado', () {
    test('avanza solo de forma secuencial', () {
      expect(OrderStateMachine.siguiente('pendiente'), 'en_preparacion');
      expect(OrderStateMachine.siguiente('en_preparacion'), 'listo');
      expect(OrderStateMachine.siguiente('listo'), isNull);
      expect(OrderStateMachine.anterior('listo'), 'en_preparacion');
      expect(OrderStateMachine.anterior('pendiente'), isNull);
      OrderStateMachine.validar('pendiente', 'en_preparacion');
      OrderStateMachine.validar('en_preparacion', 'listo');
    });

    test('no se puede saltar pasos', () {
      expect(() => OrderStateMachine.validar('pendiente', 'listo'),
          throwsA(isA<InvalidOrderTransitionException>()));
    });

    test('no se puede repetir el mismo estado', () {
      expect(() => OrderStateMachine.validar('listo', 'listo'),
          throwsA(isA<InvalidOrderTransitionException>()));
    });

    test('regresar un paso exige un motivo', () {
      expect(OrderStateMachine.esReversa('listo', 'en_preparacion'), isTrue);
      expect(OrderStateMachine.esReversa('pendiente', 'en_preparacion'), isFalse);
      expect(() => OrderStateMachine.validar('listo', 'en_preparacion'),
          throwsA(isA<InvalidOrderTransitionException>()));
      expect(() => OrderStateMachine.validar('listo', 'en_preparacion', motivo: '  '),
          throwsA(isA<InvalidOrderTransitionException>()));
      OrderStateMachine.validar('listo', 'en_preparacion', motivo: 'Se cayó el platillo');
    });

    test('regresar solo se permite un paso a la vez', () {
      expect(() => OrderStateMachine.validar('listo', 'pendiente', motivo: 'error'),
          throwsA(isA<InvalidOrderTransitionException>()));
    });

    test('estados fuera de la secuencia ya no se cambian', () {
      expect(() => OrderStateMachine.validar('entregado', 'listo', motivo: 'x'),
          throwsA(isA<InvalidOrderTransitionException>()));
    });

    group('cambio de estado guardado', () {
      late FakeFirebaseFirestore db;
      late ReservationService servicio;

      setUp(() async {
        db = FakeFirebaseFirestore();
        servicio = ReservationService(firestore: db);
        await db.collection('restaurants').doc('r1').set({'nombre': 'Miel'});
      });

      Future<ReservationModel> guardar({bool conPreorden = true}) {
        final r = reserva(id: '', conPreorden: conPreorden, inicio: DateTime(2026, 10, 30, 14));
        return servicio.createReservationVerified(r);
      }

      test('un pedido nuevo está pendiente', () async {
        final r = await guardar();
        expect(r.estadoPreorden, 'pendiente');
        expect((await servicio.getReservationById(r.id))!.estadoPreorden, 'pendiente');
      });

      test('avanza a en preparación y listo registrando la marca de tiempo', () async {
        final r = await guardar();
        final t1 = DateTime(2026, 10, 30, 13, 30);
        final enPrep = await servicio.changeOrderState(
          reservationId: r.id,
          nuevoEstado: 'en_preparacion',
          usuarioId: 'admin1',
          ahora: t1,
        );
        expect(enPrep.estadoPreorden, 'en_preparacion');
        expect(enPrep.estadoPreordenActualizadoEn, t1);

        final t2 = DateTime(2026, 10, 30, 13, 45);
        await servicio.changeOrderState(
          reservationId: r.id,
          nuevoEstado: 'listo',
          usuarioId: 'admin1',
          ahora: t2,
        );
        final leida = (await servicio.getReservationById(r.id))!;
        expect(leida.estadoPreorden, 'listo');
        expect(leida.estadoPreordenActualizadoEn, t2);
        expect(leida.historialPedido, hasLength(2));
        expect(leida.historialPedido.last['de'], 'en_preparacion');
        expect(leida.historialPedido.last['a'], 'listo');
        expect(leida.historialPedido.last['por'], 'admin1');
      });

      test('rechaza saltarse un paso y no cambia nada', () async {
        final r = await guardar();
        await expectLater(
          servicio.changeOrderState(
              reservationId: r.id, nuevoEstado: 'listo', usuarioId: 'admin1'),
          throwsA(isA<InvalidOrderTransitionException>()),
        );
        expect((await servicio.getReservationById(r.id))!.estadoPreorden, 'pendiente');
      });

      test('la reversa guarda el motivo', () async {
        final r = await guardar();
        for (final e in ['en_preparacion', 'listo']) {
          await servicio.changeOrderState(
              reservationId: r.id, nuevoEstado: e, usuarioId: 'admin1');
        }
        await expectLater(
          servicio.changeOrderState(
              reservationId: r.id, nuevoEstado: 'en_preparacion', usuarioId: 'admin1'),
          throwsA(isA<InvalidOrderTransitionException>()),
        );
        await servicio.changeOrderState(
          reservationId: r.id,
          nuevoEstado: 'en_preparacion',
          usuarioId: 'admin1',
          motivo: 'El cliente cambió el platillo',
        );
        final leida = (await servicio.getReservationById(r.id))!;
        expect(leida.estadoPreorden, 'en_preparacion');
        expect(leida.historialPedido.last['motivo'], 'El cliente cambió el platillo');
      });

      test('una reserva sin preorden no tiene pedido que cambiar', () async {
        final r = await guardar(conPreorden: false);
        await expectLater(
          servicio.changeOrderState(
              reservationId: r.id, nuevoEstado: 'en_preparacion', usuarioId: 'admin1'),
          throwsA(isA<InvalidOrderTransitionException>()),
        );
      });

      test('HU29-RF03: marcar el pedido listo no cambia la reserva ni su mesa', () async {
        final r = await guardar();
        for (final e in ['en_preparacion', 'listo']) {
          await servicio.changeOrderState(
              reservationId: r.id, nuevoEstado: e, usuarioId: 'admin1');
        }
        final leida = (await servicio.getReservationById(r.id))!;
        expect(leida.estadoOperativo, ReservationModel.estadoPendienteLlegada);
        expect(leida.historialEstados, isEmpty);
        expect(leida.mesaIds, ['m1']);
        // La mesa sigue bloqueada para otras reservas.
        await expectLater(
          servicio.createReservationVerified(
              reserva(id: '', inicio: DateTime(2026, 10, 30, 14, 30))),
          throwsA(isA<ReservationConflictException>()),
        );
      });

      test('el pedido listo antes de la llegada queda disponible para la alerta', () async {
        final r = await guardar();
        for (final e in ['en_preparacion', 'listo']) {
          await servicio.changeOrderState(
              reservationId: r.id, nuevoEstado: e, usuarioId: 'admin1');
        }
        final leida = (await servicio.getReservationById(r.id))!;
        final alerta = ArrivalAlertCalculator.calcular(
          reservas: [leida.copyWith(fechaLocal: '2026-10-30', inicio: mx(30, 14))],
          ahora: mx(30, 13, 50),
        ).single;
        expect(alerta.pedidoListo, isTrue);
      });
    });
  });

  group('HU21-RF01 recordatorio', () {
    const config = OperationsConfig(recordatorioMin: 120);

    test('se programa con la anticipación configurada', () {
      final plan = ReminderPolicy.planear(
          inicio: mx(30, 14), ahora: mx(29, 10), config: config);
      expect(plan.estado, ReminderState.programado);
      expect(plan.programadoPara, mx(30, 12));
    });

    test('con menos anticipación que el recordatorio no se envía', () {
      final plan = ReminderPolicy.planear(
          inicio: mx(30, 14), ahora: mx(30, 13), config: config);
      expect(plan.estado, ReminderState.omitido);
      expect(plan.programadoPara, isNull);
      expect(plan.motivo, isNotNull);
    });

    test('con la regla configurable se envía de inmediato', () {
      final plan = ReminderPolicy.planear(
        inicio: mx(30, 14),
        ahora: mx(30, 13),
        config: const OperationsConfig(recordatorioMin: 120, recordatorioTardioInmediato: true),
      );
      expect(plan.estado, ReminderState.programado);
      expect(plan.programadoPara, mx(30, 13));
    });

    test('una reserva que ya comenzó no recibe recordatorio', () {
      final plan = ReminderPolicy.planear(
        inicio: mx(30, 14),
        ahora: mx(30, 14, 5),
        config: const OperationsConfig(recordatorioTardioInmediato: true),
      );
      expect(plan.estado, ReminderState.omitido);
    });

    group('con Firestore', () {
      late FakeFirebaseFirestore db;
      late _FakeEmail correo;
      late ReminderService recordatorios;
      late ReservationService reservas;

      DateTime ahoraBase = DateTime(2026, 10, 29, 10);

      setUp(() async {
        db = FakeFirebaseFirestore();
        correo = _FakeEmail();
        recordatorios = ReminderService(
          firestore: db,
          now: () => ahoraBase,
          notificaciones: ConfirmationNotificationService(
            emailClient: correo,
            whatsAppClient: DefaultWhatsAppBusinessApiClient(),
            firestore: db,
          ),
        );
        reservas = ReservationService(firestore: db, recordatorios: recordatorios);
        await db.collection('restaurants').doc('r1').set({
          'nombre': 'Miel',
          'configuracion': {'recordatorioMin': 120},
        });
        ahoraBase = DateTime(2026, 10, 29, 10);
      });

      Future<ReservationModel> confirmar({DateTime? inicio, String id = ''}) =>
          reservas.createReservationVerified(
            reserva(id: id, inicio: inicio ?? DateTime(2026, 10, 30, 14)),
          );

      test('al confirmar la reserva se programa el recordatorio', () async {
        final r = await confirmar();
        final doc = await recordatorios.obtener('r1', r.id);
        expect(doc, isNotNull);
        expect(doc!['estado'], ReminderState.programado);
        expect((doc['programadoPara'] as Timestamp).toDate(), DateTime(2026, 10, 30, 12));
        expect(doc['minutosAntes'], 120);
      });

      test('antes de la hora programada no se envía nada', () async {
        final r = await confirmar();
        final res = await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [r],
          ahora: DateTime(2026, 10, 30, 11, 50),
        );
        expect(res.enviados, isEmpty);
        expect(correo.enviados, isEmpty);
      });

      test('a la hora programada se envía por el mismo canal de la confirmación', () async {
        final r = await confirmar();
        final res = await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [r],
          ahora: DateTime(2026, 10, 30, 12, 1),
        );
        expect(res.enviados, [r.id]);
        expect(correo.enviados, hasLength(1));
        expect(correo.enviados.single, startsWith('carlos@test.com|'));
        final doc = (await recordatorios.obtener('r1', r.id))!;
        expect(doc['estado'], ReminderState.enviado);
        expect(doc['dentroDeMargen'], isTrue);
      });

      test('no se envía dos veces', () async {
        final r = await confirmar();
        for (var i = 0; i < 3; i++) {
          await recordatorios.procesar(
            restauranteId: 'r1',
            reservas: [r],
            ahora: DateTime(2026, 10, 30, 12, 1 + i),
          );
        }
        expect(correo.enviados, hasLength(1));
      });

      test('si el envío llega con más de 5 minutos de retraso lo registra', () async {
        final r = await confirmar();
        await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [r],
          ahora: DateTime(2026, 10, 30, 12, 20),
        );
        expect((await recordatorios.obtener('r1', r.id))!['dentroDeMargen'], isFalse);
      });

      test('si la reserva se cancela el recordatorio se cancela', () async {
        final r = await confirmar();
        await reservas.changeOperationalState(
            reservationId: r.id, nuevoEstado: 'cancelada', usuarioId: 'admin1');
        expect((await recordatorios.obtener('r1', r.id))!['estado'], ReminderState.cancelado);
        final cancelada = (await reservas.getReservationById(r.id))!;
        await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [cancelada],
          ahora: DateTime(2026, 10, 30, 12, 1),
        );
        expect(correo.enviados, isEmpty);
      });

      test('la conciliación cancela el recordatorio si la reserva se canceló con su enlace', () async {
        final r = await confirmar();
        // El visitante cancela con su token: solo cambia la reserva, no el recordatorio.
        await db.collection('reservations').doc(r.id).update({'estado': 'cancelada'});
        final cancelada = (await reservas.getReservationById(r.id))!;
        final res = await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [cancelada],
          ahora: DateTime(2026, 10, 30, 12, 1),
        );
        expect(res.cancelados, [r.id]);
        expect(correo.enviados, isEmpty);
      });

      test('si se modifica la hora se reprograma', () async {
        final r = await confirmar();
        await db
            .collection('reservations')
            .doc(r.id)
            .update({'inicio': Timestamp.fromDate(DateTime(2026, 10, 30, 19))});
        final modificada = (await reservas.getReservationById(r.id))!;
        final res = await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [modificada],
          ahora: DateTime(2026, 10, 29, 12),
        );
        expect(res.reprogramados, [r.id]);
        final doc = (await recordatorios.obtener('r1', r.id))!;
        expect((doc['programadoPara'] as Timestamp).toDate(), DateTime(2026, 10, 30, 17));
        // A la hora vieja ya no se envía; a la nueva sí.
        await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [modificada],
          ahora: DateTime(2026, 10, 30, 12, 1),
        );
        expect(correo.enviados, isEmpty);
        await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [modificada],
          ahora: DateTime(2026, 10, 30, 17, 1),
        );
        expect(correo.enviados, hasLength(1));
      });

      test('una reserva anterior a los recordatorios recibe el suyo al conciliar', () async {
        final r = await confirmar();
        await db
            .collection('restaurants')
            .doc('r1')
            .collection('recordatorios')
            .doc(r.id)
            .delete();
        final res = await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [r.copyWith(creadaEn: DateTime(2026, 10, 29, 9))],
          ahora: DateTime(2026, 10, 30, 12, 1),
        );
        expect(res.enviados, [r.id]);
      });

      test('si el envío falla se reintenta y tras 3 intentos queda como fallido', () async {
        correo.falla = true;
        final r = await confirmar();
        late ReminderRunResult res;
        for (var i = 0; i < 3; i++) {
          res = await recordatorios.procesar(
            restauranteId: 'r1',
            reservas: [r],
            ahora: DateTime(2026, 10, 30, 12, 1 + i),
          );
          if (i < 2) {
            expect((await recordatorios.obtener('r1', r.id))!['estado'],
                ReminderState.programado);
          }
        }
        expect(res.fallidos, [r.id]);
        final doc = (await recordatorios.obtener('r1', r.id))!;
        expect(doc['estado'], ReminderState.fallido);
        expect(doc['intentos'], 3);
      });

      test('una reserva con menos anticipación que el recordatorio queda omitida', () async {
        final r = await confirmar(inicio: DateTime(2026, 10, 29, 11));
        final doc = (await recordatorios.obtener('r1', r.id))!;
        expect(doc['estado'], ReminderState.omitido);
        await recordatorios.procesar(
          restauranteId: 'r1',
          reservas: [r],
          ahora: DateTime(2026, 10, 29, 10, 30),
        );
        expect(correo.enviados, isEmpty);
      });

      test('un fallo al programar no revierte la reserva', () async {
        final rota = ReservationService(
          firestore: db,
          recordatorios: _RecordatoriosRotos(),
        );
        final r = await rota.createReservationVerified(
            reserva(id: '', inicio: DateTime(2026, 10, 30, 16), mesas: ['m2']));
        expect((await rota.getReservationById(r.id)), isNotNull);
      });
    });
  });

  group('HU31-RF01 estado en tiempo real de las mesas', () {
    const m1 = MesaModel(id: 'm1', nombre: 'M1', capacidad: 4);
    const m2 = MesaModel(id: 'm2', nombre: 'M2', capacidad: 4);
    const m3 = MesaModel(id: 'm3', nombre: 'M3', capacidad: 2);

    TableLiveStatus de(String id, List<MesaModel> mesas, List<ReservationModel> rs,
            DateTime ahora) =>
        TableLiveStatusCalculator.calcular(mesas: mesas, reservas: rs, ahora: ahora)
            .firstWhere((e) => e.mesa.id == id);

    test('sin reservas todas están disponibles', () {
      final estados = TableLiveStatusCalculator.calcular(
          mesas: [m1, m2], reservas: const [], ahora: mx(30, 14));
      expect(estados.every((e) => e.estado == EstadoMesaVivo.disponible), isTrue);
    });

    test('una reserva vigente en este horario ocupa su mesa', () {
      final r = reserva(inicio: mx(30, 14));
      final e = de('m1', [m1, m2], [r], mx(30, 14, 30));
      expect(e.estado, EstadoMesaVivo.ocupada);
      expect(e.reserva!.id, 'a1');
      expect(de('m2', [m1, m2], [r], mx(30, 14, 30)).estado, EstadoMesaVivo.disponible);
    });

    test('antes de la hora y después del fin la mesa está disponible', () {
      final r = reserva(inicio: mx(30, 14));
      expect(de('m1', [m1], [r], mx(30, 13, 59)).estado, EstadoMesaVivo.disponible);
      expect(de('m1', [m1], [r], mx(30, 15, 30)).estado, EstadoMesaVivo.disponible);
      expect(de('m1', [m1], [r], mx(30, 15, 29)).estado, EstadoMesaVivo.ocupada);
    });

    test('si el cliente llegó o está en servicio la mesa sigue ocupada pasado el fin', () {
      for (final estado in [
        ReservationModel.estadoClienteLlego,
        ReservationModel.estadoEnServicio,
      ]) {
        final r = reserva(inicio: mx(30, 14), estado: estado);
        expect(de('m1', [m1], [r], mx(30, 16)).estado, EstadoMesaVivo.ocupada, reason: estado);
      }
    });

    test('al finalizar, cancelar o no presentarse la mesa se libera', () {
      for (final estado in [
        ReservationModel.estadoFinalizada,
        ReservationModel.estadoCancelada,
        ReservationModel.estadoNoShow,
      ]) {
        final r = reserva(inicio: mx(30, 14), estado: estado);
        expect(de('m1', [m1], [r], mx(30, 14, 30)).estado, EstadoMesaVivo.disponible,
            reason: estado);
      }
    });

    test('una reserva con varias mesas las muestra combinadas con su reserva', () {
      final r = reserva(inicio: mx(30, 14), mesas: ['m1', 'm2']);
      final e1 = de('m1', [m1, m2, m3], [r], mx(30, 14, 10));
      expect(e1.estado, EstadoMesaVivo.combinada);
      expect(e1.combinadaCon, ['M2']);
      expect(e1.reserva!.id, 'a1');
      expect(e1.enUso, isTrue);
      final e2 = de('m2', [m1, m2, m3], [r], mx(30, 14, 10));
      expect(e2.combinadaCon, ['M1']);
      expect(de('m3', [m1, m2, m3], [r], mx(30, 14, 10)).estado, EstadoMesaVivo.disponible);
    });

    test('tres mesas combinadas listan a las otras dos', () {
      final r = reserva(inicio: mx(30, 14), mesas: ['m1', 'm2', 'm3']);
      expect(de('m1', [m1, m2, m3], [r], mx(30, 14, 10)).combinadaCon, ['M2', 'M3']);
    });

    test('el estado manual fuera de servicio manda sobre las reservas', () {
      final fuera = m1.copyWith(estadoManual: MesaModel.estadoFueraDeServicio);
      final r = reserva(inicio: mx(30, 14));
      final e = de('m1', [fuera], [r], mx(30, 14, 10));
      expect(e.estado, EstadoMesaVivo.fueraDeServicio);
      expect(e.forzada, isTrue);
      expect(e.reserva, isNotNull);
      expect(de('m1', [fuera], const [], mx(30, 14, 10)).estado,
          EstadoMesaVivo.fueraDeServicio);
    });

    test('se recalcula al cambiar el estado de la reserva', () {
      var r = reserva(inicio: mx(30, 14));
      expect(de('m1', [m1], [r], mx(30, 14, 10)).estado, EstadoMesaVivo.ocupada);
      r = r.copyWith(estado: ReservationModel.estadoCancelada);
      expect(de('m1', [m1], [r], mx(30, 14, 10)).estado, EstadoMesaVivo.disponible);
    });

    test('las etiquetas son legibles', () {
      expect(const TableLiveStatus(mesa: m1, estado: EstadoMesaVivo.disponible).etiqueta,
          'Disponible');
      expect(const TableLiveStatus(mesa: m1, estado: EstadoMesaVivo.fueraDeServicio).etiqueta,
          'Fuera de servicio');
    });

    group('estado manual en Firestore', () {
      late FakeFirebaseFirestore db;
      late TableStatusService servicio;

      setUp(() async {
        db = FakeFirebaseFirestore();
        servicio = TableStatusService(firestore: db);
        await db
            .collection('restaurants')
            .doc('r1')
            .collection('mesas')
            .doc('m1')
            .set({'nombre': 'M1', 'capacidad': 4, 'estadoManual': null});
      });

      test('se marca fuera de servicio y se reactiva', () async {
        await servicio.ponerFueraDeServicio('r1', 'm1');
        var mesas = await servicio.mesasStream('r1').first;
        expect(mesas.single.fueraDeServicio, isTrue);
        await servicio.reactivar('r1', 'm1');
        mesas = await servicio.mesasStream('r1').first;
        expect(mesas.single.fueraDeServicio, isFalse);
        expect(mesas.single.estadoManual, isNull);
      });
    });
  });

  group('HU25-RF01 métricas del día', () {
    const mesas = [
      MesaModel(id: 'm1', nombre: 'M1', capacidad: 4),
      MesaModel(id: 'm2', nombre: 'M2', capacidad: 4),
      MesaModel(id: 'm3', nombre: 'M3', capacidad: 2),
    ];

    DailyMetrics calcular(List<ReservationModel> rs, DateTime ahora,
            [List<MesaModel> ms = mesas]) =>
        DailyMetrics.calcular(
            reservas: rs, mesas: ms, ahora: ahora, zonaHoraria: 'America/Mexico_City');

    test('sin datos devuelve todo en cero, no un error', () {
      final m = calcular(const [], mx(30, 10), const []);
      expect(m, DailyMetrics.vacias);
      expect(m.totalReservas, 0);
      expect(m.sinActividad, isTrue);
    });

    test('con mesas y sin reservas solo cuenta las mesas activas', () {
      final m = calcular(const [], mx(30, 10));
      expect(m.totalReservas, 0);
      expect(m.mesasActivas, 3);
      expect(m.mesasOcupadas, 0);
    });

    test('cuenta reservas, personas, mesas ocupadas y pedidos con preorden', () {
      final rs = [
        reserva(id: 'a', inicio: mx(30, 14), personas: 4, conPreorden: true),
        reserva(id: 'b', inicio: mx(30, 14), personas: 2, mesas: ['m2']),
        reserva(id: 'c', inicio: mx(30, 20), personas: 6, mesas: ['m3'], conPreorden: true),
      ];
      final m = calcular(rs, mx(30, 14, 30));
      expect(m.totalReservas, 3);
      expect(m.personasEsperadas, 12);
      expect(m.mesasActivas, 3);
      expect(m.mesasOcupadas, 2);
      expect(m.pedidosConPreorden, 2);
    });

    test('excluye canceladas, finalizadas y no-show', () {
      final rs = [
        reserva(id: 'a', personas: 4),
        reserva(id: 'b', estado: ReservationModel.estadoCancelada, personas: 9),
        reserva(id: 'c', estado: ReservationModel.estadoFinalizada, personas: 9),
        reserva(id: 'd', estado: ReservationModel.estadoNoShow, personas: 9),
      ];
      final m = calcular(rs, mx(30, 10));
      expect(m.totalReservas, 1);
      expect(m.personasEsperadas, 4);
    });

    test('incluye reservas con el cliente ya presente o en servicio', () {
      final rs = [
        reserva(id: 'a', estado: ReservationModel.estadoClienteLlego),
        reserva(id: 'b', estado: ReservationModel.estadoEnServicio, mesas: ['m2']),
      ];
      final m = calcular(rs, mx(30, 14, 10));
      expect(m.totalReservas, 2);
      expect(m.mesasOcupadas, 2);
    });

    test('solo cuenta las reservas de hoy en la zona del restaurante', () {
      final rs = [
        reserva(id: 'hoy'),
        reserva(id: 'manana', fecha: '2026-10-31', inicio: mx(31, 14)),
      ];
      expect(calcular(rs, mx(30, 10)).totalReservas, 1);
    });

    test('las mesas fuera de servicio no cuentan como activas', () {
      final fuera = [
        mesas[0].copyWith(estadoManual: MesaModel.estadoFueraDeServicio),
        mesas[1],
      ];
      expect(calcular(const [], mx(30, 10), fuera).mesasActivas, 1);
    });

    test('una reserva con mesas combinadas cuenta todas las mesas como ocupadas', () {
      final m = calcular([reserva(mesas: ['m1', 'm2'])], mx(30, 14, 10));
      expect(m.totalReservas, 1);
      expect(m.mesasOcupadas, 2);
    });

    test('se actualiza al cambiar las reservas', () {
      final r = reserva();
      expect(calcular([r], mx(30, 10)).totalReservas, 1);
      expect(calcular([r.copyWith(estado: ReservationModel.estadoCancelada)], mx(30, 10)).totalReservas,
          0);
    });
  });
}

class _RecordatoriosRotos extends ReminderService {
  @override
  Future<ReminderPlan> programar(
    ReservationModel reserva, {
    OperationsConfig? config,
    DateTime? ahora,
  }) async {
    throw Exception('sin red');
  }
}
