import 'package:flutter/material.dart';

import '../models/anticipo_reserva.dart';
import '../models/payment_config.dart';
import '../models/pedido_model.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import 'widgets/transferencia_widgets.dart';

/// Seguimiento del pedido en tiempo real: en qué paso va y, si paga por transferencia,
/// los datos para pagar y el espacio para subir el comprobante.
class PedidoSeguimientoView extends StatefulWidget {
  final String pedidoId;
  final DatosBancarios cuenta;
  final PedidoService? pedidoService;

  const PedidoSeguimientoView({
    super.key,
    required this.pedidoId,
    this.cuenta = const DatosBancarios(),
    this.pedidoService,
  });

  @override
  State<PedidoSeguimientoView> createState() => _PedidoSeguimientoViewState();
}

class _PedidoSeguimientoViewState extends State<PedidoSeguimientoView> {
  late final PedidoService _service = widget.pedidoService ?? PedidoService();
  late final Stream<PedidoModel?> _stream = _service.seguir(widget.pedidoId);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Tu pedido'),
        ),
        body: StreamBuilder<PedidoModel?>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('No se pudo cargar tu pedido.'));
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final p = snap.data;
            if (p == null) {
              return const Center(child: Text('No encontramos este pedido.'));
            }
            return _contenido(p);
          },
        ),
      ),
    );
  }

  Widget _contenido(PedidoModel p) {
    final cancelado = p.estado == PedidoModel.estadoCancelado;
    final pasos = PedidoModel.flujo(p.tipoEntrega);
    final indice = pasos.indexOf(p.estado);
    final concepto = ConceptoTransferencia.generar(
      prefijo: 'PED',
      id: p.id,
      nombre: p.contactoNombre,
    );
    final porPagar = p.esTransferencia &&
        !p.pagoConfirmadoOk &&
        !cancelado &&
        widget.cuenta.completos;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cancelado ? const Color(0xFFFBE9E7) : AppColors.marcaSuave,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        cancelado ? Icons.cancel_outlined : Icons.receipt_long_outlined,
                        size: 40,
                        color: cancelado ? AppColors.error : AppColors.marca,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.etiquetaEstadoActual,
                        key: const ValueKey('estado_pedido'),
                        style: const TextStyle(
                          fontFamily: AppTheme.familiaTitulos,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cancelado
                            ? 'El restaurante canceló tu pedido. Comunícate con ellos si tienes dudas.'
                            : '${p.restauranteNombre} · ${p.esDomicilio ? 'A domicilio' : 'Para recoger'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textoSuave),
                      ),
                    ],
                  ),
                ),
                if (!cancelado) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _caja(),
                    child: Column(
                      children: [
                        for (var i = 0; i < pasos.length; i++)
                          _Paso(
                            etiqueta: PedidoModel.etiquetaEstado(pasos[i], tipoEntrega: p.tipoEntrega),
                            hecho: i < indice,
                            actual: i == indice,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _caja(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const Divider(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          Text(
                            formatoDinero(p.total),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.etiquetaPagoActual,
                        key: const ValueKey('pago_pedido'),
                        style: const TextStyle(color: AppColors.textoSuave),
                      ),
                      if (p.esDomicilio) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Entrega en: ${p.direccion}',
                          style: const TextStyle(color: AppColors.textoSuave),
                        ),
                      ],
                    ],
                  ),
                ),
                if (porPagar) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _caja(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TransferenciaCard(
                          cuenta: widget.cuenta,
                          monto: p.total,
                          concepto: concepto,
                          titulo: 'Paga tu pedido por transferencia',
                        ),
                        if (p.estadoPago == PedidoModel.pagoRechazado) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'El restaurante no pudo validar tu comprobante. Sube uno nuevo.',
                            key: ValueKey('pago_rechazado'),
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ComprobanteUploader(
                          tipo: 'pedido',
                          refId: p.id,
                          restauranteId: p.restauranteId,
                          usuarioId: p.usuarioId,
                          yaEnviado: p.estadoPago == PedidoModel.pagoComprobanteEnviado,
                          onEnviado: () => _service.marcarComprobanteEnviado(p.id),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton(
                  key: const ValueKey('btn_volver_inicio_pedido'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _caja() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divisor),
      );
}

class _Paso extends StatelessWidget {
  final String etiqueta;
  final bool hecho;
  final bool actual;

  const _Paso({required this.etiqueta, required this.hecho, required this.actual});

  @override
  Widget build(BuildContext context) {
    final color = hecho || actual ? AppColors.marca : AppColors.borde;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            hecho
                ? Icons.check_circle
                : (actual ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            etiqueta,
            style: TextStyle(
              fontWeight: actual ? FontWeight.w800 : FontWeight.w500,
              color: hecho || actual ? AppColors.texto : AppColors.textoSuave,
            ),
          ),
        ],
      ),
    );
  }
}
