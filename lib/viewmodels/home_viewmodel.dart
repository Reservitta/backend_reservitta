import 'package:flutter/material.dart';
import '../models/restaurant_model.dart';
import '../services/auth_service.dart';
import '../services/restaurant_service.dart';

class HomeViewModel extends ChangeNotifier {
  final AuthService _authService;
  final RestaurantService _restaurantService;

  HomeViewModel({
    AuthService? authService,
    RestaurantService? restaurantService,
  })  : _authService = authService ?? AuthService(),
        _restaurantService = restaurantService ?? RestaurantService();

  Stream<List<RestaurantModel>> get restaurantsStream =>
      _restaurantService.getRestaurantsStream();

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
