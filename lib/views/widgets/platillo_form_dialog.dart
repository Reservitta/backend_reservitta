import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/categoria_model.dart';
import '../../models/platillo_model.dart';
import '../../services/categoria_service.dart';
import '../../utils/validators.dart';
import '../../viewmodels/platillo_viewmodel.dart';

/// Formulario modal para Alta y Edición de Platillo (HU24-RF04)
/// Permite editar precio, descripción, imagen y disponibilidad sin salir de la lista principal.
class PlatilloFormDialog extends StatefulWidget {
  final String restaurantId;
  final PlatilloModel? platillo;
  final PlatilloViewModel viewModel;
  final CategoriaService categoriaService;

  const PlatilloFormDialog({
    super.key,
    required this.restaurantId,
    this.platillo,
    required this.viewModel,
    required this.categoriaService,
  });

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _primary = Color(0xFFE4572E);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamLight = Color(0xFFFAF5ED);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _error = Color(0xFFD84A38);

  static Future<bool?> show(
    BuildContext context, {
    required String restaurantId,
    PlatilloModel? platillo,
    required PlatilloViewModel viewModel,
    required CategoriaService categoriaService,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PlatilloFormDialog(
        restaurantId: restaurantId,
        platillo: platillo,
        viewModel: viewModel,
        categoriaService: categoriaService,
      ),
    );
  }

  @override
  State<PlatilloFormDialog> createState() => _PlatilloFormDialogState();
}

class _PlatilloFormDialogState extends State<PlatilloFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _precioController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _placeholderObsController;

  String? _categoriaSeleccionadaId;
  bool _isDisponible = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  Uint8List? _localImageBytes;
  String? _localImageExt;

  @override
  void initState() {
    super.initState();
    final p = widget.platillo;
    if (p != null) {
      _nombreController = TextEditingController(text: p.nombre);
      _precioController = TextEditingController(text: p.precio.toStringAsFixed(2));
      _descripcionController = TextEditingController(text: p.descripcion);
      _placeholderObsController =
          TextEditingController(text: p.placeholderObservacion);
      _categoriaSeleccionadaId = p.categoriaId.isNotEmpty ? p.categoriaId : null;
      _isDisponible = p.isActivo;
    } else {
      _nombreController = TextEditingController();
      _precioController = TextEditingController();
      _descripcionController = TextEditingController();
      _placeholderObsController = TextEditingController();
      _isDisponible = true;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    _descripcionController.dispose();
    _placeholderObsController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    await widget.viewModel.seleccionarImagenGaleria();
    if (widget.viewModel.imagenBytes != null) {
      setState(() {
        _localImageBytes = widget.viewModel.imagenBytes;
        _localImageExt = widget.viewModel.imagenExtension;
      });
    }
  }

  void _quitarFoto() {
    widget.viewModel.limpiarImagen();
    setState(() {
      _localImageBytes = null;
      _localImageExt = null;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoriaSeleccionadaId == null || _categoriaSeleccionadaId!.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor selecciona una categoría para el platillo.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final esEdicion = widget.platillo != null;
    final nuevoEstado = _isDisponible
        ? PlatilloModel.estadoActivo
        : PlatilloModel.estadoAgotado;

    bool exito = false;

    if (esEdicion) {
      // 1. Edición de platillo existente (HU24-RF04)
      widget.viewModel.placeholderObsController.text =
          _placeholderObsController.text.trim();
      exito = await widget.viewModel.actualizarPlatillo(
        widget.platillo!,
        nombre: _nombreController.text.trim(),
        precioTexto: _precioController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        categoriaId: _categoriaSeleccionadaId,
        nuevoEstado: nuevoEstado,
        nuevaImagenBytes: _localImageBytes,
        nuevaImagenExt: _localImageExt,
      );
    } else {
      // 2. Alta de nuevo platillo (HU24-RF04)
      widget.viewModel.estadoSeleccionado = nuevoEstado;
      widget.viewModel.placeholderObsController.text =
          _placeholderObsController.text.trim();
      exito = await widget.viewModel.crearPlatillo(
        nombre: _nombreController.text.trim(),
        precioTexto: _precioController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        categoriaId: _categoriaSeleccionadaId,
        customImageBytes: _localImageBytes,
        customImageExt: _localImageExt,
      );
    }

    if (mounted) {
      if (exito) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = widget.viewModel.errorMessage ??
              'Ocurrió un error al procesar el platillo.';
        });
      }
    }
  }

  Widget _buildImagePreview() {
    final platillo = widget.platillo;
    Widget content;

    if (_localImageBytes != null) {
      content = Image.memory(
        _localImageBytes!,
        fit: BoxFit.cover,
        width: 110,
        height: 110,
      );
    } else if (platillo != null && platillo.tieneImagenEnNube) {
      content = Image.network(
        platillo.imagenUrl,
        fit: BoxFit.cover,
        width: 110,
        height: 110,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    } else {
      content = _buildPlaceholderImage();
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: PlatilloFormDialog._creamLight,
              border: Border.all(color: PlatilloFormDialog._cardBorder),
            ),
            child: content,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _seleccionarFoto,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(
                  _localImageBytes != null ||
                          (platillo != null && platillo.tieneImagenEnNube)
                      ? 'Cambiar foto'
                      : 'Subir foto',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PlatilloFormDialog._primaryTerracotta,
                  side: const BorderSide(color: PlatilloFormDialog._cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_localImageBytes != null ||
                  (platillo != null && platillo.tieneImagenEnNube)) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _quitarFoto,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Quitar foto'),
                  style: TextButton.styleFrom(
                    foregroundColor: PlatilloFormDialog._error,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(
          Icons.restaurant_rounded,
          size: 36,
          color: Color(0xFFC4B8AA),
        ),
        SizedBox(height: 4),
        Text(
          'Sin imagen',
          style: TextStyle(fontSize: 11, color: Color(0xFF9E8F82)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.platillo != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: BoxDecoration(
            color: PlatilloFormDialog._cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PlatilloFormDialog._cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
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
                    // Header con icono y botón cerrar
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
                                : Icons.restaurant_menu_rounded,
                            color: PlatilloFormDialog._primaryTerracotta,
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
                                    ? 'Editar Platillo'
                                    : 'Nuevo Platillo',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: PlatilloFormDialog._textDark,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                esEdicion
                                    ? 'Modifica precio, descripción, foto y disponibilidad'
                                    : 'Agrega un nuevo platillo a tu carta',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: PlatilloFormDialog._textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: PlatilloFormDialog._textMuted,
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          tooltip: 'Cerrar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Mensaje de error general si ocurre
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEAE8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: PlatilloFormDialog._error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: PlatilloFormDialog._error, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: PlatilloFormDialog._error,
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

                    // 1. Selector de Imagen
                    const Text(
                      'Imagen del platillo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PlatilloFormDialog._textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImagePreview(),
                    const SizedBox(height: 18),

                    // 2. Nombre del Platillo
                    const Text(
                      'Nombre del platillo *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PlatilloFormDialog._textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nombreController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'Ej. Salmón a la plancha, Pasta al pesto...',
                        prefixIcon: const Icon(Icons.fastfood_outlined,
                            size: 20, color: PlatilloFormDialog._textMuted),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._primary, width: 1.8),
                        ),
                      ),
                      validator: AppValidators.validateDishName,
                    ),
                    const SizedBox(height: 16),

                    // 3. Fila: Precio y Categoría
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Precio
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Precio *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: PlatilloFormDialog._textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _precioController,
                                enabled: !_isSubmitting,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: InputDecoration(
                                  hintText: '120.00',
                                  prefixText: '\$ ',
                                  prefixStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: PlatilloFormDialog._textDark,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: PlatilloFormDialog._cardBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: PlatilloFormDialog._cardBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: PlatilloFormDialog._primary,
                                        width: 1.8),
                                  ),
                                ),
                                validator: AppValidators.validatePrice,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Categoría Dropdown
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Categoría *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: PlatilloFormDialog._textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              StreamBuilder<List<CategoriaModel>>(
                                stream: widget.categoriaService
                                    .getCategoriasStream(widget.restaurantId),
                                builder: (context, snap) {
                                  final categorias = snap.data ?? [];

                                  return DropdownButtonFormField<String>(
                                    initialValue: _categoriaSeleccionadaId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      hintText: 'Seleccionar...',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color:
                                                PlatilloFormDialog._cardBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color:
                                                PlatilloFormDialog._cardBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: PlatilloFormDialog._primary,
                                            width: 1.8),
                                      ),
                                    ),
                                    items: categorias.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(
                                          c.nombre,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13.5),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: _isSubmitting
                                        ? null
                                        : (val) {
                                            setState(() {
                                              _categoriaSeleccionadaId = val;
                                            });
                                          },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Descripción del Platillo
                    const Text(
                      'Descripción del platillo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PlatilloFormDialog._textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descripcionController,
                      enabled: !_isSubmitting,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'Detalla los ingredientes principales, alérgenos o modo de preparación...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._primary, width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Switch de Disponibilidad (HU24-RF04)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isDisponible
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isDisponible
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isDisponible
                                ? Icons.check_circle_outline_rounded
                                : Icons.do_not_disturb_on_outlined,
                            color: _isDisponible
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isDisponible
                                      ? 'Platillo Disponible'
                                      : 'Platillo Agotado',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: _isDisponible
                                        ? Colors.green.shade900
                                        : Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isDisponible
                                      ? 'Visible para visitantes en tiempo real.'
                                      : 'Marcado como agotado en el menú.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _isDisponible
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isDisponible,
                            activeThumbColor: Colors.green.shade700,
                            activeTrackColor: Colors.green.shade200,
                            onChanged: _isSubmitting
                                ? null
                                : (val) {
                                    setState(() {
                                      _isDisponible = val;
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Placeholder de personalización del cliente (HU24-RF05)
                    const Text(
                      'Texto de ayuda para personalización del cliente (Opcional)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: PlatilloFormDialog._textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _placeholderObsController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'Ej. Término medio, sin cebolla, aderezo aparte...',
                        prefixIcon: const Icon(Icons.edit_note_rounded,
                            size: 20, color: PlatilloFormDialog._textMuted),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: PlatilloFormDialog._primary, width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botones Cancelar y Guardar
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PlatilloFormDialog._textDark,
                              side: const BorderSide(
                                  color: PlatilloFormDialog._cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PlatilloFormDialog._primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _isSubmitting ? null : _guardar,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(esEdicion ? 'Actualizar' : 'Guardar Platillo'),
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
