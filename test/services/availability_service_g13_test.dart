import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/availability_service.dart';

/// Repositorio en memoria: solo implementa la consulta que usa el motor.
class _FakeReservations implements ReservationRepository {
  final List<ReservationModel> data;
  _FakeReservations(this.data);

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async =>
      data
          .where((r) =>
              r.restauranteId == restauranteId &&
              r.fechaLocal == fechaLocal &&
              r.bloqueaMesas)
          .toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _abierto = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

RestaurantModel _restaurant({
  String estado = 'activo',
  Map<String, DaySchedule>? horarios,
  List<String> diasAbiertos = const [],
  List<String> cierres = const [],
  List<MesaModel> mesas = const [],
  int? capacidadMaxima,
}) {
  return RestaurantModel(
    id: 'r1',
    nombre: 'Test',
    estado: estado,
    diasAbiertos: diasAbiertos,
    cierresEspeciales: cierres,
    capacidadMaxima: capacidadMaxima,
    mesas: mesas,
    horarios: horarios ??
        {
          for (final d in [
            'lunes',
            'martes',
            'miercoles',
            'jueves',
            'viernes',
            'sabado',
            'domingo'
          ])
            d: _abierto,
        },
  );
}

MesaModel _mesa(String id, int capacidad) => MesaModel(
      id: id,
      nombre: id,
      capacidad: capacidad,
      combinable: false,
      combinableCon: const [],
    );

ReservationModel _res(
  String id,
  DateTime inicio, {
  int duracion = 90,
  List<String> mesas = const ['m1'],
  String estado = ReservationModel.estadoConfirmada,
  int personas = 2,
}) {
  return ReservationModel.create(
    id: id,
    restauranteId: 'r1',
    fechaLocal:
        '${inicio.year.toString().padLeft(4, '0')}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}',
    inicio: inicio,
    duracionMin: duracion,
    mesaIds: mesas,
    estado: estado,
    personas: personas,
  );
}

void main() {
  // Miércoles 14 de octubre de 2026, 10:00.
  final now = DateTime(2026, 10, 14, 10);
  final viernes = DateTime(2026, 10, 16);

  AvailabilityService build(List<ReservationModel> existing) =>
      AvailabilityService(_FakeReservations(existing), now: () => now);

  group('HU07-RF03 validateDate', () {
    test('acepta un día abierto', () {
      final r = build([]).validateDate(restaurant: _restaurant(), fecha: viernes);
      expect(r.isValid, isTrue);
    });

    test('acepta la fecha de hoy', () {
      final r = build([]).validateDate(restaurant: _restaurant(), fecha: now);
      expect(r.isValid, isTrue);
    });

    test('rechaza una fecha pasada', () {
      final r = build([]).validateDate(
        restaurant: _restaurant(),
        fecha: DateTime(2026, 10, 13),
      );
      expect(r.reason, AvailabilityFailure.fechaPasada);
    });

    test('rechaza un día de cierre especial', () {
      final r = build([]).validateDate(
        restaurant: _restaurant(cierres: ['2026-10-16']),
        fecha: viernes,
      );
      expect(r.reason, AvailabilityFailure.cierreEspecial);
    });

    test('rechaza un día que no está en diasAbiertos', () {
      final r = build([]).validateDate(
        restaurant: _restaurant(diasAbiertos: ['lunes', 'martes']),
        fecha: viernes,
      );
      expect(r.reason, AvailabilityFailure.diaCerrado);
    });

    test('rechaza un día marcado como cerrado en horarios', () {
      final r = build([]).validateDate(
        restaurant: _restaurant(horarios: {
          'viernes': const DaySchedule(
              abierto: false, apertura: '12:00', cierre: '22:00'),
        }),
        fecha: viernes,
      );
      expect(r.reason, AvailabilityFailure.diaCerrado);
    });

    test('rechaza un día sin horario guardado', () {
      final r = build([]).validateDate(
        restaurant: _restaurant(horarios: {'lunes': _abierto}),
        fecha: viernes,
      );
      expect(r.reason, AvailabilityFailure.diaCerrado);
    });

    test('rechaza un restaurante inactivo', () {
      final r = build([]).validateDate(
        restaurant: _restaurant(estado: 'inactivo'),
        fecha: viernes,
      );
      expect(r.reason, AvailabilityFailure.restauranteInactivo);
    });

    test('reconoce días con acento en diasAbiertos', () {
      final r = build([]).validateDate(
        restaurant: _restaurant(diasAbiertos: ['miércoles', 'viernes']),
        fecha: viernes,
      );
      expect(r.isValid, isTrue);
    });

    test('devuelve mensaje para cada motivo y ninguno si es válida', () {
      expect(const DateValidationResult.valid().message, isNull);
      for (final reason in AvailabilityFailure.values) {
        expect(DateValidationResult.invalid(reason).message, isNotEmpty);
      }
    });
  });

  group('HU07-RF03 anticipación y horarios de hoy', () {
    test('rechaza una fecha más allá del límite de anticipación', () {
      final r = AvailabilityService(_FakeReservations([]),
              now: () => now, maxAnticipacionDias: 30)
          .validateDate(
        restaurant: _restaurant(),
        fecha: DateTime(2026, 12, 1),
      );
      expect(r.reason, AvailabilityFailure.fechaMuyLejana);
    });

    test('acepta la fecha exactamente en el límite', () {
      final r = AvailabilityService(_FakeReservations([]),
              now: () => now, maxAnticipacionDias: 30)
          .validateDate(
        restaurant: _restaurant(),
        fecha: DateTime(2026, 11, 13),
      );
      expect(r.isValid, isTrue);
    });

    test('hoy ya cerrado no es válido', () {
      final tarde = AvailabilityService(_FakeReservations([]),
          now: () => DateTime(2026, 10, 14, 22, 30));
      final r = tarde.validateDate(restaurant: _restaurant(), fecha: now);
      expect(r.reason, AvailabilityFailure.sinHorariosHoy);
    });

    test('hoy con horario nocturno que cierra de madrugada sigue válido', () {
      final noche = _restaurant(horarios: {
        'miercoles': const DaySchedule(
            abierto: true, apertura: '18:00', cierre: '02:00'),
      });
      final tarde = AvailabilityService(_FakeReservations([]),
          now: () => DateTime(2026, 10, 14, 23));
      expect(tarde.validateDate(restaurant: noche, fecha: now).isValid, isTrue);
    });
  });

  group('HU08-RF03 intervalsOverlap', () {
    final base = DateTime(2026, 10, 16, 14);

    test('intervalos que se cruzan se traslapan', () {
      expect(
        AvailabilityService.intervalsOverlap(
          base,
          base.add(const Duration(minutes: 90)),
          base.add(const Duration(minutes: 60)),
          base.add(const Duration(minutes: 150)),
        ),
        isTrue,
      );
    });

    test('uno contenido en otro se traslapa', () {
      expect(
        AvailabilityService.intervalsOverlap(
          base,
          base.add(const Duration(hours: 3)),
          base.add(const Duration(minutes: 30)),
          base.add(const Duration(minutes: 90)),
        ),
        isTrue,
      );
    });

    test('reservaciones consecutivas no se traslapan', () {
      final fin = base.add(const Duration(minutes: 90));
      expect(
        AvailabilityService.intervalsOverlap(
            base, fin, fin, fin.add(const Duration(minutes: 90))),
        isFalse,
      );
    });

    test('intervalos separados no se traslapan', () {
      expect(
        AvailabilityService.intervalsOverlap(
          base,
          base.add(const Duration(minutes: 60)),
          base.add(const Duration(hours: 3)),
          base.add(const Duration(hours: 4)),
        ),
        isFalse,
      );
    });
  });

  group('HU08-RF03 isWithinOperatingHours', () {
    final svc = build([]);

    test('cabe dentro del horario', () {
      expect(
        svc.isWithinOperatingHours(
          restaurant: _restaurant(),
          inicio: DateTime(2026, 10, 16, 20),
          duracionMin: 120,
        ),
        isTrue,
      );
    });

    test('rechaza empezar antes de abrir', () {
      expect(
        svc.isWithinOperatingHours(
          restaurant: _restaurant(),
          inicio: DateTime(2026, 10, 16, 11, 30),
          duracionMin: 60,
        ),
        isFalse,
      );
    });

    test('rechaza terminar después del cierre', () {
      expect(
        svc.isWithinOperatingHours(
          restaurant: _restaurant(),
          inicio: DateTime(2026, 10, 16, 21),
          duracionMin: 90,
        ),
        isFalse,
      );
    });

    test('acepta terminar exactamente al cierre', () {
      expect(
        svc.isWithinOperatingHours(
          restaurant: _restaurant(),
          inicio: DateTime(2026, 10, 16, 20, 30),
          duracionMin: 90,
        ),
        isTrue,
      );
    });

    test('horario nocturno que cruza la medianoche', () {
      final noche = _restaurant(horarios: {
        'viernes': const DaySchedule(
            abierto: true, apertura: '18:00', cierre: '02:00'),
      });
      expect(
        svc.isWithinOperatingHours(
          restaurant: noche,
          inicio: DateTime(2026, 10, 16, 23),
          duracionMin: 120,
        ),
        isTrue,
      );
      expect(
        svc.isWithinOperatingHours(
          restaurant: noche,
          inicio: DateTime(2026, 10, 16, 23),
          duracionMin: 240,
        ),
        isFalse,
      );
    });

    test('abierto 24 horas', () {
      final full = _restaurant(horarios: {
        'viernes':
            const DaySchedule(abierto: true, apertura: '00:00', cierre: '00:00'),
      });
      expect(
        svc.isWithinOperatingHours(
          restaurant: full,
          inicio: DateTime(2026, 10, 16, 23),
          duracionMin: 180,
        ),
        isTrue,
      );
    });
  });

  group('HU08-RF03 checkAvailability con mesas', () {
    final mesas = [_mesa('m1', 4), _mesa('m2', 2)];
    final inicio = DateTime(2026, 10, 16, 14);

    test('sin reservaciones todas las mesas están libres', () async {
      final r = await build([]).checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
      );
      expect(r.isAvailable, isTrue);
      expect(r.mesasLibres.map((m) => m.id), ['m1', 'm2']);
    });

    test('una reservación traslapada bloquea su mesa', () async {
      final r = await build([_res('a', DateTime(2026, 10, 16, 13))])
          .checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
      );
      expect(r.mesasBloqueadasIds, {'m1'});
      expect(r.mesasLibres.map((m) => m.id), ['m2']);
    });

    test('devuelve el estado disponible/ocupada de cada mesa', () async {
      final r = await build([_res('a', DateTime(2026, 10, 16, 13))])
          .checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
      );
      expect(r.estadoPorMesa, {
        'm1': MesaEstado.ocupada,
        'm2': MesaEstado.disponible,
      });
    });

    test('el margen de limpieza hace que una reserva consecutiva bloquee',
        () async {
      final svc = AvailabilityService(
        _FakeReservations([_res('a', DateTime(2026, 10, 16, 12, 30))]),
        now: () => now,
        margenLimpiezaMin: 15,
      );
      final r = await svc.checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
      );
      expect(r.mesasBloqueadasIds, {'m1'});
    });

    test('reservación consecutiva no bloquea', () async {
      final r = await build([_res('a', DateTime(2026, 10, 16, 12, 30))])
          .checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
      );
      expect(r.mesasBloqueadasIds, isEmpty);
    });

    test('una reservación cancelada no bloquea', () async {
      final r = await build([
        _res('a', DateTime(2026, 10, 16, 14),
            estado: ReservationModel.estadoCancelada),
      ]).checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
      );
      expect(r.isAvailable, isTrue);
      expect(r.mesasBloqueadasIds, isEmpty);
    });

    test('sin mesas libres no hay disponibilidad', () async {
      final r = await build([
        _res('a', DateTime(2026, 10, 16, 14), mesas: ['m1']),
        _res('b', DateTime(2026, 10, 16, 14), mesas: ['m2']),
      ]).checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
      );
      expect(r.isAvailable, isFalse);
      expect(r.reason, AvailabilityFailure.sinDisponibilidad);
    });

    test('una reservación del día anterior que cruza la medianoche bloquea',
        () async {
      final nocturno = _restaurant(
        mesas: mesas,
        horarios: {
          'viernes': const DaySchedule(
              abierto: true, apertura: '18:00', cierre: '03:00'),
          'sabado': const DaySchedule(
              abierto: true, apertura: '18:00', cierre: '03:00'),
        },
      );
      final r = await build([
        _res('a', DateTime(2026, 10, 16, 23, 30), duracion: 120, mesas: ['m1']),
      ]).checkAvailability(
        restaurant: nocturno,
        inicio: DateTime(2026, 10, 17, 0, 30),
        duracionMin: 60,
      );
      expect(r.mesasBloqueadasIds, {'m1'});
    });

    test('rechaza fecha pasada sin consultar reservaciones', () async {
      final r = await build([]).checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: DateTime(2026, 10, 1, 14),
      );
      expect(r.reason, AvailabilityFailure.fechaPasada);
    });

    test('rechaza horario fuera de atención', () async {
      final r = await build([]).checkAvailability(
        restaurant: _restaurant(mesas: mesas),
        inicio: DateTime(2026, 10, 16, 21),
        duracionMin: 120,
      );
      expect(r.reason, AvailabilityFailure.fueraDeHorario);
    });
  });

  group('HU08-RF03 checkAvailability sin mesas (capacidad)', () {
    final inicio = DateTime(2026, 10, 16, 14);

    test('cabe si personas + reservadas <= capacidad', () async {
      final r = await build([_res('a', inicio, personas: 6, mesas: [])])
          .checkAvailability(
        restaurant: _restaurant(capacidadMaxima: 10),
        inicio: inicio,
        personas: 4,
      );
      expect(r.isAvailable, isTrue);
      expect(r.personasReservadas, 6);
    });

    test('no cabe si excede la capacidad', () async {
      final r = await build([_res('a', inicio, personas: 6, mesas: [])])
          .checkAvailability(
        restaurant: _restaurant(capacidadMaxima: 10),
        inicio: inicio,
        personas: 5,
      );
      expect(r.isAvailable, isFalse);
      expect(r.reason, AvailabilityFailure.sinDisponibilidad);
    });

    test('sin capacidad registrada no hay disponibilidad', () async {
      final r = await build([]).checkAvailability(
        restaurant: _restaurant(),
        inicio: inicio,
      );
      expect(r.isAvailable, isFalse);
    });
  });
}
