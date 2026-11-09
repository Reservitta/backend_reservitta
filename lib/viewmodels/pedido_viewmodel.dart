import 'package:flutter/foundation.dart';
import '../models/platillo_model.dart';
import '../models/reservation_draft_model.dart';
import 'reservation_draft_viewmodel.dart';

/// Elemento individual dentro del pedido de preorden (HU16-RF04, HU16-RF05, HU17-RF01).
class PedidoItem {
  final String platilloId;
  final String nombre;
  final double precio;
  final int cantidad;
  final double total;
  final String observacion;
  final String imagenUrl;
  final String categoriaId;
  final String descripcion;
  final List<String> etiquetas;
  final String mensajeFelicitacion;

  const PedidoItem({
    required this.platilloId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    required this.total,
    this.observacion = '',
    this.imagenUrl = '',
    this.categoriaId = '',
    this.descripcion = '',
    this.etiquetas = const [],
    this.mensajeFelicitacion = '',
  });

  /// Precio unitario multiplicado por cantidad (HU16-RF04 Criterio 3).
  double get subtotal => precio * cantidad;

  /// Crea un [PedidoItem] a partir de un [PlatilloModel], cantidad y observación (HU16-RF04 / HU17-RF01).
  factory PedidoItem.fromPlatillo(
    PlatilloModel platillo, {
    required int cantidad,
    String observacion = '',
    String mensajeFelicitacion = '',
  }) {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser al menos 1.');
    }
    final cleanObs = observacion.trim();
    return PedidoItem(
      platilloId: platillo.id,
      nombre: platillo.nombre,
      precio: platillo.precio,
      cantidad: cantidad,
      total: platillo.precio * cantidad,
      observacion: cleanObs,
      imagenUrl: platillo.imagenUrl,
      categoriaId: platillo.categoriaId,
      descripcion: platillo.descripcion,
      etiquetas: List<String>.from(platillo.etiquetas),
      mensajeFelicitacion: mensajeFelicitacion.trim(),
    );
  }

  /// Reconstruye un [PedidoItem] desde el mapa guardado en `ReservationDraftModel.preordenItems`.
  factory PedidoItem.fromMap(Map<String, dynamic> map) {
    final precio = (map['precio'] as num?)?.toDouble() ?? 0.0;
    final cantidad = (map['cantidad'] as num?)?.toInt() ?? 1;
    final totalExplicito = (map['total'] as num?)?.toDouble();
    return PedidoItem(
      platilloId: (map['platilloId'] ?? map['id'] ?? '').toString(),
      nombre: (map['nombre'] ?? 'Platillo').toString(),
      precio: precio,
      cantidad: cantidad,
      total: totalExplicito ?? (precio * cantidad),
      observacion: (map['observacion'] ?? '').toString().trim(),
      imagenUrl: (map['imagenUrl'] ?? '').toString(),
      categoriaId: (map['categoriaId'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      etiquetas: map['etiquetas'] is Iterable
          ? List<String>.from((map['etiquetas'] as Iterable).map((e) => e.toString()))
          : const [],
      mensajeFelicitacion: (map['mensajeFelicitacion'] ?? '').toString().trim(),
    );
  }

  /// Convierte el ítem a mapa compatible con `ReservationDraftModel.preordenItems` y Firestore.
  Map<String, dynamic> toMap() {
    return {
      'platilloId': platilloId,
      'nombre': nombre,
      'precio': precio,
      'cantidad': cantidad,
      'total': precio * cantidad,
      'observacion': observacion.trim(),
      'mensajeFelicitacion': mensajeFelicitacion.trim(),
      if (imagenUrl.isNotEmpty) 'imagenUrl': imagenUrl,
      if (categoriaId.isNotEmpty) 'categoriaId': categoriaId,
      if (descripcion.isNotEmpty) 'descripcion': descripcion,
      if (etiquetas.isNotEmpty) 'etiquetas': etiquetas,
    };
  }

  PedidoItem copyWith({
    String? platilloId,
    String? nombre,
    double? precio,
    int? cantidad,
    double? total,
    String? observacion,
    String? imagenUrl,
    String? categoriaId,
    String? descripcion,
    List<String>? etiquetas,
    String? mensajeFelicitacion,
  }) {
    final nextPrecio = precio ?? this.precio;
    final nextCantidad = cantidad ?? this.cantidad;
    return PedidoItem(
      platilloId: platilloId ?? this.platilloId,
      nombre: nombre ?? this.nombre,
      precio: nextPrecio,
      cantidad: nextCantidad,
      total: total ?? (nextPrecio * nextCantidad),
      observacion: observacion != null ? observacion.trim() : this.observacion,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      categoriaId: categoriaId ?? this.categoriaId,
      descripcion: descripcion ?? this.descripcion,
      etiquetas: etiquetas ?? this.etiquetas,
      mensajeFelicitacion: mensajeFelicitacion ?? this.mensajeFelicitacion,
    );
  }
}

/// ViewModel dueño de la lógica de negocio del pedido / preorden (G24 · Catalina).
///
/// Cubre:
/// - **HU16-RF04**: Agregar platillo con cantidad (mínimo 1), cálculo de `precio unitario × cantidad`,
///   y registro en el pedido del borrador de reserva.
/// - **HU16-RF05**: Consulta y edición de un platillo ya agregado (badge de cantidad sobre imagen,
///   botón "Editar", prellenado de cantidad y observación, eliminación cuando la cantidad llega a 0,
///   y actualización inmediata en el badge `"Pedido (n)"` y en `"Mi pedido"`).
/// - **HU17-RF01**: Observación opcional en texto libre por platillo con límite razonable de caracteres
///   (por defecto 200 caracteres), guardada junto con el platillo y mostrada como referencia en el pedido.
class PedidoViewModel extends ChangeNotifier {
  /// Límite razonable por defecto para el campo de observación (HU17-RF01 Criterio 5: ej. 200).
  static const int limiteCaracteresObservacionDefault = 200;

  final int maxCaracteresObservacion;
  final ReservationDraftViewModel? draftViewModel;
  final ValueChanged<List<Map<String, dynamic>>>? onPedidoChanged;

  final List<PedidoItem> _items = [];

  PedidoViewModel({
    List<Map<String, dynamic>>? initialItems,
    this.draftViewModel,
    this.onPedidoChanged,
    this.maxCaracteresObservacion = limiteCaracteresObservacionDefault,
  }) {
    final source = initialItems ?? draftViewModel?.draft.preordenItems ?? const [];
    _cargarDesdeMapas(source);
  }

  void _cargarDesdeMapas(List<Map<String, dynamic>> rawList) {
    _items.clear();
    for (final raw in rawList) {
      final item = PedidoItem.fromMap(raw);
      if (item.platilloId.isEmpty || item.cantidad <= 0) continue;
      final idx = _items.indexWhere((e) => e.platilloId == item.platilloId);
      if (idx != -1) {
        final actual = _items[idx];
        final nuevaCant = actual.cantidad + item.cantidad;
        final obsCombinada = item.observacion.isNotEmpty
            ? item.observacion
            : actual.observacion;
        _items[idx] = actual.copyWith(
          cantidad: nuevaCant,
          total: actual.precio * nuevaCant,
          observacion: obsCombinada,
        );
      } else {
        _items.add(item);
      }
    }
  }

  /// Lista inmutable de platillos en el pedido ("Mi pedido").
  List<PedidoItem> get items => List.unmodifiable(_items);

  /// Lista serializada para `ReservationDraftModel.preordenItems` (HU16-RF04 Criterio 4).
  List<Map<String, dynamic>> get preordenItems =>
      _items.map((item) => item.toMap()).toList(growable: false);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  /// Cantidad total acumulada de platillos (porciones) en el pedido para el badge "Pedido (n)" (HU16-RF05 Criterio 4).
  int get totalCantidad =>
      _items.fold<int>(0, (sum, item) => sum + item.cantidad);

  /// Alias semántico de [totalCantidad].
  int get totalArticulos => totalCantidad;

  /// Número de platillos distintos en el pedido.
  int get cantidadPlatillosDistintos => _items.length;

  /// Subtotal monetario acumulado del pedido.
  double get subtotal =>
      _items.fold<double>(0.0, (sum, item) => sum + item.total);

  /// Alias semántico de [subtotal].
  double get totalPedido => subtotal;

  /// Texto formateado para el badge del pedido: `"Pedido (n)"` (HU16-RF05 Criterio 4).
  String get badgePedidoTexto => 'Pedido ($totalCantidad)';

  /// Calcula el precio total como `precioUnitario × cantidad` (HU16-RF04 Criterio 3).
  static double calcularTotalPlatillo(double precioUnitario, int cantidad) {
    if (cantidad <= 0 || precioUnitario <= 0) return 0.0;
    return precioUnitario * cantidad;
  }

  /// Obtiene el [PedidoItem] guardado para un `platilloId`, o `null` si no ha sido agregado.
  PedidoItem? obtenerItem(String platilloId) {
    for (final item in _items) {
      if (item.platilloId == platilloId) return item;
    }
    return null;
  }

  /// Indica si un platillo ya fue agregado al pedido (HU16-RF05 Criterio 1).
  bool estaAgregado(String platilloId) => obtenerItem(platilloId) != null;

  /// Retorna la cantidad actual del platillo en el pedido (0 si no está agregado).
  int cantidadDePlatillo(String platilloId) =>
      obtenerItem(platilloId)?.cantidad ?? 0;

  /// Retorna la observación guardada para el platillo (`''` si no tiene o no está agregado).
  String observacionDePlatillo(String platilloId) =>
      obtenerItem(platilloId)?.observacion ?? '';

  /// Valida el campo opcional de observación por platillo (HU17-RF01 Criterios 4 y 5).
  /// Nunca bloquea cuando está vacío.
  String? validarObservacion(String? valor, {int? limite}) {
    if (valor == null || valor.trim().isEmpty) {
      return null;
    }
    final maxLen = limite ?? maxCaracteresObservacion;
    if (valor.trim().length > maxLen) {
      return 'La observación no puede exceder los $maxLen caracteres.';
    }
    return null;
  }

  /// Agrega o actualiza un platillo en el pedido (HU16-RF04, HU16-RF05, HU17-RF01).
  ///
  /// - Si [cantidad] llega a `0` o menos, elimina el platillo del pedido (HU16-RF05 Criterio 3).
  /// - Si [cantidad] >= 1, guarda el platillo con su cantidad, precio total (`precio × cantidad`)
  ///   y observación opcional en texto libre.
  void guardarPlatillo(
    PlatilloModel platillo, {
    required int cantidad,
    String observacion = '',
  }) {
    final trimmedObs = observacion.trim();
    if (trimmedObs.length > maxCaracteresObservacion) {
      throw ArgumentError(
        'La observación no puede exceder el límite de $maxCaracteresObservacion caracteres.',
      );
    }

    if (cantidad <= 0) {
      eliminarPlatillo(platillo.id);
      return;
    }

    final nuevoItem = PedidoItem.fromPlatillo(
      platillo,
      cantidad: cantidad,
      observacion: trimmedObs,
    );

    final idx = _items.indexWhere((e) => e.platilloId == platillo.id);
    if (idx != -1) {
      // Conserva el mensaje de felicitación (HU18-RF04) al editar cantidad u observación.
      _items[idx] = nuevoItem.copyWith(
        mensajeFelicitacion: _items[idx].mensajeFelicitacion,
      );
    } else {
      _items.add(nuevoItem);
    }

    _sincronizarYNotificar();
  }

  /// Asocia (o quita, con texto vacío) el mensaje de felicitación de un postre
  /// ya agregado al pedido (HU18-RF04). El mensaje nunca cambia el precio.
  void establecerMensajeFelicitacion(String platilloId, String mensaje) {
    final idx = _items.indexWhere((e) => e.platilloId == platilloId);
    if (idx == -1) return;
    final limpio = mensaje.trim();
    if (_items[idx].mensajeFelicitacion == limpio) return;
    _items[idx] = _items[idx].copyWith(mensajeFelicitacion: limpio);
    _sincronizarYNotificar();
  }

  /// Agrega un platillo al pedido exigiendo mínimo 1 unidad (HU16-RF04 Criterio 2 y 4).
  void agregarPlatillo(
    PlatilloModel platillo, {
    int cantidad = 1,
    String observacion = '',
  }) {
    if (cantidad < 1) {
      throw ArgumentError('La cantidad mínima para agregar un platillo es 1.');
    }
    guardarPlatillo(
      platillo,
      cantidad: cantidad,
      observacion: observacion,
    );
  }

  /// Edita la cantidad y/u observación de un platillo ya agregado por su ID (HU16-RF05).
  /// Si [cantidad] <= 0, el platillo se elimina del pedido.
  void editarPlatillo(
    String platilloId, {
    required int cantidad,
    String? observacion,
  }) {
    if (cantidad <= 0) {
      eliminarPlatillo(platilloId);
      return;
    }

    final idx = _items.indexWhere((e) => e.platilloId == platilloId);
    if (idx == -1) return;

    final actual = _items[idx];
    final nuevaObs = observacion != null ? observacion.trim() : actual.observacion;
    if (nuevaObs.length > maxCaracteresObservacion) {
      throw ArgumentError(
        'La observación no puede exceder el límite de $maxCaracteresObservacion caracteres.',
      );
    }

    _items[idx] = actual.copyWith(
      cantidad: cantidad,
      total: actual.precio * cantidad,
      observacion: nuevaObs,
    );

    _sincronizarYNotificar();
  }

  /// Elimina un platillo del pedido (HU16-RF05 Criterio 3).
  void eliminarPlatillo(String platilloId) {
    final removed = _items.any((e) => e.platilloId == platilloId);
    if (!removed) return;
    _items.removeWhere((e) => e.platilloId == platilloId);
    _sincronizarYNotificar();
  }

  /// Reemplaza el contenido del pedido a partir de una lista de mapas del borrador.
  void reemplazarItems(List<Map<String, dynamic>> rawItems) {
    _cargarDesdeMapas(rawItems);
    _sincronizarYNotificar();
  }

  /// Vacía todos los platillos del pedido.
  void limpiarPedido() {
    if (_items.isEmpty) return;
    _items.clear();
    _sincronizarYNotificar();
  }

  /// Devuelve una copia del [ReservationDraftModel] con `preordenItems` actualizados.
  ReservationDraftModel aplicarAlBorrador(ReservationDraftModel draft) {
    return draft.copyWith(preordenItems: preordenItems);
  }

  void _sincronizarYNotificar() {
    final snapshot = preordenItems;
    draftViewModel?.setPreordenItems(snapshot);
    onPedidoChanged?.call(snapshot);
    notifyListeners();
  }
}
