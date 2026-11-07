import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa una experiencia ligada a una ocasión especial (HU33-RF01 y HU18-RF01)
class ExperienciaModel {
  final String id;
  final String nombre;
  final String descripcionCorta;
  final double precio;
  final bool esGratis;
  final bool activo;
  final int orden;

  /// Tipo de experiencia (HU18-RF03/RF04). Con [tipoPostreFelicitacion] el
  /// visitante debe elegir un postre y escribir su mensaje de felicitación.
  final String tipo;

  static const String tipoEstandar = 'estandar';
  static const String tipoPostreFelicitacion = 'postre_felicitacion';

  const ExperienciaModel({
    required this.id,
    required this.nombre,
    this.descripcionCorta = '',
    required this.precio,
    bool? esGratis,
    this.activo = true,
    this.orden = 1,
    this.tipo = tipoEstandar,
  }) : esGratis = esGratis ?? (precio <= 0.0);

  /// Es la experiencia "Postre con felicitación" (por su tipo o por su nombre).
  bool get esPostreConFelicitacion {
    if (tipo == tipoPostreFelicitacion) return true;
    final n = nombre.toLowerCase();
    return n.contains('postre') && n.contains('felicit');
  }

  /// Necesita información adicional del visitante antes de continuar (HU18-RF03 Criterio 3).
  bool get requiereInformacion => esPostreConFelicitacion;

  /// Formateo del precio o etiqueta "Gratis" (HU33-RF01 Criterio 3)
  String get precioFormateado {
    if (esGratis || precio <= 0.0) {
      return 'Gratis';
    }
    return '\$${precio.toStringAsFixed(2)} MXN';
  }

  factory ExperienciaModel.fromMap(String id, Map<String, dynamic> data) {
    final precioRaw = (data['precio'] as num?)?.toDouble() ?? 0.0;
    final esGratisRaw = data['esGratis'] as bool? ?? (precioRaw <= 0.0);

    return ExperienciaModel(
      id: id,
      nombre: (data['nombre'] as String? ?? '').trim(),
      descripcionCorta: (data['descripcionCorta'] as String? ?? '').trim(),
      precio: precioRaw,
      esGratis: esGratisRaw,
      activo: data['activo'] as bool? ?? true,
      orden: (data['orden'] as num?)?.toInt() ?? 1,
      tipo: (data['tipo'] as String?) ?? tipoEstandar,
    );
  }

  factory ExperienciaModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ExperienciaModel.fromMap(doc.id, doc.data() ?? {});
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcionCorta': descripcionCorta,
      'precio': precio,
      'esGratis': esGratis,
      'activo': activo,
      'orden': orden,
      if (tipo != tipoEstandar) 'tipo': tipo,
    };
  }

  ExperienciaModel copyWith({
    String? id,
    String? nombre,
    String? descripcionCorta,
    double? precio,
    bool? esGratis,
    bool? activo,
    int? orden,
    String? tipo,
  }) {
    return ExperienciaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcionCorta: descripcionCorta ?? this.descripcionCorta,
      precio: precio ?? this.precio,
      esGratis: esGratis ?? this.esGratis,
      activo: activo ?? this.activo,
      orden: orden ?? this.orden,
      tipo: tipo ?? this.tipo,
    );
  }
}
