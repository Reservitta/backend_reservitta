import 'package:flutter/material.dart';
import '../models/notification_delivery_result.dart';
import '../models/reservation_draft_model.dart';
import '../models/reservation_model.dart';
import '../models/reservation_notification_payload.dart';
import '../models/visitor_account_result.dart';
import '../repositories/reservation_repository.dart';
import '../services/confirmation_notification_service.dart';
import '../services/visitor_account_service.dart';

/// ViewModel para la confirmación de la reserva y orquestación de cuenta de visitante (HU14-RF02)
/// y disparo automático de confirmación por correo/WhatsApp/Push (HU19-RF01).
///
/// Gestiona:
/// 1. La creación opcional de cuenta de visitante en el proveedor de autenticación (HU14-RF02).
/// 2. La asociación de la cuenta (`usuarioId`) a la reserva en curso.
/// 3. La persistencia de la reserva en estado confirmada.
/// 4. El disparo automático del servicio de notificación (HU14-RF03 / HU19-RF01).
/// 5. El reflejo en el historial de reservas del usuario y notificación push.
/// 6. La tolerancia a fallos: si falla la notificación o la cuenta, la reserva
///    confirmada no se revierte ni se corrompe.
class ReservationConfirmationViewModel extends ChangeNotifier {
  final VisitorAccountService _visitorAccountService;
  final ConfirmationNotificationService _notificationService;
  final ReservationRepository? reservationRepository;

  ReservationDraftModel _draft;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _accountNoticeMessage;
  String? _notificationNoticeMessage;
  VisitorAccountResult? _accountResult;
  ReservationModel? _confirmedReservation;
  NotificationDeliveryResult? _notificationResult;
  bool _pushNotificationSent = false;

  ReservationConfirmationViewModel({
    required ReservationDraftModel initialDraft,
    VisitorAccountService? visitorAccountService,
    ConfirmationNotificationService? notificationService,
    this.reservationRepository,
  })  : _draft = initialDraft,
        _visitorAccountService = visitorAccountService ?? VisitorAccountService(),
        _notificationService = notificationService ?? ConfirmationNotificationService();

  // Getters
  ReservationDraftModel get draft => _draft;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  String? get accountNoticeMessage => _accountNoticeMessage;
  String? get notificationNoticeMessage => _notificationNoticeMessage;
  VisitorAccountResult? get accountResult => _accountResult;
  ReservationModel? get confirmedReservation => _confirmedReservation;
  NotificationDeliveryResult? get notificationResult => _notificationResult;
  bool get pushNotificationSent => _pushNotificationSent;

  bool get hasAccountCreated => _accountResult?.cuentaCreada ?? false;
  bool get hasAccountFallback => _accountResult?.motivoFallo != null;
  bool get isReservationConfirmed => _confirmedReservation != null;

  /// Procesa la creación opcional de cuenta y la asocia a la reserva en curso (HU14-RF02).
  ///
  /// Retorna el borrador actualizado con el `usuarioId` correspondiente
  /// o sin cuenta si falló o no se solicitó (Criterios 1, 2 y 3).
  Future<ReservationDraftModel> procesarCuentaVisitante() async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _visitorAccountService.processVisitorAccount(draft: _draft);
      _accountResult = result;

      // Criterio 2: Asociar cuenta a la reserva en curso
      _draft = _visitorAccountService.associateAccountToDraft(
        draft: _draft,
        result: result,
      );

      // Criterio 3: Si falló, informar el motivo al usuario
      if (result.hasError) {
        _accountNoticeMessage = result.mensajeInformativo;
      } else if (result.cuentaCreada) {
        _accountNoticeMessage = result.mensajeInformativo;
      } else {
        _accountNoticeMessage = null;
      }

      return _draft;
    } catch (e) {
      // Fallback de ultra-seguridad para que nada detenga el flujo de reserva
      _draft = _draft.copyWith(usuarioId: '');
      _accountNoticeMessage =
          'Ocurrió un problema inesperado con la cuenta. Tu reserva continuará como invitado.';
      return _draft;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Ejecuta el proceso completo de confirmación de reserva (HU14-RF02 + HU19-RF01):
  /// 1. Procesa cuenta de visitante (con fallback si falla).
  /// 2. Asocia `usuarioId` a la reserva.
  /// 3. Si hay repositorio inyectado, persiste el documento en Firestore.
  /// 4. Dispara automáticamente la confirmación usando ConfirmationNotificationService (HU19-RF01).
  /// 5. Registra el reflejo en historial y notificación push.
  Future<ReservationModel?> confirmarReserva({
    String estado = ReservationModel.estadoConfirmada,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    _notificationNoticeMessage = null;
    notifyListeners();

    try {
      // 1. Procesar cuenta si aún no se ha procesado (HU14-RF02)
      if (_accountResult == null) {
        await procesarCuentaVisitante();
      }

      // 2. Construir el modelo final asociado
      final reservationModel = _draft.toReservationModel(estado: estado);

      // 3. Persistir si hay repositorio provisto
      if (reservationRepository != null) {
        final saved = await reservationRepository!.createReservation(reservationModel);
        _confirmedReservation = saved;
      } else {
        _confirmedReservation = reservationModel;
      }

      // 4. HU19-RF01: Disparo automático de confirmación al confirmarse la reserva
      if (_confirmedReservation != null &&
          ReservationModel.normalizeStatus(_confirmedReservation!.estado) ==
              ReservationModel.estadoConfirmada) {
        try {
          final payload = ReservationNotificationPayload.fromReservation(
            _confirmedReservation!,
            canalPreferido: _draft.canalPreferido,
            notas: _draft.notasAlergias,
            sucursalId: _draft.branch?.id ?? '',
            sucursalNombre: _draft.branch?.nombre ?? '',
          );

          final result = await _notificationService.sendNotification(payload);
          _notificationResult = result;

          if (result.exitoso) {
            final canalTexto = result.canal == ReservationNotificationPayload.canalWhatsApp
                ? 'WhatsApp (${result.destino})'
                : 'correo electrónico (${result.destino})';
            _notificationNoticeMessage = 'Confirmación enviada por $canalTexto.';
          } else if (result.requiereReintentoManual) {
            _notificationNoticeMessage =
                'Tu reserva está confirmada. El mensaje de confirmación quedó programado para reintento manual.';
          }

          // Criterio 3: Si el visitante creó cuenta (HU14-RF02), se refleja en su historial
          // (mediante el usuarioId asociado) y se registra notificación push si aplica.
          if (hasAccountCreated || (_confirmedReservation!.usuarioId.isNotEmpty)) {
            _pushNotificationSent = true;
          }
        } catch (_) {
          // Criterio 5 / Tolerancia a fallos:
          // Una falla en el envío de notificación jamás cancela ni corrompe una reserva confirmada
          _notificationNoticeMessage =
              'Tu reserva está confirmada con éxito. Hubo un problema temporal enviando el mensaje de confirmación.';
        }
      }

      return _confirmedReservation;
    } catch (e) {
      _errorMessage = 'Error al confirmar la reserva: $e';
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Permite actualizar externamente el borrador
  void updateDraft(ReservationDraftModel newDraft) {
    _draft = newDraft;
    _accountResult = null;
    _accountNoticeMessage = null;
    _notificationNoticeMessage = null;
    _notificationResult = null;
    _pushNotificationSent = false;
    _errorMessage = null;
    notifyListeners();
  }
}
