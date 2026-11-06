import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/reservation_notification_payload.dart';
import 'package:reservitta/services/confirmation_notification_service.dart';
import 'package:reservitta/services/notification_clients.dart';

/// Fake para TransactionalEmailClient con control de fallos y conteo de llamadas
class FakeTransactionalEmailClient implements TransactionalEmailClient {
  int sendCalls = 0;
  int failuresBeforeSuccess = 0;
  bool alwaysFail = false;
  String? lastRecipient;
  String? lastSubject;
  String? lastBody;

  @override
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    sendCalls++;
    lastRecipient = to;
    lastSubject = subject;
    lastBody = body;

    if (alwaysFail) {
      throw Exception('Simulated SMTP connection error.');
    }
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw Exception('Simulated temporary SMTP failure.');
    }
    return true;
  }
}

/// Fake para WhatsAppBusinessApiClient con control de fallos y conteo de llamadas
class FakeWhatsAppBusinessApiClient implements WhatsAppBusinessApiClient {
  int sendCalls = 0;
  int failuresBeforeSuccess = 0;
  bool alwaysFail = false;
  String? lastPhone;
  String? lastMessage;

  @override
  Future<bool> sendWhatsAppMessage({
    required String toPhone,
    required String message,
  }) async {
    sendCalls++;
    lastPhone = toPhone;
    lastMessage = message;

    if (alwaysFail) {
      throw Exception('Simulated WhatsApp API 500 error.');
    }
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw Exception('Simulated temporary rate limit.');
    }
    return true;
  }
}

void main() {
  group('HU14-RF03: Servicio reutilizable de envío de confirmación y recordatorio', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeTransactionalEmailClient fakeEmailClient;
    late FakeWhatsAppBusinessApiClient fakeWhatsAppClient;
    late ConfirmationNotificationService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeEmailClient = FakeTransactionalEmailClient();
      fakeWhatsAppClient = FakeWhatsAppBusinessApiClient();
      service = ConfirmationNotificationService(
        emailClient: fakeEmailClient,
        whatsAppClient: fakeWhatsAppClient,
        firestore: fakeFirestore,
        maxRetries: 3,
      );
    });

    // =========================================================================
    // CRITERIO 1: Formato JSON estándar
    // =========================================================================
    group('Criterio 1: Formato JSON estándar del payload', () {
      test('Serializa y deserializa todos los campos requeridos fielmente', () {
        final payload = ReservationNotificationPayload(
          reservaId: 'res_123',
          estadoReserva: ReservationModel.estadoConfirmada,
          tipo: ReservationNotificationPayload.tipoConfirmacion,
          contactoNombre: 'Carlos Santana',
          contactoCorreo: 'carlos@example.com',
          contactoTelefono: '+52 331 234 5678',
          canalPreferido: ReservationNotificationPayload.canalEmail,
          restauranteId: 'rest_01',
          restauranteNombre: 'La Trattoria Italiana',
          sucursalId: 'branch_gdl',
          sucursalNombre: 'Sucursal Providencia',
          fecha: '2026-11-20',
          horario: '19:30',
          duracionMin: 90,
          personas: 4,
          mesas: const ['Mesa 12', 'Mesa 13'],
          preordenItems: const [
            {'platilloId': 'p1', 'nombre': 'Pizza Margherita', 'cantidad': 2, 'precio': 180.0},
            {'platilloId': 'p2', 'nombre': 'Pasta Carbonara', 'cantidad': 1, 'precio': 220.0},
          ],
          ocasionEspecial: const {
            'tipo': 'Aniversario',
            'nota': 'Mesa decorada con rosas rojas',
          },
          alergias: const ['Nueces', 'Mariscos'],
          notas: 'Llegaremos puntuales',
          usuarioId: 'uid_carlos',
        );

        final map = payload.toMap();

        expect(map['reservaId'], 'res_123');
        expect(map['contacto']['nombre'], 'Carlos Santana');
        expect(map['restaurante']['nombre'], 'La Trattoria Italiana');
        expect(map['fecha'], '2026-11-20');
        expect(map['horario'], '19:30');
        expect(map['duracionMin'], 90);
        expect(map['personas'], 4);
        expect(map['mesas'], ['Mesa 12', 'Mesa 13']);
        expect((map['preorden'] as List).length, 2);
        expect(map['ocasionEspecial']['tipo'], 'Aniversario');
        expect(map['alergias'], ['Nueces', 'Mariscos']);

        // Deserialización
        final reconstructed = ReservationNotificationPayload.fromMap(map);
        expect(reconstructed.reservaId, payload.reservaId);
        expect(reconstructed.contactoCorreo, payload.contactoCorreo);
        expect(reconstructed.personas, 4);
        expect(reconstructed.hasPreorden, isTrue);
        expect(reconstructed.hasOcasionEspecial, isTrue);
        expect(reconstructed.preordenTotal, 580.0);
      });

      test('Crea payload correctamente desde una instancia de ReservationModel', () {
        final reservation = ReservationModel(
          id: 'res_abc',
          restauranteId: 'rest_italian',
          restauranteNombre: 'Trattoria Gourmet',
          contactoNombre: 'Elena Torres',
          contactoCorreo: 'elena@gmail.com',
          contactoTelefono: '3398765432',
          fechaLocal: '2026-12-01',
          inicio: DateTime(2026, 12, 1, 20, 0),
          duracionMin: 120,
          personas: 3,
          mesaIds: const ['m1', 'm2'],
          mesasNombres: const ['Terraza 1', 'Terraza 2'],
          estado: ReservationModel.estadoConfirmada,
          preordenItems: const [
            {'nombre': 'Vino Tinto', 'cantidad': 1, 'precio': 450.0}
          ],
          ocasionEspecial: const {'tipo': 'Cumpleaños'},
          alergias: const ['Gluten'],
        );

        final payload = ReservationNotificationPayload.fromReservation(
          reservation,
          tipo: ReservationNotificationPayload.tipoConfirmacion,
          canalPreferido: ReservationNotificationPayload.canalWhatsApp,
        );

        expect(payload.reservaId, 'res_abc');
        expect(payload.isReservaConfirmada, isTrue);
        expect(payload.contactoNombre, 'Elena Torres');
        expect(payload.canalPreferido, 'whatsapp');
        expect(payload.mesas, ['Terraza 1', 'Terraza 2']);
        expect(payload.preordenItems.length, 1);
        expect(payload.ocasionEspecial?['tipo'], 'Cumpleaños');
      });
    });

    // =========================================================================
    // CRITERIO 2: Endpoint único y despacho por Email o WhatsApp
    // =========================================================================
    group('Criterio 2: Despacho por correo o WhatsApp y resolución inteligente', () {
      test('Envía confirmación por correo si es el canal preferido y hay email', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_email_1',
          estadoReserva: ReservationModel.estadoConfirmada,
          contactoNombre: 'Valeria Castro',
          contactoCorreo: 'valeria@example.com',
          contactoTelefono: '3312345678',
          canalPreferido: ReservationNotificationPayload.canalEmail,
          restauranteId: 'rest_bistro',
          restauranteNombre: 'Bistró Central',
          fecha: '2026-11-25',
          horario: '14:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isTrue);
        expect(result.canal, ReservationNotificationPayload.canalEmail);
        expect(result.destino, 'valeria@example.com');
        expect(fakeEmailClient.sendCalls, 1);
        expect(fakeWhatsAppClient.sendCalls, 0);
        expect(fakeEmailClient.lastSubject, contains('Reserva confirmada en Bistró Central'));
      });

      test('Envía confirmación por WhatsApp si es el preferido y hay teléfono válido', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_wa_1',
          estadoReserva: ReservationModel.estadoConfirmada,
          contactoNombre: 'Pedro Martínez',
          contactoCorreo: 'pedro@example.com',
          contactoTelefono: '+52 (33) 1234-5678',
          canalPreferido: ReservationNotificationPayload.canalWhatsApp,
          restauranteId: 'rest_tacos',
          restauranteNombre: 'Tacos Gourmet',
          fecha: '2026-11-25',
          horario: '15:30',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isTrue);
        expect(result.canal, ReservationNotificationPayload.canalWhatsApp);
        expect(result.destino, '523312345678');
        expect(fakeWhatsAppClient.sendCalls, 1);
        expect(fakeEmailClient.sendCalls, 0);
        expect(fakeWhatsAppClient.lastMessage, contains('Tacos Gourmet'));
      });

      test('Aplica fallback a Email si se eligió WhatsApp pero falta teléfono', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_fallback_email',
          estadoReserva: ReservationModel.estadoConfirmada,
          contactoNombre: 'Laura Vega',
          contactoCorreo: 'laura@example.com',
          contactoTelefono: '', // Sin teléfono
          canalPreferido: ReservationNotificationPayload.canalWhatsApp,
          restauranteId: 'rest_cafe',
          restauranteNombre: 'Café Roma',
          fecha: '2026-11-25',
          horario: '10:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isTrue);
        expect(result.canal, ReservationNotificationPayload.canalEmail);
        expect(result.destino, 'laura@example.com');
        expect(fakeEmailClient.sendCalls, 1);
        expect(fakeWhatsAppClient.sendCalls, 0);
      });

      test('Aplica fallback a WhatsApp si no hay correo válido pero sí teléfono', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_fallback_wa',
          estadoReserva: ReservationModel.estadoConfirmada,
          contactoNombre: 'Miguel Solís',
          contactoCorreo: '', // Sin correo
          contactoTelefono: '3318889900',
          canalPreferido: ReservationNotificationPayload.canalEmail,
          restauranteId: 'rest_asador',
          restauranteNombre: 'Asador Vasco',
          fecha: '2026-11-25',
          horario: '16:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isTrue);
        expect(result.canal, ReservationNotificationPayload.canalWhatsApp);
        expect(result.destino, '3318889900');
        expect(fakeWhatsAppClient.sendCalls, 1);
      });

      test('Rechaza el envío si no hay ni correo ni teléfono válidos', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_invalida',
          estadoReserva: ReservationModel.estadoConfirmada,
          contactoNombre: 'Sin Datos',
          contactoCorreo: 'invalido',
          contactoTelefono: '123', // Incompleto
          restauranteId: 'rest_x',
          restauranteNombre: 'Restaurante X',
          fecha: '2026-11-25',
          horario: '12:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isFalse);
        expect(result.motivoRechazo, isNotNull);
        expect(fakeEmailClient.sendCalls, 0);
        expect(fakeWhatsAppClient.sendCalls, 0);
      });
    });

    // =========================================================================
    // CRITERIO 3: Reutilización para Confirmación (HU19) y Recordatorio (HU21)
    // =========================================================================
    group('Criterio 3: Soporte para Confirmación (HU19) y Recordatorio (HU21)', () {
      test('Formatea plantilla adaptada para recordatorio (HU21)', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_rec_1',
          estadoReserva: ReservationModel.estadoConfirmada,
          tipo: ReservationNotificationPayload.tipoRecordatorio,
          contactoNombre: 'Raquel Mendoza',
          contactoCorreo: 'raquel@example.com',
          restauranteId: 'rest_mariscos',
          restauranteNombre: 'Mariscos Bahía',
          fecha: '2026-11-06',
          horario: '13:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isTrue);
        expect(fakeEmailClient.lastSubject, contains('Recordatorio: Tu reserva en Mariscos Bahía'));
        expect(fakeEmailClient.lastBody, contains('Te recordamos que tienes una reserva programada hoy'));
      });

      test('Incluye detalles de preorden y ocasión en el cuerpo de la confirmación', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_completa',
          estadoReserva: ReservationModel.estadoConfirmada,
          tipo: ReservationNotificationPayload.tipoConfirmacion,
          contactoNombre: 'Sofía Lara',
          contactoCorreo: 'sofia@example.com',
          restauranteId: 'rest_chef',
          restauranteNombre: 'Le Petit Chef',
          fecha: '2026-11-26',
          horario: '21:00',
          preordenItems: [
            {'nombre': 'Sopa de cebolla', 'cantidad': 2, 'precio': 120.0}
          ],
          ocasionEspecial: {'tipo': 'Cumpleaños', 'nota': 'Pastel sorpresa'},
          alergias: ['Nueces'],
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isTrue);
        final body = fakeEmailClient.lastBody!;
        expect(body, contains('Resumen de tu preorden:'));
        expect(body, contains('2x Sopa de cebolla'));
        expect(body, contains('Celebración: Cumpleaños'));
        expect(body, contains('Pastel sorpresa'));
        expect(body, contains('Alergias reportadas: Nueces'));
      });
    });

    // =========================================================================
    // CRITERIO 4: Reintentos automáticos y registro para reintento manual
    // =========================================================================
    group('Criterio 4: Reintentos y recuperación manual', () {
      test('Reintenta hasta tener éxito y reporta el número exacto de intentos', () async {
        fakeEmailClient.failuresBeforeSuccess = 2; // Falla intento 1 y 2, tiene éxito en 3

        final payload = const ReservationNotificationPayload(
          reservaId: 'res_retry_success',
          estadoReserva: ReservationModel.estadoConfirmada,
          contactoNombre: 'Cliente Reintento',
          contactoCorreo: 'retry@example.com',
          restauranteId: 'rest_retry',
          restauranteNombre: 'Restaurante Reintento',
          fecha: '2026-11-27',
          horario: '18:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isTrue);
        expect(result.intentos, 3);
        expect(fakeEmailClient.sendCalls, 3);

        // Verifica que quedó registrado en Firestore como exitosa
        final doc = await fakeFirestore
            .collection('notificaciones')
            .doc('notif_confirmacion_res_retry_success')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['estado'], 'enviada');
        expect(doc.data()?['intentos'], 3);
      });

      test('Si falla todos los reintentos (máx 3), marca requiereReintentoManual: true en Firestore', () async {
        fakeEmailClient.alwaysFail = true;

        final payload = const ReservationNotificationPayload(
          reservaId: 'res_max_retries',
          estadoReserva: ReservationModel.estadoConfirmada,
          contactoNombre: 'Cliente Fallido',
          contactoCorreo: 'fail@example.com',
          restauranteId: 'rest_down',
          restauranteNombre: 'Restaurante Caído',
          fecha: '2026-11-27',
          horario: '19:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isFalse);
        expect(result.intentos, 3);
        expect(result.requiereReintentoManual, isTrue);

        // Verifica en Firestore el registro para reintento manual
        final doc = await fakeFirestore
            .collection('notificaciones')
            .doc('notif_confirmacion_res_max_retries')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['estado'], 'pendiente_reintento_manual');
        expect(doc.data()?['requiereReintentoManual'], isTrue);
        expect(doc.data()?['intentos'], 3);
        expect(doc.data()?['payloadJson'], isNotNull);
      });

      test('Permite reprocesar una notificación fallida mediante retryManualNotification', () async {
        // 1. Simular primera ejecución fallida
        fakeEmailClient.alwaysFail = true;
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_manual_recover',
          estadoReserva: ReservationModel.estadoConfirmada,
          contactoNombre: 'Cliente Rescatado',
          contactoCorreo: 'recover@example.com',
          restauranteId: 'rest_rescate',
          restauranteNombre: 'Restaurante Rescatado',
          fecha: '2026-11-27',
          horario: '20:00',
        );
        await service.sendNotification(payload);

        final notifId = 'notif_confirmacion_res_manual_recover';

        // 2. Ahora el servicio SMTP se recupera
        fakeEmailClient.alwaysFail = false;
        fakeEmailClient.failuresBeforeSuccess = 0;

        // 3. Ejecutar reintento manual
        final manualResult = await service.retryManualNotification(notifId);

        expect(manualResult.exitoso, isTrue);
        final docActualizado = await fakeFirestore.collection('notificaciones').doc(notifId).get();
        expect(docActualizado.data()?['estado'], 'enviada');
        expect(docActualizado.data()?['requiereReintentoManual'], isFalse);
      });
    });

    // =========================================================================
    // CRITERIO 5: Solo se dispara si la reserva quedó confirmada
    // =========================================================================
    group('Criterio 5: Validación estricta de estado confirmada', () {
      test('Rechaza el envío si la reserva está en estado pendiente', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_pendiente',
          estadoReserva: ReservationModel.estadoPendiente,
          contactoNombre: 'Usuario Pendiente',
          contactoCorreo: 'user@example.com',
          restauranteId: 'rest_pend',
          restauranteNombre: 'Restaurante Pendiente',
          fecha: '2026-11-28',
          horario: '13:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isFalse);
        expect(result.motivoRechazo, contains('no está en estado confirmada'));
        expect(result.motivoRechazo, contains('pendiente'));
        expect(fakeEmailClient.sendCalls, 0);
        expect(fakeWhatsAppClient.sendCalls, 0);

        // Asegurar que no se creó registro falso en Firestore
        final doc = await fakeFirestore
            .collection('notificaciones')
            .doc('notif_confirmacion_res_pendiente')
            .get();
        expect(doc.exists, isFalse);
      });

      test('Rechaza el envío si la reserva está en estado cancelada', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_cancelada',
          estadoReserva: ReservationModel.estadoCancelada,
          contactoNombre: 'Usuario Cancelado',
          contactoCorreo: 'user@example.com',
          restauranteId: 'rest_canc',
          restauranteNombre: 'Restaurante Cancelado',
          fecha: '2026-11-28',
          horario: '14:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isFalse);
        expect(result.motivoRechazo, contains('no está en estado confirmada'));
        expect(fakeEmailClient.sendCalls, 0);
      });

      test('Acepta el envío si el estado es confirmada (incluso con mayúsculas/espacios)', () async {
        final payload = const ReservationNotificationPayload(
          reservaId: 'res_confirmada_ok',
          estadoReserva: ' Confirmada ',
          contactoNombre: 'Usuario OK',
          contactoCorreo: 'ok@example.com',
          restauranteId: 'rest_ok',
          restauranteNombre: 'Restaurante Confirmado',
          fecha: '2026-11-28',
          horario: '15:00',
        );

        final result = await service.sendNotification(payload);

        expect(result.exitoso, isTrue);
        expect(fakeEmailClient.sendCalls, 1);
      });
    });
  });
}
