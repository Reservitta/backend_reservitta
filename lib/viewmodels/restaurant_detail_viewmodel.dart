import 'package:flutter/material.dart';
import '../models/restaurant_model.dart';
import '../repositories/restaurant_repository.dart';

/// ViewModel / Controlador para la vista de Detalle de Restaurante (HU05-RF01)
class RestaurantDetailViewModel extends ChangeNotifier {
  final String restaurantId;
  final RestaurantRepository _restaurantRepository;

  bool _isLoading = true;
  String? _errorMessage;
  RestaurantDetailModel? _detail;

  RestaurantDetailViewModel({
    required this.restaurantId,
    RestaurantRepository? restaurantRepository,
  }) : _restaurantRepository = restaurantRepository ?? RestaurantService();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  RestaurantDetailModel? get detail => _detail;

  bool get hasError => _errorMessage != null;
  bool get hasData => _detail != null;

  RestaurantModel? get restaurant => _detail?.restaurant;
  List<MenuCategoryModel> get menu => _detail?.menu ?? const [];

  /// Carga la información completa del restaurante y su menú organizado (HU05-RF01)
  Future<void> cargarDetalle({bool soloPlatillosVisibles = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _restaurantRepository.getRestaurantDetailResult(
        restaurantId,
        soloPlatillosVisibles: soloPlatillosVisibles,
      );

      if (result.hasError) {
        _errorMessage = result.errorMessage;
        _detail = null;
      } else {
        _detail = result.detail;
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = 'Error inesperado al cargar el detalle del restaurante.';
      _detail = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
