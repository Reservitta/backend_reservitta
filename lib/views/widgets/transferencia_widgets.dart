import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/payment_config.dart';
import '../../services/comprobante_service.dart';
import '../../theme/app_theme.dart';

String formatoDinero(double v) => '\$${v.toStringAsFixed(2)} MXN';

/// Datos para hacer la transferencia: banco, beneficiario, cuenta, monto y el concepto
/// que debe escribir el cliente. Cada dato se copia con un toque.
class TransferenciaCard extends StatelessWidget {
  final DatosBancarios cuenta;
  final double monto;
  final String concepto;
  final String titulo;

  const TransferenciaCard({
    super.key,
    required this.cuenta,
    required this.monto,
    required this.concepto,
    this.titulo = 'Datos para transferir',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('tarjeta_transferencia'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.marcaSuave,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.marcaMedia),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 20, color: AppColors.marca),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.texto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FilaDato(etiqueta: 'Banco', valor: cuenta.banco),
          _FilaDato(etiqueta: 'Beneficiario', valor: cuenta.beneficiario),
          _FilaDato(
            etiqueta: 'Cuenta / CLABE',
            valor: cuenta.cuenta,
            claveCopiar: 'copiar_cuenta',
          ),
          _FilaDato(etiqueta: 'Monto', valor: formatoDinero(monto)),
          _FilaDato(
            etiqueta: 'Concepto',
            valor: concepto,
            claveCopiar: 'copiar_concepto',
            destacado: true,
          ),
          const SizedBox(height: 4),
          const Text(
            'Escribe el concepto tal cual para que el restaurante encuentre tu pago rápido.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textoSuave),
          ),
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String? claveCopiar;
  final bool destacado;

  const _FilaDato({
    required this.etiqueta,
    required this.valor,
    this.claveCopiar,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13, color: AppColors.textoSuave),
            ),
          ),
          Expanded(
            child: SelectableText(
              valor,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: destacado ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.texto,
              ),
            ),
          ),
          if (claveCopiar != null)
            IconButton(
              key: ValueKey(claveCopiar),
              tooltip: 'Copiar $etiqueta',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.marca),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: valor));
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$etiqueta copiado'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Espacio para elegir la captura del comprobante y subirla.
///
/// Guarda la imagen con [ComprobanteService] y después llama [onEnviado], que se
/// encarga de marcar la reserva o el pedido como "comprobante enviado".
class ComprobanteUploader extends StatefulWidget {
  final String tipo; // 'reserva' | 'pedido'
  final String refId;
  final String restauranteId;
  final String usuarioId;
  final Future<void> Function() onEnviado;
  final ComprobanteService? service;
  final ImagePicker? picker;
  final bool yaEnviado;

  const ComprobanteUploader({
    super.key,
    required this.tipo,
    required this.refId,
    required this.restauranteId,
    required this.usuarioId,
    required this.onEnviado,
    this.service,
    this.picker,
    this.yaEnviado = false,
  });

  @override
  State<ComprobanteUploader> createState() => _ComprobanteUploaderState();
}

class _ComprobanteUploaderState extends State<ComprobanteUploader> {
  late final ComprobanteService _service = widget.service ?? ComprobanteService();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  Uint8List? _bytes;
  String _extension = 'jpg';
  bool _enviando = false;
  bool _enviado = false;
  String? _error;

  @override
  void didUpdateWidget(covariant ComprobanteUploader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el restaurante rechazó el comprobante, vuelve a pedirse uno nuevo.
    if (oldWidget.yaEnviado && !widget.yaEnviado) {
      _enviado = false;
      _bytes = null;
    }
  }

  Future<void> _elegir() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final partes = picked.name.split('.');
      setState(() {
        _bytes = bytes;
        _extension = partes.length > 1 ? partes.last.toLowerCase() : 'jpg';
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'No se pudo abrir la imagen. Inténtalo de nuevo.');
    }
  }

  Future<void> _enviar() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await _service.guardar(
        tipo: widget.tipo,
        refId: widget.refId,
        restauranteId: widget.restauranteId,
        usuarioId: widget.usuarioId,
        bytes: bytes,
        extension: _extension,
      );
      await widget.onEnviado();
      if (mounted) setState(() => _enviado = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is Exception || e is Error
            ? (e.toString().contains('pesa demasiado')
                ? e.toString()
                : 'No se pudo enviar el comprobante. Revisa tu conexión e inténtalo de nuevo.')
            : e.toString());
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enviado || widget.yaEnviado) {
      return Container(
        key: const ValueKey('comprobante_enviado'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB7D8BA)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.exito),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recibimos tu comprobante. El restaurante lo revisará y te confirmará.',
                style: TextStyle(color: AppColors.texto),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bytes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Image.memory(_bytes!, fit: BoxFit.contain),
              ),
            ),
          ),
        OutlinedButton.icon(
          key: const ValueKey('btn_elegir_comprobante'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _enviando ? null : _elegir,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(_bytes == null ? 'Subir comprobante' : 'Cambiar imagen'),
        ),
        if (_bytes != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('btn_enviar_comprobante'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_enviando ? 'Enviando…' : 'Enviar comprobante'),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              key: const ValueKey('comprobante_error'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

/// Muestra el comprobante que mandó el cliente (para el restaurante).
class ComprobanteVisor extends StatelessWidget {
  final String tipo;
  final String refId;
  final ComprobanteService? service;

  const ComprobanteVisor({
    super.key,
    required this.tipo,
    required this.refId,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    final servicio = service ?? ComprobanteService();
    return FutureBuilder<Comprobante?>(
      future: servicio.obtener(tipo, refId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final bytes = snap.data?.bytes;
        if (bytes == null) {
          return const Text(
            'Todavía no hay comprobante.',
            style: TextStyle(color: AppColors.textoSuave),
          );
        }
        return InkWell(
          key: const ValueKey('visor_comprobante'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              child: InteractiveViewer(child: Image.memory(bytes)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }
}
