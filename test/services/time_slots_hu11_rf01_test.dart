import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/availability_service.dart';

class _FakeReservations implements ReservationRepository {
  final List<ReservationModel> data;
  _FakeReservations(this.data);

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async => data
      .where(
        (r) =>
            r.restauranteId == restauranteId &&
            r.fechaLocal == fechaLocal &&
            r.bloqueaMesas,
      )
      .toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RestaurantModel _restaurant({
  DaySchedule? horario,
  List<MesaModel> mesas = const [],
}) {
  final h =
      horario ??
      const DaySchedule(abierto: true, apertura: '12:00', cierre: '16:00');
  return RestaurantModel(
    id: 'r1',
    nombre: 'Test',
    estado: 'activo',
    mesas: mesas,
    horarios: {
      for (final d in [
        'lunes',
        'martes',
        'miercoles',
        'jueves',
        'viernes',
        'sabado',
        'domingo',
      ])
        d: h,
    },
  );
}

MesaModel _mesa(
  String id,
  int cap, {
  bool combinable = false,
  List<String> con = const [],
}) => MesaModel(
  id: id,
  nombre: id,
  capacidad: cap,
  combinable: combinable,
  combinableCon: con,
  x: 0,
  y: 0,
);

ReservationModel _res(
  DateTime inicio,
  List<String> mesas, {
  int duracion = 90,
  String estado = ReservationModel.estadoConfirmada,
}) {
  final f =
      '${inicio.year.toString().padLeft(4, '0')}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}';
  return ReservationModel.create(
    id: 'r${inicio.microsecondsSinceEpoch}${mesas.join()}',
    restauranteId: 'r1',
    fechaLocal: f,
    inicio: inicio,
    duracionMin: duracion,
    mesaIds: mesas,
    estado: estado,
  );
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

void main() {
  // Domingo 25 de octubre de 2026; se consulta el viernes 30.
  final now = DateTime(2026, 10, 25, 10);
  final viernes = DateTime(2026, 10, 30);

  AvailabilityService build([List<ReservationModel> data = const []]) =>
      AvailabilityService(_FakeReservations(data), now: () => now);

  group('HU11-RF01 horarios disponibles', () {
    test('genera inicios cada 30 minutos y termina antes del cierre', () async {
      final slots = await build().getAvailableTimeSlots(
        restaurant: _restaurant(),
        fecha: viernes,
        duracionMin: 90,
        mesaIds: ['m1'],
      );
      expect(slots.map((s) => _hhmm(s.inicio)), [
        '12:00',
        '12:30',
        '13:00',
        '13:30',
        '14:00',
        '14:30',
      ]);
      expect(_hhmm(slots.last.fin), '16:00');
    });

    test('respeta el intervalo configurado', () async {
      final slots = await build().getAvailableTimeSlots(
        restaurant: _restaurant(),
        fecha: viernes,
        duracionMin: 120,
        mesaIds: ['m1'],
        intervaloMin: 60,
      );
      expect(slots.map((s) => _hhmm(s.inicio)), ['12:00', '13:00', '14:00']);
    });

    test(
      'una duración que no cabe antes del cierre no devuelve horarios',
      () async {
        final slots = await build().getAvailableTimeSlots(
          restaurant: _restaurant(),
          fecha: viernes,
          duracionMin: 300,
          mesaIds: ['m1'],
        );
        expect(slots, isEmpty);
      },
    );

    test('excluye los horarios que se traslapan con otra reserva de la mesa', () async {
      final slots =
          await build([
            _res(DateTime(2026, 10, 30, 13), ['m1']),
          ]).getAvailableTimeSlots(
            restaurant: _restaurant(),
            fecha: viernes,
            duracionMin: 90,
            mesaIds: ['m1'],
          );
      // La reserva ocupa 13:00-14:30: solo el inicio de las 14:30 queda libre.
      expect(slots.map((s) => _hhmm(s.inicio)), ['14:30']);
    });

    test('reservas de otras mesas no afectan', () async {
      final slots =
          await build([
            _res(DateTime(2026, 10, 30, 13), ['m2']),
          ]).getAvailableTimeSlots(
            restaurant: _restaurant(),
            fecha: viernes,
            duracionMin: 90,
            mesaIds: ['m1'],
          );
      expect(slots, hasLength(6));
    });

    test('con una combinación basta que choque alguna de las mesas', () async {
      final slots =
          await build([
            _res(DateTime(2026, 10, 30, 13), ['m2']),
          ]).getAvailableTimeSlots(
            restaurant: _restaurant(),
            fecha: viernes,
            duracionMin: 90,
            mesaIds: ['m1', 'm2'],
          );
      expect(slots.map((s) => _hhmm(s.inicio)), ['14:30']);
    });

    test('las reservaciones canceladas no bloquean', () async {
      final slots =
          await build([
            _res(DateTime(2026, 10, 30, 13), [
              'm1',
            ], estado: ReservationModel.estadoCancelada),
          ]).getAvailableTimeSlots(
            restaurant: _restaurant(),
            fecha: viernes,
            duracionMin: 90,
            mesaIds: ['m1'],
          );
      expect(slots, hasLength(6));
    });

    test('para hoy no devuelve horarios que ya pasaron', () async {
      final hoy = AvailabilityService(
        _FakeReservations(const []),
        now: () => DateTime(2026, 10, 30, 13, 10),
      );
      final slots = await hoy.getAvailableTimeSlots(
        restaurant: _restaurant(),
        fecha: viernes,
        duracionMin: 60,
        mesaIds: ['m1'],
      );
      expect(slots.first.inicio, DateTime(2026, 10, 30, 13, 30));
    });

    test('si no hay horarios devuelve una lista vacía', () async {
      final slots =
          await build([
            _res(DateTime(2026, 10, 30, 12), ['m1'], duracion: 240),
          ]).getAvailableTimeSlots(
            restaurant: _restaurant(),
            fecha: viernes,
            duracionMin: 60,
            mesaIds: ['m1'],
          );
      expect(slots, isEmpty);
    });

    test('un día cerrado o fecha pasada devuelve una lista vacía', () async {
      final cerrado = _restaurant(
        horario: const DaySchedule(
          abierto: false,
          apertura: '12:00',
          cierre: '16:00',
        ),
      );
      expect(
        await build().getAvailableTimeSlots(
          restaurant: cerrado,
          fecha: viernes,
          duracionMin: 60,
          mesaIds: ['m1'],
        ),
        isEmpty,
      );
      expect(
        await build().getAvailableTimeSlots(
          restaurant: _restaurant(),
          fecha: DateTime(2026, 10, 1),
          duracionMin: 60,
          mesaIds: ['m1'],
        ),
        isEmpty,
      );
    });

    test('horario nocturno: los inicios pasan de medianoche', () async {
      final noche = _restaurant(
        horario: const DaySchedule(
          abierto: true,
          apertura: '22:00',
          cierre: '02:00',
        ),
      );
      final slots = await build().getAvailableTimeSlots(
        restaurant: noche,
        fecha: viernes,
        duracionMin: 120,
        mesaIds: ['m1'],
      );
      expect(slots.map((s) => _hhmm(s.inicio)), [
        '22:00',
        '22:30',
        '23:00',
        '23:30',
        '00:00',
      ]);
      expect(slots.last.inicio.day, 31);
    });

    test(
      'una reserva de la madrugada siguiente bloquea el último turno',
      () async {
        final noche = _restaurant(
          horario: const DaySchedule(
            abierto: true,
            apertura: '22:00',
            cierre: '02:00',
          ),
        );
        final slots =
            await build([
              _res(DateTime(2026, 10, 31, 0, 30), ['m1'], duracion: 60),
            ]).getAvailableTimeSlots(
              restaurant: noche,
              fecha: viernes,
              duracionMin: 120,
              mesaIds: ['m1'],
            );
        expect(slots.map((s) => _hhmm(s.inicio)), ['22:00', '22:30']);
      },
    );

    test('el margen de limpieza se respeta entre reservas', () async {
      final svc = AvailabilityService(
        _FakeReservations([
          _res(DateTime(2026, 10, 30, 12), ['m1']),
        ]),
        now: () => now,
        margenLimpiezaMin: 30,
      );
      final slots = await svc.getAvailableTimeSlots(
        restaurant: _restaurant(),
        fecha: viernes,
        duracionMin: 60,
        mesaIds: ['m1'],
      );
      // La reserva ocupa 12:00-13:30 más 30 min de limpieza.
      expect(_hhmm(slots.first.inicio), '14:00');
    });
  });

  group('Consultas por día (antes de elegir la hora)', () {
    final mesas = [
      _mesa('m1', 2, combinable: true, con: ['m2']),
      _mesa('m2', 2, combinable: true, con: ['m1']),
      _mesa('m3', 6),
    ];

    test(
      'findSuitableTablesForDate ofrece mesas con algún horario libre',
      () async {
        final r = await build().findSuitableTablesForDate(
          restaurant: _restaurant(mesas: mesas),
          fecha: viernes,
          personas: 5,
        );
        expect(r.mesas.map((o) => o.mesa.id), ['m3']);
      },
    );

    test('descarta una mesa sin horarios libres ese día', () async {
      final r =
          await build([
            _res(DateTime(2026, 10, 30, 12), ['m3'], duracion: 240),
          ]).findSuitableTablesForDate(
            restaurant: _restaurant(mesas: mesas),
            fecha: viernes,
            personas: 5,
          );
      expect(r.mesas, isEmpty);
      expect(r.reason, AvailabilityFailure.sinDisponibilidad);
    });

    test(
      'si ninguna alcanza propone combinaciones con horario común',
      () async {
        final r = await build().findSuitableTablesForDate(
          restaurant: _restaurant(mesas: mesas.take(2).toList()),
          fecha: viernes,
          personas: 4,
        );
        expect(r.mesas, isEmpty);
        expect(r.combinaciones.single.mesaIds, ['m1', 'm2']);
      },
    );

    test('descarta la combinación si las mesas no coinciden libres', () async {
      final r =
          await build([
            _res(DateTime(2026, 10, 30, 12), ['m1'], duracion: 120),
            _res(DateTime(2026, 10, 30, 14), ['m2'], duracion: 120),
          ]).findSuitableTablesForDate(
            restaurant: _restaurant(mesas: mesas.take(2).toList()),
            fecha: viernes,
            personas: 4,
            duracionMin: 120,
          );
      expect(r.combinaciones, isEmpty);
    });

    test('una fecha no reservable devuelve el motivo', () async {
      final r = await build().findSuitableTablesForDate(
        restaurant: _restaurant(mesas: mesas),
        fecha: DateTime(2026, 10, 1),
        personas: 2,
      );
      expect(r.reason, AvailabilityFailure.fechaPasada);
    });

    test(
      'getFloorPlanForDate marca ocupada la mesa sin horarios libres',
      () async {
        final plan =
            await build([
              _res(DateTime(2026, 10, 30, 12), ['m3'], duracion: 240),
            ]).getFloorPlanForDate(
              restaurant: _restaurant(mesas: mesas),
              fecha: viernes,
            );
        expect(
          {for (final p in plan.mesas) p.mesa.id: p.estado},
          {
            'm1': MesaEstado.disponible,
            'm2': MesaEstado.disponible,
            'm3': MesaEstado.ocupada,
          },
        );
      },
    );

    test('una mesa con un horario libre sigue disponible', () async {
      final plan =
          await build([
            _res(DateTime(2026, 10, 30, 12), ['m3'], duracion: 90),
          ]).getFloorPlanForDate(
            restaurant: _restaurant(mesas: mesas),
            fecha: viernes,
          );
      expect(
        plan.mesas.firstWhere((p) => p.mesa.id == 'm3').estado,
        MesaEstado.disponible,
      );
    });

    test(
      'getFloorPlanForDate con fecha cerrada devuelve noDisponible',
      () async {
        final plan = await build().getFloorPlanForDate(
          restaurant: _restaurant(mesas: mesas),
          fecha: DateTime(2026, 10, 1),
        );
        expect(plan.reason, AvailabilityFailure.fechaPasada);
        expect(
          plan.mesas.every((p) => p.estado == MesaEstado.noDisponible),
          isTrue,
        );
      },
    );

    test(
      'getFloorPlanForDate sin mesas posicionadas es plano no configurado',
      () async {
        final plan = await build().getFloorPlanForDate(
          restaurant: _restaurant(),
          fecha: viernes,
        );
        expect(plan.configurado, isFalse);
      },
    );
  });
}
