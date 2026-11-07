import 'package:flutter/material.dart';

import '../../models/reservation_model.dart';
import '../../models/reservation_status_flow.dart';

/// Colores e ícono de cada estado operativo de una reserva (HU27-RF02).
class ReservationStateStyle {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  const ReservationStateStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  static ReservationStateStyle of(String estado) {
    switch (ReservationStateMachine.normalizar(estado)) {
      case ReservationModel.estadoClienteLlego:
        return const ReservationStateStyle(
          background: Color(0xFFE3F2FD),
          border: Color(0xFF90CAF9),
          foreground: Color(0xFF1565C0),
          icon: Icons.how_to_reg_rounded,
        );
      case ReservationModel.estadoEnServicio:
        return const ReservationStateStyle(
          background: Color(0xFFE8F5E9),
          border: Color(0xFFA5D6A7),
          foreground: Color(0xFF2E7D32),
          icon: Icons.restaurant_rounded,
        );
      case ReservationModel.estadoFinalizada:
        return const ReservationStateStyle(
          background: Color(0xFFECEFF1),
          border: Color(0xFFB0BEC5),
          foreground: Color(0xFF455A64),
          icon: Icons.task_alt_rounded,
        );
      case ReservationModel.estadoCancelada:
        return const ReservationStateStyle(
          background: Color(0xFFFFEBEE),
          border: Color(0xFFEF9A9A),
          foreground: Color(0xFFC62828),
          icon: Icons.cancel_outlined,
        );
      case ReservationModel.estadoNoShow:
        return const ReservationStateStyle(
          background: Color(0xFFF3E5F5),
          border: Color(0xFFCE93D8),
          foreground: Color(0xFF6A1B9A),
          icon: Icons.person_off_outlined,
        );
      case ReservationModel.estadoPendienteLlegada:
      default:
        return const ReservationStateStyle(
          background: Color(0xFFFFF8E1),
          border: Color(0xFFFFE082),
          foreground: Color(0xFFB26A00),
          icon: Icons.schedule_rounded,
        );
    }
  }
}

/// Texto de la acción que lleva a cada estado.
String accionParaEstado(String destino) {
  switch (ReservationStateMachine.normalizar(destino)) {
    case ReservationModel.estadoClienteLlego:
      return 'Marcar llegada';
    case ReservationModel.estadoEnServicio:
      return 'Iniciar servicio';
    case ReservationModel.estadoFinalizada:
      return 'Finalizar';
    case ReservationModel.estadoCancelada:
      return 'Cancelar reserva';
    case ReservationModel.estadoNoShow:
      return 'No se presentó';
    default:
      return ReservationModel.etiquetaParaEstado(destino);
  }
}

/// Control para cambiar el estado de una reserva (HU27-RF02): solo ofrece las
/// transiciones válidas desde el estado actual y pide confirmación antes de
/// cancelar o marcar como no-show.
///
/// [onChange] recibe el estado destino y devuelve un mensaje de error, o null si
/// el cambio se aplicó.
class ReservationStateControl extends StatefulWidget {
  final String reservaId;
  final String estadoActual;
  final Future<String?> Function(String nuevoEstado) onChange;

  /// Versión compacta (menú) para las filas del listado.
  final bool compacto;

  const ReservationStateControl({
    super.key,
    required this.reservaId,
    required this.estadoActual,
    required this.onChange,
    this.compacto = false,
  });

  @override
  State<ReservationStateControl> createState() => _ReservationStateControlState();
}

class _ReservationStateControlState extends State<ReservationStateControl> {
  bool _cambiando = false;

  Future<void> _seleccionar(String destino) async {
    if (ReservationStateMachine.requiereConfirmacion(destino)) {
      final confirmado = await _confirmar(destino);
      if (confirmado != true || !mounted) return;
    }
    setState(() => _cambiando = true);
    final error = await widget.onChange(destino);
    if (!mounted) return;
    setState(() => _cambiando = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          key: const ValueKey('snack_cambio_estado_error'),
          content: Text(error),
        ));
    }
  }

  Future<bool?> _confirmar(String destino) {
    final esCancelar =
        ReservationStateMachine.normalizar(destino) == ReservationModel.estadoCancelada;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: ValueKey('dialogo_confirmar_estado_${widget.reservaId}'),
        title: Text(esCancelar ? '¿Cancelar esta reserva?' : '¿Marcar como no-show?'),
        content: Text(esCancelar
            ? 'La reserva quedará cancelada y se liberará la mesa. Esta acción no se puede deshacer.'
            : 'Se registrará que el cliente no se presentó y se liberará la mesa. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            key: const ValueKey('boton_volver_estado'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const ValueKey('boton_confirmar_estado'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(esCancelar ? 'Sí, cancelar' : 'Sí, no se presentó'),
          ),
        ],
      ),
    );
  }

  bool _esPeligrosa(String destino) =>
      ReservationStateMachine.requiereConfirmacion(destino);

  @override
  Widget build(BuildContext context) {
    final siguientes = ReservationStateMachine.siguientes(widget.estadoActual);
    if (siguientes.isEmpty) return const SizedBox.shrink();

    if (_cambiando) {
      return const Center(
        child: SizedBox(
          key: ValueKey('cambiando_estado'),
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (widget.compacto) {
      return PopupMenuButton<String>(
        key: ValueKey('menu_estado_${widget.reservaId}'),
        tooltip: 'Cambiar estado',
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        onSelected: _seleccionar,
        itemBuilder: (_) => [
          for (final destino in siguientes)
            PopupMenuItem<String>(
              key: ValueKey('opcion_estado_$destino'),
              value: destino,
              child: Row(
                children: [
                  Icon(ReservationStateStyle.of(destino).icon,
                      size: 18, color: ReservationStateStyle.of(destino).foreground),
                  const SizedBox(width: 10),
                  Text(accionParaEstado(destino)),
                ],
              ),
            ),
        ],
      );
    }

    return Wrap(
      key: const ValueKey('control_estado'),
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final destino in siguientes)
          _esPeligrosa(destino)
              ? OutlinedButton.icon(
                  key: ValueKey('boton_estado_$destino'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFEF9A9A)),
                  ),
                  onPressed: () => _seleccionar(destino),
                  icon: Icon(ReservationStateStyle.of(destino).icon, size: 18),
                  label: Text(accionParaEstado(destino)),
                )
              : FilledButton.icon(
                  key: ValueKey('boton_estado_$destino'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB34A26),
                  ),
                  onPressed: () => _seleccionar(destino),
                  icon: Icon(ReservationStateStyle.of(destino).icon, size: 18),
                  label: Text(accionParaEstado(destino)),
                ),
      ],
    );
  }
}
