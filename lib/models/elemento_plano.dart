import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Elemento decorativo del plano del salón: barra, paredes, puertas, plantas, cocina,
/// baños, escenario o una etiqueta de texto. No es una mesa: no se reserva ni tiene
/// capacidad; solo ayuda a que el plano se parezca al salón real.
class ElementoPlano {
  static const String barra = 'barra';
  static const String pared = 'pared';
  static const String puerta = 'puerta';
  static const String ventana = 'ventana';
  static const String escalera = 'escalera';
  static const String planta = 'planta';
  static const String columna = 'columna';
  static const String cocina = 'cocina';
  static const String bano = 'bano';
  static const String escenario = 'escenario';
  static const String texto = 'texto';

  static const List<String> tiposValidos = [
    barra,
    pared,
    puerta,
    ventana,
    escalera,
    planta,
    columna,
    cocina,
    bano,
    escenario,
    texto,
  ];

  static const double tamanoMinimo = 8;
  static const double tamanoMaximo = 600;
  static const int textoMax = 40;

  final String id;
  final String tipo;
  final double x;
  final double y;
  final double ancho;
  final double alto;
  final double rotacion;
  final String etiqueta;
  final String? zonaId;

  const ElementoPlano({
    required this.id,
    required this.tipo,
    required this.x,
    required this.y,
    required this.ancho,
    required this.alto,
    this.rotacion = 0,
    this.etiqueta = '',
    this.zonaId,
  });

  bool get esCircular => tipo == planta || tipo == columna;

  /// Caja que ocupa el elemento una vez girado, para calcular los límites del plano.
  Rect get cajaRotada => cajaGirada(x, y, ancho, alto, rotacion);

  static Rect cajaGirada(double x, double y, double ancho, double alto, double grados) {
    final c = Offset(x + ancho / 2, y + alto / 2);
    final r = grados * math.pi / 180;
    final cosA = math.cos(r).abs();
    final sinA = math.sin(r).abs();
    final w = ancho * cosA + alto * sinA;
    final h = ancho * sinA + alto * cosA;
    return Rect.fromCenter(center: c, width: w, height: h);
  }

  /// Datos de presentación de cada tipo.
  static ({
    String nombre,
    IconData icono,
    double ancho,
    double alto,
    Color relleno,
    Color borde,
    Color tinta,
    bool llevaTexto,
  }) estilo(String tipo) {
    switch (tipo) {
      case barra:
        return (
          nombre: 'Barra',
          icono: Icons.local_bar_outlined,
          ancho: 260,
          alto: 60,
          relleno: const Color(0xFFC9A27E),
          borde: const Color(0xFF8A6240),
          tinta: const Color(0xFF3F2A17),
          llevaTexto: true,
        );
      case pared:
        return (
          nombre: 'Pared',
          icono: Icons.horizontal_rule,
          ancho: 240,
          alto: 14,
          relleno: const Color(0xFF6E665D),
          borde: const Color(0xFF4A443D),
          tinta: Colors.white,
          llevaTexto: false,
        );
      case puerta:
        return (
          nombre: 'Puerta',
          icono: Icons.door_front_door_outlined,
          ancho: 80,
          alto: 18,
          relleno: const Color(0xFFE8D8C3),
          borde: const Color(0xFF8A6240),
          tinta: const Color(0xFF3F2A17),
          llevaTexto: false,
        );
      case ventana:
        return (
          nombre: 'Ventana',
          icono: Icons.window_outlined,
          ancho: 140,
          alto: 12,
          relleno: const Color(0xFFD7E8F2),
          borde: const Color(0xFF6A93AD),
          tinta: const Color(0xFF2F5870),
          llevaTexto: false,
        );
      case escalera:
        return (
          nombre: 'Escalera',
          icono: Icons.stairs_outlined,
          ancho: 90,
          alto: 140,
          relleno: const Color(0xFFE4DED5),
          borde: const Color(0xFF8C8478),
          tinta: const Color(0xFF4A443D),
          llevaTexto: false,
        );
      case planta:
        return (
          nombre: 'Planta',
          icono: Icons.local_florist_outlined,
          ancho: 54,
          alto: 54,
          relleno: const Color(0xFFCFE5CF),
          borde: const Color(0xFF4F8A55),
          tinta: const Color(0xFF2C5A31),
          llevaTexto: false,
        );
      case columna:
        return (
          nombre: 'Columna',
          icono: Icons.circle,
          ancho: 36,
          alto: 36,
          relleno: const Color(0xFFBDB6AC),
          borde: const Color(0xFF6E665D),
          tinta: Colors.white,
          llevaTexto: false,
        );
      case cocina:
        return (
          nombre: 'Cocina',
          icono: Icons.soup_kitchen_outlined,
          ancho: 220,
          alto: 130,
          relleno: const Color(0xFFE2E4E6),
          borde: const Color(0xFF858B90),
          tinta: const Color(0xFF3F454A),
          llevaTexto: true,
        );
      case bano:
        return (
          nombre: 'Baños',
          icono: Icons.wc_outlined,
          ancho: 110,
          alto: 100,
          relleno: const Color(0xFFDDE7EF),
          borde: const Color(0xFF6A93AD),
          tinta: const Color(0xFF2F5870),
          llevaTexto: true,
        );
      case escenario:
        return (
          nombre: 'Escenario',
          icono: Icons.music_note_outlined,
          ancho: 220,
          alto: 100,
          relleno: const Color(0xFFE5D3EC),
          borde: const Color(0xFF8A5FA1),
          tinta: const Color(0xFF52306A),
          llevaTexto: true,
        );
      default:
        return (
          nombre: 'Texto',
          icono: Icons.text_fields,
          ancho: 170,
          alto: 40,
          relleno: Colors.transparent,
          borde: const Color(0xFF8C7B6E),
          tinta: const Color(0xFF2B1D14),
          llevaTexto: true,
        );
    }
  }

  /// Texto que lleva por defecto al agregarse.
  static String textoInicial(String tipo) {
    switch (tipo) {
      case barra:
        return 'Barra';
      case cocina:
        return 'Cocina';
      case bano:
        return 'Baños';
      case escenario:
        return 'Escenario';
      case texto:
        return 'Zona';
      default:
        return '';
    }
  }

  factory ElementoPlano.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ElementoPlano.fromMap(doc.id, doc.data() ?? {});

  factory ElementoPlano.fromMap(String id, Map<String, dynamic> data) {
    final tipo = (data['tipo'] as String?) ?? texto;
    final base = estilo(tipo);
    String? zona;
    final rawZona = data['zonaId'];
    if (rawZona is DocumentReference) {
      zona = rawZona.id;
    } else if (rawZona is String) {
      zona = rawZona;
    }
    return ElementoPlano(
      id: id,
      tipo: tipo,
      x: (data['x'] as num?)?.toDouble() ?? 0,
      y: (data['y'] as num?)?.toDouble() ?? 0,
      ancho: (data['ancho'] as num?)?.toDouble() ?? base.ancho,
      alto: (data['alto'] as num?)?.toDouble() ?? base.alto,
      rotacion: (data['rotacion'] as num?)?.toDouble() ?? 0,
      etiqueta: (data['texto'] as String?) ?? '',
      zonaId: zona,
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo,
        'x': x,
        'y': y,
        'ancho': ancho,
        'alto': alto,
        'rotacion': rotacion,
        'texto': etiqueta,
        if (zonaId != null) 'zonaId': zonaId,
      };

  ElementoPlano copyWith({
    String? id,
    String? tipo,
    double? x,
    double? y,
    double? ancho,
    double? alto,
    double? rotacion,
    String? etiqueta,
    String? zonaId,
    bool sinZona = false,
  }) {
    return ElementoPlano(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      x: x ?? this.x,
      y: y ?? this.y,
      ancho: ancho ?? this.ancho,
      alto: alto ?? this.alto,
      rotacion: rotacion ?? this.rotacion,
      etiqueta: etiqueta ?? this.etiqueta,
      zonaId: sinZona ? null : (zonaId ?? this.zonaId),
    );
  }

  /// Errores por campo; vacío si es válido.
  Map<String, String> validar({required Set<String> zonaIds}) {
    final errores = <String, String>{};
    if (!tiposValidos.contains(tipo)) errores['tipo'] = 'Tipo de elemento no válido.';
    if (ancho < tamanoMinimo || ancho > tamanoMaximo) {
      errores['ancho'] = 'El ancho debe estar entre ${tamanoMinimo.round()} y ${tamanoMaximo.round()}.';
    }
    if (alto < tamanoMinimo || alto > tamanoMaximo) {
      errores['alto'] = 'El alto debe estar entre ${tamanoMinimo.round()} y ${tamanoMaximo.round()}.';
    }
    if (x < 0 || y < 0) errores['x'] = 'El elemento debe estar dentro del plano.';
    if (etiqueta.length > textoMax) {
      errores['texto'] = 'El texto no puede pasar de $textoMax caracteres.';
    }
    if (zonaId != null && zonaId!.isNotEmpty && !zonaIds.contains(zonaId)) {
      errores['zona'] = 'El espacio de este elemento ya no existe.';
    }
    return errores;
  }
}
