import 'package:flutter/material.dart';
import '../../models/platillo_model.dart';

/// Modo de visualización para la tarjeta del platillo
enum PlatilloCardMode {
  /// Modo de solo consulta (HU06-RF03): visualiza información básica, foto y precio sin controles de adición.
  readOnly,

  /// Modo de preorden (HU16-RF02): incluye controles de cantidad y botón "Agregar" para armar la preorden.
  preorden,
}

/// Componente visual reutilizable para tarjetas de platillos en el menú.
///
/// RELACIÓN ARQUITECTÓNICA DEL SISTEMA (HU16-RF02 Criterio 3):
/// El catálogo del menú se define y administra una única vez por el administrador
/// del restaurante (HU24) utilizando los modelos [PlatilloModel] y [CategoriaModel]
/// guardados en Firebase Firestore (`restaurants/{id}/platillos`).
///
/// Este mismo componente visual y los mismos servicios de catálogo se consumen
/// desde dos flujos independientes sin duplicar consultas ni crear estructuras de datos separadas:
/// 1. Flujo de consulta pública del restaurante (HU06-RF03): se utiliza en [PlatilloCardMode.readOnly].
/// 2. Flujo de preparación y preorden de la reserva (HU16-RF02): se utiliza en [PlatilloCardMode.preorden].
class PlatilloMenuCard extends StatelessWidget {
  final PlatilloModel platillo;
  final PlatilloCardMode mode;
  final int cantidad;
  final VoidCallback? onAgregar;
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
    this.onAgregar,
    this.onIncrementar,
    this.onDecrementar,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPreorden = mode == PlatilloCardMode.preorden;

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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen o icono representativo
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
                          errorBuilder: (context, error, stackTrace) => const Icon(
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

                        // Controles de adición / cantidad exclusivos de HU16-RF02
                        if (isPreorden) ...[
                          if (cantidad <= 0)
                            FilledButton.tonalIcon(
                              key: ValueKey('btn_agregar_platillo_${platillo.id}'),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: _primaryTerracotta.withAlpha(25),
                                foregroundColor: _primaryTerracotta,
                              ),
                              onPressed: onAgregar,
                            )
                          else
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
                                    key: ValueKey('btn_decrementar_platillo_${platillo.id}'),
                                    icon: const Icon(Icons.remove, size: 16),
                                    color: _primaryTerracotta,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: onDecrementar,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '$cantidad',
                                      key: ValueKey('txt_cantidad_platillo_${platillo.id}'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: ValueKey('btn_incrementar_platillo_${platillo.id}'),
                                    icon: const Icon(Icons.add, size: 16),
                                    color: _primaryTerracotta,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: onIncrementar,
                                  ),
                                ],
                              ),
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

