import 'package:flutter/material.dart';
import '../../models/platillo_model.dart';

/// Tarjeta para cada platillo en la lista de gestión del menú (HU24-RF04)
/// Incluye un switch directo para cambiar disponibilidad con un solo toque,
/// y botón de edición rápida sin abandonar la lista principal.
class PlatilloCard extends StatelessWidget {
  final PlatilloModel platillo;
  final String categoriaNombre;
  final ValueChanged<bool> onToggleDisponibilidad;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamLight = Color(0xFFFAF5ED);
  static const Color _creamAccent = Color(0xFFF3ECE1);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _error = Color(0xFFD84A38);

  const PlatilloCard({
    super.key,
    required this.platillo,
    required this.categoriaNombre,
    required this.onToggleDisponibilidad,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final bool disponible = platillo.isActivo;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: disponible ? _cardBorder : Colors.orange.shade200,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Miniatura de imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _creamLight,
                  border: Border.all(color: _cardBorder),
                ),
                child: platillo.tieneImagenEnNube
                    ? Image.network(
                        platillo.imagenUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                      )
                    : _buildFallbackImage(),
              ),
            ),
            const SizedBox(width: 14),

            // 2. Información del platillo (Nombre, Categoría, Precio, Descripción)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          platillo.nombre,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: disponible ? _textDark : _textMuted,
                            decoration:
                                disponible ? null : TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Badge de precio
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF1EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$${platillo.precio.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _primaryTerracotta,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Categoría y Badge de disponibilidad
                  Row(
                    children: [
                      if (categoriaNombre.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _creamAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            categoriaNombre,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _primaryTerracotta,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: disponible
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          disponible ? 'Disponible' : 'Agotado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: disponible
                                ? Colors.green.shade800
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Descripción si existe
                  if (platillo.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      platillo.descripcion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),

            // 3. Switch de disponibilidad con un solo toque (HU24-RF04)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: disponible,
                  activeThumbColor: Colors.green.shade700,
                  activeTrackColor: Colors.green.shade200,
                  inactiveTrackColor: Colors.orange.shade100,
                  inactiveThumbColor: Colors.orange.shade700,
                  onChanged: onToggleDisponibilidad,
                ),
                Text(
                  disponible ? 'Activo' : 'Agotado',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: disponible ? Colors.green.shade800 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),

            // 4. Botones de acción rápida: Editar y Eliminar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: _primaryTerracotta,
                  onPressed: onEditar,
                  tooltip: 'Editar platillo',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: _error,
                  onPressed: onEliminar,
                  tooltip: 'Eliminar platillo',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(
          Icons.restaurant_rounded,
          size: 26,
          color: Color(0xFFC4B8AA),
        ),
      ],
    );
  }
}
