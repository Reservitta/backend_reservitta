import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/experiencia_model.dart';
import '../models/ocasion_model.dart';
import '../services/ocasion_service.dart';
import '../viewmodels/ocasion_viewmodel.dart';
import 'widgets/ocasion_form_dialog.dart';
import '../theme/app_theme.dart';

/// Pantalla de gestión de Ocasiones Especiales y Experiencias para Administradores (HU33-RF01 y HU33-RF02)
class OcasionListView extends StatefulWidget {
  final String restaurantId;
  final OcasionService? ocasionService;
  final OcasionViewModel? viewModel;
  final bool showAppBar;

  const OcasionListView({
    super.key,
    required this.restaurantId,
    this.ocasionService,
    this.viewModel,
    this.showAppBar = true,
  });

  @override
  State<OcasionListView> createState() => _OcasionListViewState();
}

class _OcasionListViewState extends State<OcasionListView> {
  late final OcasionViewModel _viewModel;

  static const Color _primaryTerracotta = AppColors.marca;
  static const Color _lightBg = AppColors.fondo;
  static const Color _cardBorder = AppColors.divisor;
  static const Color _textDark = AppColors.texto;
  static const Color _textMuted = AppColors.textoSuave;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ??
        OcasionViewModel(
          restaurantId: widget.restaurantId,
          ocasionService: widget.ocasionService,
        );
    _viewModel.iniciarEscucha();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  IconData _obtenerIcono(String nombreIcono) {
    switch (nombreIcono) {
      case 'cake':
        return Icons.cake_outlined;
      case 'favorite':
        return Icons.favorite_border;
      case 'diamond':
        return Icons.diamond_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'wine_bar':
        return Icons.wine_bar_outlined;
      case 'celebration':
      default:
        return Icons.celebration_outlined;
    }
  }

  Future<void> _abrirDialogoCrear() async {
    final creado = await OcasionFormDialog.show(context, viewModel: _viewModel);
    if (creado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.successMessage ?? 'Ocasión especial creada correctamente.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _abrirDialogoEditar(OcasionModel ocasion) async {
    final editado = await OcasionFormDialog.show(
      context,
      viewModel: _viewModel,
      ocasionAEditar: ocasion,
    );
    if (editado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.successMessage ?? 'Ocasión especial actualizada correctamente.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _confirmarEliminar(OcasionModel ocasion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar ocasión especial?'),
        content: Text(
          'Se eliminará la ocasión "${ocasion.nombre}" y sus ${ocasion.experiencias.length} experiencia(s) asociadas.\n\n'
          'Las reservas que ya la tenían seleccionada conservarán su dato histórico intacto, pero dejará de estar disponible para nuevas reservas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await _viewModel.eliminarOcasion(ocasion.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocasión eliminada correctamente.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _confirmarEliminarExperiencia(OcasionModel ocasion, ExperienciaModel exp) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar experiencia?'),
        content: Text(
          'Se eliminará la experiencia "${exp.nombre}" de la ocasión "${ocasion.nombre}".\n\n'
          'Las reservas existentes conservarán su dato histórico intacto, pero dejará de ofrecerse a nuevas reservas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar experiencia'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final ok = await _viewModel.eliminarExperienciaIndividual(
        ocasionId: ocasion.id,
        experienciaId: exp.id,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Experiencia "${exp.nombre}" eliminada.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _abrirDialogoEditarExperienciaDirecta(OcasionModel ocasion, ExperienciaModel exp) async {
    final nombreCtrl = TextEditingController(text: exp.nombre);
    final descCtrl = TextEditingController(text: exp.descripcionCorta);
    final precioCtrl = TextEditingController(text: exp.precio.toStringAsFixed(2));
    bool esGratisLive = exp.esGratis;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              key: const ValueKey('dialogo_editar_experiencia_individual'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Editar Experiencia', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nombre *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const ValueKey('input_edit_directo_nombre_exp'),
                      controller: nombreCtrl,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
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
                      key: const ValueKey('input_edit_directo_precio_exp'),
                      controller: precioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        hintText: '0.00',
                        helperText: 'Ingresa \$0 para volverla gratuita, o un valor mayor para asignarle precio.',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? 0.0;
                        setDialogState(() {
                          esGratisLive = parsed <= 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    const Text('Descripción corta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const ValueKey('input_edit_directo_desc_exp'),
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
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
                  key: const ValueKey('boton_confirmar_guardar_exp_individual'),
                  style: FilledButton.styleFrom(backgroundColor: _primaryTerracotta),
                  onPressed: () {
                    final n = nombreCtrl.text.trim();
                    if (n.isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (guardado == true && mounted) {
      final nuevoPrecio = double.tryParse(precioCtrl.text.trim()) ?? 0.0;
      final nuevasExperiencias = ocasion.experiencias.map((e) {
        if (e.id == exp.id) {
          return e.copyWith(
            nombre: nombreCtrl.text.trim(),
            descripcionCorta: descCtrl.text.trim(),
            precio: nuevoPrecio,
            esGratis: nuevoPrecio <= 0.0,
          );
        }
        return e;
      }).toList();

      final service = widget.ocasionService ?? OcasionService();
      await service.actualizarOcasion(
        restaurantId: widget.restaurantId,
        ocasionId: ocasion.id,
        nombre: ocasion.nombre,
        tipoPredefinido: ocasion.tipoPredefinido,
        descripcion: ocasion.descripcion,
        icono: ocasion.icono,
        experiencias: nuevasExperiencias,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Experiencia actualizada correctamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Ocasiones y Experiencias'),
              backgroundColor: _lightBg,
              elevation: 0,
              actions: [
                FilledButton.icon(
                  key: const ValueKey('boton_nueva_ocasion_appbar'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva ocasión'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryTerracotta,
                  ),
                  onPressed: _abrirDialogoCrear,
                ),
                const SizedBox(width: 16),
              ],
            )
          : null,
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.ocasiones.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryTerracotta),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de acciones superior si no hay AppBar
              if (!widget.showAppBar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ocasiones Especiales',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Configura paquetes o amenidades para celebraciones en tu restaurante.',
                            style: TextStyle(
                              fontSize: 13,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        key: const ValueKey('boton_nueva_ocasion'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nueva ocasión'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryTerracotta,
                        ),
                        onPressed: _abrirDialogoCrear,
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: _viewModel.ocasiones.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        itemCount: _viewModel.ocasiones.length,
                        itemBuilder: (context, index) {
                          final ocasion = _viewModel.ocasiones[index];
                          return _buildOcasionCard(ocasion);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: widget.showAppBar
          ? FloatingActionButton.extended(
              key: const ValueKey('boton_nueva_ocasion_fab'),
              backgroundColor: _primaryTerracotta,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nueva ocasión', style: TextStyle(color: Colors.white)),
              onPressed: _abrirDialogoCrear,
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('vista_vacia_ocasiones'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryTerracotta.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration_outlined,
                size: 56,
                color: _primaryTerracotta,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes ocasiones especiales creadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea paquetes para Cumpleaños, Aniversarios o Cenas Románticas con experiencias exclusivas o de cortesía.',
              style: TextStyle(fontSize: 13, color: _textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('boton_crear_primera_ocasion'),
              icon: const Icon(Icons.add),
              label: const Text('Crear primera ocasión'),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryTerracotta,
              ),
              onPressed: _abrirDialogoCrear,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcasionCard(OcasionModel ocasion) {
    return Card(
      key: ValueKey('card_ocasion_${ocasion.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _cardBorder),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryTerracotta.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _obtenerIcono(ocasion.icono),
                    color: _primaryTerracotta,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ocasion.nombre,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      if (ocasion.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ocasion.descripcion,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Botón editar ocasión (HU33-RF02)
                IconButton(
                  key: ValueKey('boton_editar_ocasion_${ocasion.id}'),
                  icon: const Icon(Icons.edit_outlined, color: _primaryTerracotta, size: 20),
                  tooltip: 'Editar ocasión',
                  onPressed: () => _abrirDialogoEditar(ocasion),
                ),
                // Botón eliminar ocasión (HU33-RF01 y HU33-RF02)
                IconButton(
                  key: ValueKey('boton_eliminar_ocasion_${ocasion.id}'),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'Eliminar ocasión',
                  onPressed: () => _confirmarEliminar(ocasion),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Lista de experiencias (HU33-RF02)
            Row(
              children: [
                const Icon(Icons.stars_rounded, size: 16, color: _primaryTerracotta),
                const SizedBox(width: 6),
                Text(
                  'Experiencias disponibles (${ocasion.experiencias.length}):',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Column(
              children: ocasion.experiencias.map((exp) {
                return Container(
                  key: ValueKey('card_experiencia_${exp.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _lightBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp.nombre,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (exp.descripcionCorta.isNotEmpty)
                              Text(
                                exp.descripcionCorta,
                                style: const TextStyle(fontSize: 12, color: _textMuted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      // Botón editar experiencia individual (HU33-RF02)
                      IconButton(
                        key: ValueKey('boton_editar_experiencia_${exp.id}'),
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                        tooltip: 'Editar experiencia',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _abrirDialogoEditarExperienciaDirecta(ocasion, exp),
                      ),
                      const SizedBox(width: 6),
                      // Botón eliminar experiencia individual (HU33-RF02)
                      IconButton(
                        key: ValueKey('boton_eliminar_experiencia_${exp.id}'),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        tooltip: 'Eliminar experiencia',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmarEliminarExperiencia(ocasion, exp),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
