import 'package:flutter/material.dart';

import '../../models/mesa_model.dart';
import '../../models/restaurant_model.dart';
import '../../services/availability_service.dart';
import '../../viewmodels/table_selection_viewmodel.dart';
import 'table_map_widget.dart';

/// Paso "Mesa" del flujo de reserva: plano, selección de mesa o combinación y
/// mensajes cuando no hay mesas adecuadas (HU09-RF03, HU10-RF02/03/04).
class TableSelectionStep extends StatefulWidget {
  final RestaurantModel restaurant;
  final AvailabilityService availability;
  final DateTime fecha;
  final int personas;
  final int duracionMin;
  final List<String> initialSelectedIds;
  final void Function(List<MesaModel> mesas) onSelectionChanged;

  /// Vuelve a un paso anterior para cambiar fecha, duración o personas.
  final void Function(int step) onChangeStep;

  const TableSelectionStep({
    super.key,
    required this.restaurant,
    required this.availability,
    required this.fecha,
    required this.personas,
    required this.duracionMin,
    required this.onSelectionChanged,
    required this.onChangeStep,
    this.initialSelectedIds = const [],
  });

  @override
  State<TableSelectionStep> createState() => _TableSelectionStepState();
}

class _TableSelectionStepState extends State<TableSelectionStep> {
  late final TableSelectionViewModel _vm;

  static const Color terracotta = Color(0xFFB34A26);
  static const Color darkText = Color(0xFF2E241E);
  static const Color mutedText = Color(0xFF7A6E65);
  static const Color cardBorder = Color(0xFFEDE4D8);

  @override
  void initState() {
    super.initState();
    _vm = TableSelectionViewModel(
      restaurant: widget.restaurant,
      availability: widget.availability,
      fecha: widget.fecha,
      personas: widget.personas,
      duracionMin: widget.duracionMin,
      onSelectionChanged: widget.onSelectionChanged,
      initialSelectedIds: widget.initialSelectedIds,
    )..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elige tu mesa',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Para ${widget.personas} ${widget.personas == 1 ? 'persona' : 'personas'}. Toca una mesa para seleccionarla.',
              style: const TextStyle(fontSize: 13, color: mutedText),
            ),
            const SizedBox(height: 16),
            _buildBody(),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    if (_vm.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            key: ValueKey('tables_loading'),
            color: terracotta,
          ),
        ),
      );
    }

    if (_vm.error != null) {
      return _MessageCard(
        key: const ValueKey('tables_error'),
        icon: Icons.error_outline,
        title: 'Algo salió mal',
        detail: _vm.error!,
        action: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: terracotta),
          onPressed: _vm.load,
          child: const Text('Reintentar'),
        ),
      );
    }

    final empty = _vm.emptyMessage;
    if (empty != null) return _buildEmptyState(empty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_vm.hasIndividualOptions)
          const _InfoBanner(
            key: ValueKey('combination_required_banner'),
            text: 'Ninguna mesa individual alcanza para tu grupo. Une mesas combinables para completar la capacidad.',
          ),
        SwitchListTile(
          key: const ValueKey('combine_mode_switch'),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: terracotta,
          title: const Text(
            'Combinar mesas',
            style: TextStyle(fontWeight: FontWeight.w600, color: darkText),
          ),
          subtitle: const Text(
            'Selecciona varias mesas combinables entre sí.',
            style: TextStyle(fontSize: 12, color: mutedText),
          ),
          value: _vm.combineMode,
          onChanged: _vm.needsCombination ? null : _vm.setCombineMode,
        ),
        const SizedBox(height: 8),
        TableMapWidget(viewModel: _vm, onTapMesa: _vm.onTapMesa),
        const SizedBox(height: 12),
        const TableLegend(),
        if (_vm.message != null) ...[
          const SizedBox(height: 12),
          _InfoBanner(
            key: const ValueKey('table_selection_message'),
            text: _vm.message!,
            warning: true,
          ),
        ],
        const SizedBox(height: 16),
        _buildSelectionSummary(),
      ],
    );
  }

  Widget _buildSelectionSummary() {
    final selected = _vm.selected;
    if (selected.isEmpty) {
      return const _InfoBanner(
        key: ValueKey('selection_hint'),
        text: 'Aún no has elegido ninguna mesa.',
      );
    }

    final zonas = {for (final z in _vm.plan.zonas) z.id: z.nombre};
    final valida = _vm.isValidSelection;
    final faltan = widget.personas - _vm.capacidadSeleccionada;

    return Container(
      key: const ValueKey('selection_summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: valida ? terracotta : cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected.length == 1 ? 'Mesa elegida' : 'Combinación de mesas',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: darkText,
            ),
          ),
          const SizedBox(height: 8),
          for (final m in selected)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${m.nombre} · capacidad ${m.capacidad}'
                      '${zonas[m.zonaId] != null ? ' · ${zonas[m.zonaId]}' : ''}',
                      style: const TextStyle(fontSize: 13, color: darkText),
                    ),
                  ),
                  if (selected.length > 1)
                    IconButton(
                      key: ValueKey('remove_mesa_${m.id}'),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quitar ${m.nombre}',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _vm.removeMesa(m.id),
                    ),
                ],
              ),
            ),
          const Divider(height: 18),
          Text(
            'Capacidad total: ${_vm.capacidadSeleccionada} de ${widget.personas} necesarias',
            key: const ValueKey('selection_capacity'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valida ? const Color(0xFF2E7D32) : terracotta,
            ),
          ),
          if (!valida && faltan > 0)
            Text(
              'Faltan $faltan ${faltan == 1 ? 'lugar' : 'lugares'} para cubrir a tu grupo.',
              style: const TextStyle(fontSize: 12, color: mutedText),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TableEmptyMessage message) {
    return _MessageCard(
      key: const ValueKey('tables_empty_state'),
      icon: Icons.table_restaurant_outlined,
      title: message.title,
      detail: message.detail,
      suggestions: message.suggestions,
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            key: const ValueKey('btn_change_date'),
            onPressed: () => widget.onChangeStep(1),
            child: const Text('Cambiar fecha'),
          ),
          OutlinedButton(
            key: const ValueKey('btn_change_duration'),
            onPressed: () => widget.onChangeStep(2),
            child: const Text('Cambiar duración'),
          ),
          OutlinedButton(
            key: const ValueKey('btn_change_people'),
            onPressed: () => widget.onChangeStep(3),
            child: const Text('Cambiar personas'),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final bool warning;

  const _InfoBanner({super.key, required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF3D6) : const Color(0xFFF3ECE1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.info_outline : Icons.lightbulb_outline,
            size: 18,
            color: warning ? const Color(0xFF7A5A00) : const Color(0xFF7A6E65),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF2E241E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de mensaje con título, detalle, sugerencias y acciones.
class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final List<String> suggestions;
  final Widget? action;

  const _MessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.suggestions = const [],
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE4D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: const Color(0xFFB34A26)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E241E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF7A6E65)),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Prueba con:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(s, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
