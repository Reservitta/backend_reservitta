/// Resultado de la entrega o intento de notificación (HU14-RF03).
class NotificationDeliveryResult {
  final bool exitoso;
  final String notificacionId;
  final String canal; // 'email' o 'whatsapp'
  final String destino; // correo o teléfono
  final int intentos;
  final bool requiereReintentoManual;
  final String? error;
  final String mensajeFormateado;
  final DateTime fechaEnvio;

  String? get motivoRechazo => error;

  const NotificationDeliveryResult({
    required this.exitoso,
    required this.notificacionId,
    required this.canal,
    required this.destino,
    required this.intentos,
    this.requiereReintentoManual = false,
    this.error,
    this.mensajeFormateado = '',
    required this.fechaEnvio,
  });

  factory NotificationDeliveryResult.success({
    required String notificacionId,
    required String canal,
    required String destino,
    required int intentos,
    String mensajeFormateado = '',
  }) {
    return NotificationDeliveryResult(
      exitoso: true,
      notificacionId: notificacionId,
      canal: canal,
      destino: destino,
      intentos: intentos,
      requiereReintentoManual: false,
      mensajeFormateado: mensajeFormateado,
      fechaEnvio: DateTime.now(),
    );
  }

  factory NotificationDeliveryResult.failed({
    required String notificacionId,
    required String canal,
    required String destino,
    required int intentos,
    required String error,
    bool requiereReintentoManual = true,
    String mensajeFormateado = '',
  }) {
    return NotificationDeliveryResult(
      exitoso: false,
      notificacionId: notificacionId,
      canal: canal,
      destino: destino,
      intentos: intentos,
      requiereReintentoManual: requiereReintentoManual,
      error: error,
      mensajeFormateado: mensajeFormateado,
      fechaEnvio: DateTime.now(),
    );
  }

  factory NotificationDeliveryResult.rejected({
    required String motivo,
    String reservaId = '',
  }) {
    return NotificationDeliveryResult(
      exitoso: false,
      notificacionId: reservaId,
      canal: 'ninguno',
      destino: '',
      intentos: 0,
      requiereReintentoManual: false,
      error: motivo,
      mensajeFormateado: '',
      fechaEnvio: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exitoso': exitoso,
      'notificacionId': notificacionId,
      'canal': canal,
      'destino': destino,
      'intentos': intentos,
      'requiereReintentoManual': requiereReintentoManual,
      'error': error,
      'mensajeFormateado': mensajeFormateado,
      'fechaEnvio': fechaEnvio.toIso8601String(),
    };
  }
}

