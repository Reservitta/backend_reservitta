import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_delivery_result.dart';
import '../models/reservation_model.dart';
import '../models/reservation_notification_payload.dart';
import 'notification_clients.dart';

/// Servicio y endpoint reutilizable para el envío de confirmaciones (HU19) y recordatorios (HU21)
/// por correo electrónico o WhatsApp Business API (HU14-RF03 [#49]).
///
/// Criterios de aceptación:
/// 1. Formato JSON estándar con contacto, restaurante, fecha, hora, duración, personas, mesas, preorden y ocasión.
/// 2. Endpoint único y reutilizable que despacha por correo transaccional o WhatsApp según preferencia/disponibilidad.
/// 3. Consumido por HU19 (confirmación) y HU21 (recordatorio), evitando duplicidad.
/// 4. Reintentos automáticos limitados (máx 3). Si falla, queda registrado para reintento manual en Firestore.
/// 5. El envío SOLO se dispara si la reserva quedó confirmada, no antes.
class ConfirmationNotificationService {
  final TransactionalEmailClient _emailClient;
  final WhatsAppBusinessApiClient _whatsAppClient;
  final FirebaseFirestore? firestore;
  final int maxRetries;

  ConfirmationNotificationService({
    TransactionalEmailClient? emailClient,
    WhatsAppBusinessApiClient? whatsAppClient,
    this.firestore,
    this.maxRetries = 3,
  })  : _emailClient = emailClient ?? DefaultTransactionalEmailClient(firestore: firestore),
        _whatsAppClient = whatsAppClient ?? DefaultWhatsAppBusinessApiClient();

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  /// Endpoint único y reutilizable para el envío de notificaciones (HU14-RF03 Criterio 2 y 3).
  Future<NotificationDeliveryResult> sendNotification(
    ReservationNotificationPayload payload,
  ) async {
    // -------------------------------------------------------------------------
    // CRITERIO 5: Solo se dispara si la reserva quedó confirmada
    // -------------------------------------------------------------------------
    final estadoNormalizado =
        ReservationModel.normalizeStatus(payload.estadoReserva);
    if (estadoNormalizado != ReservationModel.estadoConfirmada) {
      return NotificationDeliveryResult.rejected(
        motivo:
            'El envío de confirmación/recordatorio fue rechazado porque la reserva no está en estado confirmada (estado actual: "${payload.estadoReserva}").',
        reservaId: payload.reservaId,
      );
    }

    // -------------------------------------------------------------------------
    // CRITERIO 2: Resolver el canal disponible y preferido (Email vs WhatsApp)
    // -------------------------------------------------------------------------
    final resolution = resolveDeliveryChannel(payload);
    if (!resolution.isDeliverable) {
      return NotificationDeliveryResult.rejected(
        motivo: resolution.reasonIfNotDeliverable ??
            'No se proporcionaron datos de contacto válidos (correo o teléfono).',
        reservaId: payload.reservaId,
      );
    }

    final canal = resolution.channel;
    final destino = resolution.destination;
    final mensaje = buildNotificationMessage(payload);
    final subject = buildNotificationSubject(payload);

    // Identificador para trazabilidad
    final notifId = payload.reservaId.isNotEmpty
        ? 'notif_${payload.tipo}_${payload.reservaId}'
        : 'notif_${payload.tipo}_${DateTime.now().millisecondsSinceEpoch}';

    // -------------------------------------------------------------------------
    // CRITERIO 4: Reintentos automáticos y persistencia para reintento manual
    // -------------------------------------------------------------------------
    int attempts = 0;
    String? lastError;
    bool delivered = false;

    while (attempts < maxRetries && !delivered) {
      attempts++;
      try {
        if (canal == ReservationNotificationPayload.canalWhatsApp) {
          delivered = await _whatsAppClient.sendWhatsAppMessage(
            toPhone: destino,
            message: mensaje,
          );
        } else {
          delivered = await _emailClient.sendEmail(
            to: destino,
            subject: subject,
            body: mensaje,
          );
        }
      } catch (e) {
        lastError = e.toString();
        delivered = false;
      }
    }

    // Persistencia en Firestore (colección 'notificaciones' - database_init_service)
    await _recordNotificationInFirestore(
      notifId: notifId,
      payload: payload,
      canal: canal,
      destino: destino,
      mensaje: mensaje,
      exitoso: delivered,
      intentos: attempts,
      error: lastError,
      requiereReintentoManual: !delivered,
    );

    if (delivered) {
      return NotificationDeliveryResult.success(
        notificacionId: notifId,
        canal: canal,
        destino: destino,
        intentos: attempts,
        mensajeFormateado: mensaje,
      );
    } else {
      return NotificationDeliveryResult.failed(
        notificacionId: notifId,
        canal: canal,
        destino: destino,
        intentos: attempts,
        error: lastError ?? 'Fallo tras $attempts intentos de envío.',
        requiereReintentoManual: true,
        mensajeFormateado: mensaje,
      );
    }
  }

  /// Criterio 4: Reprocesa un reintento manual desde un registro existente en Firestore.
  Future<NotificationDeliveryResult> retryManualNotification(
    String notificacionId,
  ) async {
    try {
      final doc = await _db.collection('notificaciones').doc(notificacionId).get();
      if (!doc.exists) {
        return NotificationDeliveryResult.rejected(
          motivo: 'No se encontró la notificación con ID $notificacionId para reintento manual.',
          reservaId: notificacionId,
        );
      }

      final data = doc.data()!;
      final payloadMap = Map<String, dynamic>.from(data['payloadJson'] as Map? ?? {});
      if (payloadMap.isEmpty) {
        return NotificationDeliveryResult.rejected(
          motivo: 'La notificación $notificacionId no cuenta con el payload estándar almacenado.',
          reservaId: notificacionId,
        );
      }

      final payload = ReservationNotificationPayload.fromMap(payloadMap);
      return await sendNotification(payload);
    } catch (e) {
      return NotificationDeliveryResult.failed(
        notificacionId: notificacionId,
        canal: 'desconocido',
        destino: '',
        intentos: 1,
        error: 'Error al reintentar manualmente: $e',
        requiereReintentoManual: true,
      );
    }
  }

  /// Criterio 2: Resuelve con inteligencia qué canal emplear según preferencia y disponibilidad.
  ChannelResolution resolveDeliveryChannel(
    ReservationNotificationPayload payload,
  ) {
    final hasEmail = payload.contactoCorreo.trim().contains('@');
    final digitsPhone = payload.contactoTelefono.replaceAll(RegExp(r'\D'), '');
    final hasPhone = digitsPhone.length >= 10;

    final pref = payload.canalPreferido.trim().toLowerCase();

    // Preferencia explícita WhatsApp
    if (pref == ReservationNotificationPayload.canalWhatsApp || pref == 'whatsapp') {
      if (hasPhone) {
        return ChannelResolution.deliverable(
          channel: ReservationNotificationPayload.canalWhatsApp,
          destination: digitsPhone,
        );
      }
      // Fallback a Email si no hay teléfono
      if (hasEmail) {
        return ChannelResolution.deliverable(
          channel: ReservationNotificationPayload.canalEmail,
          destination: payload.contactoCorreo.trim(),
          fallbackApplied: true,
        );
      }
    }

    // Preferencia por defecto Email
    if (hasEmail) {
      return ChannelResolution.deliverable(
        channel: ReservationNotificationPayload.canalEmail,
        destination: payload.contactoCorreo.trim(),
      );
    }

    // Fallback a WhatsApp si solo hay teléfono
    if (hasPhone) {
      return ChannelResolution.deliverable(
        channel: ReservationNotificationPayload.canalWhatsApp,
        destination: digitsPhone,
        fallbackApplied: true,
      );
    }

    return const ChannelResolution.undeliverable(
      reason: 'No hay correo electrónico ni teléfono válido configurado para enviar la notificación.',
    );
  }

  /// Criterio 3: Genera el asunto de acuerdo al tipo (Confirmación vs Recordatorio).
  String buildNotificationSubject(ReservationNotificationPayload payload) {
    final rest = payload.restauranteNombre.isNotEmpty
        ? payload.restauranteNombre
        : 'Reservitta';

    if (payload.tipo == ReservationNotificationPayload.tipoRecordatorio) {
      return 'Recordatorio: Tu reserva en $rest es hoy';
    }
    return '¡Reserva confirmada en $rest!';
  }

  /// Criterio 1: Construye el mensaje completo con todos los datos requeridos.
  String buildNotificationMessage(ReservationNotificationPayload payload) {
    final buffer = StringBuffer();
    final nombre = payload.contactoNombre.isNotEmpty
        ? payload.contactoNombre.trim()
        : 'Comensal';

    final esRecordatorio =
        payload.tipo == ReservationNotificationPayload.tipoRecordatorio;

    if (esRecordatorio) {
      buffer.writeln('¡Hola, $nombre! Te recordamos que tienes una reserva programada hoy en ${payload.restauranteNombre}.');
    } else {
      buffer.writeln('¡Hola, $nombre! Tu reserva en ${payload.restauranteNombre} ha sido confirmada con éxito.');
    }
    buffer.writeln();

    buffer.writeln('Detalles de tu visita:');
    buffer.writeln('- Restaurante: ${payload.restauranteNombre}');
    if (payload.restauranteDireccion.isNotEmpty) {
      buffer.writeln('- Dirección: ${payload.restauranteDireccion}');
    }
    buffer.writeln('- Fecha: ${payload.fecha}');
    buffer.writeln('- Horario: ${payload.horario}');
    buffer.writeln('- Duración: ${payload.duracionMin} minutos');
    buffer.writeln('- Personas: ${payload.personas}');
    final mesasStr = payload.mesas.isNotEmpty ? payload.mesas.join(', ') : 'Asignación al llegar';
    buffer.writeln('- Mesa(s): $mesasStr');
    if (payload.reservaId.isNotEmpty) {
      buffer.writeln('- Código de reservación: ${payload.reservaId}');
    }

    // Preorden si aplica (HU15/16)
    if (payload.tienePreorden) {
      buffer.writeln();
      buffer.writeln('Resumen de tu preorden:');
      for (final item in payload.preordenItems) {
        final cant = item['cantidad'] ?? 1;
        final nombreItem = item['nombre'] ?? 'Platillo';
        final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
        final obs = (item['observacion'] ?? item['notas'] ?? '').toString().trim();
        if (obs.isNotEmpty) {
          buffer.writeln('  • ${cant}x $nombreItem (\$${precio.toStringAsFixed(2)}) - "$obs"');
        } else {
          buffer.writeln('  • ${cant}x $nombreItem (\$${precio.toStringAsFixed(2)})');
        }
      }
    }

    // Ocasión especial si aplica (HU15/16)
    if (payload.tieneOcasionEspecial) {
      buffer.writeln();
      final ocasion = payload.ocasionEspecial!;
      final nombreOcasion = ocasion['tipo'] ?? ocasion['nombre'] ?? 'Ocasión especial';
      buffer.writeln('Celebración: $nombreOcasion');
      final notaOcasion = (ocasion['nota'] ?? ocasion['descripcion'] ?? '').toString().trim();
      if (notaOcasion.isNotEmpty) {
        buffer.writeln('  • Nota: $notaOcasion');
      }
      final exp = ocasion['experiencias'] as List<dynamic>?;
      if (exp != null && exp.isNotEmpty) {
        final expNombres = exp.map((e) => e is Map ? (e['nombre'] ?? '') : e.toString()).where((e) => e.toString().isNotEmpty);
        if (expNombres.isNotEmpty) {
          buffer.writeln('  • Experiencias: ${expNombres.join(", ")}');
        }
      }
    }

    // Alergias / notas si aplican
    if (payload.tieneAlergias || payload.notas.isNotEmpty) {
      buffer.writeln();
      if (payload.tieneAlergias) {
        buffer.writeln('Alergias reportadas: ${payload.alergias.join(", ")}');
      }
      if (payload.notas.isNotEmpty) {
        buffer.writeln('Notas adicionales: ${payload.notas}');
      }
    }

    buffer.writeln();
    buffer.writeln('¡Te esperamos! Si necesitas modificar tu visita o tienes dudas, ponte en contacto con nosotros.');

    return buffer.toString().trim();
  }

  /// Criterio 4: Persistencia en Firestore
  Future<void> _recordNotificationInFirestore({
    required String notifId,
    required ReservationNotificationPayload payload,
    required String canal,
    required String destino,
    required String mensaje,
    required bool exitoso,
    required int intentos,
    required String? error,
    required bool requiereReintentoManual,
  }) async {
    try {
      final docRef = _db.collection('notificaciones').doc(notifId);
      await docRef.set({
        'reservaId': payload.reservaId,
        'restauranteId': payload.restauranteId,
        'destinatarioUid': payload.usuarioId.isNotEmpty ? payload.usuarioId : null,
        'tipo': payload.tipo,
        'canal': canal,
        'destino': destino,
        'mensaje': mensaje,
        'payloadJson': payload.toMap(),
        'estado': exitoso ? 'enviada' : (requiereReintentoManual ? 'pendiente_reintento_manual' : 'fallida'),
        'intentos': intentos,
        'ultimoError': error,
        'requiereReintentoManual': requiereReintentoManual,
        'creadaEn': FieldValue.serverTimestamp(),
        'enviadaEn': exitoso ? FieldValue.serverTimestamp() : null,
      });
    } catch (_) {
      // Ignora fallo de log si Firestore no está inicializado o en entorno sin conexión
    }
  }
}

/// Helper para resolución de canal
class ChannelResolution {
  final bool isDeliverable;
  final String channel;
  final String destination;
  final bool fallbackApplied;
  final String? reasonIfNotDeliverable;

  const ChannelResolution.deliverable({
    required this.channel,
    required this.destination,
    this.fallbackApplied = false,
  })  : isDeliverable = true,
        reasonIfNotDeliverable = null;

  const ChannelResolution.undeliverable({required String reason})
      : isDeliverable = false,
        channel = 'ninguno',
        destination = '',
        fallbackApplied = false,
        reasonIfNotDeliverable = reason;
}
