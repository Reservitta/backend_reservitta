import 'package:flutter/material.dart';

import '../../models/order_status_flow.dart';
import '../../models/reservation_model.dart';
import '../../theme/app_theme.dart';

/// Color, ícono y etiqueta de cada estado del pedido (HU29-RF02). El ícono y el texto
/// acompañan al color para que el estado no dependa solo de él.
class OrderStateStyle {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
  final String label;

  const OrderStateStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  static OrderStateStyle of(String estado) {
    final e = OrderStateMachine.normalizar(estado);
    switch (e) {
      case OrderStateMachine.enPreparacion:
        return const OrderStateStyle(
          background: Color(0xFFE3F2FD),
          border: Color(0xFF90CAF9),
          foreground: Color(0xFF1565C0),
          icon: Icons.soup_kitchen_outlined,
          label: 'En preparación',
        );
      case OrderStateMachine.listo:
        return const OrderStateStyle(
          background: Color(0xFFE8F5E9),
          border: Color(0xFFA5D6A7),
          foreground: AppColors.exito,
          icon: Icons.check_circle_outline,
          label: 'Listo',
        );
      case ReservationModel.preordenEntregado:
        return const OrderStateStyle(
          background: Color(0xFFECEFF1),
          border: Color(0xFFB0BEC5),
          foreground: Color(0xFF455A64),
          icon: Icons.task_alt_rounded,
          label: 'Entregado',
        );
      case ReservationModel.preordenCancelado:
        return const OrderStateStyle(
          background: Color(0xFFFFEBEE),
          border: Color(0xFFEF9A9A),
          foreground: Color(0xFFC62828),
          icon: Icons.cancel_outlined,
          label: 'Cancelado',
        );
      default:
        return const OrderStateStyle(
          background: Color(0xFFFFF3D6),
          border: Color(0xFFE0A100),
          foreground: Color(0xFF7A5A00),
          icon: Icons.hourglass_empty_rounded,
          label: 'Pendiente',
        );
    }
  }
}

/// Etiqueta con el estado del pedido.
class OrderStateBadge extends StatelessWidget {
  final String estado;

  const OrderStateBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final s = OrderStateStyle.of(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 14, color: s.foreground),
          const SizedBox(width: 5),
          Text(
            s.label,
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

/// Control del estado del pedido (HU29-RF02): un botón grande avanza al siguiente
/// estado con un solo toque y, si hace falta, un enlace regresa un paso pidiendo el motivo.
class OrderStateControl extends StatefulWidget {
  final String reservaId;
  final String estadoActual;

  /// Aplica el cambio; devuelve un mensaje de error o null si se aplicó.
  final Future<String?> Function(String nuevoEstado, {String? motivo}) onChange;

  const OrderStateControl({
    super.key,
    required this.reservaId,
    required this.estadoActual,
    required this.onChange,
  });

  @override
  State<OrderStateControl> createState() => _OrderStateControlState();
}

class _OrderStateControlState extends State<OrderStateControl> {
  bool _procesando = false;

  Future<void> _aplicar(String nuevo, {String? motivo}) async {
    setState(() => _procesando = true);
    final error = await widget.onChange(nuevo, motivo: motivo);
    if (!mounted) return;
    setState(() => _procesando = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          key: const ValueKey('snack_pedido_error'),
          content: Text(error),
        ));
    }
  }

  Future<void> _regresar(String anterior) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => _MotivoReversaDialog(destino: anterior),
    );
    if (motivo == null || !mounted) return;
    await _aplicar(anterior, motivo: motivo);
  }

  @override
  Widget build(BuildContext context) {
    final estado = OrderStateMachine.normalizar(widget.estadoActual);
    final siguiente = OrderStateMachine.siguiente(estado);
    final anterior = OrderStateMachine.anterior(estado);

    if (siguiente == null && anterior == null) {
      return const SizedBox.shrink();
    }

    final textoAvance = siguiente == OrderStateMachine.listo
        ? 'Marcar como listo'
        : 'Empezar a preparar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (siguiente != null)
          FilledButton.icon(
            key: ValueKey('btn_pedido_avanzar_${widget.reservaId}'),
            style: FilledButton.styleFrom(
              backgroundColor: OrderStateStyle.of(siguiente).foreground,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _procesando ? null : () => _aplicar(siguiente),
            icon: _procesando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(OrderStateStyle.of(siguiente).icon),
            label: Text(textoAvance),
          ),
        if (anterior != null)
          TextButton(
            key: ValueKey('btn_pedido_regresar_${widget.reservaId}'),
            onPressed: _procesando ? null : () => _regresar(anterior),
            child: Text('Regresar a "${OrderStateMachine.etiqueta(anterior)}"'),
          ),
      ],
    );
  }
}

/// Pide el motivo para regresar el pedido un paso. El controlador vive en el propio
/// diálogo para liberarse cuando termina su animación de cierre.
class _MotivoReversaDialog extends StatefulWidget {
  final String destino;

  const _MotivoReversaDialog({required this.destino});

  @override
  State<_MotivoReversaDialog> createState() => _MotivoReversaDialogState();
}

class _MotivoReversaDialogState extends State<_MotivoReversaDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('dialogo_reversa_pedido'),
      title: Text('Regresar a "${OrderStateMachine.etiqueta(widget.destino)}"'),
      content: TextField(
        key: const ValueKey('campo_motivo_reversa'),
        controller: _ctrl,
        autofocus: true,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Motivo',
          hintText: 'Por qué se regresa el pedido',
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('btn_cancelar_reversa'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('btn_confirmar_reversa'),
          onPressed: () {
            final texto = _ctrl.text.trim();
            if (texto.isEmpty) return;
            Navigator.of(context).pop(texto);
          },
          child: const Text('Regresar'),
        ),
      ],
    );
  }
}
