import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceCatalogModel {
  final String id;
  final String nombre;
  final String icono;
  final bool activo;

  const ServiceCatalogModel({
    required this.id,
    required this.nombre,
    this.icono = '',
    this.activo = true,
  });

  factory ServiceCatalogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ServiceCatalogModel(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      icono: data['icono'] as String? ?? '',
      activo: data['activo'] as bool? ?? true,
    );
  }

  factory ServiceCatalogModel.fromMap(String id, Map<String, dynamic> data) {
    return ServiceCatalogModel(
      id: id,
      nombre: data['nombre'] as String? ?? '',
      icono: data['icono'] as String? ?? '',
      activo: data['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'icono': icono,
      'activo': activo,
    };
  }
}
