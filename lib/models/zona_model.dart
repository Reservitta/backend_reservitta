import 'package:cloud_firestore/cloud_firestore.dart';

/// Zona o área del restaurante, por ejemplo terraza o interior (HU10-RF01 Criterio 2).
class ZonaModel {
  final String id;
  final String nombre;
  final int orden;

  const ZonaModel({
    required this.id,
    required this.nombre,
    this.orden = 0,
  });

  factory ZonaModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ZonaModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory ZonaModel.fromMap(String id, Map<String, dynamic> data) {
    return ZonaModel(
      id: id,
      nombre: (data['nombre'] as String?) ?? 'Zona',
      orden: (data['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'nombre': nombre, 'orden': orden};
}
