import 'dart:async';
import 'package:flutter/material.dart';
import '../models/categoria_model.dart';
import '../repositories/restaurant_repository.dart';

/// ViewModel / Controlador para la vista del Menú por Categorías (HU06-RF01)
class RestaurantMenuViewModel extends ChangeNotifier {
  final String restaurantId;
  final RestaurantRepository _repository;

  bool _isLoading = true;
  String? _errorMessage;
  List<MenuCategoryModel> _menu = [];
  String? _categoriaSeleccionadaId;
  StreamSubscription<List<MenuCategoryModel>>? _streamSubscription;

  RestaurantMenuViewModel({
    required this.restaurantId,
    RestaurantRepository? repository,
  }) : _repository = repository ?? RestaurantService();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MenuCategoryModel> get menu => _menu;
  String? get categoriaSeleccionadaId => _categoriaSeleccionadaId;

  bool get hasError => _errorMessage != null;
  bool get hasData => _menu.isNotEmpty;
  bool get estaVacio => _menu.isEmpty;
  int get totalPlatillos =>
      _menu.fold(0, (acc, cat) => acc + cat.platillos.length);

  List<CategoriaModel> get categorias => _menu.map((m) => m.categoria).toList();

  MenuCategoryModel? get categoriaSeleccionada {
    if (_categoriaSeleccionadaId == null) return null;
    try {
      return _menu.firstWhere((m) => m.categoriaId == _categoriaSeleccionadaId);
    } catch (_) {
      return null;
    }
  }

  void seleccionarCategoria(String? categoriaId) {
    _categoriaSeleccionadaId = categoriaId;
    notifyListeners();
  }

  /// Carga el menú organizado por categorías temáticas (HU06-RF01)
  /// Si el restaurante no tiene menú, se asigna lista vacía sin error (Criterio 5).
  Future<void> cargarMenu({
    bool soloDisponibles = true,
    bool ocultarCategoriasVacias = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getMenuByCategoriesResult(
        restaurantId,
        soloDisponibles: soloDisponibles,
        ocultarCategoriasVacias: ocultarCategoriasVacias,
      );

      if (result.hasError) {
        _errorMessage = result.errorMessage;
        _menu = [];
      } else {
        _menu = result.menu;
        _errorMessage = null;
        if (_categoriaSeleccionadaId == null && _menu.isNotEmpty) {
          _categoriaSeleccionadaId = _menu.first.categoriaId;
        }
      }
    } catch (e) {
      _errorMessage = 'Error inesperado al cargar el menú del restaurante.';
      _menu = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Inicia la sincronización en tiempo real del menú para comensales (HU32-RF01)
  void iniciarEscuchaEnTiempoReal({
    bool soloDisponibles = true,
    bool ocultarCategoriasVacias = false,
  }) {
    _streamSubscription?.cancel();
    _streamSubscription = _repository
        .getMenuByCategoriesStream(
          restaurantId,
          soloDisponibles: soloDisponibles,
          ocultarCategoriasVacias: ocultarCategoriasVacias,
        )
        .listen(
      (menuActualizado) {
        _menu = menuActualizado;
        _isLoading = false;
        _errorMessage = null;
        if (_categoriaSeleccionadaId == null && _menu.isNotEmpty) {
          _categoriaSeleccionadaId = _menu.first.categoriaId;
        }
        notifyListeners();
      },
      onError: (Object err) {
        _errorMessage = 'Error al sincronizar el menú en tiempo real.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

