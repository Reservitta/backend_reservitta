import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/inventario_models.dart';
import 'package:reservitta/models/pedido_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/inventario_service.dart';
import 'package:reservitta/services/pedido_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/views/inventario_view.dart';
import 'package:reservitta/views/pedido_online_view.dart';
import 'package:reservitta/views/pedidos_online_admin_view.dart';
import 'package:reservitta/views/widgets/branch_picker_dialog.dart';
import 'package:reservitta/views/widgets/receta_editor.dart';

const rid = 'r1';

class _FakeRestaurantService extends RestaurantService {
  final List<BranchModel> sucursales;
  _FakeRestaurantService(this.sucursales);

  @override
  Future<List<BranchModel>> getBranches(String restaurantId) async => sucursales;
}

class _FakePlatillos extends PlatilloService {
  final List<PlatilloModel> lista;
  _FakePlatillos(this.lista);

  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) => Stream.value(lista);
}

class _FakeCategorias extends CategoriaService {
  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) => Stream.value(const []);
}

BranchModel _suc(String id, String nombre, {bool principal = false}) =>
    BranchModel(id: id, nombre: nombre, direccion: '$nombre 123', telefono: '', esPrincipal: principal);

void _grande(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tocar(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String key, String texto) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, texto);
}

void main() {
  late FakeFirebaseFirestore db;
  late InventarioService inv;

  setUp(() {
    db = FakeFirebaseFirestore();
    inv = InventarioService(firestore: db);
  });

  Future<InsumoModel> insumo(String nombre, {String unidad = 'kg'}) async {
    final id = await inv.crearInsumo(rid, nombre: nombre, unidad: unidad);
    return InsumoModel(id: id, nombre: nombre, unidad: unidad);
  }

  Future<void> abrir(WidgetTester tester, {List<BranchModel>? sucursales}) async {
    _grande(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventarioView(
            restaurantId: rid,
            service: inv,
            restaurantService: _FakeRestaurantService(sucursales ?? [_suc('s1', 'Centro', principal: true)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<double> cantidad(String sid, String insumoId) async {
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

  group('Pantalla de inventario', () {
    testWidgets('sin insumos invita a crear el primero', (tester) async {
      await abrir(tester);
      expect(find.byKey(const ValueKey('inventario_vacio')), findsOneWidget);
    });

    testWidgets('crea un insumo con existencia inicial y mínimo', (tester) async {
      await abrir(tester);
      await _tocar(tester, 'btn_nuevo_insumo');
      await _escribir(tester, 'insumo_nombre', 'Harina');
      await _escribir(tester, 'insumo_existencia', '10');
      await _escribir(tester, 'insumo_minimo', '2');
      await _tocar(tester, 'btn_guardar_insumo');

      final lista = await inv.insumosStream(rid).first;
      expect(lista.single.nombre, 'Harina');
      expect(await cantidad('s1', lista.single.id), 10);
      expect(find.text('Harina'), findsOneWidget);
      expect(find.byKey(ValueKey('existencia_${lista.single.id}')), findsOneWidget);
      expect(find.textContaining('10 pza'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
    });

    testWidgets('valida el nombre del insumo antes de guardar', (tester) async {
      await abrir(tester);
      await _tocar(tester, 'btn_nuevo_insumo');
      await _tocar(tester, 'btn_guardar_insumo');
      expect(find.byKey(const ValueKey('insumo_error')), findsOneWidget);
      expect(await inv.insumosStream(rid).first, isEmpty);
    });

    testWidgets('registra una entrada y una salida', (tester) async {
      final i = await insumo('Harina');
      await abrir(tester);

      await _tocar(tester, 'entrada_${i.id}');
      await _escribir(tester, 'cantidad_campo', '8');
      await _escribir(tester, 'cantidad_motivo', 'Compra');
      await _tocar(tester, 'btn_aceptar_cantidad');
      expect(await cantidad('s1', i.id), 8);

      await _tocar(tester, 'salida_${i.id}');
      await _escribir(tester, 'cantidad_campo', '3,5');
      await _tocar(tester, 'btn_aceptar_cantidad');
      expect(await cantidad('s1', i.id), 4.5);
      expect(find.textContaining('4.5 kg'), findsOneWidget);
    });

    testWidgets('una salida mayor a la existencia muestra el error y no cambia nada', (tester) async {
      final i = await insumo('Harina');
      await inv.registrarEntrada(rid, 's1', i, cantidad: 2);
      await abrir(tester);
      await _tocar(tester, 'salida_${i.id}');
      await _escribir(tester, 'cantidad_campo', '5');
      await _tocar(tester, 'btn_aceptar_cantidad');
      expect(find.textContaining('No hay suficiente'), findsOneWidget);
      expect(await cantidad('s1', i.id), 2);
    });

    testWidgets('la cantidad debe ser mayor a cero', (tester) async {
      final i = await insumo('Harina');
      await abrir(tester);
      await _tocar(tester, 'entrada_${i.id}');
      await _escribir(tester, 'cantidad_campo', '0');
      await _tocar(tester, 'btn_aceptar_cantidad');
      expect(find.byKey(const ValueKey('cantidad_error')), findsOneWidget);
      expect(await cantidad('s1', i.id), 0);
    });

    testWidgets('marca stock bajo y agotado, y avisa arriba', (tester) async {
      final harina = await insumo('Harina');
      final sal = await insumo('Sal');
      final azucar = await insumo('Azúcar');
      await inv.definirMinimo(rid, 's1', harina.id, 5);
      await inv.registrarEntrada(rid, 's1', harina, cantidad: 4);
      await inv.registrarEntrada(rid, 's1', azucar, cantidad: 50);
      await abrir(tester);

      expect(find.byKey(ValueKey('estado_insumo_${harina.id}')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey('estado_insumo_${harina.id}'))).data, 'Stock bajo');
      expect(tester.widget<Text>(find.byKey(ValueKey('estado_insumo_${sal.id}'))).data, 'Agotado');
      expect(tester.widget<Text>(find.byKey(ValueKey('estado_insumo_${azucar.id}'))).data, 'Disponible');
      expect(find.byKey(const ValueKey('banner_stock_bajo')), findsOneWidget);
      expect(find.textContaining('2 insumos con stock bajo o agotado'), findsOneWidget);
    });

    testWidgets('un insumo agotado no permite registrar salida', (tester) async {
      final i = await insumo('Harina');
      await abrir(tester);
      final boton = tester.widget<OutlinedButton>(find.byKey(ValueKey('salida_${i.id}')));
      expect(boton.onPressed, isNull);
    });

    testWidgets('cada sucursal muestra su propio inventario', (tester) async {
      final i = await insumo('Harina');
      await inv.registrarEntrada(rid, 's1', i, cantidad: 10);
      await inv.registrarEntrada(rid, 's2', i, cantidad: 3);
      await abrir(tester, sucursales: [_suc('s1', 'Centro', principal: true), _suc('s2', 'Norte')]);

      expect(find.byKey(const ValueKey('sucursal_s1')), findsOneWidget);
      expect(find.byKey(const ValueKey('sucursal_s2')), findsOneWidget);
      expect(find.textContaining('10 kg'), findsOneWidget);

      await _tocar(tester, 'sucursal_s2');
      expect(find.textContaining('3 kg'), findsOneWidget);
      expect(find.textContaining('10 kg'), findsNothing);

      // Una entrada en Norte no cambia Centro.
      await _tocar(tester, 'entrada_${i.id}');
      await _escribir(tester, 'cantidad_campo', '2');
      await _tocar(tester, 'btn_aceptar_cantidad');
      expect(await cantidad('s2', i.id), 5);
      expect(await cantidad('s1', i.id), 10);
    });

    testWidgets('con una sola sucursal no se muestra el selector', (tester) async {
      await abrir(tester);
      expect(find.byKey(const ValueKey('sucursal_s1')), findsNothing);
    });

    testWidgets('el historial muestra entradas, salidas y faltantes', (tester) async {
      final i = await insumo('Harina');
      await inv.registrarEntrada(rid, 's1', i, cantidad: 5, motivo: 'Compra');
      await db.collection('restaurants').doc(rid).collection('platillos').doc('pan').set({
        'nombre': 'Pan',
        'precio': 10,
        'categoriaId': 'c',
        'estado': 'activo',
        'receta': [
          {'insumoId': i.id, 'nombre': 'Harina', 'unidad': 'kg', 'cantidad': 4},
        ],
      });
      final pedidoRef = await db.collection('pedidos').add({
        'restauranteId': rid,
        'sucursalId': 's1',
        'items': [
          {'platilloId': 'pan', 'cantidad': 2},
        ],
      });
      await inv.descontarPorPedido(rid, pedidoRef.id);
      await abrir(tester);

      await _tocar(tester, 'tab_movimientos');
      expect(find.textContaining('Entrada · 5 kg · Harina'), findsOneWidget);
      expect(find.textContaining('Salida · 5 kg · Harina'), findsOneWidget);
      expect(find.textContaining('Pedido en línea'), findsOneWidget);
      expect(find.textContaining('Faltaron 3 kg'), findsOneWidget);
    });

    testWidgets('sin movimientos explica que aún no hay', (tester) async {
      await abrir(tester);
      await _tocar(tester, 'tab_movimientos');
      expect(find.byKey(const ValueKey('movimientos_vacio')), findsOneWidget);
    });

    testWidgets('permite editar el nombre y la unidad de un insumo', (tester) async {
      final i = await insumo('Harina');
      await abrir(tester);
      await _tocar(tester, 'menu_insumo_${i.id}');
      await tester.tap(find.text('Editar nombre y unidad'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('insumo_nombre')), 'Harina de trigo');
      await _tocar(tester, 'btn_guardar_insumo');
      expect((await inv.insumosStream(rid).first).single.nombre, 'Harina de trigo');
    });

    testWidgets('permite definir el mínimo desde el menú', (tester) async {
      final i = await insumo('Harina');
      await inv.registrarEntrada(rid, 's1', i, cantidad: 3);
      await abrir(tester);
      await _tocar(tester, 'menu_insumo_${i.id}');
      await tester.tap(find.text('Definir mínimo'));
      await tester.pumpAndSettle();
      await _escribir(tester, 'cantidad_campo', '5');
      await _tocar(tester, 'btn_aceptar_cantidad');
      final ex = (await inv.existenciasStream(rid, 's1').first)[i.id]!;
      expect(ex.minimo, 5);
      expect(ex.bajo, isTrue);
    });
  });

  group('Búsqueda y filtro por categoría', () {
    Future<Map<String, String>> sembrar() async {
      final ids = <String, String>{};
      Future<void> a(String nombre, String unidad, String categoria) async {
        ids[nombre] = await inv.crearInsumo(rid, nombre: nombre, unidad: unidad, categoria: categoria);
      }

      await a('Queso cheddar', 'g', 'Lácteos y quesos');
      await a('Leche', 'l', 'Lácteos y quesos');
      await a('Tocino', 'g', 'Carnes y proteínas');
      await a('Azúcar', 'g', 'Abarrotes');
      await a('Sal', 'g', '');
      return ids;
    }

    Finder tarjeta(Map<String, String> ids, String nombre) => find.byKey(ValueKey('insumo_${ids[nombre]}'));

    testWidgets('busca por nombre sin importar acentos ni mayúsculas', (tester) async {
      final ids = await sembrar();
      await abrir(tester);
      expect(tarjeta(ids, 'Azúcar'), findsOneWidget);
      expect(tarjeta(ids, 'Tocino'), findsOneWidget);

      await _escribir(tester, 'buscar_insumo', 'AZUCAR');
      await tester.pumpAndSettle();
      expect(tarjeta(ids, 'Azúcar'), findsOneWidget);
      expect(tarjeta(ids, 'Tocino'), findsNothing);
      expect(tarjeta(ids, 'Leche'), findsNothing);

      await _tocar(tester, 'btn_borrar_busqueda');
      expect(tarjeta(ids, 'Tocino'), findsOneWidget);
      expect(tarjeta(ids, 'Leche'), findsOneWidget);
    });

    testWidgets('filtra por categoría y cuenta los insumos de cada una', (tester) async {
      final ids = await sembrar();
      await abrir(tester);
      expect(find.text('Todas (5)'), findsOneWidget);
      expect(find.text('Lácteos y quesos (2)'), findsOneWidget);
      expect(find.text('Sin categoría (1)'), findsOneWidget);

      await _tocar(tester, 'filtro_categoria_Lácteos y quesos');
      expect(tarjeta(ids, 'Queso cheddar'), findsOneWidget);
      expect(tarjeta(ids, 'Leche'), findsOneWidget);
      expect(tarjeta(ids, 'Tocino'), findsNothing);

      await _tocar(tester, 'filtro_categoria_Sin categoría');
      expect(tarjeta(ids, 'Sal'), findsOneWidget);
      expect(tarjeta(ids, 'Leche'), findsNothing);

      await _tocar(tester, 'filtro_categoria_todas');
      expect(tarjeta(ids, 'Tocino'), findsOneWidget);
      expect(tarjeta(ids, 'Sal'), findsOneWidget);
    });

    testWidgets('la búsqueda y la categoría se combinan', (tester) async {
      final ids = await sembrar();
      await abrir(tester);
      await _tocar(tester, 'filtro_categoria_Lácteos y quesos');
      await _escribir(tester, 'buscar_insumo', 'lec');
      await tester.pumpAndSettle();
      expect(tarjeta(ids, 'Leche'), findsOneWidget);
      expect(tarjeta(ids, 'Queso cheddar'), findsNothing);
      // Con el texto, los conteos de cada categoría reflejan solo lo que coincide.
      expect(find.text('Lácteos y quesos (1)'), findsOneWidget);
      expect(find.text('Carnes y proteínas (0)'), findsOneWidget);
    });

    testWidgets('sin coincidencias avisa y "Limpiar filtros" lo restaura', (tester) async {
      final ids = await sembrar();
      await abrir(tester);
      await _escribir(tester, 'buscar_insumo', 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventario_sin_resultados')), findsOneWidget);
      expect(tarjeta(ids, 'Leche'), findsNothing);

      await _tocar(tester, 'btn_limpiar_filtros');
      expect(find.byKey(const ValueKey('inventario_sin_resultados')), findsNothing);
      expect(tarjeta(ids, 'Leche'), findsOneWidget);
    });

    testWidgets('sin categorías distintas no muestra los filtros', (tester) async {
      await insumo('Harina');
      await abrir(tester);
      expect(find.byKey(const ValueKey('filtro_categoria_todas')), findsNothing);
      expect(find.byKey(const ValueKey('buscar_insumo')), findsOneWidget);
    });

    testWidgets('al crear un insumo se guarda la categoría elegida', (tester) async {
      await abrir(tester);
      await _tocar(tester, 'btn_nuevo_insumo');
      await _escribir(tester, 'insumo_nombre', 'Mantequilla');
      await _tocar(tester, 'insumo_categoria');
      await tester.tap(find.text('Lácteos y quesos').last);
      await tester.pumpAndSettle();
      await _tocar(tester, 'btn_guardar_insumo');

      final docs = (await db.collection('restaurants').doc(rid).collection('insumos').get()).docs;
      expect(docs.single.data()['categoria'], 'Lácteos y quesos');
    });

    testWidgets('editar un insumo cambia su categoría sin tocar lo demás', (tester) async {
      final ids = await sembrar();
      await abrir(tester);
      await _tocar(tester, 'menu_insumo_${ids['Sal']}');
      await tester.tap(find.text('Editar nombre y unidad'));
      await tester.pumpAndSettle();
      await _tocar(tester, 'insumo_categoria');
      await tester.tap(find.text('Abarrotes').last);
      await tester.pumpAndSettle();
      await _tocar(tester, 'btn_guardar_insumo');

      final d = (await db.collection('restaurants').doc(rid).collection('insumos').doc(ids['Sal']).get()).data()!;
      expect(d['categoria'], 'Abarrotes');
      expect(d['nombre'], 'Sal');
      expect(d['unidad'], 'g');
    });
  });

  group('Resumen del dashboard', () {
    Future<void> abrirResumen(WidgetTester tester, List<BranchModel> sucursales) async {
      var abierto = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventarioResumen(
              restaurantId: rid,
              service: inv,
              restaurantService: _FakeRestaurantService(sucursales),
              onVer: () => abierto = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (abierto) fail('No debía abrirse sola');
    }

    testWidgets('sin insumos no aparece', (tester) async {
      await abrirResumen(tester, [_suc('s1', 'Centro')]);
      expect(find.byKey(const ValueKey('resumen_inventario')), findsNothing);
    });

    testWidgets('cuenta lo que está bajo o agotado en todas las sucursales', (tester) async {
      final a = await insumo('Harina');
      final b = await insumo('Sal');
      await inv.registrarEntrada(rid, 's1', a, cantidad: 10);
      await inv.registrarEntrada(rid, 's2', a, cantidad: 10);
      await inv.registrarEntrada(rid, 's2', b, cantidad: 10);
      await abrirResumen(tester, [_suc('s1', 'Centro'), _suc('s2', 'Norte')]);
      // Centro: Sal agotada. Norte: nada.
      expect(find.text('1 insumo con stock bajo o agotado'), findsOneWidget);
      expect(find.textContaining('Centro: 1'), findsOneWidget);
    });

    testWidgets('con todo en orden dice que el inventario está al día', (tester) async {
      final a = await insumo('Harina');
      await inv.registrarEntrada(rid, 's1', a, cantidad: 10);
      await abrirResumen(tester, [_suc('s1', 'Centro')]);
      expect(find.text('Inventario al día'), findsOneWidget);
    });
  });

  group('Receta en el platillo', () {
    testWidgets('agrega y quita ingredientes', (tester) async {
      final harina = await insumo('Harina');
      await insumo('Sal', unidad: 'g');
      var receta = <RecetaItem>[];
      _grande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecetaEditor(
                restaurantId: rid,
                inicial: const [],
                service: inv,
                onChanged: (r) => receta = r,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receta_vacia')), findsOneWidget);

      await _tocar(tester, 'btn_agregar_ingrediente');
      await _escribir(tester, 'ingrediente_cantidad', '0,25');
      await _tocar(tester, 'btn_aceptar_ingrediente');

      expect(receta, hasLength(1));
      expect(receta.single.cantidad, 0.25);
      expect(find.byKey(ValueKey('receta_item_${receta.single.insumoId}')), findsOneWidget);

      await _tocar(tester, 'quitar_ingrediente_${receta.single.insumoId}');
      expect(receta, isEmpty);
      expect(harina.id, isNotEmpty);
    });

    testWidgets('no repite un insumo ya agregado', (tester) async {
      await insumo('Harina');
      _grande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecetaEditor(restaurantId: rid, inicial: const [], service: inv, onChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tocar(tester, 'btn_agregar_ingrediente');
      await _escribir(tester, 'ingrediente_cantidad', '1');
      await _tocar(tester, 'btn_aceptar_ingrediente');
      // Ya usó el único insumo del catálogo: no quedan para agregar.
      final boton = tester.widget<OutlinedButton>(find.byKey(const ValueKey('btn_agregar_ingrediente')));
      expect(boton.onPressed, isNull);
    });

    testWidgets('pide una cantidad válida', (tester) async {
      await insumo('Harina');
      _grande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecetaEditor(restaurantId: rid, inicial: const [], service: inv, onChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tocar(tester, 'btn_agregar_ingrediente');
      await _tocar(tester, 'btn_aceptar_ingrediente');
      expect(find.textContaining('Escribe cuánto usa una porción'), findsOneWidget);
    });

    testWidgets('sin insumos registrados manda al inventario', (tester) async {
      _grande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecetaEditor(restaurantId: rid, inicial: const [], service: inv, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receta_sin_catalogo')), findsOneWidget);
    });

    testWidgets('muestra la receta con la que ya cuenta el platillo', (tester) async {
      await insumo('Harina');
      _grande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecetaEditor(
              restaurantId: rid,
              service: inv,
              inicial: const [RecetaItem(insumoId: 'x', nombre: 'Tortilla', unidad: 'pza', cantidad: 3)],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Tortilla · 3 pza'), findsOneWidget);
    });
  });

  group('Pedidos en línea e inventario', () {
    late PedidoService pedidos;
    setUp(() => pedidos = PedidoService(firestore: db));

    Future<PedidoModel> crearPedido({String sucursalId = 's1'}) => pedidos.crear(
          PedidoModel(
            id: '',
            restauranteId: rid,
            sucursalId: sucursalId,
            sucursalNombre: 'Centro',
            usuarioId: 'u1',
            contactoNombre: 'Ana López',
            contactoTelefono: '5512345678',
            lineas: const [PedidoLinea(platilloId: 'taco', nombre: 'Taco', precio: 30, cantidad: 4)],
          ),
        );

    Future<void> platilloConReceta(String insumoId, double porPorcion) =>
        db.collection('restaurants').doc(rid).collection('platillos').doc('taco').set({
          'nombre': 'Taco',
          'precio': 30,
          'categoriaId': 'c',
          'estado': 'activo',
          'receta': [
            {'insumoId': insumoId, 'nombre': 'Tortilla', 'unidad': 'pza', 'cantidad': porPorcion},
          ],
        });

    Future<void> abrirPanel(WidgetTester tester) async {
      _grande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PedidosOnlineAdminView(restaurantId: rid, service: pedidos, inventario: inv),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pasar a preparando descuenta el inventario de la sucursal del pedido', (tester) async {
      final tortilla = await insumo('Tortilla', unidad: 'pza');
      await inv.registrarEntrada(rid, 's1', tortilla, cantidad: 50);
      await inv.registrarEntrada(rid, 's2', tortilla, cantidad: 50);
      await platilloConReceta(tortilla.id, 3);
      final p = await crearPedido(sucursalId: 's2');
      await abrirPanel(tester);

      expect(find.textContaining('Centro'), findsWidgets); // la tarjeta indica la sucursal
      await _tocar(tester, 'avanzar_${p.id}');

      expect(await cantidad('s2', tortilla.id), 38);
      expect(await cantidad('s1', tortilla.id), 50);
      expect((await db.collection('pedidos').doc(p.id).get()).data()!['estado'], PedidoModel.estadoPreparando);
    });

    testWidgets('si faltan insumos el pedido avanza igual y se avisa', (tester) async {
      final tortilla = await insumo('Tortilla', unidad: 'pza');
      await inv.registrarEntrada(rid, 's1', tortilla, cantidad: 5);
      await platilloConReceta(tortilla.id, 3);
      final p = await crearPedido();
      InventarioAvisos.instancia.tomar();
      await abrirPanel(tester);

      await _tocar(tester, 'avanzar_${p.id}');

      expect((await db.collection('pedidos').doc(p.id).get()).data()!['estado'], PedidoModel.estadoPreparando);
      expect(await cantidad('s1', tortilla.id), 0);
      expect(InventarioAvisos.instancia.tomar(), contains('Tortilla'));
    });

    testWidgets('cancelar un pedido no toca el inventario', (tester) async {
      final tortilla = await insumo('Tortilla', unidad: 'pza');
      await inv.registrarEntrada(rid, 's1', tortilla, cantidad: 50);
      await platilloConReceta(tortilla.id, 3);
      final p = await crearPedido();
      await abrirPanel(tester);
      await _tocar(tester, 'cancelar_${p.id}');
      await _tocar(tester, 'btn_confirmar_cancelar_pedido');
      expect(await cantidad('s1', tortilla.id), 50);
    });

    testWidgets('el menú de pedidos oculta lo que no se puede preparar en esa sucursal', (tester) async {
      _grande(tester);
      final auth = AuthService(auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')), firestore: db);
      final taco = PlatilloModel(
        id: 'taco',
        categoriaId: 'c',
        nombre: 'Taco al pastor',
        descripcion: '',
        precio: 30,
        agotadoSucursales: const ['s2'],
      );
      final agua = PlatilloModel(id: 'agua', categoriaId: 'c', nombre: 'Agua fresca', descripcion: '', precio: 20);

      Future<void> abrirMenu(BranchModel s) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PedidoOnlineView(
              key: ValueKey(s.id),
              restaurant: const RestaurantModel(id: rid, nombre: 'Casa', estado: 'activo', ofreceDelivery: true),
              sucursal: s,
              platilloService: _FakePlatillos([taco, agua]),
              categoriaService: _FakeCategorias(),
              pedidoService: pedidos,
              authService: auth,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await abrirMenu(_suc('s1', 'Centro'));
      expect(find.text('Taco al pastor'), findsOneWidget);
      expect(find.text('Agua fresca'), findsOneWidget);
      expect(find.text('Pedir en Centro'), findsOneWidget);

      await abrirMenu(_suc('s2', 'Norte'));
      expect(find.text('Taco al pastor'), findsNothing);
      expect(find.text('Agua fresca'), findsOneWidget);
      expect(find.text('Pedir en Norte'), findsOneWidget);
    });

    testWidgets('si la sucursal no puede preparar nada lo explica con su nombre', (tester) async {
      _grande(tester);
      final auth = AuthService(auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')), firestore: db);
      final taco = PlatilloModel(
        id: 'taco',
        categoriaId: 'c',
        nombre: 'Taco',
        descripcion: '',
        precio: 30,
        agotadoSucursales: const ['s2'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PedidoOnlineView(
            restaurant: const RestaurantModel(id: rid, nombre: 'Casa', estado: 'activo', ofreceDelivery: true),
            sucursal: _suc('s2', 'Norte'),
            platilloService: _FakePlatillos([taco]),
            categoriaService: _FakeCategorias(),
            pedidoService: pedidos,
            authService: auth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Esta sucursal no tiene platillos disponibles'), findsOneWidget);
    });

    testWidgets('el selector de sucursal habla de pedir cuando es un pedido', (tester) async {
      _grande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchPickerDialog(
              restaurant: const RestaurantModel(id: rid, nombre: 'Casa', estado: 'activo'),
              service: _FakeRestaurantService([_suc('s1', 'Centro'), _suc('s2', 'Norte')]),
              accion: 'pedir',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Selecciona dónde quieres pedir en Casa'), findsOneWidget);
    });

    testWidgets('el pedido guarda la sucursal elegida', (tester) async {
      final p = await crearPedido(sucursalId: 's2');
      final doc = (await db.collection('pedidos').doc(p.id).get()).data()!;
      expect(doc['sucursalId'], 's2');
      expect(doc['sucursalNombre'], 'Centro');
      expect(PedidoModel.fromMap(p.id, doc).sucursalId, 's2');
    });
  });
}
