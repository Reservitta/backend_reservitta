import '../models/reservation_detail.dart';
import '../models/reservation_model.dart';
export '../services/reservation_service.dart' show ReservationService;

/// Contrato del repositorio de reservaciones (HU08-RF02)
abstract class ReservationRepository {
  /// Crea una nueva reservación con cálculo automático de hora de fin y validación de estado (Criterios 1 y 2)
  Future<ReservationModel> createReservation(ReservationModel reservation);

  /// Guarda la reservación solo si todas sus mesas siguen libres, dentro de una
  /// transacción que evita reservas dobles (HU11-RF04). Lanza
  /// `ReservationConflictException` si otra persona ya reservó alguna mesa y
  /// `ReservationConnectionException` si falla la conexión; en ambos casos no
  /// queda nada guardado. [margenLimpiezaMin] se suma al final de las reservas existentes.
  Future<ReservationModel> createReservationVerified(
    ReservationModel reservation, {
    int margenLimpiezaMin = 0,
  });

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

  /// Cambia el estado operativo validando la transición (HU27-RF01). Registra quién
  /// lo hizo y cuándo, y libera la mesa si la reserva termina, se cancela o es no-show.
  /// Lanza `InvalidStateTransitionException` si la transición no es válida.
  Future<ReservationModel> changeOperationalState({
    required String reservationId,
    required String nuevoEstado,
    required String usuarioId,
    DateTime? ahora,
  });

  /// Cambia el estado del pedido preordenado (HU29-RF01), independiente del estado de
  /// la reserva. Solo avanza pendiente → en preparación → listo; regresar un paso exige
  /// [motivo]. Lanza `InvalidOrderTransitionException` si no es válido. No cambia la
  /// reserva ni la mesa (HU29-RF03: marcar listo es solo informativo).
  Future<ReservationModel> changeOrderState({
    required String reservationId,
    required String nuevoEstado,
    required String usuarioId,
    String? motivo,
    DateTime? ahora,
  });

  /// Detalle completo de una reservación para el administrador (HU28-RF01); null si no existe.
  Future<ReservationDetail?> getReservationDetail(
    String reservationId, {
    Map<String, String>? categoriasPorId,
    Map<String, String>? categoriaPorPlatilloId,
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
