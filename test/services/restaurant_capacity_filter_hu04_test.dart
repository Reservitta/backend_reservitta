import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/restaurant_repository.dart';

/// Implementación en memoria de RestaurantRepository para pruebas unitarias de HU04-RF01
class FakeCapacityRestaurantRepository extends Fake implements RestaurantRepository {
  final List<RestaurantModel> restaurants;
  final List<ReservationModel> reservations;
  final bool shouldFail;

  FakeCapacityRestaurantRepository({
    required this.restaurants,
    this.reservations = const [],
    this.shouldFail = false,
  });

  @override
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit}) async {
    if (shouldFail) {
      throw const ControlledRestaurantQueryException(
        'Error simulado de red al consultar restaurantes activos.',
      );
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
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
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
    return getActiveRestaurants();
  }

  @override
  Future<RestaurantQueryResult> getActiveRestaurantsByRadiusResult({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    return RestaurantQueryResult.success(await getActiveRestaurants());
  }

  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsByRadiusStream({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async* {
    yield await getActiveRestaurants();
  }

  @override
  Future<List<RestaurantWithDistance>> getRestaurantsWithDistanceByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    return [];
  }

  @override
  Future<List<RestaurantModel>> getRestaurantsByDateTime({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  }) async {
    return getRestaurantsByCapacity(
      partySize: partySize ?? 1,
      dateTime: dateTime,
      durationMin: durationMin,
    );
  }

  @override
  Future<RestaurantQueryResult> getRestaurantsByDateTimeResult({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  }) async {
    return getRestaurantsByCapacityResult(
      partySize: partySize ?? 1,
      dateTime: dateTime,
      durationMin: durationMin,
    );
  }

  @override
  Stream<List<RestaurantModel>> getRestaurantsByDateTimeStream({
    required DateTime dateTime,
    int? partySize,
    int durationMin = 90,
  }) {
    return getRestaurantsByCapacityStream(
      partySize: partySize ?? 1,
      dateTime: dateTime,
      durationMin: durationMin,
    );
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
    if (!r.tieneCapacidadRegistrada) return 0;
    if (!ScheduleUtils.isRestaurantOpenAt(restaurant: r, dateTime: dateTime)) {
      return 0;
    }

    final dateString = ScheduleUtils.formatDateLocal(dateTime);
    final overlapping = reservations.where((res) =>
        res.restauranteId == restaurantId &&
        res.fechaLocal == dateString &&
        res.bloqueaMesas &&
        res.overlapsWith(dateTime, durationMin: durationMin));

    int occupied = 0;
    for (final res in overlapping) {
      occupied += res.personas;
    }

    final remaining = r.capacidadTotal - occupied;
    return remaining > 0 ? remaining : 0;
  }

  @override
  Future<List<RestaurantModel>> getRestaurantsByCapacity({
    required int partySize,
    DateTime? dateTime,
    int durationMin = 90,
  }) async {
    if (shouldFail) {
      throw const ControlledRestaurantQueryException(
        'Error simulado de red en Firestore al consultar restaurantes por capacidad.',
      );
    }
    if (partySize <= 0) return <RestaurantModel>[];

    // Criterio 4: Excluir restaurantes sin capacidad registrada
    final withCapacity =
        restaurants.where((r) => r.isActivo && r.tieneCapacidadRegistrada).toList();
    if (withCapacity.isEmpty) return <RestaurantModel>[];

    // Caso 1: Sin fecha/hora seleccionadas (Criterio 2)
    if (dateTime == null) {
      return withCapacity.where((r) => r.capacidadTotal >= partySize).toList();
    }

    // Caso 2: Con fecha/hora seleccionadas (Criterio 3)
    final open = withCapacity
        .where((r) => ScheduleUtils.isRestaurantOpenAt(restaurant: r, dateTime: dateTime))
        .toList();

    final dateString = ScheduleUtils.formatDateLocal(dateTime);
    final matching = <RestaurantModel>[];

    for (final rest in open) {
      final overlapping = reservations.where((res) =>
          res.restauranteId == rest.id &&
          res.fechaLocal == dateString &&
          res.bloqueaMesas &&
          res.overlapsWith(dateTime, durationMin: durationMin));

      int occupied = 0;
      for (final res in overlapping) {
        occupied += res.personas;
      }

      final remaining = rest.capacidadTotal - occupied;
      if (remaining >= partySize) {
        matching.add(rest);
      }
    }

    return matching;
  }

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
      return RestaurantQueryResult.failure('Error inesperado: $e');
    }
  }

  @override
  Stream<List<RestaurantModel>> getRestaurantsByCapacityStream({
    required int partySize,
    DateTime? dateTime,
    int durationMin = 90,
  }) async* {
    if (shouldFail) {
      yield <RestaurantModel>[];
      return;
    }
    yield await getRestaurantsByCapacity(
      partySize: partySize,
      dateTime: dateTime,
      durationMin: durationMin,
    );
  }
}

void main() {
  group('HU04-RF01: Consulta por capacidad', () {
    const horarioEstandar = DaySchedule(abierto: true, apertura: '12:00', cierre: '23:00');
    final horariosCompletos = {
      'lunes': horarioEstandar,
      'martes': horarioEstandar,
      'miercoles': horarioEstandar,
      'jueves': horarioEstandar,
      'viernes': horarioEstandar,
      'sabado': horarioEstandar,
      'domingo': horarioEstandar,
    };

    // Restaurante 1: Capacidad máxima explícita de 20
    final restCapacidad20 = RestaurantModel(
      id: 'rest_20',
      nombre: 'Bistró Pequeño',
      estado: 'activo',
      capacidadMaxima: 20,
      horarios: horariosCompletos,
    );

    // Restaurante 2: Capacidad máxima explícita de 80
    final restCapacidad80 = RestaurantModel(
      id: 'rest_80',
      nombre: 'Gran Salón',
      estado: 'activo',
      capacidadMaxima: 80,
      horarios: horariosCompletos,
    );

    // Restaurante 3: Capacidad mediante registro de mesas (2 mesas de 4 + 1 mesa de 6 = 14)
    final restConMesas14 = RestaurantModel(
      id: 'rest_mesas_14',
      nombre: 'Trattoria con Mesas',
      estado: 'activo',
      horarios: horariosCompletos,
      mesas: const [
        MesaModel(id: 'm1', nombre: 'Mesa 1', capacidad: 4),
        MesaModel(id: 'm2', nombre: 'Mesa 2', capacidad: 4),
        MesaModel(id: 'm3', nombre: 'Mesa 3', capacidad: 6),
      ],
    );

    // Restaurante 4: Sin capacidad registrada (capacidadMaxima null y sin mesas)
    final restSinCapacidad = RestaurantModel(
      id: 'rest_sin_cap',
      nombre: 'Restaurante Incompleto',
      estado: 'activo',
      horarios: horariosCompletos,
    );

    // Restaurante 5: Inactivo (con capacidad registrada)
    final restInactivo = RestaurantModel(
      id: 'rest_inactivo',
      nombre: 'Restaurante Cerrado Definitivo',
      estado: 'inactivo',
      capacidadMaxima: 50,
      horarios: horariosCompletos,
    );

    final todosRestaurantes = [
      restCapacidad20,
      restCapacidad80,
      restConMesas14,
      restSinCapacidad,
      restInactivo,
    ];

    test('Criterio 1: Cada restaurante registra capacidad máxima o mediante mesas', () {
      expect(restCapacidad20.capacidadTotal, 20);
      expect(restCapacidad20.tieneCapacidadRegistrada, isTrue);

      expect(restCapacidad80.capacidadTotal, 80);
      expect(restCapacidad80.tieneCapacidadRegistrada, isTrue);

      expect(restConMesas14.capacidadTotal, 14);
      expect(restConMesas14.mesas.length, 3);
      expect(restConMesas14.tieneCapacidadRegistrada, isTrue);

      expect(restSinCapacidad.capacidadTotal, 0);
      expect(restSinCapacidad.tieneCapacidadRegistrada, isFalse);
    });

    test('Criterio 2: Dada una cantidad de personas, se devuelven solo restaurantes que pueden atender a ese grupo (sin fecha)', () async {
      final repo = FakeCapacityRestaurantRepository(restaurants: todosRestaurantes);

      // Consulta para 10 personas:
      // - rest_20 (cap 20): SÍ
      // - rest_80 (cap 80): SÍ
      // - rest_mesas_14 (cap 14): SÍ
      // - rest_sin_cap: NO (sin capacidad)
      // - rest_inactivo: NO (inactivo)
      final resultado10 = await repo.getRestaurantsByCapacity(partySize: 10);
      final ids10 = resultado10.map((r) => r.id).toList();
      expect(ids10, containsAll(['rest_20', 'rest_80', 'rest_mesas_14']));
      expect(ids10, isNot(contains('rest_sin_cap')));
      expect(ids10, isNot(contains('rest_inactivo')));

      // Consulta para 18 personas:
      // - rest_20 (cap 20): SÍ
      // - rest_80 (cap 80): SÍ
      // - rest_mesas_14 (cap 14 < 18): NO
      final resultado18 = await repo.getRestaurantsByCapacity(partySize: 18);
      final ids18 = resultado18.map((r) => r.id).toList();
      expect(ids18, containsAll(['rest_20', 'rest_80']));
      expect(ids18, isNot(contains('rest_mesas_14')));

      // Consulta para 50 personas:
      // - Solo rest_80 (cap 80 >= 50)
      final resultado50 = await repo.getRestaurantsByCapacity(partySize: 50);
      final ids50 = resultado50.map((r) => r.id).toList();
      expect(ids50, equals(['rest_80']));

      // Consulta para 100 personas: Ninguno puede atender
      final resultado100 = await repo.getRestaurantsByCapacity(partySize: 100);
      expect(resultado100, isEmpty);
    });

    test('Criterio 3: Si hay fecha y hora seleccionadas, se considera la capacidad restante en ese horario', () async {
      final fechaPrueba = '2026-10-20';
      final horaObjetivo = DateTime(2026, 10, 20, 14, 0);

      // En rest_20 (cap 20): reservación confirmada de 15 personas de 13:30 a 15:00
      final resRest20 = ReservationModel(
        id: 'res_1',
        restauranteId: 'rest_20',
        fechaLocal: fechaPrueba,
        inicio: DateTime(2026, 10, 20, 13, 30),
        fin: DateTime(2026, 10, 20, 15, 0),
        personas: 15,
        estado: 'confirmada',
      );

      // En rest_80 (cap 80): reservación confirmada de 75 personas de 13:30 a 15:00 (quedan 5 lugares)
      final resRest80 = ReservationModel(
        id: 'res_2',
        restauranteId: 'rest_80',
        fechaLocal: fechaPrueba,
        inicio: DateTime(2026, 10, 20, 13, 30),
        fin: DateTime(2026, 10, 20, 15, 0),
        personas: 75,
        estado: 'confirmada',
      );

      // En rest_mesas_14 (cap 14): reservación cancelada de 10 personas (NO debe restar capacidad)
      final resCancelada = ReservationModel(
        id: 'res_3',
        restauranteId: 'rest_mesas_14',
        fechaLocal: fechaPrueba,
        inicio: DateTime(2026, 10, 20, 13, 30),
        fin: DateTime(2026, 10, 20, 15, 0),
        personas: 10,
        estado: 'cancelada',
      );

      final repo = FakeCapacityRestaurantRepository(
        restaurants: todosRestaurantes,
        reservations: [resRest20, resRest80, resCancelada],
      );

      // Caso A: Consulta para 4 personas a las 14:00
      // - rest_20 tiene 20 - 15 = 5 restantes -> SÍ (5 >= 4)
      // - rest_80 tiene 80 - 75 = 5 restantes -> SÍ (5 >= 4)
      // - rest_mesas_14 tiene 14 - 0 = 14 restantes (reserva cancelada) -> SÍ (14 >= 4)
      final resultado4 = await repo.getRestaurantsByCapacity(
        partySize: 4,
        dateTime: horaObjetivo,
      );
      final ids4 = resultado4.map((r) => r.id).toList();
      expect(ids4, containsAll(['rest_20', 'rest_80', 'rest_mesas_14']));

      // Caso B: Consulta para 6 personas a las 14:00
      // - rest_20 tiene 5 restantes -> NO (5 < 6)
      // - rest_80 tiene 5 restantes -> NO (5 < 6)
      // - rest_mesas_14 tiene 14 restantes -> SÍ (14 >= 6)
      final resultado6 = await repo.getRestaurantsByCapacity(
        partySize: 6,
        dateTime: horaObjetivo,
      );
      final ids6 = resultado6.map((r) => r.id).toList();
      expect(ids6, equals(['rest_mesas_14']));

      // Caso C: En un horario no traslapado (18:00), la capacidad de rest_20 está libre al 100% (20 lugares)
      final horaLibre = DateTime(2026, 10, 20, 18, 0);
      final resultado18HoraLibre = await repo.getRestaurantsByCapacity(
        partySize: 18,
        dateTime: horaLibre,
      );
      final idsLibre = resultado18HoraLibre.map((r) => r.id).toList();
      expect(idsLibre, contains('rest_20'));
    });

    test('Criterio 4: Un restaurante sin capacidad registrada no aparece en este filtro', () async {
      final repo = FakeCapacityRestaurantRepository(restaurants: todosRestaurantes);

      // 1. Consulta sin fecha ni hora para 1 persona
      final resultadoSinFecha = await repo.getRestaurantsByCapacity(partySize: 1);
      final idsSinFecha = resultadoSinFecha.map((r) => r.id).toList();
      expect(idsSinFecha, isNot(contains('rest_sin_cap')));

      // 2. Consulta con fecha y hora para 1 persona
      final resultadoConFecha = await repo.getRestaurantsByCapacity(
        partySize: 1,
        dateTime: DateTime(2026, 10, 20, 14, 0),
      );
      final idsConFecha = resultadoConFecha.map((r) => r.id).toList();
      expect(idsConFecha, isNot(contains('rest_sin_cap')));

      // 3. getRemainingCapacity retorna 0 para restaurantes sin capacidad registrada
      final remaining = await repo.getRemainingCapacity(
        restaurantId: 'rest_sin_cap',
        dateTime: DateTime(2026, 10, 20, 14, 0),
      );
      expect(remaining, 0);

      // 4. checkRestaurantAvailability retorna false
      final disponible = await repo.checkRestaurantAvailability(
        restaurantId: 'rest_sin_cap',
        dateTime: DateTime(2026, 10, 20, 14, 0),
        partySize: 1,
      );
      expect(disponible, isFalse);
    });

    test('Stream reactivo y Result seguro manejan casos exitosos y fallos controlados', () async {
      final repoExitoso = FakeCapacityRestaurantRepository(restaurants: todosRestaurantes);
      final resultSeguro = await repoExitoso.getRestaurantsByCapacityResult(partySize: 15);
      expect(resultSeguro.hasError, isFalse);
      expect(resultSeguro.restaurants.length, 2); // rest_20 y rest_80

      final repoFallo = FakeCapacityRestaurantRepository(
        restaurants: todosRestaurantes,
        shouldFail: true,
      );
      final resultFallo = await repoFallo.getRestaurantsByCapacityResult(partySize: 15);
      expect(resultFallo.hasError, isTrue);
      expect(resultFallo.errorMessage, contains('Error simulado'));

      final streamFallo = repoFallo.getRestaurantsByCapacityStream(partySize: 15);
      expect(await streamFallo.first, isEmpty);
    });
  });
}
