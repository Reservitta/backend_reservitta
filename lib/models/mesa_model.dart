import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart' show Offset, Rect;

/// Modelo inmutable de Mesa para gestión de capacidad y asignación (HU04-RF01 Criterio 1)
class MesaModel {
  // Formas del plano (HU10-RF01 Criterio 1)
  static const String formaRedonda = 'redonda';
  static const String formaCuadrada = 'cuadrada';
  static const String formaRectangular = 'rectangular';
  static const List<String> formasValidas = [
    formaRedonda,
    formaCuadrada,
    formaRectangular,
  ];

  // Tipos de mesa del plano
  static const String tipoRegular = 'regular';
  static const String tipoBarra = 'barra';
  static const String tipoAlta = 'alta';
  static const String tipoSillon = 'sillon';
  static const List<String> tiposValidos = [tipoRegular, tipoBarra, tipoAlta, tipoSillon];

  /// Estado manual que fija el administrador (HU31-RF01); null = se deriva de las reservas.
  static const String estadoFueraDeServicio = 'fuera_de_servicio';

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

  /// Giro de la mesa en el plano, en grados (0 a 359).
  final double rotacion;

  /// Regular, barra, alta o sillón.
  final String tipo;

  /// Grupo mínimo que se acepta en la mesa (1 por defecto).
  final int minPersonas;

  /// Grupo máximo; si es null, el número de sillas.
  final int? maxPersonas;

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
    this.rotacion = 0,
    this.tipo = 'regular',
    this.minPersonas = 1,
    this.maxPersonas,
  });

  /// Grupo máximo que admite la mesa.
  int get maxEfectivo => maxPersonas ?? capacidad;

  /// La mesa acepta un grupo de [personas] según su mínimo y máximo.
  bool admite(int personas) => personas >= minPersonas && personas <= maxEfectivo;

  /// Caja que ocupa la mesa en el plano una vez girada.
  Rect get cajaRotada {
    final cx = (x ?? 0) + ancho / 2;
    final cy = (y ?? 0) + alto / 2;
    final r = rotacion * math.pi / 180;
    final c = math.cos(r).abs();
    final sn = math.sin(r).abs();
    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: ancho * c + alto * sn,
      height: ancho * sn + alto * c,
    );
  }

  /// El administrador la marcó fuera de servicio (por ejemplo, por mantenimiento).
  bool get fueraDeServicio => estadoManual == estadoFueraDeServicio;

  /// Tiene coordenadas para dibujarse en el plano (HU10-RF01 Criterio 1).
  bool get tienePosicion => x != null && y != null;

  /// La forma es una de las admitidas por el plano.
  bool get tieneFormaValida => formasValidas.contains(forma);

  /// Dos mesas pueden unirse si ambas son combinables y alguna declara a la otra.
  bool puedeCombinarCon(MesaModel otra) {
    if (id == otra.id || !combinable || !otra.combinable) return false;
    return combinableCon.contains(otra.id) || otra.combinableCon.contains(id);
  }

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
      rotacion: (data['rotacion'] as num?)?.toDouble() ?? 0,
      tipo: (data['tipo'] as String?) ?? 'regular',
      minPersonas: (data['minPersonas'] as num?)?.toInt() ?? 1,
      maxPersonas: (data['maxPersonas'] as num?)?.toInt(),
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
      'rotacion': rotacion,
      'tipo': tipo,
      'minPersonas': minPersonas,
      if (maxPersonas != null) 'maxPersonas': maxPersonas,
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
    double? rotacion,
    String? tipo,
    int? minPersonas,
    int? maxPersonas,
    bool sinMaximo = false,
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
      rotacion: rotacion ?? this.rotacion,
      tipo: tipo ?? this.tipo,
      minPersonas: minPersonas ?? this.minPersonas,
      maxPersonas: sinMaximo ? null : (maxPersonas ?? this.maxPersonas),
    );
  }
}
