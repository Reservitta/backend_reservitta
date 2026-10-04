import 'package:flutter/material.dart';
import '../models/restaurant_model.dart';
import '../services/auth_service.dart';
import '../services/database_init_service.dart';
import '../services/restaurant_service.dart';

class HomeViewModel extends ChangeNotifier {
  final AuthService _authService;
  final RestaurantService _restaurantService;
  final DatabaseInitService _databaseInitService;

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  HomeViewModel({
    AuthService? authService,
    RestaurantService? restaurantService,
    DatabaseInitService? databaseInitService,
  })  : _authService = authService ?? AuthService(),
        _restaurantService = restaurantService ?? RestaurantService(),
        _databaseInitService = databaseInitService ?? DatabaseInitService();

  Stream<List<RestaurantModel>> get restaurantsStream =>
      _restaurantService.getRestaurantsStream();

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
