import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/preorder_restrictions.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/reservation_service.dart';

const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

RestaurantModel _restaurant() {
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
        d: _horario,
    },
  );
}

Map<String, dynamic> _linea(
  String id,
  String nombre, {
  int cantidad = 1,
  Object? observacion = '',
  double precio = 100,
}) =>
    {
      'platilloId': id,
      'nombre': nombre,
      'precio': precio,
      'cantidad': cantidad,
      'total': precio * cantidad,
      'observacion': observacion,
    };

ReservationModel _reserva({
  List<Map<String, dynamic>> preorden = const [],
  List<String> alergias = const [],
  String notas = '',
}) {
  return ReservationModel.create(
    id: 'res1',
    restauranteId: 'r1',
    usuarioId: 'u1',
    fechaLocal: '2026-10-30',
    inicio: DateTime(2026, 10, 30, 14),
    mesaIds: const ['m1'],
    estado: ReservationModel.estadoConfirmada,
    preordenItems: preorden,
    alergias: alergias,
    notasAlergias: notas,
  );
}

void main() {
  // El Firestore de pruebas debe existir antes de crear cualquier FieldValue
  // (toMap() usa serverTimestamp), o los FieldValue quedan con la plataforma real.
  setUpAll(() => FakeFirebaseFirestore());

  group('PreorderRestrictions.normalizarLineas', () {
    test('cada línea conserva su propia observación', () {
      final lineas = PreorderRestrictions.normalizarLineas([
        _linea('p1', 'Pasta', observacion: 'sin gluten'),
        _linea('p2', 'Sopa', observacion: 'sin cebolla'),
        _linea('p3', 'Postre'),
      ]);
      expect(lineas.map((l) => l['observacion']), ['sin gluten', 'sin cebolla', '']);
      expect(lineas.map((l) => l['platilloId']), ['p1', 'p2', 'p3']);
    });

    test('dos líneas del mismo platillo no mezclan sus observaciones', () {
      final lineas = PreorderRestrictions.normalizarLineas([
        _linea('p1', 'Pasta', observacion: 'sin gluten'),
        _linea('p1', 'Pasta', observacion: 'extra queso'),
      ]);
      expect(lineas, hasLength(2));
      expect(lineas.map((l) => l['observacion']), ['sin gluten', 'extra queso']);
    });

    test('limpia espacios y recorta al límite de caracteres', () {
      final larga = 'a' * 250;
      final lineas = PreorderRestrictions.normalizarLineas([
        _linea('p1', 'Pasta', observacion: '   sin sal   '),
        _linea('p2', 'Sopa', observacion: larga),
      ]);
      expect(lineas[0]['observacion'], 'sin sal');
      expect((lineas[1]['observacion'] as String).length, 200);
    });

    test('descarta líneas sin platillo o con cantidad menor a 1', () {
      final lineas = PreorderRestrictions.normalizarLineas([
        _linea('', 'Sin id'),
        _linea('p1', 'Cero', cantidad: 0),
        _linea('p2', 'Bien', cantidad: 2),
      ]);
      expect(lineas.map((l) => l['platilloId']), ['p2']);
    });

    test('una observación nula queda como texto vacío', () {
      final lineas = PreorderRestrictions.normalizarLineas([
        _linea('p1', 'Pasta', observacion: null),
      ]);
      expect(lineas.single['observacion'], '');
    });

    test('no modifica la lista original', () {
      final original = [_linea('p1', 'Pasta', observacion: '  x  ')];
      PreorderRestrictions.normalizarLineas(original);
      expect(original.single['observacion'], '  x  ');
    });
  });

  group('PreorderRestrictions.porPlatillo y alergias', () {
    test('devuelve solo las líneas con observación, asociadas a su platillo', () {
      final porPlatillo = PreorderRestrictions.porPlatillo([
        _linea('p1', 'Pasta', cantidad: 2, observacion: 'sin gluten'),
        _linea('p2', 'Sopa'),
        _linea('p3', 'Postre', observacion: 'sin nueces'),
      ]);
      expect(porPlatillo, const [
        RestriccionPlatillo(
          platilloId: 'p1',
          nombre: 'Pasta',
          cantidad: 2,
          observacion: 'sin gluten',
        ),
        RestriccionPlatillo(
          platilloId: 'p3',
          nombre: 'Postre',
          cantidad: 1,
          observacion: 'sin nueces',
        ),
      ]);
    });

    test('normalizarAlergias quita vacías, espacios y repetidas', () {
      expect(
        PreorderRestrictions.normalizarAlergias(
            [' Gluten ', '', 'gluten', 'Nueces', '   ']),
        ['Gluten', 'Nueces'],
      );
    });
  });

  group('HU17-RF02 Criterio 1: restricción por platillo en la reserva', () {
    test('la observación se guarda dentro de la línea de su platillo', () {
      final map = _reserva(
        preorden: [
          _linea('p1', 'Pasta', observacion: 'sin gluten'),
          _linea('p2', 'Sopa'),
        ],
      ).toMap();
      final items = (map['preorden'] as Map)['items'] as List;
      expect(items, hasLength(2));
      expect((items[0] as Map)['platilloId'], 'p1');
      expect((items[0] as Map)['observacion'], 'sin gluten');
      expect((items[1] as Map)['observacion'], '');
    });

    test('se marca que hay observaciones y restricciones', () {
      final map = _reserva(
        preorden: [_linea('p1', 'Pasta', observacion: 'sin gluten')],
      ).toMap();
      expect(map['tieneObservaciones'], isTrue);
      expect(map['tieneRestricciones'], isTrue);
    });

    test('el subtotal solo cuenta las líneas válidas', () {
      final map = _reserva(preorden: [
        _linea('p1', 'Pasta', cantidad: 2, precio: 100),
        _linea('', 'Sin id', precio: 999),
      ]).toMap();
      expect((map['preorden'] as Map)['subtotalPreorden'], 200.0);
    });

    test('alergias y notas generales se guardan limpias', () {
      final map = _reserva(
        preorden: [_linea('p1', 'Pasta')],
        alergias: [' Gluten ', 'gluten', 'Nueces'],
        notas: '  Una persona celíaca  ',
      ).toMap();
      expect(map['alergias'], ['Gluten', 'Nueces']);
      expect(map['notasAlergias'], 'Una persona celíaca');
      expect(map['tieneRestricciones'], isTrue);
    });

    test('un pedido sin observaciones ni alergias no marca restricciones', () {
      final map = _reserva(preorden: [_linea('p1', 'Pasta')]).toMap();
      expect(map['tienePreorden'], isTrue);
      expect(map.containsKey('tieneRestricciones'), isFalse);
      expect(map.containsKey('tieneObservaciones'), isFalse);
      expect(map.containsKey('alergias'), isFalse);
    });

    test('el modelo expone las restricciones por platillo', () {
      final r = _reserva(preorden: [
        _linea('p1', 'Pasta', observacion: 'sin gluten'),
        _linea('p2', 'Sopa'),
      ]);
      expect(r.restriccionesPorPlatillo.map((e) => e.platilloId), ['p1']);
      expect(r.tieneRestricciones, isTrue);
      expect(_reserva(alergias: ['Gluten']).tieneRestricciones, isTrue);
      expect(_reserva(notas: 'Vegano').tieneRestricciones, isTrue);
      expect(_reserva().tieneRestricciones, isFalse);
    });
  });

  group('HU17-RF02 Criterio 3: solo reservar no deja registros', () {
    test('la reserva sin personalización no escribe campos de restricciones', () {
      final map = _reserva().toMap();
      for (final clave in [
        'alergias',
        'notasAlergias',
        'tieneObservaciones',
        'tieneRestricciones',
        'preorden',
        'totales',
      ]) {
        expect(map.containsKey(clave), isFalse, reason: 'no debe existir "$clave"');
      }
      expect(map['tienePreorden'], isFalse);
    });

    test('alergias vacías o en blanco tampoco generan registro', () {
      final map = _reserva(alergias: ['  ', ''], notas: '   ').toMap();
      expect(map.containsKey('alergias'), isFalse);
      expect(map.containsKey('notasAlergias'), isFalse);
      expect(map.containsKey('tieneRestricciones'), isFalse);
    });

    test('una reserva guardada sin personalización se lee sin restricciones',
        () async {
      final db = FakeFirebaseFirestore();
      await db.collection('reservations').doc('res1').set(_reserva().toMap());
      final doc = await db.collection('reservations').doc('res1').get();
      expect(doc.data()!.keys, isNot(contains('alergias')));
      final leida = ReservationModel.fromMap('res1', doc.data()!);
      expect(leida.tieneRestricciones, isFalse);
      expect(leida.preordenItems, isEmpty);
    });
  });

  group('HU17-RF02 Criterio 2: detalle para el administrador', () {
    late FakeFirebaseFirestore db;
    late ReservationService repo;
    final now = DateTime(2026, 10, 25, 10);

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = ReservationService(firestore: db);
    });

    ReservationBookingService booking() => ReservationBookingService(
          AvailabilityService(repo, now: () => now),
          repo,
        );

    ReservationDraftModel draft({
      List<Map<String, dynamic>> preorden = const [],
      List<String> alergias = const [],
      String notas = '',
    }) {
      return ReservationDraftModel(
        restaurant: _restaurant(),
        fecha: DateTime(2026, 10, 30),
        duracionMin: 90,
        personas: 4,
        mesaIds: const ['m1'],
        mesasNombres: const ['M1'],
        horario: const TimeOfDay(hour: 14, minute: 0),
        preordenItems: preorden,
        alergias: alergias,
        notasAlergias: notas,
      );
    }

    test('al confirmar se guardan las observaciones por platillo y se leen de vuelta',
        () async {
      final result = await booking().confirm(
        restaurant: _restaurant(),
        draft: draft(
          preorden: [
            _linea('p1', 'Pasta', observacion: 'sin gluten'),
            _linea('p2', 'Sopa', observacion: '  poco picante '),
            _linea('p3', 'Postre'),
          ],
          alergias: ['Nueces'],
          notas: 'Mesa tranquila',
        ),
        usuarioId: 'u1',
      );
      final guardada = (result as BookingConfirmed).reservation;

      // Lo que ve el administrador al consultar la reservación.
      final detalle = await repo.getReservationById(guardada.id);
      expect(detalle, isNotNull);
      expect(detalle!.preordenItems, hasLength(3));
      expect(detalle.restriccionesPorPlatillo.map((e) => e.platilloId), ['p1', 'p2']);
      expect(
        detalle.restriccionesPorPlatillo.map((e) => e.observacion),
        ['sin gluten', 'poco picante'],
      );
      expect(detalle.restriccionesPorPlatillo.first.nombre, 'Pasta');
      expect(detalle.alergias, ['Nueces']);
      expect(detalle.notasAlergias, 'Mesa tranquila');
      expect(detalle.tieneRestricciones, isTrue);
      expect(detalle.tieneRestriccionesOAlergias, isTrue);
    });

    test('las observaciones quedan en el documento de la reserva en Firestore',
        () async {
      final result = await booking().confirm(
        restaurant: _restaurant(),
        draft: draft(preorden: [_linea('p1', 'Pasta', observacion: 'sin gluten')]),
        usuarioId: 'u1',
      );
      final id = (result as BookingConfirmed).reservation.id;
      final data = (await db.collection('reservations').doc(id).get()).data()!;
      final items = (data['preorden'] as Map)['items'] as List;
      expect((items.single as Map)['observacion'], 'sin gluten');
      expect(data['tieneObservaciones'], isTrue);
    });

    test('una reserva sin personalización se guarda sin registro de restricciones',
        () async {
      final result = await booking().confirm(
        restaurant: _restaurant(),
        draft: draft(),
        usuarioId: 'u1',
      );
      final id = (result as BookingConfirmed).reservation.id;
      final data = (await db.collection('reservations').doc(id).get()).data()!;
      expect(data.containsKey('preorden'), isFalse);
      expect(data.containsKey('alergias'), isFalse);
      expect(data.containsKey('notasAlergias'), isFalse);
      expect(data.containsKey('tieneRestricciones'), isFalse);
      expect(data.containsKey('tieneObservaciones'), isFalse);

      final detalle = await repo.getReservationById(id);
      expect(detalle!.restriccionesPorPlatillo, isEmpty);
      expect(detalle.tieneRestricciones, isFalse);
    });
  });
}
