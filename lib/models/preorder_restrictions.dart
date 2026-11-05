/// Observación libre que el visitante escribió para un platillo específico de su
/// pedido (HU17-RF02 Criterio 1). Se lee de las líneas de la preorden de la reserva.
class RestriccionPlatillo {
  final String platilloId;
  final String nombre;
  final int cantidad;
  final String observacion;

  const RestriccionPlatillo({
    required this.platilloId,
    required this.nombre,
    required this.cantidad,
    required this.observacion,
  });

  @override
  bool operator ==(Object other) =>
      other is RestriccionPlatillo &&
      other.platilloId == platilloId &&
      other.nombre == nombre &&
      other.cantidad == cantidad &&
      other.observacion == observacion;

  @override
  int get hashCode => Object.hash(platilloId, nombre, cantidad, observacion);

  @override
  String toString() => 'RestriccionPlatillo($platilloId, "$observacion")';
}

/// Normaliza y consulta las restricciones guardadas con una reserva (HU17-RF02):
/// la observación de cada línea del pedido y las alergias generales de la reserva.
class PreorderRestrictions {
  const PreorderRestrictions._();

  /// Límite de caracteres de la observación de un platillo (el mismo de HU17-RF01).
  static const int maxCaracteresObservacion = 200;

  /// Deja cada línea del pedido lista para guardarse: descarta las líneas sin
  /// platillo o con cantidad menor a 1 y limpia su observación (sin espacios
  /// sobrantes y con el límite de caracteres). La observación queda dentro de la
  /// misma línea, asociada a ese platillo, y no se mezcla con otras líneas.
  static List<Map<String, dynamic>> normalizarLineas(
    List<Map<String, dynamic>> items, {
    int maxObservacion = maxCaracteresObservacion,
  }) {
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final platilloId = (item['platilloId'] ?? item['id'] ?? '').toString().trim();
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;
      if (platilloId.isEmpty || cantidad < 1) continue;

      final linea = Map<String, dynamic>.from(item)
        ..['platilloId'] = platilloId
        ..['cantidad'] = cantidad
        ..['observacion'] = _limpiarObservacion(item['observacion'], maxObservacion);
      result.add(linea);
    }
    return result;
  }

  /// Observaciones por platillo: solo las líneas que traen una observación.
  static List<RestriccionPlatillo> porPlatillo(
    List<Map<String, dynamic>> items,
  ) {
    return [
      for (final linea in normalizarLineas(items))
        if ((linea['observacion'] as String).isNotEmpty)
          RestriccionPlatillo(
            platilloId: linea['platilloId'] as String,
            nombre: (linea['nombre'] ?? '').toString(),
            cantidad: linea['cantidad'] as int,
            observacion: linea['observacion'] as String,
          ),
    ];
  }

  /// Alergias sin espacios sobrantes, sin vacías y sin repetir.
  static List<String> normalizarAlergias(Iterable<String> alergias) {
    final vistas = <String>{};
    final result = <String>[];
    for (final alergia in alergias) {
      final limpia = alergia.trim();
      if (limpia.isEmpty) continue;
      if (vistas.add(limpia.toLowerCase())) result.add(limpia);
    }
    return result;
  }

  static String _limpiarObservacion(Object? valor, int max) {
    final texto = (valor ?? '').toString().trim();
    return texto.length > max ? texto.substring(0, max).trimRight() : texto;
  }
}
