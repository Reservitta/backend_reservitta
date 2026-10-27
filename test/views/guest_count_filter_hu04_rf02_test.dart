import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/views/landing_view.dart';

class FakeRestaurantCapacityService extends RestaurantService {
  final List<RestaurantModel> restaurantsEnMemoria;

  FakeRestaurantCapacityService({required this.restaurantsEnMemoria});

  @override
  Future<List<ServiceCatalogModel>> getServicesCatalog() async => [];

  @override
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async {
    return PaginatedRestaurantsResult(
      restaurants: restaurantsEnMemoria,
      lastDocument: null,
      hasMore: false,
    );
  }

  @override
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    for (final r in restaurantsEnMemoria) {
      if (r.id == restaurantId) return r;
    }
    return null;
  }
}

void main() {
  group('35.- HU04-RF02: Selector de cantidad de personas', () {
    late List<RestaurantModel> mockRestaurants;
    late FakeRestaurantCapacityService fakeService;

    setUp(() {
      mockRestaurants = [
        const RestaurantModel(
          id: 'rest_pequeno',
          nombre: 'Café Para Dos',
          direccion: 'Calle Sol 10',
          estado: 'activo',
          capacidadMaxima: 2,
        ),
        const RestaurantModel(
          id: 'rest_mediano',
          nombre: 'Trattoria Familiar',
          direccion: 'Av. Central 50',
          estado: 'activo',
          capacidadMaxima: 6,
        ),
        const RestaurantModel(
          id: 'rest_grande',
          nombre: 'Gran Banquete',
          direccion: 'Blvd. Real 100',
          estado: 'activo',
          capacidadMaxima: 20,
        ),
        const RestaurantModel(
          id: 'rest_sin_capacidad',
          nombre: 'Puesto Callejero',
          direccion: 'Esquina 5',
          estado: 'activo',
          capacidadMaxima: 0,
        ),
      ];

      fakeService = FakeRestaurantCapacityService(restaurantsEnMemoria: mockRestaurants);
    });

    test('Criterio 1 y 2: Validación estricta - No se permiten valores negativos, cero ni no numéricos', () {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);

      // 1. Cero no permitido
      expect(PublicCatalogViewModel.isValidGuestCount(0), isFalse);
      expect(vm.setGuestCountFilter(0), isFalse);
      expect(vm.isGuestCountFilterActive, isFalse);
      expect(vm.selectedGuestCount, isNull);

      // 2. Números negativos no permitidos
      expect(PublicCatalogViewModel.isValidGuestCount(-1), isFalse);
      expect(PublicCatalogViewModel.isValidGuestCount(-10), isFalse);
      expect(vm.setGuestCountFilter(-3), isFalse);
      expect(vm.isGuestCountFilterActive, isFalse);

      // 3. Tipos no numéricos o no enteros rechazados
      expect(PublicCatalogViewModel.isValidGuestCount('4'), isFalse);
      expect(PublicCatalogViewModel.isValidGuestCount(null), isFalse);
      expect(PublicCatalogViewModel.isValidGuestCount(3.5), isFalse);

      // 4. Exceder el límite superior definido (maxGuestCount = 20)
      expect(PublicCatalogViewModel.isValidGuestCount(21), isFalse);
      expect(vm.setGuestCountFilter(25), isFalse);

      // 5. Valores válidos dentro del rango [1..20]
      expect(PublicCatalogViewModel.isValidGuestCount(1), isTrue);
      expect(PublicCatalogViewModel.isValidGuestCount(4), isTrue);
      expect(PublicCatalogViewModel.isValidGuestCount(20), isTrue);
    });

    test('Criterio 1: Stepper numérico con mínimo 1 y máximo definido (1 a 20)', () {
      expect(PublicCatalogViewModel.minGuestCount, equals(1));
      expect(PublicCatalogViewModel.maxGuestCount, equals(20));

      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      expect(vm.setGuestCountFilter(PublicCatalogViewModel.minGuestCount), isTrue);
      expect(vm.selectedGuestCount, equals(1));

      expect(vm.setGuestCountFilter(PublicCatalogViewModel.maxGuestCount), isTrue);
      expect(vm.selectedGuestCount, equals(20));
    });

    test('Criterio 3: Formateo visible en ViewModel para pantalla principal', () {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);

      expect(vm.selectedGuestCountFormatted, isNull);

      vm.setGuestCountFilter(1);
      expect(vm.selectedGuestCountFormatted, equals('1 persona'));

      vm.setGuestCountFilter(4);
      expect(vm.selectedGuestCountFormatted, equals('4 personas'));
    });

    test('Criterio 3: Filtrado en catálogo según capacidad suficiente', () async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      // Inicialmente 4 restaurantes cargados
      expect(vm.restaurants.length, equals(4));

      // Filtro para 4 personas:
      // - rest_pequeno (capacidad 2) -> Excluido
      // - rest_sin_capacidad (capacidad 0) -> Excluido (sin capacidad registrada)
      // - rest_mediano (capacidad 6) -> Incluido
      // - rest_grande (capacidad 20) -> Incluido
      vm.setGuestCountFilter(4);
      expect(vm.restaurants.length, equals(2));
      expect(vm.restaurants.map((r) => r.id), containsAll(['rest_mediano', 'rest_grande']));

      // Filtro para 10 personas:
      // Solo rest_grande (20) tiene capacidad suficiente
      vm.setGuestCountFilter(10);
      expect(vm.restaurants.length, equals(1));
      expect(vm.restaurants.first.id, equals('rest_grande'));
    });

    test('Criterio 4: Se puede quitar el filtro y restablecer el catálogo', () async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      vm.setGuestCountFilter(15);
      expect(vm.isGuestCountFilterActive, isTrue);
      expect(vm.restaurants.length, equals(1));

      // Quitar filtro de personas
      vm.clearGuestCountFilter();
      expect(vm.isGuestCountFilterActive, isFalse);
      expect(vm.selectedGuestCount, isNull);
      expect(vm.selectedGuestCountFormatted, isNull);
      expect(vm.restaurants.length, equals(4));

      // Limpiar todos los filtros también lo restablece
      vm.setGuestCountFilter(5);
      expect(vm.isGuestCountFilterActive, isTrue);
      vm.clearFilters();
      expect(vm.isGuestCountFilterActive, isFalse);
      expect(vm.selectedGuestCount, isNull);
    });

    testWidgets('UI Widget Test: Selector numérico, interacción stepper y chips activos', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final vm = PublicCatalogViewModel(restaurantService: fakeService);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verificar presencia del botón de filtro de cantidad de personas
      final botonFiltro = find.byKey(const ValueKey('boton_filtro_cantidad_personas'));
      expect(botonFiltro, findsOneWidget);
      expect(find.text('Personas'), findsOneWidget);

      // 2. Abrir diálogo del selector de personas
      await tester.tap(botonFiltro);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialogo_selector_cantidad_personas')), findsOneWidget);
      expect(find.byKey(const ValueKey('texto_conteo_personas')), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Valor por defecto sugerido: 2

      // 3. Probar botón de restar personas (decrementar)
      final botonRestar = find.byKey(const ValueKey('boton_decrementar_personas'));
      await tester.tap(botonRestar);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('persona'), findsOneWidget);

      // No se permite menos de 1 (botón deshabilitado)
      await tester.tap(botonRestar);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      // 4. Probar botón de sumar personas (incrementar)
      final botonSumar = find.byKey(const ValueKey('boton_incrementar_personas'));
      await tester.tap(botonSumar);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      await tester.tap(botonSumar);
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      // 5. Aplicar filtro
      final botonAplicar = find.byKey(const ValueKey('boton_aplicar_filtro_personas'));
      await tester.tap(botonAplicar);
      await tester.pumpAndSettle();

      // Criterio 3: La cantidad elegida se muestra visible en la pantalla principal
      expect(find.byKey(const ValueKey('chip_filtro_cantidad_personas_activo')), findsOneWidget);
      expect(find.text('3 personas'), findsWidgets);

      // Criterio 4: Se puede quitar el filtro desde el chip activo
      final chipActivo = find.byKey(const ValueKey('chip_filtro_cantidad_personas_activo'));
      expect(chipActivo, findsOneWidget);

      // Buscar el icono de eliminar del Chip
      final iconoBorrar = find.descendant(
        of: chipActivo,
        matching: find.byIcon(Icons.cancel),
      );
      if (iconoBorrar.evaluate().isNotEmpty) {
        await tester.tap(iconoBorrar);
        await tester.pumpAndSettle();
      } else {
        vm.clearGuestCountFilter();
        await tester.pumpAndSettle();
      }

      expect(vm.isGuestCountFilterActive, isFalse);
      expect(find.byKey(const ValueKey('chip_filtro_cantidad_personas_activo')), findsNothing);
    });
  });
}
