import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/views/landing_view.dart';

class _FakeRestaurantService extends RestaurantService {
  final List<RestaurantModel> restaurants;

  _FakeRestaurantService(this.restaurants);

  @override
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async {
    var filtrados = restaurants.where((r) => r.isActivo).toList();
    if (servicioId != null && servicioId.isNotEmpty) {
      filtrados = filtrados.where((r) => r.serviciosIds.contains(servicioId)).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtrados = filtrados.where((r) =>
          r.nombre.toLowerCase().contains(q) ||
          r.direccion.toLowerCase().contains(q)).toList();
    }
    return PaginatedRestaurantsResult(
      restaurants: filtrados,
      hasMore: false,
    );
  }

  @override
  Future<List<ServiceCatalogModel>> getServicesCatalog() async {
    return const [];
  }
}

class _FakeAuthService extends Fake implements AuthService {
  @override
  User? get currentUser => null;
}

void main() {
  final mockRestaurants = [
    const RestaurantModel(
      id: 'rest_1',
      nombre: 'Trattoria Bella',
      estado: 'activo',
      direccion: 'Av. Italia 123',
      serviciosIds: ['terraza', 'estacionamiento'],
      diasAbiertos: ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'],
      capacidadMaxima: 4,
    ),
    const RestaurantModel(
      id: 'rest_2',
      nombre: 'Taquería El Pastor',
      estado: 'activo',
      direccion: 'Calle Sol 456',
      serviciosIds: ['wifi'],
      diasAbiertos: ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'],
      capacidadMaxima: 10,
    ),
  ];

  group('Limpieza de filtros con un solo botón en el listado principal de restaurantes', () {
    testWidgets('Permite limpiar todos los filtros activos con un solo botón desde la barra de filtros', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = _FakeRestaurantService(mockRestaurants);
      final vm = PublicCatalogViewModel(
        restaurantService: service,
        authService: _FakeAuthService(),
      );
      await vm.init();

      await tester.pumpWidget(
        MaterialApp(
          home: LandingView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trattoria Bella'), findsOneWidget);
      expect(find.text('Taquería El Pastor'), findsOneWidget);

      // 1. Activar múltiples filtros: texto y cantidad de personas
      vm.setSearchQuery('Taquería');
      vm.setGuestCountFilter(2);
      await tester.pumpAndSettle();

      expect(vm.hasActiveFilters, isTrue);
      expect(vm.restaurants.length, equals(1));
      expect(find.text('Trattoria Bella'), findsNothing);
      expect(find.text('Taquería El Pastor'), findsOneWidget);

      // 2. Verificar que aparece el botón de limpiar filtros en la barra horizontal
      final botonLimpiarBarra = find.byKey(const ValueKey('boton_limpiar_filtros_barra'));
      expect(botonLimpiarBarra, findsOneWidget);

      // 3. Pulsar el botón de limpiar filtros con un solo toque
      await tester.tap(botonLimpiarBarra);
      await tester.pumpAndSettle();

      // 4. Todos los filtros deben quedar restablecidos y mostrarse todo el catálogo
      expect(vm.hasActiveFilters, isFalse);
      expect(vm.searchQuery, isEmpty);
      expect(vm.isGuestCountFilterActive, isFalse);
      expect(vm.isLocationFilterActive, isFalse);
      expect(vm.isDateTimeFilterActive, isFalse);
      expect(vm.selectedServiceId, isNull);
      expect(vm.restaurants.length, equals(2));
      expect(find.text('Trattoria Bella'), findsOneWidget);
      expect(find.text('Taquería El Pastor'), findsOneWidget);
    });

    testWidgets('Permite limpiar todos los filtros con un solo botón desde el estado vacío (sin resultados)', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = _FakeRestaurantService(mockRestaurants);
      final vm = PublicCatalogViewModel(
        restaurantService: service,
        authService: _FakeAuthService(),
      );
      await vm.init();

      await tester.pumpWidget(
        MaterialApp(
          home: LandingView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Aplicar un filtro que no coincida con ningún restaurante
      vm.setSearchQuery('Restaurante Inexistente 999');
      await tester.pumpAndSettle();

      expect(vm.restaurants.isEmpty, isTrue);
      expect(find.text('Trattoria Bella'), findsNothing);
      expect(find.text('Taquería El Pastor'), findsNothing);

      // 2. Verificar que se muestra el botón "Limpiar todos los filtros" en el estado vacío
      final botonLimpiarVacio = find.byKey(const ValueKey('boton_limpiar_filtros_vacio'));
      expect(botonLimpiarVacio, findsOneWidget);

      // 3. Pulsar el botón con un solo toque
      await tester.tap(botonLimpiarVacio);
      await tester.pumpAndSettle();

      // 4. El catálogo completo debe restablecerse de inmediato
      expect(vm.hasActiveFilters, isFalse);
      expect(vm.restaurants.length, equals(2));
      expect(find.text('Trattoria Bella'), findsOneWidget);
      expect(find.text('Taquería El Pastor'), findsOneWidget);
    });

    testWidgets('Permite limpiar todos los filtros desde la barra de filtros activos', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = _FakeRestaurantService(mockRestaurants);
      final vm = PublicCatalogViewModel(
        restaurantService: service,
        authService: _FakeAuthService(),
      );
      await vm.init();

      await tester.pumpWidget(
        MaterialApp(
          home: LandingView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      // Activar filtro
      vm.setGuestCountFilter(3);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('boton_limpiar_filtros')), findsOneWidget);

      // Pulsar "Limpiar todos"
      await tester.tap(find.byKey(const ValueKey('boton_limpiar_filtros')));
      await tester.pumpAndSettle();

      expect(vm.hasActiveFilters, isFalse);
      expect(vm.isGuestCountFilterActive, isFalse);
    });
  });
}
