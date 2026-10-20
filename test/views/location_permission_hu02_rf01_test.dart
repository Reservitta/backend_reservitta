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

/// Proveedor de ubicación simulado para pruebas de permisos y estados de GPS
class MockLocationProvider implements LocationProvider {
  bool serviceEnabled;
  LocationPermissionStatus permissionStatus;
  UserLocation? mockPosition;
  int checkPermissionCallCount = 0;
  int requestPermissionCallCount = 0;
  int getCurrentPositionCallCount = 0;

  MockLocationProvider({
    this.serviceEnabled = true,
    this.permissionStatus = LocationPermissionStatus.granted,
    this.mockPosition = const UserLocation(
      latitude: 19.4326,
      longitude: -99.1332,
      label: 'Mi ubicación actual',
      isGps: true,
    ),
  });

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    checkPermissionCallCount++;
    return permissionStatus;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestPermissionCallCount++;
    return permissionStatus;
  }

  @override
  Future<UserLocation?> getCurrentPosition() async {
    getCurrentPositionCallCount++;
    return mockPosition;
  }
}

class FakeRestaurantServiceHU01 extends RestaurantService {
  final List<RestaurantModel> restaurantsEnMemoria;

  FakeRestaurantServiceHU01({required this.restaurantsEnMemoria});

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
  group('22.- HU02-RF01 Permiso y obtención de ubicación', () {
    late List<RestaurantModel> mockRestaurants;
    late FakeRestaurantServiceHU01 fakeRestaurantService;

    setUp(() {
      mockRestaurants = [
        const RestaurantModel(
          id: 'rest_cdmx_1',
          nombre: 'Restaurante Centro CDMX',
          direccion: 'Calle Madero 10, CDMX',
          estado: 'activo',
          coordenadas: GeoPoint(19.4330, -99.1330),
        ),
        const RestaurantModel(
          id: 'rest_cdmx_2',
          nombre: 'Bistró Polanco',
          direccion: 'Campos Elíseos 200, CDMX',
          estado: 'activo',
          coordenadas: GeoPoint(19.4335, -99.1900),
        ),
      ];

      fakeRestaurantService = FakeRestaurantServiceHU01(
        restaurantsEnMemoria: mockRestaurants,
      );
    });

    Widget createTestApp(PublicCatalogViewModel vm) {
      return MaterialApp(
        home: LandingView(viewModel: vm),
      );
    }

    testWidgets('Criterio 1: El permiso de ubicación se solicita solo cuando el usuario activa el filtro, NO al abrir la app', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockLocationProvider = MockLocationProvider();
      final locationService = LocationService(locationProvider: mockLocationProvider);
      final vm = PublicCatalogViewModel(
        restaurantService: fakeRestaurantService,
        locationService: locationService,
      );

      // 1. Abrimos la app e inicializamos la vista
      await vm.init();
      await tester.pumpWidget(createTestApp(vm));
      await tester.pumpAndSettle();

      // Verificación: No se ha solicitado permiso ni ubicación al abrir la app
      expect(mockLocationProvider.checkPermissionCallCount, 0);
      expect(mockLocationProvider.requestPermissionCallCount, 0);
      expect(mockLocationProvider.getCurrentPositionCallCount, 0);

      // 2. El usuario presiona el chip de ubicación en la pantalla principal
      final ubicacionChip = find.byKey(const ValueKey('boton_filtro_ubicacion'));
      expect(ubicacionChip, findsOneWidget);
      await tester.tap(ubicacionChip);
      await tester.pumpAndSettle();

      // Sigue sin solicitarse el permiso hasta que el usuario decida usar GPS
      expect(mockLocationProvider.requestPermissionCallCount, 0);

      // 3. El usuario pulsa explícitamente "Usar mi ubicación actual (GPS)"
      final gpsButton = find.byKey(const ValueKey('boton_usar_gps_ubicacion'));
      expect(gpsButton, findsOneWidget);
      await tester.tap(gpsButton);
      await tester.pumpAndSettle();

      // Ahora sí se solicitó la ubicación bajo demanda
      expect(mockLocationProvider.getCurrentPositionCallCount, 1);
    });

    testWidgets('Criterio 2: Si acepta el permiso, la app obtiene las coordenadas actuales con GPS', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const expectedLat = 19.4337;
      const expectedLng = -99.1906;

      final mockLocationProvider = MockLocationProvider(
        serviceEnabled: true,
        permissionStatus: LocationPermissionStatus.granted,
        mockPosition: const UserLocation(
          latitude: expectedLat,
          longitude: expectedLng,
          label: 'Mi ubicación actual',
          isGps: true,
        ),
      );

      final locationService = LocationService(locationProvider: mockLocationProvider);
      final vm = PublicCatalogViewModel(
        restaurantService: fakeRestaurantService,
        locationService: locationService,
      );

      await vm.init();
      await tester.pumpWidget(createTestApp(vm));
      await tester.pumpAndSettle();

      // Abrir modal de ubicación
      await tester.tap(find.byKey(const ValueKey('boton_filtro_ubicacion')));
      await tester.pumpAndSettle();

      // Presionar botón GPS
      await tester.tap(find.byKey(const ValueKey('boton_usar_gps_ubicacion')));
      await tester.pumpAndSettle();

      // Verificar que se detectaron las coordenadas y se muestra la etiqueta
      expect(find.text('Mi ubicación actual'), findsOneWidget);

      // Aplicar el filtro
      final aplicarBtn = find.byKey(const ValueKey('boton_aplicar_filtro_ubicacion'));
      await tester.ensureVisible(aplicarBtn);
      await tester.tap(aplicarBtn);
      await tester.pumpAndSettle();

      // El ViewModel debe tener las coordenadas GPS exactas
      expect(vm.isLocationFilterActive, isTrue);
      expect(vm.selectedLocation!.latitude, expectedLat);
      expect(vm.selectedLocation!.longitude, expectedLng);
      expect(vm.selectedLocation!.isGps, isTrue);
    });

    testWidgets('Criterio 3a: Si deniega el permiso, se ofrece elegir manualmente una ciudad o zona', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockLocationProviderDenied = MockLocationProvider(
        serviceEnabled: true,
        permissionStatus: LocationPermissionStatus.denied,
      );

      final locationServiceDenied = LocationService(locationProvider: mockLocationProviderDenied);
      final vmDenied = PublicCatalogViewModel(
        restaurantService: fakeRestaurantService,
        locationService: locationServiceDenied,
      );

      await vmDenied.init();
      await tester.pumpWidget(createTestApp(vmDenied));
      await tester.pumpAndSettle();

      // Abrir modal de ubicación
      await tester.tap(find.byKey(const ValueKey('boton_filtro_ubicacion')));
      await tester.pumpAndSettle();

      // Pulsar botón de GPS
      await tester.tap(find.byKey(const ValueKey('boton_usar_gps_ubicacion')));
      await tester.pumpAndSettle();

      // Se despliega el aviso informativo sin bloquear la app
      expect(find.byKey(const ValueKey('aviso_permiso_denegado_o_gps_apagado')), findsOneWidget);
      expect(find.textContaining('denegado el permiso'), findsOneWidget);
      expect(find.textContaining('puedes elegir manualmente una ciudad o zona'), findsOneWidget);

      // La sección de selección manual está visible y operable
      expect(find.text('O elige una ciudad o zona manualmente'), findsOneWidget);
      expect(find.byKey(const ValueKey('campo_buscar_zona_manual')), findsOneWidget);

      // El usuario elige manualmente una zona sugerida (ej. CDMX - Polanco)
      final presetPolanco = find.byKey(const ValueKey('preset_CDMX - Polanco'));
      expect(presetPolanco, findsOneWidget);
      await tester.ensureVisible(presetPolanco);
      await tester.tap(presetPolanco);
      await tester.pumpAndSettle();

      // Aplica el filtro con la zona manual
      final aplicarBtn = find.byKey(const ValueKey('boton_aplicar_filtro_ubicacion'));
      await tester.ensureVisible(aplicarBtn);
      await tester.tap(aplicarBtn);
      await tester.pumpAndSettle();

      expect(vmDenied.isLocationFilterActive, isTrue);
      expect(vmDenied.selectedLocation!.label, 'CDMX - Polanco');
      expect(vmDenied.selectedLocation!.isGps, isFalse);
    });

    testWidgets('Criterio 3b: Si el GPS está apagado, se advierte y se ofrece elegir manualmente una ciudad o zona', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockLocationProviderGpsOff = MockLocationProvider(
        serviceEnabled: false,
      );
      final locationServiceGpsOff = LocationService(locationProvider: mockLocationProviderGpsOff);
      final vmGpsOff = PublicCatalogViewModel(
        restaurantService: fakeRestaurantService,
        locationService: locationServiceGpsOff,
      );

      await vmGpsOff.init();
      await tester.pumpWidget(createTestApp(vmGpsOff));
      await tester.pumpAndSettle();

      // Abrir modal y pulsar GPS
      await tester.tap(find.byKey(const ValueKey('boton_filtro_ubicacion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('boton_usar_gps_ubicacion')));
      await tester.pumpAndSettle();

      // Debe advertir que el servicio GPS está desactivado y ofrecer selección manual
      expect(find.byKey(const ValueKey('aviso_permiso_denegado_o_gps_apagado')), findsOneWidget);
      expect(find.textContaining('desactivado en tu dispositivo'), findsOneWidget);
      expect(find.textContaining('puedes elegir manualmente una ciudad o zona'), findsOneWidget);
    });

    testWidgets('Criterio 4: Negar el permiso no bloquea el uso del resto de la app', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockLocationProvider = MockLocationProvider(
        serviceEnabled: true,
        permissionStatus: LocationPermissionStatus.denied,
      );
      final locationService = LocationService(locationProvider: mockLocationProvider);
      final vm = PublicCatalogViewModel(
        restaurantService: fakeRestaurantService,
        locationService: locationService,
      );

      await vm.init();
      await tester.pumpWidget(createTestApp(vm));
      await tester.pumpAndSettle();

      // Abrir modal y denegar GPS
      await tester.tap(find.byKey(const ValueKey('boton_filtro_ubicacion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('boton_usar_gps_ubicacion')));
      await tester.pumpAndSettle();

      // Cerrar el bottom sheet deslizando hacia atrás o pulsando fuera
      Navigator.of(tester.element(find.byType(LocationFilterSheet))).pop();
      await tester.pumpAndSettle();

      // Verificar que el resto de la app funciona sin ningún bloqueo
      expect(find.text('Bienvenido a Reservitta'), findsOneWidget);
      expect(find.text('Restaurante Centro CDMX'), findsOneWidget);
      expect(find.text('Bistró Polanco'), findsOneWidget);

      // El usuario puede usar el buscador por texto con normalidad
      final searchField = find.byKey(const ValueKey('campo_buscar_restaurantes'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Centro');
      await tester.pumpAndSettle();

      expect(vm.searchQuery, 'Centro');
      expect(find.text('Restaurante Centro CDMX'), findsOneWidget);
    });
  });
}
