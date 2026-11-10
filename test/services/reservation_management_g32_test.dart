import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/reservation_access.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/reservation_notification_payload.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/confirmation_notification_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/reservation_management_service.dart';
import 'package:reservitta/services/reservation_service.dart';

const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

RestaurantModel _restaurant() {
  return RestaurantModel(
    id: 'r1',
    nombre: 'Miel Test',
    estado: 'activo',
    telefono: '418-555-0101',
    direccion: 'Calle 1',
    horarios: {
      for (final d in [
        'lunes',
        'martes',
        'miercoles',
        'jueves',
        'viernes',
        'sabado',
        'domingo'
      ])
        d: _horario,
    },
  );
}

ReservationModel _reserva({
  String token = 'ABCDEFGHJKMNPQRSTUVW',
  List<String> mesas = const ['m1'],
  DateTime? inicio,
  String contactoNombre = 'Carlos Secreto',
}) {
  final i = inicio ?? DateTime(2026, 10, 30, 14);
  return ReservationModel.create(
    id: '',
    restauranteId: 'r1',
    usuarioId: 'u1',
    restauranteNombre: 'Miel Test',
    contactoNombre: contactoNombre,
    contactoCorreo: 'carlos@secreto.com',
    contactoTelefono: '4181234567',
    fechaLocal:
        '${i.year}-${i.month.toString().padLeft(2, '0')}-${i.day.toString().padLeft(2, '0')}',
    inicio: i,
    duracionMin: 90,
    personas: 4,
    mesaIds: mesas,
    mesasNombres: [for (final m in mesas) m.toUpperCase()],
    estado: ReservationModel.estadoConfirmada,
    preordenItems: [
      {'platilloId': 'p1', 'nombre': 'Pasta', 'cantidad': 1, 'precio': 100.0, 'observacion': 'sin gluten'},
    ],
    alergias: const ['Nueces'],
    tokenGestion: token,
  );
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  group('HU20-RF01 token y enlace', () {
    test('el token es largo, usa solo caracteres sin ambigüedad y no se repite', () {
      final tokens = {for (var i = 0; i < 2000; i++) ReservationAccess.generarToken()};
      expect(tokens, hasLength(2000));
      for (final t in tokens.take(50)) {
        expect(t, hasLength(ReservationAccess.longitud));
        expect(RegExp(r'^[A-HJKMNP-Z2-9]+$').hasMatch(t), isTrue, reason: t);
        expect(ReservationAccess.esValido(t), isTrue);
      }
    });

    test('el código corto se agrupa y se vuelve a normalizar', () {
      const t = 'ABCDEFGHJKMNPQRSTUVW';
      final corto = ReservationAccess.formatear(t);
      expect(corto, 'ABCD-EFGH-JKMN-PQRS-TUVW');
      expect(ReservationAccess.normalizar(corto), t);
      expect(ReservationAccess.normalizar(' abcd-efgh jkmn-pqrs-tuvw '), t);
      expect(ReservationAccess.esValido('corto'), isFalse);
    });

    test('el enlace lleva el token y se puede leer de vuelta', () {
      final enlace = ReservationAccess.enlace('ABCDEFGHJKMNPQRSTUVW',
          base: 'https://miapp.test/');
      expect(enlace, 'https://miapp.test/?reserva=ABCDEFGHJKMNPQRSTUVW');
      expect(ReservationAccess.tokenDeEnlace(Uri.parse(enlace)), 'ABCDEFGHJKMNPQRSTUVW');
      expect(ReservationAccess.tokenDeEnlace(Uri.parse('https://miapp.test/')), isNull);
    });

    test('vence al terminar el día siguiente a la visita', () {
      final exp = ReservationAccess.expiracion('2026-10-30', DateTime(2026, 10, 30));
      expect(exp, DateTime(2026, 11, 1));
    });
  });

  group('HU20-RF02 regla de tiempo límite', () {
    final inicio = DateTime(2026, 10, 30, 14);
    const politica = ReservationChangePolicy();

    test('se permite hasta 2 horas antes, incluida la hora exacta', () {
      expect(politica.permite(inicio, DateTime(2026, 10, 30, 11, 59)), isTrue);
      expect(politica.permite(inicio, DateTime(2026, 10, 30, 12, 0)), isTrue);
    });

    test('pasado el límite se rechaza', () {
      expect(politica.permite(inicio, DateTime(2026, 10, 30, 12, 1)), isFalse);
      expect(politica.permite(inicio, DateTime(2026, 10, 30, 14, 30)), isFalse);
    });

    test('el mensaje explica el límite', () {
      expect(politica.mensajeFueraDeTiempo, contains('2 horas'));
      expect(const ReservationChangePolicy(limiteMin: 60).mensajeFueraDeTiempo,
          contains('1 hora'));
      expect(const ReservationChangePolicy(limiteMin: 90).mensajeFueraDeTiempo,
          contains('90 minutos'));
    });
  });

  group('HU20-RF01 documento de gestión al crear la reserva', () {
    late FakeFirebaseFirestore db;
    late ReservationService repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = ReservationService(firestore: db);
    });

    test('se crea un documento con el token que permite consultar la reserva', () async {
      final guardada = await repo.createReservationVerified(_reserva());
      final snap = await db.collection('gestionReservas').doc('ABCDEFGHJKMNPQRSTUVW').get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['reservaId'], guardada.id);
      expect(snap.data()!['estado'], 'pendiente_llegada');
    });

    test('no expone contacto, preorden ni alergias de nadie', () async {
      await repo.createReservationVerified(_reserva());
      final data = (await db.collection('gestionReservas').doc('ABCDEFGHJKMNPQRSTUVW').get()).data()!;
      final texto = data.toString();
      for (final secreto in ['Carlos Secreto', 'carlos@secreto.com', '4181234567', 'Nueces', 'sin gluten']) {
        expect(texto.contains(secreto), isFalse, reason: secreto);
      }
      for (final clave in ['contacto', 'preorden', 'alergias', 'tokenGestion']) {
        expect(data.containsKey(clave), isFalse, reason: clave);
      }
    });

    test('la reserva guarda su token y expira el día siguiente a la visita', () async {
      final guardada = await repo.createReservationVerified(_reserva());
      final res = (await repo.getReservationById(guardada.id))!;
      expect(res.tokenGestion, 'ABCDEFGHJKMNPQRSTUVW');
      final gestion = ManagedReservation.fromMap(
        res.tokenGestion,
        (await db.collection('gestionReservas').doc(res.tokenGestion).get()).data()!,
      );
      expect(gestion.expiraEn, DateTime(2026, 11, 1));
    });

    test('una reserva sin token no crea documento de gestión', () async {
      await repo.createReservationVerified(_reserva(token: ''));
      expect((await db.collection('gestionReservas').get()).docs, isEmpty);
    });

    test('el token se envía solo en el mensaje de confirmación', () async {
      final guardada = await repo.createReservationVerified(_reserva());
      final payload = ReservationNotificationPayload.fromReservation(guardada);
      expect(payload.enlaceGestion, contains('?reserva=ABCDEFGHJKMNPQRSTUVW'));
      expect(payload.codigoGestion, 'ABCD-EFGH-JKMN-PQRS-TUVW');
      // No viaja en el JSON del payload ni se guarda en otro lado.
      expect(payload.toMap().toString().contains('ABCDEFGHJKMNPQRSTUVW'), isFalse);

      final mensaje = ConfirmationNotificationService(firestore: db)
          .buildNotificationMessage(payload);
      expect(mensaje, contains('?reserva=ABCDEFGHJKMNPQRSTUVW'));
      expect(mensaje, contains('ABCD-EFGH-JKMN-PQRS-TUVW'));
      expect(mensaje, contains('2 horas'));
    });

    test('un mensaje sin token no menciona la gestión', () {
      final mensaje = ConfirmationNotificationService(firestore: db)
          .buildNotificationMessage(
              ReservationNotificationPayload.fromReservation(_reserva(token: '')));
      expect(mensaje.contains('?reserva='), isFalse);
    });

    test('al confirmar desde el borrador se genera un token distinto por reserva', () async {
      final ahora = DateTime(2026, 10, 25, 10);
      final booking = ReservationBookingService(
          AvailabilityService(repo, now: () => ahora), repo);
      Future<String> reservar(String mesa) async {
        final r = await booking.confirm(
          restaurant: _restaurant(),
          draft: ReservationDraftModel(
            restaurant: _restaurant(),
            fecha: DateTime(2026, 10, 30),
            duracionMin: 90,
            personas: 2,
            mesaIds: [mesa],
            mesasNombres: [mesa],
            horario: const TimeOfDay(hour: 14, minute: 0),
          ),
          usuarioId: 'u1',
        );
        return ((r as BookingConfirmed).reservation).tokenGestion;
      }

      final a = await reservar('m1');
      final b = await reservar('m2');
      expect(ReservationAccess.esValido(a), isTrue);
      expect(a, isNot(b));
      expect((await db.collection('gestionReservas').get()).docs, hasLength(2));
    });
  });

  group('Consultar con el código', () {
    late FakeFirebaseFirestore db;
    late ReservationService repo;
    late ReservationManagementService gestion;
    final ahora = DateTime(2026, 10, 30, 9);

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = ReservationService(firestore: db);
      gestion = ReservationManagementService(firestore: db, now: () => ahora);
      await repo.createReservationVerified(_reserva());
    });

    test('abre la reserva con el código en cualquier formato', () async {
      for (final codigo in ['ABCDEFGHJKMNPQRSTUVW', 'abcd-efgh-jkmn-pqrs-tuvw']) {
        final r = await gestion.consultar(codigo);
        expect(r.restauranteNombre, 'Miel Test');
        expect(r.mesasTexto, 'M1');
        expect(r.personas, 4);
        expect(r.inicio, DateTime(2026, 10, 30, 14));
      }
    });

    test('un código que no existe o está mal escrito se rechaza', () async {
      for (final codigo in ['ZZZZZZZZZZZZZZZZZZZZ', 'corto', '']) {
        await expectLater(
          gestion.consultar(codigo),
          throwsA(isA<ManagementException>().having(
              (e) => e.failure, 'failure', ManagementFailure.noEncontrada)),
        );
      }
    });

    test('un código vencido se rechaza', () async {
      final tarde = ReservationManagementService(
          firestore: db, now: () => DateTime(2026, 11, 1, 0, 1));
      await expectLater(
        tarde.consultar('ABCDEFGHJKMNPQRSTUVW'),
        throwsA(isA<ManagementException>()
            .having((e) => e.failure, 'failure', ManagementFailure.expirada)),
      );
    });

    test('devuelve el contacto del restaurante', () async {
      await db.collection('restaurants').doc('r1').set(
          {'nombre': 'Miel Test', 'telefono': '418-555-0101', 'direccion': 'Calle 1'});
      final c = await gestion.contactoRestaurante('r1');
      expect(c.telefono, '418-555-0101');
      expect(c.nombre, 'Miel Test');
    });
  });

  group('HU20-RF02 cancelar', () {
    late FakeFirebaseFirestore db;
    late ReservationService repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = ReservationService(firestore: db);
      await repo.createReservationVerified(_reserva());
    });

    ReservationManagementService servicio(DateTime ahora) =>
        ReservationManagementService(firestore: db, now: () => ahora);

    test('cancela, cambia el estado y libera la mesa', () async {
      final r = await servicio(DateTime(2026, 10, 30, 11)).cancelar('abcd-efgh-jkmn-pqrs-tuvw');
      expect(r.estaCancelada, isTrue);

      final reserva = (await db.collection('reservations').get()).docs.single.data();
      expect(reserva['estado'], 'cancelada');
      expect(reserva['estadoActualizadoPor'], 'visitante (enlace)');
      expect((reserva['historialEstados'] as List).single['a'], 'cancelada');
      final gestion = (await db.collection('gestionReservas').doc('ABCDEFGHJKMNPQRSTUVW').get()).data()!;
      expect(gestion['estado'], 'cancelada');

      // La mesa quedó libre para ese horario.
      await repo.createReservationVerified(_reserva(token: 'BCDEFGHJKMNPQRSTUVWX'));
    });

    test('pasado el límite se rechaza con un mensaje claro y no cambia nada', () async {
      await expectLater(
        servicio(DateTime(2026, 10, 30, 12, 30)).cancelar('ABCDEFGHJKMNPQRSTUVW'),
        throwsA(isA<ManagementException>()
            .having((e) => e.failure, 'failure', ManagementFailure.fueraDeTiempo)
            .having((e) => e.message, 'message', contains('2 horas'))),
      );
      final reserva = (await db.collection('reservations').get()).docs.single.data();
      expect(reserva['estado'], 'confirmada');
    });

    test('una reserva ya cancelada no se puede cancelar de nuevo', () async {
      final s = servicio(DateTime(2026, 10, 30, 9));
      await s.cancelar('ABCDEFGHJKMNPQRSTUVW');
      await expectLater(
        s.cancelar('ABCDEFGHJKMNPQRSTUVW'),
        throwsA(isA<ManagementException>().having(
            (e) => e.failure, 'failure', ManagementFailure.estadoNoPermitido)),
      );
    });

    test('una reserva ya atendida no se puede cancelar con el enlace', () async {
      final id = (await db.collection('reservations').get()).docs.single.id;
      await repo.changeOperationalState(
          reservationId: id, nuevoEstado: 'cliente_llego', usuarioId: 'admin');
      await db.collection('gestionReservas').doc('ABCDEFGHJKMNPQRSTUVW').update({'estado': 'cliente_llego'});
      await expectLater(
        servicio(DateTime(2026, 10, 30, 9)).cancelar('ABCDEFGHJKMNPQRSTUVW'),
        throwsA(isA<ManagementException>().having(
            (e) => e.failure, 'failure', ManagementFailure.estadoNoPermitido)),
      );
    });

    test('un código ajeno no cancela ninguna reserva', () async {
      await expectLater(
        servicio(DateTime(2026, 10, 30, 9)).cancelar('ZZZZZZZZZZZZZZZZZZZZ'),
        throwsA(isA<ManagementException>()),
      );
      expect((await db.collection('reservations').get()).docs.single.data()['estado'],
          'confirmada');
    });
  });

  group('HU20-RF02 modificar', () {
    late FakeFirebaseFirestore db;
    late ReservationService repo;
    final antes = DateTime(2026, 10, 30, 9);

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = ReservationService(firestore: db);
      await repo.createReservationVerified(_reserva());
    });

    ReservationManagementService servicio(DateTime ahora) =>
        ReservationManagementService(
          firestore: db,
          availability: AvailabilityService(repo, now: () => ahora),
          now: () => ahora,
        );

    Future<ManagedReservation> modificar(
      ReservationManagementService s, {
      DateTime? inicio,
      List<String> mesas = const ['m1'],
      int personas = 4,
    }) {
      final i = inicio ?? DateTime(2026, 10, 30, 18);
      return s.modificar(
        'ABCDEFGHJKMNPQRSTUVW',
        restaurant: _restaurant(),
        fecha: DateTime(i.year, i.month, i.day),
        inicio: i,
        duracionMin: 90,
        personas: personas,
        mesaIds: mesas,
        mesasNombres: [for (final m in mesas) m.toUpperCase()],
      );
    }

    test('cambia el horario y se refleja en la reserva y en el enlace', () async {
      final r = await modificar(servicio(antes), inicio: DateTime(2026, 10, 30, 18));
      expect(r.inicio, DateTime(2026, 10, 30, 18));

      final reserva = (await repo.getReservationById(
          (await db.collection('reservations').get()).docs.single.id))!;
      expect(reserva.inicio, DateTime(2026, 10, 30, 18));
      expect(reserva.fin, DateTime(2026, 10, 30, 19, 30));
      final consulta = await servicio(antes).consultar('ABCDEFGHJKMNPQRSTUVW');
      expect(consulta.inicio, DateTime(2026, 10, 30, 18));
    });

    test('libera el horario anterior y ocupa el nuevo', () async {
      await modificar(servicio(antes), inicio: DateTime(2026, 10, 30, 18));
      // El horario anterior (14:00) quedó libre...
      await repo.createReservationVerified(_reserva(token: 'BCDEFGHJKMNPQRSTUVWX'));
      // ...y el nuevo (18:00) está ocupado.
      await expectLater(
        repo.createReservationVerified(
            _reserva(token: 'CDEFGHJKMNPQRSTUVWXY', inicio: DateTime(2026, 10, 30, 18, 30))),
        throwsA(isA<ReservationConflictException>()),
      );
    });

    test('puede cambiar de día y de mesa', () async {
      await modificar(servicio(antes),
          inicio: DateTime(2026, 10, 31, 15), mesas: const ['m2'], personas: 2);
      final reserva = (await db.collection('reservations').get()).docs.single.data();
      expect(reserva['fechaLocal'], '2026-10-31');
      expect(reserva['mesaIds'], ['m2']);
      expect(reserva['personas'], 2);
      await repo.createReservationVerified(_reserva(token: 'BCDEFGHJKMNPQRSTUVWX')); // m1 libre
    });

    test('modificar a un horario ocupado se rechaza y deja todo como estaba', () async {
      await repo.createReservationVerified(
          _reserva(token: 'BCDEFGHJKMNPQRSTUVWX', inicio: DateTime(2026, 10, 30, 18)));
      await expectLater(
        modificar(servicio(antes), inicio: DateTime(2026, 10, 30, 18, 30)),
        throwsA(isA<ManagementException>().having(
            (e) => e.failure, 'failure', ManagementFailure.disponibilidad)),
      );
      final reserva = (await repo.getReservationById(
          (await db.collection('reservations').where('tokenGestion', isEqualTo: 'ABCDEFGHJKMNPQRSTUVW').get())
              .docs.single.id))!;
      expect(reserva.inicio, DateTime(2026, 10, 30, 14));
    });

    test('la propia reserva no cuenta como ocupada al moverla un poco', () async {
      final r = await modificar(servicio(antes), inicio: DateTime(2026, 10, 30, 14, 30));
      expect(r.inicio, DateTime(2026, 10, 30, 14, 30));
    });

    test('pasado el límite no se puede modificar', () async {
      await expectLater(
        modificar(servicio(DateTime(2026, 10, 30, 12, 30))),
        throwsA(isA<ManagementException>().having(
            (e) => e.failure, 'failure', ManagementFailure.fueraDeTiempo)),
      );
    });

    test('datos incompletos se rechazan', () async {
      await expectLater(
        modificar(servicio(antes), personas: 0),
        throwsA(isA<ManagementException>().having(
            (e) => e.failure, 'failure', ManagementFailure.datosInvalidos)),
      );
    });

    test('el nuevo horario se valida contra el horario de atención', () async {
      await expectLater(
        modificar(servicio(antes), inicio: DateTime(2026, 10, 30, 21)),
        throwsA(isA<ManagementException>().having(
            (e) => e.failure, 'failure', ManagementFailure.disponibilidad)),
      );
    });
  });
}
