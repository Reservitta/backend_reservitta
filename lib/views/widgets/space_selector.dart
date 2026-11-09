import 'package:flutter/material.dart';

import '../../viewmodels/table_selection_viewmodel.dart';

/// Selector de espacio (piso, patio, interior…) del paso "Elige tu mesa" (HU34-RF04).
/// Solo aparece si el restaurante tiene más de un espacio con mesas.
class SpaceSelector extends StatelessWidget {
  final TableSelectionViewModel viewModel;

  const SpaceSelector({super.key, required this.viewModel});

  static const Color terracotta = Color(0xFFB34A26);

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hayVariosEspacios) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('selector_espacio'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿En qué espacio quieres sentarte?',
          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E241E)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in viewModel.espacios)
              ChoiceChip(
                key: ValueKey('chip_espacio_${e.id}'),
                selected: viewModel.zonaActivaId == e.id,
                selectedColor: const Color(0xFFFFE3D6),
                label: Text(_etiqueta(e.nombre, viewModel.disponiblesEn(e.id))),
                onSelected: (_) => viewModel.seleccionarZona(e.id),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  static String _etiqueta(String nombre, int disponibles) {
    if (disponibles == 0) return '$nombre · sin mesas libres';
    return '$nombre · $disponibles ${disponibles == 1 ? 'mesa libre' : 'mesas libres'}';
  }
}
