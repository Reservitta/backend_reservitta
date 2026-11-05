import 'package:cloud_firestore/cloud_firestore.dart';

class PlatilloModel {
  final String id;
  final String categoriaId;
  final String nombre;
  final String descripcion;
  final double precio;
  final String imagenUrl;
  final String estado; // 'activo' | 'agotado' | 'inactivo'
  final int orden;
  final List<String> etiquetas;
  final bool permitePersonalizacion;
  final String placeholderObservacion;
  final int limiteCaracteresObs;

  /// Estados válidos de disponibilidad del platillo (HU06 y HU32-RF01)
  static const String estadoActivo = 'activo';
  static const String estadoAgotado = 'agotado';
  static const String estadoInactivo = 'inactivo';
  static const List<String> estadosValidos = [
    estadoActivo,
    estadoAgotado,
    estadoInactivo,
  ];

  /// Ruta del asset local para platillos sin foto personalizada
  static const String imagenPorDefecto = 'assets/images/default_platillo.png';

  PlatilloModel({
    required this.id,
    required this.categoriaId,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    String? imagenUrl,
    this.estado = estadoActivo,
    this.orden = 1,
    this.etiquetas = const [],
    this.permitePersonalizacion = true,
    this.placeholderObservacion = '',
    this.limiteCaracteresObs = 150,
  }) : imagenUrl = (imagenUrl != null && imagenUrl.trim().isNotEmpty)
            ? imagenUrl
            : imagenPorDefecto;

  /// Indica si el platillo está activo y disponible para preordenar
  bool get isActivo => estado == estadoActivo;

  /// Indica si el platillo está disponible para los clientes (HU06-RF01)
  bool get isDisponible => estado == estadoActivo;

  /// Indica si el platillo está marcado temporalmente como agotado (HU32-RF01)
  bool get isAgotado => estado == estadoAgotado;

  /// Indica si el platillo está inactivo/oculto para visitantes (HU06 y HU32-RF01)
  bool get isInactivo => estado == estadoInactivo;

  /// Indica si el platillo cuenta con una imagen subida en la nube (URL http/https)
  bool get tieneImagenEnNube =>
      imagenUrl.isNotEmpty &&
      (imagenUrl.startsWith('http://') || imagenUrl.startsWith('https://'));

  factory PlatilloModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrecio = data['precio'];
    final double precio = (rawPrecio is num) ? rawPrecio.toDouble() : 0.0;

    // Soporta tanto DocumentReference como String para categoriaId
    String parseCategoriaId(dynamic rawCat) {
      if (rawCat is DocumentReference) return rawCat.id;
      if (rawCat is String) return rawCat;
      return '';
    }

    final rawImagen = data['imagenUrl'] as String?;
    final String imagenFinal = (rawImagen != null && rawImagen.trim().isNotEmpty)
        ? rawImagen
        : imagenPorDefecto;

    final rawEstado = data['estado'] as String? ?? estadoActivo;
    final String estadoFinal =
        estadosValidos.contains(rawEstado) ? rawEstado : estadoActivo;

    return PlatilloModel(
      id: doc.id,
      categoriaId: parseCategoriaId(data['categoriaId']),
      nombre: data['nombre'] as String? ?? 'Sin nombre',
      descripcion: data['descripcion'] as String? ?? '',
      precio: precio > 0 ? precio : 0.01,
      imagenUrl: imagenFinal,
      estado: estadoFinal,
      orden: (data['orden'] as num?)?.toInt() ?? 1,
      etiquetas: List<String>.from(data['etiquetas'] ?? const []),
      permitePersonalizacion: data['permitePersonalizacion'] as bool? ?? true,
      placeholderObservacion: data['placeholderObservacion'] as String? ?? '',
      limiteCaracteresObs: (data['limiteCaracteresObs'] as num?)?.toInt() ?? 150,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoriaId': categoriaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imagenUrl': imagenUrl,
      'estado': estado,
      'orden': orden,
      'etiquetas': etiquetas,
      'permitePersonalizacion': permitePersonalizacion,
      'placeholderObservacion': placeholderObservacion,
      'limiteCaracteresObs': limiteCaracteresObs,
    };
  }

  /// Genera una copia histórica congelada (snapshot) del platillo para guardarse
  /// dentro de `preorden.items` de una reservación confirmada (HU32-RF01 y HU24-RF05).
  /// Criterio 3: El texto ingresado por el cliente se guarda junto con el ítem
  /// preordenado en la reservación, no en el catálogo del menú.
  /// Criterio 4: El campo tiene un límite máximo de caracteres.
  Map<String, dynamic> toPreordenItemSnapshot({
    required int cantidad,
    String observacion = '',
    String mensajeFelicitacion = '',
  }) {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad preseleccionada debe ser mayor a cero.');
    }
    final trimmedObs = observacion.trim();
    if (!permitePersonalizacion && trimmedObs.isNotEmpty) {
      throw ArgumentError(
        'Este platillo no admite personalizaciones del cliente.',
      );
    }
    if (trimmedObs.length > limiteCaracteresObs) {
      throw ArgumentError(
        'La personalización no puede exceder el límite de $limiteCaracteresObs caracteres.',
      );
    }
    return {
      'platilloId': id,
      'nombre': nombre,
      'precio': precio,
      'cantidad': cantidad,
      'total': precio * cantidad,
      'observacion': trimmedObs,
      'mensajeFelicitacion': mensajeFelicitacion.trim(),
    };
  }

  PlatilloModel copyWith({
    String? id,
    String? categoriaId,
    String? nombre,
    String? descripcion,
    double? precio,
    String? imagenUrl,
    String? estado,
    int? orden,
    List<String>? etiquetas,
    bool? permitePersonalizacion,
    String? placeholderObservacion,
    int? limiteCaracteresObs,
  }) {
    return PlatilloModel(
      id: id ?? this.id,
      categoriaId: categoriaId ?? this.categoriaId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      estado: estado ?? this.estado,
      orden: orden ?? this.orden,
      etiquetas: etiquetas ?? this.etiquetas,
      permitePersonalizacion:
          permitePersonalizacion ?? this.permitePersonalizacion,
      placeholderObservacion:
          placeholderObservacion ?? this.placeholderObservacion,
      limiteCaracteresObs: limiteCaracteresObs ?? this.limiteCaracteresObs,
    );
  }
}
