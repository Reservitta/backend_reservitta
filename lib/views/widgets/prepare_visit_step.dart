import 'package:flutter/material.dart';
import '../../models/reservation_draft_model.dart';
import '../../theme/app_theme.dart';

/// Pantalla / Paso "¿Quieres preparar tu visita?" (HU15-RF01)
///
/// Presenta dos opciones claras al comensal tras ingresar sus datos de contacto (o crear cuenta):
/// 1. "Reservar solamente": confirma directamente la mesa sin personalizaciones adicionales.
/// 2. "Personalizar mi visita": navega a la pantalla de personalización (HU16) para preordenar,
///    declarar alergias y seleccionar ocasión especial.
///
/// El usuario puede volver atrás y cambiar de opción antes de confirmar.
class PrepareVisitStep extends StatelessWidget {
  final ReservationDraftModel draft;
  final VoidCallback onSoloReservar;
  final VoidCallback onPersonalizarVisita;
  final bool isProcessing;

  static const Color _primaryTerracotta = AppColors.marca;
  static const Color _lightBg = AppColors.fondo;
  static const Color _cardBorder = AppColors.divisor;
  static const Color _textDark = AppColors.texto;
  static const Color _textMuted = AppColors.textoSuave;

  const PrepareVisitStep({
    super.key,
    required this.draft,
    required this.onSoloReservar,
    required this.onPersonalizarVisita,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('step_preparar_visita'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado
          const Text(
            '¿Quieres preparar tu visita?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Elige si deseas asegurar tu mesa ahora mismo o personalizar tu experiencia con platillos en preorden, alergias u ocasiones especiales.',
            style: TextStyle(fontSize: 13, color: _textMuted, height: 1.3),
          ),
          const SizedBox(height: 20),

          // Resumen compacto de mesa
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_restaurant, color: _primaryTerracotta, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.restaurant.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${draft.formattedDate} · ${draft.formattedTimeRange} · ${draft.personas} pers.',
                        style: const TextStyle(fontSize: 12, color: _textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // TARJETA 1: "Reservar solamente" (HU15-RF01)
          Card(
            key: const ValueKey('card_reservar_solamente'),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: _cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _primaryTerracotta.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_added_outlined,
                          color: _primaryTerracotta,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Reservar solamente',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Asegura tu mesa de inmediato. Ordenarás tus platillos directamente cuando llegues al restaurante.',
                    style: TextStyle(fontSize: 13, color: _textMuted, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      key: const ValueKey('btn_solo_reservar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryTerracotta,
                        side: const BorderSide(color: _primaryTerracotta, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: isProcessing ? null : onSoloReservar,
                      child: isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _primaryTerracotta),
                            )
                          : const Text(
                              'Solo reservar',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TARJETA 2: "Personalizar mi visita" (HU15-RF01)
          Card(
            key: const ValueKey('card_personalizar_visita'),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: _primaryTerracotta, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _primaryTerracotta.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: _primaryTerracotta,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Personalizar mi visita',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Preordena tus platillos favoritos, notifica alergias alimentarias a cocina o elige una ocasión especial con amenidades y experiencias exclusivas.',
                    style: TextStyle(fontSize: 13, color: _textMuted, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      key: const ValueKey('btn_personalizar_visita'),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text(
                        'Personalizar visita',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryTerracotta,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: isProcessing ? null : onPersonalizarVisita,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

