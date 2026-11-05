import 'package:flutter/material.dart';
import '../../models/platillo_model.dart';
import '../../viewmodels/pedido_viewmodel.dart';

/// Resultado devuelto al cerrar el detalle de platillo (HU16-RF04, HU16-RF05, HU17-RF01).
class PlatilloDetalleResult {
  /// Snapshot del platillo guardado (`null` si fue eliminado del pedido).
  final Map<String, dynamic>? item;

  /// `true` cuando el usuario redujo la cantidad a 0 y confirmó eliminar el platillo del pedido (HU16-RF05).
  final bool eliminado;

  /// ID del platillo afectado.
  final String platilloId;

  const PlatilloDetalleResult._({
    required this.platilloId,
    this.item,
    this.eliminado = false,
  });

  factory PlatilloDetalleResult.guardado(Map<String, dynamic> item) {
    return PlatilloDetalleResult._(
      platilloId: (item['platilloId'] ?? '').toString(),
      item: item,
      eliminado: false,
    );
  }

  factory PlatilloDetalleResult.eliminado(String platilloId) {
    return PlatilloDetalleResult._(
      platilloId: platilloId,
      item: null,
      eliminado: true,
    );
  }
}

/// Detalle de platillo con cantidad y observaciones (G24 · Catalina).
///
/// Este archivo único resuelve la circularidad **HU16-RF04 ↔ HU17-RF01** e implementa
/// también la edición de un platillo ya agregado (**HU16-RF05**):
///
/// - **HU16-RF04**:
///   1. Muestra imagen, nombre, precio unitario, descripción y etiquetas.
///   2. Stepper de "Cantidad" con mínimo 1 al agregar.
///   3. El precio en el botón "Agregar al pedido" se recalcula como `precio unitario × cantidad`.
///   4. Al confirmar, el platillo (cantidad, precio total, observación) se agrega al pedido en el borrador de reserva.
/// - **HU17-RF01**:
///   1. Muestra únicamente un campo de texto libre ("Agregar una observación",
///      subtítulo "¿Algo más que debamos saber sobre este platillo?").
///   2. No muestra opciones predefinidas tipo checkbox ("Sin cebolla", "Sin aderezo", "Vegano"); solo texto libre.
///   3. El texto se guarda junto con el platillo y se muestra como referencia en el pedido.
///   4. Campo opcional; no bloquea "Agregar al pedido".
///   5. Límite de caracteres razonable (por defecto 200), visible para el usuario.
/// - **HU16-RF05**:
///   1. Cuando el platillo ya fue agregado, se abre prellenado con la cantidad y observación guardadas.
///   2. Si la cantidad llega a 0 durante la edición, se ofrece eliminar el platillo del pedido.
class PlatilloDetalleSheet extends StatefulWidget {
  final PlatilloModel platillo;
  final PedidoViewModel? pedidoViewModel;
  final int? cantidadInicial;
  final String? observacionInicial;
  final bool? esEdicion;
  final int limiteCaracteresObservacion;

  static const int limitePorDefecto =
      PedidoViewModel.limiteCaracteresObservacionDefault; // 200

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamLight = Color(0xFFFAF5ED);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _dangerRed = Color(0xFFC62828);

  const PlatilloDetalleSheet({
    super.key,
    required this.platillo,
    this.pedidoViewModel,
    this.cantidadInicial,
    this.observacionInicial,
    this.esEdicion,
    this.limiteCaracteresObservacion = limitePorDefecto,
  });

  /// Abre el detalle del platillo como hoja modal (o diálogo) y retorna el [PlatilloDetalleResult].
  static Future<PlatilloDetalleResult?> show(
    BuildContext context, {
    required PlatilloModel platillo,
    PedidoViewModel? pedidoViewModel,
    int? cantidadInicial,
    String? observacionInicial,
    bool? esEdicion,
    int limiteCaracteresObservacion = limitePorDefecto,
  }) {
    return showModalBottomSheet<PlatilloDetalleResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: PlatilloDetalleSheet(
          platillo: platillo,
          pedidoViewModel: pedidoViewModel,
          cantidadInicial: cantidadInicial,
          observacionInicial: observacionInicial,
          esEdicion: esEdicion,
          limiteCaracteresObservacion: limiteCaracteresObservacion,
        ),
      ),
    );
  }

  @override
  State<PlatilloDetalleSheet> createState() => _PlatilloDetalleSheetState();
}

class _PlatilloDetalleSheetState extends State<PlatilloDetalleSheet> {
  late final TextEditingController _observacionController;
  late bool _esEdicion;
  late int _cantidad;

  int get _limiteCaracteres => widget.limiteCaracteresObservacion > 0
      ? widget.limiteCaracteresObservacion
      : PlatilloDetalleSheet.limitePorDefecto;

  @override
  void initState() {
    super.initState();
    final existente = widget.pedidoViewModel?.obtenerItem(widget.platillo.id);
    _esEdicion = widget.esEdicion ?? (existente != null || (widget.cantidadInicial != null && widget.cantidadInicial! > 0 && widget.observacionInicial != null));

    final cantGuardada = widget.cantidadInicial ?? existente?.cantidad ?? 1;
    _cantidad = cantGuardada >= 1 ? cantGuardada : 1;

    final obsGuardada = widget.observacionInicial ?? existente?.observacion ?? '';
    _observacionController = TextEditingController(text: obsGuardada);
    _observacionController.addListener(_onObservacionChanged);
  }

  void _onObservacionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _observacionController.removeListener(_onObservacionChanged);
    _observacionController.dispose();
    super.dispose();
  }

  /// En modo creación el mínimo es 1 (HU16-RF04 Criterio 2).
  /// En modo edición permite bajar hasta 0 para ofrecer eliminar el platillo (HU16-RF05 Criterio 3).
  int get _cantidadMinima => _esEdicion ? 0 : 1;

  bool get _puedeDecrementar => _cantidad > _cantidadMinima;

  double get _precioTotal =>
      PedidoViewModel.calcularTotalPlatillo(widget.platillo.precio, _cantidad);

  void _incrementar() {
    setState(() => _cantidad++);
  }

  void _decrementar() {
    if (_puedeDecrementar) {
      setState(() => _cantidad--);
    }
  }

  void _confirmar() {
    // HU16-RF05 Criterio 3: Si la cantidad llega a 0 en edición, se elimina el platillo del pedido.
    if (_esEdicion && _cantidad == 0) {
      widget.pedidoViewModel?.eliminarPlatillo(widget.platillo.id);
      Navigator.of(context).pop(
        PlatilloDetalleResult.eliminado(widget.platillo.id),
      );
      return;
    }

    final obs = _observacionController.text.trim();
    final obsRecortada =
        obs.length > _limiteCaracteres ? obs.substring(0, _limiteCaracteres) : obs;

    final item = PedidoItem.fromPlatillo(
      widget.platillo,
      cantidad: _cantidad,
      observacion: obsRecortada,
    );

    widget.pedidoViewModel?.guardarPlatillo(
      widget.platillo,
      cantidad: _cantidad,
      observacion: obsRecortada,
    );

    Navigator.of(context).pop(
      PlatilloDetalleResult.guardado(item.toMap()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.platillo;
    final caracteresActuales = _observacionController.text.length;
    final ofrecerEliminar = _esEdicion && _cantidad == 0;

    return Container(
      key: const ValueKey('platillo_detalle_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        maxWidth: 540,
      ),
      decoration: const BoxDecoration(
        color: PlatilloDetalleSheet._cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador superior de arrastre y botón de cierre
            Row(
              children: [
                const Spacer(),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      key: const ValueKey('btn_cerrar_detalle_platillo'),
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Imagen del platillo (HU16-RF04 Criterio 1)
            ClipRRect(
              key: const ValueKey('detalle_platillo_imagen'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 170,
                width: double.infinity,
                color: PlatilloDetalleSheet._creamLight,
                child: p.tieneImagenEnNube
                    ? Image.network(
                        p.imagenUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            size: 52,
                            color: PlatilloDetalleSheet._primaryTerracotta,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 52,
                          color: PlatilloDetalleSheet._primaryTerracotta,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Nombre y precio unitario (HU16-RF04 Criterio 1)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    p.nombre,
                    key: const ValueKey('detalle_platillo_nombre'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: PlatilloDetalleSheet._textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '\$${p.precio.toStringAsFixed(2)} MXN',
                  key: const ValueKey('detalle_platillo_precio_unitario'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: PlatilloDetalleSheet._primaryTerracotta,
                  ),
                ),
              ],
            ),

            // 3. Descripción (HU16-RF04 Criterio 1)
            if (p.descripcion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                p.descripcion,
                key: const ValueKey('detalle_platillo_descripcion'),
                style: const TextStyle(
                  fontSize: 14,
                  color: PlatilloDetalleSheet._textMuted,
                  height: 1.35,
                ),
              ),
            ],

            // 4. Etiquetas del platillo (HU16-RF04 Criterio 1)
            if (p.etiquetas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                key: const ValueKey('detalle_platillo_etiquetas'),
                spacing: 8,
                runSpacing: 6,
                children: p.etiquetas.map((etiqueta) {
                  return Container(
                    key: ValueKey('etiqueta_platillo_$etiqueta'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: PlatilloDetalleSheet._creamLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: PlatilloDetalleSheet._cardBorder),
                    ),
                    child: Text(
                      etiqueta,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PlatilloDetalleSheet._primaryTerracotta,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 18),
            const Divider(height: 1, color: PlatilloDetalleSheet._cardBorder),
            const SizedBox(height: 16),

            // 5. Campo de observación por platillo (HU17-RF01 Criterios 1, 2, 4, 5)
            // Únicamente campo de texto libre; sin opciones predefinidas tipo checkbox.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Agregar una observación',
                    key: ValueKey('titulo_campo_observacion'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: PlatilloDetalleSheet._textDark,
                    ),
                  ),
                ),
                const Text(
                  'Opcional',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PlatilloDetalleSheet._textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '¿Algo más que debamos saber sobre este platillo?',
              key: ValueKey('subtitulo_campo_observacion'),
              style: TextStyle(
                fontSize: 13,
                color: PlatilloDetalleSheet._textMuted,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey('input_observacion_platillo'),
              controller: _observacionController,
              maxLength: _limiteCaracteres,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: p.placeholderObservacion.isNotEmpty
                    ? p.placeholderObservacion
                    : 'Escribe aquí cualquier indicación o restricción alimentaria...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9E8F82),
                ),
                filled: true,
                fillColor: PlatilloDetalleSheet._creamLight,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: PlatilloDetalleSheet._cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: PlatilloDetalleSheet._cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: PlatilloDetalleSheet._primaryTerracotta,
                    width: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$caracteresActuales/$_limiteCaracteres caracteres',
                key: const ValueKey('contador_caracteres_observacion'),
                style: const TextStyle(
                  fontSize: 12,
                  color: PlatilloDetalleSheet._textMuted,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 6. Stepper de "Cantidad" (HU16-RF04 Criterio 2 / HU16-RF05 Criterio 3)
            Container(
              key: const ValueKey('detalle_stepper_cantidad'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: PlatilloDetalleSheet._creamLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PlatilloDetalleSheet._cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cantidad',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: PlatilloDetalleSheet._textDark,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('btn_decrementar_cantidad'),
                        icon: const Icon(Icons.remove_circle_outline),
                        color: PlatilloDetalleSheet._primaryTerracotta,
                        onPressed: _puedeDecrementar ? _decrementar : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_cantidad',
                          key: const ValueKey('texto_cantidad_detalle'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: PlatilloDetalleSheet._textDark,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('btn_incrementar_cantidad'),
                        icon: const Icon(Icons.add_circle_outline),
                        color: PlatilloDetalleSheet._primaryTerracotta,
                        onPressed: _incrementar,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Aviso cuando la cantidad llega a 0 durante la edición (HU16-RF05 Criterio 3)
            if (ofrecerEliminar) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('aviso_eliminar_platillo'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.delete_outline,
                      color: PlatilloDetalleSheet._dangerRed,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La cantidad es 0. ¿Deseas eliminar este platillo del pedido?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PlatilloDetalleSheet._dangerRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 7. Botón de confirmación con precio recalculado (HU16-RF04 Criterio 3 y 4 / HU16-RF05 Criterio 3)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: ValueKey(
                  ofrecerEliminar
                      ? 'btn_eliminar_del_pedido'
                      : 'btn_agregar_al_pedido',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ofrecerEliminar
                      ? PlatilloDetalleSheet._dangerRed
                      : PlatilloDetalleSheet._primaryTerracotta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _confirmar,
                child: Text(
                  ofrecerEliminar
                      ? 'Eliminar del pedido'
                      : 'Agregar al pedido · \$${_precioTotal.toStringAsFixed(2)} MXN',
                  key: const ValueKey('texto_boton_confirmar_platillo'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
