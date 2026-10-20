import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch_model.dart';
import '../models/reservation_model.dart';
import '../models/restaurant_model.dart';
import '../models/restaurant_with_distance.dart';
import '../models/service_catalog_model.dart';
import '../utils/geo_utils.dart';
import '../utils/schedule_utils.dart';

/// Resultado paginado para navegación de restaurantes con scroll infinito (HU01-RF01, HU01-RF02)
class PaginatedRestaurantsResult {
  final List<RestaurantModel> restaurants;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const PaginatedRestaurantsResult({
    required this.restaurants,
    this.lastDocument,
    required this.hasMore,
  });
}

/// Excepción controlada para errores en consultas de restaurantes (HU01-RF01 Criterio 4)
class ControlledRestaurantQueryException implements Exception {
  final String message;
  final Object? originalError;

  const ControlledRestaurantQueryException(
    this.message, {
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Resultado seguro de consulta para evitar cierres o excepciones no capturadas
class RestaurantQueryResult {
  final List<RestaurantModel> restaurants;
  final String? errorMessage;
  final bool hasError;

  const RestaurantQueryResult.success(this.restaurants)
      : errorMessage = null,
        hasError = false;

  const RestaurantQueryResult.failure(this.errorMessage)
      : restaurants = const [],
        hasError = true;
}

/// Contrato del Repositorio de Restaurantes (HU01-RF01, HU02-RF02)
abstract class RestaurantRepository {
  /// Consulta de restaurantes asociados con estado 'activo' (HU01-RF01 Criterio 2)
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit});

  /// Consulta de restaurantes asociados activos retornando un resultado seguro (HU01-RF01 Criterio 4)
  Future<RestaurantQueryResult> getActiveRestaurantsResult({int? limit});

  /// Stream en tiempo real de restaurantes asociados activos
  Stream<List<RestaurantModel>> getActiveRestaurantsStream();

  /// Obtiene los datos de un restaurante por su ID
  Future<RestaurantModel?> getRestaurantById(String restaurantId);

  /// HU02-RF02: Consulta y filtra restaurantes activos dentro de un radio en km
  /// respecto a la ubicación del usuario, ordenados del más cercano al más lejano.
  /// Excluye aquellos sin coordenadas válidas.
  Future<List<RestaurantModel>> getActiveRestaurantsByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  });

  /// HU02-RF02: Versión segura que devuelve RestaurantQueryResult sin lanzar excepciones
  Future<RestaurantQueryResult> getActiveRestaurantsByRadiusResult({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  });

  /// HU02-RF02: Stream en tiempo real de restaurantes filtrados por radio y ordenados por distancia
  Stream<List<RestaurantModel>> getActiveRestaurantsByRadiusStream({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  });

  /// HU02-RF02: Retorna lista de pares RestaurantWithDistance
  Future<List<RestaurantWithDistance>> getRestaurantsWithDistanceByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  });

  /// HU03-RF01: Consulta de restaurantes abiertos y con disponibilidad para una fecha y hora dada.
  /// - Criterio 1: Cada restaurante tiene guardados sus días y horarios de atención.
  /// - Criterio 2: Dada una fecha y hora, devuelve solo los restaurantes abiertos en ese momento.
  /// - Criterio 3: Excluye restaurantes sin lugares disponibles en ese horario, considerando las reservaciones existentes.
  /// - Criterio 4: Respeta los días de cierre especial.
  Future<List<RestaurantModel>> getRestaurantsByDateTime({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  });

  /// HU03-RF01: Consulta segura de restaurantes por fecha y hora retornando RestaurantQueryResult
  Future<RestaurantQueryResult> getRestaurantsByDateTimeResult({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  });

  /// HU03-RF01: Stream reactivo de restaurantes abiertos y con lugares disponibles por fecha y hora
  Stream<List<RestaurantModel>> getRestaurantsByDateTimeStream({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  });

  /// HU03-RF01: Verifica si un restaurante específico tiene lugares disponibles y está abierto
  Future<bool> checkRestaurantAvailability({
    required String restaurantId,
    required DateTime dateTime,
    int partySize = 1,
    int durationMin = 90,
  });

  /// HU03-RF01: Obtiene la capacidad restante de un restaurante para una fecha y hora
  Future<int> getRemainingCapacity({
    required String restaurantId,
    required DateTime dateTime,
    int durationMin = 90,
  });

  /// HU04-RF01: Consulta de restaurantes por capacidad (Criterios 1, 2, 3 y 4)
  /// - Criterio 1: Cada restaurante tiene registrada su capacidad máxima (o mesas y su capacidad).
  /// - Criterio 2: Dada una cantidad de personas, se devuelven solo los restaurantes que pueden atender a ese grupo.
  /// - Criterio 3: Si también hay fecha y hora seleccionadas, se considera la capacidad restante en ese horario.
  /// - Criterio 4: Un restaurante sin capacidad registrada no aparece en este filtro.
  Future<List<RestaurantModel>> getRestaurantsByCapacity({
    required int partySize,
    DateTime? dateTime,
    int durationMin = 90,
  });

  /// HU04-RF01: Consulta segura de restaurantes por capacidad retornando RestaurantQueryResult
  Future<RestaurantQueryResult> getRestaurantsByCapacityResult({
    required int partySize,
    DateTime? dateTime,
    int durationMin = 90,
  });

  /// HU04-RF01: Stream reactivo de restaurantes filtrados por capacidad
  Stream<List<RestaurantModel>> getRestaurantsByCapacityStream({
    required int partySize,
    DateTime? dateTime,
    int durationMin = 90,
  });
}

/// Servicio y Repositorio de Restaurantes (HU01-RF01, HU01-RF02, HU02-RF02, HU03-RF01)
class RestaurantService implements RestaurantRepository {
  final FirebaseFirestore? _firestoreInstance;

  RestaurantService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  static const List<Map<String, String>> defaultServicesList = [
    {'id': 'reservaciones', 'nombre': 'Reservaciones', 'icono': 'event_seat'},
    {'id': 'preorden', 'nombre': 'Preorden', 'icono': 'restaurant_menu'},
    {'id': 'estacionamiento', 'nombre': 'Estacionamiento', 'icono': 'local_parking'},
    {'id': 'acceso_discapacidad', 'nombre': 'Acceso para discapacidad', 'icono': 'accessible'},
    {'id': 'terraza', 'nombre': 'Terraza', 'icono': 'deck'},
    {'id': 'wifi', 'nombre': 'Wi-Fi', 'icono': 'wifi'},
    {'id': 'musica_en_vivo', 'nombre': 'Música en vivo', 'icono': 'music_note'},
    {'id': 'pet_friendly', 'nombre': 'Apto para mascotas', 'icono': 'pets'},
  ];

  /// Obtiene los datos de un restaurante por su ID con manejo de error controlado
  @override
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    try {
      final doc =
          await _firestore.collection('restaurants').doc(restaurantId).get();
      if (!doc.exists) return null;
      return RestaurantModel.fromFirestore(doc);
    } catch (e) {
      // HU01-RF01 Criterio 4: Error controlado sin cerrar la app
      return null;
    }
  }

  /// HU01-RF01 Criterio 2: Consulta de restaurantes asociados con estado activo.
  /// HU01-RF01 Criterio 4: Manejo controlado de fallas sin cerrar la app.
  @override
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('restaurants')
          .where('estado', isEqualTo: 'activo');

      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final list = snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .where((r) => r.isActivo)
          .toList();

      // Ordenar alfabéticamente por nombre para consistencia
      list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return list;
    } catch (e) {
      // HU01-RF01 Criterio 4: Si la consulta falla, el repositorio devuelve un error controlado
      throw ControlledRestaurantQueryException(
        'Error controlado al consultar restaurantes asociados activos: $e',
        originalError: e,
      );
    }
  }

  /// HU01-RF01 Criterio 4: Consulta segura que retorna RestaurantQueryResult y no cierra la app
  @override
  Future<RestaurantQueryResult> getActiveRestaurantsResult({int? limit}) async {
    try {
      final list = await getActiveRestaurants(limit: limit);
      return RestaurantQueryResult.success(list);
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
    } catch (e) {
      return RestaurantQueryResult.failure('Error inesperado al consultar restaurantes: $e');
    }
  }

  /// HU01-RF01 Criterio 2 y 4: Stream en tiempo real de restaurantes activos con manejo de error controlado
  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsStream() {
    return _firestore
        .collection('restaurants')
        .where('estado', isEqualTo: 'activo')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .where((r) => r.isActivo)
          .toList();
      list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return list;
    }).handleError((error) {
      // HU01-RF01 Criterio 4: Error controlado en el stream sin cerrar la app
      return <RestaurantModel>[];
    });
  }

  /// HU02-RF02: Consulta y filtra restaurantes activos dentro de un radio en km.
  /// - Calcula distancia por Haversine (Criterio 1).
  /// - Filtra por radio (Criterio 2).
  /// - Ordena del más cercano al más lejano (Criterio 3).
  /// - Excluye restaurantes sin coordenadas válidas (Criterio 4).
  @override
  Future<List<RestaurantModel>> getActiveRestaurantsByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    try {
      if (radiusKm <= 0) {
        throw ArgumentError('El radio de búsqueda debe ser mayor a 0 km.');
      }
      if (!GeoUtils.isValidCoordinate(userLatitude, userLongitude)) {
        throw ArgumentError(
          'Coordenadas de usuario inválidas: ($userLatitude, $userLongitude)',
        );
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

  /// HU02-RF02: Consulta segura por radio retornando RestaurantQueryResult
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
      return RestaurantQueryResult.failure(
        'Error inesperado al filtrar restaurantes por radio: $e',
      );
    }
  }

  /// HU02-RF02: Stream en tiempo real de restaurantes filtrados por radio
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
    }).handleError((_) {
      return <RestaurantModel>[];
    });
  }

  /// HU02-RF02: Retorna lista de pares RestaurantWithDistance
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

  /// HU03-RF01: Consulta de restaurantes abiertos y con disponibilidad para una fecha y hora.
  /// - Criterio 1: Cada restaurante tiene guardados sus días y horarios de atención.
  /// - Criterio 2: Dada una fecha y hora, la consulta devuelve solo los restaurantes abiertos en ese momento.
  /// - Criterio 3: Se excluyen los restaurantes sin lugares disponibles en ese horario, considerando las reservaciones existentes.
  /// - Criterio 4: La consulta respeta los días de cierre.
  @override
  Future<List<RestaurantModel>> getRestaurantsByDateTime({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  }) async {
    try {
      if (partySize != null && partySize <= 0) {
        throw ArgumentError('El número de personas debe ser mayor a 0.');
      }
      if (durationMin <= 0) {
        throw ArgumentError('La duración de la reservación debe ser mayor a 0 minutos.');
      }

      // 1. Obtener restaurantes activos
      final activeList = await getActiveRestaurants();

      // 2. Filtrar restaurantes abiertos en esa fecha y hora (Criterios 1, 2 y 4)
      final openRestaurants = activeList.where((restaurant) {
        return ScheduleUtils.isRestaurantOpenAt(
          restaurant: restaurant,
          dateTime: dateTime,
        );
      }).toList();

      if (openRestaurants.isEmpty) {
        return <RestaurantModel>[];
      }

      // 3. Consultar reservaciones activas para esa fecha local
      final dateString = ScheduleUtils.formatDateLocal(dateTime);
      final reservationsSnap = await _firestore
          .collection('reservations')
          .where('fechaLocal', isEqualTo: dateString)
          .get();

      final allDayReservations = reservationsSnap.docs
          .map((doc) => ReservationModel.fromFirestore(doc))
          .where((res) => res.isActiva)
          .toList();

      // Agrupar reservaciones por restauranteId
      final reservationsByRest = <String, List<ReservationModel>>{};
      for (final res in allDayReservations) {
        reservationsByRest.putIfAbsent(res.restauranteId, () => []).add(res);
      }

      // 4. Filtrar restaurantes con lugares disponibles (Criterio 3)
      final availableRestaurants = <RestaurantModel>[];
      final requiredSeats = partySize ?? 1;

      for (final rest in openRestaurants) {
        final restReservations = reservationsByRest[rest.id] ?? [];

        // Calcular lugares ocupados por reservaciones que se traslapan con el horario objetivo
        int occupiedSeats = 0;
        for (final res in restReservations) {
          if (res.overlapsWith(dateTime, durationMin: durationMin)) {
            occupiedSeats += res.personas;
          }
        }

        final maxCap = rest.capacidadTotal;
        final remainingSeats = maxCap - occupiedSeats;

        if (remainingSeats >= requiredSeats) {
          availableRestaurants.add(rest);
        }
      }

      return availableRestaurants;
    } catch (e) {
      if (e is ControlledRestaurantQueryException) rethrow;
      throw ControlledRestaurantQueryException(
        'Error controlado al consultar restaurantes por fecha y hora: $e',
        originalError: e,
      );
    }
  }

  /// HU03-RF01: Versión segura que devuelve RestaurantQueryResult sin lanzar excepciones
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
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
    } catch (e) {
      return RestaurantQueryResult.failure(
        'Error inesperado al consultar restaurantes por fecha y hora: $e',
      );
    }
  }

  /// HU03-RF01: Stream reactivo de restaurantes abiertos y con lugares disponibles por fecha y hora
  @override
  Stream<List<RestaurantModel>> getRestaurantsByDateTimeStream({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  }) {
    return getActiveRestaurantsStream().asyncMap((activeRestaurants) async {
      try {
        final openRestaurants = activeRestaurants.where((r) {
          return ScheduleUtils.isRestaurantOpenAt(
            restaurant: r,
            dateTime: dateTime,
          );
        }).toList();

        if (openRestaurants.isEmpty) return <RestaurantModel>[];

        final dateString = ScheduleUtils.formatDateLocal(dateTime);
        final reservationsSnap = await _firestore
            .collection('reservations')
            .where('fechaLocal', isEqualTo: dateString)
            .get();

        final activeReservations = reservationsSnap.docs
            .map((doc) => ReservationModel.fromFirestore(doc))
            .where((r) => r.isActiva)
            .toList();

        final byRest = <String, List<ReservationModel>>{};
        for (final res in activeReservations) {
          byRest.putIfAbsent(res.restauranteId, () => []).add(res);
        }

        final result = <RestaurantModel>[];
        final req = partySize ?? 1;

        for (final rest in openRestaurants) {
          final resList = byRest[rest.id] ?? [];
          int occupied = 0;
          for (final res in resList) {
            if (res.overlapsWith(dateTime, durationMin: durationMin)) {
              occupied += res.personas;
            }
          }
          final maxCap = rest.capacidadTotal;
          final remaining = maxCap - occupied;
          if (remaining >= req) {
            result.add(rest);
          }
        }
        return result;
      } catch (_) {
        return <RestaurantModel>[];
      }
    }).handleError((_) {
      return <RestaurantModel>[];
    });
  }

  /// HU03-RF01: Verifica si un restaurante específico tiene lugares disponibles y está abierto
  @override
  Future<bool> checkRestaurantAvailability({
    required String restaurantId,
    required DateTime dateTime,
    int partySize = 1,
    int durationMin = 90,
  }) async {
    final remaining = await getRemainingCapacity(
      restaurantId: restaurantId,
      dateTime: dateTime,
      durationMin: durationMin,
    );
    return remaining >= (partySize > 0 ? partySize : 1);
  }

  /// HU03-RF01: Obtiene la capacidad restante de un restaurante para una fecha y hora
  @override
  Future<int> getRemainingCapacity({
    required String restaurantId,
    required DateTime dateTime,
    int durationMin = 90,
  }) async {
    try {
      final restaurant = await getRestaurantById(restaurantId);
      if (restaurant == null || !restaurant.isActivo) return 0;
      if (!restaurant.tieneCapacidadRegistrada) return 0;

      // Si no está abierto en esa fecha/hora, capacidad es 0
      if (!ScheduleUtils.isRestaurantOpenAt(
        restaurant: restaurant,
        dateTime: dateTime,
      )) {
        return 0;
      }

      final dateString = ScheduleUtils.formatDateLocal(dateTime);
      final reservationsSnap = await _firestore
          .collection('reservations')
          .where('fechaLocal', isEqualTo: dateString)
          .get();

      final overlappingReservations = reservationsSnap.docs
          .map((doc) => ReservationModel.fromFirestore(doc))
          .where((r) =>
              r.restauranteId == restaurantId &&
              r.isActiva &&
              r.overlapsWith(dateTime, durationMin: durationMin));

      int occupiedSeats = 0;
      for (final r in overlappingReservations) {
        occupiedSeats += r.personas;
      }

      final maxCap = restaurant.capacidadTotal;
      final remaining = maxCap - occupiedSeats;
      return remaining > 0 ? remaining : 0;
    } catch (_) {
      return 0;
    }
  }

  /// HU04-RF01: Consulta de restaurantes por capacidad (Criterios 1, 2, 3 y 4)
  /// - Criterio 1: Cada restaurante tiene registrada su capacidad máxima (o mesas y su capacidad).
  /// - Criterio 2: Dada una cantidad de personas, se devuelven solo los restaurantes que pueden atender a ese grupo.
  /// - Criterio 3: Si también hay fecha y hora seleccionadas, se considera la capacidad restante en ese horario.
  /// - Criterio 4: Un restaurante sin capacidad registrada no aparece en este filtro.
  @override
  Future<List<RestaurantModel>> getRestaurantsByCapacity({
    required int partySize,
    DateTime? dateTime,
    int durationMin = 90,
  }) async {
    try {
      if (partySize <= 0) return <RestaurantModel>[];

      // 1. Obtener restaurantes activos
      final activeList = await getActiveRestaurants();

      // Criterio 4: Un restaurante sin capacidad registrada no aparece en este filtro.
      final withCapacity = activeList
          .where((restaurant) => restaurant.tieneCapacidadRegistrada)
          .toList();

      if (withCapacity.isEmpty) return <RestaurantModel>[];

      // Caso 1: Si no hay fecha ni hora seleccionadas (Criterios 2 y 4)
      if (dateTime == null) {
        return withCapacity
            .where((restaurant) => restaurant.capacidadTotal >= partySize)
            .toList();
      }

      // Caso 2: Si también hay fecha y hora seleccionadas (Criterio 3)
      // a) Filtrar restaurantes abiertos en esa fecha y horario
      final openRestaurants = withCapacity.where((restaurant) {
        return ScheduleUtils.isRestaurantOpenAt(
          restaurant: restaurant,
          dateTime: dateTime,
        );
      }).toList();

      if (openRestaurants.isEmpty) return <RestaurantModel>[];

      // b) Consultar reservaciones activas para esa fecha local
      final dateString = ScheduleUtils.formatDateLocal(dateTime);
      final reservationsSnap = await _firestore
          .collection('reservations')
          .where('fechaLocal', isEqualTo: dateString)
          .get();

      final activeReservations = reservationsSnap.docs
          .map((doc) => ReservationModel.fromFirestore(doc))
          .where((res) => res.bloqueaMesas)
          .toList();

      final reservationsByRest = <String, List<ReservationModel>>{};
      for (final res in activeReservations) {
        reservationsByRest.putIfAbsent(res.restauranteId, () => []).add(res);
      }

      // c) Evaluar capacidad restante en ese horario específico
      final matchingRestaurants = <RestaurantModel>[];
      for (final rest in openRestaurants) {
        final restReservations = reservationsByRest[rest.id] ?? [];
        int occupiedSeats = 0;
        for (final res in restReservations) {
          if (res.overlapsWith(dateTime, durationMin: durationMin)) {
            occupiedSeats += res.personas;
          }
        }

        final remainingSeats = rest.capacidadTotal - occupiedSeats;
        if (remainingSeats >= partySize) {
          matchingRestaurants.add(rest);
        }
      }

      return matchingRestaurants;
    } catch (e) {
      if (e is ControlledRestaurantQueryException) rethrow;
      throw ControlledRestaurantQueryException(
        'Error controlado al consultar restaurantes por capacidad: $e',
        originalError: e,
      );
    }
  }

  /// HU04-RF01: Consulta segura por capacidad retornando RestaurantQueryResult
  @override
  Future<RestaurantQueryResult> getRestaurantsByCapacityResult({
    required int partySize,
    DateTime? dateTime,
    int durationMin = 90,
  }) async {
    try {
      final list = await getRestaurantsByCapacity(
        partySize: partySize,
        dateTime: dateTime,
        durationMin: durationMin,
      );
      return RestaurantQueryResult.success(list);
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
    } catch (e) {
      return RestaurantQueryResult.failure(
        'Error inesperado al consultar restaurantes por capacidad: $e',
      );
    }
  }

  /// HU04-RF01: Stream reactivo de consulta por capacidad
  @override
  Stream<List<RestaurantModel>> getRestaurantsByCapacityStream({
    required int partySize,
    DateTime? dateTime,
    int durationMin = 90,
  }) {
    return getActiveRestaurantsStream().asyncMap((activeList) async {
      try {
        if (partySize <= 0) return <RestaurantModel>[];

        final withCapacity = activeList
            .where((restaurant) => restaurant.tieneCapacidadRegistrada)
            .toList();

        if (withCapacity.isEmpty) return <RestaurantModel>[];

        if (dateTime == null) {
          return withCapacity
              .where((restaurant) => restaurant.capacidadTotal >= partySize)
              .toList();
        }

        final openRestaurants = withCapacity.where((restaurant) {
          return ScheduleUtils.isRestaurantOpenAt(
            restaurant: restaurant,
            dateTime: dateTime,
          );
        }).toList();

        if (openRestaurants.isEmpty) return <RestaurantModel>[];

        final dateString = ScheduleUtils.formatDateLocal(dateTime);
        final reservationsSnap = await _firestore
            .collection('reservations')
            .where('fechaLocal', isEqualTo: dateString)
            .get();

        final activeReservations = reservationsSnap.docs
            .map((doc) => ReservationModel.fromFirestore(doc))
            .where((res) => res.bloqueaMesas)
            .toList();

        final reservationsByRest = <String, List<ReservationModel>>{};
        for (final res in activeReservations) {
          reservationsByRest.putIfAbsent(res.restauranteId, () => []).add(res);
        }

        final matchingRestaurants = <RestaurantModel>[];
        for (final rest in openRestaurants) {
          final restReservations = reservationsByRest[rest.id] ?? [];
          int occupiedSeats = 0;
          for (final res in restReservations) {
            if (res.overlapsWith(dateTime, durationMin: durationMin)) {
              occupiedSeats += res.personas;
            }
          }

          final remainingSeats = rest.capacidadTotal - occupiedSeats;
          if (remainingSeats >= partySize) {
            matchingRestaurants.add(rest);
          }
        }

        return matchingRestaurants;
      } catch (_) {
        return <RestaurantModel>[];
      }
    }).handleError((_) {
      return <RestaurantModel>[];
    });
  }

  /// Stream de todos los restaurantes (para dashboard de administrador)
  Stream<List<RestaurantModel>> getRestaurantsStream() {
    return _firestore.collection('restaurants').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RestaurantModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// Consulta paginada de restaurantes activos para la interfaz pública (HU01-RF01 Criterios 2, 3, 5)
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('restaurants')
          .where('estado', isEqualTo: 'activo');

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      query = query.limit(limit + 1);

      final snapshot = await query.get();
      final docs = snapshot.docs;

      final bool hasMore = docs.length > limit;
      final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

      List<RestaurantModel> items = pageDocs.map((doc) {
        return RestaurantModel.fromFirestore(doc);
      }).toList();

      if (servicioId != null && servicioId.isNotEmpty) {
        items = items.where((r) => r.serviciosIds.contains(servicioId)).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final queryClean = searchQuery.trim().toLowerCase();
        items = items.where((r) {
          final nombreMatch = r.nombre.toLowerCase().contains(queryClean);
          final descMatch = r.descripcion.toLowerCase().contains(queryClean);
          final dirMatch = r.direccion.toLowerCase().contains(queryClean);
          return nombreMatch || descMatch || dirMatch;
        }).toList();
      }

      return PaginatedRestaurantsResult(
        restaurants: items,
        lastDocument: pageDocs.isNotEmpty ? pageDocs.last : null,
        hasMore: hasMore,
      );
    } catch (e) {
      // HU01-RF01 Criterio 5: Retorno con error controlado sin cerrar la app
      throw Exception('No fue posible consultar los restaurantes disponibles. Por favor, reintenta.');
    }
  }

  /// Guarda el perfil completo del restaurante junto con su sucursal principal y sucursales adicionales
  Future<void> saveFullRestaurantProfile({
    required String restaurantId,
    required RestaurantModel restaurant,
    required BranchModel mainBranch,
    required List<BranchModel> additionalBranches,
  }) async {
    final restaurantRef = _firestore.collection('restaurants').doc(restaurantId);

    // 1. Actualizar el documento del restaurante con respaldo de sucursales en la raíz
    final restaurantData = restaurant.toMap();
    restaurantData['perfilCompleto'] = true;
    restaurantData['estado'] = 'activo';
    restaurantData['sucursalPrincipal'] = {
      'nombre': mainBranch.nombre.isNotEmpty ? mainBranch.nombre : 'Sucursal Principal',
      'direccion': restaurant.direccion,
      'telefono': restaurant.telefono,
      'esPrincipal': true,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    restaurantData['sucursalesAdicionales'] =
        additionalBranches.map((b) => b.toMap()).toList();

    // Guardar el documento del restaurante primero
    await restaurantRef.set(restaurantData, SetOptions(merge: true));

    // 2. Guardar en la subcolección 'sucursales' (protegido ante falta de reglas en consola remota)
    try {
      final batch = _firestore.batch();
      final mainBranchRef = restaurantRef.collection('sucursales').doc('principal');
      batch.set(mainBranchRef, {
        'nombre': mainBranch.nombre.isNotEmpty ? mainBranch.nombre : 'Sucursal Principal',
        'direccion': restaurant.direccion,
        'telefono': restaurant.telefono,
        'esPrincipal': true,
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final branch in additionalBranches) {
        final branchRef = branch.id.isNotEmpty
            ? restaurantRef.collection('sucursales').doc(branch.id)
            : restaurantRef.collection('sucursales').doc();
        batch.set(branchRef, {
          'nombre': branch.nombre,
          'direccion': branch.direccion,
          'telefono': branch.telefono,
          'esPrincipal': false,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (_) {
      // Si la consola de Firebase aún no tiene desplegadas las reglas para la subcolección sucursales,
      // la información ya quedó guardada e íntegra en el documento principal del restaurante.
    }
  }

  /// Obtiene las sucursales de un restaurante de forma segura
  Future<List<BranchModel>> getBranches(String restaurantId) async {
    try {
      final snap = await _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('sucursales')
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => BranchModel.fromFirestore(d)).toList();
      }
    } catch (_) {}

    // Fallback: leer del documento raíz si la subcolección no tiene reglas aún en consola
    try {
      final doc =
          await _firestore.collection('restaurants').doc(restaurantId).get();
      final data = doc.data() ?? {};
      final list = <BranchModel>[];
      if (data['sucursalPrincipal'] is Map<String, dynamic>) {
        list.add(BranchModel.fromMap(
          'principal',
          data['sucursalPrincipal'] as Map<String, dynamic>,
        ));
      }
      if (data['sucursalesAdicionales'] is List) {
        for (final item in data['sucursalesAdicionales'] as List) {
          if (item is Map<String, dynamic>) {
            list.add(BranchModel.fromMap(
              item['id'] as String? ?? '',
              item,
            ));
          }
        }
      }
      if (list.isNotEmpty) return list;
    } catch (_) {}

    return [];
  }

  /// Stream en tiempo real de sucursales de un restaurante
  Stream<List<BranchModel>> getBranchesStream(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('sucursales')
        .snapshots()
        .map((snap) => snap.docs.map((d) => BranchModel.fromFirestore(d)).toList());
  }

  /// Agrega una sucursal adicional
  Future<String> addBranch(String restaurantId, BranchModel branch) async {
    final ref = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('sucursales')
        .doc();

    await ref.set({
      'nombre': branch.nombre,
      'direccion': branch.direccion,
      'telefono': branch.telefono,
      'esPrincipal': false,
      'creadoEn': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Actualiza una sucursal adicional
  Future<void> updateBranch(String restaurantId, BranchModel branch) async {
    if (branch.esPrincipal) {
      throw Exception('La sucursal principal no se puede editar directamente desde aquí.');
    }
    final ref = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('sucursales')
        .doc(branch.id);

    await ref.update({
      'nombre': branch.nombre,
      'direccion': branch.direccion,
      'telefono': branch.telefono,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina una sucursal adicional (la principal está protegida)
  Future<void> deleteBranch(String restaurantId, String branchId) async {
    if (branchId == 'principal') {
      throw Exception('No es posible eliminar la sucursal principal.');
    }
    await _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('sucursales')
        .doc(branchId)
        .delete();
  }

  /// Obtiene el catálogo predefinido de servicios (con fallback robusto en memoria)
  Future<List<ServiceCatalogModel>> getServicesCatalog() async {
    try {
      final snap = await _firestore.collection('serviciosCatalogo').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => ServiceCatalogModel.fromFirestore(d))
            .toList();
      }
    } catch (_) {
      // Si falla por permisos o colección inexistente en consola remota, usar catálogo base
    }

    return defaultServicesList.map((item) {
      return ServiceCatalogModel(
        id: item['id']!,
        nombre: item['nombre']!,
        icono: item['icono']!,
        activo: true,
      );
    }).toList();
  }
}
