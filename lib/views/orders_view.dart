import 'package:flutter/material.dart';

import '../models/order_status_flow.dart';
import '../models/reservation_model.dart';
import '../viewmodels/admin_operations_viewmodel.dart';
import 'widgets/arrival_alert_widgets.dart';
import 'widgets/order_state_control.dart';

/// Vista de cocina y pedidos (HU29-RF02): los pedidos preordenados del día con un
/// control de un toque para avanzar su estado. Cualquier cambio se refleja en tiempo
/// real en los demás dispositivos del restaurante que tengan abierta esta pantalla.
class OrdersView extends StatelessWidget {
  final AdminOperationsViewModel operaciones;
  final void Function(ReservationModel reserva) onAbrirReserva;

  const OrdersView({
    super.key,
    required this.operaciones,
    required this.onAbrirReserva,
  });

  static const Color _terracotta = Color(0xFFB34A26);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _cardBorder = Color(0xFFEDE4D8);

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: operaciones,
      builder: (context, _) {
        if (operaciones.cargando) {
          return const Center(
            child: CircularProgressIndicator(
              key: ValueKey('pedidos_cargando'),
              color: _terracotta,
            ),
          );
        }
        final pedidos = operaciones.pedidos;
        return RefreshIndicator(
          color: _terracotta,
          onRefresh: operaciones.refrescar,
          child: ListView(
            key: const ValueKey('pedidos_contenido'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Pedidos',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Preórdenes de las reservas de hoy.',
                        style: TextStyle(fontSize: 13.5, color: _textMuted),
                      ),
                      const SizedBox(height: 18),
                      if (operaciones.error != null)
                        Text(
                          operaciones.error!,
                          key: const ValueKey('pedidos_error'),
                          style: const TextStyle(color: Colors.red),
                        )
                      else if (pedidos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No hay pedidos preordenados para hoy.',
                            key: ValueKey('pedidos_vacio'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _textMuted),
                          ),
                        )
                      else
                        for (final r in pedidos)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PedidoCard(
                              reserva: r,
                              operaciones: operaciones,
                              onAbrirReserva: onAbrirReserva,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PedidoCard extends StatelessWidget {
  final ReservationModel reserva;
  final AdminOperationsViewModel operaciones;
  final void Function(ReservationModel reserva) onAbrirReserva;

  const _PedidoCard({
    required this.reserva,
    required this.operaciones,
    required this.onAbrirReserva,
  });

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    final alerta = operaciones.alertaDe(r.id);
    final platillos = r.preordenItems.fold<int>(
      0,
      (a, i) => a + ((i['cantidad'] as num?)?.toInt() ?? 1),
    );
    final cliente = r.contactoNombre.trim().isEmpty ? 'Cliente' : r.contactoNombre.trim();
    final mesa = r.mesasNombres.isEmpty ? 'Sin mesa' : r.mesasNombres.join(' + ');

    return Container(
      key: ValueKey('pedido_${r.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrdersView._cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('pedido_abrir_${r.id}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => onAbrirReserva(r),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${OrdersView._hora(r.effectiveStart)} · $cliente',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: OrdersView._textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$mesa · ${r.personas} pers. · $platillos platillo${platillos == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 13, color: OrdersView._textMuted),
                      ),
                    ],
                  ),
                ),
                KeyedSubtree(
                  key: ValueKey('pedido_estado_${r.id}'),
                  child: OrderStateBadge(estado: r.estadoPreorden),
                ),
              ],
            ),
          ),
          if (alerta != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ArrivalAlertChip(alerta: alerta),
            ),
          ],
          if (r.tieneRestriccionesOAlergias) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC62828)),
                SizedBox(width: 6),
                Text(
                  'Alergias o restricciones',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFFC62828)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (OrderStateMachine.siguiente(r.estadoPreorden) == null &&
              OrderStateMachine.anterior(r.estadoPreorden) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Listo para servir${r.estadoOperativo == ReservationModel.estadoPendienteLlegada ? ' · esperando al cliente' : ''}',
                key: ValueKey('pedido_listo_${r.id}'),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF2E7D32)),
              ),
            ),
          OrderStateControl(
            reservaId: r.id,
            estadoActual: r.estadoPreorden,
            onChange: (nuevo, {motivo}) =>
                operaciones.cambiarEstadoPedido(r.id, nuevo, motivo: motivo),
          ),
        ],
      ),
    );
  }
}
