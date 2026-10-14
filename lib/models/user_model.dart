import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String rol;
  final String nombre;
  final String correo;
  final String telefono;
  final DocumentReference? restauranteId;
  final String canalPreferido;
  final DateTime? fechaAlta;

  const UserModel({
    required this.uid,
    required this.rol,
    required this.nombre,
    required this.correo,
    required this.telefono,
    this.restauranteId,
    this.canalPreferido = 'email',
    this.fechaAlta,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      rol: data['rol'] as String? ?? 'visitante',
      nombre: data['nombre'] as String? ?? '',
      correo: data['correo'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      restauranteId: data['restauranteId'] as DocumentReference?,
      canalPreferido: data['canalPreferido'] as String? ?? 'email',
      fechaAlta: (data['fechaAlta'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'rol': rol,
      'nombre': nombre,
      'correo': correo,
      'telefono': telefono,
      'restauranteId': restauranteId,
      'canalPreferido': canalPreferido,
      'fechaAlta': fechaAlta != null ? Timestamp.fromDate(fechaAlta!) : FieldValue.serverTimestamp(),
    };
  }
}
