import '../models/booking_models.dart';
import '../models/reservation_draft_model.dart';
import '../models/reservation_model.dart';
import '../models/restaurant_model.dart';
import '../repositories/reservation_repository.dart';
import '../utils/schedule_utils.dart';
import 'availability_service.dart';

/// Confirma una reserva a partir del borrador (HU11-RF04, HU15-RF02): revalida la selección,
/// guarda la reservación en una transacción y traduce los fallos a mensajes claros.
///
/// REUTILIZACIÓN DE ENDPOINTS (HU15-RF02):
/// Tanto el camino de "Solo reservar" como el de "Personalizar visita" consumen este mismo
/// método y endpoint de creación de reserva. El camino de personalización únicamente aporta
/// los datos adicionales en el payload (preorden, alergias y ocasión especial con experiencias).
/// No se duplica la lógica de verificación ni la validación de disponibilidad.
class ReservationBookingService {
  final AvailabilityService _availability;
  final ReservationRepository _reservations;

  ReservationBookingService(this._availability, this._reservations);

  /// Estado con el que se guarda una reserva recién confirmada.
  static const String estadoInicial = ReservationModel.estadoConfirmada;

  Future<BookingResult> confirm({
    required RestaurantModel restaurant,
    required ReservationDraftModel draft,
    required String usuarioId,
    String contactoNombre = '',
    String contactoCorreo = '',
    String contactoTelefono = '',
  }) async {
    final inicio = draft.inicio;
    if (usuarioId.isEmpty) {
      return const BookingFailed(
        message: 'Inicia sesión para confirmar tu reserva.',
      );
    }
    if (inicio == null || draft.fecha == null || draft.mesaIds.isEmpty) {
      return const BookingFailed(
        message: 'Faltan datos de la reserva: elige fecha, mesa y horario.',
      );
    }

    final SelectionValidation validation;
    try {
      validation = await _availability.revalidateSelection(
        restaurant: restaurant,
        inicio: inicio,
        duracionMin: draft.duracionMin,
        mesaIds: draft.mesaIds,
      );
    } catch (_) {
      return const BookingFailed(
        message:
            'No se pudo verificar la disponibilidad. Revisa tu conexión e intenta de nuevo. No se guardó ninguna reserva.',
        retryable: true,
      );
    }
    if (!validation.isValid) return BookingRejected(validation);

    final reserva = ReservationModel.create(
      id: '',
      restauranteId: restaurant.id,
      usuarioId: usuarioId,
      restauranteNombre: restaurant.nombre,
      contactoNombre: contactoNombre,
      contactoCorreo: contactoCorreo,
      contactoTelefono: contactoTelefono,
      fechaLocal: ScheduleUtils.formatDateLocal(draft.fecha!),
      inicio: inicio,
      duracionMin: draft.duracionMin,
      personas: draft.personas,
      mesaIds: draft.mesaIds,
      mesasNombres: draft.mesasNombres,
      estado: estadoInicial,
      preordenItems: draft.preordenItems,
      alergias: draft.alergias,
      notasAlergias: draft.notasAlergias,
      ocasionEspecial: draft.ocasionEspecial,
      experiencias: draft.experiencias,
    );

    try {
      final guardada = await _reservations.createReservationVerified(
        reserva,
        margenLimpiezaMin: _availability.margenLimpiezaMin,
      );
      return BookingConfirmed(guardada);
    } on ReservationConflictException catch (e) {
      return BookingConflict(
        message: _conflictMessage(draft, e.mesaIds.toList()),
        mesasEnConflicto: e.mesaIds,
        alternativas: await _safeAlternatives(restaurant, draft, inicio),
      );
    } on ReservationConnectionException {
      return const BookingFailed(
        message:
            'Se perdió la conexión al confirmar. No se guardó ninguna reserva: intenta de nuevo.',
        retryable: true,
      );
    } catch (_) {
      return const BookingFailed(
        message:
            'No se pudo guardar la reserva. No se guardó ninguna reserva: intenta de nuevo.',
        retryable: true,
      );
    }
  }

  String _conflictMessage(ReservationDraftModel draft, List<String> mesas) {
    final nombre = draft.mesasNombres.isNotEmpty
        ? draft.mesasNombres.join(', ')
        : (mesas.length <= 1 ? 'La mesa' : 'Una de las mesas');
    return '$nombre acaba de ser reservada por otra persona para este horario.';
  }

  Future<List<TimeSlot>> _safeAlternatives(
    RestaurantModel restaurant,
    ReservationDraftModel draft,
    DateTime inicio,
  ) async {
    try {
      return await _availability.alternativeSlots(
        restaurant: restaurant,
        fecha: draft.fecha!,
        duracionMin: draft.duracionMin,
        mesaIds: draft.mesaIds,
        cercaDe: inicio,
        max: 3,
      );
    } catch (_) {
      return const [];
    }
  }
}
