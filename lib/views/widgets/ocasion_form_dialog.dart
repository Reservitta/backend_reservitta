import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ocasion_model.dart';
import '../../viewmodels/ocasion_viewmodel.dart';

/// Modal para crear una ocasión especial y sus experiencias (HU33-RF01)
class OcasionFormDialog extends StatefulWidget {
  final OcasionViewModel viewModel;

  const OcasionFormDialog({
    super.key,
    required this.viewModel,
  });

  static Future<bool?> show(BuildContext context, {required OcasionViewModel viewModel}) {
    viewModel.resetFormulario();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OcasionFormDialog(viewModel: viewModel),
    );
  }

  @override
  State<OcasionFormDialog> createState() => _OcasionFormDialogState();
}

class _OcasionFormDialogState extends State<OcasionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombrePersonalizadoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);

  @override
  void dispose() {
    _nombrePersonalizadoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirModalNuevaExperiencia() async {
    final expNombreCtrl = TextEditingController();
    final expDescCtrl = TextEditingController();
    final expPrecioCtrl = TextEditingController(text: '0');
    bool esGratisLive = true;

    final agregada = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              key: const ValueKey('dialogo_nueva_experiencia'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.stars_rounded, color: _primaryTerracotta),
                  SizedBox(width: 8),
                  Text('Agregar Experiencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nombre de la experiencia *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const ValueKey('input_nombre_experiencia'),
                      controller: expNombreCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Pastel con bengala, Decoración con pétalos',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Text('Precio (MXN) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        if (esGratisLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Gratis', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const ValueKey('input_precio_experiencia'),
                      controller: expPrecioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        hintText: '0.00',
                        helperText: 'Si ingresas \$0 se marcará automáticamente como Gratis.',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? 0.0;
                        setModalState(() {
                          esGratisLive = parsed <= 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    const Text('Descripción corta (Opcional recomendada)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const ValueKey('input_descripcion_experiencia'),
                      controller: expDescCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Describe brevemente qué incluye esta experiencia',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const ValueKey('boton_confirmar_agregar_experiencia'),
                  style: FilledButton.styleFrom(backgroundColor: _primaryTerracotta),
                  onPressed: () {
                    final nombre = expNombreCtrl.text.trim();
                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El nombre de la experiencia es obligatorio.')),
                      );
                      return;
                    }
                    final precio = double.tryParse(expPrecioCtrl.text.trim()) ?? 0.0;
                    if (precio < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El precio no puede ser negativo.')),
                      );
                      return;
                    }

                    final ok = widget.viewModel.agregarExperienciaTemporal(
                      nombre: nombre,
                      descripcionCorta: expDescCtrl.text.trim(),
                      precio: precio,
                    );
                    if (ok) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (agregada == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _guardarOcasion() async {
    if (widget.viewModel.nombrePredefinidoSeleccionado == OcasionModel.tipoOtro) {
      widget.viewModel.setNombrePersonalizado(_nombrePersonalizadoCtrl.text);
    }
    widget.viewModel.setDescripcion(_descripcionCtrl.text);

    final ok = await widget.viewModel.guardarOcasion();
    if (ok && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final esOtro = vm.nombrePredefinidoSeleccionado == OcasionModel.tipoOtro;

        return Dialog(
          key: const ValueKey('dialogo_crear_ocasion'),
          backgroundColor: _lightBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryTerracotta.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.celebration, color: _primaryTerracotta, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nueva Ocasión Especial',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Configura una ocasión y agrega una o más experiencias para tus comensales.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (vm.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                vm.errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          // 1. Selector de Nombres Predefinidos (HU33-RF01 Criterio 1)
                          const Text(
                            'Tipo / Nombre de la ocasión *',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const ValueKey('dropdown_nombre_ocasion'),
                            initialValue: vm.nombrePredefinidoSeleccionado,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: OcasionModel.nombresPredefinidos.map((n) {
                              return DropdownMenuItem(
                                value: n,
                                child: Row(
                                  children: [
                                    Text(n),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                vm.setNombrePredefinido(val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Si elige "Otro", especificar nombre personalizado
                          if (esOtro) ...[
                            const Text(
                              'Especifica el nombre de la ocasión *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              key: const ValueKey('input_nombre_ocasion_personalizado'),
                              controller: _nombrePersonalizadoCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Ej. Despedida de soltera, Baby Shower',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onChanged: (val) => vm.setNombrePersonalizado(val),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Descripción general opcional
                          const Text(
                            'Descripción de la ocasión (Opcional)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            key: const ValueKey('input_descripcion_ocasion'),
                            controller: _descripcionCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Detalles sobre cómo celebra tu restaurante esta ocasión...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) => vm.setDescripcion(val),
                          ),
                          const SizedBox(height: 16),

                          // 2. Sección de Experiencias (HU33-RF01 Criterios 2, 3, 4 y 6)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Experiencias incluidas *',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      '${vm.experienciasTemporales.length} agregada(s) (mínimo 1 requerida)',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                key: const ValueKey('boton_agregar_experiencia'),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Agregar experiencia'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primaryTerracotta,
                                  side: const BorderSide(color: _primaryTerracotta),
                                ),
                                onPressed: _abrirModalNuevaExperiencia,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (vm.experienciasTemporales.isEmpty)
                            Container(
                              key: const ValueKey('aviso_sin_experiencias'),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Añade al menos una experiencia con su precio (ej. Pastel de cortesía, Decoración con velas, etc.).',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...vm.experienciasTemporales.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final exp = entry.value;
                              return Card(
                                key: ValueKey('card_experiencia_temporal_$idx'),
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: _cardBorder),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: exp.esGratis
                                        ? Colors.green.shade100
                                        : _primaryTerracotta.withAlpha(20),
                                    child: Icon(
                                      exp.esGratis ? Icons.card_giftcard : Icons.room_service,
                                      color: exp.esGratis ? Colors.green : _primaryTerracotta,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(exp.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  subtitle: exp.descripcionCorta.isNotEmpty
                                      ? Text(exp.descripcionCorta, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: exp.esGratis ? Colors.green.shade50 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: exp.esGratis ? Colors.green.shade300 : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          exp.precioFormateado,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: exp.esGratis ? Colors.green.shade800 : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: ValueKey('boton_eliminar_experiencia_$idx'),
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                        onPressed: () => vm.removerExperienciaTemporal(idx),
                                        tooltip: 'Eliminar experiencia',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    const Divider(height: 24),
                    // Acciones inferiores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          key: const ValueKey('boton_guardar_ocasion'),
                          style: FilledButton.styleFrom(backgroundColor: _primaryTerracotta),
                          icon: vm.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Guardar ocasión'),
                          onPressed: vm.puedeGuardar ? _guardarOcasion : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
