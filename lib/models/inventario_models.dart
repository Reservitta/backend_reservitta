import 'package:cloud_firestore/cloud_firestore.dart';

/// Redondea a 3 decimales para que sumar y restar gramos o litros no arrastre
/// errores de coma flotante (0.1 + 0.2 = 0.30000000000000004).
double redondearCantidad(num valor) => (valor * 1000).round() / 1000;

/// Texto corto de una cantidad: sin ceros de más (`2`, `0.5`, `1.25`).
String formatoCantidad(num valor) {
  final v = redondearCantidad(valor);
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

/// Unidades en las que se miden los insumos.
class UnidadInsumo {
  UnidadInsumo._();

  static const List<String> todas = ['pza', 'kg', 'g', 'l', 'ml'];

  static String etiqueta(String unidad) {
    switch (unidad) {
      case 'pza':
        return 'Piezas';
      case 'kg':
        return 'Kilogramos';
      case 'g':
        return 'Gramos';
      case 'l':
        return 'Litros';
      case 'ml':
        return 'Mililitros';
      default:
        return unidad;
    }
  }
}

/// Insumo del catálogo del restaurante (se define una vez; cada sucursal lleva
/// sus propias existencias).
class InsumoModel {
  final String id;
  final String nombre;
  final String unidad;

  /// Categoría para filtrar el inventario (por ejemplo "Carnes y proteínas").
  /// Vacía en los insumos creados antes de que existiera.
  final String categoria;

  const InsumoModel({required this.id, required this.nombre, this.unidad = 'pza', this.categoria = ''});

  /// Nombre con el que se agrupa en los filtros.
  String get etiquetaCategoria =>
      categoria.trim().isEmpty ? CategoriaInsumo.sinCategoria : categoria.trim();

  factory InsumoModel.fromMap(String id, Map<String, dynamic> data) => InsumoModel(
        id: id,
        nombre: (data['nombre'] as String?) ?? 'Insumo',
        unidad: (data['unidad'] as String?) ?? 'pza',
        categoria: ((data['categoria'] as String?) ?? '').trim(),
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'unidad': unidad,
        if (categoria.trim().isNotEmpty) 'categoria': categoria.trim(),
      };
}

/// Categorías sugeridas para clasificar los insumos.
class CategoriaInsumo {
  CategoriaInsumo._();

  static const String sinCategoria = 'Sin categoría';

  static const List<String> sugeridas = [
    'Carnes y proteínas',
    'Lácteos y quesos',
    'Verduras y frutas',
    'Panadería y tortillas',
    'Papas y botanas',
    'Salsas y aderezos',
    'Bebidas y mezclas',
    'Abarrotes',
    'Otros',
  ];

  /// Texto en minúsculas y sin acentos, para buscar sin importar cómo se escriba.
  static String normalizar(String texto) {
    const con = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sin = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final c in texto.toLowerCase().trim().split('')) {
      final i = con.indexOf(c);
      b.write(i >= 0 ? sin[i] : c);
    }
    return b.toString();
  }
}

/// Existencias de un insumo en una sucursal.
class ExistenciaModel {
  final String insumoId;
  final double cantidad;
  final double minimo;

  const ExistenciaModel({required this.insumoId, this.cantidad = 0, this.minimo = 0});

  /// Sin existencias (o con una cantidad negativa por algún ajuste).
  bool get agotado => cantidad <= 0;

  /// Quedan pocas: igual o por debajo del mínimo definido (y todavía hay algo).
  bool get bajo => !agotado && minimo > 0 && cantidad <= minimo;

  /// Necesita atención: agotado o bajo.
  bool get requiereAtencion => agotado || bajo;

  factory ExistenciaModel.fromMap(String insumoId, Map<String, dynamic>? data) {
    final d = data ?? const {};
    return ExistenciaModel(
      insumoId: insumoId,
      cantidad: redondearCantidad((d['cantidad'] as num?) ?? 0),
      minimo: redondearCantidad((d['minimo'] as num?) ?? 0),
    );
  }

  Map<String, dynamic> toMap() => {'cantidad': cantidad, 'minimo': minimo};
}

/// Entrada o salida de inventario. Las salidas automáticas (al preparar un pedido)
/// llevan su origen y la referencia al pedido o a la reserva.
class MovimientoInventario {
  static const String entrada = 'entrada';
  static const String salida = 'salida';

  static const String origenManual = 'manual';
  static const String origenPedido = 'pedido';
  static const String origenPreorden = 'preorden';

  final String id;
  final String insumoId;
  final String insumoNombre;
  final String unidad;
  final String tipo;
  final double cantidad;
  final String motivo;
  final String origen;
  final String refId;

  /// Lo que faltó para completar la salida automática (existencias insuficientes).
  final double faltante;
  final String por;
  final DateTime? en;

  const MovimientoInventario({
    this.id = '',
    required this.insumoId,
    this.insumoNombre = '',
    this.unidad = 'pza',
    required this.tipo,
    required this.cantidad,
    this.motivo = '',
    this.origen = origenManual,
    this.refId = '',
    this.faltante = 0,
    this.por = '',
    this.en,
  });

  bool get esEntrada => tipo == entrada;
  bool get tieneFaltante => faltante > 0;

  factory MovimientoInventario.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['en'];
    return MovimientoInventario(
      id: id,
      insumoId: (data['insumoId'] as String?) ?? '',
      insumoNombre: (data['insumoNombre'] as String?) ?? '',
      unidad: (data['unidad'] as String?) ?? 'pza',
      tipo: (data['tipo'] as String?) ?? salida,
      cantidad: redondearCantidad((data['cantidad'] as num?) ?? 0),
      motivo: (data['motivo'] as String?) ?? '',
      origen: (data['origen'] as String?) ?? origenManual,
      refId: (data['refId'] as String?) ?? '',
      faltante: redondearCantidad((data['faltante'] as num?) ?? 0),
      por: (data['por'] as String?) ?? '',
      en: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'insumoId': insumoId,
        'insumoNombre': insumoNombre,
        'unidad': unidad,
        'tipo': tipo,
        'cantidad': cantidad,
        'motivo': motivo,
        'origen': origen,
        if (refId.isNotEmpty) 'refId': refId,
        if (faltante > 0) 'faltante': faltante,
        'por': por,
        'en': FieldValue.serverTimestamp(),
      };
}

/// Un ingrediente de la receta de un platillo: cuánto de un insumo usa una porción.
class RecetaItem {
  final String insumoId;
  final String nombre;
  final String unidad;
  final double cantidad;

  const RecetaItem({
    required this.insumoId,
    this.nombre = '',
    this.unidad = 'pza',
    required this.cantidad,
  });

  factory RecetaItem.fromMap(Map<String, dynamic> data) => RecetaItem(
        insumoId: (data['insumoId'] as String?) ?? '',
        nombre: (data['nombre'] as String?) ?? '',
        unidad: (data['unidad'] as String?) ?? 'pza',
        cantidad: redondearCantidad((data['cantidad'] as num?) ?? 0),
      );

  Map<String, dynamic> toMap() => {
        'insumoId': insumoId,
        'nombre': nombre,
        'unidad': unidad,
        'cantidad': cantidad,
      };

  RecetaItem copyWith({double? cantidad}) => RecetaItem(
        insumoId: insumoId,
        nombre: nombre,
        unidad: unidad,
        cantidad: cantidad ?? this.cantidad,
      );
}

/// Un insumo que no alcanzó para completar un descuento.
class FaltanteInsumo {
  final String insumoId;
  final String nombre;
  final String unidad;
  final double requerido;
  final double disponible;

  const FaltanteInsumo({
    required this.insumoId,
    required this.nombre,
    required this.unidad,
    required this.requerido,
    required this.disponible,
  });

  double get falto => redondearCantidad(requerido - disponible);

  String get texto => '$nombre (faltaron ${formatoCantidad(falto)} $unidad)';
}

/// Resultado de descontar los insumos de un pedido o de una preorden.
class DescuentoResultado {
  /// Se descontó ahora. Falso si ya se había descontado antes o no hay nada que descontar.
  final bool aplicado;
  final bool yaDescontado;
  final List<FaltanteInsumo> faltantes;

  const DescuentoResultado({
    this.aplicado = false,
    this.yaDescontado = false,
    this.faltantes = const [],
  });

  bool get hayFaltantes => faltantes.isNotEmpty;

  String? get aviso => hayFaltantes
      ? 'Inventario insuficiente: ${faltantes.map((f) => f.texto).join(', ')}.'
      : null;
}
