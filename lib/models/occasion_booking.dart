/// Normaliza la ocasión especial y sus experiencias antes de guardarlas con la
/// reserva (HU18-RF05): lo que se guarda es lo que el administrador verá en el
/// detalle (HU28) y lo que se cobró en el total.
class OccasionBooking {
  const OccasionBooking._();

  /// Límite del texto "Cuéntanos qué celebras" (ocasión "Otro").
  static const int maxCaracteresDetalle = 100;

  /// Límite de cada mensaje de felicitación.
  static const int maxCaracteresMensaje = 100;

  /// Ocasión y experiencias listas para guardar. Si no hay ocasión elegida (el
  /// visitante no celebra nada), ambas quedan vacías: las experiencias no tienen
  /// sentido sin ocasión.
  static ({Map<String, dynamic>? ocasion, List<Map<String, dynamic>> experiencias})
      normalizar(
    Map<String, dynamic>? ocasion,
    List<Map<String, dynamic>> experiencias,
  ) {
    final nombre = (ocasion?['nombre'] ?? '').toString().trim();
    if (ocasion == null || nombre.isEmpty) {
      return (ocasion: null, experiencias: const []);
    }

    final detalle = limpiar(ocasion['detalle'], maxCaracteresDetalle);
    final ocasionLimpia = <String, dynamic>{
      'ocasionId': (ocasion['ocasionId'] ?? ocasion['id'] ?? '').toString(),
      'nombre': nombre,
      'icono': (ocasion['icono'] ?? 'celebration').toString(),
      if (detalle.isNotEmpty) 'detalle': detalle,
    };

    final vistas = <String>{};
    final limpias = <Map<String, dynamic>>[];
    for (final exp in experiencias) {
      final id = (exp['experienciaId'] ?? exp['id'] ?? '').toString().trim();
      final nombreExp = (exp['nombre'] ?? '').toString().trim();
      if (nombreExp.isEmpty) continue;
      if (!vistas.add(id.isNotEmpty ? id : nombreExp.toLowerCase())) continue;

      final precioBruto = (exp['precio'] as num?)?.toDouble() ?? 0.0;
      final esGratis = exp['esGratis'] == true || precioBruto <= 0;
      final mensaje = limpiar(exp['mensajeFelicitacion'], maxCaracteresMensaje);
      limpias.add({
        'experienciaId': id,
        'nombre': nombreExp,
        'precio': esGratis ? 0.0 : precioBruto,
        'esGratis': esGratis,
        if (mensaje.isNotEmpty) 'mensajeFelicitacion': mensaje,
      });
    }
    return (ocasion: ocasionLimpia, experiencias: limpias);
  }

  /// Costo adicional de las experiencias con precio; las gratuitas no suman.
  static double totalExperiencias(List<Map<String, dynamic>> experiencias) {
    return experiencias.fold<double>(0.0, (acc, e) {
      if (e['esGratis'] == true) return acc;
      return acc + ((e['precio'] as num?)?.toDouble() ?? 0.0);
    });
  }

  /// Texto sin espacios sobrantes y con el límite de caracteres.
  static String limpiar(Object? valor, int max) {
    final texto = (valor ?? '').toString().trim();
    return texto.length > max ? texto.substring(0, max).trimRight() : texto;
  }
}
