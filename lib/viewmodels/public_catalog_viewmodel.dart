import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../models/service_catalog_model.dart';
import '../services/auth_service.dart';
import '../services/restaurant_service.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import '../views/auth_modal_dialog.dart';

/// ViewModel para la navegación pública sin sesión y catálogo de restaurantes (HU01-RF03)
class PublicCatalogViewModel extends ChangeNotifier {
  final RestaurantService _restaurantService;
  final AuthService _authService;

  PublicCatalogViewModel({
    RestaurantService? restaurantService,
    AuthService? authService,
  })  : _restaurantService = restaurantService ?? RestaurantService(),
        _authService = authService ?? AuthService();

  // Estados de datos
  List<RestaurantModel> _restaurants = [];
  List<ServiceCatalogModel> _availableServices = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  // Estados de interfaz y red
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  // Filtros activos
  String _searchQuery = '';
  String? _selectedServiceId;

  // Getters
  List<RestaurantModel> get restaurants => _restaurants;
  List<ServiceCatalogModel> get availableServices => _availableServices;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedServiceId => _selectedServiceId;
  bool get hasActiveFilters => _searchQuery.isNotEmpty || _selectedServiceId != null;

  /// Indica si el usuario actual cuenta con una sesión iniciada
  bool get isUserAuthenticated => _authService.currentUser != null;

  /// Nombre del usuario autenticado si existe sesión
  String? get currentUserName => _authService.currentUser?.displayName ?? _authService.currentUser?.email;

  /// Carga inicial del catálogo y servicios
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _availableServices = await _restaurantService.getServicesCatalog();
    } catch (_) {
      _availableServices = [];
    }

    await _fetchFirstPage();
  }

  /// Carga la primera página de restaurantes activos
  Future<void> _fetchFirstPage() async {
    _isLoading = true;
    _errorMessage = null;
    _lastDocument = null;
    notifyListeners();

    try {
      final result = await _restaurantService.getActiveRestaurants(
        limit: 10,
        startAfterDocument: null,
        searchQuery: _searchQuery,
        servicioId: _selectedServiceId,
      );

      _restaurants = result.restaurants;
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
    } catch (e) {
      // HU01-RF01 Criterio 5: Error controlado sin cerrar la app
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _restaurants = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga la siguiente página para scroll infinito (HU01-RF02 Criterio 6)
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _restaurantService.getActiveRestaurants(
        limit: 10,
        startAfterDocument: _lastDocument,
        searchQuery: _searchQuery,
        servicioId: _selectedServiceId,
      );

      _restaurants.addAll(result.restaurants);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
    } catch (e) {
      // Si falla la página siguiente, mantenemos lo ya cargado sin romper la app
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresca los restaurantes activos con pull-to-refresh (HU01-RF02 Criterio 7)
  Future<void> refresh() async {
    await _fetchFirstPage();
  }

  /// Aplica búsqueda por texto (nombre, descripción, dirección)
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _fetchFirstPage();
  }

  /// Selecciona o deselecciona un servicio como filtro
  void toggleServiceFilter(String serviceId) {
    if (_selectedServiceId == serviceId) {
      _selectedServiceId = null;
    } else {
      _selectedServiceId = serviceId;
    }
    _fetchFirstPage();
  }

  /// Restablece todos los filtros activos
  void clearFilters() {
    _searchQuery = '';
    _selectedServiceId = null;
    _fetchFirstPage();
  }

  /// Reintenta la consulta en caso de error previo
  Future<void> retry() async {
    await _fetchFirstPage();
  }

  /// Cierra la sesión activa si la hubiera
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }

  /// Valida si el usuario tiene sesión para acciones protegidas (como reservar).
  /// HU01-RF03 Criterio 3: Las acciones que sí requieren cuenta (como reservar)
  /// redirigen a login o registro.
  bool requireAuthForAction(
    BuildContext context, {
    String actionName = 'reservar',
    String? restaurantName,
  }) {
    if (isUserAuthenticated) {
      return true;
    }

    // Si no tiene sesión, redirige al modal de inicio de sesión / registro
    final target = restaurantName != null ? ' en $restaurantName' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Para $actionName$target necesitas iniciar sesión o crear una cuenta.'),
        action: SnackBarAction(
          label: 'Iniciar sesión',
          onPressed: () {
            AuthModalDialog.show(context, initialMode: AuthMode.login);
          },
        ),
      ),
    );

    AuthModalDialog.show(context, initialMode: AuthMode.login);
    return false;
  }
}
