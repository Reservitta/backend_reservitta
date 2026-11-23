import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/branch_model.dart';
import '../models/inventario_models.dart';
import '../services/inventario_service.dart';
import '../services/restaurant_service.dart';
import '../theme/app_theme.dart';

/// Inventario del restaurante. Los insumos son del restaurante, pero las existencias y
/// los movimientos son de cada sucursal: con varias sucursales se elige cuál se consulta.
class InventarioView extends StatefulWidget {
  final String restaurantId;
  final InventarioService? service;
  final RestaurantService? restaurantService;

  /// Sucursal con la que abre (por ejemplo, al venir del aviso del dashboard).
  final String? sucursalInicial;

  const InventarioView({
    super.key,
    required this.restaurantId,
    this.service,
    this.restaurantService,
    this.sucursalInicial,
  });

  @override
  State<InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends State<InventarioView> {
  late final InventarioService _service = widget.service ?? InventarioService();
  late final Stream<List<InsumoModel>> _insumos = _service.insumosStream(widget.restaurantId);

  List<BranchModel> _sucursales = const [];
  bool _cargando = true;
  String _sid = InventarioService.sucursalPorDefecto;
  Stream<Map<String, ExistenciaModel>>? _existencias;
  Stream<List<MovimientoInventario>>? _movimientos;
  bool _verMovimientos = false;

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    List<BranchModel> lista = const [];
    try {
      lista = await (widget.restaurantService ?? RestaurantService())
          .getBranches(widget.restaurantId);
    } catch (_) {}
    if (lista.isEmpty) {
      lista = const [
        BranchModel(
          id: InventarioService.sucursalPorDefecto,
          nombre: 'Sucursal principal',
          direccion: '',
          telefono: '',
          esPrincipal: true,
        ),
      ];
    }
    if (!mounted) return;
    final inicial = lista.any((s) => s.id == widget.sucursalInicial)
        ? widget.sucursalInicial!
        : lista.firstWhere((s) => s.esPrincipal, orElse: () => lista.first).id;
    setState(() {
      _sucursales = lista;
      _cargando = false;
    });
    _seleccionar(inicial);
  }

  void _seleccionar(String sid) {
    setState(() {
      _sid = sid;
      _existencias = _service.existenciasStream(widget.restaurantId, sid);
      _movimientos = _service.movimientosStream(widget.restaurantId, sid);
    });
  }

  String _uid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  void _aviso(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: error ? AppColors.error : AppColors.exito,
      ));
  }

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    try {
      await accion();
      if (mounted) _aviso(exito);
    } on InventarioException catch (e) {
      if (mounted) _aviso(e.message, error: true);
    } catch (_) {
      if (mounted) _aviso('No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.', error: true);
    }
  }

  Future<void> _nuevoInsumo() async {
    final r = await showDialog<_DatosInsumo>(
      context: context,
      builder: (_) => const _InsumoDialog(),
    );
    if (r == null) return;
    await _ejecutar(
      () => _service.crearInsumoConExistencia(
        widget.restaurantId,
        _sid,
        nombre: r.nombre,
        unidad: r.unidad,
        minimo: r.minimo,
        existenciaInicial: r.existencia,
        por: _uid(),
      ),
      'Insumo "${r.nombre}" agregado.',
    );
  }

  Future<void> _editarInsumo(InsumoModel i) async {
    final r = await showDialog<_DatosInsumo>(
      context: context,
      builder: (_) => _InsumoDialog(insumo: i),
    );
    if (r == null) return;
    await _ejecutar(
      () => _service.actualizarInsumo(widget.restaurantId, i.id, nombre: r.nombre, unidad: r.unidad),
      'Insumo actualizado.',
    );
  }

  Future<void> _definirMinimo(InsumoModel i, ExistenciaModel ex) async {
    final valor = await showDialog<_DatosCantidad>(
      context: context,
      builder: (_) => _CantidadDialog(
        titulo: 'Mínimo de ${i.nombre}',
        etiqueta: 'Avisar cuando queden',
        unidad: i.unidad,
        inicial: ex.minimo > 0 ? formatoCantidad(ex.minimo) : '',
        permiteCero: true,
        conMotivo: false,
        textoBoton: 'Guardar',
      ),
    ).then((r) => r?.cantidad);
    if (valor == null) return;
    await _ejecutar(
      () => _service.definirMinimo(widget.restaurantId, _sid, i.id, valor),
      'Mínimo actualizado.',
    );
  }

  Future<void> _movimiento(InsumoModel i, {required bool entrada}) async {
    final r = await showDialog<_DatosCantidad>(
      context: context,
      builder: (_) => _CantidadDialog(
        titulo: '${entrada ? 'Entrada' : 'Salida'} de ${i.nombre}',
        etiqueta: entrada ? 'Cantidad que entra' : 'Cantidad que sale',
        unidad: i.unidad,
        textoBoton: entrada ? 'Registrar entrada' : 'Registrar salida',
      ),
    );
    if (r == null) return;
    await _ejecutar(
      () => entrada
          ? _service.registrarEntrada(widget.restaurantId, _sid, i,
              cantidad: r.cantidad, motivo: r.motivo, por: _uid())
          : _service.registrarSalida(widget.restaurantId, _sid, i,
              cantidad: r.cantidad, motivo: r.motivo, por: _uid()),
      entrada ? 'Entrada registrada.' : 'Salida registrada.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.fondo,
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Inventario',
                                    style: TextStyle(
                                      fontFamily: AppTheme.familiaTitulos,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.texto,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Existencias por sucursal. Se descuentan al preparar los pedidos.',
                                    style: TextStyle(fontSize: 13.5, color: AppColors.textoSuave),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              key: const ValueKey('btn_nuevo_insumo'),
                              onPressed: _nuevoInsumo,
                              icon: const Icon(Icons.add),
                              label: const Text('Nuevo insumo'),
                            ),
                          ],
                        ),
                        if (_sucursales.length > 1) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in _sucursales)
                                ChoiceChip(
                                  key: ValueKey('sucursal_${s.id}'),
                                  avatar: const Icon(Icons.storefront_outlined, size: 16),
                                  label: Text(s.nombre.isEmpty ? 'Sucursal' : s.nombre),
                                  selected: _sid == s.id,
                                  onSelected: (_) => _seleccionar(s.id),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              key: const ValueKey('tab_existencias'),
                              label: const Text('Existencias'),
                              selected: !_verMovimientos,
                              onSelected: (_) => setState(() => _verMovimientos = false),
                            ),
                            ChoiceChip(
                              key: const ValueKey('tab_movimientos'),
                              label: const Text('Movimientos'),
                              selected: _verMovimientos,
                              onSelected: (_) => setState(() => _verMovimientos = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_verMovimientos) _listaMovimientos() else _listaExistencias(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _listaExistencias() {
    return StreamBuilder<List<InsumoModel>>(
      stream: _insumos,
      builder: (context, insumosSnap) {
        return StreamBuilder<Map<String, ExistenciaModel>>(
          stream: _existencias,
          builder: (context, exSnap) {
            if (insumosSnap.hasError || exSnap.hasError) {
              return const Text('No se pudo cargar el inventario.', key: ValueKey('inventario_error'));
            }
            if (!insumosSnap.hasData || !exSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final insumos = insumosSnap.data!;
            final existencias = exSnap.data!;
            if (insumos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Todavía no hay insumos. Agrega el primero con "Nuevo insumo" y registra su existencia.',
                  key: ValueKey('inventario_vacio'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textoSuave),
                ),
              );
            }
            final atencion = [
              for (final i in insumos)
                if ((existencias[i.id] ?? ExistenciaModel(insumoId: i.id)).requiereAtencion) i,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (atencion.isNotEmpty)
                  Container(
                    key: const ValueKey('banner_stock_bajo'),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE8B04C)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFF8A5300)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${atencion.length} insumo${atencion.length == 1 ? '' : 's'} con stock bajo o agotado: '
                            '${atencion.take(4).map((i) => i.nombre).join(', ')}${atencion.length > 4 ? '…' : ''}',
                            style: const TextStyle(fontSize: 13.5, color: AppColors.texto),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final i in insumos)
                  _TarjetaInsumo(
                    insumo: i,
                    existencia: existencias[i.id] ?? ExistenciaModel(insumoId: i.id),
                    onEntrada: () => _movimiento(i, entrada: true),
                    onSalida: () => _movimiento(i, entrada: false),
                    onEditar: () => _editarInsumo(i),
                    onMinimo: () => _definirMinimo(i, existencias[i.id] ?? ExistenciaModel(insumoId: i.id)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _listaMovimientos() {
    return StreamBuilder<List<MovimientoInventario>>(
      stream: _movimientos,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Text('No se pudieron cargar los movimientos.', key: ValueKey('movimientos_error'));
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final lista = snap.data!;
        if (lista.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'Aún no hay movimientos en esta sucursal.',
              key: ValueKey('movimientos_vacio'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSuave),
            ),
          );
        }
        return Column(
          children: [for (final m in lista) _FilaMovimiento(movimiento: m)],
        );
      },
    );
  }
}

class _TarjetaInsumo extends StatelessWidget {
  final InsumoModel insumo;
  final ExistenciaModel existencia;
  final VoidCallback onEntrada;
  final VoidCallback onSalida;
  final VoidCallback onEditar;
  final VoidCallback onMinimo;

  const _TarjetaInsumo({
    required this.insumo,
    required this.existencia,
    required this.onEntrada,
    required this.onSalida,
    required this.onEditar,
    required this.onMinimo,
  });

  @override
  Widget build(BuildContext context) {
    final ex = existencia;
    final Color color = ex.agotado
        ? AppColors.error
        : (ex.bajo ? const Color(0xFF8A5300) : AppColors.exito);
    final String estado = ex.agotado ? 'Agotado' : (ex.bajo ? 'Stock bajo' : 'Disponible');
    return Container(
      key: ValueKey('insumo_${insumo.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ex.requiereAtencion ? color.withValues(alpha: 0.5) : AppColors.divisor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  insumo.nombre,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.texto),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estado,
                  key: ValueKey('estado_insumo_${insumo.id}'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('menu_insumo_${insumo.id}'),
                tooltip: 'Más opciones',
                onSelected: (v) => v == 'editar' ? onEditar() : onMinimo(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar nombre y unidad')),
                  PopupMenuItem(value: 'minimo', child: Text('Definir mínimo')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${formatoCantidad(ex.cantidad)} ${insumo.unidad}'
            '${ex.minimo > 0 ? '  ·  mínimo ${formatoCantidad(ex.minimo)}' : ''}',
            key: ValueKey('existencia_${insumo.id}'),
            style: const TextStyle(fontSize: 14, color: AppColors.textoSuave),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: ValueKey('entrada_${insumo.id}'),
                onPressed: onEntrada,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Entrada'),
              ),
              OutlinedButton.icon(
                key: ValueKey('salida_${insumo.id}'),
                onPressed: ex.agotado ? null : onSalida,
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('Salida'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  final MovimientoInventario movimiento;
  const _FilaMovimiento({required this.movimiento});

  static String _fecha(DateTime? d) {
    if (d == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)} ${dos(d.hour)}:${dos(d.minute)}';
  }

  String get _origen {
    switch (movimiento.origen) {
      case MovimientoInventario.origenPedido:
        return 'Pedido en línea';
      case MovimientoInventario.origenPreorden:
        return 'Preorden de reserva';
      default:
        return movimiento.motivo.isEmpty ? 'Manual' : movimiento.motivo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    final color = m.esEntrada ? AppColors.exito : AppColors.marca;
    return Container(
      key: ValueKey('movimiento_${m.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divisor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(m.esEntrada ? Icons.south_west : Icons.north_east, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.esEntrada ? 'Entrada' : 'Salida'} · ${formatoCantidad(m.cantidad)} ${m.unidad} · ${m.insumoNombre}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.texto),
                ),
                Text(
                  '$_origen · ${_fecha(m.en)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textoSuave),
                ),
                if (m.tieneFaltante)
                  Text(
                    'Faltaron ${formatoCantidad(m.faltante)} ${m.unidad} para completar el pedido.',
                    key: ValueKey('faltante_${m.id}'),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.error),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatosInsumo {
  final String nombre;
  final String unidad;
  final double minimo;
  final double existencia;
  const _DatosInsumo(this.nombre, this.unidad, this.minimo, this.existencia);
}

double? _leerNumero(String texto) {
  final t = texto.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

class _InsumoDialog extends StatefulWidget {
  final InsumoModel? insumo;
  const _InsumoDialog({this.insumo});

  @override
  State<_InsumoDialog> createState() => _InsumoDialogState();
}

class _InsumoDialogState extends State<_InsumoDialog> {
  late final TextEditingController _nombre = TextEditingController(text: widget.insumo?.nombre ?? '');
  final TextEditingController _minimo = TextEditingController();
  final TextEditingController _existencia = TextEditingController();
  late String _unidad = widget.insumo?.unidad ?? 'pza';
  String? _error;

  bool get _nuevo => widget.insumo == null;

  @override
  void dispose() {
    _nombre.dispose();
    _minimo.dispose();
    _existencia.dispose();
    super.dispose();
  }

  void _guardar() {
    final problema = InventarioService.validarInsumo(nombre: _nombre.text, unidad: _unidad);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    final minimo = _leerNumero(_minimo.text) ?? 0;
    final existencia = _leerNumero(_existencia.text) ?? 0;
    if (_nuevo && (minimo < 0 || existencia < 0)) {
      setState(() => _error = 'Las cantidades no pueden ser negativas.');
      return;
    }
    Navigator.pop(context, _DatosInsumo(_nombre.text.trim(), _unidad, minimo, existencia));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_nuevo ? 'Nuevo insumo' : 'Editar insumo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('insumo_nombre'),
              controller: _nombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('insumo_unidad'),
              initialValue: _unidad,
              decoration: const InputDecoration(labelText: 'Unidad de medida', border: OutlineInputBorder()),
              items: [
                for (final u in UnidadInsumo.todas)
                  DropdownMenuItem(value: u, child: Text('${UnidadInsumo.etiqueta(u)} ($u)')),
              ],
              onChanged: (v) => setState(() => _unidad = v ?? 'pza'),
            ),
            if (_nuevo) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('insumo_existencia'),
                controller: _existencia,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Existencia inicial en esta sucursal',
                  suffixText: _unidad,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('insumo_minimo'),
                controller: _minimo,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Avisar cuando queden (opcional)',
                  suffixText: _unidad,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, key: const ValueKey('insumo_error'), style: const TextStyle(color: AppColors.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('btn_guardar_insumo'),
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DatosCantidad {
  final double cantidad;
  final String motivo;
  const _DatosCantidad(this.cantidad, this.motivo);
}

class _CantidadDialog extends StatefulWidget {
  final String titulo;
  final String etiqueta;
  final String unidad;
  final String inicial;
  final bool permiteCero;
  final bool conMotivo;
  final String textoBoton;

  const _CantidadDialog({
    required this.titulo,
    required this.etiqueta,
    required this.unidad,
    required this.textoBoton,
    this.inicial = '',
    this.permiteCero = false,
    this.conMotivo = true,
  });

  @override
  State<_CantidadDialog> createState() => _CantidadDialogState();
}

class _CantidadDialogState extends State<_CantidadDialog> {
  late final TextEditingController _cantidad = TextEditingController(text: widget.inicial);
  final TextEditingController _motivo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _cantidad.dispose();
    _motivo.dispose();
    super.dispose();
  }

  void _aceptar() {
    final c = _leerNumero(_cantidad.text);
    if (c == null || c < 0 || (!widget.permiteCero && c == 0)) {
      setState(() => _error = widget.permiteCero
          ? 'Escribe una cantidad válida (0 o más).'
          : 'Escribe una cantidad mayor a cero.');
      return;
    }
    Navigator.pop(context, _DatosCantidad(c, _motivo.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('cantidad_campo'),
            controller: _cantidad,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.etiqueta,
              suffixText: widget.unidad,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.conMotivo) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('cantidad_motivo'),
              controller: _motivo,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Ej. Compra del proveedor',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null)
            Text(_error!, key: const ValueKey('cantidad_error'), style: const TextStyle(color: AppColors.error)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('btn_aceptar_cantidad'),
          onPressed: _aceptar,
          child: Text(widget.textoBoton),
        ),
      ],
    );
  }
}

/// Aviso del dashboard: cuántos insumos están bajos o agotados en cada sucursal.
class InventarioResumen extends StatefulWidget {
  final String restaurantId;
  final VoidCallback onVer;
  final InventarioService? service;
  final RestaurantService? restaurantService;

  const InventarioResumen({
    super.key,
    required this.restaurantId,
    required this.onVer,
    this.service,
    this.restaurantService,
  });

  @override
  State<InventarioResumen> createState() => _InventarioResumenState();
}

class _InventarioResumenState extends State<InventarioResumen> {
  late final InventarioService _service = widget.service ?? InventarioService();
  final Map<String, Map<String, ExistenciaModel>> _existencias = {};
  final Map<String, String> _nombres = {};
  Set<String> _catalogo = {};
  final List<StreamSubscription<Map<String, ExistenciaModel>>> _subs = [];
  StreamSubscription<List<InsumoModel>>? _insumosSub;

  /// Insumos por atender en cada sucursal: los bajos, los agotados y los que todavía
  /// no tienen existencias registradas allí (igual que en la pantalla de inventario).
  Map<String, int> get _atencion => {
        for (final e in _existencias.entries)
          e.key: _catalogo
              .where((id) => (e.value[id] ?? ExistenciaModel(insumoId: id)).requiereAtencion)
              .length,
      };

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    List<BranchModel> sucursales = const [];
    try {
      sucursales = await (widget.restaurantService ?? RestaurantService())
          .getBranches(widget.restaurantId);
    } catch (_) {}
    final ids = sucursales.isEmpty
        ? [InventarioService.sucursalPorDefecto]
        : sucursales.map((s) => s.id).toList();
    for (final s in sucursales) {
      _nombres[s.id] = s.nombre;
    }
    if (!mounted) return;
    _insumosSub = _service.insumosStream(widget.restaurantId).listen((l) {
      if (mounted) setState(() => _catalogo = {for (final i in l) i.id});
    }, onError: (_) {});
    for (final sid in ids) {
      _subs.add(_service.existenciasStream(widget.restaurantId, sid).listen((mapa) {
        if (!mounted) return;
        setState(() => _existencias[sid] = mapa);
      }, onError: (_) {}));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _insumosSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_catalogo.isEmpty) return const SizedBox.shrink();
    final atencion = _atencion;
    final total = atencion.values.fold<int>(0, (a, b) => a + b);
    final detalle = atencion.entries
        .where((e) => e.value > 0)
        .map((e) => '${_nombres[e.key]?.isNotEmpty == true ? _nombres[e.key] : 'Sucursal'}: ${e.value}')
        .join(' · ');
    return Material(
      color: total > 0 ? const Color(0xFFFFF7E6) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: total > 0 ? AppColors.acento : AppColors.divisor),
      ),
      child: InkWell(
        key: const ValueKey('resumen_inventario'),
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: widget.onVer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                total > 0 ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                color: total > 0 ? const Color(0xFF8A5300) : AppColors.marca,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total > 0
                          ? '$total insumo${total == 1 ? '' : 's'} con stock bajo o agotado'
                          : 'Inventario al día',
                      key: const ValueKey('resumen_inventario_texto'),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.texto),
                    ),
                    if (detalle.isNotEmpty && atencion.length > 1)
                      Text(detalle, style: const TextStyle(fontSize: 13, color: AppColors.textoSuave)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}
