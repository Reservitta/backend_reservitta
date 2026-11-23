import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/payment_config.dart';
import '../models/restaurant_model.dart';
import '../services/pagos_config_service.dart';
import '../theme/app_theme.dart';

/// Configuración de cobros del restaurante: pedidos a domicilio, cuenta para
/// transferencias y anticipo de reservaciones.
class PagosConfigView extends StatefulWidget {
  final RestaurantModel restaurant;
  final VoidCallback onGuardado;
  final PagosConfigService? service;

  const PagosConfigView({
    super.key,
    required this.restaurant,
    required this.onGuardado,
    this.service,
  });

  @override
  State<PagosConfigView> createState() => _PagosConfigViewState();
}

class _PagosConfigViewState extends State<PagosConfigView> {
  late final PagosConfigService _service = widget.service ?? PagosConfigService();

  late bool _delivery;
  late bool _anticipoActivo;
  late final TextEditingController _banco;
  late final TextEditingController _beneficiario;
  late final TextEditingController _cuenta;
  late final TextEditingController _monto;
  late final TextEditingController _horas;
  late final TextEditingController _politica;

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    _delivery = r.ofreceDelivery;
    _anticipoActivo = r.anticipo.activo;
    _banco = TextEditingController(text: r.datosBancarios.banco);
    _beneficiario = TextEditingController(text: r.datosBancarios.beneficiario);
    _cuenta = TextEditingController(text: r.datosBancarios.cuenta);
    _monto = TextEditingController(
      text: r.anticipo.monto > 0 ? r.anticipo.monto.toStringAsFixed(r.anticipo.monto % 1 == 0 ? 0 : 2) : '',
    );
    _horas = TextEditingController(text: '${r.anticipo.horasLimite}');
    _politica = TextEditingController(text: r.anticipo.politicaCancelacion);
  }

  @override
  void dispose() {
    for (final c in [_banco, _beneficiario, _cuenta, _monto, _horas, _politica]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final cuenta = DatosBancarios(
      banco: _banco.text,
      beneficiario: _beneficiario.text,
      cuenta: _cuenta.text,
    );
    final anticipo = AnticipoConfig(
      activo: _anticipoActivo,
      monto: double.tryParse(_monto.text.replaceAll(',', '.').trim()) ?? 0,
      horasLimite: int.tryParse(_horas.text.trim()) ?? AnticipoConfig.horasLimitePorDefecto,
      politicaCancelacion: _politica.text,
    );
    final problema = PagosConfigService.validar(cuenta: cuenta, anticipo: anticipo);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _service.guardar(
        restaurantId: widget.restaurant.id,
        ofreceDelivery: _delivery,
        cuenta: cuenta,
        anticipo: anticipo,
      );
      if (mounted) widget.onGuardado();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _campo(String etiqueta, {String? ayuda, String? prefijo}) => InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        prefixText: prefijo,
        border: const OutlineInputBorder(),
      );

  Widget _seccion(String titulo, String subtitulo, List<Widget> hijos) {
    // Material (no Container con fondo) para que los interruptores muestren su efecto.
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.divisor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.texto),
              ),
              const SizedBox(height: 4),
              Text(subtitulo, style: const TextStyle(fontSize: 13.5, color: AppColors.textoSuave)),
              const SizedBox(height: 14),
              ...hijos,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.fondo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pagos y pedidos',
                  style: TextStyle(
                    fontFamily: AppTheme.familiaTitulos,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Configura cómo te pagan tus clientes.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textoSuave),
                ),
                const SizedBox(height: 18),
                _seccion(
                  'Pedidos a domicilio y para recoger',
                  'Tus clientes verán un botón para pedir desde tu menú.',
                  [
                    SwitchListTile(
                      key: const ValueKey('switch_delivery'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Recibo pedidos a domicilio y para recoger'),
                      value: _delivery,
                      onChanged: (v) => setState(() => _delivery = v),
                    ),
                  ],
                ),
                _seccion(
                  'Cuenta para transferencias',
                  'Aquí te depositan los anticipos y los pedidos pagados por transferencia.',
                  [
                    TextField(
                      key: const ValueKey('campo_banco'),
                      controller: _banco,
                      textCapitalization: TextCapitalization.words,
                      decoration: _campo('Banco'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('campo_beneficiario'),
                      controller: _beneficiario,
                      textCapitalization: TextCapitalization.words,
                      decoration: _campo('Nombre del beneficiario'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('campo_cuenta'),
                      controller: _cuenta,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                        LengthLimitingTextInputFormatter(22),
                      ],
                      decoration: _campo(
                        'CLABE, cuenta o tarjeta',
                        ayuda: 'Entre 10 y 18 dígitos.',
                      ),
                    ),
                  ],
                ),
                _seccion(
                  'Anticipo para confirmar reservaciones',
                  'El cliente transfiere este monto y sube su comprobante; tú lo revisas y se descuenta de su cuenta final.',
                  [
                    SwitchListTile(
                      key: const ValueKey('switch_anticipo'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pedir anticipo al reservar'),
                      value: _anticipoActivo,
                      onChanged: (v) => setState(() => _anticipoActivo = v),
                    ),
                    if (_anticipoActivo) ...[
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('campo_monto_anticipo'),
                        controller: _monto,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: _campo(
                          'Monto por reservación',
                          prefijo: '\$ ',
                          ayuda: 'Monto fijo en pesos mexicanos.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('campo_horas_anticipo'),
                        controller: _horas,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _campo(
                          'Horas para enviar el comprobante',
                          ayuda: 'Pasado ese plazo verás la reserva marcada como vencida.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('campo_politica'),
                        controller: _politica,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: _campo(
                          'Política de cancelación y reembolso',
                          ayuda: 'Ej. Reembolso total si cancelas 24 h antes.',
                        ),
                      ),
                    ],
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      key: const ValueKey('pagos_error'),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey('btn_guardar_pagos'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
