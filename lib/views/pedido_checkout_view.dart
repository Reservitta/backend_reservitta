import 'package:flutter/material.dart';

import '../models/anticipo_reserva.dart';
import '../models/branch_model.dart';
import '../models/pedido_model.dart';
import '../models/restaurant_model.dart';
import '../services/auth_service.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/carrito_viewmodel.dart';
import 'pedido_seguimiento_view.dart';
import 'widgets/transferencia_widgets.dart';

/// Último paso del pedido: resumen, forma de pago, entrega (domicilio o recoger),
/// datos de contacto y confirmación.
class PedidoCheckoutView extends StatefulWidget {
  final RestaurantModel restaurant;
  final BranchModel? sucursal;
  final CarritoViewModel carrito;
  final PedidoService? pedidoService;
  final AuthService? authService;

  const PedidoCheckoutView({
    super.key,
    required this.restaurant,
    this.sucursal,
    required this.carrito,
    this.pedidoService,
    this.authService,
  });

  @override
  State<PedidoCheckoutView> createState() => _PedidoCheckoutViewState();
}

class _PedidoCheckoutViewState extends State<PedidoCheckoutView> {
  late final PedidoService _service = widget.pedidoService ?? PedidoService();
  late final AuthService _auth = widget.authService ?? AuthService();

  /// Id reservado desde el inicio para poder mostrar el concepto de la transferencia.
  late final String _pedidoId = _service.nuevoId();

  String _metodoPago = PedidoModel.pagoEfectivo;
  String _tipoEntrega = PedidoModel.entregaRecoger;

  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _referencias = TextEditingController();

  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _telefono, _direccion, _referencias]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmar() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      setState(() => _error = 'Inicia sesión para confirmar tu pedido.');
      return;
    }
    final pedido = PedidoModel(
      id: _pedidoId,
      restauranteId: widget.restaurant.id,
      restauranteNombre: widget.restaurant.nombre,
      sucursalId: widget.sucursal?.id ?? '',
      sucursalNombre: widget.sucursal?.nombre ?? '',
      usuarioId: uid,
      contactoNombre: _nombre.text,
      contactoTelefono: _telefono.text,
      lineas: widget.carrito.lineas,
      tipoEntrega: _tipoEntrega,
      direccion: _direccion.text,
      referencias: _referencias.text,
      metodoPago: _metodoPago,
    );
    final problema = PedidoService.validar(pedido);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final guardado = await _service.crear(pedido, id: _pedidoId);
      widget.carrito.limpiar();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PedidoSeguimientoView(
            pedidoId: guardado.id,
            cuenta: widget.restaurant.datosBancarios,
            pedidoService: _service,
          ),
        ),
      );
    } on PedidoInvalidoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo enviar tu pedido. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divisor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.texto,
            ),
          ),
          const SizedBox(height: 10),
          ...hijos,
        ],
      ),
    );
  }

  Widget _opcion({
    required Key key,
    required String valor,
    required String grupo,
    required IconData icono,
    required String titulo,
    required String detalle,
    required ValueChanged<String> onTap,
  }) {
    final seleccionada = valor == grupo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: seleccionada ? AppColors.marcaSuave : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: seleccionada ? AppColors.marca : AppColors.divisor,
            width: seleccionada ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          key: key,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onTap: () => onTap(valor),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icono, color: AppColors.marca),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        detalle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  seleccionada
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: seleccionada ? AppColors.marca : AppColors.borde,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _campo(String etiqueta, {String? ayuda}) => InputDecoration(
    labelText: etiqueta,
    helperText: ayuda,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: AnimatedBuilder(
        animation: widget.carrito,
        builder: (context, _) {
          final carrito = widget.carrito;
          if (carrito.vacio) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tu pedido está vacío. Vuelve al menú para agregar platillos.',
                  key: ValueKey('carrito_vacio'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final concepto = ConceptoTransferencia.generar(
            prefijo: 'PED',
            id: _pedidoId,
            nombre: _nombre.text,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _seccion('Tu pedido', [
                        for (final l in carrito.lineas)
                          Padding(
                            key: ValueKey('linea_${l.platilloId}'),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                IconButton(
                                  key: ValueKey('menos_${l.platilloId}'),
                                  tooltip: 'Quitar uno',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppColors.marca,
                                  ),
                                  onPressed: () => carrito.quitar(l.platilloId),
                                ),
                                Text(
                                  '${l.cantidad}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey('mas_${l.platilloId}'),
                                  tooltip: 'Agregar uno',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.marca,
                                  ),
                                  onPressed:
                                      l.cantidad >=
                                          CarritoViewModel.maxPorPlatillo
                                      ? null
                                      : () => carrito.sumar(l.platilloId),
                                ),
                                Expanded(child: Text(l.nombre)),
                                Text(formatoDinero(l.total)),
                              ],
                            ),
                          ),
                        const Divider(),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              formatoDinero(carrito.total),
                              key: const ValueKey('total_carrito'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ]),
                      _seccion('1. Forma de pago', [
                        _opcion(
                          key: const ValueKey('pago_efectivo'),
                          valor: PedidoModel.pagoEfectivo,
                          grupo: _metodoPago,
                          icono: Icons.payments_outlined,
                          titulo: 'Efectivo',
                          detalle: 'Pagas al recibir o recoger tu pedido.',
                          onTap: (v) => setState(() => _metodoPago = v),
                        ),
                        if (r.aceptaTransferencia)
                          _opcion(
                            key: const ValueKey('pago_transferencia'),
                            valor: PedidoModel.pagoTransferencia,
                            grupo: _metodoPago,
                            icono: Icons.account_balance_outlined,
                            titulo: 'Transferencia',
                            detalle: 'Transfieres y subes tu comprobante al confirmar.',
                            onTap: (v) => setState(() => _metodoPago = v),
                          ),
                        if (_metodoPago == PedidoModel.pagoTransferencia) ...[
                          const SizedBox(height: 4),
                          TransferenciaCard(
                            cuenta: r.datosBancarios,
                            monto: carrito.total,
                            concepto: concepto,
                          ),
                        ],
                      ]),
                      _seccion('2. ¿Cómo lo quieres?', [
                        _opcion(
                          key: const ValueKey('entrega_recoger'),
                          valor: PedidoModel.entregaRecoger,
                          grupo: _tipoEntrega,
                          icono: Icons.storefront_outlined,
                          titulo: 'Recoger en el local',
                          detalle: (widget.sucursal?.direccion.isNotEmpty ?? false)
                              ? widget.sucursal!.direccion
                              : (r.direccion.isEmpty
                                  ? 'Pasas por tu pedido.'
                                  : r.direccion),
                          onTap: (v) => setState(() => _tipoEntrega = v),
                        ),
                        _opcion(
                          key: const ValueKey('entrega_domicilio'),
                          valor: PedidoModel.entregaDomicilio,
                          grupo: _tipoEntrega,
                          icono: Icons.delivery_dining_outlined,
                          titulo: 'A domicilio',
                          detalle: 'Te lo llevamos a tu dirección.',
                          onTap: (v) => setState(() => _tipoEntrega = v),
                        ),
                        if (_tipoEntrega == PedidoModel.entregaDomicilio) ...[
                          const SizedBox(height: 4),
                          TextField(
                            key: const ValueKey('campo_direccion'),
                            controller: _direccion,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 2,
                            decoration: _campo(
                              'Dirección de entrega',
                              ayuda: 'Calle, número, colonia y ciudad.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('campo_referencias'),
                            controller: _referencias,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _campo(
                              'Referencias (opcional)',
                              ayuda: 'Ej. portón negro, entre calles…',
                            ),
                          ),
                        ],
                      ]),
                      _seccion('3. Tus datos', [
                        TextField(
                          key: const ValueKey('campo_nombre_pedido'),
                          controller: _nombre,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          decoration: _campo('Nombre'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('campo_telefono_pedido'),
                          controller: _telefono,
                          keyboardType: TextInputType.phone,
                          decoration: _campo(
                            'Teléfono',
                            ayuda: 'Para avisarte de tu pedido.',
                          ),
                        ),
                      ]),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            key: const ValueKey('error_pedido'),
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      FilledButton(
                        key: const ValueKey('btn_confirmar_pedido'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                        onPressed: _enviando ? null : _confirmar,
                        child: _enviando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Confirmar pedido · ${formatoDinero(carrito.total)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
