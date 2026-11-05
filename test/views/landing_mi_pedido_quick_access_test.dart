import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/views/landing_view.dart';
import 'package:reservitta/views/mi_pedido_view.dart';

class _FakeRestaurantService extends RestaurantService {
  final List<RestaurantModel> restaurants;
  _FakeRestaurantService(this.restaurants);

  @override
  Future<List<ServiceCatalogModel>> getServicesCatalog() async => [];

  @override
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    dynamic startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async {
    return PaginatedRestaurantsResult(
      restaurants: restaurants,
      lastDocument: null,
      hasMore: false,
    );
  }
}

class _FakeAuthService extends AuthService {
  final bool _isAuth;
  _FakeAuthService(this._isAuth);

  @override
  bool get isAuthenticated => _isAuth;
}

void main() {
  final testRestaurant = const RestaurantModel(
    id: 'rest_demo',
    nombre: 'Miel Aurum',
    estado: 'activo',
  );

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Visitante sin sesión NO ve el acceso rápido a Mi Pedido en el menú principal',
    (tester) async {
      setScreenSize(tester);
      final vm = PublicCatalogViewModel(
        restaurantService: _FakeRestaurantService([testRestaurant]),
        isAuthenticated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LandingView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('btn_header_mi_pedido')), findsNothing);
      expect(find.byKey(const ValueKey('card_acceso_rapido_mi_pedido')), findsNothing);
    },
  );

  testWidgets(
    'Usuario con sesión iniciada ve el acceso rápido a Mi Pedido y al pulsar abre MiPedidoView',
    (tester) async {
      setScreenSize(tester);
      final vm = PublicCatalogViewModel(
        restaurantService: _FakeRestaurantService([testRestaurant]),
        isAuthenticated: true,
        currentUserName: 'gaelq1074@gmail.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LandingView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica presencia del botón en el Header y la tarjeta de acceso rápido
      expect(find.byKey(const ValueKey('btn_header_mi_pedido')), findsOneWidget);
      expect(find.byKey(const ValueKey('card_acceso_rapido_mi_pedido')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_acceso_rapido_mi_pedido')), findsOneWidget);

      // Pulsa el botón "Ver mi pedido (3 platillos)" de la tarjeta
      await tester.tap(find.byKey(const ValueKey('btn_acceso_rapido_mi_pedido')));
      await tester.pumpAndSettle();

      // Debe abrir MiPedidoView
      expect(find.byType(MiPedidoView), findsOneWidget);
      expect(find.text('Mi pedido'), findsOneWidget);

      // Muestra el resumen de reserva de solo lectura
      expect(find.byKey(const ValueKey('resumen_reserva_mi_pedido')), findsOneWidget);

      // Lista platillos con cantidad, precios y subtotal
      expect(find.text('Ribeye a la Leña'), findsOneWidget);
      expect(find.text('Ceviche Mixto'), findsOneWidget);
      expect(find.text('Vino Tinto Reserva'), findsOneWidget);
      expect(find.byKey(const ValueKey('texto_subtotal_general')), findsOneWidget);

      // Controles requeridos de HU16-RF06
      expect(find.byKey(const ValueKey('btn_agregar_mas_platillos')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_continuar_ocasion')), findsOneWidget);
    },
  );
}
