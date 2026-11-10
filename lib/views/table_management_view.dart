import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mesa_model.dart';
import '../models/reservation_model.dart';
import '../models/table_live_status.dart';
import '../viewmodels/admin_operations_viewmodel.dart';
import 'plan_editor_view.dart';
import '../theme/app_theme.dart';

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
          border: AppColors.exito,
          foreground: Color(0xFF1B5E20),
          icon: Icons.check_circle_outline,
        );
      case EstadoMesaVivo.ocupada:
        return const TableLiveStyle(
          fill: Color(0xFFFFE3D6),
          border: AppColors.marca,
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

  static const Color _terracotta = AppColors.marca;
  static const Color _textDark = AppColors.texto;
  static const Color _textMuted = AppColors.textoSuave;
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
        final todas = operaciones.estadosMesas;
        final estados = operaciones.estadosMesasVisibles;
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Text(
                              'Mesas',
                              style: TextStyle(
                                fontFamily: AppTheme.familiaTitulos,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: _textDark,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            key: const ValueKey('btn_editar_plano'),
                            style: FilledButton.styleFrom(backgroundColor: _terracotta),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PlanEditorView(restaurantId: operaciones.restaurantId),
                              ),
                            ),
                            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                            label: Text(todas.isEmpty ? 'Crear mi plano' : 'Editar plano'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Estado de cada mesa en este momento.',
                        style: TextStyle(fontSize: 13.5, color: _textMuted),
                      ),
                      const SizedBox(height: 14),
                      if (operaciones.zonas.isNotEmpty) ...[
                        _SelectorEspacio(operaciones: operaciones),
                        const SizedBox(height: 14),
                      ],
                      const _Leyenda(),
                      const SizedBox(height: 14),
                      if (operaciones.error != null)
                        Text(
                          operaciones.error!,
                          key: const ValueKey('mesas_error'),
                          style: const TextStyle(color: Colors.red),
                        )
                      else if (todas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'Este restaurante todavía no tiene mesas registradas.\n'
                            'Toca "Crear mi plano" para armar tu mapa de mesas.',
                            key: ValueKey('mesas_vacio'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _textMuted),
                          ),
                        )
                      else if (estados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'Este espacio todavía no tiene mesas.',
                            key: ValueKey('espacio_vacio'),
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
    // El plano empieza en la mesa más a la izquierda y arriba: así no queda un hueco
    // entre el borde y las mesas cuando el espacio tiene pocas o están lejos del origen.
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = 0.0;
    var maxY = 0.0;
    for (final e in estados) {
      minX = math.min(minX, e.mesa.x ?? 0);
      minY = math.min(minY, e.mesa.y ?? 0);
      maxX = math.max(maxX, (e.mesa.x ?? 0) + e.mesa.ancho);
      maxY = math.max(maxY, (e.mesa.y ?? 0) + e.mesa.alto);
    }
    final width = maxX - minX + _padding * 2;
    final height = maxY - minY + _padding * 2;

    return Container(
      key: const ValueKey('mesas_plano'),
      height: math.min(460, math.max(240, height)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(8),
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
                for (final e in estados)
                  Positioned(
                    left: (e.mesa.x ?? 0) - minX + _padding,
                    top: (e.mesa.y ?? 0) - minY + _padding,
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
                borderRadius: BorderRadius.circular(6),
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
            borderRadius: redonda ? null : BorderRadius.circular(6),
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

/// Pestañas con los espacios (pisos, patio…) del restaurante.
class _SelectorEspacio extends StatelessWidget {
  final AdminOperationsViewModel operaciones;

  const _SelectorEspacio({required this.operaciones});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const ValueKey('selector_espacio_admin'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final z in operaciones.zonas)
          ChoiceChip(
            key: ValueKey('chip_espacio_admin_${z.id}'),
            selected: operaciones.zonaMesasId == z.id,
            selectedColor: const Color(0xFFFFE3D6),
            label: Text(
              '${z.nombre} (${operaciones.estadosMesas.where((e) => e.mesa.zonaId == z.id).length})',
            ),
            onSelected: (_) => operaciones.seleccionarZonaMesas(z.id),
          ),
        // Las mesas que no están en ningún espacio no se esconden.
        if (operaciones.mesasSinEspacio > 0)
          ChoiceChip(
            key: const ValueKey('chip_espacio_admin_sin_espacio'),
            selected: operaciones.zonaMesasId == AdminOperationsViewModel.sinEspacioId,
            selectedColor: const Color(0xFFFFE3D6),
            label: Text('Sin espacio (${operaciones.mesasSinEspacio})'),
            onSelected: (_) =>
                operaciones.seleccionarZonaMesas(AdminOperationsViewModel.sinEspacioId),
          ),
      ],
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
              Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.texto)),
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
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.divisor),
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
                style: TextStyle(color: AppColors.textoSuave),
              ),
              const SizedBox(height: 10),
            ],
            if (e.mesa.fueraDeServicio)
              FilledButton.icon(
                key: const ValueKey('btn_mesa_reactivar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.exito,
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
                  style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
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
