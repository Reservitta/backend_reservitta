import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/views/landing_view.dart';
import 'package:reservitta/views/restaurant_detail_view.dart';

/// Servicio de restaurantes simulado para pruebas unitarias y de widgets
class FakeRestaurantService extends RestaurantService {
  final List<RestaurantModel> restaurantsEnMemoria;
  final List<ServiceCatalogModel> servicesEnMemoria;

  FakeRestaurantService({
    required this.restaurantsEnMemoria,
    required this.servicesEnMemoria,
  });

  @override
  Future<List<ServiceCatalogModel>> getServicesCatalog() async {
    return servicesEnMemoria;
  }

  @override
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async {
    List<RestaurantModel> filtrados = restaurantsEnMemoria
        .where((r) => r.estado == 'activo')
        .toList();

    if (servicioId != null && servicioId.isNotEmpty) {
      filtrados = filtrados.where((r) => r.serviciosIds.contains(servicioId)).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtrados = filtrados
          .where((r) =>
              r.nombre.toLowerCase().contains(q) ||
              r.direccion.toLowerCase().contains(q))
          .toList();
    }

    return PaginatedRestaurantsResult(
      restaurants: filtrados,
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

/// Servicio de autenticación simulado para probar estado con o sin sesión
class FakeAuthService extends AuthService {
  final bool isAuthenticated;

  FakeAuthService({this.isAuthenticated = false});

  bool get isSignedIn => isAuthenticated;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => Stream.value(null);
}

/// Fake de categorías para pruebas de menú en detalle
class FakeCategoriaService extends CategoriaService {
  final List<CategoriaModel> categorias;

  FakeCategoriaService({this.categorias = const []});

  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) {
    return Stream.value(categorias);
  }
}

/// Fake de platillos para pruebas de menú en detalle
class FakePlatilloService extends PlatilloService {
  final List<PlatilloModel> platillos;

  FakePlatilloService({this.platillos = const []});

  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) {
    return Stream.value(platillos);
  }
}

void main() {
  group('HU01-RF03 Navegación pública sin sesión FE/BE', () {
    late FakeRestaurantService fakeRestaurantService;
    late FakeCategoriaService fakeCategoriaService;
    late FakePlatilloService fakePlatilloService;
    late List<RestaurantModel> mockRestaurants;
    late List<ServiceCatalogModel> mockServices;

    setUp(() {
      mockServices = [
        const ServiceCatalogModel(
          id: 'wifi',
          nombre: 'Wi-Fi Gratis',
          icono: 'wifi',
          activo: true,
        ),
        const ServiceCatalogModel(
          id: 'terraza',
          nombre: 'Terraza',
          icono: 'deck',
          activo: true,
        ),
      ];

      mockRestaurants = [
        const RestaurantModel(
          id: 'rest_1',
          nombre: 'Trattoria Bella',
          direccion: 'Av. Reforma 101, CDMX',
          telefono: '555-1111',
          correo: 'contacto@trattoria.com',
          estado: 'activo',
          serviciosIds: ['wifi', 'terraza'],
          horarios: {
            'lunes': DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00'),
          },
        ),
        const RestaurantModel(
          id: 'rest_2',
          nombre: 'Taquería El Pastor',
          direccion: 'Calle Durango 45, CDMX',
          telefono: '555-2222',
          correo: 'contacto@taqueria.com',
          estado: 'activo',
          serviciosIds: ['wifi'],
        ),
      ];

      fakeRestaurantService = FakeRestaurantService(
        restaurantsEnMemoria: mockRestaurants,
        servicesEnMemoria: mockServices,
      );

      fakeCategoriaService = FakeCategoriaService(
        categorias: [
          const CategoriaModel(
            id: 'cat_pastas',
            nombre: 'Pastas Artesanales',
            nombreNormalizado: 'pastas artesanales',
            orden: 1,
          ),
        ],
      );

      fakePlatilloService = FakePlatilloService(
        platillos: [
          PlatilloModel(
            id: 'plat_1',
            nombre: 'Fettuccine Alfredo',
            descripcion: 'Pasta fresca con salsa cremosa de parmesano',
            precio: 210.0,
            categoriaId: 'cat_pastas',
            estado: 'activo',
          ),
        ],
      );
    });

    test('ViewModel: Criterio 1 y 2 - Carga catálogo público y permite filtros sin requerir sesión', () async {
      final fakeAuth = FakeAuthService(isAuthenticated: false);
      final vm = PublicCatalogViewModel(
        restaurantService: fakeRestaurantService,
        authService: fakeAuth,
      );

      expect(vm.isUserAuthenticated, isFalse);
      expect(vm.isLoading, isFalse);

      await vm.init();

      // Criterio 1: Carga los restaurantes sin autenticación
      expect(vm.restaurants.length, 2);
      expect(vm.restaurants.first.nombre, 'Trattoria Bella');
      expect(vm.availableServices.length, 2);
      expect(vm.errorMessage, isNull);

      // Criterio 2: Filtrado por texto sin sesión
      vm.setSearchQuery('Taquería');
      await Future<void>.delayed(Duration.zero);
      expect(vm.restaurants.length, 1);
      expect(vm.restaurants.first.nombre, 'Taquería El Pastor');

      // Limpiar filtros
      vm.clearFilters();
      await Future<void>.delayed(Duration.zero);
      expect(vm.restaurants.length, 2);

      // Filtrado por servicio sin sesión
      vm.toggleServiceFilter('terraza');
      await Future<void>.delayed(Duration.zero);
      expect(vm.restaurants.length, 1);
      expect(vm.restaurants.first.nombre, 'Trattoria Bella');
    });

    testWidgets('Widget: Criterio 1 - La pantalla principal abre sin pedir login o registro obligatorio', (tester) async {
      final fakeAuth = FakeAuthService(isAuthenticated: false);
      final vm = PublicCatalogViewModel(
        restaurantService: fakeRestaurantService,
        authService: fakeAuth,
      );
      await vm.init();

      await tester.pumpWidget(MaterialApp(
        home: LandingView(viewModel: vm),
      ));

      await tester.pumpAndSettle();

      // Verifica que el hero y título de bienvenida sean visibles inmediatamente
      expect(find.text('Bienvenido a Reservitta'), findsOneWidget);
      expect(find.byKey(const ValueKey('campo_buscar_restaurantes')), findsOneWidget);

      // Verifica que las tarjetas de restaurantes aparezcan sin pedir sesión
      expect(find.text('Trattoria Bella'), findsOneWidget);
      expect(find.text('Taquería El Pastor'), findsOneWidget);

      // Verifica botones opcionales de acceso en el header
      expect(find.byKey(const ValueKey('boton_header_iniciar_sesion')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_header_registrarse')), findsOneWidget);
    });

    testWidgets('Widget: Criterio 2 - La pantalla de detalle de restaurante es accesible sin sesión', (tester) async {
      final fakeAuth = FakeAuthService(isAuthenticated: false);
      final restaurant = mockRestaurants.first;

      await tester.pumpWidget(MaterialApp(
        home: RestaurantDetailView(
          restaurant: restaurant,
          authService: fakeAuth,
          categoriaService: fakeCategoriaService,
          platilloService: fakePlatilloService,
        ),
      ));

      await tester.pumpAndSettle();

      // La información del restaurante se muestra libremente
      expect(find.text('Trattoria Bella'), findsAtLeast(1));
      expect(find.text('Av. Reforma 101, CDMX'), findsAtLeast(1));
      expect(find.text('555-1111'), findsOneWidget);
      expect(find.text('contacto@trattoria.com'), findsOneWidget);
      expect(find.text('ACTIVO'), findsOneWidget);
      expect(find.text('Horarios de Atención'), findsOneWidget);
      expect(find.text('Servicios e Instalaciones'), findsOneWidget);
      expect(find.text('Menú y Platillos'), findsOneWidget);
      expect(find.text('Pastas Artesanales'), findsOneWidget);
      expect(find.text('Fettuccine Alfredo'), findsOneWidget);
      expect(find.text('\$210.00 MXN'), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_reservar_mesa')), findsOneWidget);
    });

    testWidgets('Widget: Criterio 3 - La acción de reservar sin sesión redirige a inicio de sesión / registro', (tester) async {
      final fakeAuth = FakeAuthService(isAuthenticated: false);
      final restaurant = mockRestaurants.first;

      await tester.pumpWidget(MaterialApp(
        home: RestaurantDetailView(
          restaurant: restaurant,
          authService: fakeAuth,
          categoriaService: fakeCategoriaService,
          platilloService: fakePlatilloService,
        ),
      ));

      await tester.pumpAndSettle();

      // Presionar "Reservar Mesa" sin tener sesión iniciada
      final botonReservar = find.byKey(const ValueKey('boton_reservar_mesa'));
      expect(botonReservar, findsOneWidget);
      await tester.tap(botonReservar);
      await tester.pumpAndSettle();

      // Debe abrirse el modal / diálogo de autenticación con opciones de acceso
      expect(find.text('Iniciar Sesión'), findsAtLeast(1));
      expect(find.textContaining('Para reservar en Trattoria Bella necesitas'), findsOneWidget);
    });
  });
}
