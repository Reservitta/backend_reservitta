import 'package:flutter/material.dart';

/// Servicio de caché en memoria local para la preorden de platillos del cliente (HU24-RF05, HU16).
///
/// Mantiene los platillos preseleccionados y sus notas de personalización en caché
/// durante la navegación del visitante antes de que confirme su reservación (HU07).
/// No toca la base de datos de Firebase hasta que la reservación sea enviada.
class PreordenCacheService extends ChangeNotifier {
  static final PreordenCacheService _instance = PreordenCacheService._internal();
  factory PreordenCacheService() => _instance;
  PreordenCacheService._internal();

  /// Mapa de items en memoria indexados por restaurantId
  final Map<String, List<Map<String, dynamic>>> _cachePorRestaurante = {};

  /// Obtiene una copia inmutable de los platillos en caché para un restaurante
  List<Map<String, dynamic>> obtenerItems(String restaurantId) {
    final list = _cachePorRestaurante[restaurantId];
    return list != null ? List<Map<String, dynamic>>.from(list) : [];
  }

  /// Agrega un platillo con sus personalizaciones al caché
  void agregarItem(String restaurantId, Map<String, dynamic> itemSnapshot) {
    _cachePorRestaurante.putIfAbsent(restaurantId, () => []);

    final items = _cachePorRestaurante[restaurantId]!;
    final platilloId = itemSnapshot['platilloId'];
    final observacion = itemSnapshot['observacion'] as String? ?? '';

    // Si ya existe exactamente el mismo platillo con la misma personalización, incrementa cantidad
    final idxExistente = items.indexWhere(
      (it) => it['platilloId'] == platilloId && it['observacion'] == observacion,
    );

    if (idxExistente != -1) {
      final existente = items[idxExistente];
      final nuevaCantidad = (existente['cantidad'] as int) + (itemSnapshot['cantidad'] as int);
      final precio = (existente['precio'] as num).toDouble();
      items[idxExistente] = {
        ...existente,
        'cantidad': nuevaCantidad,
        'total': precio * nuevaCantidad,
      };
    } else {
      items.add(Map<String, dynamic>.from(itemSnapshot));
    }

    notifyListeners();
  }

  /// Remueve un ítem específico del caché por índice
  void eliminarItem(String restaurantId, int index) {
    final items = _cachePorRestaurante[restaurantId];
    if (items != null && index >= 0 && index < items.length) {
      items.removeAt(index);
      if (items.isEmpty) {
        _cachePorRestaurante.remove(restaurantId);
      }
      notifyListeners();
    }
  }

  /// Calcula el total monetario de la preorden en caché
  double obtenerTotal(String restaurantId) {
    final items = _cachePorRestaurante[restaurantId] ?? [];
    return items.fold<double>(
      0.0,
      (sum, item) => sum + ((item['total'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Cuenta la cantidad total de porciones/platillos en la preorden
  int contarItems(String restaurantId) {
    final items = _cachePorRestaurante[restaurantId] ?? [];
    return items.fold<int>(
      0,
      (sum, item) => sum + ((item['cantidad'] as int?) ?? 1),
    );
  }

  /// Limpia la preorden en memoria para un restaurante
  void limpiar(String restaurantId) {
    _cachePorRestaurante.remove(restaurantId);
    notifyListeners();
  }
}
