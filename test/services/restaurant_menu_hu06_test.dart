import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/restaurant_repository.dart';
import 'package:reservitta/viewmodels/restaurant_menu_viewmodel.dart';

/// Implementación Fake de RestaurantRepository para pruebas unitarias de HU06-RF01
class FakeRestaurantMenuRepository implements RestaurantRepository {
  final Map<String, RestaurantModel> restaurants;
  final Map<String, List<CategoriaModel>> categorias;
  final Map<String, List<PlatilloModel>> platillos;
  final bool simulateNetworkError;

  FakeRestaurantMenuRepository({
    required this.restaurants,
    required this.categorias,
    required this.platillos,
    this.simulateNetworkError = false,
  });

  @override
  Future<List<MenuCategoryModel>> getMenuByCategories(
    String restaurantId, {
    bool soloDisponibles = true,
    bool ocultarCategoriasVacias = false,
  }) async {
    if (simulateNetworkError) {
      throw const ControlledRestaurantQueryException(
        'Falla simulada de red al consultar el menú.',
      );
    }

    if (restaurantId.trim().isEmpty) return [];

    final rest = restaurants[restaurantId];
    if (rest == null || !rest.isActivo) {
      // Criterio 5: Un restaurante sin menú (o inexistente/inactivo) devuelve una lista vacía, no un error
      return [];
    }

    final cats = categorias[restaurantId] ?? [];
    final plats = platillos[restaurantId] ?? [];

    if (cats.isEmpty && plats.isEmpty) {
      // Criterio 5: Restaurante sin menú configurado devuelve lista vacía, no un error
      return [];
    }

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
    try {
      final list = await getMenuByCategories(
        restaurantId,
        soloDisponibles: soloDisponibles,
        ocultarCategoriasVacias: ocultarCategoriasVacias,
      );
      return MenuQueryResult.success(list);
    } on ControlledRestaurantQueryException catch (e) {
      return MenuQueryResult.failure(e.message);
    } catch (e) {
      return MenuQueryResult.failure('Error inesperado: $e');
    }
  }

  @override
  Stream<List<MenuCategoryModel>> getMenuByCategoriesStream(
    String restaurantId, {
    bool soloDisponibles = true,
    bool ocultarCategoriasVacias = false,
  }) async* {
    if (simulateNetworkError) {
      yield <MenuCategoryModel>[];
      return;
    }
    yield await getMenuByCategories(
      restaurantId,
      soloDisponibles: soloDisponibles,
      ocultarCategoriasVacias: ocultarCategoriasVacias,
    );
  }

  // Métodos secundarios de RestaurantRepository
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
  Future<RestaurantDetailModel> getRestaurantDetail(
    String restaurantId, {
    bool soloPlatillosVisibles = true,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<RestaurantDetailResult> getRestaurantDetailResult(
    String restaurantId, {
    bool soloPlatillosVisibles = true,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  group('HU06-RF01: Consulta del menú por categorías', () {
    late FakeRestaurantMenuRepository repository;

    final restActivoConMenu = const RestaurantModel(
      id: 'rest_menu_ok',
      nombre: 'La Taquería Gourmet',
      estado: 'activo',
    );

    final restActivoSinMenu = const RestaurantModel(
      id: 'rest_sin_menu',
      nombre: 'Restaurante Nuevo Sin Menú',
      estado: 'activo',
    );

    final restInactivo = const RestaurantModel(
      id: 'rest_cerrado',
      nombre: 'Restaurante Inactivo',
      estado: 'inactivo',
    );

    // Categorías con orden intencionalmente desordenado
    final catBebidas = const CategoriaModel(
      id: 'cat_bebidas',
      nombre: 'Bebidas y Coctelería',
      nombreNormalizado: 'bebidas y cocteleria',
      orden: 2,
    );

    final catTacos = const CategoriaModel(
      id: 'cat_tacos',
      nombre: 'Tacos Especiales',
      nombreNormalizado: 'tacos especiales',
      orden: 1,
    );

    final catPostres = const CategoriaModel(
      id: 'cat_postres',
      nombre: 'Postres Artesanales',
      nombreNormalizado: 'postres artesanales',
      orden: 3,
    );

    // Platillos con orden desordenado y diferentes estados
    final tacoPastor = PlatilloModel(
      id: 'plat_pastor',
      categoriaId: 'cat_tacos',
      nombre: 'Taco al Pastor Especial',
      descripcion: 'Carne adobada, piña asada, cebolla y cilantro',
      precio: 35.0,
      imagenUrl: 'https://images.reservitta.com/pastor.jpg',
      estado: 'activo',
      orden: 2,
    );

    final tacoRibEye = PlatilloModel(
      id: 'plat_ribeye',
      categoriaId: 'cat_tacos',
      nombre: 'Taco de Rib Eye',
      descripcion: 'Corte fino de res con costra de queso manchego',
      precio: 85.0,
      imagenUrl: 'https://images.reservitta.com/ribeye.jpg',
      estado: 'activo',
      orden: 1, // Debe salir antes que el taco al pastor
    );

    final tacoAgotado = PlatilloModel(
      id: 'plat_costilla',
      categoriaId: 'cat_tacos',
      nombre: 'Taco de Costilla Premium',
      descripcion: 'Costilla confitada',
      precio: 75.0,
      estado: 'agotado', // No disponible temporalmente
      orden: 3,
    );

    final tacoInactivo = PlatilloModel(
      id: 'plat_descontinuado',
      categoriaId: 'cat_tacos',
      nombre: 'Taco Retirado',
      descripcion: 'Ya no se ofrece',
      precio: 50.0,
      estado: 'inactivo', // Deshabilitado
      orden: 4,
    );

    final bebidaHorchata = PlatilloModel(
      id: 'plat_horchata',
      categoriaId: 'cat_bebidas',
      nombre: 'Agua de Horchata Artesanal 500ml',
      descripcion: 'Arroz, canela y toque de vainilla de Papantla',
      precio: 40.0,
      imagenUrl: 'https://images.reservitta.com/horchata.jpg',
      estado: 'activo',
      orden: 1,
    );

    // Postre inactivo (para que la categoría quede sin platillos activos)
    final flanInactivo = PlatilloModel(
      id: 'plat_flan',
      categoriaId: 'cat_postres',
      nombre: 'Flan Casero',
      descripcion: 'Flan napolitano con caramelo',
      precio: 55.0,
      estado: 'inactivo',
      orden: 1,
    );

    setUp(() {
      repository = FakeRestaurantMenuRepository(
        restaurants: {
          'rest_menu_ok': restActivoConMenu,
          'rest_sin_menu': restActivoSinMenu,
          'rest_cerrado': restInactivo,
        },
        categorias: {
          'rest_menu_ok': [catBebidas, catPostres, catTacos], // Desordenadas a propósito
          'rest_sin_menu': [],
        },
        platillos: {
          'rest_menu_ok': [
            tacoPastor,
            tacoAgotado,
            tacoRibEye,
            tacoInactivo,
            bebidaHorchata,
            flanInactivo,
          ],
          'rest_sin_menu': [],
        },
      );
    });

    test('Criterio 1: Dado el ID del restaurante, se obtienen sus categorías temáticas con los platillos', () async {
      final menu = await repository.getMenuByCategories('rest_menu_ok');

      expect(menu, isNotEmpty);
      expect(menu.length, 3); // 3 categorías: Tacos, Bebidas, Postres

      final categoriaTacos = menu.firstWhere((c) => c.categoriaId == 'cat_tacos');
      expect(categoriaTacos.nombre, 'Tacos Especiales');
      expect(categoriaTacos.platillos, isNotEmpty);

      final categoriaBebidas = menu.firstWhere((c) => c.categoriaId == 'cat_bebidas');
      expect(categoriaBebidas.nombre, 'Bebidas y Coctelería');
      expect(categoriaBebidas.platillos.length, 1);
    });

    test('Criterio 2: Cada platillo incluye nombre, descripción/ingredientes, precio e imagen', () async {
      final menu = await repository.getMenuByCategories('rest_menu_ok');
      final categoriaTacos = menu.firstWhere((c) => c.categoriaId == 'cat_tacos');
      final platillo = categoriaTacos.platillos.first;

      // Debe contener nombre
      expect(platillo.nombre, isNotEmpty);
      expect(platillo.nombre, 'Taco de Rib Eye');

      // Debe contener descripción / ingredientes
      expect(platillo.descripcion, isNotEmpty);
      expect(platillo.descripcion, 'Corte fino de res con costra de queso manchego');

      // Debe contener precio numérico positivo
      expect(platillo.precio, 85.0);
      expect(platillo.precio, isPositive);

      // Debe contener imagen (URL o imagen por defecto garantizada)
      expect(platillo.imagenUrl, isNotEmpty);
      expect(platillo.imagenUrl, 'https://images.reservitta.com/ribeye.jpg');
    });

    test('Criterio 3: Las categorías y los platillos respetan el orden definido por el restaurante', () async {
      final menu = await repository.getMenuByCategories('rest_menu_ok');

      // 1. Verificación del orden ascendente de las categorías:
      // Cat 1 (Tacos, orden: 1), Cat 2 (Bebidas, orden: 2), Cat 3 (Postres, orden: 3)
      expect(menu[0].categoriaId, 'cat_tacos');
      expect(menu[0].orden, 1);

      expect(menu[1].categoriaId, 'cat_bebidas');
      expect(menu[1].orden, 2);

      expect(menu[2].categoriaId, 'cat_postres');
      expect(menu[2].orden, 3);

      // 2. Verificación del orden ascendente de los platillos dentro de 'cat_tacos':
      // Rib Eye (orden: 1) debe ir antes de Pastor (orden: 2)
      final platillosTacos = menu[0].platillos;
      expect(platillosTacos.length, 2); // Solo los 2 activos
      expect(platillosTacos[0].id, 'plat_ribeye');
      expect(platillosTacos[0].orden, 1);
      expect(platillosTacos[1].id, 'plat_pastor');
      expect(platillosTacos[1].orden, 2);
    });

    test('Criterio 4: Solo se devuelven platillos activos o disponibles', () async {
      final menu = await repository.getMenuByCategories(
        'rest_menu_ok',
        soloDisponibles: true,
      );

      final catTacos = menu.firstWhere((c) => c.categoriaId == 'cat_tacos');
      final idsPlatillos = catTacos.platillos.map((p) => p.id).toList();

      // Debe incluir los platillos con estado 'activo'
      expect(idsPlatillos, contains('plat_ribeye'));
      expect(idsPlatillos, contains('plat_pastor'));

      // NO debe incluir platillos 'agotado' o 'inactivo'
      expect(idsPlatillos.contains('plat_costilla'), isFalse);
      expect(idsPlatillos.contains('plat_descontinuado'), isFalse);

      for (final p in catTacos.platillos) {
        expect(p.isActivo, isTrue);
        expect(p.isDisponible, isTrue);
        expect(p.isAgotado, isFalse);
        expect(p.isInactivo, isFalse);
      }

      // La categoría postres solo tenía un platillo inactivo, debe quedar con 0 platillos activos
      final catPostres = menu.firstWhere((c) => c.categoriaId == 'cat_postres');
      expect(catPostres.platillos, isEmpty);
    });

    test('Criterio 5: Un restaurante sin menú devuelve una lista vacía, no un error', () async {
      // 1. Restaurante registrado pero sin categorías ni platillos creados
      final menuSinMenu = await repository.getMenuByCategories('rest_sin_menu');
      expect(menuSinMenu, isA<List<MenuCategoryModel>>());
      expect(menuSinMenu, isEmpty);

      // Versión Result segura
      final resultSinMenu = await repository.getMenuByCategoriesResult('rest_sin_menu');
      expect(resultSinMenu.isSuccess, isTrue);
      expect(resultSinMenu.hasError, isFalse);
      expect(resultSinMenu.menu, isEmpty);
      expect(resultSinMenu.isEmpty, isTrue);

      // 2. Restaurante inexistente (no registrado en el sistema)
      final menuInexistente = await repository.getMenuByCategories('id_no_existente_999');
      expect(menuInexistente, isEmpty);

      final resultInexistente = await repository.getMenuByCategoriesResult('id_no_existente_999');
      expect(resultInexistente.isSuccess, isTrue);
      expect(resultInexistente.hasError, isFalse);
      expect(resultInexistente.menu, isEmpty);

      // 3. Restaurante inactivo
      final menuInactivo = await repository.getMenuByCategories('rest_cerrado');
      expect(menuInactivo, isEmpty);

      // 4. ID vacío o en blanco
      final menuVacio = await repository.getMenuByCategories('   ');
      expect(menuVacio, isEmpty);
    });

    test('MVVM: RestaurantMenuViewModel gestiona estados reactivos y navegación por categorías', () async {
      final vm = RestaurantMenuViewModel(
        restaurantId: 'rest_menu_ok',
        repository: repository,
      );

      expect(vm.isLoading, isTrue);
      expect(vm.menu, isEmpty);

      await vm.cargarMenu();

      expect(vm.isLoading, isFalse);
      expect(vm.hasError, isFalse);
      expect(vm.hasData, isTrue);
      expect(vm.estaVacio, isFalse);
      expect(vm.totalPlatillos, 3); // 2 tacos + 1 bebida
      expect(vm.categorias.length, 3);

      // Selecciona por defecto la primera categoría
      expect(vm.categoriaSeleccionadaId, 'cat_tacos');
      expect(vm.categoriaSeleccionada?.nombre, 'Tacos Especiales');

      // Cambiar de categoría seleccionada
      vm.seleccionarCategoria('cat_bebidas');
      expect(vm.categoriaSeleccionadaId, 'cat_bebidas');
      expect(vm.categoriaSeleccionada?.nombre, 'Bebidas y Coctelería');

      // Probar ViewModel con restaurante sin menú
      final vmSinMenu = RestaurantMenuViewModel(
        restaurantId: 'rest_sin_menu',
        repository: repository,
      );
      await vmSinMenu.cargarMenu();
      expect(vmSinMenu.isLoading, isFalse);
      expect(vmSinMenu.hasError, isFalse);
      expect(vmSinMenu.hasData, isFalse);
      expect(vmSinMenu.estaVacio, isTrue);
      expect(vmSinMenu.menu, isEmpty);
      expect(vmSinMenu.totalPlatillos, 0);
    });

    test('Polimorfismo: RestaurantService implementa los métodos de HU06-RF01', () {
      final service = RestaurantService();
      expect(service, isA<RestaurantRepository>());

      // Verificar método agruparMenu estático
      final agrupado = RestaurantService.agruparMenu(
        categorias: [catBebidas, catTacos],
        platillos: [tacoPastor, tacoRibEye, tacoAgotado, bebidaHorchata],
        soloDisponibles: true,
      );

      expect(agrupado.length, 2);
      expect(agrupado[0].categoriaId, 'cat_tacos');
      expect(agrupado[0].platillos.length, 2); // Excluye el agotado
      expect(agrupado[1].categoriaId, 'cat_bebidas');
      expect(agrupado[1].platillos.length, 1);
    });
  });
}

