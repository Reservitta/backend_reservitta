import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/utils/schedule_utils.dart';

const _dias = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];

Map<String, dynamic> restaurante(
  String nombre, {
  String estado = 'activo',
  GeoPoint? coords,
  int? capacidad = 20,
  List<String> cierres = const [],
  List<String> dias = _dias,
}) =>
    {
      'nombre': nombre,
      'estado': estado,
      'perfilCompleto': true,
      if (coords != null) 'coordenadas': coords,
      if (capacidad != null) 'capacidadMaxima': capacidad,
      'diasAbiertos': dias,
      'horarios': {
        for (final d in dias) d: {'abierto': true, 'apertura': '12:00', 'cierre': '22:00'},
      },
      'cierresEspeciales': cierres,
    };

/// Jueves 5 de noviembre de 2026 a las 14:00 (hora de pared del equipo).
final _jueves14 = DateTime(2026, 11, 5, 14);

void main() {
  setUpAll(() => FakeFirebaseFirestore());
  horariosTests();

  late FakeFirebaseFirestore db;
  late RestaurantService svc;

  setUp(() {
    db = FakeFirebaseFirestore();
    svc = RestaurantService(firestore: db);
  });

  Future<void> reservar(String rest, int personas,
      {DateTime? inicio, String estado = 'confirmada', String id = ''}) {
    final i = inicio ?? _jueves14;
    final ref = id.isEmpty ? db.collection('reservations').doc() : db.collection('reservations').doc(id);
    return ref.set({
      'restauranteId': rest,
      'fechaLocal':
          '${i.year}-${i.month.toString().padLeft(2, '0')}-${i.day.toString().padLeft(2, '0')}',
      'inicio': Timestamp.fromDate(i),
      'fin': Timestamp.fromDate(i.add(const Duration(minutes: 90))),
      'duracionMin': 90,
      'personas': personas,
      'estado': estado,
    });
  }

  group('Restaurantes activos (HU01-RF01)', () {
    setUp(() async {
      await db.collection('restaurants').doc('b').set(restaurante('Beta'));
      await db.collection('restaurants').doc('a').set(restaurante('alfa'));
      await db.collection('restaurants').doc('c').set(restaurante('Gama', estado: 'inactivo'));
    });

    test('solo trae los activos y ordenados sin importar mayúsculas', () async {
      final lista = await svc.getActiveRestaurants();
      expect(lista.map((r) => r.nombre), ['alfa', 'Beta']);
    });

    test('respeta el límite', () async {
      expect(await svc.getActiveRestaurants(limit: 1), hasLength(1));
      expect(await svc.getActiveRestaurants(limit: 0), hasLength(2));
    });

    test('getRestaurantById devuelve el restaurante o null', () async {
      expect((await svc.getRestaurantById('a'))!.nombre, 'alfa');
      expect(await svc.getRestaurantById('zzz'), isNull);
    });

    test('la versión segura devuelve el resultado sin lanzar', () async {
      final r = await svc.getActiveRestaurantsResult();
      expect(r.hasError, isFalse);
      expect(r.restaurants, hasLength(2));
    });

    test('el stream emite los activos y se actualiza', () async {
      final emitidos = <List<String>>[];
      final sub = svc.getActiveRestaurantsStream().listen((l) => emitidos.add([for (final r in l) r.nombre]));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.collection('restaurants').doc('d').set(restaurante('Delta'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(emitidos.first, ['alfa', 'Beta']);
      expect(emitidos.last, ['alfa', 'Beta', 'Delta']);
    });

    test('sin restaurantes devuelve una lista vacía, no un error', () async {
      expect(await RestaurantService(firestore: FakeFirebaseFirestore()).getActiveRestaurants(), isEmpty);
    });
  });

  group('Por radio (HU02-RF02)', () {
    setUp(() async {
      await db.collection('restaurants').doc('cerca').set(
          restaurante('Cerca', coords: const GeoPoint(19.4326, -99.1332)));
      await db.collection('restaurants').doc('medio').set(
          restaurante('Medio', coords: const GeoPoint(19.50, -99.13)));
      await db.collection('restaurants').doc('lejos').set(
          restaurante('Lejos', coords: const GeoPoint(25.67, -100.31)));
      await db.collection('restaurants').doc('sin').set(restaurante('SinCoords'));
    });

    test('filtra por radio y ordena del más cercano al más lejano', () async {
      final lista = await svc.getActiveRestaurantsByRadius(
          userLatitude: 19.4326, userLongitude: -99.1332, radiusKm: 20);
      expect(lista.map((r) => r.nombre), ['Cerca', 'Medio']);
      expect(lista.first.distanciaKm, lessThan(lista.last.distanciaKm!));
    });

    test('un radio grande incluye a más restaurantes y excluye a los sin coordenadas', () async {
      final lista = await svc.getActiveRestaurantsByRadius(
          userLatitude: 19.4326, userLongitude: -99.1332, radiusKm: 2000);
      expect(lista.map((r) => r.nombre), ['Cerca', 'Medio', 'Lejos']);
    });

    test('rechaza radios no positivos y coordenadas inválidas', () async {
      await expectLater(
        svc.getActiveRestaurantsByRadius(userLatitude: 19, userLongitude: -99, radiusKm: 0),
        throwsA(isA<ControlledRestaurantQueryException>()),
      );
      await expectLater(
        svc.getActiveRestaurantsByRadius(userLatitude: 200, userLongitude: -99, radiusKm: 5),
        throwsA(isA<ControlledRestaurantQueryException>()),
      );
    });

    test('la versión segura convierte los errores en un resultado fallido', () async {
      final r = await svc.getActiveRestaurantsByRadiusResult(
          userLatitude: 19, userLongitude: -99, radiusKm: -1);
      expect(r.hasError, isTrue);
      expect(r.errorMessage, isNotEmpty);
      final ok = await svc.getActiveRestaurantsByRadiusResult(
          userLatitude: 19.4326, userLongitude: -99.1332, radiusKm: 20);
      expect(ok.hasError, isFalse);
    });

    test('con distancia devuelve cada restaurante con sus km', () async {
      final lista = await svc.getRestaurantsWithDistanceByRadius(
          userLatitude: 19.4326, userLongitude: -99.1332, radiusKm: 20);
      expect(lista, hasLength(2));
      expect(lista.first.distanceKm, lessThan(lista.last.distanceKm));
    });

    test('el stream por radio filtra y con datos inválidos emite vacío', () async {
      final bien = await svc
          .getActiveRestaurantsByRadiusStream(userLatitude: 19.4326, userLongitude: -99.1332, radiusKm: 20)
          .first;
      expect(bien.map((r) => r.nombre), ['Cerca', 'Medio']);
      final mal = await svc
          .getActiveRestaurantsByRadiusStream(userLatitude: 19.4326, userLongitude: -99.1332, radiusKm: 0)
          .first;
      expect(mal, isEmpty);
    });
  });

  group('Por fecha y hora (HU03-RF01)', () {
    setUp(() async {
      await db.collection('restaurants').doc('abierto').set(restaurante('Abierto', capacidad: 10));
      await db.collection('restaurants').doc('lunes').set(restaurante('SoloLunes', dias: ['lunes']));
      await db.collection('restaurants').doc('cierre').set(
          restaurante('Cierre', cierres: ['2026-11-05']));
    });

    test('devuelve solo los abiertos ese día y hora, respetando los cierres especiales', () async {
      final lista = await svc.getRestaurantsByDateTime(dateTime: _jueves14);
      expect(lista.map((r) => r.nombre), ['Abierto']);
    });

    test('fuera de horario no devuelve ninguno', () async {
      expect(await svc.getRestaurantsByDateTime(dateTime: DateTime(2026, 11, 5, 8)), isEmpty);
      expect(await svc.getRestaurantsByDateTime(dateTime: DateTime(2026, 11, 5, 23)), isEmpty);
    });

    test('excluye al restaurante sin lugares para el grupo en ese horario', () async {
      await reservar('abierto', 8);
      expect(await svc.getRestaurantsByDateTime(dateTime: _jueves14, partySize: 2), hasLength(1));
      expect(await svc.getRestaurantsByDateTime(dateTime: _jueves14, partySize: 3), isEmpty);
    });

    test('las reservas canceladas o de otro horario no ocupan lugares', () async {
      await reservar('abierto', 9, estado: 'cancelada');
      await reservar('abierto', 9, inicio: DateTime(2026, 11, 5, 19));
      expect(await svc.getRestaurantsByDateTime(dateTime: _jueves14, partySize: 10), hasLength(1));
    });

    test('rechaza grupos y duraciones inválidos', () async {
      await expectLater(svc.getRestaurantsByDateTime(dateTime: _jueves14, partySize: 0),
          throwsA(isA<ControlledRestaurantQueryException>()));
      await expectLater(svc.getRestaurantsByDateTime(dateTime: _jueves14, durationMin: 0),
          throwsA(isA<ControlledRestaurantQueryException>()));
      final r = await svc.getRestaurantsByDateTimeResult(dateTime: _jueves14, partySize: -1);
      expect(r.hasError, isTrue);
    });

    test('el stream reacciona a las nuevas reservas', () async {
      final emitidos = <int>[];
      final sub = svc
          .getRestaurantsByDateTimeStream(dateTime: _jueves14, partySize: 5)
          .listen((l) => emitidos.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(emitidos.first, 1);
    });

    test('capacidad restante y disponibilidad de un restaurante', () async {
      expect(await svc.getRemainingCapacity(restaurantId: 'abierto', dateTime: _jueves14), 10);
      await reservar('abierto', 4);
      expect(await svc.getRemainingCapacity(restaurantId: 'abierto', dateTime: _jueves14), 6);
      expect(await svc.checkRestaurantAvailability(restaurantId: 'abierto', dateTime: _jueves14, partySize: 6),
          isTrue);
      expect(await svc.checkRestaurantAvailability(restaurantId: 'abierto', dateTime: _jueves14, partySize: 7),
          isFalse);
    });

    test('capacidad cero si no existe, está inactivo, cerrado o sin capacidad', () async {
      expect(await svc.getRemainingCapacity(restaurantId: 'nada', dateTime: _jueves14), 0);
      await db.collection('restaurants').doc('off').set(restaurante('Off', estado: 'inactivo'));
      expect(await svc.getRemainingCapacity(restaurantId: 'off', dateTime: _jueves14), 0);
      expect(await svc.getRemainingCapacity(restaurantId: 'lunes', dateTime: _jueves14), 0);
      await db.collection('restaurants').doc('sincap').set(restaurante('SinCap', capacidad: null));
      expect(await svc.getRemainingCapacity(restaurantId: 'sincap', dateTime: _jueves14), 0);
    });
  });

  group('Por capacidad (HU04-RF01)', () {
    setUp(() async {
      await db.collection('restaurants').doc('chico').set(restaurante('Chico', capacidad: 4));
      await db.collection('restaurants').doc('grande').set(restaurante('Grande', capacidad: 40));
      await db.collection('restaurants').doc('sin').set(restaurante('SinCapacidad', capacidad: null));
    });

    test('devuelve los que pueden atender al grupo y omite a los sin capacidad', () async {
      expect((await svc.getRestaurantsByCapacity(partySize: 2)).map((r) => r.nombre), ['Chico', 'Grande']);
      expect((await svc.getRestaurantsByCapacity(partySize: 10)).map((r) => r.nombre), ['Grande']);
      expect(await svc.getRestaurantsByCapacity(partySize: 100), isEmpty);
    });

    test('un grupo de 0 o negativo no devuelve nada', () async {
      expect(await svc.getRestaurantsByCapacity(partySize: 0), isEmpty);
      expect(await svc.getRestaurantsByCapacity(partySize: -2), isEmpty);
    });

    test('con fecha y hora descuenta lo ocupado', () async {
      await reservar('grande', 35);
      expect((await svc.getRestaurantsByCapacity(partySize: 10, dateTime: _jueves14)).map((r) => r.nombre),
          isEmpty);
      // Grande conserva 5 lugares: alcanza para 4 pero no para 6.
      expect((await svc.getRestaurantsByCapacity(partySize: 4, dateTime: _jueves14)).map((r) => r.nombre),
          ['Chico', 'Grande']);
      expect(await svc.getRestaurantsByCapacity(partySize: 6, dateTime: _jueves14), isEmpty);
    });

    test('la versión segura y el stream funcionan', () async {
      expect((await svc.getRestaurantsByCapacityResult(partySize: 2)).hasError, isFalse);
      final l = await svc.getRestaurantsByCapacityStream(partySize: 10).first;
      expect(l.map((r) => r.nombre), ['Grande']);
    });
  });

  group('Detalle y menú (HU05, HU06)', () {
    Future<void> menu() async {
      await db.collection('restaurants').doc('r1').set(restaurante('Miel'));
      final r = db.collection('restaurants').doc('r1');
      await r.collection('categorias').doc('c2').set({'nombre': 'Postres', 'orden': 2});
      await r.collection('categorias').doc('c1').set({'nombre': 'Entradas', 'orden': 1});
      await r.collection('categorias').doc('c3').set({'nombre': 'Vacía', 'orden': 3});
      Map<String, dynamic> p(String n, String cat, String estado, int orden) =>
          {'nombre': n, 'categoriaId': cat, 'estado': estado, 'precio': 50, 'orden': orden};
      await r.collection('platillos').add(p('Flan', 'c2', 'activo', 1));
      await r.collection('platillos').add(p('Sopa', 'c1', 'activo', 2));
      await r.collection('platillos').add(p('Ensalada', 'c1', 'activo', 1));
      await r.collection('platillos').add(p('Agotado', 'c1', 'agotado', 3));
      await r.collection('platillos').add(p('Oculto', 'c1', 'inactivo', 4));
      await r.collection('platillos').add(p('Huérfano', 'zz', 'activo', 1));
    }

    test('el detalle trae el menú por categorías ordenadas, sin los inactivos', () async {
      await menu();
      final d = await svc.getRestaurantDetail('r1');
      expect(d.nombre, 'Miel');
      expect(d.menu.map((m) => m.nombre), ['Entradas', 'Postres', 'Vacía', 'Otros']);
      final entradas = d.menu.first.platillos.map((p) => p.nombre).toList();
      expect(entradas, ['Ensalada', 'Sopa', 'Agotado']);
      expect(d.menu.last.platillos.single.nombre, 'Huérfano');
    });

    test('para el administrador incluye también los inactivos', () async {
      await menu();
      final d = await svc.getRestaurantDetail('r1', soloPlatillosVisibles: false);
      expect(d.menu.first.platillos.map((p) => p.nombre), contains('Oculto'));
    });

    test('el detalle falla de forma controlada si no existe o está inactivo', () async {
      await expectLater(svc.getRestaurantDetail('nada'),
          throwsA(isA<ControlledRestaurantQueryException>()));
      await db.collection('restaurants').doc('off').set(restaurante('Off', estado: 'inactivo'));
      await expectLater(svc.getRestaurantDetail('off'),
          throwsA(isA<ControlledRestaurantQueryException>()));
      final r = await svc.getRestaurantDetailResult('nada');
      expect(r.isSuccess, isFalse);
      expect(r.errorMessage, contains('no existe'));
    });

    test('el menú solo muestra los platillos activos y puede ocultar las categorías vacías', () async {
      await menu();
      var m = await svc.getMenuByCategories('r1');
      expect(m.map((c) => c.nombre), ['Entradas', 'Postres', 'Vacía', 'Otros']);
      expect(m.first.platillos.map((p) => p.nombre), ['Ensalada', 'Sopa']);
      m = await svc.getMenuByCategories('r1', ocultarCategoriasVacias: true);
      expect(m.map((c) => c.nombre), ['Entradas', 'Postres', 'Otros']);
      m = await svc.getMenuByCategories('r1', soloDisponibles: false);
      expect(m.first.platillos, hasLength(4));
    });

    test('sin menú, sin restaurante, inactivo o con id vacío devuelve lista vacía', () async {
      expect(await svc.getMenuByCategories(' '), isEmpty);
      expect(await svc.getMenuByCategories('nada'), isEmpty);
      await db.collection('restaurants').doc('vacio').set(restaurante('Vacío'));
      expect(await svc.getMenuByCategories('vacio'), isEmpty);
      await db.collection('restaurants').doc('off').set(restaurante('Off', estado: 'inactivo'));
      expect(await svc.getMenuByCategories('off'), isEmpty);
      expect((await svc.getMenuByCategoriesResult('vacio')).isSuccess, isTrue);
    });

    test('agruparMenu ordena categorías y platillos', () {
      final cats = [
        const CategoriaModel(id: 'b', nombre: 'B', nombreNormalizado: 'b', orden: 2),
        const CategoriaModel(id: 'a', nombre: 'A', nombreNormalizado: 'a', orden: 1),
      ];
      PlatilloModel p(String n, String c, int o) =>
          PlatilloModel(id: n, categoriaId: c, nombre: n, descripcion: '', precio: 5, orden: o);
      final m = RestaurantService.agruparMenu(
          categorias: cats, platillos: [p('x2', 'a', 2), p('x1', 'a', 1), p('y', 'b', 1)]);
      expect(m.map((c) => c.categoriaId), ['a', 'b']);
      expect(m.first.platillos.map((x) => x.id), ['x1', 'x2']);
      expect(m.first.totalPlatillos, 2);
      expect(m.first.isNotEmpty, isTrue);
    });

    test('el stream del menú emite la agrupación', () async {
      await menu();
      final m = await svc.getMenuByCategoriesStream('r1').first;
      expect(m.first.nombre, 'Entradas');
    });
  });
}

void horariosTests() {
  test('los horarios se muestran de lunes a domingo aunque lleguen desordenados', () {
    const d = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');
    final orden = ScheduleUtils.sortedSchedule({
      'miercoles': d,
      'jueves': d,
      'domingo': d,
      'Lunes': d,
      'martes': d,
      'extraño': d,
      'sábado': d,
    }).map((e) => e.key).toList();
    expect(orden, ['Lunes', 'martes', 'miercoles', 'jueves', 'sábado', 'domingo', 'extraño']);
  });
}
