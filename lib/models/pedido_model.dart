import 'package:cloud_firestore/cloud_firestore.dart';

/// Un platillo dentro del pedido a domicilio o para recoger.
class PedidoLinea {
  final String platilloId;
  final String nombre;
  final double precio;
  final int cantidad;

  const PedidoLinea({
    required this.platilloId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
  });

  double get total => precio * cantidad;

  factory PedidoLinea.fromMap(Map<String, dynamic> data) => PedidoLinea(
        platilloId: (data['platilloId'] as String?) ?? '',
        nombre: (data['nombre'] as String?) ?? 'Platillo',
        precio: (data['precio'] as num?)?.toDouble() ?? 0,
        cantidad: (data['cantidad'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'platilloId': platilloId,
        'nombre': nombre,
        'precio': precio,
        'cantidad': cantidad,
        'total': total,
      };
}

/// Pedido en línea: a domicilio o para recoger en el local.
class PedidoModel {
  // Cómo se entrega
  static const String entregaDomicilio = 'domicilio';
  static const String entregaRecoger = 'recoger';

  // Cómo paga
  static const String pagoTransferencia = 'transferencia';
  static const String pagoEfectivo = 'efectivo';

  // Estado del pedido
  static const String estadoRecibido = 'recibido';
  static const String estadoPreparando = 'preparando';
  static const String estadoListo = 'listo';
  static const String estadoEnCamino = 'en_camino';
  static const String estadoEntregado = 'entregado';
  static const String estadoCancelado = 'cancelado';

  // Estado del pago
  static const String pagoPendiente = 'pendiente';
  static const String pagoComprobanteEnviado = 'comprobante_enviado';
  static const String pagoConfirmado = 'confirmado';
  static const String pagoRechazado = 'rechazado';

  final String id;
  final String restauranteId;
  final String restauranteNombre;
  final String usuarioId;
  final String contactoNombre;
  final String contactoTelefono;
  final List<PedidoLinea> lineas;
  final double total;
  final String tipoEntrega;
  final String direccion;
  final String referencias;
  final String metodoPago;
  final String estadoPago;
  final String estado;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  const PedidoModel({
    required this.id,
    required this.restauranteId,
    this.restauranteNombre = '',
    this.usuarioId = '',
    this.contactoNombre = '',
    this.contactoTelefono = '',
    this.lineas = const [],
    this.total = 0,
    this.tipoEntrega = entregaRecoger,
    this.direccion = '',
    this.referencias = '',
    this.metodoPago = pagoEfectivo,
    this.estadoPago = pagoPendiente,
    this.estado = estadoRecibido,
    this.creadoEn,
    this.actualizadoEn,
  });

  bool get esDomicilio => tipoEntrega == entregaDomicilio;
  bool get esTransferencia => metodoPago == pagoTransferencia;
  bool get estaCerrado => estado == estadoEntregado || estado == estadoCancelado;
  bool get pagoConfirmadoOk => estadoPago == pagoConfirmado;

  int get totalPlatillos => lineas.fold(0, (s, l) => s + l.cantidad);

  /// Recibe el total de las líneas (nunca se confía en un total ajeno).
  static double sumar(Iterable<PedidoLinea> lineas) =>
      lineas.fold(0.0, (s, l) => s + l.total);

  // --- Flujo de estados ---------------------------------------------------

  /// Estados por los que pasa el pedido, según cómo se entrega.
  static List<String> flujo(String tipoEntrega) => [
        estadoRecibido,
        estadoPreparando,
        estadoListo,
        if (tipoEntrega == entregaDomicilio) estadoEnCamino,
        estadoEntregado,
      ];

  /// Estado al que se avanza con un toque; null si ya terminó.
  String? get siguienteEstado {
    if (estaCerrado) return null;
    final pasos = flujo(tipoEntrega);
    final i = pasos.indexOf(estado);
    if (i < 0 || i >= pasos.length - 1) return null;
    return pasos[i + 1];
  }

  /// Se puede cancelar mientras no se haya entregado.
  bool get sePuedeCancelar => !estaCerrado;

  static String etiquetaEstado(String estado, {String tipoEntrega = entregaRecoger}) {
    switch (estado) {
      case estadoPreparando:
        return 'Preparando';
      case estadoListo:
        return tipoEntrega == entregaDomicilio ? 'Listo para salir' : 'Listo para recoger';
      case estadoEnCamino:
        return 'En camino';
      case estadoEntregado:
        return 'Entregado';
      case estadoCancelado:
        return 'Cancelado';
      case estadoRecibido:
      default:
        return 'Recibido';
    }
  }

  String get etiquetaEstadoActual =>
      etiquetaEstado(estado, tipoEntrega: tipoEntrega);

  static String etiquetaPago(String metodo, String estadoPago) {
    if (metodo == pagoEfectivo) {
      return estadoPago == pagoConfirmado ? 'Efectivo · cobrado' : 'Efectivo · por cobrar';
    }
    switch (estadoPago) {
      case pagoComprobanteEnviado:
        return 'Transferencia · comprobante por revisar';
      case pagoConfirmado:
        return 'Transferencia · pago confirmado';
      case pagoRechazado:
        return 'Transferencia · comprobante rechazado';
      case pagoPendiente:
      default:
        return 'Transferencia · esperando pago';
    }
  }

  String get etiquetaPagoActual => etiquetaPago(metodoPago, estadoPago);

  // --- Serialización ---------------------------------------------------------

  factory PedidoModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      PedidoModel.fromMap(doc.id, doc.data() ?? {});

  factory PedidoModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? fecha(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    final contacto = (data['contacto'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pago = (data['pago'] as Map?)?.cast<String, dynamic>() ?? const {};
    final entrega = (data['entrega'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PedidoModel(
      id: id,
      restauranteId: (data['restauranteId'] as String?) ?? '',
      restauranteNombre: (data['restauranteNombre'] as String?) ?? '',
      usuarioId: (data['usuarioId'] as String?) ?? '',
      contactoNombre: (contacto['nombre'] as String?) ?? '',
      contactoTelefono: (contacto['telefono'] as String?) ?? '',
      lineas: [
        for (final l in (data['items'] as List?) ?? const [])
          if (l is Map) PedidoLinea.fromMap(Map<String, dynamic>.from(l)),
      ],
      total: (data['total'] as num?)?.toDouble() ?? 0,
      tipoEntrega: (entrega['tipo'] as String?) ?? entregaRecoger,
      direccion: (entrega['direccion'] as String?) ?? '',
      referencias: (entrega['referencias'] as String?) ?? '',
      metodoPago: (pago['metodo'] as String?) ?? pagoEfectivo,
      estadoPago: (pago['estado'] as String?) ?? pagoPendiente,
      estado: (data['estado'] as String?) ?? estadoRecibido,
      creadoEn: fecha(data['creadoEn']),
      actualizadoEn: fecha(data['actualizadoEn']),
    );
  }

  Map<String, dynamic> toMap() => {
        'restauranteId': restauranteId,
        'restauranteNombre': restauranteNombre,
        'usuarioId': usuarioId,
        'contacto': {'nombre': contactoNombre, 'telefono': contactoTelefono},
        'items': lineas.map((l) => l.toMap()).toList(),
        'total': total,
        'entrega': {
          'tipo': tipoEntrega,
          if (esDomicilio) 'direccion': direccion,
          if (esDomicilio && referencias.isNotEmpty) 'referencias': referencias,
        },
        'pago': {'metodo': metodoPago, 'estado': estadoPago},
        'estado': estado,
        'creadoEn': creadoEn != null
            ? Timestamp.fromDate(creadoEn!)
            : FieldValue.serverTimestamp(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      };
}
