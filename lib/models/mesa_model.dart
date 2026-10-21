import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo inmutable de Mesa para gestión de capacidad y asignación (HU04-RF01 Criterio 1)
class MesaModel {
  final String id;
  final String nombre;
  final int capacidad;
  final bool combinable;
  final List<String> combinableCon;
  final String? zonaId;
  final double? x;
  final double? y;
  final String forma;
  final double ancho;
  final double alto;
  final String? estadoManual;

  const MesaModel({
    required this.id,
    required this.nombre,
    required this.capacidad,
    this.combinable = false,
    this.combinableCon = const [],
    this.zonaId,
    this.x,
    this.y,
    this.forma = 'cuadrada',
    this.ancho = 100.0,
    this.alto = 100.0,
    this.estadoManual,
  });

  factory MesaModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MesaModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory MesaModel.fromMap(String id, Map<String, dynamic> data) {
    String? zona;
    final rawZona = data['zonaId'];
    if (rawZona is DocumentReference) {
      zona = rawZona.id;
    } else if (rawZona is String) {
      zona = rawZona;
    }

    final rawCombinableCon = data['combinableCon'] as List<dynamic>? ?? [];
    final combinableList = <String>[];
    for (final c in rawCombinableCon) {
      if (c is DocumentReference) {
        combinableList.add(c.id);
      } else if (c is String) {
        combinableList.add(c);
      }
    }

    return MesaModel(
      id: id,
      nombre: (data['nombre'] as String?) ?? 'Mesa',
      capacidad: (data['capacidad'] as num?)?.toInt() ?? 2,
      combinable: (data['combinable'] as bool?) ?? false,
      combinableCon: combinableList,
      zonaId: zona,
      x: (data['x'] as num?)?.toDouble(),
      y: (data['y'] as num?)?.toDouble(),
      forma: (data['forma'] as String?) ?? 'cuadrada',
      ancho: (data['ancho'] as num?)?.toDouble() ?? 100.0,
      alto: (data['alto'] as num?)?.toDouble() ?? 100.0,
      estadoManual: data['estadoManual'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'capacidad': capacidad,
      'combinable': combinable,
      'combinableCon': combinableCon,
      if (zonaId != null) 'zonaId': zonaId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      'forma': forma,
      'ancho': ancho,
      'alto': alto,
      'estadoManual': estadoManual,
    };
  }

  MesaModel copyWith({
    String? id,
    String? nombre,
    int? capacidad,
    bool? combinable,
    List<String>? combinableCon,
    String? zonaId,
    double? x,
    double? y,
    String? forma,
    double? ancho,
    double? alto,
    String? estadoManual,
  }) {
    return MesaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      capacidad: capacidad ?? this.capacidad,
      combinable: combinable ?? this.combinable,
      combinableCon: combinableCon ?? this.combinableCon,
      zonaId: zonaId ?? this.zonaId,
      x: x ?? this.x,
      y: y ?? this.y,
      forma: forma ?? this.forma,
      ancho: ancho ?? this.ancho,
      alto: alto ?? this.alto,
      estadoManual: estadoManual ?? this.estadoManual,
    );
  }
}
