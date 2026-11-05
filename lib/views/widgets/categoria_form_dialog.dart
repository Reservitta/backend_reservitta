import 'package:flutter/material.dart';
import '../../models/categoria_model.dart';
import '../../utils/validators.dart';

/// Diálogo para agregar o editar una categoría (HU24-RF02 Criterio 1)
class CategoriaFormDialog extends StatefulWidget {
  final CategoriaModel? categoria;
  final Future<bool> Function(String nombre, String tipo) onGuardar;

  const CategoriaFormDialog({
    super.key,
    this.categoria,
    required this.onGuardar,
  });

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _primary = Color(0xFFE4572E);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamLight = Color(0xFFFAF5ED);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _error = Color(0xFFD84A38);
  static const Color _errorLight = Color(0xFFFDEAE8);

  static Future<bool?> show(
    BuildContext context, {
    CategoriaModel? categoria,
    required Future<bool> Function(String nombre, String tipo) onGuardar,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CategoriaFormDialog(
        categoria: categoria,
        onGuardar: onGuardar,
      ),
    );
  }

  @override
  State<CategoriaFormDialog> createState() => _CategoriaFormDialogState();
}

class _CategoriaFormDialogState extends State<CategoriaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late String _tipoSeleccionado;
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _tiposDisponibles = const [
    {'id': 'general', 'label': 'General', 'icon': Icons.label_rounded},
    {'id': 'alimentos', 'label': 'Alimentos', 'icon': Icons.restaurant_rounded},
    {'id': 'bebidas', 'label': 'Bebidas', 'icon': Icons.local_bar_rounded},
    {'id': 'postres', 'label': 'Postres', 'icon': Icons.cake_rounded},
    {'id': 'especiales', 'label': 'Especiales', 'icon': Icons.star_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.categoria?.nombre ?? '');
    _tipoSeleccionado = widget.categoria?.tipo ?? 'general';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onGuardar(
        _nombreController.text.trim(),
        _tipoSeleccionado,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('ArgumentError: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.categoria != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: CategoriaFormDialog._cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CategoriaFormDialog._cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header con icono y título
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF1EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            esEdicion
                                ? Icons.edit_note_rounded
                                : Icons.add_circle_outline_rounded,
                            color: CategoriaFormDialog._primaryTerracotta,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                esEdicion
                                    ? 'Editar Categoría'
                                    : 'Nueva Categoría',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: CategoriaFormDialog._textDark,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                esEdicion
                                    ? 'Actualiza los datos de esta sección'
                                    : 'Crea una nueva sección para tu menú',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: CategoriaFormDialog._textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: CategoriaFormDialog._textMuted,
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(false),
                          tooltip: 'Cerrar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Mensaje de error general si ocurre
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: CategoriaFormDialog._errorLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: CategoriaFormDialog._error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: CategoriaFormDialog._error, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: CategoriaFormDialog._error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Campo de Nombre
                    const Text(
                      'Nombre de la categoría *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CategoriaFormDialog._textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nombreController,
                      autofocus: true,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Ej. Entradas, Pastas, Cócteles...',
                        prefixIcon: const Icon(Icons.label_outline_rounded,
                            size: 20, color: CategoriaFormDialog._textMuted),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: CategoriaFormDialog._cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: CategoriaFormDialog._cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: CategoriaFormDialog._primary, width: 1.8),
                        ),
                        suffixIcon: _nombreController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _nombreController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      validator: AppValidators.validateCategoryName,
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 18),

                    // Selector de Tipo de Categoría
                    const Text(
                      'Tipo de categoría',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CategoriaFormDialog._textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tiposDisponibles.map((tipo) {
                        final isSelected = _tipoSeleccionado == tipo['id'];
                        return ChoiceChip(
                          avatar: Icon(
                            tipo['icon'] as IconData,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : CategoriaFormDialog._textMuted,
                          ),
                          label: Text(tipo['label'] as String),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : CategoriaFormDialog._textDark,
                          ),
                          selected: isSelected,
                          selectedColor: CategoriaFormDialog._primaryTerracotta,
                          backgroundColor: CategoriaFormDialog._creamLight,
                          side: BorderSide(
                            color: isSelected
                                ? CategoriaFormDialog._primaryTerracotta
                                : CategoriaFormDialog._cardBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          showCheckmark: false,
                          onSelected: _isLoading
                              ? null
                              : (selected) {
                                  if (selected) {
                                    setState(() {
                                      _tipoSeleccionado = tipo['id'] as String;
                                    });
                                  }
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 26),

                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CategoriaFormDialog._textDark,
                              side: const BorderSide(color: CategoriaFormDialog._cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CategoriaFormDialog._primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(esEdicion ? 'Actualizar' : 'Guardar'),
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
      ),
    );
  }
}
