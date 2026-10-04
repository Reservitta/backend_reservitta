import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_init_service.dart';
import '../services/restaurant_service.dart';

class HomeViewModel extends ChangeNotifier {
  final AuthService _authService;
  final RestaurantService _restaurantService;
  final DatabaseInitService _databaseInitService;

  bool _isInitializing = false;
  bool _isLoadingProfile = true;
  String? _loadError;
  UserModel? _currentUserProfile;
  RestaurantModel? _currentRestaurant;

  bool get isInitializing => _isInitializing;
  bool get isLoadingProfile => _isLoadingProfile;
  String? get loadError => _loadError;
  UserModel? get currentUserProfile => _currentUserProfile;
  RestaurantModel? get currentRestaurant => _currentRestaurant;

  /// Retorna si el perfil del restaurante está completo (Dashboard HU25 vs Configuración HU23)
  bool get isRestaurantProfileComplete =>
      _currentRestaurant?.perfilCompleto ?? false;

  HomeViewModel({
    AuthService? authService,
    RestaurantService? restaurantService,
    DatabaseInitService? databaseInitService,
  }) : _authService = authService ?? AuthService(),
       _restaurantService = restaurantService ?? RestaurantService(),
       _databaseInitService = databaseInitService ?? DatabaseInitService();

  Stream<List<RestaurantModel>> get restaurantsStream =>
      _restaurantService.getRestaurantsStream();

  Future<void> loadAdminSessionData() async {
    _isLoadingProfile = true;
    _loadError = null;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw StateError('No hay una sesión activa de administrador.');
      }

      _currentUserProfile = await _authService.getUserProfile(user.uid);
      if (_currentUserProfile == null) {
        throw StateError('No se encontró el perfil de Reservitta.');
      }

      if (_currentUserProfile!.rol != 'admin') {
        throw StateError('La cuenta no tiene rol de administrador.');
      }

      final restaurantRef = _currentUserProfile!.restauranteId;
      if (restaurantRef == null) {
        throw StateError('El perfil no tiene un restaurante asociado.');
      }

      _currentRestaurant = await _authService.getRestaurantByRef(restaurantRef);
      if (_currentRestaurant == null) {
        throw StateError('No se encontró el restaurante asociado.');
      }
    } catch (error) {
      _loadError = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> initDatabase() async {
    _isInitializing = true;
    notifyListeners();
    try {
      await _databaseInitService.initFullDatabaseSchema();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
