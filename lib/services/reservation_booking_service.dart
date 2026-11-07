import 'package:flutter/foundation.dart';

import '../models/booking_models.dart';
import '../models/notification_delivery_result.dart';
import '../models/reservation_access.dart';
import '../models/reservation_draft_model.dart';
import '../models/reservation_model.dart';
import '../models/reservation_notification_payload.dart';
import '../models/restaurant_model.dart';
import '../repositories/reservation_repository.dart';
import '../utils/schedule_utils.dart';
import 'availability_service.dart';
import 'confirmation_notification_service.dart';

/// Confirma una reserva a partir del borrador (HU11-RF04, HU15-RF02, HU19-RF01):
/// revalida la selección, guarda la reservación en una transacción y dispara
/// automáticamente la confirmación mediante [ConfirmationNotificationService].
///
/// REUTILIZACIÓN DE ENDPOINTS (HU15-RF02 / HU19-RF01):
/// Tanto el camino de "Solo reservar" como el de "Personalizar visita" consumen este mismo
/// método y endpoint de creación de reserva. El camino de personalización únicamente aporta
/// los datos adicionales en el payload (preorden, alergias y ocasión especial con experiencias).
/// No se duplica la lógica de verificación ni la validación de disponibilidad.
class ReservationBookingService {
  final AvailabilityService _availability;
  final ReservationRepository _reservations;
  final ConfirmationNotificationService? _notifications;

  ReservationBookingService(
    this._availability,
    this._reservations, [
    this._notifications,
  ]);

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

    final efectivoNombre =
        contactoNombre.isNotEmpty ? contactoNombre : draft.contactoNombre;
    final efectivoCorreo =
        contactoCorreo.isNotEmpty ? contactoCorreo : draft.contactoCorreo;
    final efectivoTelefono =
        contactoTelefono.isNotEmpty ? contactoTelefono : draft.contactoTelefono;

    final reserva = ReservationModel.create(
      id: '',
      restauranteId: restaurant.id,
      usuarioId: usuarioId,
      restauranteNombre: restaurant.nombre,
      contactoNombre: efectivoNombre,
      contactoCorreo: efectivoCorreo,
      contactoTelefono: efectivoTelefono,
      fechaLocal: ScheduleUtils.formatDateLocal(draft.fecha!),
      inicio: inicio,
      duracionMin: draft.duracionMin,
      personas: draft.personas,
      mesaIds: draft.mesaIds,
      mesasNombres: draft.mesasNombres,
      estado: estadoInicial,
      tokenGestion: ReservationAccess.generarToken(),
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

      // HU19-RF01: Disparo automático de confirmación al confirmarse la reserva
      NotificationDeliveryResult? notifResult;
      if (_notifications != null &&
          ReservationModel.normalizeStatus(guardada.estado) ==
              ReservationModel.estadoConfirmada) {
        try {
          final payload = ReservationNotificationPayload.fromReservation(
            guardada,
            canalPreferido: draft.canalPreferido,
            notas: draft.notasAlergias,
            sucursalId: draft.branch?.id ?? '',
            sucursalNombre: draft.branch?.nombre ?? '',
          );
          notifResult = await _notifications.sendNotification(payload);
        } catch (e) {
          // Tolerancia a fallos: fallo de notificación no revierte la reserva confirmada (HU19-RF02)
          notifResult = NotificationDeliveryResult.failed(
            notificacionId: 'notif_${guardada.id}',
            canal: draft.canalPreferido.isNotEmpty ? draft.canalPreferido : 'email',
            destino: guardada.contactoCorreo.isNotEmpty
                ? guardada.contactoCorreo
                : guardada.contactoTelefono,
            intentos: 1,
            error: e.toString(),
            requiereReintentoManual: true,
          );
        }
      }

      return BookingConfirmed(guardada, notificationResult: notifResult);
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
    } catch (e, stack) {
      debugPrint('Error al guardar reserva: $e\n$stack');
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
