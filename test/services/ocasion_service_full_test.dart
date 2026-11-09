import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/experiencia_model.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/services/ocasion_service.dart';

ExperienciaModel exp(String nombre, double precio, {String id = '', int orden = 0, bool activo = true}) =>
    ExperienciaModel(id: id, nombre: nombre, precio: precio, orden: orden, activo: activo);

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  late OcasionService svc;

  setUp(() {
    db = FakeFirebaseFirestore();
    svc = OcasionService(firestore: db);
  });

  group('Validación (HU33-RF01)', () {
    test('exige restaurante, nombre y al menos una experiencia', () {
      expect(
          () => OcasionService.validarOcasion(
              restaurantId: ' ', nombre: 'Cumpleaños', experiencias: [exp('Pastel', 0)]),
          throwsArgumentError);
      expect(
          () => OcasionService.validarOcasion(
              restaurantId: 'r1', nombre: ' ', experiencias: [exp('Pastel', 0)]),
          throwsArgumentError);
      expect(
          () => OcasionService.validarOcasion(
              restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: const []),
          throwsArgumentError);
    });

    test('cada experiencia necesita nombre y no puede tener precio negativo', () {
      expect(
          () => OcasionService.validarOcasion(
              restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: [exp(' ', 5)]),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'mensaje', contains('#1'))));
      expect(
          () => OcasionService.validarOcasion(
              restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: [exp('Pastel', -1)]),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'mensaje', contains('negativo'))));
      OcasionService.validarOcasion(
          restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: [exp('Pastel', 0)]);
    });

    test('una validación fallida no guarda nada', () async {
      await expectLater(
        svc.crearOcasion(restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: const []),
        throwsArgumentError,
      );
      expect((await db.collection('restaurants').doc('r1').collection('ocasiones').get()).docs,
          isEmpty);
    });
  });

  group('Crear', () {
    test('guarda la ocasión con su ícono y las experiencias en el documento y la subcolección', () async {
      final id = await svc.crearOcasion(
        restaurantId: 'r1',
        nombre: 'Cumpleaños',
        descripcion: '  Fiesta ',
        experiencias: [exp('Pastel', 0), exp('Música', 150)],
      );
      final doc = await db.collection('restaurants').doc('r1').collection('ocasiones').doc(id).get();
      final d = doc.data()!;
      expect(d['nombre'], 'Cumpleaños');
      expect(d['tipoPredefinido'], 'Cumpleaños');
      expect(d['icono'], 'cake');
      expect(d['descripcion'], 'Fiesta');
      expect(d['activo'], isTrue);
      expect((d['experiencias'] as List), hasLength(2));
      final sub = await doc.reference.collection('experiencias').get();
      expect(sub.docs, hasLength(2));
    });

    test('una experiencia con precio 0 se marca gratis y las demás no', () async {
      final id = await svc.crearOcasion(
        restaurantId: 'r1',
        nombre: 'Aniversario',
        experiencias: [exp('Flor', 0), exp('Música', 150)],
      );
      final o = (await svc.getOcasiones('r1')).single;
      expect(o.id, id);
      final porNombre = {for (final e in o.experiencias) e.nombre: e};
      expect(porNombre['Flor']!.esGratis, isTrue);
      expect(porNombre['Música']!.esGratis, isFalse);
      expect(porNombre['Música']!.precioFormateado, contains('150'));
      expect(porNombre['Flor']!.precioFormateado, 'Gratis');
    });

    test('un nombre libre queda como tipo "Otro" con el ícono por defecto', () async {
      await svc.crearOcasion(
          restaurantId: 'r1', nombre: 'Despedida', experiencias: [exp('Brindis', 10)]);
      final o = (await svc.getOcasiones('r1')).single;
      expect(o.tipoPredefinido, 'Otro');
      expect(o.icono, 'celebration');
    });

    test('respeta un tipo e ícono indicados y asigna orden consecutivo', () async {
      await svc.crearOcasion(
        restaurantId: 'r1',
        nombre: 'Mi fiesta',
        tipoPredefinido: 'Graduación',
        icono: 'star',
        experiencias: [exp('A1', 1), exp('B1', 2)],
      );
      final o = (await svc.getOcasiones('r1')).single;
      expect(o.tipoPredefinido, 'Graduación');
      expect(o.icono, 'star');
      expect(o.experiencias.map((e) => e.orden).toSet(), {1, 2});
    });

    test('cada ocasión es de su restaurante', () async {
      await svc.crearOcasion(
          restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: [exp('Pastel', 0)]);
      expect(await svc.getOcasiones('r2'), isEmpty);
    });
  });

  group('Actualizar', () {
    Future<String> crear() => svc.crearOcasion(
          restaurantId: 'r1',
          nombre: 'Cumpleaños',
          experiencias: [exp('Pastel', 0), exp('Música', 150)],
        );

    test('edita nombre, descripción y experiencias y recalcula "Gratis"', () async {
      final id = await crear();
      final antes = (await svc.getOcasiones('r1')).single;
      await svc.actualizarOcasion(
        restaurantId: 'r1',
        ocasionId: id,
        nombre: 'Aniversario',
        descripcion: 'Nueva',
        experiencias: [
          antes.experiencias.first.copyWith(precio: 50),
          exp('Fotos', 0, id: 'temp_1'),
        ],
      );
      final o = (await svc.getOcasiones('r1')).single;
      expect(o.nombre, 'Aniversario');
      expect(o.icono, 'favorite');
      expect(o.descripcion, 'Nueva');
      expect(o.experiencias, hasLength(2));
      expect(o.experiencias.where((e) => e.nombre == 'Fotos').single.esGratis, isTrue);
      expect(o.experiencias.where((e) => e.precio == 50).single.esGratis, isFalse);
    });

    test('quita de la subcolección las experiencias que ya no están', () async {
      final id = await crear();
      final antes = (await svc.getOcasiones('r1')).single;
      await svc.actualizarOcasion(
        restaurantId: 'r1',
        ocasionId: id,
        nombre: 'Cumpleaños',
        experiencias: [antes.experiencias.first],
      );
      final sub = await db
          .collection('restaurants')
          .doc('r1')
          .collection('ocasiones')
          .doc(id)
          .collection('experiencias')
          .get();
      expect(sub.docs, hasLength(1));
    });

    test('rechaza datos inválidos', () async {
      final id = await crear();
      await expectLater(
          svc.actualizarOcasion(
              restaurantId: 'r1', ocasionId: id, nombre: '', experiencias: [exp('X1', 1)]),
          throwsArgumentError);
      await expectLater(
          svc.actualizarOcasion(
              restaurantId: 'r1', ocasionId: id, nombre: 'Cumpleaños', experiencias: const []),
          throwsArgumentError);
    });

    test('elimina una experiencia individual sin tocar las demás', () async {
      final id = await crear();
      final antes = (await svc.getOcasiones('r1')).single;
      final borrar = antes.experiencias.first;
      await svc.eliminarExperienciaIndividual(
          restaurantId: 'r1', ocasionId: id, experienciaId: borrar.id);
      final o = (await svc.getOcasiones('r1')).single;
      expect(o.experiencias.map((e) => e.id), isNot(contains(borrar.id)));
      expect(o.experiencias, hasLength(1));
    });

    test('eliminar una experiencia de una ocasión inexistente no falla', () async {
      await svc.eliminarExperienciaIndividual(
          restaurantId: 'r1', ocasionId: 'nada', experienciaId: 'x');
    });
  });

  group('Consultar, activar y eliminar', () {
    test('sin restaurante devuelve listas vacías', () async {
      expect(await svc.getOcasiones(' '), isEmpty);
      expect(await svc.getOcasionesStream(' ').first, isEmpty);
    });

    test('el stream refleja los cambios en tiempo real', () async {
      final emitidos = <int>[];
      final sub = svc.getOcasionesStream('r1').listen((l) => emitidos.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await svc.crearOcasion(
          restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: [exp('Pastel', 0)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(emitidos.first, 0);
      expect(emitidos.last, 1);
    });

    test('una ocasión desactivada no aparece como disponible y se puede reactivar', () async {
      final id = await svc.crearOcasion(
          restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: [exp('Pastel', 0)]);
      await svc.toggleOcasionActiva(restaurantId: 'r1', ocasionId: id, nuevoEstado: false);
      expect(await svc.getOcasiones('r1'), isEmpty);
      expect(await svc.getOcasionesDisponibles('r1'), isEmpty);
      // El administrador la sigue viendo.
      expect(await svc.getOcasionesStream('r1').first, hasLength(1));
      await svc.toggleOcasionActiva(restaurantId: 'r1', ocasionId: id, nuevoEstado: true);
      expect(await svc.getOcasiones('r1'), hasLength(1));
    });

    test('las disponibles traen solo experiencias activas, ordenadas, y "Otro" al final', () async {
      await svc.crearOcasion(
          restaurantId: 'r1', nombre: 'Despedida', experiencias: [exp('Brindis', 10)]);
      final a = await svc.crearOcasion(
          restaurantId: 'r1',
          nombre: 'Aniversario',
          experiencias: [exp('Segundo', 5, orden: 2), exp('Primero', 5, orden: 1), exp('Oculto', 5, orden: 3)]);
      await svc.crearOcasion(
          restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: [exp('Pastel', 0)]);
      // Se oculta una experiencia.
      final doc = db.collection('restaurants').doc('r1').collection('ocasiones').doc(a);
      final data = (await doc.get()).data()!;
      final lista = [
        for (final e in data['experiencias'] as List)
          {...Map<String, dynamic>.from(e as Map), if (e['nombre'] == 'Oculto') 'activo': false},
      ];
      await doc.update({'experiencias': lista});

      final disp = await svc.getOcasionesDisponibles('r1');
      expect(disp.map((o) => o.nombre), ['Cumpleaños', 'Aniversario', 'Despedida']);
      final aniv = disp.firstWhere((o) => o.nombre == 'Aniversario');
      expect(aniv.experiencias.map((e) => e.nombre), ['Primero', 'Segundo']);
    });

    test('al eliminar una ocasión se borra también su subcolección', () async {
      final id = await svc.crearOcasion(
          restaurantId: 'r1', nombre: 'Cumpleaños', experiencias: [exp('Pastel', 0), exp('Vino', 90)]);
      await svc.eliminarOcasion(restaurantId: 'r1', ocasionId: id);
      expect(await svc.getOcasionesStream('r1').first, isEmpty);
      final sub = await db
          .collection('restaurants')
          .doc('r1')
          .collection('ocasiones')
          .doc(id)
          .collection('experiencias')
          .get();
      expect(sub.docs, isEmpty);
    });
  });

  group('Modelos', () {
    test('iconoPorNombre devuelve el ícono de cada ocasión predefinida', () {
      expect({for (final n in OcasionModel.nombresPredefinidos) OcasionModel.iconoPorNombre(n)},
          hasLength(OcasionModel.nombresPredefinidos.length));
      expect(OcasionModel.iconoPorNombre('Algo raro'), 'celebration');
    });

    test('fromMap deduce el tipo del nombre y tolera datos faltantes', () {
      final o = OcasionModel.fromMap('x', 'r1', {'nombre': 'Pedida'});
      expect(o.tipoPredefinido, 'Pedida');
      expect(o.activo, isTrue);
      expect(o.experiencias, isEmpty);
      expect(OcasionModel.fromMap('x', 'r1', {'nombre': 'Rara'}).tipoPredefinido, 'Otro');
      expect(OcasionModel.fromMap('x', 'r1', {}).nombre, '');
    });

    test('las experiencias embebidas se leen con su id', () {
      final o = OcasionModel.fromMap('x', 'r1', {
        'nombre': 'Cumpleaños',
        'experiencias': [
          {'id': 'e1', 'nombre': 'Pastel', 'precio': 0},
          {'nombre': 'Vino', 'precio': 90.5},
        ],
      });
      expect(o.experiencias.map((e) => e.id), ['e1', 'exp_1']);
      expect(o.experiencias.last.precio, 90.5);
      expect(o.experiencias.first.esGratis, isTrue);
    });

    test('"Postre con felicitación" se reconoce por tipo o por nombre', () {
      expect(const ExperienciaModel(id: 'a', nombre: 'X1', precio: 0, tipo: ExperienciaModel.tipoPostreFelicitacion)
              .requiereInformacion,
          isTrue);
      expect(const ExperienciaModel(id: 'a', nombre: 'Postre con felicitación', precio: 0)
              .esPostreConFelicitacion,
          isTrue);
      expect(const ExperienciaModel(id: 'a', nombre: 'Postre', precio: 0).esPostreConFelicitacion,
          isFalse);
      expect(const ExperienciaModel(id: 'a', nombre: 'Vino', precio: 9).requiereInformacion, isFalse);
    });
  });
}
