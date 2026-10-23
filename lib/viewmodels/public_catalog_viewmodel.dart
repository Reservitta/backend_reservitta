import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../models/service_catalog_model.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/restaurant_service.dart';
import '../utils/geo_utils.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import '../views/auth_modal_dialog.dart';

/// ViewModel para la navegación pública sin sesión, catálogo de restaurantes y filtros (HU01-RF03, HU02-RF03)
class PublicCatalogViewModel extends ChangeNotifier {
  final RestaurantService _restaurantService;
  final AuthService _authService;
  final LocationService _locationService;

  PublicCatalogViewModel({
    RestaurantService? restaurantService,
    AuthService? authService,
    LocationService? locationService,
  })  : _restaurantService = restaurantService ?? RestaurantService(),
        _authService = authService ?? AuthService(),
        _locationService = locationService ?? LocationService();

  // Estados de datos
  List<RestaurantModel> _rawRestaurants = [];
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

  // Filtro de ubicación (HU02-RF01, HU02-RF02, HU02-RF03)
  UserLocation? _selectedLocation;
  double? _selectedRadiusKm;

  // Filtro de fecha y hora (HU03-RF02)
  DateTime? _selectedDateTime;

  // Getters
  List<RestaurantModel> get restaurants => _restaurants;
  List<ServiceCatalogModel> get availableServices => _availableServices;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedServiceId => _selectedServiceId;
  UserLocation? get selectedLocation => _selectedLocation;
  double? get selectedRadiusKm => _selectedRadiusKm;
  DateTime? get selectedDateTime => _selectedDateTime;
  LocationService get locationService => _locationService;

  /// Indica si el filtro de ubicación por radio está actualmente activo
  bool get isLocationFilterActive => _selectedLocation != null && _selectedRadiusKm != null;

  /// Indica si el filtro de fecha y hora está actualmente activo (HU03-RF02 Criterio 3)
  bool get isDateTimeFilterActive => _selectedDateTime != null;

  /// Indica si hay algún filtro activo (texto, servicio, ubicación o fecha/hora)
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedServiceId != null ||
      isLocationFilterActive ||
      isDateTimeFilterActive;

  static const List<String> _meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];
  static const List<String> _diasSemana = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom',
  ];

  /// Horario formateado visible en pantalla principal (HU03-RF02 Criterio 3)
  String? get selectedDateTimeFormatted {
    if (_selectedDateTime == null) return null;
    final dt = _selectedDateTime!;
    final now = DateTime.now();

    final hora = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hora:$min';

    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day;

    if (isToday) {
      return 'Hoy, $timeStr';
    } else if (isTomorrow) {
      return 'Mañana, $timeStr';
    } else {
      final diaSemana = _diasSemana[dt.weekday - 1];
      final mes = _meses[dt.month - 1];
      return '$diaSemana ${dt.day} $mes, $timeStr';
    }
  }

  /// Indica si el usuario actual cuenta con una sesión iniciada
  bool get isUserAuthenticated => _authService.currentUser != null;

  /// Nombre del usuario autenticado si existe sesión
  String? get currentUserName =>
      _authService.currentUser?.displayName ?? _authService.currentUser?.email;

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
      final result = await _restaurantService.getPaginatedActiveRestaurants(
        limit: 15,
        startAfterDocument: null,
        searchQuery: _searchQuery,
        servicioId: _selectedServiceId,
      );

      _rawRestaurants = result.restaurants;
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
      _applyFiltersAndSorting();
    } catch (e) {
      // HU01-RF01 Criterio 5: Error controlado sin cerrar la app
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _rawRestaurants = [];
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
      final result = await _restaurantService.getPaginatedActiveRestaurants(
        limit: 15,
        startAfterDocument: _lastDocument,
        searchQuery: _searchQuery,
        servicioId: _selectedServiceId,
      );

      _rawRestaurants.addAll(result.restaurants);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
      _applyFiltersAndSorting();
    } catch (e) {
      // Si falla la página siguiente, mantenemos lo ya cargado sin romper la app
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Aplica los filtros locales (ubicación y ordenamiento por cercanía)
  void _applyFiltersAndSorting() {
    List<RestaurantModel> list = List.from(_rawRestaurants);

    // 1. Filtrar por servicio
    if (_selectedServiceId != null && _selectedServiceId!.isNotEmpty) {
      list = list.where((r) => r.serviciosIds.contains(_selectedServiceId)).toList();
    }

    // 2. Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) =>
          r.nombre.toLowerCase().contains(q) ||
          r.direccion.toLowerCase().contains(q) ||
          r.descripcion.toLowerCase().contains(q)).toList();
    }

    // 3. Filtrar por fecha y hora según horarios de apertura (HU03-RF02 Criterio 3)
    if (isDateTimeFilterActive) {
      list = list.where((r) => r.isOpenAt(_selectedDateTime!)).toList();
    }

    // 4. Filtrar por ubicación y radio utilizando la lógica del backend (HU02-RF02)
    if (isLocationFilterActive) {
      list = GeoUtils.filterAndSortByDistance(
        restaurants: list,
        userLatitude: _selectedLocation!.latitude,
        userLongitude: _selectedLocation!.longitude,
        radiusKm: _selectedRadiusKm!,
      );
    }

    _restaurants = list;
  }

  /// Calcula la distancia en metros hacia un restaurante según la ubicación seleccionada
  /// HU02-RF02 Criterio 1
  double? getDistanceInMeters(RestaurantModel restaurant) {
    if (!isLocationFilterActive || !restaurant.hasValidCoordinates) return null;
    if (restaurant.distanciaKm != null) {
      return restaurant.distanciaKm! * 1000.0;
    }
    return GeoUtils.calculateDistanceMeters(
      startLatitude: _selectedLocation!.latitude,
      startLongitude: _selectedLocation!.longitude,
      endLatitude: restaurant.coordenadas!.latitude,
      endLongitude: restaurant.coordenadas!.longitude,
    );
  }

  /// Obtiene la distancia formateada legible (ej. "450 m", "1.2 km")
  /// HU02-RF03 Criterio 2
  String? getFormattedDistance(RestaurantModel restaurant) {
    if (!isLocationFilterActive) return null;
    if (restaurant.distanciaFormateada.isNotEmpty) {
      return restaurant.distanciaFormateada;
    }
    final dist = getDistanceInMeters(restaurant);
    if (dist == null) return null;
    return LocationService.formatDistance(dist);
  }

  /// Activa o actualiza el filtro de ubicación con una zona/coordenada y radio en km
  /// HU02-RF01 Criterios 2 y 3, HU02-RF02 Criterio 2
  void setLocationFilter({
    required UserLocation location,
    double radiusKm = 5.0,
  }) {
    _selectedLocation = location;
    _selectedRadiusKm = radiusKm;
    _applyFiltersAndSorting();
    notifyListeners();
  }

  /// Actualiza únicamente el radio del filtro de ubicación
  void updateRadius(double newRadiusKm) {
    if (!isLocationFilterActive) return;
    _selectedRadiusKm = newRadiusKm;
    _applyFiltersAndSorting();
    notifyListeners();
  }

  /// Amplía el radio al siguiente nivel disponible si no hay resultados (HU02-RF03 Criterio 4)
  void expandRadius() {
    if (!isLocationFilterActive) return;
    final current = _selectedRadiusKm ?? 5.0;
    final next = LocationService.availableRadiiKm.firstWhere(
      (r) => r > current,
      orElse: () => current,
    );
    if (next > current) {
      _selectedRadiusKm = next;
      _applyFiltersAndSorting();
      notifyListeners();
    }
  }

  /// Quita el filtro de ubicación y restablece el listado completo (HU02-RF03 Criterio 3)
  void clearLocationFilter() {
    _selectedLocation = null;
    _selectedRadiusKm = null;
    _applyFiltersAndSorting();
    notifyListeners();
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
    _applyFiltersAndSorting();
    notifyListeners();
  }

  /// Valida si una fecha y hora es futura (no pasada)
  /// HU03-RF02 Criterio 2
  static bool isValidFutureDateTime(DateTime dateTime, [DateTime? referenceNow]) {
    final now = referenceNow ?? DateTime.now();
    // Tolerancia de 1 minuto para evitar falsos rechazos en el mismo minuto
    final threshold = now.subtract(const Duration(minutes: 1));
    return dateTime.isAfter(threshold);
  }

  /// Establece el filtro de fecha y hora (HU03-RF02 Criterios 1, 2)
  /// Retorna false si la fecha y hora es pasada.
  bool setDateTimeFilter(DateTime dateTime, [DateTime? referenceNow]) {
    if (!isValidFutureDateTime(dateTime, referenceNow)) {
      return false;
    }
    _selectedDateTime = dateTime;
    _applyFiltersAndSorting();
    notifyListeners();
    return true;
  }

  /// Quita el filtro de fecha y hora y restablece los resultados (HU03-RF02 Criterio 4)
  void clearDateTimeFilter() {
    _selectedDateTime = null;
    _applyFiltersAndSorting();
    notifyListeners();
  }

  /// Restablece todos los filtros activos (incluyendo texto, servicios, ubicación y fecha/hora)
  void clearFilters() {
    _searchQuery = '';
    _selectedServiceId = null;
    _selectedLocation = null;
    _selectedRadiusKm = null;
    _selectedDateTime = null;
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Para $actionName$target necesitas iniciar sesión o crear una cuenta.'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Iniciar sesión',
          onPressed: () {
            messenger.hideCurrentSnackBar();
            AuthModalDialog.show(context, initialMode: AuthMode.login);
          },
        ),
      ),
    );

    AuthModalDialog.show(context, initialMode: AuthMode.login);
    return false;
  }
}
