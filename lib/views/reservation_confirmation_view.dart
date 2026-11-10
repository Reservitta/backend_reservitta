import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/notification_delivery_result.dart';
import '../models/operations_config.dart';
import '../models/reservation_model.dart';
import '../models/reservation_notification_payload.dart';
import '../services/confirmation_notification_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import 'reservation_management_view.dart';

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
    final r = widget.reservation;
    final mesas = r.mesasNombres.isNotEmpty
        ? r.mesasNombres.join(' + ')
        : (r.mesaIds.isNotEmpty
            ? r.mesaIds.join(' + ')
            : 'El restaurante te la asignará');

    final banner = _deliveryResult == null
        ? _buildPendingDeliveryBanner()
        : (_deliveryResult!.exitoso
            ? _buildSuccessDeliveryBanner()
            : _buildFailureDeliveryBanner());

    final ticket = _buildTicket(mesas);
    final siguiente = _buildQueSigue();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: ReservationConfirmationView.creamBg,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEncabezado(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          if (c.maxWidth >= 900) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: ticket),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      banner,
                                      const SizedBox(height: 18),
                                      siguiente,
                                      const SizedBox(height: 22),
                                      _buildAcciones(),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              banner,
                              const SizedBox(height: 18),
                              ticket,
                              const SizedBox(height: 18),
                              siguiente,
                              const SizedBox(height: 22),
                              _buildAcciones(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Encabezado con la palomita, el título y el código de la reserva.
  Widget _buildEncabezado() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.marcaSuave, AppColors.fondo],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.exito.withValues(alpha: 0.35), width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.exito.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.exito, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Reserva confirmada!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.familiaTitulos,
              fontWeight: FontWeight.w700,
              fontVariations: [FontVariation('wght', 700)],
              fontSize: 38,
              height: 1.1,
              letterSpacing: -0.6,
              color: ReservationConfirmationView.darkText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Te esperamos. Estos son los datos de tu visita.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: ReservationConfirmationView.mutedText),
          ),
          const SizedBox(height: 18),
          Container(
            key: const ValueKey('codigo_reserva'),
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ReservationConfirmationView.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.confirmation_number_outlined,
                    size: 20, color: ReservationConfirmationView.terracotta),
                const SizedBox(width: 10),
                const Text(
                  'Código de reserva',
                  style: TextStyle(fontSize: 13, color: ReservationConfirmationView.mutedText),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    widget.reservation.id,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: ReservationConfirmationView.darkText,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('btn_copiar_codigo'),
                  tooltip: 'Copiar código',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.reservation.id));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código copiado'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Boleto con los datos principales destacados y el resto en lista.
  Widget _buildTicket(String mesas) {
    final r = widget.reservation;

    Widget destacado(IconData icono, String etiqueta, String valor, {String? unidad}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.fondo,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ReservationConfirmationView.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, size: 18, color: ReservationConfirmationView.terracotta),
                  const SizedBox(width: 8),
                  Text(
                    etiqueta,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ReservationConfirmationView.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                valor,
                style: const TextStyle(
                  fontFamily: AppTheme.familiaTitulos,
                  fontWeight: FontWeight.w700,
                  fontVariations: [FontVariation('wght', 700)],
                  fontSize: 22,
                  height: 1.15,
                  color: ReservationConfirmationView.darkText,
                ),
              ),
              if (unidad != null) ...[
                const SizedBox(height: 2),
                Text(
                  unidad,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ReservationConfirmationView.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('confirmation_details'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ReservationConfirmationView.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.marca.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              color: AppColors.marca,
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: Colors.white, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      r.restauranteNombre,
                      style: const TextStyle(
                        fontFamily: AppTheme.familiaTitulos,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation('wght', 700)],
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _estado,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final bloques = [
                        destacado(Icons.calendar_today_outlined, 'Fecha', _fecha),
                        destacado(Icons.schedule, 'Horario', _horario),
                        destacado(Icons.groups_outlined, 'Personas', '${r.personas}',
                            unidad: r.personas == 1 ? 'persona' : 'personas'),
                      ];
                      if (c.maxWidth >= 560) {
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < bloques.length; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                bloques[i],
                              ],
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < bloques.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            Row(children: [bloques[i]]),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _row(Icons.timer_outlined, 'Duración', _duracion),
                  _row(Icons.table_restaurant_outlined,
                      r.mesaIds.length > 1 ? 'Mesas' : 'Mesa', mesas),
                  _row(
                    Icons.notifications_active_outlined,
                    'Canal de confirmación',
                    _canalConfirmacionTexto,
                  ),
                  if (r.contactoNombre.isNotEmpty)
                    _row(Icons.person_outline, 'Nombre', r.contactoNombre),
                  if (r.contactoCorreo.isNotEmpty)
                    _row(Icons.email_outlined, 'Correo', r.contactoCorreo),
                  if (r.contactoTelefono.isNotEmpty)
                    _row(Icons.phone_outlined, 'Teléfono', r.contactoTelefono),
                  if (r.esOcasionEspecial)
                    _row(Icons.celebration_outlined, 'Ocasión', r.nombreOcasionEspecial),
                  if (r.tienePreorden)
                    _row(Icons.restaurant_menu, 'Pedido', _dinero(r.subtotalPreorden)),
                  if (r.totalExperiencias > 0)
                    _row(Icons.auto_awesome_outlined, 'Experiencias',
                        _dinero(r.totalExperiencias)),
                  if (r.totalPersonalizacion > 0)
                    _row(Icons.payments_outlined, 'Total por pagar',
                        _dinero(r.totalPersonalizacion),
                        last: true)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Aviso del recordatorio y recomendaciones para la visita.
  Widget _buildQueSigue() {
    final recordatorio = _textoRecordatorio;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ReservationConfirmationView.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Qué sigue',
            style: TextStyle(
              fontFamily: AppTheme.familiaTitulos,
              fontWeight: FontWeight.w700,
              fontVariations: [FontVariation('wght', 700)],
              fontSize: 20,
              color: ReservationConfirmationView.darkText,
            ),
          ),
          const SizedBox(height: 12),
          if (recordatorio != null)
            Row(
              key: const ValueKey('aviso_recordatorio'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined,
                    size: 20, color: ReservationConfirmationView.terracotta),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recordatorio,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: ReservationConfirmationView.darkText,
                    ),
                  ),
                ),
              ],
            ),
          if (recordatorio != null) const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule, size: 20, color: ReservationConfirmationView.terracotta),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Llega unos minutos antes de tu hora para que te acomoden con calma.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: ReservationConfirmationView.darkText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcciones() {
    final token = widget.reservation.tokenGestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const ValueKey('btn_confirmation_done'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: widget.onDone ??
              () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text(
            'Volver al inicio',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        if (token.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('btn_gestionar_desde_confirmacion'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.event_note_outlined, size: 20),
            label: const Text('Gestionar mi reserva'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReservationManagementView(initialCode: token),
              ),
            ),
          ),
        ],
      ],
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
