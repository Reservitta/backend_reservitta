import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/ocasion_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/viewmodels/pedido_viewmodel.dart';
import 'package:reservitta/views/personalize_visit_view.dart';
import 'package:reservitta/views/widgets/platillo_detalle_sheet.dart';
import 'package:reservitta/views/widgets/platillo_menu_card.dart';

class _FakeCategoriaService extends CategoriaService {
  final List<CategoriaModel> categorias;
  _FakeCategoriaService(this.categorias);

  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) {
    return Stream.value(categorias);
  }
}

class _FakePlatilloService extends PlatilloService {
  final List<PlatilloModel> platillos;
  _FakePlatilloService(this.platillos);

  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) {
    return Stream.value(platillos);
  }
}

class _FakeOcasionService extends OcasionService {
  @override
  Future<List<OcasionModel>> getOcasiones(String restaurantId) async {
    return const [];
  }
}

void main() {
  final restaurant = RestaurantModel(
    id: 'rest_hu16_rf03',
    nombre: 'Restaurante Gourmet HU16',
    estado: 'activo',
  );

  final categoriasMock = [
    const CategoriaModel(
      id: 'cat_entradas',
      nombre: 'Entradas',
      nombreNormalizado: 'entradas',
      orden: 1,
      tipo: 'comida',
    ),
    const CategoriaModel(
      id: 'cat_fuertes',
      nombre: 'Platos fuertes',
      nombreNormalizado: 'platos fuertes',
      orden: 2,
      tipo: 'comida',
    ),
    const CategoriaModel(
      id: 'cat_postres',
      nombre: 'Postres',
      nombreNormalizado: 'postres',
      orden: 3,
      tipo: 'postre',
    ),
    const CategoriaModel(
      id: 'cat_bebidas',
      nombre: 'Bebidas',
      nombreNormalizado: 'bebidas',
      orden: 4,
      tipo: 'bebida',
    ),
  ];

  final platilloEntrada = PlatilloModel(
    id: 'plat_ceviche',
    categoriaId: 'cat_entradas',
    nombre: 'Ceviche Clásico',
    descripcion: 'Pescado fresco marinado con limón y cebolla morada',
    precio: 180.0,
    etiquetas: const ['Fresco', 'Mariscos'],
  );

  final platilloFuerte = PlatilloModel(
    id: 'plat_bife',
    categoriaId: 'cat_fuertes',
    nombre: 'Bife de Chorizo',
    descripcion: 'Corte de res de 400g a la parrilla con papas',
    precio: 340.0,
    etiquetas: const ['Corte', 'Parrilla'],
  );

  final platilloPostre = PlatilloModel(
    id: 'plat_flan',
    categoriaId: 'cat_postres',
    nombre: 'Flan Casero',
    descripcion: 'Tradicional flan con caramelo y dulce de leche',
    precio: 95.0,
    etiquetas: const ['Dulce', 'Casero'],
  );

  final platilloBebida = PlatilloModel(
    id: 'plat_limonada',
    categoriaId: 'cat_bebidas',
    nombre: 'Limonada Mineral',
    descripcion: 'Jugo natural de limón con agua mineral y menta',
    precio: 60.0,
    etiquetas: const ['Bebida', 'Refrescante'],
  );

  final todosLosPlatillos = [
    platilloEntrada,
    platilloFuerte,
    platilloPostre,
    platilloBebida,
  ];

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
  }

  group('HU16-RF03: Listado de platillos por categoría con opción de agregar', () {
    testWidgets(
      'Criterio 1: Pestañas por categoría (Entradas, Platos fuertes, Postres, Bebidas) y filtrado dinámico',
      (tester) async {
        setScreenSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pedidoVm = PedidoViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: PersonalizeVisitView(
              restaurant: restaurant,
              draft: ReservationDraftModel(restaurant: restaurant, fecha: DateTime(2026, 11, 20), personas: 2),
              pedidoViewModel: pedidoVm,
              categoriaService: _FakeCategoriaService(categoriasMock),
              platilloService: _FakePlatilloService(todosLosPlatillos),
              ocasionService: _FakeOcasionService(),
              isAuthenticated: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verificar presencia de la barra de pestañas de categorías
        expect(find.byKey(const ValueKey('container_categorias_preorden')), findsOneWidget);
        expect(find.byKey(const ValueKey('tabbar_categorias_preorden')), findsOneWidget);

        // 2. Verificar que existen las pestañas por categoría
        expect(find.widgetWithText(Tab, 'Todas'), findsOneWidget);
        expect(find.widgetWithText(Tab, 'Entradas'), findsOneWidget);
        expect(find.widgetWithText(Tab, 'Platos fuertes'), findsOneWidget);
        expect(find.widgetWithText(Tab, 'Postres'), findsOneWidget);
        expect(find.widgetWithText(Tab, 'Bebidas'), findsOneWidget);

        // Inicialmente "Todas" muestra los 4 platillos
        expect(find.text('Ceviche Clásico'), findsOneWidget);
        expect(find.text('Bife de Chorizo'), findsOneWidget);
        expect(find.text('Flan Casero'), findsOneWidget);
        expect(find.text('Limonada Mineral'), findsOneWidget);

        // 3. Tocar la pestaña "Entradas" -> Solo debe verse Ceviche Clásico
        await tester.tap(find.widgetWithText(Tab, 'Entradas'));
        await tester.pumpAndSettle();

        expect(find.text('Ceviche Clásico'), findsOneWidget);
        expect(find.text('Bife de Chorizo'), findsNothing);
        expect(find.text('Flan Casero'), findsNothing);
        expect(find.text('Limonada Mineral'), findsNothing);

        // 4. Tocar la pestaña "Platos fuertes" -> Solo debe verse Bife de Chorizo
        await tester.tap(find.widgetWithText(Tab, 'Platos fuertes'));
        await tester.pumpAndSettle();

        expect(find.text('Ceviche Clásico'), findsNothing);
        expect(find.text('Bife de Chorizo'), findsOneWidget);
        expect(find.text('Flan Casero'), findsNothing);
        expect(find.text('Limonada Mineral'), findsNothing);

        // 5. Tocar la pestaña "Postres" -> Solo debe verse Flan Casero
        await tester.tap(find.widgetWithText(Tab, 'Postres'));
        await tester.pumpAndSettle();

        expect(find.text('Ceviche Clásico'), findsNothing);
        expect(find.text('Bife de Chorizo'), findsNothing);
        expect(find.text('Flan Casero'), findsOneWidget);
        expect(find.text('Limonada Mineral'), findsNothing);

        // 6. Volver a tocar "Todas" -> Reaparecen los 4 platillos
        await tester.tap(find.widgetWithText(Tab, 'Todas'));
        await tester.pumpAndSettle();

        expect(find.text('Ceviche Clásico'), findsOneWidget);
        expect(find.text('Bife de Chorizo'), findsOneWidget);
        expect(find.text('Flan Casero'), findsOneWidget);
        expect(find.text('Limonada Mineral'), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 2: Cada platillo muestra imagen, nombre, descripción, etiquetas y precio',
      (tester) async {
        setScreenSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pedidoVm = PedidoViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: PersonalizeVisitView(
              restaurant: restaurant,
              draft: ReservationDraftModel(restaurant: restaurant, fecha: DateTime(2026, 11, 20), personas: 2),
              pedidoViewModel: pedidoVm,
              categoriaService: _FakeCategoriaService(categoriasMock),
              platilloService: _FakePlatilloService([platilloEntrada]),
              ocasionService: _FakeOcasionService(),
              isAuthenticated: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verificar tarjeta del platillo
        expect(find.byKey(ValueKey('card_platillo_${platilloEntrada.id}')), findsOneWidget);

        // Nombre
        expect(find.text('Ceviche Clásico'), findsOneWidget);

        // Descripción
        expect(find.text('Pescado fresco marinado con limón y cebolla morada'), findsOneWidget);

        // Etiquetas
        expect(find.text('Fresco'), findsOneWidget);
        expect(find.text('Mariscos'), findsOneWidget);

        // Precio
        expect(find.text('\$180.00 MXN'), findsOneWidget);

        // Icono / contenedor de imagen
        expect(find.byIcon(Icons.fastfood_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 3: Botón "Agregar" abre el detalle de personalización del platillo (HU16-RF04)',
      (tester) async {
        setScreenSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pedidoVm = PedidoViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: PersonalizeVisitView(
              restaurant: restaurant,
              draft: ReservationDraftModel(restaurant: restaurant, fecha: DateTime(2026, 11, 20), personas: 2),
              pedidoViewModel: pedidoVm,
              categoriaService: _FakeCategoriaService(categoriasMock),
              platilloService: _FakePlatilloService([platilloEntrada]),
              ocasionService: _FakeOcasionService(),
              isAuthenticated: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Botón "Agregar" visible en la tarjeta
        final btnAgregar = find.byKey(ValueKey('btn_agregar_platillo_${platilloEntrada.id}'));
        expect(btnAgregar, findsOneWidget);
        expect(find.text('Agregar'), findsOneWidget);

        // Pulsar "Agregar" debe abrir PlatilloDetalleSheet (HU16-RF04)
        await tester.tap(btnAgregar);
        await tester.pumpAndSettle();

        expect(find.byType(PlatilloDetalleSheet), findsOneWidget);
        expect(find.byKey(const ValueKey('btn_agregar_al_pedido')), findsOneWidget);
        expect(find.byKey(const ValueKey('input_observacion_platillo')), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 4: Badge "Pedido (n)" en la parte superior con cantidad total acumulada en tiempo real',
      (tester) async {
        setScreenSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pedidoVm = PedidoViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: PersonalizeVisitView(
              restaurant: restaurant,
              draft: ReservationDraftModel(restaurant: restaurant, fecha: DateTime(2026, 11, 20), personas: 2),
              pedidoViewModel: pedidoVm,
              categoriaService: _FakeCategoriaService(categoriasMock),
              platilloService: _FakePlatilloService(todosLosPlatillos),
              ocasionService: _FakeOcasionService(),
              isAuthenticated: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inicialmente el badge en el AppBar dice "Pedido (0)"
        expect(find.byKey(const ValueKey('badge_pedido_count')), findsOneWidget);
        expect(find.text('Pedido (0)'), findsOneWidget);

        // Agregar 2 Ceviches
        await tester.tap(find.byKey(ValueKey('btn_agregar_platillo_${platilloEntrada.id}')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('btn_incrementar_cantidad')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('btn_agregar_al_pedido')));
        await tester.pumpAndSettle();

        // El badge ahora dice "Pedido (2)"
        expect(find.text('Pedido (2)'), findsOneWidget);

        // Agregar 1 Limonada
        await tester.tap(find.byKey(ValueKey('btn_agregar_platillo_${platilloBebida.id}')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('btn_agregar_al_pedido')));
        await tester.pumpAndSettle();

        // El badge ahora dice "Pedido (3)" en tiempo real
        expect(find.text('Pedido (3)'), findsOneWidget);
      },
    );
  });
}
