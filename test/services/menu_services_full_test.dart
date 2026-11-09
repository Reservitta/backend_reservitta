import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/services/storage_service.dart';

class _FakeStorage implements StorageService {
  int subidas = 0;
  bool falla = false;

  @override
  Future<String> uploadRestaurantImage({
    required String restaurantId,
    required String folder,
    required Uint8List imageBytes,
    String fileExtension = 'jpg',
  }) async {
    if (falla) throw Exception('sin red');
    subidas++;
    return 'https://cdn.test/$restaurantId/$folder/$subidas.$fileExtension';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlatilloModel platillo({
  String id = '',
  String nombre = 'Pasta',
  double precio = 120,
  String categoriaId = 'c1',
  String estado = 'activo',
  int orden = 1,
  String? imagen,
}) =>
    PlatilloModel(
      id: id,
      categoriaId: categoriaId,
      nombre: nombre,
      descripcion: 'Rica',
      precio: precio,
      estado: estado,
      orden: orden,
      imagenUrl: imagen,
    );

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  group('PlatilloModel', () {
    test('sin imagen usa la imagen por defecto', () {
      expect(platillo().imagenUrl, PlatilloModel.imagenPorDefecto);
      expect(platillo(imagen: '  ').imagenUrl, PlatilloModel.imagenPorDefecto);
      expect(platillo().tieneImagenEnNube, isFalse);
    });

    test('con una URL http(s) tiene imagen en la nube', () {
      expect(platillo(imagen: 'https://x.test/a.jpg').tieneImagenEnNube, isTrue);
      expect(platillo(imagen: 'http://x.test/a.jpg').tieneImagenEnNube, isTrue);
      expect(platillo(imagen: 'assets/a.png').tieneImagenEnNube, isFalse);
    });

    test('los estados activo, agotado e inactivo se distinguen', () {
      expect(platillo().isActivo, isTrue);
      expect(platillo().isDisponible, isTrue);
      expect(platillo(estado: 'agotado').isAgotado, isTrue);
      expect(platillo(estado: 'agotado').isDisponible, isFalse);
      expect(platillo(estado: 'inactivo').isInactivo, isTrue);
    });

    test('toMap y fromFirestore son consistentes', () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('p').doc('x');
      await ref.set(platillo(nombre: 'Sopa', precio: 80).copyWith(etiquetas: ['vegano']).toMap());
      final leido = PlatilloModel.fromFirestore(await ref.get());
      expect(leido.id, 'x');
      expect(leido.nombre, 'Sopa');
      expect(leido.precio, 80);
      expect(leido.etiquetas, ['vegano']);
      expect(leido.categoriaId, 'c1');
    });

    test('fromFirestore es tolerante con datos incompletos o inválidos', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('p').doc('x').set({'precio': -5, 'estado': 'raro'});
      final p = PlatilloModel.fromFirestore(await db.collection('p').doc('x').get());
      expect(p.nombre, 'Sin nombre');
      expect(p.precio, 0.01);
      expect(p.estado, 'activo');
      expect(p.orden, 1);
      expect(p.limiteCaracteresObs, 150);
      expect(p.permitePersonalizacion, isTrue);
    });

    test('la categoría puede venir como referencia o como texto', () async {
      final db = FakeFirebaseFirestore();
      final cat = db.collection('c').doc('cat9');
      await db.collection('p').doc('a').set({'categoriaId': cat});
      await db.collection('p').doc('b').set({'categoriaId': 'cat9'});
      await db.collection('p').doc('c').set({'categoriaId': 7});
      expect(PlatilloModel.fromFirestore(await db.collection('p').doc('a').get()).categoriaId, 'cat9');
      expect(PlatilloModel.fromFirestore(await db.collection('p').doc('b').get()).categoriaId, 'cat9');
      expect(PlatilloModel.fromFirestore(await db.collection('p').doc('c').get()).categoriaId, '');
    });

    group('toPreordenItemSnapshot', () {
      test('guarda cantidad, total, observación y felicitación recortadas', () {
        final p = platillo(id: 'p1', precio: 50);
        final s = p.toPreordenItemSnapshot(
            cantidad: 3, observacion: '  sin sal ', mensajeFelicitacion: ' feliz ');
        expect(s['platilloId'], 'p1');
        expect(s['cantidad'], 3);
        expect(s['total'], 150);
        expect(s['observacion'], 'sin sal');
        expect(s['mensajeFelicitacion'], 'feliz');
      });

      test('rechaza cantidades menores o iguales a cero', () {
        expect(() => platillo().toPreordenItemSnapshot(cantidad: 0), throwsArgumentError);
        expect(() => platillo().toPreordenItemSnapshot(cantidad: -1), throwsArgumentError);
      });

      test('rechaza observaciones que pasan el límite', () {
        final p = platillo().copyWith(limiteCaracteresObs: 5);
        expect(() => p.toPreordenItemSnapshot(cantidad: 1, observacion: '123456'),
            throwsArgumentError);
        expect(p.toPreordenItemSnapshot(cantidad: 1, observacion: '12345')['observacion'], '12345');
      });

      test('rechaza observaciones si el platillo no admite personalización', () {
        final p = platillo().copyWith(permitePersonalizacion: false);
        expect(() => p.toPreordenItemSnapshot(cantidad: 1, observacion: 'algo'),
            throwsArgumentError);
        expect(p.toPreordenItemSnapshot(cantidad: 1)['observacion'], '');
      });
    });

    test('copyWith conserva lo que no se cambia', () {
      final p = platillo(id: 'a', nombre: 'X', precio: 10).copyWith(nombre: 'Y');
      expect(p.nombre, 'Y');
      expect(p.id, 'a');
      expect(p.precio, 10);
    });
  });

  group('PlatilloService', () {
    late FakeFirebaseFirestore db;
    late _FakeStorage storage;
    late PlatilloService svc;

    setUp(() {
      db = FakeFirebaseFirestore();
      storage = _FakeStorage();
      svc = PlatilloService(firestore: db, storageService: storage);
    });

    test('crea un platillo y lo guarda con la imagen por defecto', () async {
      final id = await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo());
      final leido = await svc.getPlatilloById('r1', id);
      expect(leido!.nombre, 'Pasta');
      expect(leido.imagenUrl, PlatilloModel.imagenPorDefecto);
    });

    test('al crear con foto la sube y guarda su URL', () async {
      final id = await svc.crearPlatillo(
        restaurantId: 'r1',
        platillo: platillo(),
        imageBytes: Uint8List.fromList([1, 2, 3]),
        imageExtension: 'png',
      );
      expect(storage.subidas, 1);
      expect((await svc.getPlatilloById('r1', id))!.imagenUrl, 'https://cdn.test/r1/platillos/1.png');
    });

    test('si falla la subida de la foto no crea el platillo', () async {
      storage.falla = true;
      await expectLater(
        svc.crearPlatillo(
            restaurantId: 'r1', platillo: platillo(), imageBytes: Uint8List.fromList([1])),
        throwsException,
      );
      expect((await db.collection('restaurants').doc('r1').collection('platillos').get()).docs,
          isEmpty);
    });

    test('rechaza nombre vacío y precios inválidos', () async {
      for (final p in [platillo(nombre: ''), platillo(nombre: '   '), platillo(precio: 0), platillo(precio: -3)]) {
        await expectLater(svc.crearPlatillo(restaurantId: 'r1', platillo: p), throwsArgumentError,
            reason: '${p.nombre}/${p.precio}');
      }
      expect((await db.collection('restaurants').doc('r1').collection('platillos').get()).docs,
          isEmpty);
    });

    test('actualiza un platillo con sus nuevos datos', () async {
      final id = await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo());
      await svc.actualizarPlatillo(
        restaurantId: 'r1',
        platillo: platillo(id: id, nombre: 'Lasaña', precio: 150),
      );
      final leido = (await svc.getPlatilloById('r1', id))!;
      expect(leido.nombre, 'Lasaña');
      expect(leido.precio, 150);
    });

    test('al actualizar con foto nueva la sube', () async {
      final id = await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo());
      await svc.actualizarPlatillo(
        restaurantId: 'r1',
        platillo: platillo(id: id),
        imageBytes: Uint8List.fromList([9]),
      );
      expect((await svc.getPlatilloById('r1', id))!.tieneImagenEnNube, isTrue);
    });

    test('al actualizar rechaza nombre, precio o estado inválidos', () async {
      final id = await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo());
      await expectLater(
          svc.actualizarPlatillo(restaurantId: 'r1', platillo: platillo(id: id, nombre: '')),
          throwsArgumentError);
      await expectLater(
          svc.actualizarPlatillo(restaurantId: 'r1', platillo: platillo(id: id, precio: 0)),
          throwsArgumentError);
      await expectLater(
          svc.actualizarPlatillo(
              restaurantId: 'r1', platillo: PlatilloModel(
                id: id, categoriaId: 'c1', nombre: 'X', descripcion: '', precio: 5, estado: 'borrado')),
          throwsArgumentError);
    });

    test('cambia la disponibilidad y rechaza estados que no existen', () async {
      final id = await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo());
      await svc.toggleEstadoPlatillo(restaurantId: 'r1', platilloId: id, nuevoEstado: 'agotado');
      expect((await svc.getPlatilloById('r1', id))!.isAgotado, isTrue);
      await expectLater(
        svc.toggleEstadoPlatillo(restaurantId: 'r1', platilloId: id, nuevoEstado: 'volando'),
        throwsArgumentError,
      );
    });

    test('elimina un platillo y consultarlo devuelve null', () async {
      final id = await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo());
      await svc.eliminarPlatillo('r1', id);
      expect(await svc.getPlatilloById('r1', id), isNull);
      expect(await svc.getPlatilloById('r1', 'no-existe'), isNull);
    });

    test('los visitantes solo ven los activos y ordenados', () async {
      await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo(nombre: 'BB', orden: 2));
      await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo(nombre: 'AA', orden: 1));
      await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo(nombre: 'CC', estado: 'agotado'));
      await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo(nombre: 'DD', estado: 'inactivo'));
      final visibles = await svc.getPlatillosActivosStream('r1').first;
      expect(visibles.map((p) => p.nombre), ['AA', 'BB']);
      final todos = await svc.getAllPlatillosStream('r1').first;
      expect(todos, hasLength(4));
    });

    test('filtra por categoría y opcionalmente solo activos', () async {
      await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo(nombre: 'AA', categoriaId: 'c1'));
      await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo(nombre: 'BB', categoriaId: 'c2'));
      await svc.crearPlatillo(
          restaurantId: 'r1', platillo: platillo(nombre: 'CC', categoriaId: 'c1', estado: 'agotado'));
      expect((await svc.getPlatillosPorCategoriaStream('r1', 'c1').first).map((p) => p.nombre),
          unorderedEquals(['AA', 'CC']));
      expect(
          (await svc.getPlatillosPorCategoriaStream('r1', 'c1', soloActivos: true).first)
              .map((p) => p.nombre),
          ['AA']);
      expect(await svc.getPlatillosPorCategoriaStream('r1', 'zz').first, isEmpty);
    });

    test('los platillos de un restaurante no aparecen en otro', () async {
      await svc.crearPlatillo(restaurantId: 'r1', platillo: platillo());
      expect(await svc.getAllPlatillosStream('r2').first, isEmpty);
    });
  });

  group('CategoriaModel', () {
    test('normaliza nombres sin espacios extra y en minúsculas', () {
      expect(CategoriaModel.normalizarNombre('  Postres  '), 'postres');
    });

    test('fromFirestore completa los valores que faltan', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('c').doc('x').set({'nombre': 'Entradas'});
      final c = CategoriaModel.fromFirestore(await db.collection('c').doc('x').get());
      expect(c.nombreNormalizado, 'entradas');
      expect(c.orden, 0);
      expect(c.tipo, 'general');
      await db.collection('c').doc('y').set({});
      expect(CategoriaModel.fromFirestore(await db.collection('c').doc('y').get()).nombre,
          'Sin categoría');
    });

    test('toMap y copyWith', () {
      const c = CategoriaModel(id: 'a', nombre: 'X', nombreNormalizado: 'x', orden: 2);
      expect(c.toMap(), {'nombre': 'X', 'nombreNormalizado': 'x', 'orden': 2, 'tipo': 'general'});
      expect(c.copyWith(orden: 5, tipo: 'bebida').orden, 5);
      expect(c.copyWith(tipo: 'bebida').tipo, 'bebida');
      expect(c.copyWith().id, 'a');
    });
  });

  group('CategoriaService', () {
    late FakeFirebaseFirestore db;
    late CategoriaService svc;

    setUp(() {
      db = FakeFirebaseFirestore();
      svc = CategoriaService(firestore: db);
    });

    test('crea categorías con orden consecutivo', () async {
      await svc.crearCategoria(restaurantId: 'r1', nombre: 'Entradas');
      await svc.crearCategoria(restaurantId: 'r1', nombre: 'Postres', tipo: 'postre');
      final lista = await svc.getCategoriasStream('r1').first;
      expect(lista.map((c) => c.nombre), ['Entradas', 'Postres']);
      expect(lista.map((c) => c.orden), [1, 2]);
      expect(lista.last.tipo, 'postre');
    });

    test('respeta un orden indicado', () async {
      await svc.crearCategoria(restaurantId: 'r1', nombre: 'AA', orden: 7);
      expect((await svc.getCategoriasStream('r1').first).single.orden, 7);
    });

    test('rechaza nombres vacíos y duplicados sin importar mayúsculas', () async {
      await expectLater(svc.crearCategoria(restaurantId: 'r1', nombre: '  '), throwsArgumentError);
      await svc.crearCategoria(restaurantId: 'r1', nombre: 'Postres');
      await expectLater(
          svc.crearCategoria(restaurantId: 'r1', nombre: ' POSTRES '), throwsException);
      expect(await svc.getCategoriasStream('r1').first, hasLength(1));
    });

    test('el mismo nombre se permite en otro restaurante', () async {
      await svc.crearCategoria(restaurantId: 'r1', nombre: 'Postres');
      await svc.crearCategoria(restaurantId: 'r2', nombre: 'Postres');
      expect(await svc.getCategoriasStream('r2').first, hasLength(1));
    });

    test('existeNombreCategoria puede excluir a la propia categoría', () async {
      final id = await svc.crearCategoria(restaurantId: 'r1', nombre: 'Postres');
      expect(await svc.existeNombreCategoria(restaurantId: 'r1', nombre: 'postres'), isTrue);
      expect(await svc.existeNombreCategoria(restaurantId: 'r1', nombre: 'postres', excludeCategoriaId: id),
          isFalse);
      expect(await svc.existeNombreCategoria(restaurantId: 'r1', nombre: 'otra'), isFalse);
    });

    test('actualiza nombre y tipo; rechaza duplicados y vacíos', () async {
      final a = await svc.crearCategoria(restaurantId: 'r1', nombre: 'AA');
      await svc.crearCategoria(restaurantId: 'r1', nombre: 'BB');
      await svc.actualizarCategoria(
          restaurantId: 'r1', categoriaId: a, nuevoNombre: 'Aperitivos', nuevoTipo: 'entrada');
      var lista = await svc.getCategoriasStream('r1').first;
      expect(lista.first.nombre, 'Aperitivos');
      expect(lista.first.tipo, 'entrada');
      // Mantener su propio nombre no es un duplicado.
      await svc.actualizarCategoria(restaurantId: 'r1', categoriaId: a, nuevoNombre: 'aperitivos');
      await expectLater(
          svc.actualizarCategoria(restaurantId: 'r1', categoriaId: a, nuevoNombre: 'bb'),
          throwsException);
      await expectLater(
          svc.actualizarCategoria(restaurantId: 'r1', categoriaId: a, nuevoNombre: ''),
          throwsArgumentError);
      lista = await svc.getCategoriasStream('r1').first;
      expect(lista.first.nombre, 'aperitivos');
    });

    test('reordena en un solo lote', () async {
      final a = await svc.crearCategoria(restaurantId: 'r1', nombre: 'AA');
      final b = await svc.crearCategoria(restaurantId: 'r1', nombre: 'BB');
      final c = await svc.crearCategoria(restaurantId: 'r1', nombre: 'CC');
      final lista = await svc.getCategoriasStream('r1').first;
      final nuevo = [lista[2], lista[0], lista[1]];
      await svc.reordenarCategorias(restaurantId: 'r1', categoriasOrdenadas: nuevo);
      final despues = await svc.getCategoriasStream('r1').first;
      expect(despues.map((x) => x.id), [c, a, b]);
      expect(despues.map((x) => x.orden), [1, 2, 3]);
    });

    test('cuenta los platillos asociados por referencia o por id', () async {
      final cat = await svc.crearCategoria(restaurantId: 'r1', nombre: 'AA');
      final catRef = db.collection('restaurants').doc('r1').collection('categorias').doc(cat);
      final pl = db.collection('restaurants').doc('r1').collection('platillos');
      expect(await svc.contarPlatillosAsociados(restaurantId: 'r1', categoriaId: cat), 0);
      await pl.add({'categoriaId': catRef});
      await pl.add({'categoriaId': catRef});
      expect(await svc.contarPlatillosAsociados(restaurantId: 'r1', categoriaId: cat), 2);

      final otra = await svc.crearCategoria(restaurantId: 'r1', nombre: 'BB');
      await pl.add({'categoriaId': otra});
      expect(await svc.contarPlatillosAsociados(restaurantId: 'r1', categoriaId: otra), 1);
    });

    test('elimina una categoría', () async {
      final a = await svc.crearCategoria(restaurantId: 'r1', nombre: 'AA');
      await svc.eliminarCategoria(restaurantId: 'r1', categoriaId: a);
      expect(await svc.getCategoriasStream('r1').first, isEmpty);
    });
  });
}
