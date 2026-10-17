import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/views/landing_view.dart';

class _FakeRestaurantService extends RestaurantService {
  @override
  Future<List<ServiceCatalogModel>> getServicesCatalog() async => [];

  @override
  Future<PaginatedRestaurantsResult> getActiveRestaurants({
    int limit = 10,
    dynamic startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async {
    return const PaginatedRestaurantsResult(
      restaurants: [],
      hasMore: false,
    );
  }
}

class _FakeAuthService extends AuthService {
  @override
  User? get currentUser => null;
}

void main() {
  testWidgets('landing page presents sign-in and registration actions', (
    tester,
  ) async {
    final vm = PublicCatalogViewModel(
      restaurantService: _FakeRestaurantService(),
      authService: _FakeAuthService(),
    );
    await vm.init();

    await tester.pumpWidget(MaterialApp(home: LandingView(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a Reservitta'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsAtLeast(1));
  });
}
