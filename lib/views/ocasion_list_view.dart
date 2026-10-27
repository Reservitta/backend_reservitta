import 'package:flutter/material.dart';
import '../models/ocasion_model.dart';
import '../services/ocasion_service.dart';
import '../viewmodels/ocasion_viewmodel.dart';
import 'widgets/ocasion_form_dialog.dart';

/// Pantalla de gestión de Ocasiones Especiales y Experiencias para Administradores (HU33-RF01)
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

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);

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

  Future<void> _confirmarEliminar(OcasionModel ocasion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar ocasión especial?'),
        content: Text(
          'Se eliminará la ocasión "${ocasion.nombre}" y sus ${ocasion.experiencias.length} experiencia(s) asociadas.',
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

            // Lista de experiencias
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

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ocasion.experiencias.map((exp) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _lightBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exp.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: exp.esGratis ? Colors.green.shade900 : Colors.brown.shade900,
                          ),
                        ),
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
