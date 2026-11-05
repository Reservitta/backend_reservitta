import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/zona_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/repositories/table_repository.dart';
import 'package:reservitta/services/availability_service.dart';

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

class _FakeTables implements TableRepository {
  final List<MesaModel> mesas;
  final List<ZonaModel> zonas;
  _FakeTables(this.mesas, {this.zonas = const []});

  @override
  Future<List<MesaModel>> getMesas(String restaurantId) async => mesas;

  @override
  Future<List<ZonaModel>> getZonas(String restaurantId) async => zonas;
}

const _abierto = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

RestaurantModel _restaurant({List<MesaModel> mesas = const []}) {
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
        'domingo'
      ])
        d: _abierto,
    },
  );
}

MesaModel _mesa(
  String id,
  int capacidad, {
  bool combinable = false,
  List<String> con = const [],
  double? x,
  double? y,
  String? zona,
  String forma = MesaModel.formaCuadrada,
}) {
  return MesaModel(
    id: id,
    nombre: id,
    capacidad: capacidad,
    combinable: combinable,
    combinableCon: con,
    x: x,
    y: y,
    zonaId: zona,
    forma: forma,
  );
}

ReservationModel _res(String id, DateTime inicio, List<String> mesas) {
  return ReservationModel.create(
    id: id,
    restauranteId: 'r1',
    fechaLocal: '2026-10-30',
    inicio: inicio,
    mesaIds: mesas,
    estado: ReservationModel.estadoConfirmada,
  );
}

void main() {
  // Domingo 25 de octubre de 2026; se reserva el viernes 30 a las 14:00.
  final now = DateTime(2026, 10, 25, 10);
  final inicio = DateTime(2026, 10, 30, 14);

  AvailabilityService build({
    List<MesaModel>? mesas,
    List<ZonaModel> zonas = const [],
    List<ReservationModel> reservations = const [],
  }) {
    return AvailabilityService(
      _FakeReservations(reservations),
      tables: mesas == null ? null : _FakeTables(mesas, zonas: zonas),
      now: () => now,
    );
  }

  group('MesaModel y ZonaModel', () {
    test('formas admitidas: redonda, cuadrada y rectangular', () {
      expect(MesaModel.formasValidas, ['redonda', 'cuadrada', 'rectangular']);
      expect(_mesa('a', 2, forma: 'redonda').tieneFormaValida, isTrue);
      expect(_mesa('a', 2, forma: 'hexagonal').tieneFormaValida, isFalse);
    });

    test('tienePosicion exige x e y', () {
      expect(_mesa('a', 2, x: 1, y: 2).tienePosicion, isTrue);
      expect(_mesa('a', 2, x: 1).tienePosicion, isFalse);
      expect(_mesa('a', 2).tienePosicion, isFalse);
    });

    test('puedeCombinarCon es simétrico y exige que ambas sean combinables', () {
      final a = _mesa('a', 2, combinable: true, con: ['b']);
      final b = _mesa('b', 2, combinable: true);
      final c = _mesa('c', 2, combinable: false, con: ['a']);
      expect(a.puedeCombinarCon(b), isTrue);
      expect(b.puedeCombinarCon(a), isTrue);
      expect(a.puedeCombinarCon(c), isFalse);
      expect(a.puedeCombinarCon(a), isFalse);
    });

    test('ZonaModel se lee desde un mapa de Firestore', () {
      final z = ZonaModel.fromMap('z1', {'nombre': 'Terraza', 'orden': 2});
      expect(z.nombre, 'Terraza');
      expect(z.orden, 2);
      expect(ZonaModel.fromMap('z2', {}).nombre, 'Zona');
    });
  });

  group('HU09-RF02 mesas individuales', () {
    final mesas = [_mesa('m1', 2), _mesa('m2', 4), _mesa('m3', 6)];

    test('devuelve las mesas libres cuya capacidad cubre al grupo', () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
        personas: 3,
      );
      expect(r.mesas.map((o) => o.mesa.id), ['m2', 'm3']);
      expect(r.combinaciones, isEmpty);
      expect(r.reason, isNull);
    });

    test('una mesa con más capacidad se marca como sobrada pero no se descarta',
        () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
        personas: 4,
      );
      final exacta = r.mesas.firstWhere((o) => o.mesa.id == 'm2');
      final grande = r.mesas.firstWhere((o) => o.mesa.id == 'm3');
      expect(exacta.adecuada, isTrue);
      expect(exacta.sobrada, isFalse);
      expect(grande.adecuada, isTrue);
      expect(grande.sobrada, isTrue);
      expect(grande.holgura, 2);
    });

    test('ordena de menor a mayor holgura', () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
        personas: 2,
      );
      expect(r.mesas.map((o) => o.mesa.id), ['m1', 'm2', 'm3']);
    });

    test('excluye las mesas ocupadas en la fecha y duración elegidas',
        () async {
      final r = await build(reservations: [
        _res('a', DateTime(2026, 10, 30, 13), ['m2']),
      ]).findSuitableTables(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
        personas: 3,
      );
      expect(r.mesas.map((o) => o.mesa.id), ['m3']);
    });

    test('una mesa ocupada en otro horario sigue disponible', () async {
      final r = await build(reservations: [
        _res('a', DateTime(2026, 10, 30, 19), ['m2']),
      ]).findSuitableTables(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
        personas: 3,
      );
      expect(r.mesas.map((o) => o.mesa.id), ['m2', 'm3']);
    });

    test('lee las mesas del TableRepository cuando se proporciona', () async {
      final r = await build(mesas: mesas).findSuitableTables(
        restaurant: _restaurant(),
        inicio: inicio,
        personas: 5,
      );
      expect(r.mesas.map((o) => o.mesa.id), ['m3']);
    });

    test('si el repositorio no tiene mesas usa las del restaurante', () async {
      final r = await build(mesas: const []).findSuitableTables(
        restaurant: _restaurant(mesas: mesas),
        inicio: inicio,
        personas: 5,
      );
      expect(r.mesas.map((o) => o.mesa.id), ['m3']);
    });

    test('una fecha no reservable devuelve el motivo', () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: mesas),
        inicio: DateTime(2026, 10, 1, 14),
        personas: 2,
      );
      expect(r.reason, AvailabilityFailure.fechaPasada);
      expect(r.hayOpciones, isFalse);
    });
  });

  group('HU09-RF02 combinaciones', () {
    // a - b - c enlazadas en cadena; d no es combinable.
    final cadena = [
      _mesa('a', 2, combinable: true, con: ['b']),
      _mesa('b', 2, combinable: true, con: ['a', 'c']),
      _mesa('c', 2, combinable: true, con: ['b']),
      _mesa('d', 1),
    ];

    test('si ninguna mesa alcanza, devuelve combinaciones conectadas', () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: cadena),
        inicio: inicio,
        personas: 4,
      );
      expect(r.mesas, isEmpty);
      final sets = r.combinaciones.map((c) => (c.mesaIds..sort()).join()).toSet();
      expect(sets, {'ab', 'bc'});
    });

    test('no combina mesas que no están enlazadas entre sí', () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: cadena),
        inicio: inicio,
        personas: 4,
      );
      final sets = r.combinaciones.map((c) => (c.mesaIds..sort()).join());
      expect(sets, isNot(contains('ac')));
    });

    test('solo devuelve combinaciones mínimas', () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: cadena),
        inicio: inicio,
        personas: 3,
      );
      expect(r.combinaciones.every((c) => c.mesas.length == 2), isTrue);
    });

    test('la capacidad sumada cubre al grupo', () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: cadena),
        inicio: inicio,
        personas: 6,
      );
      expect(r.combinaciones, hasLength(1));
      expect(r.combinaciones.single.capacidadTotal, 6);
      expect(r.combinaciones.single.holgura, 0);
    });

    test('excluye mesas ocupadas de las combinaciones', () async {
      final r = await build(reservations: [
        _res('x', DateTime(2026, 10, 30, 14), ['b']),
      ]).findSuitableTables(
        restaurant: _restaurant(mesas: cadena),
        inicio: inicio,
        personas: 4,
      );
      expect(r.combinaciones, isEmpty);
      expect(r.reason, AvailabilityFailure.sinDisponibilidad);
    });

    test('mesas no combinables no se unen aunque sumen la capacidad',
        () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: [_mesa('a', 2), _mesa('b', 2)]),
        inicio: inicio,
        personas: 4,
      );
      expect(r.hayOpciones, isFalse);
      expect(r.reason, AvailabilityFailure.sinDisponibilidad);
    });

    test('un grupo mayor que todo el restaurante no tiene opciones', () async {
      final r = await build().findSuitableTables(
        restaurant: _restaurant(mesas: cadena),
        inicio: inicio,
        personas: 20,
      );
      expect(r.hayOpciones, isFalse);
    });
  });

  group('HU10-RF01 plano del restaurante', () {
    final mesas = [
      _mesa('m1', 2, x: 10, y: 10, zona: 'z1', forma: MesaModel.formaRedonda),
      _mesa('m2', 4, x: 50, y: 10, zona: 'z1'),
      _mesa('m3', 6, x: 10, y: 80, zona: 'z2',
          forma: MesaModel.formaRectangular),
    ];
    final zonas = [
      const ZonaModel(id: 'z1', nombre: 'Terraza', orden: 1),
      const ZonaModel(id: 'z2', nombre: 'Interior', orden: 2),
    ];

    test('devuelve el plano completo con el estado de cada mesa', () async {
      final plan = await build(
        mesas: mesas,
        zonas: zonas,
        reservations: [_res('a', DateTime(2026, 10, 30, 13), ['m2'])],
      ).getFloorPlan(restaurant: _restaurant(), inicio: inicio);

      expect(plan.configurado, isTrue);
      expect(plan.reason, isNull);
      expect({for (final p in plan.mesas) p.mesa.id: p.estado}, {
        'm1': MesaEstado.disponible,
        'm2': MesaEstado.ocupada,
        'm3': MesaEstado.disponible,
      });
    });

    test('incluye posición, forma y tamaño de cada mesa', () async {
      final plan = await build(mesas: mesas, zonas: zonas)
          .getFloorPlan(restaurant: _restaurant(), inicio: inicio);
      final m1 = plan.mesas.first.mesa;
      expect(m1.x, 10);
      expect(m1.y, 10);
      expect(m1.forma, 'redonda');
      expect(m1.ancho, greaterThan(0));
      expect(m1.alto, greaterThan(0));
    });

    test('incluye las zonas y agrupa las mesas por zona', () async {
      final plan = await build(mesas: mesas, zonas: zonas)
          .getFloorPlan(restaurant: _restaurant(), inicio: inicio);
      expect(plan.zonas.map((z) => z.nombre), ['Terraza', 'Interior']);
      expect(plan.mesasDeZona('z1').map((p) => p.mesa.id), ['m1', 'm2']);
      expect(plan.mesasDeZona('z2').map((p) => p.mesa.id), ['m3']);
    });

    test('un restaurante sin mesas devuelve un estado controlado', () async {
      final plan = await build(mesas: const [])
          .getFloorPlan(restaurant: _restaurant(), inicio: inicio);
      expect(plan.configurado, isFalse);
      expect(plan.mesas, isEmpty);
    });

    test('mesas sin posición no cuentan como plano configurado', () async {
      final plan = await build(mesas: [_mesa('m1', 2), _mesa('m2', 4)])
          .getFloorPlan(restaurant: _restaurant(), inicio: inicio);
      expect(plan.configurado, isFalse);
    });

    test('mesas sin posición no se dibujan en el plano', () async {
      final plan = await build(mesas: [
        _mesa('m1', 2, x: 1, y: 1),
        _mesa('m2', 4),
      ]).getFloorPlan(restaurant: _restaurant(), inicio: inicio);
      expect(plan.mesas.map((p) => p.mesa.id), ['m1']);
    });

    test('una fecha no reservable marca todas las mesas como no disponibles',
        () async {
      final plan = await build(mesas: mesas, zonas: zonas).getFloorPlan(
        restaurant: _restaurant(),
        inicio: DateTime(2026, 10, 1, 14),
      );
      expect(plan.configurado, isTrue);
      expect(plan.reason, AvailabilityFailure.fechaPasada);
      expect(
        plan.mesas.every((p) => p.estado == MesaEstado.noDisponible),
        isTrue,
      );
    });

    test('con todas las mesas ocupadas no hay motivo de fecha', () async {
      final plan = await build(
        mesas: mesas,
        reservations: [
          _res('a', DateTime(2026, 10, 30, 14), ['m1', 'm2', 'm3']),
        ],
      ).getFloorPlan(restaurant: _restaurant(), inicio: inicio);
      expect(plan.reason, isNull);
      expect(
        plan.mesas.every((p) => p.estado == MesaEstado.ocupada),
        isTrue,
      );
    });
  });
}
