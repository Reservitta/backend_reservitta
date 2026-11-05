import 'package:flutter/material.dart';

import '../models/platillo_model.dart';
import '../models/reservation_draft_model.dart';
import '../models/restaurant_model.dart';
import '../viewmodels/pedido_viewmodel.dart';
import 'widgets/platillo_detalle_sheet.dart';

/// Pantalla "Mi pedido" (HU16-RF06)
///
/// Criterios de aceptación:
/// - Se accede desde "Ver mi pedido (n platillos)" (solo usuarios con sesión).
/// - Muestra el resumen de la reserva de solo lectura.
/// - Lista cada platillo con imagen, nombre, cantidad × precio unitario, precio total de línea y observación (si existe).
/// - Cada línea tiene "Editar" y "Eliminar" (con diálogo de confirmación).
/// - Muestra el "Subtotal" general del pedido.
/// - Botón "Agregar más platillos" que regresa al listado conservando lo agregado.
/// - Botón "Continuar" que avanza a la pantalla/sección de ocasión especial (HU18).
class MiPedidoView extends StatefulWidget {
  final RestaurantModel restaurant;
  final ReservationDraftModel draft;
  final PedidoViewModel pedidoViewModel;
  final Map<String, PlatilloModel> catalogoPorId;
  final VoidCallback? onAgregarMasPlatillos;
  final VoidCallback? onContinuarOcasion;

  const MiPedidoView({
    super.key,
    required this.restaurant,
    required this.draft,
    required this.pedidoViewModel,
    this.catalogoPorId = const {},
    this.onAgregarMasPlatillos,
    this.onContinuarOcasion,
  });

  static const Color primaryTerracotta = Color(0xFFB34A26);
  static const Color lightBg = Color(0xFFFBF8F4);
  static const Color cardBorder = Color(0xFFEDE4D8);
  static const Color textDark = Color(0xFF2E241E);
  static const Color textMuted = Color(0xFF7A6E65);

  @override
  State<MiPedidoView> createState() => _MiPedidoViewState();
}

class _MiPedidoViewState extends State<MiPedidoView> {
  Future<void> _editarItem(PedidoItem item) async {
    final platillo = widget.catalogoPorId[item.platilloId] ??
        PlatilloModel(
          id: item.platilloId,
          categoriaId: item.categoriaId,
          nombre: item.nombre,
          descripcion: item.descripcion,
          precio: item.precio,
          imagenUrl: item.imagenUrl,
          etiquetas: item.etiquetas,
        );

    await PlatilloDetalleSheet.show(
      context,
      platillo: platillo,
      pedidoViewModel: widget.pedidoViewModel,
    );
  }

  Future<void> _confirmarEliminarItem(PedidoItem item) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('dialog_confirmar_eliminar'),
        title: const Text('¿Eliminar platillo?'),
        content: Text(
          '¿Seguro que deseas eliminar "${item.nombre}" de tu pedido?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('btn_cancelar_eliminar'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('btn_confirmar_eliminar'),
            style: FilledButton.styleFrom(
              backgroundColor: MiPedidoView.primaryTerracotta,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      widget.pedidoViewModel.eliminarPlatillo(item.platilloId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pedidoViewModel,
      builder: (context, _) {
        final items = widget.pedidoViewModel.items;

        return Scaffold(
          backgroundColor: MiPedidoView.lightBg,
          appBar: AppBar(
            backgroundColor: MiPedidoView.lightBg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MiPedidoView.textDark),
              onPressed: () {
                if (widget.onAgregarMasPlatillos != null) {
                  widget.onAgregarMasPlatillos!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: const Text(
              'Mi pedido',
              style: TextStyle(
                color: MiPedidoView.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Resumen de la reserva de solo lectura (HU16-RF06 Criterio 2)
              _buildResumenReservaReadOnly(),
              const SizedBox(height: 16),

              // Título de la sección de platillos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Platillos preordenados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MiPedidoView.textDark,
                    ),
                  ),
                  Text(
                    '${widget.pedidoViewModel.totalCantidad} ${widget.pedidoViewModel.totalCantidad == 1 ? "porción" : "porciones"}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MiPedidoView.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Lista de platillos o estado vacío
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MiPedidoView.cardBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'Tu pedido está vacío. Agrega platillos para continuar.',
                      style: TextStyle(color: MiPedidoView.textMuted),
                    ),
                  ),
                )
              else
                ...items.map((item) => _buildItemTile(item)),

              const SizedBox(height: 16),

              // 3. Subtotal general del pedido (HU16-RF06 Criterio 5)
              _buildSubtotalCard(),

              const SizedBox(height: 24),
            ],
          ),
          bottomNavigationBar: _buildBottomActions(),
        );
      },
    );
  }

  /// Resumen de reserva de solo lectura (HU16-RF06 Criterio 2)
  Widget _buildResumenReservaReadOnly() {
    final d = widget.draft;
    final mesasTexto = d.mesasNombres.isNotEmpty
        ? d.mesasNombres.join(', ')
        : (d.mesaIds.isNotEmpty ? d.mesaIds.join(', ') : 'Sin mesa asignada');

    final fechaTexto = d.formattedDate.isNotEmpty
        ? d.formattedDate
        : (d.fecha != null ? '${d.fecha!.day}/${d.fecha!.month}/${d.fecha!.year}' : 'Fecha no definida');

    final horarioTexto = d.formattedTimeRange.isNotEmpty
        ? d.formattedTimeRange
        : (d.horario != null
            ? '${d.horario!.hour.toString().padLeft(2, '0')}:${d.horario!.minute.toString().padLeft(2, '0')}'
            : 'Horario no definido');

    return Container(
      key: const ValueKey('resumen_reserva_mi_pedido'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MiPedidoView.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant,
                size: 18,
                color: MiPedidoView.primaryTerracotta,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.restaurant.nombre,
                  key: const ValueKey('resumen_nombre_restaurante'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: MiPedidoView.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MiPedidoView.lightBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: MiPedidoView.cardBorder),
                ),
                child: const Text(
                  'Solo lectura',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MiPedidoView.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: MiPedidoView.cardBorder),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.calendar_today_outlined, 'Fecha:', fechaTexto, 'resumen_fecha'),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.schedule, 'Horario:', horarioTexto, 'resumen_horario'),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.people_outline, 'Personas:', '${d.personas} personas', 'resumen_personas'),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.table_restaurant_outlined, 'Mesa:', mesasTexto, 'resumen_mesas'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, String keySuffix) {
    return Row(
      children: [
        Icon(icon, size: 14, color: MiPedidoView.textMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: MiPedidoView.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            key: ValueKey(keySuffix),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: MiPedidoView.textDark,
            ),
          ),
        ),
      ],
    );
  }

  /// Lista cada platillo con imagen, nombre, cantidad × precio unitario, precio total de línea y observación (HU16-RF06 Criterio 3)
  Widget _buildItemTile(PedidoItem item) {
    return Container(
      key: ValueKey('mi_pedido_item_${item.platilloId}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MiPedidoView.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Imagen del platillo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: MiPedidoView.lightBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MiPedidoView.cardBorder),
                ),
                child: item.imagenUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item.imagenUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.fastfood_outlined,
                            color: MiPedidoView.primaryTerracotta,
                            size: 26,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.fastfood_outlined,
                        color: MiPedidoView.primaryTerracotta,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 12),

              // 2. Nombre, desglose de precio y total
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre,
                      key: ValueKey('mi_pedido_item_nombre_${item.platilloId}'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: MiPedidoView.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Cantidad × precio unitario
                    Text(
                      '${item.cantidad} × \$${item.precio.toStringAsFixed(2)} MXN',
                      key: ValueKey('mi_pedido_item_desglose_${item.platilloId}'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: MiPedidoView.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Precio total de línea
                    Text(
                      'Total: \$${item.total.toStringAsFixed(2)} MXN',
                      key: ValueKey('mi_pedido_item_total_${item.platilloId}'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: MiPedidoView.primaryTerracotta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Observación si existe
          if (item.observacion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              key: ValueKey('mi_pedido_item_observacion_${item.platilloId}'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MiPedidoView.lightBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MiPedidoView.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.note_alt_outlined,
                    size: 14,
                    color: MiPedidoView.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Observación: ${item.observacion}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: MiPedidoView.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, color: MiPedidoView.cardBorder),
          const SizedBox(height: 6),

          // 4. Acciones: Editar y Eliminar (HU16-RF06 Criterio 4)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: ValueKey('btn_editar_${item.platilloId}'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
                style: TextButton.styleFrom(
                  foregroundColor: MiPedidoView.primaryTerracotta,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _editarItem(item),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: ValueKey('btn_eliminar_${item.platilloId}'),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Eliminar'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _confirmarEliminarItem(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Subtotal general del pedido (HU16-RF06 Criterio 5)
  Widget _buildSubtotalCard() {
    return Container(
      key: const ValueKey('card_subtotal_mi_pedido'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MiPedidoView.primaryTerracotta.withAlpha(80)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Subtotal general:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: MiPedidoView.textDark,
            ),
          ),
          Text(
            '\$${widget.pedidoViewModel.subtotal.toStringAsFixed(2)} MXN',
            key: const ValueKey('texto_subtotal_general'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: MiPedidoView.primaryTerracotta,
            ),
          ),
        ],
      ),
    );
  }

  /// Botones "Agregar más platillos" (HU16-RF06 Criterio 6) y "Continuar" (HU16-RF06 Criterio 7)
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: MiPedidoView.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón "Continuar" que avanza a la pantalla de ocasión especial (HU18)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const ValueKey('btn_continuar_ocasion'),
                style: FilledButton.styleFrom(
                  backgroundColor: MiPedidoView.primaryTerracotta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (widget.onContinuarOcasion != null) {
                    widget.onContinuarOcasion!();
                  } else {
                    Navigator.of(context).pop('ir_a_ocasion');
                  }
                },
                child: const Text(
                  'Continuar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Botón "Agregar más platillos" que regresa al listado conservando lo ya agregado
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                key: const ValueKey('btn_agregar_mas_platillos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MiPedidoView.primaryTerracotta,
                  side: const BorderSide(color: MiPedidoView.primaryTerracotta),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (widget.onAgregarMasPlatillos != null) {
                    widget.onAgregarMasPlatillos!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text(
                  'Agregar más platillos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
