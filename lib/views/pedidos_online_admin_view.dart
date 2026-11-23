import 'package:flutter/material.dart';

import '../models/anticipo_reserva.dart';
import '../models/pedido_model.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import 'widgets/transferencia_widgets.dart';

/// Pedidos a domicilio y para recoger que llegan al restaurante, en tiempo real.
class PedidosOnlineAdminView extends StatefulWidget {
  final String restaurantId;
  final PedidoService? service;

  const PedidosOnlineAdminView({
    super.key,
    required this.restaurantId,
    this.service,
  });

  @override
  State<PedidosOnlineAdminView> createState() => _PedidosOnlineAdminViewState();
}

class _PedidosOnlineAdminViewState extends State<PedidosOnlineAdminView> {
  late final PedidoService _service = widget.service ?? PedidoService();
  late final Stream<List<PedidoModel>> _stream =
      _service.pedidosDelRestaurante(widget.restaurantId);
  bool _verHistorial = false;

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await accion();
      messenger.showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'No se pudo actualizar el pedido.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmarCancelar(PedidoModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: Text('¿Cancelar el pedido de ${p.contactoNombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(
            key: const ValueKey('btn_confirmar_cancelar_pedido'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _ejecutar(
      () => _service.cambiarEstado(p.id, PedidoModel.estadoCancelado),
      'Pedido cancelado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.fondo,
      child: StreamBuilder<List<PedidoModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text(
                'No se pudieron cargar los pedidos.',
                key: ValueKey('pedidos_online_error'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final todos = snap.data!;
          final activos = todos.where((p) => !p.estaCerrado).toList();
          final historial = todos.where((p) => p.estaCerrado).toList();
          final lista = _verHistorial ? historial : activos;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Domicilio y recoger',
                        style: TextStyle(
                          fontFamily: AppTheme.familiaTitulos,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pedidos en línea de tus clientes. Se actualizan solos.',
                        style: TextStyle(fontSize: 13.5, color: AppColors.textoSuave),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            key: const ValueKey('filtro_activos'),
                            label: Text('Activos (${activos.length})'),
                            selected: !_verHistorial,
                            onSelected: (_) => setState(() => _verHistorial = false),
                          ),
                          ChoiceChip(
                            key: const ValueKey('filtro_historial'),
                            label: Text('Historial (${historial.length})'),
                            selected: _verHistorial,
                            onSelected: (_) => setState(() => _verHistorial = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (lista.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            _verHistorial
                                ? 'Aún no hay pedidos terminados.'
                                : 'No hay pedidos activos. Cuando un cliente pida, aparecerá aquí.',
                            key: const ValueKey('pedidos_online_vacio'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textoSuave),
                          ),
                        )
                      else
                        for (final p in lista)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TarjetaPedido(
                              pedido: p,
                              onAvanzar: () => _ejecutar(
                                () => _service.cambiarEstado(p.id, p.siguienteEstado!),
                                'Pedido actualizado.',
                              ),
                              onCancelar: () => _confirmarCancelar(p),
                              onConfirmarPago: () => _ejecutar(
                                () => _service.confirmarPago(p.id),
                                'Pago confirmado.',
                              ),
                              onRechazarPago: () => _ejecutar(
                                () => _service.rechazarPago(p.id),
                                'Comprobante rechazado. El cliente puede subir otro.',
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  final PedidoModel pedido;
  final VoidCallback onAvanzar;
  final VoidCallback onCancelar;
  final VoidCallback onConfirmarPago;
  final VoidCallback onRechazarPago;

  const _TarjetaPedido({
    required this.pedido,
    required this.onAvanzar,
    required this.onCancelar,
    required this.onConfirmarPago,
    required this.onRechazarPago,
  });

  static String _hora(DateTime? d) {
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color get _colorEstado {
    switch (pedido.estado) {
      case PedidoModel.estadoCancelado:
        return AppColors.error;
      case PedidoModel.estadoEntregado:
        return AppColors.exito;
      case PedidoModel.estadoRecibido:
        return AppColors.acento;
      default:
        return AppColors.marca;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final siguiente = p.siguienteEstado;
    final concepto = ConceptoTransferencia.generar(
      prefijo: 'PED',
      id: p.id,
      nombre: p.contactoNombre,
    );
    return Container(
      key: ValueKey('pedido_${p.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divisor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                p.esDomicilio ? Icons.delivery_dining_outlined : Icons.storefront_outlined,
                color: AppColors.marca,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${p.contactoNombre} · ${_hora(p.creadoEn)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _colorEstado.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.etiquetaEstadoActual,
                  key: ValueKey('estado_${p.id}'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _colorEstado,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${p.esDomicilio ? 'A domicilio' : 'Para recoger'} · ${p.contactoTelefono} · $concepto',
            style: const TextStyle(fontSize: 13, color: AppColors.textoSuave),
          ),
          if (p.esDomicilio) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, size: 17, color: AppColors.marca),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.referencias.isEmpty ? p.direccion : '${p.direccion} (${p.referencias})',
                    key: ValueKey('direccion_${p.id}'),
                    style: const TextStyle(fontSize: 14, color: AppColors.texto),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 22),
          for (final l in p.lineas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text('${l.cantidad} × ${l.nombre}')),
                  Text(formatoDinero(l.total)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(
                formatoDinero(p.total),
                key: ValueKey('total_${p.id}'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                p.pagoConfirmadoOk ? Icons.check_circle_outline : Icons.payments_outlined,
                size: 18,
                color: p.pagoConfirmadoOk ? AppColors.exito : AppColors.acento,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.etiquetaPagoActual,
                  key: ValueKey('pago_${p.id}'),
                  style: const TextStyle(fontSize: 13.5, color: AppColors.texto),
                ),
              ),
            ],
          ),
          if (p.esTransferencia &&
              (p.estadoPago == PedidoModel.pagoComprobanteEnviado ||
                  p.estadoPago == PedidoModel.pagoConfirmado)) ...[
            const SizedBox(height: 8),
            ComprobanteVisor(tipo: 'pedido', refId: p.id),
          ],
          if (!p.estaCerrado) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (siguiente != null)
                  FilledButton(
                    key: ValueKey('avanzar_${p.id}'),
                    onPressed: onAvanzar,
                    child: Text(
                      'Pasar a: ${PedidoModel.etiquetaEstado(siguiente, tipoEntrega: p.tipoEntrega)}',
                    ),
                  ),
                if (!p.pagoConfirmadoOk &&
                    (!p.esTransferencia || p.estadoPago == PedidoModel.pagoComprobanteEnviado))
                  OutlinedButton(
                    key: ValueKey('confirmar_pago_${p.id}'),
                    onPressed: onConfirmarPago,
                    child: Text(p.esTransferencia ? 'Confirmar pago' : 'Marcar cobrado'),
                  ),
                if (p.esTransferencia && p.estadoPago == PedidoModel.pagoComprobanteEnviado)
                  OutlinedButton(
                    key: ValueKey('rechazar_pago_${p.id}'),
                    onPressed: onRechazarPago,
                    child: const Text('Rechazar comprobante'),
                  ),
                TextButton(
                  key: ValueKey('cancelar_${p.id}'),
                  onPressed: onCancelar,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Cancelar pedido'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Resumen para el dashboard: cuántos pedidos esperan y acceso directo a la lista.
class PedidosOnlineResumen extends StatelessWidget {
  final String restaurantId;
  final VoidCallback onVer;
  final PedidoService? service;

  const PedidosOnlineResumen({
    super.key,
    required this.restaurantId,
    required this.onVer,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    final servicio = service ?? PedidoService();
    return StreamBuilder<List<PedidoModel>>(
      stream: servicio.pedidosDelRestaurante(restaurantId),
      builder: (context, snap) {
        final todos = snap.data ?? const <PedidoModel>[];
        final nuevos = todos.where((p) => p.estado == PedidoModel.estadoRecibido).length;
        final activos = todos.where((p) => !p.estaCerrado).length;
        return Material(
          color: nuevos > 0 ? const Color(0xFFFFF7E6) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: nuevos > 0 ? AppColors.acento : AppColors.divisor),
          ),
          child: InkWell(
            key: const ValueKey('resumen_pedidos_online'),
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: onVer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
              children: [
                const Icon(Icons.delivery_dining_outlined, color: AppColors.marca, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nuevos > 0
                            ? '$nuevos pedido${nuevos == 1 ? '' : 's'} nuevo${nuevos == 1 ? '' : 's'}'
                            : 'Sin pedidos nuevos',
                        key: const ValueKey('resumen_pedidos_texto'),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.texto),
                      ),
                      Text(
                        '$activos activo${activos == 1 ? '' : 's'} · domicilio y recoger',
                        style: const TextStyle(fontSize: 13, color: AppColors.textoSuave),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textoSuave),
              ],
              ),
            ),
          ),
        );
      },
    );
  }
}
