import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/experiencia_model.dart';
import 'package:reservitta/models/occasion_booking.dart';
import 'package:reservitta/models/preorder_restrictions.dart';
import 'package:reservitta/models/reservation_detail.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/services/ocasion_service.dart';
import 'package:reservitta/services/reservation_service.dart';

Map<String, dynamic> _exp(
  String id,
  String nombre, {
  double precio = 0,
  bool? esGratis,
  String? mensaje,
  Object? extra,
}) =>
    {
      'experienciaId': id,
      'nombre': nombre,
      'precio': precio,
      'esGratis': esGratis ?? precio <= 0,
      if (mensaje != null) 'mensajeFelicitacion': mensaje,
    };

ReservationModel _reserva({
  Map<String, dynamic>? ocasion,
  List<Map<String, dynamic>> experiencias = const [],
  List<Map<String, dynamic>> preorden = const [],
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
    ocasionEspecial: ocasion,
    experiencias: experiencias,
  );
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  group('HU18-RF01 consulta de ocasiones por restaurante', () {
    late FakeFirebaseFirestore db;
    late OcasionService service;

    Future<void> ocasion(
      String id,
      String restaurante,
      String nombre, {
      bool activo = true,
      List<Map<String, dynamic>> experiencias = const [],
    }) {
      return db
          .collection('restaurants')
          .doc(restaurante)
          .collection('ocasiones')
          .doc(id)
          .set({
        'nombre': nombre,
        'tipoPredefinido': nombre,
        'descripcion': 'Descripción de $nombre',
        'icono': 'cake',
        'activo': activo,
        'experiencias': experiencias,
      });
    }

    setUp(() {
      db = FakeFirebaseFirestore();
      service = OcasionService(firestore: db);
    });

    test('devuelve nombre, ícono y experiencias con descripción y precio o Gratis',
        () async {
      await ocasion('o1', 'r1', 'Cumpleaños', experiencias: [
        {'id': 'e1', 'nombre': 'Postre con felicitación', 'descripcionCorta': 'Mensaje en tu postre', 'precio': 0.0, 'orden': 1},
        {'id': 'e2', 'nombre': 'Globos', 'descripcionCorta': 'Decoración', 'precio': 150.0, 'orden': 2},
      ]);
      final lista = await service.getOcasionesDisponibles('r1');
      expect(lista, hasLength(1));
      final o = lista.single;
      expect(o.nombre, 'Cumpleaños');
      expect(o.icono, 'cake');
      expect(o.descripcion, 'Descripción de Cumpleaños');
      expect(o.experiencias.map((e) => e.nombre), ['Postre con felicitación', 'Globos']);
      expect(o.experiencias.map((e) => e.descripcionCorta),
          ['Mensaje en tu postre', 'Decoración']);
      expect(o.experiencias.map((e) => e.precioFormateado), ['Gratis', '\$150.00 MXN']);
    });

    test('solo trae las ocasiones del restaurante consultado', () async {
      await ocasion('o1', 'r1', 'Cumpleaños');
      await ocasion('o2', 'r2', 'Aniversario');
      final r1 = await service.getOcasionesDisponibles('r1');
      expect(r1.map((o) => o.nombre), ['Cumpleaños']);
    });

    test('omite ocasiones inactivas y experiencias inactivas', () async {
      await ocasion('o1', 'r1', 'Cumpleaños', experiencias: [
        {'id': 'e1', 'nombre': 'Activa', 'precio': 0.0, 'activo': true},
        {'id': 'e2', 'nombre': 'Apagada', 'precio': 0.0, 'activo': false},
      ]);
      await ocasion('o2', 'r1', 'Aniversario', activo: false);
      final lista = await service.getOcasionesDisponibles('r1');
      expect(lista.map((o) => o.nombre), ['Cumpleaños']);
      expect(lista.single.experiencias.map((e) => e.nombre), ['Activa']);
    });

    test('ordena las ocasiones en el orden predefinido y deja "Otro" al final',
        () async {
      await ocasion('o1', 'r1', 'Otro');
      await ocasion('o2', 'r1', 'Aniversario');
      await ocasion('o3', 'r1', 'Cumpleaños');
      final lista = await service.getOcasionesDisponibles('r1');
      expect(lista.map((o) => o.nombre), ['Cumpleaños', 'Aniversario', 'Otro']);
    });

    test('ordena las experiencias por su orden', () async {
      await ocasion('o1', 'r1', 'Cumpleaños', experiencias: [
        {'id': 'e2', 'nombre': 'B', 'precio': 0.0, 'orden': 2},
        {'id': 'e1', 'nombre': 'A', 'precio': 0.0, 'orden': 1},
      ]);
      final lista = await service.getOcasionesDisponibles('r1');
      expect(lista.single.experiencias.map((e) => e.nombre), ['A', 'B']);
    });

    test('un restaurante sin ocasiones o un id vacío devuelve una lista vacía',
        () async {
      expect(await service.getOcasionesDisponibles('r1'), isEmpty);
      expect(await service.getOcasionesDisponibles('  '), isEmpty);
    });

    test('la experiencia "Postre con felicitación" requiere información', () {
      expect(const ExperienciaModel(id: 'a', nombre: 'Postre con felicitación', precio: 0)
          .requiereInformacion, isTrue);
      expect(const ExperienciaModel(id: 'a', nombre: 'Globos', precio: 100)
          .requiereInformacion, isFalse);
      expect(
        const ExperienciaModel(
          id: 'a',
          nombre: 'Detalle especial',
          precio: 0,
          tipo: ExperienciaModel.tipoPostreFelicitacion,
        ).requiereInformacion,
        isTrue,
      );
      final desdeMapa = ExperienciaModel.fromMap(
          'a', {'nombre': 'X', 'precio': 0.0, 'tipo': 'postre_felicitacion'});
      expect(desdeMapa.requiereInformacion, isTrue);
      expect(desdeMapa.toMap()['tipo'], 'postre_felicitacion');
      expect(const ExperienciaModel(id: 'a', nombre: 'X', precio: 0).toMap().containsKey('tipo'),
          isFalse);
    });
  });

  group('HU18-RF05 normalización de la ocasión', () {
    test('sin ocasión elegida no queda ninguna experiencia', () {
      final r = OccasionBooking.normalizar(null, [_exp('e1', 'Globos', precio: 100)]);
      expect(r.ocasion, isNull);
      expect(r.experiencias, isEmpty);
      final vacia = OccasionBooking.normalizar({'nombre': '  '}, [_exp('e1', 'X')]);
      expect(vacia.ocasion, isNull);
    });

    test('limpia el detalle de "Otro" y los mensajes de felicitación', () {
      final r = OccasionBooking.normalizar(
        {'ocasionId': 'o9', 'nombre': 'Otro', 'icono': 'celebration', 'detalle': '  Ascenso de Luis  '},
        [_exp('e1', 'Postre con felicitación', mensaje: '  Feliz cumple Ana  ')],
      );
      expect(r.ocasion!['detalle'], 'Ascenso de Luis');
      expect(r.experiencias.single['mensajeFelicitacion'], 'Feliz cumple Ana');
    });

    test('recorta los textos al límite', () {
      final r = OccasionBooking.normalizar(
        {'nombre': 'Otro', 'detalle': 'a' * 150},
        [_exp('e1', 'Postre', mensaje: 'b' * 150)],
      );
      expect((r.ocasion!['detalle'] as String).length, 100);
      expect((r.experiencias.single['mensajeFelicitacion'] as String).length, 100);
    });

    test('sin detalle ni mensaje no se guardan esos campos', () {
      final r = OccasionBooking.normalizar({'nombre': 'Cumpleaños'}, [_exp('e1', 'Globos', precio: 50)]);
      expect(r.ocasion!.containsKey('detalle'), isFalse);
      expect(r.experiencias.single.containsKey('mensajeFelicitacion'), isFalse);
    });

    test('una experiencia gratuita no cobra y las repetidas se quitan', () {
      final r = OccasionBooking.normalizar({'nombre': 'Cumpleaños'}, [
        _exp('e1', 'Postre', precio: 80, esGratis: true),
        _exp('e1', 'Postre', precio: 80, esGratis: true),
        _exp('e2', 'Globos', precio: 150),
        {'experienciaId': 'e3', 'nombre': '   ', 'precio': 10.0},
      ]);
      expect(r.experiencias.map((e) => e['experienciaId']), ['e1', 'e2']);
      expect(r.experiencias.first['precio'], 0.0);
      expect(OccasionBooking.totalExperiencias(r.experiencias), 150.0);
    });
  });

  group('HU18-RF05 persistencia en la reserva', () {
    test('guarda la ocasión, las experiencias, los mensajes y los totales', () {
      final map = _reserva(
        ocasion: {'ocasionId': 'o1', 'nombre': 'Cumpleaños', 'icono': 'cake'},
        experiencias: [
          _exp('e1', 'Postre con felicitación', mensaje: 'Feliz cumple Ana'),
          _exp('e2', 'Globos', precio: 150),
        ],
        preorden: [
          {'platilloId': 'p1', 'nombre': 'Pastel', 'precio': 200.0, 'cantidad': 1, 'total': 200.0, 'mensajeFelicitacion': '  Feliz cumple Ana '},
        ],
      ).toMap();
      expect(map['tieneOcasion'], isTrue);
      final ocasion = map['ocasion'] as Map;
      expect(ocasion['nombre'], 'Cumpleaños');
      final exps = ocasion['experiencias'] as List;
      expect((exps[0] as Map)['mensajeFelicitacion'], 'Feliz cumple Ana');
      expect((exps[1] as Map)['precio'], 150.0);
      final totales = map['totales'] as Map;
      expect(totales['totalExperiencias'], 150.0);
      expect(totales['subtotalPreorden'], 200.0);
      expect(totales['total'], 350.0);
      final linea = ((map['preorden'] as Map)['items'] as List).single as Map;
      expect(linea['mensajeFelicitacion'], 'Feliz cumple Ana');
    });

    test('guarda explícitamente que no hay ocasión', () {
      final map = _reserva().toMap();
      expect(map['tieneOcasion'], isFalse);
      expect(map.containsKey('ocasion'), isFalse);
      expect(map.containsKey('totales'), isFalse);
    });

    test('experiencias sin ocasión no se guardan', () {
      final map = _reserva(experiencias: [_exp('e1', 'Globos', precio: 100)]).toMap();
      expect(map['tieneOcasion'], isFalse);
      expect(map.containsKey('ocasion'), isFalse);
      expect(map.containsKey('totales'), isFalse);
    });

    test('el mensaje de felicitación de un postre se recorta a 100 caracteres', () {
      final lineas = PreorderRestrictions.normalizarLineas([
        {'platilloId': 'p1', 'nombre': 'Pastel', 'cantidad': 1, 'mensajeFelicitacion': 'x' * 130},
        {'platilloId': 'p2', 'nombre': 'Flan', 'cantidad': 1, 'mensajeFelicitacion': '   '},
      ]);
      expect((lineas[0]['mensajeFelicitacion'] as String).length, 100);
      expect(lineas[1].containsKey('mensajeFelicitacion'), isFalse);
    });

    test('al leerla de Firestore conserva lo guardado y el detalle del administrador lo muestra',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = ReservationService(firestore: db);
      final guardada = await repo.createReservationVerified(_reserva(
        ocasion: {'ocasionId': 'o9', 'nombre': 'Otro', 'icono': 'celebration', 'detalle': 'Ascenso de Luis'},
        experiencias: [
          _exp('e1', 'Postre con felicitación', mensaje: 'Felicidades Luis'),
          _exp('e2', 'Globos', precio: 150),
        ],
      ).copyWith(id: ''));

      final leida = (await repo.getReservationById(guardada.id))!;
      expect(leida.esOcasionEspecial, isTrue);
      expect(leida.nombreOcasionEspecial, 'Otro');
      expect(leida.totalExperiencias, 150.0);

      final detalle = (await repo.getReservationDetail(guardada.id))!;
      expect(detalle.resumenOcasion, 'Otro: Ascenso de Luis');
      expect(detalle.experiencias.map((e) => e.nombre), ['Postre con felicitación', 'Globos']);
      expect(detalle.experiencias.first.mensajeFelicitacion, 'Felicidades Luis');
      expect(detalle.experiencias.last.precioFormateado, '\$150.00 MXN');
      expect(detalle.totalExperiencias, 150.0);
    });

    test('una reserva sin ocasión se lee como "No indicado"', () async {
      final db = FakeFirebaseFirestore();
      final repo = ReservationService(firestore: db);
      final guardada = await repo.createReservationVerified(_reserva().copyWith(id: ''));
      final data = (await db.collection('reservations').doc(guardada.id).get()).data()!;
      expect(data['tieneOcasion'], isFalse);
      expect(ReservationDetail.fromReservation(guardada).resumenOcasion, 'No indicado');
    });
  });
}
