import 'package:flutter/material.dart';
import '../models/notification_delivery_result.dart';
import '../models/operations_config.dart';
import '../models/reservation_model.dart';
import '../models/reservation_notification_payload.dart';
import '../services/confirmation_notification_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de confirmación con los datos de la reserva guardada (HU11-RF04, HU19-RF01, HU19-RF02).
///
/// Criterios de aceptación (HU19-RF02):
/// 1. Tras confirmar, se muestra una pantalla de éxito con los datos de la reserva y el canal por el que se envió la confirmación.
/// 2. Si el envío falla, la pantalla de confirmación igual se muestra (la reserva ya existe), informando que el comprobante no pudo enviarse, con opción de reenviar.
/// 3. Botón para reenviar la confirmación manualmente.
class ReservationConfirmationView extends StatefulWidget {
  final ReservationModel reservation;
  final NotificationDeliveryResult? notificationResult;
  final ConfirmationNotificationService? notificationService;
  final Future<NotificationDeliveryResult> Function(ReservationModel)? onResend;

  /// Se llama al pulsar "Volver al inicio"; por defecto regresa a la primera pantalla.
  final VoidCallback? onDone;

  /// Ajustes del restaurante para informar del recordatorio (HU21-RF02).
  final OperationsConfig operaciones;

  /// Reloj para decidir si todavía alcanza a enviarse el recordatorio.
  final DateTime Function()? now;

  const ReservationConfirmationView({
    super.key,
    required this.reservation,
    this.notificationResult,
    this.notificationService,
    this.onResend,
    this.onDone,
    this.operaciones = const OperationsConfig(),
    this.now,
  });

  static const Color terracotta = AppColors.marca;
  static const Color creamBg = AppColors.fondo;
  static const Color darkText = AppColors.texto;
  static const Color mutedText = AppColors.textoSuave;
  static const Color cardBorder = AppColors.divisor;

  static const _dias = ['L', 'M', 'Mi', 'J', 'V', 'S', 'D'];
  static const _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  State<ReservationConfirmationView> createState() =>
      _ReservationConfirmationViewState();
}

class _ReservationConfirmationViewState
    extends State<ReservationConfirmationView> {
  late NotificationDeliveryResult? _deliveryResult;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _deliveryResult = widget.notificationResult;
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String get _fecha {
    final d = widget.reservation.effectiveStart;
    return '${ReservationConfirmationView._dias[d.weekday - 1]}, ${d.day} de ${ReservationConfirmationView._meses[d.month - 1]}';
  }

  String get _horario =>
      '${_hhmm(widget.reservation.effectiveStart)} – ${_hhmm(widget.reservation.effectiveEnd)}';

  String get _duracion {
    final h = widget.reservation.duracionMin ~/ 60;
    final m = widget.reservation.duracionMin % 60;
    if (h > 0 && m > 0) return '$h h $m min';
    if (h > 0) return '$h h';
    return '$m min';
  }

  static String _dinero(double v) => '\$${v.toStringAsFixed(2)} MXN';

  /// Aviso del recordatorio (HU21-RF02); null si a esta reserva no se le enviará uno.
  String? get _textoRecordatorio {
    final r = widget.reservation;
    if (!r.bloqueaMesas) return null;
    return ReminderPolicy.textoParaCliente(
      inicio: r.effectiveStart,
      ahora: (widget.now ?? DateTime.now)(),
      config: widget.operaciones,
    );
  }

  String get _estado {
    switch (widget.reservation.estado) {
      case ReservationModel.estadoPendiente:
        return 'Pendiente';
      case ReservationModel.estadoCancelada:
        return 'Cancelada';
      default:
        return 'Confirmada';
    }
  }

  String get _canalConfirmacionTexto {
    if (_deliveryResult != null && _deliveryResult!.canal.isNotEmpty && _deliveryResult!.canal != 'ninguno') {
      return _deliveryResult!.canal == ReservationNotificationPayload.canalWhatsApp
          ? 'WhatsApp'
          : 'Correo electrónico';
    }
    if (widget.reservation.contactoTelefono.isNotEmpty && widget.reservation.contactoCorreo.isEmpty) {
      return 'WhatsApp';
    }
    return 'Correo electrónico';
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);

    try {
      NotificationDeliveryResult result;
      if (widget.onResend != null) {
        result = await widget.onResend!(widget.reservation);
      } else {
        final service =
            widget.notificationService ?? ConfirmationNotificationService();
        final prefCanal = widget.reservation.contactoTelefono.isNotEmpty &&
                widget.reservation.contactoCorreo.isEmpty
            ? ReservationNotificationPayload.canalWhatsApp
            : ReservationNotificationPayload.canalEmail;

        final payload = ReservationNotificationPayload.fromReservation(
          widget.reservation,
          canalPreferido: prefCanal,
        );
        result = await service.sendNotification(payload);
      }

      if (!mounted) return;
      setState(() {
        _deliveryResult = result;
        _isResending = false;
      });

      if (result.exitoso) {
        final canalNombre =
            result.canal == ReservationNotificationPayload.canalWhatsApp
                ? 'WhatsApp'
                : 'correo electrónico';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('snackbar_reenvio_exitoso'),
            content: Text(
              'Comprobante reenviado con éxito por $canalNombre a ${result.destino}.',
            ),
            backgroundColor: AppColors.exito,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('snackbar_reenvio_fallido'),
            content: Text(
              'No se pudo enviar el comprobante: ${result.error ?? "error de entrega"}. Puedes intentar de nuevo.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('snackbar_reenvio_fallido'),
          content: Text('Error al reenviar comprobante: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesas = widget.reservation.mesasNombres.isNotEmpty
        ? widget.reservation.mesasNombres.join(' + ')
        : (widget.reservation.mesaIds.isNotEmpty
            ? widget.reservation.mesaIds.join(' + ')
            : 'El restaurante te la asignará');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: ReservationConfirmationView.creamBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.exito,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¡Reserva confirmada!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: ReservationConfirmationView.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Te esperamos. Estos son los datos de tu visita.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: ReservationConfirmationView.mutedText,
                    ),
                  ),

                  // -----------------------------------------------------------
                  // HU19-RF02 Criterio 1: Confirmación enviada con éxito
                  // -----------------------------------------------------------
                  if (_deliveryResult != null && _deliveryResult!.exitoso) ...[
                    const SizedBox(height: 16),
                    _buildSuccessDeliveryBanner(),
                  ],

                  // -----------------------------------------------------------
                  // HU19-RF02 Criterio 2: Envío fallido pero reserva confirmada
                  // -----------------------------------------------------------
                  if (_deliveryResult != null && !_deliveryResult!.exitoso) ...[
                    const SizedBox(height: 16),
                    _buildFailureDeliveryBanner(),
                  ],

                  // -----------------------------------------------------------
                  // Caso sin notificación previa enviada (opción manual)
                  // -----------------------------------------------------------
                  if (_deliveryResult == null) ...[
                    const SizedBox(height: 16),
                    _buildPendingDeliveryBanner(),
                  ],

                  const SizedBox(height: 24),
                  Container(
                    key: const ValueKey('confirmation_details'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ReservationConfirmationView.cardBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        _row(Icons.storefront, 'Restaurante',
                            widget.reservation.restauranteNombre),
                        _row(Icons.calendar_today, 'Fecha', _fecha),
                        _row(Icons.schedule, 'Horario', _horario),
                        _row(Icons.timer_outlined, 'Duración', _duracion),
                        _row(Icons.people_outline, 'Personas',
                            '${widget.reservation.personas}'),
                        _row(Icons.table_restaurant_outlined,
                            widget.reservation.mesaIds.length > 1 ? 'Mesas' : 'Mesa', mesas),
                        _row(
                          Icons.notifications_active_outlined,
                          'Canal de confirmación',
                          _canalConfirmacionTexto,
                        ),
                        if (widget.reservation.contactoNombre.isNotEmpty)
                          _row(Icons.person_outline, 'Nombre',
                              widget.reservation.contactoNombre),
                        if (widget.reservation.contactoCorreo.isNotEmpty)
                          _row(Icons.email_outlined, 'Correo',
                              widget.reservation.contactoCorreo),
                        if (widget.reservation.contactoTelefono.isNotEmpty)
                          _row(Icons.phone_outlined, 'Teléfono',
                              widget.reservation.contactoTelefono),
                        if (widget.reservation.esOcasionEspecial)
                          _row(Icons.celebration_outlined, 'Ocasión',
                              widget.reservation.nombreOcasionEspecial),
                        if (widget.reservation.tienePreorden)
                          _row(Icons.restaurant_menu, 'Pedido',
                              _dinero(widget.reservation.subtotalPreorden)),
                        if (widget.reservation.totalExperiencias > 0)
                          _row(Icons.auto_awesome_outlined, 'Experiencias',
                              _dinero(widget.reservation.totalExperiencias)),
                        if (widget.reservation.totalPersonalizacion > 0)
                          _row(Icons.payments_outlined, 'Total por pagar',
                              _dinero(widget.reservation.totalPersonalizacion)),
                        _row(Icons.verified_outlined, 'Estado', _estado),
                        _row(
                          Icons.confirmation_number_outlined,
                          'Código',
                          widget.reservation.id,
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  if (_textoRecordatorio != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      key: const ValueKey('aviso_recordatorio'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notifications_active_outlined,
                            size: 18, color: ReservationConfirmationView.mutedText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _textoRecordatorio!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ReservationConfirmationView.mutedText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('btn_confirmation_done'),
                      style: FilledButton.styleFrom(
                        backgroundColor: ReservationConfirmationView.terracotta,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: widget.onDone ??
                          () => Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                      child: const Text(
                        'Volver al inicio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BANNER DE ENTREGA EXITOSA (HU19-RF02 Criterio 1)
  // ---------------------------------------------------------------------------
  Widget _buildSuccessDeliveryBanner() {
    final isWhatsApp = _deliveryResult!.canal == ReservationNotificationPayload.canalWhatsApp;
    final canalNombre = isWhatsApp ? 'WhatsApp' : 'correo electrónico';

    return Container(
      key: const ValueKey('notification_delivery_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWhatsApp ? Icons.phone_android : Icons.mark_email_read_outlined,
                color: AppColors.exito,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isWhatsApp
                      ? 'Confirmación enviada por WhatsApp al ${_deliveryResult!.destino}'
                      : 'Confirmación enviada por correo a ${_deliveryResult!.destino}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Text(
                  'Canal: $canalNombre',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.exito,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('btn_reenviar_confirmacion'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.exito,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                icon: _isResending
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 14),
                label: Text(
                  _isResending ? 'Reenviando...' : 'Reenviar comprobante',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _isResending ? null : _handleResend,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BANNER DE ENTREGA FALLIDA (HU19-RF02 Criterio 2 y 3)
  // ---------------------------------------------------------------------------
  Widget _buildFailureDeliveryBanner() {
    final canalNombre =
        _deliveryResult!.canal == ReservationNotificationPayload.canalWhatsApp
            ? 'WhatsApp'
            : 'correo electrónico';
    final destino = _deliveryResult!.destino.isNotEmpty
        ? _deliveryResult!.destino
        : (widget.reservation.contactoCorreo.isNotEmpty
            ? widget.reservation.contactoCorreo
            : widget.reservation.contactoTelefono);

    return Container(
      key: const ValueKey('notification_failure_banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE65100),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La reserva ya existe, pero el comprobante no pudo enviarse.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFBF360C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tu reserva está asegurada en el restaurante. Sin embargo, no se pudo enviar el comprobante a $destino por $canalNombre. Puedes reenviarlo manualmente.',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('btn_reenviar_confirmacion'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _isResending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 14),
              label: Text(
                _isResending ? 'Reenviando...' : 'Reenviar confirmación',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              onPressed: _isResending ? null : _handleResend,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BANNER CUANDO NO SE HA ENVIADO COMPROBANTE AÚN
  // ---------------------------------------------------------------------------
  Widget _buildPendingDeliveryBanner() {
    return Container(
      key: const ValueKey('notification_pending_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF4ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ReservationConfirmationView.terracotta.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            color: ReservationConfirmationView.terracotta,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '¿Deseas recibir tu comprobante de reserva?',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ReservationConfirmationView.darkText,
              ),
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('btn_reenviar_confirmacion'),
            style: FilledButton.styleFrom(
              backgroundColor: ReservationConfirmationView.terracotta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: _isResending
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 14),
            label: Text(
              _isResending ? 'Enviando...' : 'Enviar confirmación',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: _isResending ? null : _handleResend,
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ReservationConfirmationView.terracotta),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                fontSize: 13,
                color: ReservationConfirmationView.mutedText,
              )),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ReservationConfirmationView.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
