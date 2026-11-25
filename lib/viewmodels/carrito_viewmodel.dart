import 'package:flutter/foundation.dart';

import '../models/pedido_model.dart';
import '../models/platillo_model.dart';

/// Carrito del pedido a domicilio o para recoger: platillos y cantidades, sin
/// personalización ni observaciones.
class CarritoViewModel extends ChangeNotifier {
  /// Máximo de unidades de un mismo platillo en un pedido.
  static const int maxPorPlatillo = 20;

  final Map<String, PedidoLinea> _lineas = {};

  List<PedidoLinea> get lineas => List.unmodifiable(_lineas.values);
  bool get vacio => _lineas.isEmpty;
  int get totalPlatillos => _lineas.values.fold(0, (s, l) => s + l.cantidad);
  double get total => PedidoModel.sumar(_lineas.values);

  int cantidadDe(String platilloId) => _lineas[platilloId]?.cantidad ?? 0;

  /// Suma una unidad del platillo (hasta [maxPorPlatillo]).
  void agregar(PlatilloModel platillo) {
    final actual = _lineas[platillo.id];
    final cantidad = (actual?.cantidad ?? 0) + 1;
    if (cantidad > maxPorPlatillo) return;
    _lineas[platillo.id] = PedidoLinea(
      platilloId: platillo.id,
      nombre: platillo.nombre,
      precio: platillo.precio,
      cantidad: cantidad,
    );
    notifyListeners();
  }

  /// Suma una unidad de un platillo que ya está en el carrito.
  void sumar(String platilloId) {
    final actual = _lineas[platilloId];
    if (actual == null || actual.cantidad >= maxPorPlatillo) return;
    _lineas[platilloId] = PedidoLinea(
      platilloId: actual.platilloId,
      nombre: actual.nombre,
      precio: actual.precio,
      cantidad: actual.cantidad + 1,
    );
    notifyListeners();
  }

  /// Quita una unidad; si era la última, el platillo sale del carrito.
  void quitar(String platilloId) {
    final actual = _lineas[platilloId];
    if (actual == null) return;
    if (actual.cantidad <= 1) {
      _lineas.remove(platilloId);
    } else {
      _lineas[platilloId] = PedidoLinea(
        platilloId: actual.platilloId,
        nombre: actual.nombre,
        precio: actual.precio,
        cantidad: actual.cantidad - 1,
      );
    }
    notifyListeners();
  }

  void eliminar(String platilloId) {
    if (_lineas.remove(platilloId) != null) notifyListeners();
  }

  void limpiar() {
    if (_lineas.isEmpty) return;
    _lineas.clear();
    notifyListeners();
  }
}
