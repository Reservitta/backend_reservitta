import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_config.dart';

/// Arma el concepto de la transferencia: un código corto del registro más el nombre del
/// cliente, para que el restaurante encuentre el pago rápido en su estado de cuenta.
class ConceptoTransferencia {
  ConceptoTransferencia._();

  /// Los conceptos SPEI aceptan pocos caracteres y sin acentos.
  static const int maxLongitud = 30;

  /// Código corto y estable del registro (primeros 5 caracteres de su id).
  static String codigo(String id) {
    final limpio = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (limpio.isEmpty) return '-----';
    return limpio.length <= 5 ? limpio : limpio.substring(0, 5);
  }

  /// Ejemplo: `RES 7K2QA JUAN PEREZ`. [prefijo] es `RES` (reserva) o `PED` (pedido).
  static String generar({
    required String prefijo,
    required String id,
    required String nombre,
  }) {
    final base = '$prefijo ${codigo(id)}';
    final nombreLimpio = _sinAcentos(nombre)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (nombreLimpio.isEmpty) return base;
    final completo = '$base $nombreLimpio';
    if (completo.length <= maxLongitud) return completo;
    return completo.substring(0, maxLongitud).trim();
  }

  static String _sinAcentos(String texto) {
    const origen = 'áàäâéèëêíìïîóòöôúùüûñÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
    const destino = 'aaaaeeeeiiiioooouuuunAAAAEEEEIIIIOOOOUUUUN';
    final salida = StringBuffer();
    for (final c in texto.split('')) {
      final i = origen.indexOf(c);
      salida.write(i >= 0 ? destino[i] : c);
    }
    return salida.toString();
  }
}

/// Anticipo de una reservación: lo que debe pagar, a dónde y en qué va la revisión.
///
/// Copia los datos bancarios y la política al momento de reservar, para que el cliente
/// vea lo mismo aunque el restaurante los cambie después.
class AnticipoReserva {
  static const String estadoPendiente = 'pendiente';
  static const String estadoComprobanteEnviado = 'comprobante_enviado';
  static const String estadoConfirmado = 'confirmado';
  static const String estadoRechazado = 'rechazado';

  final double monto;
  final String estado;
  final DateTime? venceEn;
  final DatosBancarios cuenta;
  final String politicaCancelacion;
  final DateTime? comprobanteEnviadoEn;
  final String motivoRechazo;

  const AnticipoReserva({
    required this.monto,
    this.estado = estadoPendiente,
    this.venceEn,
    this.cuenta = const DatosBancarios(),
    this.politicaCancelacion = '',
    this.comprobanteEnviadoEn,
    this.motivoRechazo = '',
  });

  /// Anticipo nuevo según la configuración del restaurante.
  factory AnticipoReserva.desdeConfig({
    required AnticipoConfig config,
    required DatosBancarios cuenta,
    required DateTime ahora,
    DateTime? inicioReserva,
  }) {
    var vence = ahora.add(Duration(hours: config.horasLimite));
    // No tiene sentido darle más tiempo que el que falta para la reserva.
    if (inicioReserva != null && inicioReserva.isBefore(vence)) {
      vence = inicioReserva;
    }
    return AnticipoReserva(
      monto: config.monto,
      venceEn: vence,
      cuenta: cuenta,
      politicaCancelacion: config.politicaCancelacion,
    );
  }

  bool get pendiente => estado == estadoPendiente;
  bool get comprobanteEnviado => estado == estadoComprobanteEnviado;
  bool get confirmado => estado == estadoConfirmado;
  bool get rechazado => estado == estadoRechazado;

  /// El cliente todavía puede subir (o volver a subir) su comprobante.
  bool get aceptaComprobante => pendiente || rechazado;

  bool estaVencido(DateTime ahora) =>
      !confirmado && venceEn != null && ahora.isAfter(venceEn!);

  String get etiquetaEstado {
    switch (estado) {
      case estadoComprobanteEnviado:
        return 'Comprobante por revisar';
      case estadoConfirmado:
        return 'Anticipo confirmado';
      case estadoRechazado:
        return 'Comprobante rechazado';
      case estadoPendiente:
      default:
        return 'Esperando anticipo';
    }
  }

  factory AnticipoReserva.fromMap(Map<String, dynamic> data) {
    DateTime? fecha(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    return AnticipoReserva(
      monto: (data['monto'] as num?)?.toDouble() ?? 0,
      estado: (data['estado'] as String?) ?? estadoPendiente,
      venceEn: fecha(data['venceEn']),
      cuenta: DatosBancarios.fromMap(data['cuenta'] as Map<String, dynamic>?),
      politicaCancelacion: (data['politicaCancelacion'] as String?) ?? '',
      comprobanteEnviadoEn: fecha(data['comprobanteEnviadoEn']),
      motivoRechazo: (data['motivoRechazo'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'monto': monto,
        'estado': estado,
        if (venceEn != null) 'venceEn': Timestamp.fromDate(venceEn!),
        'cuenta': cuenta.toMap(),
        'politicaCancelacion': politicaCancelacion,
        if (comprobanteEnviadoEn != null)
          'comprobanteEnviadoEn': Timestamp.fromDate(comprobanteEnviadoEn!),
        if (motivoRechazo.isNotEmpty) 'motivoRechazo': motivoRechazo,
      };
}
