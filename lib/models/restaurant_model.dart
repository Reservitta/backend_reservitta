import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantModel {
  final String id;
  final String name;
  final DocumentReference? adminId;
  final String estado;
  final bool perfilCompleto;

  const RestaurantModel({
    required this.id,
    required this.name,
    this.adminId,
    this.estado = 'inactivo',
    this.perfilCompleto = false,
  });

  factory RestaurantModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RestaurantModel(
      id: doc.id,
      name: (data['nombre'] ?? data['name']) as String? ?? 'Sin nombre',
      adminId: data['adminId'] as DocumentReference?,
      estado: data['estado'] as String? ?? 'inactivo',
      perfilCompleto: data['perfilCompleto'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': name,
      'adminId': adminId,
      'estado': estado,
      'perfilCompleto': perfilCompleto,
    };
  }
}
