import 'package:flutter/material.dart';
import '../../models/platillo_model.dart';
import '../../utils/validators.dart';

/// Diálogo modal para que el cliente agregue y personalice un platillo al preordenar (HU24-RF05).
/// Cumple con:
/// - Criterio 1: Campo de texto libre opcional para modificaciones (ej. 'sin crema').
/// - Criterio 2: El placeholder configurado por el administrador se muestra como texto de ayuda/ejemplo.
/// - Criterio 3: El texto ingresado se guarda en el snapshot de preorden para la reservación (no altera el catálogo).
/// - Criterio 4: Respeta el límite máximo de caracteres configurado (por defecto 150 caracteres).
class PreordenItemDialog extends StatefulWidget {
  final PlatilloModel platillo;

  const PreordenItemDialog({
    super.key,
    required this.platillo,
  });

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _primary = Color(0xFFE4572E);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamLight = Color(0xFFFAF5ED);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required PlatilloModel platillo,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PreordenItemDialog(platillo: platillo),
    );
  }

  @override
  State<PreordenItemDialog> createState() => _PreordenItemDialogState();
}

class _PreordenItemDialogState extends State<PreordenItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _observacionController = TextEditingController();
  int _cantidad = 1;

  @override
  void dispose() {
    _observacionController.dispose();
    super.dispose();
  }

  void _incrementar() {
    setState(() => _cantidad++);
  }

  void _decrementar() {
    if (_cantidad > 1) {
      setState(() => _cantidad--);
    }
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;

    final obsTexto = widget.platillo.permitePersonalizacion
        ? _observacionController.text.trim()
        : '';

    // Criterio 3: Se genera el snapshot inmutable para la reservación
    // sin modificar el documento del platillo en el catálogo.
    final snapshot = widget.platillo.toPreordenItemSnapshot(
      cantidad: _cantidad,
      observacion: obsTexto,
    );

    Navigator.of(context).pop(snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.platillo;
    final total = p.precio * _cantidad;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: PreordenItemDialog._cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PreordenItemDialog._cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera: Título y botón cerrar
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Preordenar Platillo',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PreordenItemDialog._textDark,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tarjeta resumen del platillo
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PreordenItemDialog._creamLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: PreordenItemDialog._cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 68,
                            height: 68,
                            color: Colors.white,
                            child: p.tieneImagenEnNube
                                ? Image.network(
                                    p.imagenUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.restaurant,
                                      color: Color(0xFFC4B8AA),
                                    ),
                                  )
                                : const Icon(
                                    Icons.restaurant,
                                    color: Color(0xFFC4B8AA),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: PreordenItemDialog._textDark,
                                ),
                              ),
                              if (p.descripcion.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  p.descripcion,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PreordenItemDialog._textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                '\$${p.precio.toStringAsFixed(2)} MXN c/u',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: PreordenItemDialog._primaryTerracotta,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Selector de cantidad
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cantidad:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PreordenItemDialog._textDark,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: PreordenItemDialog._creamLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PreordenItemDialog._cardBorder),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              key: const ValueKey('btn_decrementar_preorden'),
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _cantidad > 1 ? _decrementar : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '$_cantidad',
                                key: const ValueKey('texto_cantidad_preorden'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('btn_incrementar_preorden'),
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: _incrementar,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Campo de personalización (HU24-RF05)
                  if (p.permitePersonalizacion) ...[
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded,
                            size: 18, color: PreordenItemDialog._primaryTerracotta),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Personalización del platillo (Opcional)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: PreordenItemDialog._textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const ValueKey('input_preorden_observacion'),
                      controller: _observacionController,
                      maxLength: p.limiteCaracteresObs,
                      maxLines: 2,
                      validator: (val) => AppValidators.validateCustomization(
                        val,
                        maxCharacters: p.limiteCaracteresObs,
                      ),
                      decoration: InputDecoration(
                        // Criterio 2: El texto de ayuda definido por el admin se muestra aquí como placeholder
                        hintText: p.placeholderObservacion.isNotEmpty
                            ? p.placeholderObservacion
                            : 'Indica modificaciones o preferencias (ej. sin cebolla)...',
                        hintStyle: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF9E8F82),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PreordenItemDialog._cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PreordenItemDialog._cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PreordenItemDialog._primary, width: 1.8),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F6F3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PreordenItemDialog._cardBorder),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline,
                              size: 18, color: PreordenItemDialog._textMuted),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Este platillo se elabora con receta estándar y no admite modificaciones personalizadas.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: PreordenItemDialog._textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Resumen de total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a pagar:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: PreordenItemDialog._textDark,
                        ),
                      ),
                      Text(
                        '\$${total.toStringAsFixed(2)} MXN',
                        key: const ValueKey('texto_total_preorden'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: PreordenItemDialog._primaryTerracotta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PreordenItemDialog._textDark,
                            side: const BorderSide(
                                color: PreordenItemDialog._cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          key: const ValueKey('btn_confirmar_preorden_item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PreordenItemDialog._primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: _confirmar,
                          child: const Text('Agregar a Preorden'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
