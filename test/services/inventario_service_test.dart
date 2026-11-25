import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/inventario_models.dart';
import 'package:reservitta/models/pedido_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/inventario_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/viewmodels/admin_reservations_viewmodel.dart';

const rid = 'r1';

void main() {
  late FakeFirebaseFirestore db;
  late InventarioService inv;

  setUp(() {
    db = FakeFirebaseFirestore();
    inv = InventarioService(firestore: db);
  });

  // --- Preparación de datos ---------------------------------------------------

  Future<void> sucursales(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await db.collection('restaurants').doc(rid).collection('sucursales').doc(ids[i]).set({
        'nombre': 'Sucursal ${ids[i]}',
        'esPrincipal': i == 0,
      });
    }
  }

  Future<void> platillo(
    String id, {
    List<Map<String, dynamic>> receta = const [],
    String estado = 'activo',
    bool agotadoAuto = false,
  }) async {
    await db.collection('restaurants').doc(rid).collection('platillos').doc(id).set({
      'nombre': 'Platillo $id',
      'precio': 100,
      'categoriaId': 'c',
      'estado': estado,
      'receta': receta,
      'agotadoAuto': agotadoAuto,
      'agotadoSucursales': <String>[],
    });
  }

  Map<String, dynamic> ing(String insumoId, double cantidad, {String nombre = 'Insumo', String unidad = 'pza'}) =>
      {'insumoId': insumoId, 'nombre': nombre, 'unidad': unidad, 'cantidad': cantidad};

  Future<void> stock(String sid, String insumoId, double cantidad, {double minimo = 0}) =>
      db.collection('restaurants').doc(rid).collection('sucursales').doc(sid).collection('existencias').doc(insumoId).set({
        'cantidad': cantidad,
        'minimo': minimo,
      });

  Future<double> cantidadDe(String sid, String insumoId) async {
    final d = await db
        .collection('restaurants')
        .doc(rid)
        .collection('sucursales')
        .doc(sid)
        .collection('existencias')
        .doc(insumoId)
        .get();
    return ((d.data()?['cantidad'] as num?) ?? 0).toDouble();
  }

  Future<List<MovimientoInventario>> movimientos(String sid) async {
    final q = await db.collection('restaurants').doc(rid).collection('sucursales').doc(sid).collection('movimientos').get();
    return q.docs.map((d) => MovimientoInventario.fromMap(d.id, d.data())).toList();
  }

  Future<Map<String, dynamic>> platilloDoc(String id) async =>
      (await db.collection('restaurants').doc(rid).collection('platillos').doc(id).get()).data()!;

  Future<String> pedido({
    required String sucursalId,
    required List<(String, int)> items,
    String estado = 'recibido',
  }) async {
    final ref = await db.collection('pedidos').add({
      'restauranteId': rid,
      'sucursalId': sucursalId,
      'estado': estado,
      'items': [
        for (final (id, c) in items) {'platilloId': id, 'nombre': 'x', 'precio': 10, 'cantidad': c, 'total': 10.0 * c},
      ],
    });
    return ref.id;
  }

  // --- Modelos --------------------------------------------------------------------

  group('Modelos del inventario', () {
    test('estados de una existencia', () {
      expect(const ExistenciaModel(insumoId: 'a', cantidad: 0, minimo: 5).agotado, isTrue);
      expect(const ExistenciaModel(insumoId: 'a', cantidad: 5, minimo: 5).bajo, isTrue);
      expect(const ExistenciaModel(insumoId: 'a', cantidad: 6, minimo: 5).bajo, isFalse);
      expect(const ExistenciaModel(insumoId: 'a', cantidad: 2, minimo: 0).bajo, isFalse);
      expect(const ExistenciaModel(insumoId: 'a', cantidad: 0, minimo: 5).bajo, isFalse);
      expect(const ExistenciaModel(insumoId: 'a', cantidad: 3, minimo: 5).requiereAtencion, isTrue);
      expect(const ExistenciaModel(insumoId: 'a', cantidad: 30, minimo: 5).requiereAtencion, isFalse);
    });

    test('las cantidades no arrastran errores de coma flotante', () {
      expect(redondearCantidad(0.1 + 0.2), 0.3);
      expect(formatoCantidad(2.0), '2');
      expect(formatoCantidad(0.5), '0.5');
      expect(formatoCantidad(1.2500001), '1.25');
    });

    test('un platillo se puede pedir según su estado y su sucursal', () {
      final p = PlatilloModel(
        id: 'p',
        categoriaId: 'c',
        nombre: 'Taco',
        descripcion: '',
        precio: 10,
        agotadoSucursales: const ['s2'],
      );
      expect(p.disponibleEn('s1'), isTrue);
      expect(p.disponibleEn('s2'), isFalse);
      expect(p.disponibleEn(null), isTrue);
      expect(p.disponibleEn(''), isTrue);
      expect(p.copyWith(estado: 'agotado').disponibleEn('s1'), isFalse);
    });

    test('la receta se guarda y se lee en el platillo', () {
      final p = PlatilloModel(
        id: 'p',
        categoriaId: 'c',
        nombre: 'Taco',
        descripcion: '',
        precio: 10,
        receta: const [RecetaItem(insumoId: 'tortilla', nombre: 'Tortilla', cantidad: 3)],
        agotadoAuto: true,
        agotadoSucursales: const ['s1'],
      );
      final leido = PlatilloModel.fromMap('p', p.toMap());
      expect(leido.receta.single.cantidad, 3);
      expect(leido.tieneReceta, isTrue);
      expect(leido.agotadoAuto, isTrue);
      expect(leido.agotadoSucursales, ['s1']);
    });
  });

  // --- Catálogo y movimientos manuales ---------------------------------------------

  group('Insumos', () {
    test('valida nombre y unidad, y no repite nombres', () async {
      await expectLater(inv.crearInsumo(rid, nombre: ' ', unidad: 'kg'), throwsA(isA<InventarioException>()));
      await expectLater(inv.crearInsumo(rid, nombre: 'Harina', unidad: 'cuchara'), throwsA(isA<InventarioException>()));
      await inv.crearInsumo(rid, nombre: 'Harina', unidad: 'kg');
      await expectLater(
        inv.crearInsumo(rid, nombre: '  harina ', unidad: 'g'),
        throwsA(isA<InventarioException>().having((e) => e.message, 'mensaje', contains('Ya existe'))),
      );
    });

    test('crea el insumo con existencia inicial y mínimo en la sucursal', () async {
      await sucursales(['s1']);
      final id = await inv.crearInsumoConExistencia(
        rid,
        's1',
        nombre: 'Harina',
        unidad: 'kg',
        minimo: 2,
        existenciaInicial: 10,
        por: 'u1',
      );
      expect(await cantidadDe('s1', id), 10);
      final ex = (await inv.existenciasStream(rid, 's1').first)[id]!;
      expect(ex.minimo, 2);
      final movs = await movimientos('s1');
      expect(movs.single.esEntrada, isTrue);
      expect(movs.single.motivo, 'Existencia inicial');
      expect(movs.single.por, 'u1');
    });

    test('editar el nombre no permite repetir otro insumo', () async {
      final a = await inv.crearInsumo(rid, nombre: 'Harina', unidad: 'kg');
      await inv.crearInsumo(rid, nombre: 'Azúcar', unidad: 'kg');
      await expectLater(
        inv.actualizarInsumo(rid, a, nombre: 'Azúcar', unidad: 'kg'),
        throwsA(isA<InventarioException>()),
      );
      await inv.actualizarInsumo(rid, a, nombre: 'Harina de trigo', unidad: 'kg');
      final lista = await inv.insumosStream(rid).first;
      expect(lista.map((i) => i.nombre), contains('Harina de trigo'));
    });
  });

  group('Entradas y salidas', () {
    late InsumoModel harina;
    setUp(() async {
      await sucursales(['s1', 's2']);
      final id = await inv.crearInsumo(rid, nombre: 'Harina', unidad: 'kg');
      harina = InsumoModel(id: id, nombre: 'Harina', unidad: 'kg');
    });

    test('la entrada suma y la salida resta, con su bitácora', () async {
      await inv.registrarEntrada(rid, 's1', harina, cantidad: 10, motivo: 'Compra');
      await inv.registrarSalida(rid, 's1', harina, cantidad: 2.5, motivo: 'Merienda del personal');
      expect(await cantidadDe('s1', harina.id), 7.5);
      final movs = await movimientos('s1');
      expect(movs, hasLength(2));
      expect(movs.where((m) => m.esEntrada).single.cantidad, 10);
      expect(movs.where((m) => !m.esEntrada).single.motivo, 'Merienda del personal');
    });

    test('no se puede sacar más de lo que hay y no se guarda nada', () async {
      await inv.registrarEntrada(rid, 's1', harina, cantidad: 3);
      await expectLater(
        inv.registrarSalida(rid, 's1', harina, cantidad: 3.5),
        throwsA(isA<InventarioException>().having((e) => e.message, 'mensaje', contains('No hay suficiente'))),
      );
      expect(await cantidadDe('s1', harina.id), 3);
      expect((await movimientos('s1')).length, 1);
    });

    test('rechaza cantidades en cero o negativas', () async {
      await expectLater(inv.registrarEntrada(rid, 's1', harina, cantidad: 0), throwsA(isA<InventarioException>()));
      await expectLater(inv.registrarEntrada(rid, 's1', harina, cantidad: -2), throwsA(isA<InventarioException>()));
      await expectLater(inv.registrarSalida(rid, 's1', harina, cantidad: 0), throwsA(isA<InventarioException>()));
    });

    test('cada sucursal lleva su propio inventario', () async {
      await inv.registrarEntrada(rid, 's1', harina, cantidad: 10);
      await inv.registrarEntrada(rid, 's2', harina, cantidad: 4);
      await inv.registrarSalida(rid, 's1', harina, cantidad: 6);
      expect(await cantidadDe('s1', harina.id), 4);
      expect(await cantidadDe('s2', harina.id), 4);
      await inv.registrarSalida(rid, 's2', harina, cantidad: 4);
      expect(await cantidadDe('s1', harina.id), 4);
      expect(await cantidadDe('s2', harina.id), 0);
      expect((await movimientos('s1')).length, 2);
      expect((await movimientos('s2')).length, 2);
    });

    test('los decimales no acumulan errores', () async {
      await inv.registrarEntrada(rid, 's1', harina, cantidad: 0.1);
      await inv.registrarEntrada(rid, 's1', harina, cantidad: 0.2);
      expect(await cantidadDe('s1', harina.id), 0.3);
      await inv.registrarSalida(rid, 's1', harina, cantidad: 0.3);
      expect(await cantidadDe('s1', harina.id), 0);
    });

    test('definir el mínimo lo guarda sin tocar la existencia', () async {
      await inv.registrarEntrada(rid, 's1', harina, cantidad: 5);
      await inv.definirMinimo(rid, 's1', harina.id, 2);
      final ex = (await inv.existenciasStream(rid, 's1').first)[harina.id]!;
      expect(ex.cantidad, 5);
      expect(ex.minimo, 2);
      await expectLater(inv.definirMinimo(rid, 's1', harina.id, -1), throwsA(isA<InventarioException>()));
    });
  });

  // --- Disponibilidad ----------------------------------------------------------------

  group('Agotado automático', () {
    test('un platillo con insumos suficientes sigue activo', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 10);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      await inv.recalcularDisponibilidad(rid);
      final d = await platilloDoc('taco');
      expect(d['estado'], 'activo');
      expect(d['agotadoSucursales'], isEmpty);
    });

    test('con una sola sucursal, sin insumos pasa a agotado y vuelve al reponer', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 2);
      await platillo('taco', receta: [ing('tortilla', 3)]);

      await inv.recalcularDisponibilidad(rid);
      var d = await platilloDoc('taco');
      expect(d['estado'], 'agotado');
      expect(d['agotadoAuto'], isTrue);
      expect(d['agotadoSucursales'], ['s1']);

      await stock('s1', 'tortilla', 30);
      await inv.recalcularDisponibilidad(rid);
      d = await platilloDoc('taco');
      expect(d['estado'], 'activo');
      expect(d['agotadoAuto'], isFalse);
      expect(d['agotadoSucursales'], isEmpty);
    });

    test('un insumo que no existe en la sucursal cuenta como cero', () async {
      await sucursales(['s1']);
      await platillo('taco', receta: [ing('tortilla', 1)]);
      await inv.recalcularDisponibilidad(rid);
      expect((await platilloDoc('taco'))['estado'], 'agotado');
    });

    test('un agotado puesto a mano no se reactiva al reponer', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 30);
      await platillo('taco', receta: [ing('tortilla', 3)], estado: 'agotado');
      await inv.recalcularDisponibilidad(rid);
      final d = await platilloDoc('taco');
      expect(d['estado'], 'agotado');
      expect(d['agotadoAuto'], isFalse);
    });

    test('un platillo sin receta no se toca', () async {
      await sucursales(['s1']);
      await platillo('agua');
      await platillo('sopa', estado: 'agotado');
      await inv.recalcularDisponibilidad(rid);
      expect((await platilloDoc('agua'))['estado'], 'activo');
      expect((await platilloDoc('sopa'))['estado'], 'agotado');
    });

    test('un platillo necesita todos los insumos de su receta', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 30);
      await stock('s1', 'carne', 0.1);
      await platillo('taco', receta: [ing('tortilla', 3), ing('carne', 0.2, unidad: 'kg')]);
      await inv.recalcularDisponibilidad(rid);
      expect((await platilloDoc('taco'))['estado'], 'agotado');
    });

    test('con dos sucursales, si falta en una solo se oculta allí', () async {
      await sucursales(['s1', 's2']);
      await stock('s1', 'tortilla', 30);
      await stock('s2', 'tortilla', 0);
      await platillo('taco', receta: [ing('tortilla', 3)]);

      await inv.recalcularDisponibilidad(rid);
      var d = await platilloDoc('taco');
      expect(d['estado'], 'activo');
      expect(d['agotadoSucursales'], ['s2']);
      final p = PlatilloModel.fromMap('taco', d);
      expect(p.disponibleEn('s1'), isTrue);
      expect(p.disponibleEn('s2'), isFalse);

      await stock('s1', 'tortilla', 0);
      await inv.recalcularDisponibilidad(rid);
      d = await platilloDoc('taco');
      expect(d['estado'], 'agotado');
      expect(d['agotadoSucursales'], unorderedEquals(['s1', 's2']));

      await stock('s2', 'tortilla', 12);
      await inv.recalcularDisponibilidad(rid);
      d = await platilloDoc('taco');
      expect(d['estado'], 'activo');
      expect(d['agotadoSucursales'], ['s1']);
    });

    test('un movimiento manual actualiza la disponibilidad solo', () async {
      await sucursales(['s1']);
      final id = await inv.crearInsumo(rid, nombre: 'Tortilla', unidad: 'pza');
      final insumo = InsumoModel(id: id, nombre: 'Tortilla', unidad: 'pza');
      await platillo('taco', receta: [ing(id, 3)]);

      await inv.registrarEntrada(rid, 's1', insumo, cantidad: 2);
      expect((await platilloDoc('taco'))['estado'], 'agotado');
      await inv.registrarEntrada(rid, 's1', insumo, cantidad: 10);
      expect((await platilloDoc('taco'))['estado'], 'activo');
      await inv.registrarSalida(rid, 's1', insumo, cantidad: 12);
      expect((await platilloDoc('taco'))['estado'], 'agotado');
    });

    test('sin sucursales registradas usa la sucursal por defecto', () async {
      await stock(InventarioService.sucursalPorDefecto, 'tortilla', 30);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      await inv.recalcularDisponibilidad(rid);
      expect((await platilloDoc('taco'))['estado'], 'activo');
    });
  });

  // --- Descuento al preparar ---------------------------------------------------------

  group('Descuento de un pedido en línea', () {
    test('descuenta solo de la sucursal del pedido y deja bitácora', () async {
      await sucursales(['s1', 's2']);
      await stock('s1', 'tortilla', 30);
      await stock('s2', 'tortilla', 30);
      await platillo('taco', receta: [ing('tortilla', 3, nombre: 'Tortilla')]);
      final id = await pedido(sucursalId: 's2', items: [('taco', 4)]);

      final r = await inv.descontarPorPedido(rid, id, por: 'admin1');

      expect(r.aplicado, isTrue);
      expect(r.hayFaltantes, isFalse);
      expect(await cantidadDe('s2', 'tortilla'), 18);
      expect(await cantidadDe('s1', 'tortilla'), 30);
      final movs = await movimientos('s2');
      expect(movs.single.cantidad, 12);
      expect(movs.single.origen, MovimientoInventario.origenPedido);
      expect(movs.single.refId, id);
      expect(movs.single.por, 'admin1');
      expect((await movimientos('s1')), isEmpty);
      expect((await db.collection('pedidos').doc(id).get()).data()!['inventarioDescontado'], isTrue);
    });

    test('suma lo que usan varios platillos del mismo insumo', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 50);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      await platillo('quesadilla', receta: [ing('tortilla', 2)]);
      final id = await pedido(sucursalId: 's1', items: [('taco', 2), ('quesadilla', 3)]);
      await inv.descontarPorPedido(rid, id);
      expect(await cantidadDe('s1', 'tortilla'), 50 - 6 - 6);
      expect((await movimientos('s1')).length, 1);
    });

    test('solo descuenta una vez aunque se llame de nuevo', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 30);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      final id = await pedido(sucursalId: 's1', items: [('taco', 2)]);
      await inv.descontarPorPedido(rid, id);
      final segunda = await inv.descontarPorPedido(rid, id);
      expect(segunda.yaDescontado, isTrue);
      expect(segunda.aplicado, isFalse);
      expect(await cantidadDe('s1', 'tortilla'), 24);
      expect((await movimientos('s1')).length, 1);
    });

    test('si no alcanza, descuenta lo que hay, no deja negativos y avisa qué faltó', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 5);
      await platillo('taco', receta: [ing('tortilla', 3, nombre: 'Tortilla')]);
      final id = await pedido(sucursalId: 's1', items: [('taco', 4)]);

      final r = await inv.descontarPorPedido(rid, id);

      expect(r.aplicado, isTrue);
      expect(r.hayFaltantes, isTrue);
      expect(r.faltantes.single.nombre, 'Tortilla');
      expect(r.faltantes.single.falto, 7);
      expect(r.aviso, contains('Tortilla'));
      expect(await cantidadDe('s1', 'tortilla'), 0);
      final m = (await movimientos('s1')).single;
      expect(m.cantidad, 5);
      expect(m.faltante, 7);
      // Sin insumos, los platillos con esa receta ya se muestran como agotados.
      expect((await platilloDoc('taco'))['estado'], 'agotado');
    });

    test('los platillos sin receta no descuentan nada', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 30);
      await platillo('agua');
      final id = await pedido(sucursalId: 's1', items: [('agua', 3)]);
      final r = await inv.descontarPorPedido(rid, id);
      expect(r.aplicado, isFalse);
      expect(await cantidadDe('s1', 'tortilla'), 30);
      expect(await movimientos('s1'), isEmpty);
      // Y no vuelve a intentarlo.
      expect((await db.collection('pedidos').doc(id).get()).data()!['inventarioDescontado'], isTrue);
    });

    test('un pedido sin sucursal descuenta de la principal', () async {
      await sucursales(['norte', 'centro']);
      await db.collection('restaurants').doc(rid).collection('sucursales').doc('centro').update({'esPrincipal': true});
      await db.collection('restaurants').doc(rid).collection('sucursales').doc('norte').update({'esPrincipal': false});
      await stock('centro', 'tortilla', 30);
      await stock('norte', 'tortilla', 30);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      final id = await pedido(sucursalId: '', items: [('taco', 1)]);
      await inv.descontarPorPedido(rid, id);
      expect(await cantidadDe('centro', 'tortilla'), 27);
      expect(await cantidadDe('norte', 'tortilla'), 30);
    });

    test('un pedido que no existe no rompe nada', () async {
      final r = await inv.descontarPorPedido(rid, 'no_existe');
      expect(r.aplicado, isFalse);
      expect(r.yaDescontado, isFalse);
    });
  });

  group('Descuento de la preorden de una reserva', () {
    Future<String> reserva({String sucursalId = 's1'}) async {
      final repo = ReservationService(firestore: db);
      final r = await repo.createReservationVerified(
        ReservationModel.create(
          id: '',
          restauranteId: rid,
          usuarioId: 'u1',
          fechaLocal: '2026-12-05',
          inicio: DateTime(2026, 12, 5, 20),
          mesaIds: const ['m1'],
          sucursalId: sucursalId,
          preordenItems: const [
            {'platilloId': 'taco', 'nombre': 'Taco', 'precio': 30.0, 'cantidad': 5, 'total': 150.0},
          ],
        ),
      );
      return r.id;
    }

    test('la reserva guarda su sucursal y la preorden descuenta de ella', () async {
      await sucursales(['s1', 's2']);
      await stock('s1', 'tortilla', 40);
      await stock('s2', 'tortilla', 40);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      final id = await reserva(sucursalId: 's2');
      expect((await db.collection('reservations').doc(id).get()).data()!['sucursalId'], 's2');

      final r = await inv.descontarPorPreorden(rid, id);
      expect(r.aplicado, isTrue);
      expect(await cantidadDe('s2', 'tortilla'), 25);
      expect(await cantidadDe('s1', 'tortilla'), 40);
      expect((await movimientos('s2')).single.origen, MovimientoInventario.origenPreorden);

      final otra = await inv.descontarPorPreorden(rid, id);
      expect(otra.yaDescontado, isTrue);
      expect(await cantidadDe('s2', 'tortilla'), 25);
    });
  });

  group('Al cambiar el estado', () {
    test('un pedido que aún no está en cocina no descuenta', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 30);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      final id = await pedido(sucursalId: 's1', items: [('taco', 1)]);
      await inv.alCambiarEstadoPedido(rid, id, PedidoModel.estadoRecibido);
      await inv.alCambiarEstadoPedido(rid, id, PedidoModel.estadoCancelado);
      expect(await cantidadDe('s1', 'tortilla'), 30);
    });

    test('al pasar a preparando descuenta, y los estados siguientes no repiten', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 30);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      final id = await pedido(sucursalId: 's1', items: [('taco', 2)]);
      await inv.alCambiarEstadoPedido(rid, id, PedidoModel.estadoPreparando);
      await inv.alCambiarEstadoPedido(rid, id, PedidoModel.estadoListo);
      await inv.alCambiarEstadoPedido(rid, id, PedidoModel.estadoEntregado);
      expect(await cantidadDe('s1', 'tortilla'), 24);
    });

    test('avisa al administrador cuando faltaron insumos', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 1);
      await platillo('taco', receta: [ing('tortilla', 3, nombre: 'Tortilla')]);
      final id = await pedido(sucursalId: 's1', items: [('taco', 2)]);
      InventarioAvisos.instancia.tomar();
      var avisos = 0;
      void escuchar() => avisos++;
      InventarioAvisos.instancia.addListener(escuchar);
      addTearDown(() => InventarioAvisos.instancia.removeListener(escuchar));

      await inv.alCambiarEstadoPedido(rid, id, PedidoModel.estadoPreparando);

      expect(avisos, 1);
      expect(InventarioAvisos.instancia.tomar(), contains('Tortilla'));
      expect(InventarioAvisos.instancia.tomar(), isNull);
    });

    test('al pasar la preorden a preparación desde el panel se descuenta el inventario', () async {
      await sucursales(['s1']);
      await stock('s1', 'tortilla', 40);
      await platillo('taco', receta: [ing('tortilla', 3)]);
      final repo = ReservationService(firestore: db);
      final r = await repo.createReservationVerified(
        ReservationModel.create(
          id: '',
          restauranteId: rid,
          usuarioId: 'u1',
          fechaLocal: '2026-12-05',
          inicio: DateTime(2026, 12, 5, 20),
          mesaIds: const ['m1'],
          sucursalId: 's1',
          preordenItems: const [
            {'platilloId': 'taco', 'nombre': 'Taco', 'precio': 30.0, 'cantidad': 4, 'total': 120.0},
          ],
        ),
      );
      final vm = AdminReservationsViewModel(
        restaurantId: rid,
        reservationRepository: repo as ReservationRepository,
        usuarioId: () => 'admin1',
        inventario: inv,
      );
      addTearDown(vm.dispose);

      final error = await vm.cambiarEstadoPedido(r.id, ReservationModel.preordenEnPreparacion);

      expect(error, isNull);
      expect(await cantidadDe('s1', 'tortilla'), 28);
      expect((await movimientos('s1')).single.por, 'admin1');
      // Un cambio posterior no descuenta de nuevo.
      await vm.cambiarEstadoPedido(r.id, ReservationModel.preordenListo);
      expect(await cantidadDe('s1', 'tortilla'), 28);
    });
  });
}
