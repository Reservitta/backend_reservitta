import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/table_layout_validator.dart';
import 'package:reservitta/models/zona_model.dart';
import 'package:reservitta/services/table_layout_service.dart';

MesaModel mesa(
  String nombre, {
  String id = '',
  int capacidad = 4,
  String forma = 'cuadrada',
  double ancho = 100,
  double alto = 100,
  double x = 20,
  double y = 20,
  String? zonaId,
  bool combinable = false,
  List<String> combinableCon = const [],
}) =>
    MesaModel(
      id: id,
      nombre: nombre,
      capacidad: capacidad,
      forma: forma,
      ancho: ancho,
      alto: alto,
      x: x,
      y: y,
      zonaId: zonaId,
      combinable: combinable,
      combinableCon: combinableCon,
    );

void main() {
  setUpAll(() => FakeFirebaseFirestore());
  idsProvisionalesTests();

  group('Nombres de espacios (HU34-RF01)', () {
    const existentes = [
      ZonaModel(id: 'z1', nombre: 'Planta baja', orden: 1),
      ZonaModel(id: 'z2', nombre: 'Terraza', orden: 2),
    ];

    test('exige nombre y largo razonable', () {
      expect(TableLayoutValidator.validarNombreZona('', existentes), isNotNull);
      expect(TableLayoutValidator.validarNombreZona('   ', existentes), isNotNull);
      expect(TableLayoutValidator.validarNombreZona('A', existentes), contains('al menos 2'));
      expect(TableLayoutValidator.validarNombreZona('x' * 41, existentes), contains('40'));
      expect(TableLayoutValidator.validarNombreZona('Patio', existentes), isNull);
    });

    test('no repite nombres sin importar mayúsculas, acentos ni espacios', () {
      expect(TableLayoutValidator.validarNombreZona('planta  BAJA', existentes), contains('Ya existe'));
      expect(TableLayoutValidator.validarNombreZona('TERRAZA', existentes), contains('Ya existe'));
      expect(TableLayoutValidator.validarNombreZona('Térraza', existentes), contains('Ya existe'));
    });

    test('al renombrar puede conservar su propio nombre', () {
      expect(TableLayoutValidator.validarNombreZona('Terraza', existentes, ignorarId: 'z2'), isNull);
      expect(TableLayoutValidator.validarNombreZona('Planta baja', existentes, ignorarId: 'z2'),
          contains('Ya existe'));
    });
  });

  group('Validación de una mesa (HU34-RF02)', () {
    Map<String, String> validar(MesaModel m, {List<MesaModel> otras = const [], Set<String> zonas = const {}}) =>
        TableLayoutValidator.validarMesa(m, otras: otras, zonaIds: zonas);

    test('una mesa correcta no tiene errores', () {
      expect(validar(mesa('Mesa 1')), isEmpty);
    });

    test('el nombre es obligatorio y tiene un máximo', () {
      expect(validar(mesa('  '))['nombre'], isNotNull);
      expect(validar(mesa('x' * 31))['nombre'], contains('30'));
    });

    test('el nombre no se repite en el restaurante', () {
      final otras = [mesa('Mesa 1', id: 'a')];
      expect(validar(mesa('mesa 1', id: 'b'), otras: otras)['nombre'], contains('Ya hay'));
      expect(validar(mesa('Mesa 1', id: 'a'), otras: otras), isEmpty);
    });

    test('la capacidad va de 1 a 50 sillas', () {
      expect(validar(mesa('M', capacidad: 0))['capacidad'], isNotNull);
      expect(validar(mesa('M', capacidad: -3))['capacidad'], isNotNull);
      expect(validar(mesa('M', capacidad: 51))['capacidad'], isNotNull);
      expect(validar(mesa('M', capacidad: 1)), isEmpty);
      expect(validar(mesa('M', capacidad: 50)), isEmpty);
    });

    test('la forma y el tamaño tienen límites', () {
      expect(validar(mesa('M', forma: 'triangular'))['forma'], isNotNull);
      expect(validar(mesa('M', ancho: 39))['ancho'], isNotNull);
      expect(validar(mesa('M', ancho: 301))['ancho'], isNotNull);
      expect(validar(mesa('M', alto: 10))['alto'], isNotNull);
      expect(validar(mesa('M', ancho: 40, alto: 300)), isEmpty);
    });

    test('la posición no puede ser negativa ni faltar', () {
      expect(validar(mesa('M', x: -1))['x'], isNotNull);
      expect(validar(mesa('M', y: -1))['y'], isNotNull);
      expect(validar(const MesaModel(id: '', nombre: 'M', capacidad: 2))['x'], isNotNull);
    });

    test('el espacio debe existir', () {
      expect(validar(mesa('M', zonaId: 'z9'), zonas: {'z1'})['zona'], isNotNull);
      expect(validar(mesa('M', zonaId: 'z1'), zonas: {'z1'}), isEmpty);
      expect(validar(mesa('M')), isEmpty);
    });

    test('junta varios errores a la vez', () {
      final e = validar(mesa('', capacidad: 0, ancho: 5));
      expect(e.keys, containsAll(['nombre', 'capacidad', 'ancho']));
    });
  });

  group('Combinaciones entre mesas', () {
    test('la relación se hace simétrica', () {
      final r = TableLayoutValidator.normalizarCombinaciones([
        mesa('A', id: 'a', combinable: true, combinableCon: ['b']),
        mesa('B', id: 'b', combinable: true),
        mesa('C', id: 'c', combinable: true),
      ]);
      expect(r.firstWhere((m) => m.id == 'a').combinableCon, ['b']);
      expect(r.firstWhere((m) => m.id == 'b').combinableCon, ['a']);
      expect(r.firstWhere((m) => m.id == 'c').combinableCon, isEmpty);
    });

    test('se quitan referencias a mesas que no existen o a sí misma', () {
      final r = TableLayoutValidator.normalizarCombinaciones([
        mesa('A', id: 'a', combinable: true, combinableCon: ['a', 'zz']),
      ]);
      expect(r.single.combinableCon, isEmpty);
    });

    test('una mesa no combinable no se une a ninguna', () {
      final r = TableLayoutValidator.normalizarCombinaciones([
        mesa('A', id: 'a', combinable: true, combinableCon: ['b']),
        mesa('B', id: 'b', combinable: false),
      ]);
      expect(r.first.combinableCon, isEmpty);
      expect(r.last.combinableCon, isEmpty);
    });
  });

  group('Colocación en el plano', () {
    test('el primer lugar libre evita empalmar mesas', () {
      final lugar = TableLayoutValidator.primerLugarLibre(
        existentes: [mesa('A', x: 20, y: 20)],
        ancho: 100,
        alto: 100,
      );
      expect(lugar.x >= 140 || lugar.y >= 140, isTrue, reason: '${lugar.x},${lugar.y}');
    });

    test('sin mesas empieza arriba a la izquierda', () {
      final lugar =
          TableLayoutValidator.primerLugarLibre(existentes: const [], ancho: 100, alto: 100);
      expect((x: lugar.x, y: lugar.y), (x: 20.0, y: 20.0));
    });

    test('alinear ajusta a la cuadrícula', () {
      expect(TableLayoutValidator.alinear(23), 20);
      expect(TableLayoutValidator.alinear(26), 30);
      expect(TableLayoutValidator.alinear(0), 0);
    });
  });

  group('Espacios en Firestore', () {
    late FakeFirebaseFirestore db;
    late TableLayoutService svc;

    setUp(() {
      db = FakeFirebaseFirestore();
      svc = TableLayoutService(firestore: db, now: () => DateTime(2026, 11, 8, 12));
    });

    test('crea espacios con orden consecutivo', () async {
      await svc.crearZona('r1', 'Planta baja');
      await svc.crearZona('r1', 'Segundo piso');
      await svc.crearZona('r1', 'Patio');
      final zonas = await svc.getZonas('r1');
      expect(zonas.map((z) => z.nombre), ['Planta baja', 'Segundo piso', 'Patio']);
      expect(zonas.map((z) => z.orden), [1, 2, 3]);
    });

    test('rechaza nombres vacíos y repetidos sin guardar', () async {
      await svc.crearZona('r1', 'Patio');
      await expectLater(svc.crearZona('r1', ' '), throwsA(isA<LayoutException>()));
      await expectLater(
        svc.crearZona('r1', 'PATIO'),
        throwsA(isA<LayoutException>().having((e) => e.campos['nombre'], 'campo', isNotNull)),
      );
      expect(await svc.getZonas('r1'), hasLength(1));
    });

    test('el mismo nombre se permite en otro restaurante', () async {
      await svc.crearZona('r1', 'Patio');
      await svc.crearZona('r2', 'Patio');
      expect(await svc.getZonas('r2'), hasLength(1));
    });

    test('renombra y valida', () async {
      final z = await svc.crearZona('r1', 'Patio');
      await svc.crearZona('r1', 'Interior');
      await svc.renombrarZona('r1', z.id, 'Jardín');
      expect((await svc.getZonas('r1')).first.nombre, 'Jardín');
      await expectLater(svc.renombrarZona('r1', z.id, 'interior'), throwsA(isA<LayoutException>()));
      await expectLater(svc.renombrarZona('r1', z.id, ''), throwsA(isA<LayoutException>()));
    });

    test('reordena los espacios', () async {
      final a = await svc.crearZona('r1', 'Aa');
      final b = await svc.crearZona('r1', 'Bb');
      final c = await svc.crearZona('r1', 'Cc');
      await svc.reordenarZonas('r1', [c.id, a.id, b.id]);
      expect((await svc.getZonas('r1')).map((z) => z.nombre), ['Cc', 'Aa', 'Bb']);
    });

    test('no elimina un espacio con mesas y dice cuántas tiene', () async {
      final z = await svc.crearZona('r1', 'Patio');
      await svc.guardarPlano(
        restauranteId: 'r1',
        mesas: [mesa('M1', zonaId: z.id), mesa('M2', zonaId: z.id, x: 200)],
      );
      await expectLater(
        svc.eliminarZona('r1', z.id),
        throwsA(isA<LayoutException>().having((e) => e.message, 'msg', contains('2 mesas'))),
      );
      expect(await svc.getZonas('r1'), hasLength(1));
    });

    test('elimina un espacio vacío', () async {
      final z = await svc.crearZona('r1', 'Patio');
      await svc.eliminarZona('r1', z.id);
      expect(await svc.getZonas('r1'), isEmpty);
    });

    test('el stream refleja los cambios en tiempo real', () async {
      final emitidos = <int>[];
      final sub = svc.zonasStream('r1').listen((l) => emitidos.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await svc.crearZona('r1', 'Patio');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(emitidos.first, 0);
      expect(emitidos.last, 1);
    });
  });

  group('Guardar el plano de mesas', () {
    late FakeFirebaseFirestore db;
    late TableLayoutService svc;

    setUp(() {
      db = FakeFirebaseFirestore();
      svc = TableLayoutService(firestore: db, now: () => DateTime(2026, 11, 8, 12));
    });

    Future<void> reserva(String id, List<String> mesas, {DateTime? inicio, String estado = 'confirmada'}) {
      final i = inicio ?? DateTime(2026, 11, 10, 14);
      return db.collection('reservations').doc(id).set({
        'restauranteId': 'r1',
        'fechaLocal': '2026-11-10',
        'inicio': Timestamp.fromDate(i),
        'fin': Timestamp.fromDate(i.add(const Duration(minutes: 90))),
        'duracionMin': 90,
        'personas': 2,
        'mesaIds': mesas,
        'estado': estado,
      });
    }

    test('crea mesas nuevas con su forma, capacidad y posición', () async {
      final r = await svc.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('Mesa 1', forma: 'redonda', capacidad: 6, x: 40, y: 60),
        mesa('Mesa 2', forma: 'rectangular', ancho: 200, alto: 80, x: 200, y: 60),
      ]);
      expect(r.creadas, 2);
      expect(r.mesas.every((m) => m.id.isNotEmpty), isTrue);
      final guardadas = await svc.getMesas('r1');
      final m1 = guardadas.firstWhere((m) => m.nombre == 'Mesa 1');
      expect(m1.forma, 'redonda');
      expect(m1.capacidad, 6);
      expect((m1.x, m1.y), (40.0, 60.0));
      expect(guardadas.firstWhere((m) => m.nombre == 'Mesa 2').ancho, 200);
    });

    test('guarda a qué espacio pertenece cada mesa', () async {
      final piso = await svc.crearZona('r1', 'Segundo piso');
      final patio = await svc.crearZona('r1', 'Patio');
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zonaId: piso.id),
        mesa('P1', zonaId: patio.id),
      ]);
      final mesas = await svc.getMesas('r1');
      expect(mesas.firstWhere((m) => m.nombre == 'A1').zonaId, piso.id);
      expect(mesas.firstWhere((m) => m.nombre == 'P1').zonaId, patio.id);
    });

    test('actualiza lo que cambió y elimina lo que ya no está', () async {
      final primero = await svc.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('Mesa 1'),
        mesa('Mesa 2', x: 200),
        mesa('Mesa 3', x: 400),
      ]);
      final m1 = primero.mesas.firstWhere((m) => m.nombre == 'Mesa 1');
      final m2 = primero.mesas.firstWhere((m) => m.nombre == 'Mesa 2');
      final r = await svc.guardarPlano(restauranteId: 'r1', mesas: [
        m1.copyWith(nombre: 'Barra 1', capacidad: 6, x: 80),
        m2,
        mesa('Mesa 4', x: 600),
      ]);
      expect((r.creadas, r.actualizadas, r.eliminadas), (1, 2, 1));
      final nombres = (await svc.getMesas('r1')).map((m) => m.nombre).toSet();
      expect(nombres, {'Barra 1', 'Mesa 2', 'Mesa 4'});
    });

    test('es todo o nada: si una mesa es inválida no se guarda ninguna', () async {
      await expectLater(
        svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('Buena'), mesa('Mala', capacidad: 0)]),
        throwsA(isA<LayoutException>().having((e) => e.message, 'msg', contains('Mala'))),
      );
      expect(await svc.getMesas('r1'), isEmpty);
    });

    test('rechaza nombres repetidos entre las mesas del plano', () async {
      await expectLater(
        svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('Mesa 1'), mesa('mesa 1', x: 200)]),
        throwsA(isA<LayoutException>().having((e) => e.message, 'msg', contains('Ya hay'))),
      );
    });

    test('rechaza una mesa de un espacio que no existe', () async {
      await expectLater(
        svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('M1', zonaId: 'fantasma')]),
        throwsA(isA<LayoutException>()),
      );
    });

    test('las combinaciones quedan simétricas al guardar', () async {
      final a = mesa('A');
      final b = mesa('B', x: 200);
      final r1 = await svc.guardarPlano(restauranteId: 'r1', mesas: [a, b]);
      final ida = r1.mesas.firstWhere((m) => m.nombre == 'A').id;
      final idb = r1.mesas.firstWhere((m) => m.nombre == 'B').id;
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        r1.mesas.firstWhere((m) => m.nombre == 'A').copyWith(combinable: true, combinableCon: [idb]),
        r1.mesas.firstWhere((m) => m.nombre == 'B').copyWith(combinable: true),
      ]);
      final guardadas = await svc.getMesas('r1');
      expect(guardadas.firstWhere((m) => m.id == idb).combinableCon, [ida]);
    });

    test('al borrar una mesa se limpia su combinación en las demás', () async {
      final r1 = await svc.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A', combinable: true),
        mesa('B', x: 200, combinable: true),
      ]);
      final a = r1.mesas.firstWhere((m) => m.nombre == 'A');
      final b = r1.mesas.firstWhere((m) => m.nombre == 'B');
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        a.copyWith(combinableCon: [b.id]),
        b.copyWith(combinableCon: [a.id]),
      ]);
      await svc.guardarPlano(restauranteId: 'r1', mesas: [a.copyWith(combinableCon: [b.id])]);
      expect((await svc.getMesas('r1')).single.combinableCon, isEmpty);
    });

    test('no borra una mesa con una reserva activa a futuro', () async {
      final r = await svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('M1'), mesa('M2', x: 200)]);
      final m1 = r.mesas.firstWhere((m) => m.nombre == 'M1');
      await reserva('res1', [m1.id]);
      await expectLater(
        svc.guardarPlano(restauranteId: 'r1', mesas: [r.mesas.firstWhere((m) => m.nombre == 'M2')]),
        throwsA(isA<LayoutException>().having((e) => e.message, 'msg', allOf(contains('M1'), contains('1 reserva')))),
      );
      expect(await svc.getMesas('r1'), hasLength(2));
    });

    test('sí borra una mesa cuyas reservas ya pasaron o se cancelaron', () async {
      final r = await svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('M1'), mesa('M2', x: 200)]);
      final m1 = r.mesas.firstWhere((m) => m.nombre == 'M1');
      await reserva('pasada', [m1.id], inicio: DateTime(2026, 11, 1, 14));
      await reserva('cancelada', [m1.id], estado: 'cancelada');
      await svc.guardarPlano(restauranteId: 'r1', mesas: [r.mesas.firstWhere((m) => m.nombre == 'M2')]);
      expect(await svc.getMesas('r1'), hasLength(1));
    });

    test('no baja la capacidad de una mesa con reservas activas pero sí la sube', () async {
      final r = await svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('M1', capacidad: 6)]);
      final m1 = r.mesas.single;
      await reserva('res1', [m1.id]);
      await expectLater(
        svc.guardarPlano(restauranteId: 'r1', mesas: [m1.copyWith(capacidad: 4)]),
        throwsA(isA<LayoutException>().having((e) => e.message, 'msg', contains('no puede bajar'))),
      );
      await svc.guardarPlano(restauranteId: 'r1', mesas: [m1.copyWith(capacidad: 8)]);
      expect((await svc.getMesas('r1')).single.capacidad, 8);
    });

    test('mover una mesa con reservas está permitido', () async {
      final r = await svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('M1')]);
      await reserva('res1', [r.mesas.single.id]);
      await svc.guardarPlano(restauranteId: 'r1', mesas: [r.mesas.single.copyWith(x: 300, y: 300)]);
      expect((await svc.getMesas('r1')).single.x, 300);
    });

    test('un plano vacío borra todas las mesas sin reservas', () async {
      await svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('M1')]);
      final r = await svc.guardarPlano(restauranteId: 'r1', mesas: const []);
      expect(r.eliminadas, 1);
      expect(await svc.getMesas('r1'), isEmpty);
    });

    test('las mesas de un restaurante no afectan a otro', () async {
      await svc.guardarPlano(restauranteId: 'r1', mesas: [mesa('M1')]);
      await svc.guardarPlano(restauranteId: 'r2', mesas: [mesa('M1')]);
      expect(await svc.getMesas('r1'), hasLength(1));
      expect(await svc.getMesas('r2'), hasLength(1));
    });
  });
}

void idsProvisionalesTests() {
  group('Mesas nuevas con id provisional', () {
    test('las combinaciones entre mesas nuevas se conservan al guardar', () async {
      final db = FakeFirebaseFirestore();
      final svc = TableLayoutService(firestore: db);
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A', id: 'tmp_1', combinable: true, combinableCon: ['tmp_2']),
        mesa('B', id: 'tmp_2', x: 200, combinable: true, combinableCon: ['tmp_1']),
      ]);
      final guardadas = await svc.getMesas('r1');
      final a = guardadas.firstWhere((m) => m.nombre == 'A');
      final b = guardadas.firstWhere((m) => m.nombre == 'B');
      expect(a.id.startsWith('tmp_'), isFalse);
      expect(a.combinableCon, [b.id]);
      expect(b.combinableCon, [a.id]);
    });
  });
}
