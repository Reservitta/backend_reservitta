import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/restaurant_repository.dart';

/// Fake de RestaurantRepository para pruebas completas de HU02-RF02
class FakeRestaurantRepositoryHU02 implements RestaurantRepository {
  final List<RestaurantModel> restaurantsEnMemoria;
  final bool shouldFail;

  FakeRestaurantRepositoryHU02({
    required this.restaurantsEnMemoria,
    this.shouldFail = false,
  });

  @override
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit}) async {
    if (shouldFail) {
      throw const ControlledRestaurantQueryException(
        'Falla simulada de red al consultar restaurantes activos.',
      );
    }
    var list = restaurantsEnMemoria.where((r) => r.isActivo).toList();
    if (limit != null && limit > 0 && list.length > limit) {
      list = list.sublist(0, limit);
    }
    return list;
  }

  @override
  Future<RestaurantQueryResult> getActiveRestaurantsResult({int? limit}) async {
    try {
      final list = await getActiveRestaurants(limit: limit);
      return RestaurantQueryResult.success(list);
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
    } catch (e) {
      return RestaurantQueryResult.failure('Error inesperado: $e');
    }
  }

  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsStream() async* {
    if (shouldFail) {
      yield <RestaurantModel>[];
      return;
    }
    yield restaurantsEnMemoria.where((r) => r.isActivo).toList();
  }

  @override
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    if (shouldFail) return null;
    try {
      return restaurantsEnMemoria.firstWhere((r) => r.id == restaurantId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<RestaurantModel>> getActiveRestaurantsByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    if (shouldFail) {
      throw const ControlledRestaurantQueryException(
        'Falla simulada de red al filtrar restaurantes por radio.',
      );
    }
    try {
      if (radiusKm <= 0) {
        throw ArgumentError('El radio debe ser mayor a 0 km.');
      }
      if (!GeoUtils.isValidCoordinate(userLatitude, userLongitude)) {
        throw ArgumentError('Coordenadas de usuario inválidas.');
      }

      final activeList = await getActiveRestaurants();
      return GeoUtils.filterAndSortByDistance(
        restaurants: activeList,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radiusKm: radiusKm,
      );
    } catch (e) {
      if (e is ControlledRestaurantQueryException) rethrow;
      throw ControlledRestaurantQueryException(
        'Error controlado al consultar restaurantes por radio: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<RestaurantQueryResult> getActiveRestaurantsByRadiusResult({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    try {
      final list = await getActiveRestaurantsByRadius(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radiusKm: radiusKm,
      );
      return RestaurantQueryResult.success(list);
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
    } catch (e) {
      return RestaurantQueryResult.failure('Error inesperado: $e');
    }
  }

  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsByRadiusStream({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) {
    return getActiveRestaurantsStream().map((restaurants) {
      if (!GeoUtils.isValidCoordinate(userLatitude, userLongitude) ||
          radiusKm <= 0) {
        return <RestaurantModel>[];
      }
      return GeoUtils.filterAndSortByDistance(
        restaurants: restaurants,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radiusKm: radiusKm,
      );
    }).handleError((_) => <RestaurantModel>[]);
  }

  @override
  Future<List<RestaurantWithDistance>> getRestaurantsWithDistanceByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    final list = await getActiveRestaurantsByRadius(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      radiusKm: radiusKm,
    );

    return list
        .map((r) => RestaurantWithDistance(
              restaurant: r,
              distanceKm: r.distanciaKm ?? 0.0,
            ))
        .toList();
  }

  @override
  Future<List<RestaurantModel>> getRestaurantsByDateTime({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  }) async {
    final active = await getActiveRestaurants();
    return active
        .where((r) =>
            ScheduleUtils.isRestaurantOpenAt(restaurant: r, dateTime: dateTime))
        .toList();
  }

  @override
  Future<RestaurantQueryResult> getRestaurantsByDateTimeResult({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  }) async {
    try {
      final list = await getRestaurantsByDateTime(
        dateTime: dateTime,
        partySize: partySize,
        durationMin: durationMin,
      );
      return RestaurantQueryResult.success(list);
    } catch (e) {
      return RestaurantQueryResult.failure(e.toString());
    }
  }

  @override
  Stream<List<RestaurantModel>> getRestaurantsByDateTimeStream({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  }) {
    return getActiveRestaurantsStream().map((list) {
      return list
          .where((r) =>
              ScheduleUtils.isRestaurantOpenAt(restaurant: r, dateTime: dateTime))
          .toList();
    });
  }

  @override
  Future<bool> checkRestaurantAvailability({
    required String restaurantId,
    required DateTime dateTime,
    int partySize = 1,
    int durationMin = 90,
  }) async {
    final r = await getRestaurantById(restaurantId);
    if (r == null) return false;
    return ScheduleUtils.isRestaurantOpenAt(restaurant: r, dateTime: dateTime);
  }

  @override
  Future<int> getRemainingCapacity({
    required String restaurantId,
    required DateTime dateTime,
    int durationMin = 90,
  }) async {
    final r = await getRestaurantById(restaurantId);
    if (r == null ||
        !ScheduleUtils.isRestaurantOpenAt(restaurant: r, dateTime: dateTime)) {
      return 0;
    }
    return r.capacidadMaxima;
  }
}

void main() {
  group('HU02-RF02: Cálculo de distancia y filtrado por radio en Repositorio', () {
    // Ubicación del usuario: Zócalo de la CDMX
    const userLat = 19.4326;
    const userLng = -99.1332;

    late List<RestaurantModel> mockRestaurants;
    late FakeRestaurantRepositoryHU02 repo;

    setUp(() {
      mockRestaurants = [
        // Restaurante A: a ~1.8 km (activo)
        const RestaurantModel(
          id: 'rest_cercano',
          nombre: 'Café Tacuba',
          direccion: 'Calle de Tacuba 28, Centro Histórico',
          coordenadas: GeoPoint(19.4355, -99.1378),
          estado: 'activo',
        ),
        // Restaurante B: a ~3.7 km (activo)
        const RestaurantModel(
          id: 'rest_medio',
          nombre: 'Terraza Reforma',
          direccion: 'Paseo de la Reforma 222',
          coordenadas: GeoPoint(19.4285, -99.1610),
          estado: 'activo',
        ),
        // Restaurante C: a ~8.0 km (activo)
        const RestaurantModel(
          id: 'rest_lejano',
          nombre: 'Coyoacán Grill',
          direccion: 'Centenario 35, Coyoacán',
          coordenadas: GeoPoint(19.3510, -99.1620),
          estado: 'activo',
        ),
        // Restaurante D: a ~1.0 km pero INACTIVO (debe excluirse por inactivo)
        const RestaurantModel(
          id: 'rest_inactivo_cercano',
          nombre: 'Comedor Cerrado',
          direccion: 'Madero 10, Centro',
          coordenadas: GeoPoint(19.4338, -99.1370),
          estado: 'inactivo',
        ),
        // Restaurante E: a 2 km pero SIN COORDENADAS (debe excluirse por Criterio 4)
        const RestaurantModel(
          id: 'rest_sin_coordenadas',
          nombre: 'Pizzería Fantasma',
          direccion: 'Sin dirección fija',
          coordenadas: null,
          estado: 'activo',
        ),
        // Restaurante F: COORDENADAS (0,0) (debe excluirse por Criterio 4)
        const RestaurantModel(
          id: 'rest_coordenadas_cero',
          nombre: 'Null Island Tacos',
          direccion: 'Lat 0 Lng 0',
          coordenadas: GeoPoint(0.0, 0.0),
          estado: 'activo',
        ),
      ];

      repo = FakeRestaurantRepositoryHU02(restaurantsEnMemoria: mockRestaurants);
    });

    test('Criterio 1: Se calcula la distancia entre el usuario y cada restaurante', () async {
      final results = await repo.getActiveRestaurantsByRadius(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 15.0,
      );

      // Todos los resultados deben tener su distancia calculada y válida
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.distanciaKm, isNotNull);
        expect(r.distanciaKm!, greaterThan(0.0));
      }
    });

    test('Criterio 2: Filtrado por radio de 2 km incluye sólo Café Tacuba', () async {
      final results = await repo.getActiveRestaurantsByRadius(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 2.0,
      );

      expect(results.length, 1);
      expect(results.first.id, 'rest_cercano');
      expect(results.first.nombre, 'Café Tacuba');
      expect(results.first.distanciaKm!, lessThanOrEqualTo(2.0));
    });

    test('Criterio 2: Filtrado por radio de 5 km incluye Café Tacuba y Terraza Reforma', () async {
      final results = await repo.getActiveRestaurantsByRadius(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 5.0,
      );

      expect(results.length, 2);
      expect(results.any((r) => r.id == 'rest_cercano'), isTrue);
      expect(results.any((r) => r.id == 'rest_medio'), isTrue);
      expect(results.any((r) => r.id == 'rest_lejano'), isFalse);
    });

    test('Criterio 2: Filtrado por radio de 10 km incluye Coyoacán Grill', () async {
      final results = await repo.getActiveRestaurantsByRadius(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 10.0,
      );

      expect(results.length, 3);
      expect(results.any((r) => r.id == 'rest_lejano'), isTrue);
    });

    test('Criterio 3: Los resultados se ordenan estrictamente del más cercano al más lejano', () async {
      final results = await repo.getActiveRestaurantsByRadius(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 15.0,
      );

      expect(results.length, 3);
      // Índice 0: más cercano (~0.5 km)
      expect(results[0].id, 'rest_cercano');
      // Índice 1: intermedio (~3.2 km)
      expect(results[1].id, 'rest_medio');
      // Índice 2: más lejano (~9.1 km)
      expect(results[2].id, 'rest_lejano');

      expect(results[0].distanciaKm!, lessThan(results[1].distanciaKm!));
      expect(results[1].distanciaKm!, lessThan(results[2].distanciaKm!));
    });

    test('Criterio 4: Los restaurantes sin coordenadas válidas (null o 0,0) se excluyen del filtro', () async {
      final results = await repo.getActiveRestaurantsByRadius(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 25.0,
      );

      expect(results.any((r) => r.id == 'rest_sin_coordenadas'), isFalse);
      expect(results.any((r) => r.id == 'rest_coordenadas_cero'), isFalse);
    });

    test('Exclusión de inactivos: Restaurantes inactivos nunca entran aunque estén cerca', () async {
      final results = await repo.getActiveRestaurantsByRadius(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 25.0,
      );

      expect(results.any((r) => r.id == 'rest_inactivo_cercano'), isFalse);
    });

    test('getActiveRestaurantsByRadiusResult devuelve resultado seguro ante éxito y error', () async {
      // Caso éxito
      final successResult = await repo.getActiveRestaurantsByRadiusResult(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 5.0,
      );
      expect(successResult.hasError, isFalse);
      expect(successResult.restaurants.length, 2);

      // Caso falla controlada
      final failingRepo = FakeRestaurantRepositoryHU02(
        restaurantsEnMemoria: mockRestaurants,
        shouldFail: true,
      );
      final failureResult = await failingRepo.getActiveRestaurantsByRadiusResult(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 5.0,
      );
      expect(failureResult.hasError, isTrue);
      expect(failureResult.errorMessage, isNotNull);
      expect(failureResult.restaurants, isEmpty);
    });

    test('getRestaurantsWithDistanceByRadius devuelve lista de RestaurantWithDistance con formateo', () async {
      final withDistance = await repo.getRestaurantsWithDistanceByRadius(
        userLatitude: userLat,
        userLongitude: userLng,
        radiusKm: 5.0,
      );

      expect(withDistance.length, 2);
      expect(withDistance.first.restaurant.id, 'rest_cercano');
      expect(withDistance.first.distanceKm, greaterThan(0.0));
      expect(withDistance.first.formattedDistance, isNotEmpty);
    });

    test('getActiveRestaurantsByRadiusStream emite restaurantes filtrados en tiempo real', () async {
      final streamResult = await repo
          .getActiveRestaurantsByRadiusStream(
            userLatitude: userLat,
            userLongitude: userLng,
            radiusKm: 2.0,
          )
          .first;

      expect(streamResult.length, 1);
      expect(streamResult.first.id, 'rest_cercano');
    });

    test('Polimorfismo: RestaurantService implementa los nuevos métodos de HU02-RF02', () {
      final service = RestaurantService();
      expect(service, isA<RestaurantRepository>());
    });
  });
}
