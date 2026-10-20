import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/restaurant_repository.dart';
import 'package:reservitta/viewmodels/restaurant_detail_viewmodel.dart';

/// Implementación simulada del repositorio para pruebas unitarias de HU05-RF01
class FakeRestaurantDetailRepository extends Fake implements RestaurantRepository {
  final Map<String, RestaurantModel> restaurants;
  final Map<String, List<CategoriaModel>> categorias;
  final Map<String, List<PlatilloModel>> platillos;

  FakeRestaurantDetailRepository({
    required this.restaurants,
    required this.categorias,
    required this.platillos,
  });

  @override
  Future<RestaurantDetailModel> getRestaurantDetail(
    String restaurantId, {
    bool soloPlatillosVisibles = true,
  }) async {
    final restaurant = restaurants[restaurantId];
    if (restaurant == null) {
      throw const ControlledRestaurantQueryException(
        'El restaurante solicitado no existe.',
      );
    }

    if (!restaurant.isActivo) {
      throw ControlledRestaurantQueryException(
        'El restaurante "${restaurant.nombre}" se encuentra inactivo actualmente.',
      );
    }

    final cats = List<CategoriaModel>.from(categorias[restaurantId] ?? [])
      ..sort((a, b) => a.orden.compareTo(b.orden));

    var plats = List<PlatilloModel>.from(platillos[restaurantId] ?? [])
      ..sort((a, b) => a.orden.compareTo(b.orden));

    if (soloPlatillosVisibles) {
      plats = plats.where((p) => !p.isInactivo).toList();
    }

    final List<MenuCategoryModel> menu = [];
    for (final cat in cats) {
      final platillosDeCat = plats.where((p) => p.categoriaId == cat.id).toList();
      menu.add(MenuCategoryModel(categoria: cat, platillos: platillosDeCat));
    }

    return RestaurantDetailModel(restaurant: restaurant, menu: menu);
  }

  @override
  Future<RestaurantDetailResult> getRestaurantDetailResult(
    String restaurantId, {
    bool soloPlatillosVisibles = true,
  }) async {
    try {
      final detail = await getRestaurantDetail(
        restaurantId,
        soloPlatillosVisibles: soloPlatillosVisibles,
      );
      return RestaurantDetailResult.success(detail);
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantDetailResult.failure(e.message);
    } catch (e) {
      return RestaurantDetailResult.failure('Error inesperado: $e');
    }
  }

  @override
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit}) async => [];

  @override
  Future<RestaurantQueryResult> getActiveRestaurantsResult({int? limit}) async =>
      const RestaurantQueryResult.success([]);

  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsStream() => const Stream.empty();

  @override
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async =>
      restaurants[restaurantId];

  @override
  Future<List<RestaurantModel>> getActiveRestaurantsByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async =>
      [];

  @override
  Future<RestaurantQueryResult> getActiveRestaurantsByRadiusResult({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async =>
      const RestaurantQueryResult.success([]);

  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsByRadiusStream({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) =>
      const Stream.empty();

  @override
  Future<List<RestaurantWithDistance>> getRestaurantsWithDistanceByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async =>
      [];

  @override
  Future<List<MenuCategoryModel>> getMenuByCategories(
    String restaurantId, {
    bool soloDisponibles = true,
    bool ocultarCategoriasVacias = false,
  }) async {
    final rest = restaurants[restaurantId];
    if (rest == null || !rest.isActivo) return [];

    final cats = categorias[restaurantId] ?? [];
    final plats = platillos[restaurantId] ?? [];
    if (cats.isEmpty && plats.isEmpty) return [];

    return RestaurantService.agruparMenu(
      categorias: cats,
      platillos: plats,
      soloDisponibles: soloDisponibles,
      ocultarCategoriasVacias: ocultarCategoriasVacias,
    );
  }

  @override
  Future<MenuQueryResult> getMenuByCategoriesResult(
    String restaurantId, {
    bool soloDisponibles = true,
    bool ocultarCategoriasVacias = false,
  }) async {
    final menu = await getMenuByCategories(
      restaurantId,
      soloDisponibles: soloDisponibles,
      ocultarCategoriasVacias: ocultarCategoriasVacias,
    );
    return MenuQueryResult.success(menu);
  }

  @override
  Stream<List<MenuCategoryModel>> getMenuByCategoriesStream(
    String restaurantId, {
    bool soloDisponibles = true,
    bool ocultarCategoriasVacias = false,
  }) async* {
    yield await getMenuByCategories(
      restaurantId,
      soloDisponibles: soloDisponibles,
      ocultarCategoriasVacias: ocultarCategoriasVacias,
    );
  }
}

void main() {
  group('HU05-RF01: Consulta del detalle de un restaurante', () {
    late FakeRestaurantDetailRepository repository;

    final restaurantActivo = RestaurantModel(
      id: 'rest_activo_1',
      nombre: 'La Parrilla Urbana',
      telefono: '5512345678',
      correo: 'contacto@laparrilla.com',
      direccion: 'Av. Insurgentes Sur 1234, CDMX',
      descripcion: 'Cortes finos y cocina de humo',
      logoUrl: 'https://storage.googleapis.com/.../logo.png',
      imagenPrincipalUrl: 'https://storage.googleapis.com/.../cover.jpg',
      estado: 'activo',
      horarios: const {
        'lunes': DaySchedule(abierto: true, apertura: '13:00', cierre: '23:00'),
        'martes': DaySchedule(abierto: true, apertura: '13:00', cierre: '23:00'),
      },
    );

    final restaurantInactivo = RestaurantModel(
      id: 'rest_inactivo_2',
      nombre: 'Café Cerrado',
      telefono: '5598765432',
      correo: 'info@cafecerrado.com',
      direccion: 'Calle Luna 45',
      estado: 'inactivo',
    );

    final categoriaEntradas = const CategoriaModel(
      id: 'cat_entradas',
      nombre: 'Entradas',
      nombreNormalizado: 'entradas',
      orden: 1,
    );

    final categoriaFuertes = const CategoriaModel(
      id: 'cat_fuertes',
      nombre: 'Platos Fuertes',
      nombreNormalizado: 'platos fuertes',
      orden: 2,
    );

    final platillo1 = PlatilloModel(
      id: 'plat_1',
      categoriaId: 'cat_entradas',
      nombre: 'Carpaccio de Res',
      descripcion: 'Láminas de res con alcaparras y parmesano',
      precio: 160.0,
      imagenUrl: 'https://storage.googleapis.com/.../carpaccio.jpg',
      estado: 'activo',
      orden: 1,
    );

    final platillo2 = PlatilloModel(
      id: 'plat_2',
      categoriaId: 'cat_fuertes',
      nombre: 'Bife de Chorizo 400g',
      descripcion: 'Corte a las brasas con papas',
      precio: 380.0,
      imagenUrl: 'https://storage.googleapis.com/.../bife.jpg',
      estado: 'activo',
      orden: 1,
    );

    final platilloInactivo = PlatilloModel(
      id: 'plat_inactivo',
      categoriaId: 'cat_entradas',
      nombre: 'Platillo Descontinuado',
      descripcion: 'Ya no disponible',
      precio: 100.0,
      estado: 'inactivo',
      orden: 2,
    );

    setUp(() {
      repository = FakeRestaurantDetailRepository(
        restaurants: {
          'rest_activo_1': restaurantActivo,
          'rest_inactivo_2': restaurantInactivo,
        },
        categorias: {
          'rest_activo_1': [categoriaFuertes, categoriaEntradas], // Desordenadas a propósito
        },
        platillos: {
          'rest_activo_1': [platillo1, platillo2, platilloInactivo],
        },
      );
    });

    test('Criterio 1: Dado el ID del restaurante, obtiene su información completa', () async {
      final detail = await repository.getRestaurantDetail('rest_activo_1');

      expect(detail.id, 'rest_activo_1');
      expect(detail.nombre, 'La Parrilla Urbana');
      expect(detail.telefono, '5512345678');
      expect(detail.correo, 'contacto@laparrilla.com');
      expect(detail.tieneCorreo, isTrue);
      expect(detail.direccion, 'Av. Insurgentes Sur 1234, CDMX');
      expect(detail.logo, 'https://storage.googleapis.com/.../logo.png');
      expect(detail.imagenPrincipal, 'https://storage.googleapis.com/.../cover.jpg');
      expect(detail.horarios.containsKey('lunes'), isTrue);
      expect(detail.horarios['lunes']?.abierto, isTrue);
      expect(detail.horarios['lunes']?.apertura, '13:00');
      expect(detail.horarios['lunes']?.cierre, '23:00');
    });

    test('Criterio 2: Obtiene su menú organizado por categorías con datos de platillos', () async {
      final detail = await repository.getRestaurantDetail('rest_activo_1');

      // Las categorías deben venir ordenadas por 'orden' (1: Entradas, 2: Platos Fuertes)
      expect(detail.menu.length, 2);
      expect(detail.menu[0].nombre, 'Entradas');
      expect(detail.menu[0].orden, 1);
      expect(detail.menu[1].nombre, 'Platos Fuertes');
      expect(detail.menu[1].orden, 2);

      // Los platillos pertenecen a su categoría correspondiente
      expect(detail.menu[0].platillos.length, 1); // El inactivo fue excluido para visitantes (HU06)
      final p1 = detail.menu[0].platillos.first;
      expect(p1.nombre, 'Carpaccio de Res');
      expect(p1.descripcion, 'Láminas de res con alcaparras y parmesano');
      expect(p1.precio, 160.0);
      expect(p1.imagenUrl, 'https://storage.googleapis.com/.../carpaccio.jpg');

      expect(detail.menu[1].platillos.length, 1);
      final p2 = detail.menu[1].platillos.first;
      expect(p2.nombre, 'Bife de Chorizo 400g');
      expect(p2.precio, 380.0);
    });

    test('Criterio 3: Si el restaurante no existe, devuelve error controlado', () async {
      // 1. Vía excepción controlada
      expect(
        () => repository.getRestaurantDetail('id_inexistente_999'),
        throwsA(isA<ControlledRestaurantQueryException>()),
      );

      // 2. Vía Result seguro (no revienta la app)
      final result = await repository.getRestaurantDetailResult('id_inexistente_999');
      expect(result.hasError, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('no existe'));
    });

    test('Criterio 3: Si el restaurante está inactivo, devuelve error controlado', () async {
      // 1. Vía excepción controlada
      expect(
        () => repository.getRestaurantDetail('rest_inactivo_2'),
        throwsA(isA<ControlledRestaurantQueryException>()),
      );

      // 2. Vía Result seguro
      final result = await repository.getRestaurantDetailResult('rest_inactivo_2');
      expect(result.hasError, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('inactivo'));
    });

    test('ViewModel: RestaurantDetailViewModel carga datos y maneja errores controlados bajo MVVM', () async {
      // Caso 1: Carga exitosa
      final vmExitoso = RestaurantDetailViewModel(
        restaurantId: 'rest_activo_1',
        restaurantRepository: repository,
      );

      expect(vmExitoso.isLoading, isTrue);
      await vmExitoso.cargarDetalle();
      expect(vmExitoso.isLoading, isFalse);
      expect(vmExitoso.hasData, isTrue);
      expect(vmExitoso.hasError, isFalse);
      expect(vmExitoso.restaurant?.nombre, 'La Parrilla Urbana');
      expect(vmExitoso.menu.length, 2);

      // Caso 2: Error controlado por restaurante inexistente
      final vmInexistente = RestaurantDetailViewModel(
        restaurantId: 'id_fantasma',
        restaurantRepository: repository,
      );
      await vmInexistente.cargarDetalle();
      expect(vmInexistente.isLoading, isFalse);
      expect(vmInexistente.hasData, isFalse);
      expect(vmInexistente.hasError, isTrue);
      expect(vmInexistente.errorMessage, contains('no existe'));

      // Caso 3: Error controlado por restaurante inactivo
      final vmInactivo = RestaurantDetailViewModel(
        restaurantId: 'rest_inactivo_2',
        restaurantRepository: repository,
      );
      await vmInactivo.cargarDetalle();
      expect(vmInactivo.isLoading, isFalse);
      expect(vmInactivo.hasData, isFalse);
      expect(vmInactivo.hasError, isTrue);
      expect(vmInactivo.errorMessage, contains('inactivo'));
    });
  });
}

