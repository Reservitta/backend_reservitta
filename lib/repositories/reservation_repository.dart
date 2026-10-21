import '../models/reservation_model.dart';
export '../services/reservation_service.dart' show ReservationService;

/// Contrato del repositorio de reservaciones (HU08-RF02)
abstract class ReservationRepository {
  /// Crea una nueva reservación con cálculo automático de hora de fin y validación de estado (Criterios 1 y 2)
  Future<ReservationModel> createReservation(ReservationModel reservation);

  /// Consulta reservaciones por restaurante y fecha usando los índices definidos (Criterio 4)
  Future<List<ReservationModel>> getReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  });

  /// Consulta reservaciones activas (pendiente/confirmada) por restaurante y fecha (Criterio 3)
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  });

  /// Obtiene una reservación por su ID
  Future<ReservationModel?> getReservationById(String reservationId);

  /// Actualiza el estado de una reservación validando estados permitidos (pendiente, confirmada, cancelada)
  Future<void> updateReservationStatus({
    required String reservationId,
    required String nuevoEstado,
  });

  /// Cancela una reservación (liberando el bloqueo de mesas al cambiar a estado 'cancelada', Criterio 3)
  Future<void> cancelReservation(String reservationId);

  /// Verifica si una mesa específica está disponible en una fecha y hora objetivo (Criterio 3)
  Future<bool> isTableAvailable({
    required String restauranteId,
    required String mesaId,
    required DateTime targetDateTime,
    int durationMin = 90,
  });

  /// Retorna el conjunto de IDs de mesas bloqueadas en un horario objetivo por reservaciones activas (Criterio 3)
  Future<Set<String>> getBlockedTableIds({
    required String restauranteId,
    required DateTime targetDateTime,
    int durationMin = 90,
  });

  /// Stream en tiempo real de reservaciones por restaurante y fecha
  Stream<List<ReservationModel>> getReservationsStream({
    required String restauranteId,
    required String fechaLocal,
  });
}
