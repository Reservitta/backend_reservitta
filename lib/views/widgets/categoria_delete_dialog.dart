import 'package:flutter/material.dart';

/// Diálogo de confirmación antes de eliminar una categoría (HU24-RF02 Criterio 2)
class CategoriaDeleteDialog extends StatefulWidget {
  final String categoriaNombre;
  final int platillosAsociadosCount;
  final Future<bool> Function() onConfirmar;

  const CategoriaDeleteDialog({
    super.key,
    required this.categoriaNombre,
    required this.platillosAsociadosCount,
    required this.onConfirmar,
  });

  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _error = Color(0xFFD84A38);
  static const Color _errorLight = Color(0xFFFDEAE8);
  static const Color _warning = Color(0xFFF57C00);
  static const Color _warningLight = Color(0xFFFFF3E0);

  static Future<bool?> show(
    BuildContext context, {
    required String categoriaNombre,
    required int platillosAsociadosCount,
    required Future<bool> Function() onConfirmar,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CategoriaDeleteDialog(
        categoriaNombre: categoriaNombre,
        platillosAsociadosCount: platillosAsociadosCount,
        onConfirmar: onConfirmar,
      ),
    );
  }

  @override
  State<CategoriaDeleteDialog> createState() => _CategoriaDeleteDialogState();
}

class _CategoriaDeleteDialogState extends State<CategoriaDeleteDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _eliminar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onConfirmar();
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
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tienePlatillos = widget.platillosAsociadosCount > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: CategoriaDeleteDialog._cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CategoriaDeleteDialog._cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icono de advertencia
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: CategoriaDeleteDialog._errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: CategoriaDeleteDialog._error,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Título
              const Text(
                '¿Eliminar categoría?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CategoriaDeleteDialog._textDark,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),

              // Texto descriptivo con nombre de categoría
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: CategoriaDeleteDialog._textMuted,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Estás a punto de eliminar la categoría '),
                    TextSpan(
                      text: '"${widget.categoriaNombre}"',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: CategoriaDeleteDialog._textDark,
                      ),
                    ),
                    const TextSpan(text: '. Esta acción no se puede deshacer.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Advertencia de platillos asociados
              if (tienePlatillos) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CategoriaDeleteDialog._warningLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CategoriaDeleteDialog._warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: CategoriaDeleteDialog._warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta categoría tiene ${widget.platillosAsociadosCount} platillo(s) asociado(s). Al eliminarla, quedarán sin categoría asignada.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8A4600),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Mensaje de error si falla
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CategoriaDeleteDialog._error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CategoriaDeleteDialog._textDark,
                        side: const BorderSide(color: CategoriaDeleteDialog._cardBorder),
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
                      onPressed: _isLoading ? null : _eliminar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CategoriaDeleteDialog._error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sí, eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
