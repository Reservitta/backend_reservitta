import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';

/// Implementación Fake en memoria de ReservationRepository para pruebas unitarias de HU08-RF02
class FakeReservationRepository implements ReservationRepository {
  final List<ReservationModel> reservacionesEnMemoria;

  FakeReservationRepository({
    List<ReservationModel>? initialReservations,
  }) : reservacionesEnMemoria = initialReservations != null
            ? List.from(initialReservations)
            : [];

  @override
  Future<ReservationModel> createReservation(ReservationModel reservation) async {
    final estadoNormalizado = reservation.estado.trim().toLowerCase();
    if (!ReservationModel.isValidStatus(estadoNormalizado)) {
      throw ArgumentError(
        'Estado inválido: "${reservation.estado}". '
        'Estados permitidos: ${ReservationModel.estadosValidos.join(", ")}',
      );
    }

    // Criterio 2: La hora de fin se calcula como hora de inicio + duración
    final effectiveFin = reservation.fin ??
        (reservation.inicio != null
            ? ReservationModel.calculateEndTime(
                inicio: reservation.inicio!,
                duracionMin: reservation.duracionMin,
              )
            : null);

    final generatedId = reservation.id.isNotEmpty
        ? reservation.id
        : 'res_${DateTime.now().microsecondsSinceEpoch}';

    final toSave = reservation.copyWith(
      id: generatedId,
      estado: estadoNormalizado,
      fin: effectiveFin,
    );

    reservacionesEnMemoria.removeWhere((r) => r.id == toSave.id);
    reservacionesEnMemoria.add(toSave);
    return toSave;
  }

  @override
  Future<ReservationModel> createReservationVerified(
    ReservationModel reservation, {
    int margenLimpiezaMin = 0,
  }) async {
    final ocupadas = reservacionesEnMemoria
        .where((r) =>
            r.restauranteId == reservation.restauranteId &&
            r.overlapsWith(reservation.effectiveStart,
                durationMin: reservation.duracionMin))
        .expand((r) => r.mesaIds)
        .toSet()
        .intersection(reservation.mesaIds.toSet());
    if (ocupadas.isNotEmpty) throw ReservationConflictException(ocupadas);
    return createReservation(reservation);
  }

  @override
  Future<List<ReservationModel>> getReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async {
    // Criterio 4: Consulta por restaurante y fecha soportada por índice compuesto
    return reservacionesEnMemoria
        .where((r) => r.restauranteId == restauranteId && r.fechaLocal == fechaLocal)
        .toList();
  }

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async {
    // Criterio 3: Solo las reservaciones con estado activo (pendiente/confirmada) bloquean mesas
    final all = await getReservationsByRestaurantAndDate(
      restauranteId: restauranteId,
      fechaLocal: fechaLocal,
    );
    return all.where((r) => r.bloqueaMesas).toList();
  }

  @override
  Future<ReservationModel?> getReservationById(String reservationId) async {
    try {
      return reservacionesEnMemoria.firstWhere((r) => r.id == reservationId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateReservationStatus({
    required String reservationId,
    required String nuevoEstado,
  }) async {
    final estadoNormalizado = nuevoEstado.trim().toLowerCase();
    if (!ReservationModel.isValidStatus(estadoNormalizado)) {
      throw ArgumentError(
        'Estado inválido: "$nuevoEstado". '
        'Estados permitidos: ${ReservationModel.estadosValidos.join(", ")}',
      );
    }

    final index = reservacionesEnMemoria.indexWhere((r) => r.id == reservationId);
    if (index != -1) {
      final current = reservacionesEnMemoria[index];
      reservacionesEnMemoria[index] = current.copyWith(estado: estadoNormalizado);
    }
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    // Criterio 3: Al cancelar, deja de bloquear mesas
    await updateReservationStatus(
      reservationId: reservationId,
      nuevoEstado: ReservationModel.estadoCancelada,
    );
  }

  @override
  Future<bool> isTableAvailable({
    required String restauranteId,
    required String mesaId,
    required DateTime targetDateTime,
    int durationMin = 90,
  }) async {
    final dateString =
        '${targetDateTime.year.toString().padLeft(4, '0')}-${targetDateTime.month.toString().padLeft(2, '0')}-${targetDateTime.day.toString().padLeft(2, '0')}';

    final activeRes = await getActiveReservationsByRestaurantAndDate(
      restauranteId: restauranteId,
      fechaLocal: dateString,
    );

    return !activeRes.any(
      (r) => r.isTableBlocked(
        mesaId,
        targetDateTime: targetDateTime,
        durationMin: durationMin,
      ),
    );
  }

  @override
  Future<Set<String>> getBlockedTableIds({
    required String restauranteId,
    required DateTime targetDateTime,
    int durationMin = 90,
  }) async {
    final dateString =
        '${targetDateTime.year.toString().padLeft(4, '0')}-${targetDateTime.month.toString().padLeft(2, '0')}-${targetDateTime.day.toString().padLeft(2, '0')}';

    final activeRes = await getActiveReservationsByRestaurantAndDate(
      restauranteId: restauranteId,
      fechaLocal: dateString,
    );

    final blocked = <String>{};
    for (final res in activeRes) {
      if (res.overlapsWith(targetDateTime, durationMin: durationMin)) {
        blocked.addAll(res.mesaIds);
      }
    }
    return blocked;
  }

  @override
  Stream<List<ReservationModel>> getReservationsStream({
    required String restauranteId,
    required String fechaLocal,
  }) async* {
    yield await getReservationsByRestaurantAndDate(
      restauranteId: restauranteId,
      fechaLocal: fechaLocal,
    );
  }
}

void main() {
  group('HU08-RF02 ReservationRepository & Service Tests', () {
    late FakeReservationRepository repository;

    setUp(() {
      repository = FakeReservationRepository();
    });

    test('Criterio 1 y 2: createReservation persiste con fin calculado y valida estado', () async {
      final inicio = DateTime(2026, 10, 20, 20, 0);

      // Reserva sin hora de fin explícita y duración de 120 minutos
      final nueva = ReservationModel(
        id: '',
        restauranteId: 'rest_mariscos',
        fechaLocal: '2026-10-20',
        inicio: inicio,
        duracionMin: 120,
        personas: 6,
        mesaIds: ['mesa_vip_1'],
        estado: 'pendiente',
      );

      final guardada = await repository.createReservation(nueva);

      expect(guardada.id, isNotEmpty);
      expect(guardada.restauranteId, 'rest_mariscos');
      expect(guardada.personas, 6);
      expect(guardada.cantidadPersonas, 6);
      expect(guardada.estado, 'pendiente');
      // Fin calculado automáticamente: 20:00 + 120 min = 22:00
      expect(guardada.fin, DateTime(2026, 10, 20, 22, 0));
    });

    test('Criterio 1: Rechaza estados inválidos al crear o actualizar', () async {
      final invalidRes = const ReservationModel(
        id: 'res_inv',
        restauranteId: 'rest_01',
        fechaLocal: '2026-10-20',
        estado: 'desconocido_inventado',
      );

      expect(
        () => repository.createReservation(invalidRes),
        throwsA(isA<ArgumentError>()),
      );

      final validRes = const ReservationModel(
        id: 'res_val',
        restauranteId: 'rest_01',
        fechaLocal: '2026-10-20',
        estado: 'pendiente',
      );
      await repository.createReservation(validRes);

      expect(
        () => repository.updateReservationStatus(
          reservationId: 'res_val',
          nuevoEstado: 'estado_falso',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Criterio 3: Solo reservaciones activas (pendiente/confirmada) bloquean mesas; canceladas liberan mesas', () async {
      final fecha = '2026-10-20';
      final inicio = DateTime(2026, 10, 20, 14, 0);
      final fin = DateTime(2026, 10, 20, 15, 30);

      // Creamos una reservación pendiente en mesa_1
      final resPendiente = await repository.createReservation(
        ReservationModel(
          id: 'res_p',
          restauranteId: 'rest_01',
          fechaLocal: fecha,
          inicio: inicio,
          fin: fin,
          mesaIds: ['mesa_1'],
          estado: 'pendiente',
        ),
      );

      // Creamos una reservación confirmada en mesa_2
      await repository.createReservation(
        ReservationModel(
          id: 'res_c',
          restauranteId: 'rest_01',
          fechaLocal: fecha,
          inicio: inicio,
          fin: fin,
          mesaIds: ['mesa_2'],
          estado: 'confirmada',
        ),
      );

      // Creamos una reservación cancelada en mesa_3
      await repository.createReservation(
        ReservationModel(
          id: 'res_canc',
          restauranteId: 'rest_01',
          fechaLocal: fecha,
          inicio: inicio,
          fin: fin,
          mesaIds: ['mesa_3'],
          estado: 'cancelada',
        ),
      );

      final horaConsulta = DateTime(2026, 10, 20, 14, 30);

      // 1. mesa_1 está bloqueada por la reservación 'pendiente'
      final mesa1Disponible = await repository.isTableAvailable(
        restauranteId: 'rest_01',
        mesaId: 'mesa_1',
        targetDateTime: horaConsulta,
      );
      expect(mesa1Disponible, isFalse);

      // 2. mesa_2 está bloqueada por la reservación 'confirmada'
      final mesa2Disponible = await repository.isTableAvailable(
        restauranteId: 'rest_01',
        mesaId: 'mesa_2',
        targetDateTime: horaConsulta,
      );
      expect(mesa2Disponible, isFalse);

      // 3. mesa_3 está DISPONIBLE porque la reservación está 'cancelada' (no bloquea)
      final mesa3Disponible = await repository.isTableAvailable(
        restauranteId: 'rest_01',
        mesaId: 'mesa_3',
        targetDateTime: horaConsulta,
      );
      expect(mesa3Disponible, isTrue);

      // 4. getBlockedTableIds contiene mesa_1 y mesa_2 pero NO mesa_3
      final bloqueadas = await repository.getBlockedTableIds(
        restauranteId: 'rest_01',
        targetDateTime: horaConsulta,
      );
      expect(bloqueadas, containsAll(['mesa_1', 'mesa_2']));
      expect(bloqueadas, isNot(contains('mesa_3')));

      // 5. Al cancelar la reservación pendiente 'res_p', mesa_1 se libera inmediatamente
      await repository.cancelReservation(resPendiente.id);
      final mesa1Liberada = await repository.isTableAvailable(
        restauranteId: 'rest_01',
        mesaId: 'mesa_1',
        targetDateTime: horaConsulta,
      );
      expect(mesa1Liberada, isTrue);

      final bloqueadasDespues = await repository.getBlockedTableIds(
        restauranteId: 'rest_01',
        targetDateTime: horaConsulta,
      );
      expect(bloqueadasDespues, contains('mesa_2'));
      expect(bloqueadasDespues, isNot(contains('mesa_1')));
    });

    test('Criterio 4: Consulta por restaurante y fecha filtra exactamente los documentos solicitados', () async {
      await repository.createReservation(
        const ReservationModel(
          id: 'res_hoy_r1',
          restauranteId: 'rest_A',
          fechaLocal: '2026-10-20',
          estado: 'confirmada',
        ),
      );
      await repository.createReservation(
        const ReservationModel(
          id: 'res_manana_r1',
          restauranteId: 'rest_A',
          fechaLocal: '2026-10-21',
          estado: 'confirmada',
        ),
      );
      await repository.createReservation(
        const ReservationModel(
          id: 'res_hoy_r2',
          restauranteId: 'rest_B',
          fechaLocal: '2026-10-20',
          estado: 'confirmada',
        ),
      );

      // Consultar rest_A en 2026-10-20
      final resultados = await repository.getReservationsByRestaurantAndDate(
        restauranteId: 'rest_A',
        fechaLocal: '2026-10-20',
      );

      expect(resultados.length, 1);
      expect(resultados.first.id, 'res_hoy_r1');
      expect(resultados.first.restauranteId, 'rest_A');
      expect(resultados.first.fechaLocal, '2026-10-20');
    });
  });
}
