import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/location_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/views/landing_view.dart';
import 'package:reservitta/views/location_filter_sheet.dart';

class FakeRestaurantLocationService extends RestaurantService {
  final List<RestaurantModel> restaurantsEnMemoria;

  FakeRestaurantLocationService({required this.restaurantsEnMemoria});

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
  group('LocationService (Haversine y Formato)', () {
    test('Calcula distancia precisa con fórmula de Haversine', () {
      // Ángel de la Independencia a Fuente de la Diana Cazadora (~850 metros)
      const lat1 = 19.4270;
      const lon1 = -99.1677;
      const lat2 = 19.4241;
      const lon2 = -99.1714;

      final distanceM = LocationService.calculateDistanceInMeters(
        lat1: lat1,
        lon1: lon1,
        lat2: lat2,
        lon2: lon2,
      );
      final distanceKm = LocationService.calculateDistanceInKm(
        lat1: lat1,
        lon1: lon1,
        lat2: lat2,
        lon2: lon2,
      );

      expect(distanceM, greaterThan(400));
      expect(distanceM, lessThan(800));
      expect(distanceKm, closeTo(distanceM / 1000.0, 0.01));
    });

    test('Formatea metros y kilómetros adecuadamente', () {
      expect(LocationService.formatDistance(350), '350 m');
      expect(LocationService.formatDistance(999), '999 m');
      expect(LocationService.formatDistance(1000), '1.0 km');
      expect(LocationService.formatDistance(2450), '2.5 km');
    });
  });

  group('23.- HU02-RF03 Interfaz del filtro de ubicación', () {
    late List<RestaurantModel> mockRestaurants;
    late FakeRestaurantLocationService fakeService;

    // Coordenada base: Ángel de la Independencia (CDMX)
    const userLat = 19.4270;
    const userLng = -99.1677;

    setUp(() {
      mockRestaurants = [
        const RestaurantModel(
          id: 'rest_cerca',
          nombre: 'Trattoria Cercana',
          direccion: 'Paseo de la Reforma 250, CDMX',
          telefono: '555-0001',
          correo: 'trattoria@test.com',
          estado: 'activo',
          coordenadas: GeoPoint(19.4280, -99.1660), // ~210 m
        ),
        const RestaurantModel(
          id: 'rest_medio',
          nombre: 'Bistró Roma',
          direccion: 'Colima 120, Roma Norte, CDMX',
          telefono: '555-0002',
          correo: 'bistro@test.com',
          estado: 'activo',
          coordenadas: GeoPoint(19.4180, -99.1600), // ~1.3 km
        ),
        const RestaurantModel(
          id: 'rest_lejos',
          nombre: 'Asador Santa Fe',
          direccion: 'Vasco de Quiroga 3800, Santa Fe, CDMX',
          telefono: '555-0003',
          correo: 'asador@test.com',
          estado: 'activo',
          coordenadas: GeoPoint(19.3600, -99.2600), // ~12.5 km
        ),
        const RestaurantModel(
          id: 'rest_sin_coords',
          nombre: 'Café Virtual',
          direccion: 'Solo a domicilio',
          telefono: '555-0004',
          correo: 'cafe@test.com',
          estado: 'activo',
          coordenadas: null,
        ),
      ];

      fakeService = FakeRestaurantLocationService(restaurantsEnMemoria: mockRestaurants);
    });

    Widget createTestApp(PublicCatalogViewModel vm) {
      return MaterialApp(
        home: LandingView(viewModel: vm),
      );
    }

    testWidgets('Criterio 1: Hay un control de filtro de ubicación en pantalla principal que abre el Bottom Sheet', (tester) async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      await tester.pumpWidget(createTestApp(vm));
      await tester.pumpAndSettle();

      // Debe haber un control/chip con la key boton_filtro_ubicacion
      final ubicacionChipFinder = find.byKey(const ValueKey('boton_filtro_ubicacion'));
      expect(ubicacionChipFinder, findsOneWidget);
      expect(find.text('Cerca de mí / Ubicación'), findsOneWidget);

      // Al tocar el control se abre el Bottom Sheet de ubicación
      await tester.tap(ubicacionChipFinder);
      await tester.pumpAndSettle();

      expect(find.byType(LocationFilterSheet), findsOneWidget);
      expect(find.text('Filtro de Ubicación'), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_usar_gps_ubicacion')), findsOneWidget);
      expect(find.textContaining('Radio de búsqueda'), findsOneWidget);
    });

    testWidgets('Criterio 2: Cada tarjeta muestra distancia aproximada cuando el filtro está activo y se ordena por cercanía', (tester) async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      // Activamos filtro de 5 km en Ángel de la Independencia
      vm.setLocationFilter(
        location: const UserLocation(
          latitude: userLat,
          longitude: userLng,
          label: 'Mi ubicación',
        ),
        radiusKm: 5.0,
      );

      await tester.pumpWidget(createTestApp(vm));
      await tester.pumpAndSettle();

      // Debe mostrar restaurantes dentro del radio (Trattoria Cercana y Bistró Roma)
      expect(find.text('Trattoria Cercana'), findsOneWidget);
      expect(find.text('Bistró Roma'), findsOneWidget);

      // Asador Santa Fe (12.5 km) y Café Virtual (sin coords) NO deben aparecer en resultados
      expect(find.text('Asador Santa Fe'), findsNothing);
      expect(find.text('Café Virtual'), findsNothing);

      // Verificamos que se muestre la distancia en las tarjetas
      expect(find.byKey(const ValueKey('distancia_rest_cerca')), findsOneWidget);
      expect(find.byKey(const ValueKey('distancia_rest_medio')), findsOneWidget);

      // El orden debe ser ascendente por cercanía (primero Trattoria ~210m, luego Bistró ~1.3km)
      expect(vm.restaurants.first.id, 'rest_cerca');
      expect(vm.restaurants[1].id, 'rest_medio');
    });

    testWidgets('Criterio 3: El usuario puede quitar el filtro y volver al listado completo', (tester) async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      // Activamos filtro
      vm.setLocationFilter(
        location: const UserLocation(
          latitude: userLat,
          longitude: userLng,
          label: 'Centro CDMX',
        ),
        radiusKm: 2.0,
      );

      await tester.pumpWidget(createTestApp(vm));
      await tester.pumpAndSettle();

      // Solo hay 2 restaurantes visibles dentro del radio
      expect(vm.restaurants.length, 2);

      // Verificamos que el chip de filtro activo está en pantalla
      final chipFiltroActivo = find.byKey(const ValueKey('chip_filtro_ubicacion_activo'));
      expect(chipFiltroActivo, findsOneWidget);

      // El usuario quita el filtro
      vm.clearLocationFilter();
      await tester.pumpAndSettle();

      // El filtro debe haberse quitado y el listado vuelve a tener los 4 restaurantes completos
      expect(vm.isLocationFilterActive, isFalse);
      expect(vm.restaurants.length, 4);
      expect(vm.restaurants.any((r) => r.id == 'rest_cerca'), isTrue);
      expect(vm.restaurants.any((r) => r.id == 'rest_medio'), isTrue);
      expect(vm.restaurants.any((r) => r.id == 'rest_lejos'), isTrue);
      expect(vm.restaurants.any((r) => r.id == 'rest_sin_coords'), isTrue);
    });

    testWidgets('Criterio 4: Si no hay resultados en el radio elegido, muestra mensaje y opción de ampliar el radio', (tester) async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      // Ubicación en Guadalajara (a ~450 km de la CDMX) con radio de 5 km
      vm.setLocationFilter(
        location: const UserLocation(
          latitude: 20.6767,
          longitude: -103.3472,
          label: 'Guadalajara Centro',
        ),
        radiusKm: 5.0,
      );

      await tester.pumpWidget(createTestApp(vm));
      await tester.pumpAndSettle();

      // Lista vacía
      expect(vm.restaurants.isEmpty, isTrue);

      // Mensaje de estado vacío
      expect(find.text('Sin restaurantes en el radio elegido'), findsOneWidget);
      expect(find.textContaining('alrededor de Guadalajara Centro.'), findsOneWidget);

      // Botón para ampliar radio
      final ampliarButtonFinder = find.byKey(const ValueKey('boton_ampliar_radio'));
      expect(ampliarButtonFinder, findsOneWidget);

      // Botón para quitar filtro
      final quitarButtonFinder = find.byKey(const ValueKey('boton_quitar_filtro_ubicacion_vacio'));
      expect(quitarButtonFinder, findsOneWidget);

      // Asegurar visibilidad del botón en CustomScrollView antes de hacer tap
      await tester.ensureVisible(ampliarButtonFinder);
      await tester.pumpAndSettle();

      // Al presionar "Ampliar radio de búsqueda", el radio aumenta (de 5 a 10 km)
      await tester.tap(ampliarButtonFinder);
      await tester.pumpAndSettle();

      expect(vm.selectedRadiusKm, 10.0);
    });
  });
}
