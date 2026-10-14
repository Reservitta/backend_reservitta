import 'package:cloud_firestore/cloud_firestore.dart';

class BranchModel {
  final String id;
  final String nombre;
  final String direccion;
  final String telefono;
  final bool esPrincipal;
  final GeoPoint? coordenadas;
  final String logoUrl;
  final String imagenPrincipalUrl;

  const BranchModel({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.telefono,
    this.esPrincipal = false,
    this.coordenadas,
    this.logoUrl = '',
    this.imagenPrincipalUrl = '',
  });

  factory BranchModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return BranchModel.fromMap(doc.id, data);
  }

  factory BranchModel.fromMap(String id, Map<String, dynamic> data) {
    GeoPoint? coords;
    if (data['coordenadas'] is GeoPoint) {
      coords = data['coordenadas'] as GeoPoint;
    } else if (data['coordenadas'] is Map<String, dynamic>) {
      final mapCoords = data['coordenadas'] as Map<String, dynamic>;
      final lat = (mapCoords['latitude'] ?? mapCoords['lat'] ?? 0.0) as num;
      final lng = (mapCoords['longitude'] ?? mapCoords['lng'] ?? 0.0) as num;
      coords = GeoPoint(lat.toDouble(), lng.toDouble());
    }

    return BranchModel(
      id: id,
      nombre: data['nombre'] as String? ?? '',
      direccion: data['direccion'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      esPrincipal: data['esPrincipal'] as bool? ?? false,
      coordenadas: coords,
      logoUrl: data['logoUrl'] as String? ?? '',
      imagenPrincipalUrl: data['imagenPrincipalUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'esPrincipal': esPrincipal,
      if (coordenadas != null) 'coordenadas': coordenadas,
      'logoUrl': logoUrl,
      'imagenPrincipalUrl': imagenPrincipalUrl,
    };
  }

  BranchModel copyWith({
    String? id,
    String? nombre,
    String? direccion,
    String? telefono,
    bool? esPrincipal,
    GeoPoint? coordenadas,
    String? logoUrl,
    String? imagenPrincipalUrl,
  }) {
    return BranchModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      esPrincipal: esPrincipal ?? this.esPrincipal,
      coordenadas: coordenadas ?? this.coordenadas,
      logoUrl: logoUrl ?? this.logoUrl,
      imagenPrincipalUrl: imagenPrincipalUrl ?? this.imagenPrincipalUrl,
    );
  }
}
