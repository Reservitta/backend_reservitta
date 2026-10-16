import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriaModel {
  final String id;
  final String nombre;
  final String nombreNormalizado;
  final int orden;
  final String tipo;

  const CategoriaModel({
    required this.id,
    required this.nombre,
    required this.nombreNormalizado,
    required this.orden,
    this.tipo = 'general',
  });

  /// Normaliza una cadena para validaciones de unicidad (sin espacios extras y en minúsculas)
  static String normalizarNombre(String texto) {
    return texto.trim().toLowerCase();
  }

  factory CategoriaModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final String nombreRaw = data['nombre'] as String? ?? 'Sin categoría';

    return CategoriaModel(
      id: doc.id,
      nombre: nombreRaw,
      nombreNormalizado: (data['nombreNormalizado'] as String?)?.isNotEmpty == true
          ? data['nombreNormalizado'] as String
          : normalizarNombre(nombreRaw),
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      tipo: data['tipo'] as String? ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'nombreNormalizado': nombreNormalizado,
      'orden': orden,
      'tipo': tipo,
    };
  }

  CategoriaModel copyWith({
    String? id,
    String? nombre,
    String? nombreNormalizado,
    int? orden,
    String? tipo,
  }) {
    return CategoriaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nombreNormalizado: nombreNormalizado ?? this.nombreNormalizado,
      orden: orden ?? this.orden,
      tipo: tipo ?? this.tipo,
    );
  }
}

