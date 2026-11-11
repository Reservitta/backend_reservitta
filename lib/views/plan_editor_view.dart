import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mesa_model.dart';
import '../models/table_layout_validator.dart';
import '../models/zona_model.dart';
import '../services/table_layout_service.dart';
import '../viewmodels/plan_editor_viewmodel.dart';
import '../theme/app_theme.dart';
import 'widgets/mesa_visual.dart';

export 'widgets/mesa_visual.dart' show SillasPainter;

/// Editor del plano de mesas del administrador (HU34-RF03): espacios (pisos, patio…),
/// mesas redondas, cuadradas o rectangulares que se arrastran a su lugar, con nombre,
/// número de sillas, tamaño y combinaciones.
class PlanEditorView extends StatefulWidget {
  final String restaurantId;
  final TableLayoutService? service;
  final PlanEditorViewModel? viewModel;

  const PlanEditorView({
    super.key,
    required this.restaurantId,
    this.service,
    this.viewModel,
  });

  static const Color terracotta = AppColors.marca;
  static const Color creamBg = AppColors.fondo;
  static const Color cardBorder = AppColors.divisor;
  static const Color darkText = AppColors.texto;
  static const Color mutedText = AppColors.textoSuave;
  static const Color errorRed = Color(0xFFC62828);

  @override
  State<PlanEditorView> createState() => _PlanEditorViewState();
}

class _PlanEditorViewState extends State<PlanEditorView> {
  late final PlanEditorViewModel _vm;
  final TransformationController _zoom = TransformationController();
  bool _zoomInicial = false;

  @override
  void initState() {
    super.initState();
    _vm =
        widget.viewModel ??
        PlanEditorViewModel(
          restaurantId: widget.restaurantId,
          service: widget.service,
        );
    _vm.cargar();
  }

  @override
  void dispose() {
    _zoom.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Diálogos
  // ---------------------------------------------------------------------------

  Future<void> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('dialogo_cambios_sin_guardar'),
        title: const Text('Tienes cambios sin guardar'),
        content: const Text(
          'Si sales ahora, los cambios en las mesas se perderán.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('btn_seguir_editando'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            key: const ValueKey('btn_salir_sin_guardar'),
            style: FilledButton.styleFrom(
              backgroundColor: PlanEditorView.errorRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    if (salir == true && mounted) {
      _vm.descartar();
      Navigator.of(context).pop();
    }
  }

  Future<void> _dialogoEspacio({ZonaModel? zona}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EspacioDialog(
        inicial: zona?.nombre ?? '',
        titulo: zona == null ? 'Nuevo espacio' : 'Renombrar espacio',
        onGuardar: (nombre) => zona == null
            ? _vm.agregarZona(nombre)
            : _vm.renombrarZona(zona.id, nombre),
      ),
    );
  }

  Future<void> _eliminarEspacio(ZonaModel zona) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('dialogo_eliminar_espacio'),
        title: Text('¿Eliminar "${zona.nombre}"?'),
        content: const Text(
          'El espacio se borrará. Solo se puede eliminar si no tiene mesas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('btn_confirmar_eliminar_espacio'),
            style: FilledButton.styleFrom(
              backgroundColor: PlanEditorView.errorRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await _vm.eliminarZona(zona.id);
    if (error != null && mounted) _avisar(error);
  }

  Future<void> _eliminarMesa(MesaModel mesa) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('dialogo_eliminar_mesa'),
        title: Text('¿Eliminar ${mesa.nombre}?'),
        content: const Text(
          'La mesa se quitará del plano cuando guardes los cambios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('btn_confirmar_eliminar_mesa'),
            style: FilledButton.styleFrom(
              backgroundColor: PlanEditorView.errorRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) _vm.eliminarMesa(mesa.id);
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(key: const ValueKey('snack_plano'), content: Text(mensaje)),
      );
  }

  Future<void> _guardar() async {
    final ok = await _vm.guardar();
    if (ok && mounted) _avisar('Plano guardado.');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return PopScope(
          canPop: !_vm.hayCambios,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmarSalida();
          },
          child: Scaffold(
            backgroundColor: PlanEditorView.creamBg,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: PlanEditorView.darkText,
              elevation: 0,
              title: const Text(
                'Plano de mesas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('btn_descartar_plano'),
                  onPressed: _vm.hayCambios && !_vm.guardando
                      ? _vm.descartar
                      : null,
                  child: const Text('Descartar'),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12, left: 4),
                  child: FilledButton(
                    key: const ValueKey('btn_guardar_plano'),
                    style: FilledButton.styleFrom(
                      backgroundColor: PlanEditorView.terracotta,
                    ),
                    onPressed: _vm.hayCambios && !_vm.guardando
                        ? _guardar
                        : null,
                    child: _vm.guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar plano'),
                  ),
                ),
              ],
            ),
            body: _cuerpo(),
          ),
        );
      },
    );
  }

  Widget _cuerpo() {
    if (_vm.cargando) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('plano_cargando'),
          color: PlanEditorView.terracotta,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth >= 860;
        final lienzo = _lienzo();
        final panel = _vm.seleccionada == null
            ? null
            : _PanelMesa(vm: _vm, onEliminar: _eliminarMesa);
        return Column(
          children: [
            _barraEspacios(),
            _barraHerramientas(),
            if (_vm.error != null) _bannerError(),
            Expanded(
              child: ancho
                  ? Row(
                      children: [
                        Expanded(child: lienzo),
                        if (panel != null) SizedBox(width: 320, child: panel),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: lienzo),
                        if (panel != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: c.maxHeight * 0.5,
                            ),
                            child: panel,
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _bannerError() {
    return Container(
      key: const ValueKey('error_plano'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Text(
        _vm.error!,
        style: const TextStyle(color: PlanEditorView.errorRed),
      ),
    );
  }

  Widget _barraEspacios() {
    final pestanas = _vm.pestanas;
    final activa = pestanas.where((z) => z.id == _vm.zonaActivaId).firstOrNull;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (pestanas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Text(
                  'Un solo plano. Agrega espacios si tienes pisos, patio, etc.',
                  key: ValueKey('texto_sin_espacios'),
                  style: TextStyle(
                    color: PlanEditorView.mutedText,
                    fontSize: 13,
                  ),
                ),
              ),
            for (final z in pestanas)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey('tab_espacio_${z.id}'),
                  label: Text('${z.nombre} (${_contar(z.id)})'),
                  selected: z.id == _vm.zonaActivaId,
                  selectedColor: AppColors.marcaSuave,
                  onSelected: (_) => _vm.seleccionarZona(z.id),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey('btn_agregar_espacio'),
              onPressed: () => _dialogoEspacio(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Espacio'),
            ),
            if (activa != null &&
                activa.id != PlanEditorViewModel.sinEspacioId) ...[
              IconButton(
                key: const ValueKey('btn_renombrar_espacio'),
                tooltip: 'Renombrar espacio',
                onPressed: () => _dialogoEspacio(zona: activa),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                key: const ValueKey('btn_eliminar_espacio'),
                tooltip: 'Eliminar espacio',
                onPressed: () => _eliminarEspacio(activa),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: PlanEditorView.errorRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _contar(String zonaId) {
    if (zonaId == PlanEditorViewModel.sinEspacioId) {
      return _vm.mesas
          .where(
            (m) => m.zonaId == null || !_vm.zonas.any((z) => z.id == m.zonaId),
          )
          .length;
    }
    return _vm.mesas.where((m) => m.zonaId == zonaId).length;
  }

  Widget _barraHerramientas() {
    Widget boton(String forma, String texto, IconData icono) =>
        OutlinedButton.icon(
          key: ValueKey('btn_agregar_mesa_$forma'),
          onPressed: () => _vm.agregarMesa(forma: forma),
          icon: Icon(icono, size: 18),
          label: Text(texto),
        );
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Agregar mesa:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: PlanEditorView.darkText,
            ),
          ),
          boton(MesaModel.formaCuadrada, 'Cuadrada', Icons.crop_square),
          boton(MesaModel.formaRedonda, 'Redonda', Icons.circle_outlined),
          boton(MesaModel.formaRectangular, 'Rectangular', Icons.crop_16_9),
        ],
      ),
    );
  }

  Widget _lienzo() {
    final mesas = _vm.mesasVisibles;
    return LayoutBuilder(
      builder: (context, c) {
        if (!_zoomInicial && c.maxWidth.isFinite && c.maxWidth > 0) {
          _zoomInicial = true;
          final escala = math.min(
            1.0,
            c.maxWidth / PlanEditorViewModel.anchoLienzo,
          );
          _zoom.value = Matrix4.diagonal3Values(escala, escala, 1);
        }
        return Container(
          key: const ValueKey('plano_lienzo'),
          margin: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F1E9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PlanEditorView.cardBorder),
          ),
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: _zoom,
                constrained: false,
                minScale: 0.3,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(200),
                child: SizedBox(
                  width: PlanEditorViewModel.anchoLienzo,
                  height: PlanEditorViewModel.altoLienzo,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          key: const ValueKey('plano_fondo'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _vm.seleccionar(null),
                          child: CustomPaint(painter: _CuadriculaPainter()),
                        ),
                      ),
                      for (final m in mesas) _MesaTile(vm: _vm, mesa: m),
                    ],
                  ),
                ),
              ),
              if (mesas.isEmpty)
                const Center(
                  child: IgnorePointer(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no hay mesas en este espacio.\nUsa "Agregar mesa" para empezar.',
                        key: ValueKey('plano_vacio'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PlanEditorView.mutedText,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Lienzo
// -----------------------------------------------------------------------------

class _CuadriculaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fina = Paint()
      ..color = const Color(0xFFEDE5D8)
      ..strokeWidth = 1;
    final gruesa = Paint()
      ..color = const Color(0xFFE2D8C7)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += PlanEditorViewModel.paso * 2) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        x % 100 == 0 ? gruesa : fina,
      );
    }
    for (var y = 0.0; y <= size.height; y += PlanEditorViewModel.paso * 2) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        y % 100 == 0 ? gruesa : fina,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MesaTile extends StatelessWidget {
  final PlanEditorViewModel vm;
  final MesaModel mesa;

  const _MesaTile({required this.vm, required this.mesa});

  @override
  Widget build(BuildContext context) {
    final seleccionada = vm.seleccionadaId == mesa.id;
    final conError = vm.erroresDe(mesa.id).isNotEmpty;
    final paleta = conError
        ? MesaPaleta.editorConError
        : seleccionada
            ? MesaPaleta.editorSeleccionada
            : MesaPaleta.editor;

    return Positioned(
      left: mesa.x ?? 0,
      top: mesa.y ?? 0,
      width: mesa.ancho,
      height: mesa.alto,
      child: Semantics(
        button: true,
        label: '${mesa.nombre}, ${mesa.capacidad} sillas',
        child: GestureDetector(
          key: ValueKey('mesa_${mesa.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => vm.seleccionar(mesa.id),
          onPanStart: (_) => vm.seleccionar(mesa.id),
          onPanUpdate: (d) => vm.arrastrarMesa(mesa.id, d.delta.dx, d.delta.dy),
          onPanEnd: (_) => vm.soltarMesa(mesa.id),
          child: MesaVisual(
            mesa: mesa,
            paleta: paleta,
            seleccionada: seleccionada || conError,
            detalle: '${mesa.capacidad} ${mesa.capacidad == 1 ? 'silla' : 'sillas'}',
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Panel de la mesa seleccionada
// -----------------------------------------------------------------------------

class _PanelMesa extends StatefulWidget {
  final PlanEditorViewModel vm;
  final Future<void> Function(MesaModel mesa) onEliminar;

  const _PanelMesa({required this.vm, required this.onEliminar});

  @override
  State<_PanelMesa> createState() => _PanelMesaState();
}

class _PanelMesaState extends State<_PanelMesa> {
  late TextEditingController _nombre;
  String? _idNombre;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController();
    _sincronizar();
  }

  @override
  void didUpdateWidget(covariant _PanelMesa old) {
    super.didUpdateWidget(old);
    _sincronizar();
  }

  /// El campo de nombre solo se reescribe al cambiar de mesa (no mientras se escribe).
  void _sincronizar() {
    final m = widget.vm.seleccionada;
    if (m != null && m.id != _idNombre) {
      _idNombre = m.id;
      _nombre.text = m.nombre;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final mesa = vm.seleccionada;
    if (mesa == null) return const SizedBox.shrink();
    final errores = vm.erroresDe(mesa.id);
    final rect = mesa.forma == MesaModel.formaRectangular;
    final candidatas = [
      for (final o in vm.mesas)
        if (o.id != mesa.id && o.combinable) o,
    ];

    return Container(
      key: const ValueKey('panel_mesa'),
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PlanEditorView.cardBorder),
      ),
      // Material transparente: los interruptores y chips pintan su efecto sobre él.
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mesa seleccionada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('btn_cerrar_panel'),
                    tooltip: 'Cerrar',
                    onPressed: () => vm.seleccionar(null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              TextField(
                key: const ValueKey('campo_mesa_nombre'),
                controller: _nombre,
                maxLength: TableLayoutValidator.mesaNombreMax,
                onChanged: (v) => vm.cambiarNombre(mesa.id, v),
                decoration: InputDecoration(
                  labelText: 'Nombre o número',
                  errorText: errores['nombre'],
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sillas',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton.outlined(
                    key: const ValueKey('btn_capacidad_menos'),
                    tooltip: 'Menos sillas',
                    onPressed:
                        mesa.capacidad > TableLayoutValidator.capacidadMinima
                        ? () => vm.ajustarCapacidad(mesa.id, -1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${mesa.capacidad}',
                      key: const ValueKey('texto_capacidad'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    key: const ValueKey('btn_capacidad_mas'),
                    tooltip: 'Más sillas',
                    onPressed:
                        mesa.capacidad < TableLayoutValidator.capacidadMaxima
                        ? () => vm.ajustarCapacidad(mesa.id, 1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (errores['capacidad'] != null)
                Text(
                  errores['capacidad']!,
                  style: const TextStyle(
                    color: PlanEditorView.errorRed,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 14),
              const Text(
                'Forma',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in const [
                    (MesaModel.formaCuadrada, 'Cuadrada'),
                    (MesaModel.formaRedonda, 'Redonda'),
                    (MesaModel.formaRectangular, 'Rectangular'),
                  ])
                    ChoiceChip(
                      key: ValueKey('chip_forma_${f.$1}'),
                      label: Text(f.$2),
                      selected: mesa.forma == f.$1,
                      onSelected: (_) => vm.cambiarForma(mesa.id, f.$1),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                rect
                    ? 'Ancho: ${mesa.ancho.round()}'
                    : 'Tamaño: ${mesa.ancho.round()}',
              ),
              Slider(
                key: const ValueKey('slider_ancho'),
                min: TableLayoutValidator.tamanoMinimo,
                max: TableLayoutValidator.tamanoMaximo,
                divisions: 26,
                value: mesa.ancho.clamp(
                  TableLayoutValidator.tamanoMinimo,
                  TableLayoutValidator.tamanoMaximo,
                ),
                onChanged: (v) => vm.cambiarTamano(mesa.id, ancho: v),
              ),
              if (rect) ...[
                Text('Alto: ${mesa.alto.round()}'),
                Slider(
                  key: const ValueKey('slider_alto'),
                  min: TableLayoutValidator.tamanoMinimo,
                  max: TableLayoutValidator.tamanoMaximo,
                  divisions: 26,
                  value: mesa.alto.clamp(
                    TableLayoutValidator.tamanoMinimo,
                    TableLayoutValidator.tamanoMaximo,
                  ),
                  onChanged: (v) => vm.cambiarTamano(mesa.id, alto: v),
                ),
              ],
              if (vm.zonas.isNotEmpty) ...[
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: ValueKey('dropdown_espacio_${mesa.id}'),
                  initialValue:
                      (mesa.zonaId != null &&
                          vm.zonas.any((z) => z.id == mesa.zonaId))
                      ? mesa.zonaId
                      : PlanEditorViewModel.sinEspacioId,
                  decoration: InputDecoration(
                    labelText: 'Espacio',
                    errorText: errores['zona'],
                  ),
                  items: [
                    for (final z in vm.zonas)
                      DropdownMenuItem(value: z.id, child: Text(z.nombre)),
                    const DropdownMenuItem(
                      value: PlanEditorViewModel.sinEspacioId,
                      child: Text('Sin espacio'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) vm.moverAEspacio(mesa.id, v);
                  },
                ),
              ],
              SwitchListTile(
                key: const ValueKey('switch_combinable'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Se puede combinar'),
                subtitle: const Text(
                  'Se junta con otras mesas para grupos grandes.',
                ),
                value: mesa.combinable,
                onChanged: (v) => vm.cambiarCombinable(mesa.id, v),
              ),
              if (mesa.combinable)
                candidatas.isEmpty
                    ? const Text(
                        'Marca otra mesa como combinable para unirlas.',
                        key: ValueKey('texto_sin_candidatas'),
                        style: TextStyle(
                          color: PlanEditorView.mutedText,
                          fontSize: 12.5,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        children: [
                          for (final o in candidatas)
                            FilterChip(
                              key: ValueKey('chip_combinar_${o.id}'),
                              label: Text(
                                o.nombre.isEmpty ? '¿Nombre?' : o.nombre,
                              ),
                              selected: mesa.combinableCon.contains(o.id),
                              onSelected: (_) =>
                                  vm.alternarCombinacion(mesa.id, o.id),
                            ),
                        ],
                      ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('btn_duplicar_mesa'),
                      onPressed: () => vm.duplicarMesa(mesa.id),
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('Duplicar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('btn_eliminar_mesa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PlanEditorView.errorRed,
                      ),
                      onPressed: () => widget.onEliminar(mesa),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Diálogo de espacio
// -----------------------------------------------------------------------------

class _EspacioDialog extends StatefulWidget {
  final String inicial;
  final String titulo;

  /// Guarda el espacio; devuelve un mensaje de error o null si se guardó.
  final Future<String?> Function(String nombre) onGuardar;

  const _EspacioDialog({
    required this.inicial,
    required this.titulo,
    required this.onGuardar,
  });

  @override
  State<_EspacioDialog> createState() => _EspacioDialogState();
}

class _EspacioDialogState extends State<_EspacioDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.inicial,
  );
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await widget.onGuardar(_ctrl.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('dialogo_espacio'),
      title: Text(widget.titulo),
      content: TextField(
        key: const ValueKey('campo_espacio_nombre'),
        controller: _ctrl,
        autofocus: true,
        maxLength: TableLayoutValidator.zonaNombreMax,
        decoration: InputDecoration(
          labelText: 'Nombre del espacio',
          hintText: 'Planta baja, Segundo piso, Patio…',
          errorText: _error,
        ),
        onSubmitted: (_) => _guardar(),
      ),
      actions: [
        TextButton(
          key: const ValueKey('btn_cancelar_espacio'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('btn_guardar_espacio'),
          onPressed: _guardando ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
