import 'package:flutter/material.dart';
import '../models/reservation_model.dart';

/// Pantalla de confirmación con los datos de la reserva guardada (HU11-RF04).
class ReservationConfirmationView extends StatelessWidget {
  final ReservationModel reservation;

  /// Se llama al pulsar "Volver al inicio"; por defecto regresa a la primera pantalla.
  final VoidCallback? onDone;

  const ReservationConfirmationView({
    super.key,
    required this.reservation,
    this.onDone,
  });

  static const Color terracotta = Color(0xFFB34A26);
  static const Color creamBg = Color(0xFFFAF6F0);
  static const Color darkText = Color(0xFF2E241E);
  static const Color mutedText = Color(0xFF7A6E65);
  static const Color cardBorder = Color(0xFFEDE4D8);

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

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String get _fecha {
    final d = reservation.effectiveStart;
    return '${_dias[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';
  }

  String get _horario =>
      '${_hhmm(reservation.effectiveStart)} – ${_hhmm(reservation.effectiveEnd)}';

  String get _duracion {
    final h = reservation.duracionMin ~/ 60;
    final m = reservation.duracionMin % 60;
    if (h > 0 && m > 0) return '$h h $m min';
    if (h > 0) return '$h h';
    return '$m min';
  }

  String get _estado {
    switch (reservation.estado) {
      case ReservationModel.estadoPendiente:
        return 'Pendiente';
      case ReservationModel.estadoCancelada:
        return 'Cancelada';
      default:
        return 'Confirmada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesas = reservation.mesasNombres.isNotEmpty
        ? reservation.mesasNombres.join(' + ')
        : reservation.mesaIds.join(' + ');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: creamBg,
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
                        color: Color(0xFF2E7D32),
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
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Te esperamos. Estos son los datos de tu visita.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: mutedText),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    key: const ValueKey('confirmation_details'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: [
                        _row(Icons.storefront, 'Restaurante',
                            reservation.restauranteNombre),
                        _row(Icons.calendar_today, 'Fecha', _fecha),
                        _row(Icons.schedule, 'Horario', _horario),
                        _row(Icons.timer_outlined, 'Duración', _duracion),
                        _row(Icons.people_outline, 'Personas',
                            '${reservation.personas}'),
                        _row(Icons.table_restaurant_outlined,
                            reservation.mesaIds.length > 1 ? 'Mesas' : 'Mesa', mesas),
                        if (reservation.contactoNombre.isNotEmpty)
                          _row(Icons.person_outline, 'Nombre',
                              reservation.contactoNombre),
                        if (reservation.contactoCorreo.isNotEmpty)
                          _row(Icons.email_outlined, 'Correo',
                              reservation.contactoCorreo),
                        if (reservation.contactoTelefono.isNotEmpty)
                          _row(Icons.phone_outlined, 'Teléfono',
                              reservation.contactoTelefono),
                        _row(Icons.verified_outlined, 'Estado', _estado),
                        _row(Icons.confirmation_number_outlined, 'Código',
                            reservation.id,
                            last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('btn_confirmation_done'),
                      style: FilledButton.styleFrom(
                        backgroundColor: terracotta,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: onDone ??
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

  Widget _row(IconData icon, String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: terracotta),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: mutedText)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
