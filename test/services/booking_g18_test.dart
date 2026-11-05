import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/reservation_service.dart';

const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

RestaurantModel _restaurant({DaySchedule horario = _horario, bool abierto = true}) {
  return RestaurantModel(
    id: 'r1',
    nombre: 'Miel Test',
    estado: 'activo',
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
        d: abierto
            ? horario
            : DaySchedule(
                abierto: false,
                apertura: horario.apertura,
                cierre: horario.cierre,
              ),
    },
  );
}

ReservationModel _reserva(
  DateTime inicio, {
  List<String> mesas = const ['m1'],
  int duracion = 90,
  String usuario = 'u1',
  String? fechaLocal,
  String id = '',
}) {
  final f = fechaLocal ??
      '${inicio.year.toString().padLeft(4, '0')}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}';
  return ReservationModel.create(
    id: id,
    restauranteId: 'r1',
    usuarioId: usuario,
    fechaLocal: f,
    inicio: inicio,
    duracionMin: duracion,
    mesaIds: mesas,
    mesasNombres: [for (final m in mesas) m.toUpperCase()],
    estado: ReservationModel.estadoConfirmada,
  );
}

class _ScriptedRepo extends ReservationService {
  final Object? failWith;
  int calls = 0;

  _ScriptedRepo(FakeFirebaseFirestore db, {this.failWith}) : super(firestore: db);

  @override
  Future<ReservationModel> createReservationVerified(
    ReservationModel reservation, {
    int margenLimpiezaMin = 0,
  }) async {
    calls++;
    if (failWith != null) throw failWith!;
    return super.createReservationVerified(
      reservation,
      margenLimpiezaMin: margenLimpiezaMin,
    );
  }
}

void main() {
  // Domingo 25 de octubre de 2026; se reserva el viernes 30.
  final now = DateTime(2026, 10, 25, 10);
  final viernes = DateTime(2026, 10, 30);
  DateTime a(int h, [int m = 0]) => DateTime(2026, 10, 30, h, m);

  late FakeFirebaseFirestore db;
  late ReservationService repo;

  Future<int> reservasGuardadas() async =>
      (await db.collection('reservations').get()).docs.length;

  Future<List<OccupancyInterval>> ocupacion(String mesa, String fecha) async {
    final snap = await db
        .collection('restaurants')
        .doc('r1')
        .collection('ocupacionMesas')
        .doc(OccupancyInterval.docId(mesa, fecha))
        .get();
    return OccupancyInterval.listFromData(snap.data());
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ReservationService(firestore: db);
  });

  group('HU11-RF04 creación transaccional', () {
    test('guarda la reserva asociada al usuario y su ocupación por mesa',
        () async {
      final guardada = await repo.createReservationVerified(
        _reserva(a(14), mesas: ['m1', 'm2'], usuario: 'user_42'),
      );

      expect(guardada.id, isNotEmpty);
      final doc = await db.collection('reservations').doc(guardada.id).get();
      expect(doc.data()!['usuarioId'], 'user_42');
      expect(doc.data()!['estado'], ReservationModel.estadoConfirmada);
      expect(doc.data()!['mesaIds'], ['m1', 'm2']);

      for (final mesa in ['m1', 'm2']) {
        final intervalos = await ocupacion(mesa, '2026-10-30');
        expect(intervalos, hasLength(1));
        expect(intervalos.single.reservaId, guardada.id);
        expect(intervalos.single.inicioMin, 14 * 60);
        expect(intervalos.single.finMin, 14 * 60 + 90);
      }
    });

    test('rechaza la reserva si la mesa ya fue reservada por otra persona',
        () async {
      await repo.createReservationVerified(_reserva(a(14), usuario: 'u1'));

      await expectLater(
        repo.createReservationVerified(_reserva(a(15), usuario: 'u2')),
        throwsA(isA<ReservationConflictException>()
            .having((e) => e.mesaIds, 'mesaIds', {'m1'})),
      );
      expect(await reservasGuardadas(), 1);
      expect(await ocupacion('m1', '2026-10-30'), hasLength(1));
    });

    test('una reserva que empieza justo cuando termina otra es válida',
        () async {
      await repo.createReservationVerified(_reserva(a(14)));
      await repo.createReservationVerified(_reserva(a(15, 30)));
      expect(await reservasGuardadas(), 2);
    });

    test('mesas distintas no se bloquean entre sí', () async {
      await repo.createReservationVerified(_reserva(a(14), mesas: ['m1']));
      await repo.createReservationVerified(_reserva(a(14), mesas: ['m2']));
      expect(await reservasGuardadas(), 2);
    });

    test('una combinación se rechaza completa si alguna mesa está ocupada',
        () async {
      await repo.createReservationVerified(_reserva(a(14), mesas: ['m2']));

      await expectLater(
        repo.createReservationVerified(
          _reserva(a(14), mesas: ['m1', 'm2'], usuario: 'u2'),
        ),
        throwsA(isA<ReservationConflictException>()
            .having((e) => e.mesaIds, 'mesaIds', {'m2'})),
      );
      // No queda una reserva a medias: m1 sigue libre y solo existe la primera.
      expect(await reservasGuardadas(), 1);
      expect(await ocupacion('m1', '2026-10-30'), isEmpty);
    });

    test('una reserva nocturna bloquea el inicio del día siguiente', () async {
      await repo.createReservationVerified(
        _reserva(a(23), duracion: 120),
      ); // 23:00 a 01:00
      final siguiente = DateTime(2026, 10, 31, 0, 30);
      await expectLater(
        repo.createReservationVerified(
          _reserva(siguiente, duracion: 60, fechaLocal: '2026-10-31'),
        ),
        throwsA(isA<ReservationConflictException>()),
      );
    });

    test('el margen de limpieza cuenta como tiempo ocupado', () async {
      await repo.createReservationVerified(_reserva(a(14)));
      await expectLater(
        repo.createReservationVerified(
          _reserva(a(15, 30)),
          margenLimpiezaMin: 15,
        ),
        throwsA(isA<ReservationConflictException>()),
      );
    });

    test('cancelar libera la mesa para volver a reservarla', () async {
      final primera = await repo.createReservationVerified(_reserva(a(14)));
      await repo.cancelReservation(primera.id);

      final doc = await db.collection('reservations').doc(primera.id).get();
      expect(doc.data()!['estado'], ReservationModel.estadoCancelada);
      expect(await ocupacion('m1', '2026-10-30'), isEmpty);

      await repo.createReservationVerified(_reserva(a(14), usuario: 'u2'));
      expect(await reservasGuardadas(), 2);
    });

    test('cancelar una reserva antigua sin ocupación registrada funciona',
        () async {
      final ref = await db.collection('reservations').add(
            _reserva(a(14)).toMap()..['usuarioId'] = 'legacy',
          );
      await repo.cancelReservation(ref.id);
      final doc = await ref.get();
      expect(doc.data()!['estado'], ReservationModel.estadoCancelada);
    });

    test('exige restaurante, mesas y hora de inicio', () async {
      await expectLater(
        repo.createReservationVerified(_reserva(a(14), mesas: const [])),
        throwsArgumentError,
      );
      await expectLater(
        repo.createReservationVerified(
          ReservationModel.create(
            id: '',
            restauranteId: 'r1',
            fechaLocal: '2026-10-30',
            mesaIds: const ['m1'],
          ),
        ),
        throwsArgumentError,
      );
      expect(await reservasGuardadas(), 0);
    });

    test('OccupancyInterval: terminar justo al empezar otra no se traslapa', () {
      const i = OccupancyInterval(reservaId: 'x', inicioMin: 600, finMin: 690);
      expect(i.overlaps(690, 780), isFalse);
      expect(i.overlaps(680, 780), isTrue);
      expect(i.overlaps(690, 780, margenMin: 10), isTrue);
      expect(i.overlaps(500, 600), isFalse);
    });
  });

  group('HU12-RF02 revalidación de la selección', () {
    AvailabilityService svc() => AvailabilityService(repo, now: () => now);

    test('una selección libre sigue siendo válida', () async {
      final v = await svc().revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(14),
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      expect(v.isValid, isTrue);
      expect(v.message, isNull);
    });

    test('no bloquea ni guarda nada', () async {
      await svc().revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(14),
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      expect(await reservasGuardadas(), 0);
      expect(await ocupacion('m1', '2026-10-30'), isEmpty);
    });

    test('si otra persona reservó la mesa, informa y manda a elegir horario',
        () async {
      await repo.createReservationVerified(_reserva(a(14), usuario: 'otro'));
      final v = await svc().revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(14, 30),
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      expect(v.isValid, isFalse);
      expect(v.issue, SelectionIssue.mesaOcupada);
      expect(v.mesasEnConflicto, {'m1'});
      expect(v.redirectStep, 5);
      expect(v.message, contains('Elige otro horario'));
    });

    test('ofrece alternativas ordenadas de la más cercana a la más lejana',
        () async {
      await repo.createReservationVerified(_reserva(a(14), usuario: 'otro'));
      final v = await svc().revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(14, 30),
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      final distancias = v.alternativas
          .map((s) => s.inicio.difference(a(14, 30)).inMinutes.abs())
          .toList();
      expect([...distancias]..sort(), distancias);
      expect(v.alternativas.length, lessThanOrEqualTo(4));
      expect(v.alternativas, isNotEmpty);
    });

    test('si a la mesa no le queda ningún horario, manda a elegir otra mesa',
        () async {
      await repo.createReservationVerified(
        _reserva(a(12), duracion: 600, usuario: 'otro'),
      ); // 12:00 a 22:00
      final v = await svc().revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(14),
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      expect(v.issue, SelectionIssue.mesaOcupada);
      expect(v.alternativas, isEmpty);
      expect(v.redirectStep, 4);
      expect(v.message, contains('Elige otra mesa'));
    });

    test('con una combinación basta que una mesa esté ocupada', () async {
      await repo.createReservationVerified(
        _reserva(a(14), mesas: ['m2'], usuario: 'otro'),
      );
      final v = await svc().revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(14),
        duracionMin: 90,
        mesaIds: ['m1', 'm2'],
      );
      expect(v.mesasEnConflicto, {'m2'});
    });

    test('las reservas canceladas no invalidan la selección', () async {
      final r = await repo.createReservationVerified(_reserva(a(14)));
      await repo.cancelReservation(r.id);
      final v = await svc().revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(14),
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      expect(v.isValid, isTrue);
    });

    test('un horario que ya pasó vuelve al paso de horario', () async {
      final v = await AvailabilityService(
        repo,
        now: () => DateTime(2026, 10, 30, 15),
      ).revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(14),
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      expect(v.issue, SelectionIssue.horarioPasado);
      expect(v.redirectStep, 5);
    });

    test('una fecha que dejó de ser válida vuelve al paso de fecha', () async {
      final v = await svc().revalidateSelection(
        restaurant: _restaurant(abierto: false),
        inicio: a(14),
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      expect(v.issue, SelectionIssue.fechaInvalida);
      expect(v.redirectStep, 1);
      expect(v.message, isNotEmpty);
    });

    test('un horario fuera de atención vuelve al paso de horario', () async {
      final v = await svc().revalidateSelection(
        restaurant: _restaurant(),
        inicio: a(21),
        duracionMin: 120,
        mesaIds: ['m1'],
      );
      expect(v.issue, SelectionIssue.fueraDeHorario);
      expect(v.redirectStep, 5);
    });
  });

  group('HU11-RF04 confirmación desde el borrador', () {
    ReservationDraftModel draft({
      List<String> mesas = const ['m1'],
      TimeOfDay? horario = const TimeOfDay(hour: 14, minute: 0),
    }) {
      return ReservationDraftModel(
        restaurant: _restaurant(),
        fecha: viernes,
        duracionMin: 90,
        personas: 4,
        mesaIds: mesas,
        mesasNombres: [for (final m in mesas) m.toUpperCase()],
        horario: horario,
      );
    }

    ReservationBookingService booking(ReservationService r) =>
        ReservationBookingService(
          AvailabilityService(r, now: () => now),
          r,
        );

    test('guarda la reserva y la asocia al usuario autenticado', () async {
      final result = await booking(repo).confirm(
        restaurant: _restaurant(),
        draft: draft(),
        usuarioId: 'user_42',
        contactoNombre: 'Mirza',
        contactoCorreo: 'm@test.com',
      );
      final ok = result as BookingConfirmed;
      expect(ok.reservation.usuarioId, 'user_42');
      expect(ok.reservation.estado, ReservationModel.estadoConfirmada);
      expect(ok.reservation.fechaLocal, '2026-10-30');
      expect(ok.reservation.personas, 4);
      expect(ok.reservation.mesaIds, ['m1']);
      expect(ok.reservation.effectiveStart, a(14));
      expect(ok.reservation.effectiveEnd, a(15, 30));
      expect(ok.reservation.restauranteNombre, 'Miel Test');
      expect(ok.reservation.contactoCorreo, 'm@test.com');
      expect(await reservasGuardadas(), 1);
    });

    test('sin sesión no se guarda nada', () async {
      final result = await booking(repo).confirm(
        restaurant: _restaurant(),
        draft: draft(),
        usuarioId: '',
      );
      expect(result, isA<BookingFailed>());
      expect(await reservasGuardadas(), 0);
    });

    test('con el borrador incompleto no se guarda nada', () async {
      final result = await booking(repo).confirm(
        restaurant: _restaurant(),
        draft: draft(horario: null),
        usuarioId: 'u1',
      );
      expect(result, isA<BookingFailed>());
      expect(await reservasGuardadas(), 0);
    });

    test('si la selección ya no es válida se rechaza antes de guardar',
        () async {
      await repo.createReservationVerified(_reserva(a(14), usuario: 'otro'));
      final result = await booking(repo).confirm(
        restaurant: _restaurant(),
        draft: draft(),
        usuarioId: 'u2',
      );
      final rejected = result as BookingRejected;
      expect(rejected.validation.issue, SelectionIssue.mesaOcupada);
      expect(await reservasGuardadas(), 1);
    });

    test('si otra persona gana la carrera, ofrece horarios alternativos',
        () async {
      // La revalidación pasa, pero la transacción detecta el conflicto.
      final alVuelo = _ScriptedRepo(
        db,
        failWith: const ReservationConflictException({'m1'}),
      );
      final result = await booking(alVuelo).confirm(
        restaurant: _restaurant(),
        draft: draft(),
        usuarioId: 'u2',
      );
      final conflict = result as BookingConflict;
      expect(conflict.message, contains('M1'));
      expect(conflict.message, contains('otra persona'));
      expect(conflict.mesasEnConflicto, {'m1'});
      expect(conflict.alternativas, isNotEmpty);
      expect(await reservasGuardadas(), 0);
    });

    test('si falla la conexión informa y no queda una reserva a medias',
        () async {
      final sinRed = _ScriptedRepo(
        db,
        failWith: const ReservationConnectionException('unavailable'),
      );
      final result = await booking(sinRed).confirm(
        restaurant: _restaurant(),
        draft: draft(),
        usuarioId: 'u1',
      );
      final failed = result as BookingFailed;
      expect(failed.retryable, isTrue);
      expect(failed.message, contains('conexión'));
      expect(failed.message, contains('No se guardó ninguna reserva'));
      expect(await reservasGuardadas(), 0);
      expect(await ocupacion('m1', '2026-10-30'), isEmpty);
    });

    test('un error inesperado se informa y se puede reintentar', () async {
      final raro = _ScriptedRepo(db, failWith: StateError('boom'));
      final result = await booking(raro).confirm(
        restaurant: _restaurant(),
        draft: draft(),
        usuarioId: 'u1',
      );
      expect((result as BookingFailed).retryable, isTrue);
      expect(await reservasGuardadas(), 0);
    });

    test('el borrador calcula el inicio del día siguiente en turnos nocturnos',
        () {
      final noche = ReservationDraftModel(
        restaurant: _restaurant(
          horario: const DaySchedule(
            abierto: true,
            apertura: '22:00',
            cierre: '02:00',
          ),
        ),
        fecha: viernes,
        horario: const TimeOfDay(hour: 0, minute: 30),
      );
      expect(noche.inicio, DateTime(2026, 10, 31, 0, 30));

      final antes = ReservationDraftModel(
        restaurant: noche.restaurant,
        fecha: viernes,
        horario: const TimeOfDay(hour: 23, minute: 0),
      );
      expect(antes.inicio, DateTime(2026, 10, 30, 23, 0));
    });
  });
}
