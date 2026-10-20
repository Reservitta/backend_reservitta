import 'categoria_model.dart';
import 'platillo_model.dart';
import 'restaurant_model.dart';

/// Agrupación de platillos pertenecientes a una categoría específica (HU05-RF01 y HU06-RF01)
class MenuCategoryModel {
  final CategoriaModel categoria;
  final List<PlatilloModel> platillos;

  const MenuCategoryModel({
    required this.categoria,
    required this.platillos,
  });

  String get categoriaId => categoria.id;
  String get nombre => categoria.nombre;
  int get orden => categoria.orden;
  String get tipo => categoria.tipo;

  bool get isEmpty => platillos.isEmpty;
  bool get isNotEmpty => platillos.isNotEmpty;
  int get totalPlatillos => platillos.length;

  MenuCategoryModel copyWith({
    CategoriaModel? categoria,
    List<PlatilloModel>? platillos,
  }) {
    return MenuCategoryModel(
      categoria: categoria ?? this.categoria,
      platillos: platillos ?? this.platillos,
    );
  }
}

/// Información completa y detallada de un restaurante con su menú organizado (HU05-RF01)
class RestaurantDetailModel {
  final RestaurantModel restaurant;
  final List<MenuCategoryModel> menu;

  const RestaurantDetailModel({
    required this.restaurant,
    required this.menu,
  });

  // Getters directos de conveniencia para la UI (HU05-RF01 Criterio 1)
  String get id => restaurant.id;
  String get nombre => restaurant.nombre;
  String get telefono => restaurant.telefono;
  String get correo => restaurant.correo;
  bool get tieneCorreo => correo.trim().isNotEmpty;
  String get direccion => restaurant.direccion;
  String get logo => restaurant.logoUrl;
  String get imagenPrincipal => restaurant.imagenPrincipalUrl;
  Map<String, DaySchedule> get horarios => restaurant.horarios;
  bool get isActivo => restaurant.isActivo;
  String get descripcion => restaurant.descripcion;
  List<String> get diasAbiertos => restaurant.diasAbiertos;

  /// Total de platillos en todo el menú
  int get totalPlatillos =>
      menu.fold(0, (acum, cat) => acum + cat.platillos.length);
}

/// Patrón de resultado seguro para la consulta de detalle sin lanzar excepciones fatales (HU05-RF01 Criterio 3)
class RestaurantDetailResult {
  final RestaurantDetailModel? detail;
  final String? errorMessage;
  final bool hasError;

  const RestaurantDetailResult.success(RestaurantDetailModel this.detail)
      : errorMessage = null,
        hasError = false;

  const RestaurantDetailResult.failure(String this.errorMessage)
      : detail = null,
        hasError = true;

  bool get isSuccess => !hasError && detail != null;
}

/// Patrón de resultado seguro para la consulta de menú por categorías (HU06-RF01 Criterio 5)
class MenuQueryResult {
  final List<MenuCategoryModel> menu;
  final String? errorMessage;
  final bool hasError;

  const MenuQueryResult.success(this.menu)
      : errorMessage = null,
        hasError = false;

  const MenuQueryResult.failure(String this.errorMessage)
      : menu = const [],
        hasError = true;

  bool get isSuccess => !hasError;
  bool get isEmpty => menu.isEmpty;
  bool get isNotEmpty => menu.isNotEmpty;
  int get totalPlatillos =>
      menu.fold(0, (acum, cat) => acum + cat.platillos.length);
}
