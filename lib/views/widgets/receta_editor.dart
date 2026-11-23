import 'package:flutter/material.dart';

import '../../models/inventario_models.dart';
import '../../services/inventario_service.dart';
import '../../theme/app_theme.dart';

/// Editor de la receta de un platillo: qué insumos usa una porción y cuánto.
///
/// Con receta, el platillo se descuenta del inventario al prepararlo y se marca agotado
/// cuando faltan insumos. Sin receta no se controla por inventario.
class RecetaEditor extends StatefulWidget {
  final String restaurantId;
  final List<RecetaItem> inicial;
  final ValueChanged<List<RecetaItem>> onChanged;
  final InventarioService? service;
  final bool enabled;

  const RecetaEditor({
    super.key,
    required this.restaurantId,
    required this.inicial,
    required this.onChanged,
    this.service,
    this.enabled = true,
  });

  @override
  State<RecetaEditor> createState() => _RecetaEditorState();
}

class _RecetaEditorState extends State<RecetaEditor> {
  late final InventarioService _service = widget.service ?? InventarioService();
  late List<RecetaItem> _items = List.of(widget.inicial);
  late final Stream<List<InsumoModel>> _insumos = _abrirCatalogo();

  /// Si no se puede leer el catálogo (sin conexión o sin permiso) el formulario del
  /// platillo sigue funcionando: la receta aparece sin insumos para elegir.
  Stream<List<InsumoModel>> _abrirCatalogo() {
    try {
      return _service
          .insumosStream(widget.restaurantId)
          .handleError((_) {})
          .asBroadcastStream();
    } catch (_) {
      return Stream.value(const <InsumoModel>[]);
    }
  }

  void _cambiar(List<RecetaItem> nuevos) {
    setState(() => _items = nuevos);
    widget.onChanged(List.unmodifiable(nuevos));
  }

  Future<void> _agregar(List<InsumoModel> catalogo) async {
    final usados = _items.map((i) => i.insumoId).toSet();
    final disponibles = catalogo.where((i) => !usados.contains(i.id)).toList();
    final nuevo = await showDialog<RecetaItem>(
      context: context,
      builder: (_) => _IngredienteDialog(insumos: disponibles),
    );
    if (nuevo != null) _cambiar([..._items, nuevo]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InsumoModel>>(
      stream: _insumos,
      builder: (context, snap) {
        final catalogo = snap.data ?? const <InsumoModel>[];
        final quedan = catalogo.where((c) => !_items.any((i) => i.insumoId == c.id)).length;
        return Container(
          key: const ValueKey('receta_editor'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divisor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 19, color: AppColors.marca),
                  SizedBox(width: 8),
                  Text(
                    'Receta (inventario)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.texto),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Insumos que usa una porción. Con receta, el platillo se descuenta del inventario al prepararlo y se marca agotado si faltan insumos.',
                style: TextStyle(fontSize: 12, color: AppColors.textoSuave, height: 1.35),
              ),
              const SizedBox(height: 10),
              if (_items.isEmpty)
                const Text(
                  'Sin receta: este platillo no se controla por inventario.',
                  key: ValueKey('receta_vacia'),
                  style: TextStyle(fontSize: 12.5, color: AppColors.textoSuave),
                ),
              for (final item in _items)
                Padding(
                  key: ValueKey('receta_item_${item.insumoId}'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.nombre} · ${formatoCantidad(item.cantidad)} ${item.unidad}',
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('quitar_ingrediente_${item.insumoId}'),
                        tooltip: 'Quitar ingrediente',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: widget.enabled
                            ? () => _cambiar(_items.where((i) => i.insumoId != item.insumoId).toList())
                            : null,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              if (catalogo.isEmpty && snap.connectionState != ConnectionState.waiting)
                const Text(
                  'Primero registra tus insumos en la sección Inventario.',
                  key: ValueKey('receta_sin_catalogo'),
                  style: TextStyle(fontSize: 12.5, color: AppColors.acento),
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey('btn_agregar_ingrediente'),
                  onPressed: widget.enabled && quedan > 0 ? () => _agregar(catalogo) : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar ingrediente'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _IngredienteDialog extends StatefulWidget {
  final List<InsumoModel> insumos;
  const _IngredienteDialog({required this.insumos});

  @override
  State<_IngredienteDialog> createState() => _IngredienteDialogState();
}

class _IngredienteDialogState extends State<_IngredienteDialog> {
  final TextEditingController _cantidad = TextEditingController();
  InsumoModel? _insumo;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.insumos.isNotEmpty) _insumo = widget.insumos.first;
  }

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  void _aceptar() {
    final c = double.tryParse(_cantidad.text.trim().replaceAll(',', '.'));
    if (_insumo == null) {
      setState(() => _error = 'Elige un insumo.');
      return;
    }
    if (c == null || c <= 0) {
      setState(() => _error = 'Escribe cuánto usa una porción (mayor a cero).');
      return;
    }
    Navigator.pop(
      context,
      RecetaItem(
        insumoId: _insumo!.id,
        nombre: _insumo!.nombre,
        unidad: _insumo!.unidad,
        cantidad: redondearCantidad(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar ingrediente'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('ingrediente_insumo'),
            initialValue: _insumo?.id,
            decoration: const InputDecoration(labelText: 'Insumo', border: OutlineInputBorder()),
            items: [
              for (final i in widget.insumos)
                DropdownMenuItem(value: i.id, child: Text('${i.nombre} (${i.unidad})')),
            ],
            onChanged: (v) => setState(() {
              _insumo = widget.insumos.firstWhere((i) => i.id == v);
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('ingrediente_cantidad'),
            controller: _cantidad,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad por porción',
              suffixText: _insumo?.unidad,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('btn_aceptar_ingrediente'),
          onPressed: _aceptar,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
