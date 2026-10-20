import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/restaurant_repository.dart';

/// Implementación Fake de RestaurantRepository para pruebas unitarias de HU01-RF01
class FakeRestaurantRepository implements RestaurantRepository {
  final List<RestaurantModel> restaurantsEnMemoria;
  final bool shouldFail;

  FakeRestaurantRepository({
    required this.restaurantsEnMemoria,
    this.shouldFail = false,
  });

  @override
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit}) async {
    if (shouldFail) {
      throw const ControlledRestaurantQueryException(
        'Error simulado de red en Firestore al consultar restaurantes activos.',
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
      // HU01-RF01 Criterio 4: Manejo controlado, emite lista vacía sin propagar excepción fatal
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
    final active = await getActiveRestaurants();
    return GeoUtils.filterAndSortByDistance(
      restaurants: active,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      radiusKm: radiusKm,
    );
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
    } catch (e) {
      return RestaurantQueryResult.failure(e.toString());
    }
  }

  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsByRadiusStream({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) {
    return getActiveRestaurantsStream().map((list) {
      return GeoUtils.filterAndSortByDistance(
        restaurants: list,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radiusKm: radiusKm,
      );
    });
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
  group('HU01-RF01: Consulta de restaurantes asociados', () {
    late List<RestaurantModel> mockRestaurants;

    setUp(() {
      mockRestaurants = [
        const RestaurantModel(
          id: 'rest_activo_1',
          nombre: 'La Parrilla Urbana',
          logoUrl: 'https://example.com/logo1.png',
          imagenPrincipalUrl: 'https://example.com/cover1.jpg',
          direccion: 'Av. Insurgentes Sur 1234',
          coordenadas: GeoPoint(19.3800, -99.1750),
          estado: 'activo',
        ),
        const RestaurantModel(
          id: 'rest_inactivo_2',
          nombre: 'Bistro Cerrado',
          logoUrl: 'https://example.com/logo2.png',
          imagenPrincipalUrl: 'https://example.com/cover2.jpg',
          direccion: 'Calle Orizaba 55',
          coordenadas: GeoPoint(19.4180, -99.1590),
          estado: 'inactivo',
        ),
        const RestaurantModel(
          id: 'rest_activo_3',
          nombre: 'Trattoria Bella',
          logoUrl: 'https://example.com/logo3.png',
          imagenPrincipalUrl: 'https://example.com/cover3.jpg',
          direccion: 'Paseo de la Reforma 400',
          coordenadas: GeoPoint(19.4260, -99.1680),
          estado: 'activo',
        ),
      ];
    });

    test('Criterio 1: Los restaurantes cuentan con los campos públicos esperados', () {
      final rest = mockRestaurants.first;
      expect(rest.nombre, isNotEmpty);
      expect(rest.logo, startsWith('https://'));
      expect(rest.imagenPrincipal, startsWith('https://'));
      expect(rest.direccion, isNotEmpty);
      expect(rest.coordenadas, isA<GeoPoint>());
      expect(rest.estado, equals('activo'));
    });

    test('Criterio 2: La consulta devuelve únicamente restaurantes con estado activo', () async {
      final repository = FakeRestaurantRepository(
        restaurantsEnMemoria: mockRestaurants,
      );

      final activos = await repository.getActiveRestaurants();

      // Debe retornar únicamente los 2 activos y excluir el inactivo
      expect(activos.length, 2);
      expect(activos.every((r) => r.estado == 'activo'), isTrue);
      expect(activos.every((r) => r.isActivo), isTrue);
      expect(activos.any((r) => r.id == 'rest_inactivo_2'), isFalse);
    });

    test('Criterio 2: Limite de consulta devuelve la cantidad máxima especificada', () async {
      final repository = FakeRestaurantRepository(
        restaurantsEnMemoria: mockRestaurants,
      );

      final activos = await repository.getActiveRestaurants(limit: 1);
      expect(activos.length, 1);
      expect(activos.first.isActivo, isTrue);
    });

    test('Criterio 3: Las reglas de Firestore en firestore.rules permiten lectura sin autenticacion', () {
      final rulesFile = File('firestore.rules');
      expect(rulesFile.existsSync(), isTrue);

      final content = rulesFile.readAsStringSync();

      // Verifica que la regla para /restaurants/{restaurantId} contenga allow read: if true;
      expect(content, contains('match /restaurants/{restaurantId}'));
      expect(content, contains('allow read: if true;'));
    });

    test('Criterio 4: Si la consulta falla, se devuelve un error controlado y no cierra la app', () async {
      final failingRepository = FakeRestaurantRepository(
        restaurantsEnMemoria: mockRestaurants,
        shouldFail: true,
      );

      // Verificación 1: getActiveRestaurants lanza ControlledRestaurantQueryException (no crash de app)
      expect(
        () async => await failingRepository.getActiveRestaurants(),
        throwsA(isA<ControlledRestaurantQueryException>()),
      );

      // Verificación 2: getActiveRestaurantsResult retorna RestaurantQueryResult con hasError = true
      final result = await failingRepository.getActiveRestaurantsResult();
      expect(result.hasError, isTrue);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('Error simulado'));
      expect(result.restaurants, isEmpty);
    });

    test('Criterio 4: Si el Stream falla, el error es capturado emitiendo lista vacia', () async {
      final failingRepository = FakeRestaurantRepository(
        restaurantsEnMemoria: mockRestaurants,
        shouldFail: true,
      );

      final streamResult = await failingRepository.getActiveRestaurantsStream().first;
      expect(streamResult, isEmpty);
    });

    test('Polimorfismo: RestaurantService implementa RestaurantRepository', () {
      final service = RestaurantService();
      expect(service, isA<RestaurantRepository>());
    });
  });
}
