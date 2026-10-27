import 'package:flutter/material.dart';

import '../../models/restaurant_model.dart';
import '../../services/availability_service.dart';
import '../../viewmodels/time_slot_viewmodel.dart';

/// Paso "Horario" del flujo de reserva: cuadrícula de horarios libres para la
/// mesa elegida (HU11-RF02).
class TimeSlotStep extends StatefulWidget {
  final RestaurantModel restaurant;
  final AvailabilityService availability;
  final DateTime fecha;
  final int duracionMin;
  final List<String> mesaIds;
  final List<String> mesasNombres;
  final DateTime? initialInicio;
  final void Function(TimeSlot slot) onSelected;

  /// Vuelve a un paso anterior (1 = fecha, 4 = mesa).
  final void Function(int step) onChangeStep;

  const TimeSlotStep({
    super.key,
    required this.restaurant,
    required this.availability,
    required this.fecha,
    required this.duracionMin,
    required this.mesaIds,
    required this.mesasNombres,
    required this.onSelected,
    required this.onChangeStep,
    this.initialInicio,
  });

  @override
  State<TimeSlotStep> createState() => _TimeSlotStepState();
}

class _TimeSlotStepState extends State<TimeSlotStep> {
  late final TimeSlotViewModel _vm;

  static const Color terracotta = Color(0xFFB34A26);
  static const Color darkText = Color(0xFF2E241E);
  static const Color mutedText = Color(0xFF7A6E65);

  @override
  void initState() {
    super.initState();
    _vm = TimeSlotViewModel(
      restaurant: widget.restaurant,
      availability: widget.availability,
      fecha: widget.fecha,
      duracionMin: widget.duracionMin,
      mesaIds: widget.mesaIds,
      onSelected: widget.onSelected,
      initialInicio: widget.initialInicio,
    )..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  static String hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elige tu horario',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.mesasNombres.join(' + ')} · ${_duracion(widget.duracionMin)}',
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
            key: ValueKey('slots_loading'),
            color: terracotta,
          ),
        ),
      );
    }

    if (_vm.error != null) {
      return _card(
        key: const ValueKey('slots_error'),
        title: 'Algo salió mal',
        detail: _vm.error!,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: terracotta),
            onPressed: _vm.load,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (_vm.hasNoSlots) {
      return _card(
        key: const ValueKey('slots_empty_state'),
        title: 'No hay horarios disponibles',
        detail: 'La mesa elegida no tiene horarios libres para esa fecha y duración.',
        actions: [
          OutlinedButton(
            key: const ValueKey('btn_choose_other_table'),
            onPressed: () => widget.onChangeStep(4),
            child: const Text('Elegir otra mesa'),
          ),
          OutlinedButton(
            key: const ValueKey('btn_choose_other_date'),
            onPressed: () => widget.onChangeStep(1),
            child: const Text('Elegir otra fecha'),
          ),
        ],
      );
    }

    final seleccionado = _vm.selected;
    return Wrap(
      key: const ValueKey('slots_grid'),
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in _vm.slots)
          _SlotChip(
            key: ValueKey('slot_chip_${hhmm(s.inicio).replaceAll(':', '')}'),
            label: hhmm(s.inicio),
            sublabel: 'a ${hhmm(s.fin)}',
            selected: seleccionado == s,
            onTap: () => _vm.select(s),
          ),
      ],
    );
  }

  Widget _card({
    required Key key,
    required String title,
    required String detail,
    required List<Widget> actions,
  }) {
    return Container(
      key: key,
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
          const Icon(Icons.schedule, size: 36, color: terracotta),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(fontSize: 13.5, color: mutedText),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  static String _duracion(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    if (h > 0 && m > 0) return '$h h $m min';
    if (h > 0) return '$h h';
    return '$m min';
  }
}

class _SlotChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _SlotChip({
    super.key,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Horario de $label $sublabel',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 112,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFB34A26) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF7E2F14)
                  : const Color(0xFFEDE4D8),
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: selected ? Colors.white : const Color(0xFF2E241E),
                    ),
                  ),
                ],
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white70 : const Color(0xFF7A6E65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
