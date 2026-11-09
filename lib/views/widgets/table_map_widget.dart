import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/mesa_model.dart';
import '../../viewmodels/table_selection_viewmodel.dart';
import '../../theme/app_theme.dart';

/// Colores e iconos de cada estado de mesa. El icono acompaña al color para que
/// el estado no dependa solo del color (HU10-RF02, accesibilidad).
class TableStateStyle {
  final Color fill;
  final Color border;
  final Color foreground;
  final IconData icon;
  final String label;

  const TableStateStyle({
    required this.fill,
    required this.border,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  static TableStateStyle of(TableVisualState state) {
    switch (state) {
      case TableVisualState.disponible:
        return const TableStateStyle(
          fill: Color(0xFFE6F2E6),
          border: AppColors.exito,
          foreground: Color(0xFF1B5E20),
          icon: Icons.check_circle_outline,
          label: 'Disponible',
        );
      case TableVisualState.ocupada:
        return const TableStateStyle(
          fill: Color(0xFFEDEAE6),
          border: Color(0xFF9E9387),
          foreground: Color(0xFF6B6157),
          icon: Icons.lock_outline,
          label: 'Ocupada',
        );
      case TableVisualState.noAdecuada:
        return const TableStateStyle(
          fill: Color(0xFFFFF3D6),
          border: Color(0xFFE0A100),
          foreground: Color(0xFF7A5A00),
          icon: Icons.group_off_outlined,
          label: 'No adecuada para el grupo',
        );
      case TableVisualState.seleccionada:
        return const TableStateStyle(
          fill: AppColors.marca,
          border: Color(0xFF7E2F14),
          foreground: Colors.white,
          icon: Icons.check_circle,
          label: 'Seleccionada',
        );
      case TableVisualState.noDisponible:
        return const TableStateStyle(
          fill: Color(0xFFEDEAE6),
          border: Color(0xFFBDB3A7),
          foreground: Color(0xFF8A7B6D),
          icon: Icons.event_busy_outlined,
          label: 'No disponible',
        );
    }
  }
}

/// Plano del restaurante con zoom y desplazamiento (HU10-RF02). Si no hay plano
/// configurado muestra las mesas en una lista.
class TableMapWidget extends StatelessWidget {
  final TableSelectionViewModel viewModel;
  final void Function(MesaModel mesa) onTapMesa;

  const TableMapWidget({
    super.key,
    required this.viewModel,
    required this.onTapMesa,
  });

  static const double _padding = 24;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasPlan) {
      return _TableList(viewModel: viewModel, onTapMesa: onTapMesa);
    }

    final mesas = viewModel.mesasVisibles.map((p) => p.mesa).toList();
    // El plano empieza en la mesa más a la izquierda y arriba (sin hueco hasta el origen).
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = 0.0;
    var maxY = 0.0;
    for (final m in mesas) {
      minX = math.min(minX, m.x ?? 0);
      minY = math.min(minY, m.y ?? 0);
      maxX = math.max(maxX, (m.x ?? 0) + m.ancho);
      maxY = math.max(maxY, (m.y ?? 0) + m.alto);
    }
    if (mesas.isEmpty) {
      minX = 0;
      minY = 0;
    }
    final width = maxX - minX + _padding * 2;
    final height = maxY - minY + _padding * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const ValueKey('table_map'),
          height: math.min(380, math.max(220, height)),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divisor),
          ),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(60),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    for (final m in mesas)
                      Positioned(
                        left: (m.x ?? 0) - minX + _padding,
                        top: (m.y ?? 0) - minY + _padding,
                        width: m.ancho,
                        height: m.alto,
                        child: _TableTile(
                          mesa: m,
                          state: viewModel.stateOf(m),
                          onTap: () => onTapMesa(m),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pellizca para acercar y arrastra para moverte por el plano.',
          style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
        ),
      ],
    );
  }
}

class _TableTile extends StatelessWidget {
  final MesaModel mesa;
  final TableVisualState state;
  final VoidCallback onTap;

  const _TableTile({
    required this.mesa,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = TableStateStyle.of(state);
    final redonda = mesa.forma == MesaModel.formaRedonda;

    return Semantics(
      button: true,
      label:
          '${mesa.nombre}, capacidad ${mesa.capacidad} personas, ${style.label}',
      child: GestureDetector(
        key: ValueKey('table_tile_${mesa.id}'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: style.fill,
            shape: redonda ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: redonda ? null : BorderRadius.circular(12),
            border: Border.all(
              color: style.border,
              width: state == TableVisualState.seleccionada ? 4 : 2,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(style.icon, color: style.foreground, size: 22),
                  Text(
                    mesa.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: style.foreground,
                    ),
                  ),
                  Text(
                    '${mesa.capacidad} pers.',
                    style: TextStyle(fontSize: 12, color: style.foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alternativa al plano cuando el restaurante no lo tiene configurado (HU10-RF02).
class _TableList extends StatelessWidget {
  final TableSelectionViewModel viewModel;
  final void Function(MesaModel mesa) onTapMesa;

  const _TableList({required this.viewModel, required this.onTapMesa});

  @override
  Widget build(BuildContext context) {
    final zonas = {for (final z in viewModel.plan.zonas) z.id: z.nombre};
    return Column(
      key: const ValueKey('table_list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Este restaurante aún no tiene plano. Elige una mesa de la lista.',
            style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
          ),
        ),
        for (final p in viewModel.mesasVisibles)
          Builder(
            builder: (context) {
              final state = viewModel.stateOf(p.mesa);
              final style = TableStateStyle.of(state);
              final zona = zonas[p.mesa.zonaId];
              return Card(
                key: ValueKey('table_tile_${p.mesa.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: style.fill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: style.border,
                    width: state == TableVisualState.seleccionada ? 3 : 1.5,
                  ),
                ),
                child: ListTile(
                  onTap: () => onTapMesa(p.mesa),
                  leading: Icon(style.icon, color: style.foreground),
                  title: Text(
                    p.mesa.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: style.foreground,
                    ),
                  ),
                  subtitle: Text(
                    'Capacidad ${p.mesa.capacidad}'
                    '${zona != null ? ' · $zona' : ''} · ${style.label}',
                    style: TextStyle(color: style.foreground),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Leyenda de los estados del plano (HU10-RF02).
class TableLegend extends StatelessWidget {
  const TableLegend({super.key});

  @override
  Widget build(BuildContext context) {
    const estados = [
      TableVisualState.disponible,
      TableVisualState.seleccionada,
      TableVisualState.ocupada,
      TableVisualState.noAdecuada,
    ];
    return Wrap(
      key: const ValueKey('table_legend'),
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final e in estados)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: TableStateStyle.of(e).fill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: TableStateStyle.of(e).border,
                    width: 2,
                  ),
                ),
                child: Icon(
                  TableStateStyle.of(e).icon,
                  size: 14,
                  color: TableStateStyle.of(e).foreground,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                TableStateStyle.of(e).label,
                style: const TextStyle(fontSize: 12, color: AppColors.texto),
              ),
            ],
          ),
      ],
    );
  }
}
