import 'package:flutter/material.dart';
import '../../models/categoria_model.dart';

/// Tarjeta individual para mostrar una categoría en la lista (HU24-RF02 Criterio 1)
/// Incluye controles para editar, eliminar y reordenar mediante flechas y drag-handle.
class CategoriaCard extends StatelessWidget {
  final CategoriaModel categoria;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback? onMoverArriba;
  final VoidCallback? onMoverAbajo;

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamLight = Color(0xFFFAF5ED);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _error = Color(0xFFD84A38);

  const CategoriaCard({
    super.key,
    required this.categoria,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onEditar,
    required this.onEliminar,
    this.onMoverArriba,
    this.onMoverAbajo,
  });

  IconData _getIconForTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'alimentos':
        return Icons.restaurant_rounded;
      case 'bebidas':
        return Icons.local_bar_rounded;
      case 'postres':
        return Icons.cake_rounded;
      case 'especiales':
        return Icons.star_rounded;
      default:
        return Icons.label_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Handle de arrastre para Drag and Drop
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _creamLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.drag_indicator_rounded,
                  color: _textMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Badge numérico con la posición (#1, #2...)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF1EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primaryTerracotta,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nombre y tipo de categoría
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoria.nombre,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getIconForTipo(categoria.tipo),
                        size: 13,
                        color: _textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        categoria.tipo[0].toUpperCase() +
                            categoria.tipo.substring(1).toLowerCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Flechas de subir y bajar (Reordenar alternativo accesible)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  color: isFirst
                      ? _cardBorder
                      : _textDark,
                  onPressed: isFirst ? null : onMoverArriba,
                  tooltip: 'Mover hacia arriba',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  color: isLast
                      ? _cardBorder
                      : _textDark,
                  onPressed: isLast ? null : onMoverAbajo,
                  tooltip: 'Mover hacia abajo',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(width: 4),

            // Separador sutil
            Container(
              height: 24,
              width: 1,
              color: _cardBorder,
            ),
            const SizedBox(width: 4),

            // Botón de Editar
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 19),
              color: _primaryTerracotta,
              onPressed: onEditar,
              tooltip: 'Editar categoría',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),

            // Botón de Eliminar
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: _error,
              onPressed: onEliminar,
              tooltip: 'Eliminar categoría',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
