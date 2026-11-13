import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reservitta/services/notification_clients.dart';

void main() {
  group('Backend SMTP Email Client (Nodemailer)', () {
    test('Envía POST a /api/send-confirmation con token de Firebase y HTML', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({'ok': true, 'messageId': '<msg_123@gmail.com>'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = DefaultTransactionalEmailClient(
        emailBackendUrl: 'https://reservitta-email.onrender.com/',
        httpClient: mockClient,
        idTokenProvider: () async => 'fake_firebase_id_token',
      );

      final result = await client.sendEmail(
        to: 'balderasrodrigo344@gmail.com',
        subject: 'Comprobante de Reserva - Reservitta',
        body: 'Tu reserva fue confirmada.',
      );

      expect(result, isTrue);
      expect(
        capturedUri,
        equals(Uri.parse('https://reservitta-email.onrender.com/api/send-confirmation')),
      );
      expect(capturedHeaders?['authorization'], equals('Bearer fake_firebase_id_token'));
      expect(capturedHeaders?['content-type'], contains('application/json'));
      expect(capturedBody?['to'], equals('balderasrodrigo344@gmail.com'));
      expect(capturedBody?['subject'], equals('Comprobante de Reserva - Reservitta'));
      expect(capturedBody?['text'], equals('Tu reserva fue confirmada.'));
      expect(capturedBody?['html'], contains('Reservitta'));
    });

    test('Lanza excepción si el backend responde con error HTTP', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': false, 'error': 'Error al enviar correo SMTP'}),
          500,
        );
      });

      final client = DefaultTransactionalEmailClient(
        emailBackendUrl: 'https://reservitta-email.onrender.com',
        httpClient: mockClient,
        idTokenProvider: () async => 'fake_token',
      );

      expect(
        () => client.sendEmail(
          to: 'balderasrodrigo344@gmail.com',
          subject: 'Prueba',
          body: 'Contenido',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

