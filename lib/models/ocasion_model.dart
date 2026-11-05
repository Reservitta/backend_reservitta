import 'package:cloud_firestore/cloud_firestore.dart';
import 'experiencia_model.dart';

/// Modelo que representa una ocasión especial del restaurante (HU33-RF01 y HU18-RF01)
class OcasionModel {
  final String id;
  final String restaurantId;
  final String nombre;
  final String tipoPredefinido;
  final String descripcion;
  final String icono;
  final bool activo;
  final List<ExperienciaModel> experiencias;

  /// Nombres predefinidos según HU33-RF01 Criterio 1
  static const List<String> nombresPredefinidos = [
    'Cumpleaños',
    'Aniversario',
    'Pedida',
    'Graduación',
    'Cena romántica',
    'Otro',
  ];

  static const String tipoOtro = 'Otro';

  const OcasionModel({
    required this.id,
    required this.restaurantId,
    required this.nombre,
    this.tipoPredefinido = 'Otro',
    this.descripcion = '',
    this.icono = 'celebration',
    this.activo = true,
    this.experiencias = const [],
  });

  /// Asigna un icono predeterminado según el nombre predefinido
  static String iconoPorNombre(String nombre) {
    switch (nombre) {
      case 'Cumpleaños':
        return 'cake';
      case 'Aniversario':
        return 'favorite';
      case 'Pedida':
        return 'diamond';
      case 'Graduación':
        return 'school';
      case 'Cena romántica':
        return 'wine_bar';
      case 'Otro':
      default:
        return 'celebration';
    }
  }

  factory OcasionModel.fromMap(
    String id,
    String restaurantId,
    Map<String, dynamic> data, {
    List<ExperienciaModel> experiencias = const [],
  }) {
    final rawNombre = (data['nombre'] as String? ?? '').trim();
    final tipoRaw = (data['tipoPredefinido'] as String? ??
        (nombresPredefinidos.contains(rawNombre) ? rawNombre : 'Otro'));

    // Si viene una lista de experiencias embebida en el mapa
    List<ExperienciaModel> parsedExperiencias = List.from(experiencias);
    if (parsedExperiencias.isEmpty && data['experiencias'] is List) {
      final list = data['experiencias'] as List;
      parsedExperiencias = list.asMap().entries.map((entry) {
        final itemMap = entry.value as Map<String, dynamic>;
        final expId = itemMap['id'] as String? ?? 'exp_${entry.key}';
        return ExperienciaModel.fromMap(expId, itemMap);
      }).toList();
    }

    return OcasionModel(
      id: id,
      restaurantId: restaurantId,
      nombre: rawNombre,
      tipoPredefinido: tipoRaw,
      descripcion: (data['descripcion'] as String? ?? data['descripcionCorta'] as String? ?? '').trim(),
      icono: (data['icono'] as String? ?? iconoPorNombre(tipoRaw)),
      activo: data['activo'] as bool? ?? true,
      experiencias: parsedExperiencias,
    );
  }

  factory OcasionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String restaurantId, {
    List<ExperienciaModel> experiencias = const [],
  }) {
    return OcasionModel.fromMap(
      doc.id,
      restaurantId,
      doc.data() ?? {},
      experiencias: experiencias,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'nombre': nombre,
      'tipoPredefinido': tipoPredefinido,
      'descripcion': descripcion,
      'icono': icono,
      'activo': activo,
      'experiencias': experiencias.map((e) => e.toMap()..['id'] = e.id).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  OcasionModel copyWith({
    String? id,
    String? restaurantId,
    String? nombre,
    String? tipoPredefinido,
    String? descripcion,
    String? icono,
    bool? activo,
    List<ExperienciaModel>? experiencias,
  }) {
    return OcasionModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      nombre: nombre ?? this.nombre,
      tipoPredefinido: tipoPredefinido ?? this.tipoPredefinido,
      descripcion: descripcion ?? this.descripcion,
      icono: icono ?? this.icono,
      activo: activo ?? this.activo,
      experiencias: experiencias ?? this.experiencias,
    );
  }
}
