import 'package:flutter/material.dart';
import '../../services/preorden_cache_service.dart';

/// Modal bottom sheet para consultar, revisar y gestionar los platillos en la preorden en caché (HU24-RF05, HU16).
/// Muestra los platillos agregados, sus precios, cantidades y las notas personalizadas del cliente.
class PreordenResumenSheet extends StatelessWidget {
  final String restaurantId;
  final String restaurantNombre;
  final PreordenCacheService cacheService;

  PreordenResumenSheet({
    super.key,
    required this.restaurantId,
    required this.restaurantNombre,
    PreordenCacheService? cacheService,
  }) : cacheService = cacheService ?? PreordenCacheService();

  static void show(
    BuildContext context, {
    required String restaurantId,
    required String restaurantNombre,
    PreordenCacheService? cacheService,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PreordenResumenSheet(
        restaurantId: restaurantId,
        restaurantNombre: restaurantNombre,
        cacheService: cacheService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cacheService,
      builder: (context, _) {
        final items = cacheService.obtenerItems(restaurantId);
        final total = cacheService.obtenerTotal(restaurantId);
        final totalPorciones = cacheService.contarItems(restaurantId);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior de arrastre
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Cabecera con título y contador
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF3FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFF1E5288),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preorden en Caché',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E241E),
                            ),
                          ),
                          Text(
                            items.isEmpty
                                ? 'No hay platillos en la preorden'
                                : '$totalPorciones porciones en $restaurantNombre',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          cacheService.limpiar(restaurantId);
                        },
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('Vaciar'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD84A38),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Lista de platillos en caché
              Flexible(
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Aún no has agregado platillos a tu preorden.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7A6E65),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final item = items[idx];
                          final nombre = item['nombre'] as String? ?? 'Platillo';
                          final cantidad = item['cantidad'] as int? ?? 1;
                          final subtotal = (item['total'] as num?)?.toDouble() ?? 0.0;
                          final observacion = (item['observacion'] as String? ?? '').trim();

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5ED),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFEDE4D8)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$cantidad x $nombre',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5,
                                              color: Color(0xFF2E241E),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '\$${subtotal.toStringAsFixed(2)} MXN',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFFB34A26),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFD84A38),
                                        size: 20,
                                      ),
                                      tooltip: 'Quitar de la preorden',
                                      onPressed: () => cacheService.eliminarItem(restaurantId, idx),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                // Nota de personalización del cliente (HU24-RF05)
                                if (observacion.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEBF3FA),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFB8D0E8)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.tune_rounded,
                                          size: 14,
                                          color: Color(0xFF1E5288),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Nota: "$observacion"',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Color(0xFF0F3660),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Pie con total y botón de cierre
              if (items.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total estimado:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7A6E65),
                            ),
                          ),
                          Text(
                            '\$${total.toStringAsFixed(2)} MXN',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB34A26),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE4572E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Entendido'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
