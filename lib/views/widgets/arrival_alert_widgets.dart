import 'package:flutter/material.dart';

import '../../models/arrival_alert.dart';
import '../../theme/app_theme.dart';

/// Colores de una alerta de llegada (HU30-RF03): ámbar si está por llegar, rojo si se retrasa.
class ArrivalAlertStyle {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  const ArrivalAlertStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  static ArrivalAlertStyle of(ArrivalAlert alerta) {
    if (alerta.esRetraso) {
      return const ArrivalAlertStyle(
        background: Color(0xFFFFEBEE),
        border: Color(0xFFEF9A9A),
        foreground: Color(0xFFC62828),
        icon: Icons.person_off_outlined,
      );
    }
    return const ArrivalAlertStyle(
      background: Color(0xFFFFF3D6),
      border: Color(0xFFE0A100),
      foreground: Color(0xFF7A5A00),
      icon: Icons.alarm_rounded,
    );
  }
}

/// Indicador corto "llega en X min" para el listado del día (HU30-RF03).
class ArrivalAlertChip extends StatelessWidget {
  final ArrivalAlert alerta;

  const ArrivalAlertChip({super.key, required this.alerta});

  @override
  Widget build(BuildContext context) {
    final s = ArrivalAlertStyle.of(alerta);
    return Container(
      key: ValueKey('alerta_chip_${alerta.reserva.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: s.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 13, color: s.foreground),
          const SizedBox(width: 4),
          Text(
            alerta.texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: s.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alerta tocable: lleva al detalle de la reserva (HU30-RF03).
class ArrivalAlertTile extends StatelessWidget {
  final ArrivalAlert alerta;
  final VoidCallback onTap;

  const ArrivalAlertTile({super.key, required this.alerta, required this.onTap});

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = ArrivalAlertStyle.of(alerta);
    final r = alerta.reserva;
    final cliente = r.contactoNombre.trim().isEmpty ? 'Cliente' : r.contactoNombre.trim();
    final mesa = r.mesasNombres.isEmpty ? 'Sin mesa' : r.mesasNombres.join(' + ');
    final extras = <String>[
      if (alerta.pedidoListo) 'Pedido listo',
      if (alerta.pedidoPorPreparar) 'Pedido por preparar',
      if (r.tieneRestriccionesOAlergias) 'Alergias',
    ];

    return Semantics(
      button: true,
      label: '${alerta.texto}: $cliente, ${_hora(r.effectiveStart)}, $mesa',
      child: Material(
        color: s.background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('alerta_${r.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: s.border),
            ),
            child: Row(
              children: [
                Icon(s.icon, color: s.foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alerta.texto,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: s.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$cliente · ${_hora(r.effectiveStart)} · $mesa · ${r.personas} pers.',
                        style: const TextStyle(fontSize: 13, color: AppColors.texto),
                      ),
                      if (extras.isNotEmpty)
                        Text(
                          extras.join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textoSuave),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textoSuave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
