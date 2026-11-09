import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mesa_model.dart';
import '../models/reservation_model.dart';
import '../models/table_live_status.dart';
import '../viewmodels/admin_operations_viewmodel.dart';

/// Color, ícono y etiqueta de cada estado de mesa en la vista de gestión (HU31-RF02).
class TableLiveStyle {
  final Color fill;
  final Color border;
  final Color foreground;
  final IconData icon;

  const TableLiveStyle({
    required this.fill,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  static TableLiveStyle of(EstadoMesaVivo estado) {
    switch (estado) {
      case EstadoMesaVivo.disponible:
        return const TableLiveStyle(
          fill: Color(0xFFE6F2E6),
          border: Color(0xFF2E7D32),
          foreground: Color(0xFF1B5E20),
          icon: Icons.check_circle_outline,
        );
      case EstadoMesaVivo.ocupada:
        return const TableLiveStyle(
          fill: Color(0xFFFFE3D6),
          border: Color(0xFFB34A26),
          foreground: Color(0xFF7E2F14),
          icon: Icons.restaurant,
        );
      case EstadoMesaVivo.combinada:
        return const TableLiveStyle(
          fill: Color(0xFFE3F2FD),
          border: Color(0xFF1565C0),
          foreground: Color(0xFF0D47A1),
          icon: Icons.link,
        );
      case EstadoMesaVivo.fueraDeServicio:
        return const TableLiveStyle(
          fill: Color(0xFFECEFF1),
          border: Color(0xFF78909C),
          foreground: Color(0xFF455A64),
          icon: Icons.build_circle_outlined,
        );
    }
  }
}

/// Estado actual de las mesas (HU31-RF02): el plano del restaurante, o una lista si no
/// hay plano configurado. Al tocar una mesa se ve su reserva y se puede marcar fuera de
/// servicio o volver a activarla.
class TableManagementView extends StatelessWidget {
  final AdminOperationsViewModel operaciones;
  final void Function(ReservationModel reserva) onAbrirReserva;

  const TableManagementView({
    super.key,
    required this.operaciones,
    required this.onAbrirReserva,
  });

  static const Color _terracotta = Color(0xFFB34A26);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const double _padding = 24;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: operaciones,
      builder: (context, _) {
        if (operaciones.cargando) {
          return const Center(
            child: CircularProgressIndicator(
              key: ValueKey('mesas_cargando'),
              color: _terracotta,
            ),
          );
        }
        final estados = operaciones.estadosMesas;
        final hayPlano = estados.isNotEmpty && estados.every((e) => e.mesa.tienePosicion);

        return RefreshIndicator(
          color: _terracotta,
          onRefresh: operaciones.refrescar,
          child: ListView(
            key: const ValueKey('mesas_contenido'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Mesas',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Estado de cada mesa en este momento.',
                        style: TextStyle(fontSize: 13.5, color: _textMuted),
                      ),
                      const SizedBox(height: 14),
                      const _Leyenda(),
                      const SizedBox(height: 14),
                      if (operaciones.error != null)
                        Text(
                          operaciones.error!,
                          key: const ValueKey('mesas_error'),
                          style: const TextStyle(color: Colors.red),
                        )
                      else if (estados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'Este restaurante todavía no tiene mesas registradas.',
                            key: ValueKey('mesas_vacio'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _textMuted),
                          ),
                        )
                      else if (hayPlano)
                        _plano(context, estados)
                      else
                        _lista(context, estados),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _plano(BuildContext context, List<TableLiveStatus> estados) {
    var width = 0.0;
    var height = 0.0;
    for (final e in estados) {
      width = math.max(width, (e.mesa.x ?? 0) + e.mesa.ancho);
      height = math.max(height, (e.mesa.y ?? 0) + e.mesa.alto);
    }
    width += _padding * 2;
    height += _padding * 2;

    return Container(
      key: const ValueKey('mesas_plano'),
      height: math.min(460, math.max(240, height)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE4D8)),
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
                for (final e in estados)
                  Positioned(
                    left: (e.mesa.x ?? 0) + _padding,
                    top: (e.mesa.y ?? 0) + _padding,
                    width: e.mesa.ancho,
                    height: e.mesa.alto,
                    child: _MesaTile(estado: e, onTap: () => _abrirMesa(context, e)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lista(BuildContext context, List<TableLiveStatus> estados) {
    return Column(
      key: const ValueKey('mesas_lista'),
      children: [
        for (final e in estados)
          Builder(builder: (context) {
            final s = TableLiveStyle.of(e.estado);
            return Card(
              key: ValueKey('mesa_${e.mesa.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: s.fill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: s.border, width: 1.5),
              ),
              child: ListTile(
                minVerticalPadding: 10,
                onTap: () => _abrirMesa(context, e),
                leading: Icon(s.icon, color: s.foreground),
                title: Text(
                  e.mesa.nombre,
                  style: TextStyle(fontWeight: FontWeight.bold, color: s.foreground),
                ),
                subtitle: Text(
                  'Capacidad ${e.mesa.capacidad} · ${e.etiqueta}'
                  '${e.combinadaCon.isNotEmpty ? ' con ${e.combinadaCon.join(', ')}' : ''}',
                  style: TextStyle(color: s.foreground),
                ),
                trailing: Icon(Icons.chevron_right, color: s.foreground),
              ),
            );
          }),
      ],
    );
  }

  void _abrirMesa(BuildContext context, TableLiveStatus estado) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _MesaSheet(
        estado: estado,
        operaciones: operaciones,
        onAbrirReserva: (r) {
          Navigator.of(ctx).pop();
          onAbrirReserva(r);
        },
      ),
    );
  }
}

class _MesaTile extends StatelessWidget {
  final TableLiveStatus estado;
  final VoidCallback onTap;

  const _MesaTile({required this.estado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = TableLiveStyle.of(estado.estado);
    final m = estado.mesa;
    final redonda = m.forma == MesaModel.formaRedonda;
    return Semantics(
      button: true,
      label: '${m.nombre}, capacidad ${m.capacidad} personas, ${estado.etiqueta}',
      child: GestureDetector(
        key: ValueKey('mesa_${m.id}'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: s.fill,
            shape: redonda ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: redonda ? null : BorderRadius.circular(12),
            border: Border.all(color: s.border, width: 2),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, color: s.foreground, size: 22),
                  Text(
                    m.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: s.foreground,
                    ),
                  ),
                  Text(
                    '${m.capacidad} pers.',
                    style: TextStyle(fontSize: 12, color: s.foreground),
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

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    const items = [
      (EstadoMesaVivo.disponible, 'Disponible'),
      (EstadoMesaVivo.ocupada, 'Ocupada'),
      (EstadoMesaVivo.combinada, 'Combinada'),
      (EstadoMesaVivo.fueraDeServicio, 'Fuera de servicio'),
    ];
    return Wrap(
      key: const ValueKey('mesas_leyenda'),
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (estado, texto) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: TableLiveStyle.of(estado).fill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: TableLiveStyle.of(estado).border, width: 2),
                ),
                child: Icon(
                  TableLiveStyle.of(estado).icon,
                  size: 14,
                  color: TableLiveStyle.of(estado).foreground,
                ),
              ),
              const SizedBox(width: 6),
              Text(texto, style: const TextStyle(fontSize: 12, color: Color(0xFF2E241E))),
            ],
          ),
      ],
    );
  }
}

class _MesaSheet extends StatefulWidget {
  final TableLiveStatus estado;
  final AdminOperationsViewModel operaciones;
  final void Function(ReservationModel reserva) onAbrirReserva;

  const _MesaSheet({
    required this.estado,
    required this.operaciones,
    required this.onAbrirReserva,
  });

  @override
  State<_MesaSheet> createState() => _MesaSheetState();
}

class _MesaSheetState extends State<_MesaSheet> {
  bool _procesando = false;
  String? _error;

  Future<void> _cambiar(bool fuera) async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    final id = widget.estado.mesa.id;
    final error = fuera
        ? await widget.operaciones.ponerMesaFueraDeServicio(id)
        : await widget.operaciones.reactivarMesa(id);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _procesando = false;
        _error = error;
      });
    }
  }

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final e = widget.estado;
    final s = TableLiveStyle.of(e.estado);
    final r = e.reserva;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          key: ValueKey('hoja_mesa_${e.mesa.id}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.icon, color: s.foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${e.mesa.nombre} · ${e.mesa.capacidad} personas',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              e.etiqueta,
              key: const ValueKey('mesa_estado_texto'),
              style: TextStyle(fontWeight: FontWeight.w700, color: s.foreground),
            ),
            if (e.combinadaCon.isNotEmpty)
              Text(
                'Combinada con ${e.combinadaCon.join(', ')}',
                key: const ValueKey('mesa_combinada_con'),
              ),
            const SizedBox(height: 12),
            if (r != null) ...[
              Container(
                key: const ValueKey('mesa_reserva'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF8F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDE4D8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.contactoNombre.trim().isEmpty ? 'Cliente' : r.contactoNombre.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_hora(r.effectiveStart)} · ${r.personas} personas · ${r.etiquetaEstado}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('btn_ver_reserva_mesa'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => widget.onAbrirReserva(r),
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Ver detalle de la reserva'),
              ),
              const SizedBox(height: 10),
            ] else if (e.estado != EstadoMesaVivo.fueraDeServicio) ...[
              const Text(
                'No hay una reserva en curso en esta mesa.',
                key: ValueKey('mesa_sin_reserva'),
                style: TextStyle(color: Color(0xFF7A6E65)),
              ),
              const SizedBox(height: 10),
            ],
            if (e.mesa.fueraDeServicio)
              FilledButton.icon(
                key: const ValueKey('btn_mesa_reactivar'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _procesando ? null : () => _cambiar(false),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Volver a activar la mesa'),
              )
            else
              OutlinedButton.icon(
                key: const ValueKey('btn_mesa_fuera_servicio'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF455A64),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _procesando ? null : () => _cambiar(true),
                icon: const Icon(Icons.build_circle_outlined),
                label: const Text('Marcar fuera de servicio'),
              ),
            if (!e.mesa.fueraDeServicio && r != null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Tiene una reserva en curso: al marcarla fuera de servicio dejará de ofrecerse para nuevas reservas.',
                  key: ValueKey('mesa_aviso_fuera_servicio'),
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A6E65)),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const ValueKey('mesa_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
