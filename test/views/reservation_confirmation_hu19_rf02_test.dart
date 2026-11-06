import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/notification_delivery_result.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/reservation_notification_payload.dart';
import 'package:reservitta/views/reservation_confirmation_view.dart';

void main() {
  final reservaTest = ReservationModel.create(
    id: 'res_abc123',
    restauranteId: 'rest_001',
    restauranteNombre: 'Miel Aurum',
    fechaLocal: '2026-11-20',
    inicio: DateTime(2026, 11, 20, 14, 0),
    duracionMin: 90,
    personas: 4,
    mesaIds: const ['mesa_1', 'mesa_2'],
    mesasNombres: const ['Mesa Terraza 1', 'Mesa Terraza 2'],
    usuarioId: 'usr_gael',
    contactoNombre: 'Gael Quevedo',
    contactoCorreo: 'gaelq1074@gmail.com',
    contactoTelefono: '4181517764',
    estado: 'confirmada',
  );

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('HU19-RF02 Criterio 1: Pantalla de éxito con datos y canal de confirmación', () {
    testWidgets('Muestra datos de la reserva y canal correo electrónico cuando el envío es exitoso',
        (tester) async {
      setScreenSize(tester);

      final deliverySuccessEmail = NotificationDeliveryResult.success(
        notificacionId: 'notif_1',
        canal: ReservationNotificationPayload.canalEmail,
        destino: 'gaelq1074@gmail.com',
        intentos: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(
            reservation: reservaTest,
            notificationResult: deliverySuccessEmail,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pantalla de confirmación y título
      expect(find.text('¡Reserva confirmada!'), findsOneWidget);
      expect(find.text('Te esperamos. Estos son los datos de tu visita.'), findsOneWidget);

      // Banner de entrega exitosa
      expect(find.byKey(const ValueKey('notification_delivery_banner')), findsOneWidget);
      expect(
        find.text('Confirmación enviada por correo a gaelq1074@gmail.com'),
        findsOneWidget,
      );
      expect(find.text('Canal: correo electrónico'), findsOneWidget);

      // Detalles de la reserva
      expect(find.byKey(const ValueKey('confirmation_details')), findsOneWidget);
      expect(find.text('Miel Aurum'), findsOneWidget);
      expect(find.text('14:00 – 15:30'), findsOneWidget);
      expect(find.text('1 h 30 min'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Mesa Terraza 1 + Mesa Terraza 2'), findsOneWidget);
      expect(find.text('Gael Quevedo'), findsOneWidget);
      expect(find.text('gaelq1074@gmail.com'), findsOneWidget);
      expect(find.textContaining('gaelq1074@gmail.com'), findsNWidgets(2)); // En banner y en detalles
      expect(find.text('4181517764'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.text('res_abc123'), findsOneWidget);
      expect(find.text('Canal de confirmación'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);

      // Botón para volver al inicio
      expect(find.byKey(const ValueKey('btn_confirmation_done')), findsOneWidget);
    });

    testWidgets('Muestra datos de la reserva y canal WhatsApp cuando el envío es por WhatsApp',
        (tester) async {
      setScreenSize(tester);

      final deliverySuccessWhatsApp = NotificationDeliveryResult.success(
        notificacionId: 'notif_2',
        canal: ReservationNotificationPayload.canalWhatsApp,
        destino: '4181517764',
        intentos: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(
            reservation: reservaTest,
            notificationResult: deliverySuccessWhatsApp,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notification_delivery_banner')), findsOneWidget);
      expect(
        find.text('Confirmación enviada por WhatsApp al 4181517764'),
        findsOneWidget,
      );
      expect(find.text('Canal: WhatsApp'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget); // En detalles
      expect(find.textContaining('WhatsApp'), findsNWidgets(3)); // En banner, badge y detalles
    });
  });

  group('HU19-RF02 Criterio 2: Envío fallido muestra pantalla de confirmación informando falla', () {
    testWidgets('Si el envío falla, la pantalla de confirmación igual se muestra con advertencia y opción de reenviar',
        (tester) async {
      setScreenSize(tester);

      final deliveryFailed = NotificationDeliveryResult.failed(
        notificacionId: 'notif_fail_1',
        canal: ReservationNotificationPayload.canalEmail,
        destino: 'gaelq1074@gmail.com',
        intentos: 3,
        error: 'Servidor SMTP no respondió',
        requiereReintentoManual: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(
            reservation: reservaTest,
            notificationResult: deliveryFailed,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // La reserva ya existe: el título de éxito y los datos siguen presentes
      expect(find.text('¡Reserva confirmada!'), findsOneWidget);
      expect(find.byKey(const ValueKey('confirmation_details')), findsOneWidget);
      expect(find.text('res_abc123'), findsOneWidget);

      // Se muestra el banner de fallo informando que la reserva existe pero el comprobante no pudo enviarse
      expect(find.byKey(const ValueKey('notification_failure_banner')), findsOneWidget);
      expect(
        find.text('La reserva ya existe, pero el comprobante no pudo enviarse.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Tu reserva está asegurada en el restaurante'),
        findsOneWidget,
      );
      expect(
        find.textContaining('no se pudo enviar el comprobante a gaelq1074@gmail.com por correo electrónico'),
        findsOneWidget,
      );

      // Ofrece opción de reenviar manualmente
      expect(find.byKey(const ValueKey('btn_reenviar_confirmacion')), findsOneWidget);
      expect(find.text('Reenviar confirmación'), findsOneWidget);
    });
  });

  group('HU19-RF02 Criterio 3: Botón para reenviar confirmación manualmente', () {
    testWidgets('Pulsar Reenviar confirmación ejecuta el reenvío manual y actualiza a estado exitoso',
        (tester) async {
      setScreenSize(tester);

      final deliveryFailed = NotificationDeliveryResult.failed(
        notificacionId: 'notif_fail_1',
        canal: ReservationNotificationPayload.canalEmail,
        destino: 'gaelq1074@gmail.com',
        intentos: 3,
        error: 'Timeout',
      );

      int resendCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(
            reservation: reservaTest,
            notificationResult: deliveryFailed,
            onResend: (reserva) async {
              resendCalls++;
              return NotificationDeliveryResult.success(
                notificacionId: 'notif_manual_1',
                canal: ReservationNotificationPayload.canalEmail,
                destino: reserva.contactoCorreo,
                intentos: 1,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente en fallo
      expect(find.byKey(const ValueKey('notification_failure_banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('notification_delivery_banner')), findsNothing);

      // Pulsa botón de reenvío
      await tester.tap(find.byKey(const ValueKey('btn_reenviar_confirmacion')));
      await tester.pumpAndSettle();

      expect(resendCalls, equals(1));

      // La UI se actualiza con el banner exitoso
      expect(find.byKey(const ValueKey('notification_failure_banner')), findsNothing);
      expect(find.byKey(const ValueKey('notification_delivery_banner')), findsOneWidget);
      expect(
        find.text('Confirmación enviada por correo a gaelq1074@gmail.com'),
        findsOneWidget,
      );

      // Muestra SnackBar de éxito
      expect(find.byKey(const ValueKey('snackbar_reenvio_exitoso')), findsOneWidget);
      expect(
        find.textContaining('Comprobante reenviado con éxito por correo electrónico'),
        findsOneWidget,
      );
    });

    testWidgets('Si el reenvío manual falla, conserva el banner de reintento y muestra SnackBar de error',
        (tester) async {
      setScreenSize(tester);

      final deliveryFailed = NotificationDeliveryResult.failed(
        notificacionId: 'notif_fail_1',
        canal: ReservationNotificationPayload.canalWhatsApp,
        destino: '4181517764',
        intentos: 3,
        error: 'Error de red',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(
            reservation: reservaTest,
            notificationResult: deliveryFailed,
            onResend: (reserva) async {
              return NotificationDeliveryResult.failed(
                notificacionId: 'notif_manual_fail',
                canal: ReservationNotificationPayload.canalWhatsApp,
                destino: reserva.contactoTelefono,
                intentos: 1,
                error: 'Sin saldo de mensajería',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notification_failure_banner')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('btn_reenviar_confirmacion')));
      await tester.pumpAndSettle();

      // Sigue mostrando el banner de fallo
      expect(find.byKey(const ValueKey('notification_failure_banner')), findsOneWidget);
      // Muestra SnackBar informando que no se pudo enviar y que puede intentar de nuevo
      expect(find.byKey(const ValueKey('snackbar_reenvio_fallido')), findsOneWidget);
      expect(find.textContaining('No se pudo enviar el comprobante'), findsOneWidget);
    });

    testWidgets('En entrega exitosa, el botón Reenviar comprobante también está disponible y funcional',
        (tester) async {
      setScreenSize(tester);

      final deliverySuccess = NotificationDeliveryResult.success(
        notificacionId: 'notif_ok',
        canal: ReservationNotificationPayload.canalEmail,
        destino: 'gaelq1074@gmail.com',
        intentos: 1,
      );

      int resendCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(
            reservation: reservaTest,
            notificationResult: deliverySuccess,
            onResend: (reserva) async {
              resendCalls++;
              return NotificationDeliveryResult.success(
                notificacionId: 'notif_reok',
                canal: ReservationNotificationPayload.canalEmail,
                destino: reserva.contactoCorreo,
                intentos: 1,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('btn_reenviar_confirmacion')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('btn_reenviar_confirmacion')));
      await tester.pumpAndSettle();

      expect(resendCalls, equals(1));
      expect(find.byKey(const ValueKey('snackbar_reenvio_exitoso')), findsOneWidget);
    });

    testWidgets('Botón Volver al inicio invoca callback onDone', (tester) async {
      setScreenSize(tester);
      bool onDoneCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(
            reservation: reservaTest,
            onDone: () => onDoneCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('btn_confirmation_done')));
      await tester.pumpAndSettle();

      expect(onDoneCalled, isTrue);
    });
  });
}
