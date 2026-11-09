import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/experiencia_model.dart';
import '../../models/ocasion_model.dart';
import '../../viewmodels/ocasion_viewmodel.dart';

/// Modal para crear o editar una ocasión especial y sus experiencias (HU33-RF01 y HU33-RF02)
class OcasionFormDialog extends StatefulWidget {
  final OcasionViewModel viewModel;
  final OcasionModel? ocasionAEditar;

  const OcasionFormDialog({
    super.key,
    required this.viewModel,
    this.ocasionAEditar,
  });

  static Future<bool?> show(
    BuildContext context, {
    required OcasionViewModel viewModel,
    OcasionModel? ocasionAEditar,
  }) {
    if (ocasionAEditar != null) {
      viewModel.cargarOcasionParaEdicion(ocasionAEditar);
    } else {
      viewModel.resetFormulario();
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OcasionFormDialog(
        viewModel: viewModel,
        ocasionAEditar: ocasionAEditar,
      ),
    );
  }

  @override
  State<OcasionFormDialog> createState() => _OcasionFormDialogState();
}

class _OcasionFormDialogState extends State<OcasionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombrePersonalizadoCtrl;
  late final TextEditingController _descripcionCtrl;

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);

  @override
  void initState() {
    super.initState();
    _nombrePersonalizadoCtrl = TextEditingController(text: widget.viewModel.nombrePersonalizado);
    _descripcionCtrl = TextEditingController(text: widget.viewModel.descripcion);
  }

  @override
  void dispose() {
    _nombrePersonalizadoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirModalNuevaExperiencia({int? indexParaEditar, ExperienciaModel? expExistente}) async {
    final expNombreCtrl = TextEditingController(text: expExistente?.nombre ?? '');
    final expDescCtrl = TextEditingController(text: expExistente?.descripcionCorta ?? '');
    final expPrecioCtrl = TextEditingController(
      text: expExistente != null ? expExistente.precio.toStringAsFixed(2) : '0',
    );
    bool esGratisLive = expExistente != null ? expExistente.esGratis : true;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final esEdicion = expExistente != null;
            return AlertDialog(
              key: ValueKey(esEdicion ? 'dialogo_editar_experiencia' : 'dialogo_nueva_experiencia'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: _primaryTerracotta),
                  const SizedBox(width: 8),
                  Text(
                    esEdicion ? 'Editar Experiencia' : 'Agregar Experiencia',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                            child: const Text(
                              'Gratis',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
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

                    if (esEdicion && indexParaEditar != null) {
                      widget.viewModel.actualizarExperienciaTemporal(
                        indexParaEditar,
                        nombre: nombre,
                        descripcionCorta: expDescCtrl.text.trim(),
                        precio: precio,
                      );
                      Navigator.pop(ctx, true);
                    } else {
                      final ok = widget.viewModel.agregarExperienciaTemporal(
                        nombre: nombre,
                        descripcionCorta: expDescCtrl.text.trim(),
                        precio: precio,
                      );
                      if (ok) {
                        Navigator.pop(ctx, true);
                      }
                    }
                  },
                  child: Text(esEdicion ? 'Guardar' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == true && mounted) {
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
        final esEdicion = vm.esModoEdicion;

        return Dialog(
          key: ValueKey(esEdicion ? 'dialogo_editar_ocasion' : 'dialogo_crear_ocasion'),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                esEdicion ? 'Editar Ocasión Especial' : 'Nueva Ocasión Especial',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                esEdicion
                                    ? 'Modifica los datos y experiencias de esta ocasión.'
                                    : 'Configura una ocasión y agrega una o más experiencias para tus comensales.',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
        tooltip: 'Cerrar',
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
                          // 1. Selector de Nombres Predefinidos (HU33-RF01 Criterio 1, HU33-RF02)
                          const Text(
                            'Tipo / Nombre de la ocasión *',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const ValueKey('dropdown_nombre_ocasion'),
                            value: vm.nombrePredefinidoSeleccionado,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: OcasionModel.nombresPredefinidos.map((n) {
                              return DropdownMenuItem(
                                value: n,
                                child: Text(n),
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

                          // 2. Sección de Experiencias (HU33-RF01 y HU33-RF02)
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
                                onPressed: () => _abrirModalNuevaExperiencia(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (vm.experienciasTemporales.isEmpty)
                            Container(
                              key: const ValueKey('aviso_sin_experiencias'),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Debes agregar al menos una experiencia para poder guardar esta ocasión especial.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: vm.experienciasTemporales.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, i) {
                                final exp = vm.experienciasTemporales[i];
                                return Container(
                                  key: ValueKey('item_experiencia_temp_$i'),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.stars, color: _primaryTerracotta, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exp.nombre,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            if (exp.descripcionCorta.isNotEmpty)
                                              Text(
                                                exp.descripcionCorta,
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: exp.esGratis ? Colors.green.shade100 : Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          exp.precioFormateado,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: exp.esGratis ? Colors.green.shade900 : Colors.brown.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        key: ValueKey('boton_editar_exp_temp_$i'),
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                                        tooltip: 'Editar experiencia',
                                        onPressed: () => _abrirModalNuevaExperiencia(
                                          indexParaEditar: i,
                                          expExistente: exp,
                                        ),
                                      ),
                                      IconButton(
                                        key: ValueKey('boton_remover_exp_temp_$i'),
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                        tooltip: 'Eliminar experiencia',
                                        onPressed: () => vm.removerExperienciaTemporal(i),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const Divider(height: 24),

                    // Botones inferiores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          key: const ValueKey('boton_cancelar_ocasion'),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          key: const ValueKey('boton_guardar_ocasion'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryTerracotta,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: vm.puedeGuardar ? _guardarOcasion : null,
                          child: vm.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(esEdicion ? 'Guardar cambios' : 'Crear ocasión'),
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
