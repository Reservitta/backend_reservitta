import 'package:flutter/material.dart';
import '../../models/platillo_model.dart';

/// Modo de visualización para la tarjeta del platillo
enum PlatilloCardMode {
  /// Modo de solo consulta (HU06-RF03): visualiza información básica, foto y precio sin controles de adición.
  readOnly,

  /// Modo de preorden (HU16-RF02, HU16-RF04, HU16-RF05): incluye controles de adición/edición y badge de cantidad.
  preorden,
}

/// Componente visual reutilizable para tarjetas de platillos en el menú.
///
/// RELACIÓN ARQUITECTÓNICA DEL SISTEMA (HU16-RF02 Criterio 3, HU16-RF05):
/// El catálogo del menú se define y administra una única vez por el administrador
/// del restaurante (HU24) utilizando los modelos [PlatilloModel] y [CategoriaModel]
/// guardados en Firebase Firestore (`restaurants/{id}/platillos`).
///
/// En modo [PlatilloCardMode.preorden]:
/// - Cuando `cantidad == 0`: muestra el botón `"Agregar"` (HU16-RF04).
/// - Cuando `cantidad > 0`: muestra un badge con la cantidad sobre la imagen del platillo
///   y el botón cambia de `"Agregar"` a `"Editar"` (HU16-RF05 Criterio 1).
class PlatilloMenuCard extends StatelessWidget {
  final PlatilloModel platillo;
  final PlatilloCardMode mode;
  final int cantidad;
  final String observacion;
  final VoidCallback? onAgregar;
  final VoidCallback? onEditar;
  final VoidCallback? onIncrementar;
  final VoidCallback? onDecrementar;
  final VoidCallback? onTap;

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);

  const PlatilloMenuCard({
    super.key,
    required this.platillo,
    this.mode = PlatilloCardMode.readOnly,
    this.cantidad = 0,
    this.observacion = '',
    this.onAgregar,
    this.onEditar,
    this.onIncrementar,
    this.onDecrementar,
    this.onTap,
  });

  bool get _usaStepperInlineLegacy =>
      onEditar == null && (onIncrementar != null || onDecrementar != null);

  @override
  Widget build(BuildContext context) {
    final isPreorden = mode == PlatilloCardMode.preorden;
    final mostrarBadgeSobreImagen =
        isPreorden && cantidad > 0 && !_usaStepperInlineLegacy;

    return Card(
      key: ValueKey('card_platillo_${platillo.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cantidad > 0 ? _primaryTerracotta : _cardBorder,
          width: cantidad > 0 ? 1.5 : 1.0,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap ?? (cantidad > 0 ? onEditar : onAgregar),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del platillo con badge de cantidad superpuesto (HU16-RF05 Criterio 1)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _primaryTerracotta.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: platillo.imagenUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              platillo.imagenUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.fastfood_outlined,
                                color: _primaryTerracotta,
                                size: 28,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.fastfood_outlined,
                            color: _primaryTerracotta,
                            size: 28,
                          ),
                  ),
                  if (mostrarBadgeSobreImagen)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        key: ValueKey('badge_cantidad_platillo_${platillo.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryTerracotta,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(35),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '$cantidad',
                          key: ValueKey('txt_cantidad_platillo_${platillo.id}'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Detalles del platillo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            platillo.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF2E241E),
                            ),
                          ),
                        ),
                        if (platillo.permitePersonalizacion)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF3FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Personalizable',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E5288),
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (platillo.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        platillo.descripcion,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A6E65),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    if (platillo.etiquetas.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: platillo.etiquetas.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _lightBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _cardBorder),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF7A6E65),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    if (isPreorden && observacion.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Observación: ${observacion.trim()}',
                        key: ValueKey('txt_observacion_platillo_${platillo.id}'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF1E5288),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Fila inferior: Precio y controles (si es preorden)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '\$${platillo.precio.toStringAsFixed(2)} MXN',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _primaryTerracotta,
                            fontSize: 14,
                          ),
                        ),

                        // Controles de adición / edición de preorden (HU16-RF02, HU16-RF05)
                        if (isPreorden) ...[
                          if (cantidad <= 0)
                            FilledButton.tonalIcon(
                              key: ValueKey('btn_agregar_platillo_${platillo.id}'),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Agregar',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: _primaryTerracotta.withAlpha(25),
                                foregroundColor: _primaryTerracotta,
                              ),
                              onPressed: onAgregar ?? onTap,
                            )
                          else if (_usaStepperInlineLegacy)
                            Container(
                              decoration: BoxDecoration(
                                color: _lightBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _cardBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: ValueKey(
                                      'btn_decrementar_platillo_${platillo.id}',
                                    ),
                                    icon: const Icon(Icons.remove, size: 16),
                                    color: _primaryTerracotta,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: onDecrementar,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      '$cantidad',
                                      key: ValueKey(
                                        'txt_cantidad_platillo_${platillo.id}',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: ValueKey(
                                      'btn_incrementar_platillo_${platillo.id}',
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    color: _primaryTerracotta,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: onIncrementar,
                                  ),
                                ],
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              key: ValueKey('btn_editar_platillo_${platillo.id}'),
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text(
                                'Editar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                                foregroundColor: _primaryTerracotta,
                                side: const BorderSide(color: _primaryTerracotta),
                              ),
                              onPressed: onEditar ?? onAgregar ?? onTap,
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
