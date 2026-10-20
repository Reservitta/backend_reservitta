import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/restaurant_repository.dart';

/// Implementación en memoria de RestaurantRepository para pruebas unitarias de HU03-RF01
class MemoryRestaurantRepository implements RestaurantRepository {
  final List<RestaurantModel> restaurants;
  final List<ReservationModel> reservations;
  final bool shouldFail;

  MemoryRestaurantRepository({
    required this.restaurants,
    this.reservations = const [],
    this.shouldFail = false,
  });

  @override
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit}) async {
    if (shouldFail) {
      throw const ControlledRestaurantQueryException('Error simulado en Firestore');
    }
    var list = restaurants.where((r) => r.isActivo).toList();
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
    } catch (e) {
      return RestaurantQueryResult.failure(e.toString());
    }
  }

  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsStream() async* {
    if (shouldFail) {
      yield <RestaurantModel>[];
      return;
    }
    yield restaurants.where((r) => r.isActivo).toList();
  }

  @override
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    if (shouldFail) return null;
    try {
      return restaurants.firstWhere((r) => r.id == restaurantId);
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
    if (shouldFail) {
      throw const ControlledRestaurantQueryException('Error simulado al consultar por fecha y hora');
    }
    if (partySize != null && partySize <= 0) {
      throw ArgumentError('El número de personas debe ser mayor a 0.');
    }
    if (durationMin <= 0) {
      throw ArgumentError('La duración debe ser mayor a 0 minutos.');
    }

    final active = await getActiveRestaurants();
    final openRestaurants = active.where((r) {
      return ScheduleUtils.isRestaurantOpenAt(restaurant: r, dateTime: dateTime);
    }).toList();

    final dateString = ScheduleUtils.formatDateLocal(dateTime);
    final dayReservations = reservations
        .where((res) => res.fechaLocal == dateString && res.isActiva)
        .toList();

    final byRest = <String, List<ReservationModel>>{};
    for (final res in dayReservations) {
      byRest.putIfAbsent(res.restauranteId, () => []).add(res);
    }

    final available = <RestaurantModel>[];
    final reqSeats = partySize ?? 1;

    for (final rest in openRestaurants) {
      final resList = byRest[rest.id] ?? [];
      int occupied = 0;
      for (final res in resList) {
        if (res.overlapsWith(dateTime, durationMin: durationMin)) {
          occupied += res.personas;
        }
      }
      final remaining = rest.capacidadMaxima - occupied;
      if (remaining >= reqSeats) {
        available.add(rest);
      }
    }
    return available;
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
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
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
      final open = list
          .where((r) => ScheduleUtils.isRestaurantOpenAt(
                restaurant: r,
                dateTime: dateTime,
              ))
          .toList();

      final dateString = ScheduleUtils.formatDateLocal(dateTime);
      final dayReservations = reservations
          .where((res) => res.fechaLocal == dateString && res.isActiva)
          .toList();

      final byRest = <String, List<ReservationModel>>{};
      for (final res in dayReservations) {
        byRest.putIfAbsent(res.restauranteId, () => []).add(res);
      }

      final result = <RestaurantModel>[];
      final reqSeats = partySize ?? 1;

      for (final rest in open) {
        final resList = byRest[rest.id] ?? [];
        int occupied = 0;
        for (final res in resList) {
          if (res.overlapsWith(dateTime, durationMin: durationMin)) {
            occupied += res.personas;
          }
        }
        final remaining = rest.capacidadMaxima - occupied;
        if (remaining >= reqSeats) {
          result.add(rest);
        }
      }
      return result;
    });
  }

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

  @override
  Future<int> getRemainingCapacity({
    required String restaurantId,
    required DateTime dateTime,
    int durationMin = 90,
  }) async {
    final r = await getRestaurantById(restaurantId);
    if (r == null || !r.isActivo) return 0;
    if (!ScheduleUtils.isRestaurantOpenAt(restaurant: r, dateTime: dateTime)) {
      return 0;
    }

    final dateString = ScheduleUtils.formatDateLocal(dateTime);
    final overlapping = reservations.where((res) =>
        res.restauranteId == restaurantId &&
        res.fechaLocal == dateString &&
        res.isActiva &&
        res.overlapsWith(dateTime, durationMin: durationMin));

    int occupied = 0;
    for (final res in overlapping) {
      occupied += res.personas;
    }
    final remaining = r.capacidadMaxima - occupied;
    return remaining > 0 ? remaining : 0;
  }
}

void main() {
  group('HU03-RF01: Consulta de restaurantes por fecha y hora', () {
    late RestaurantModel restAbiertoLunes;
    late RestaurantModel restAbiertoFinesDeSemana;
    late RestaurantModel restConCierreEspecial;
    late RestaurantModel restInactivo;
    late List<RestaurantModel> todosRestaurantes;

    setUp(() {
      // 2026-10-19 es Lunes
      // 2026-10-24 es Sábado

      restAbiertoLunes = const RestaurantModel(
        id: 'rest_lunes',
        nombre: 'Café de los Lunes',
        estado: 'activo',
        capacidadMaxima: 20,
        diasAbiertos: ['lunes', 'martes', 'miercoles'],
        horarios: {
          'lunes': DaySchedule(abierto: true, apertura: '12:00', cierre: '20:00'),
          'martes': DaySchedule(abierto: true, apertura: '12:00', cierre: '20:00'),
          'miercoles': DaySchedule(abierto: true, apertura: '12:00', cierre: '20:00'),
        },
      );

      restAbiertoFinesDeSemana = const RestaurantModel(
        id: 'rest_finde',
        nombre: 'Asador del Fin de Semana',
        estado: 'activo',
        capacidadMaxima: 30,
        diasAbiertos: ['viernes', 'sabado', 'domingo'],
        horarios: {
          'viernes': DaySchedule(abierto: true, apertura: '14:00', cierre: '23:00'),
          'sabado': DaySchedule(abierto: true, apertura: '13:00', cierre: '23:00'),
          'domingo': DaySchedule(abierto: true, apertura: '13:00', cierre: '21:00'),
        },
      );

      restConCierreEspecial = const RestaurantModel(
        id: 'rest_cierre',
        nombre: 'Restaurante con Cierre Especial',
        estado: 'activo',
        capacidadMaxima: 15,
        diasAbiertos: ['lunes', 'martes', 'miercoles', 'jueves', 'viernes'],
        horarios: {
          'lunes': DaySchedule(abierto: true, apertura: '10:00', cierre: '22:00'),
        },
        cierresEspeciales: ['2026-10-19'], // Cerrado el lunes 19
      );

      restInactivo = const RestaurantModel(
        id: 'rest_inactivo',
        nombre: 'Restaurante Inactivo',
        estado: 'inactivo',
        capacidadMaxima: 40,
        diasAbiertos: ['lunes'],
        horarios: {
          'lunes': DaySchedule(abierto: true, apertura: '10:00', cierre: '22:00'),
        },
      );

      todosRestaurantes = [
        restAbiertoLunes,
        restAbiertoFinesDeSemana,
        restConCierreEspecial,
        restInactivo,
      ];
    });

    test('Criterio 1: Cada restaurante tiene guardados sus días y horarios de atención', () {
      expect(restAbiertoLunes.diasAbiertos, contains('lunes'));
      expect(restAbiertoLunes.horarios['lunes']?.abierto, isTrue);
      expect(restAbiertoLunes.horarios['lunes']?.apertura, '12:00');
      expect(restAbiertoLunes.horarios['lunes']?.cierre, '20:00');
      expect(restAbiertoLunes.capacidadMaxima, 20);
    });

    test('Criterio 2: Dada una fecha y hora, devuelve solo restaurantes abiertos en ese momento', () async {
      final repo = MemoryRestaurantRepository(restaurants: todosRestaurantes);

      // Consulta Lunes 2026-10-19 a las 14:00 (restAbiertoLunes está abierto; restAbiertoFinesDeSemana está cerrado)
      final fechaLunes = DateTime(2026, 10, 19, 14, 0);
      final resultados = await repo.getRestaurantsByDateTime(dateTime: fechaLunes);

      final ids = resultados.map((r) => r.id).toList();
      expect(ids, contains('rest_lunes'));
      expect(ids, isNot(contains('rest_finde')));
      expect(ids, isNot(contains('rest_inactivo'))); // Los inactivos nunca aparecen
    });

    test('Criterio 2: Consulta fuera del horario de atención devuelve lista vacía o excluye el restaurante', () async {
      final repo = MemoryRestaurantRepository(restaurants: todosRestaurantes);

      // Consulta Lunes 2026-10-19 a las 21:00 (restAbiertoLunes cierra a las 20:00)
      final fechaTarde = DateTime(2026, 10, 19, 21, 0);
      final resultados = await repo.getRestaurantsByDateTime(dateTime: fechaTarde);

      expect(resultados, isEmpty);
    });

    test('Criterio 4: La consulta respeta los días de cierre especial', () async {
      final repo = MemoryRestaurantRepository(restaurants: todosRestaurantes);

      // restConCierreEspecial tiene cierre el 2026-10-19
      final fechaCierre = DateTime(2026, 10, 19, 14, 0);
      final resultados = await repo.getRestaurantsByDateTime(dateTime: fechaCierre);

      final ids = resultados.map((r) => r.id).toList();
      expect(ids, isNot(contains('rest_cierre')));
    });

    test('Criterio 3: Se excluyen los restaurantes sin lugares disponibles considerando reservaciones existentes', () async {
      // restAbiertoLunes tiene capacidadMaxima: 20
      // Creamos una reservación de 20 personas en ese horario que llena por completo el restaurante
      final reservacionLlena = ReservationModel(
        id: 'res_lleno',
        restauranteId: 'rest_lunes',
        fechaLocal: '2026-10-19',
        inicio: DateTime(2026, 10, 19, 14, 0),
        fin: DateTime(2026, 10, 19, 15, 30),
        duracionMin: 90,
        personas: 20, // Llena la capacidad total de 20
        estado: 'confirmada',
      );

      final repo = MemoryRestaurantRepository(
        restaurants: todosRestaurantes,
        reservations: [reservacionLlena],
      );

      // Consulta para las 14:00 (horario ocupado al 100%)
      final resultados = await repo.getRestaurantsByDateTime(
        dateTime: DateTime(2026, 10, 19, 14, 0),
        partySize: 2,
      );

      // Debe quedar excluido porque no hay lugares disponibles
      final ids = resultados.map((r) => r.id).toList();
      expect(ids, isNot(contains('rest_lunes')));
    });

    test('Criterio 3: Se incluye si hay lugares suficientes para el número de personas (partySize)', () async {
      // Capacidad 20, reservación existente de 14 personas -> quedan 6 lugares
      final reservacionParcial = ReservationModel(
        id: 'res_parcial',
        restauranteId: 'rest_lunes',
        fechaLocal: '2026-10-19',
        inicio: DateTime(2026, 10, 19, 14, 0),
        fin: DateTime(2026, 10, 19, 15, 30),
        duracionMin: 90,
        personas: 14,
        estado: 'confirmada',
      );

      final repo = MemoryRestaurantRepository(
        restaurants: todosRestaurantes,
        reservations: [reservacionParcial],
      );

      // Grupo de 4 personas: caben (quedan 6)
      final resultadoCaben = await repo.getRestaurantsByDateTime(
        dateTime: DateTime(2026, 10, 19, 14, 0),
        partySize: 4,
      );
      expect(resultadoCaben.map((r) => r.id), contains('rest_lunes'));

      // Grupo de 8 personas: no caben (quedan solo 6) -> se excluye
      final resultadoNoCaben = await repo.getRestaurantsByDateTime(
        dateTime: DateTime(2026, 10, 19, 14, 0),
        partySize: 8,
      );
      expect(resultadoNoCaben.map((r) => r.id), isNot(contains('rest_lunes')));
    });

    test('Criterio 3: Reservaciones canceladas o en horarios distintos no consumen disponibilidad', () async {
      final reservacionCancelada = ReservationModel(
        id: 'res_cancel',
        restauranteId: 'rest_lunes',
        fechaLocal: '2026-10-19',
        inicio: DateTime(2026, 10, 19, 14, 0),
        fin: DateTime(2026, 10, 19, 15, 30),
        personas: 20,
        estado: 'cancelada', // Cancelada
      );

      final reservacionOtroHorario = ReservationModel(
        id: 'res_otro_horario',
        restauranteId: 'rest_lunes',
        fechaLocal: '2026-10-19',
        inicio: DateTime(2026, 10, 19, 18, 0), // A las 18:00, no a las 14:00
        fin: DateTime(2026, 10, 19, 19, 30),
        personas: 20,
        estado: 'confirmada',
      );

      final repo = MemoryRestaurantRepository(
        restaurants: todosRestaurantes,
        reservations: [reservacionCancelada, reservacionOtroHorario],
      );

      // Consulta a las 14:00
      final resultados = await repo.getRestaurantsByDateTime(
        dateTime: DateTime(2026, 10, 19, 14, 0),
        partySize: 10,
      );

      expect(resultados.map((r) => r.id), contains('rest_lunes'));
    });

    test('getRemainingCapacity calcula con precisión los asientos disponibles restantes', () async {
      final res = ReservationModel(
        id: 'res1',
        restauranteId: 'rest_lunes',
        fechaLocal: '2026-10-19',
        inicio: DateTime(2026, 10, 19, 14, 0),
        fin: DateTime(2026, 10, 19, 15, 30),
        personas: 7,
        estado: 'confirmada',
      );

      final repo = MemoryRestaurantRepository(
        restaurants: todosRestaurantes,
        reservations: [res],
      );

      // Capacidad máxima 20 - 7 ocupados = 13 restantes
      final remaining = await repo.getRemainingCapacity(
        restaurantId: 'rest_lunes',
        dateTime: DateTime(2026, 10, 19, 14, 15),
      );
      expect(remaining, 13);

      // Si el restaurante está cerrado, la capacidad restante es 0
      final remainingCerrado = await repo.getRemainingCapacity(
        restaurantId: 'rest_lunes',
        dateTime: DateTime(2026, 10, 19, 22, 0),
      );
      expect(remainingCerrado, 0);
    });

    test('getRestaurantsByDateTimeResult devuelve resultado seguro ante éxito y error controlado', () async {
      final repoExito = MemoryRestaurantRepository(restaurants: todosRestaurantes);
      final resOk = await repoExito.getRestaurantsByDateTimeResult(
        dateTime: DateTime(2026, 10, 19, 14, 0),
      );
      expect(resOk.hasError, isFalse);
      expect(resOk.restaurants, isNotEmpty);

      final repoFallo = MemoryRestaurantRepository(
        restaurants: todosRestaurantes,
        shouldFail: true,
      );
      final resFallo = await repoFallo.getRestaurantsByDateTimeResult(
        dateTime: DateTime(2026, 10, 19, 14, 0),
      );
      expect(resFallo.hasError, isTrue);
      expect(resFallo.errorMessage, contains('Error simulado'));
    });

    test('getRestaurantsByDateTimeStream emite restaurantes disponibles en tiempo real', () async {
      final repo = MemoryRestaurantRepository(restaurants: todosRestaurantes);
      final stream = repo.getRestaurantsByDateTimeStream(
        dateTime: DateTime(2026, 10, 19, 14, 0),
      );

      final emitted = await stream.first;
      expect(emitted.map((r) => r.id), contains('rest_lunes'));
      expect(emitted.map((r) => r.id), isNot(contains('rest_finde')));
    });

    test('Polimorfismo: RestaurantService implementa RestaurantRepository con los métodos de HU03-RF01', () {
      final service = RestaurantService();
      expect(service, isA<RestaurantRepository>());
    });
  });
}
