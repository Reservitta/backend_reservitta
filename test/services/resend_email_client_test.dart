import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reservitta/services/notification_clients.dart';

void main() {
  group('Resend API Email Client', () {
    test('Envía correo a https://api.resend.com/emails cuando apiKey está presente', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({'id': 're_test_email_id_123'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final emailClient = DefaultTransactionalEmailClient(
        apiKey: 're_test_key_12345',
        httpClient: mockClient,
      );

      final success = await emailClient.sendEmail(
        to: 'gaelq1074@gmail.com',
        subject: '¡Reserva confirmada en Miel Aurum!',
        body: 'Hola Gael, tu mesa está lista.',
      );

      expect(success, isTrue);
      expect(capturedUri, equals(Uri.parse('https://api.resend.com/emails')));
      expect(capturedHeaders?['authorization'], equals('Bearer re_test_key_12345'));
      expect(capturedHeaders?['content-type'], contains('application/json'));
      expect(capturedBody?['to'], equals(['gaelq1074@gmail.com']));
      expect(capturedBody?['from'], equals('Reservitta <onboarding@resend.dev>'));
      expect(capturedBody?['subject'], equals('¡Reserva confirmada en Miel Aurum!'));
      expect(capturedBody?['text'], equals('Hola Gael, tu mesa está lista.'));
      expect(capturedBody?['html'], contains('Reservitta'));
    });

    test('Lanza excepción si Resend responde con error (status >= 400)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'statusCode': 401, 'message': 'API key inválida'}),
          401,
        );
      });

      final emailClient = DefaultTransactionalEmailClient(
        apiKey: 're_invalid_key',
        httpClient: mockClient,
      );

      expect(
        () => emailClient.sendEmail(
          to: 'gaelq1074@gmail.com',
          subject: 'Test',
          body: 'Test',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Funciona en modo sandbox cuando apiKey está vacía', () async {
      final emailClient = DefaultTransactionalEmailClient(apiKey: '');

      final result = await emailClient.sendEmail(
        to: 'gaelq1074@gmail.com',
        subject: 'Sandbox Test',
        body: 'Sandbox',
      );

      expect(result, isTrue);
    });

    test('Lanza FormatException si el correo es inválido', () async {
      final emailClient = DefaultTransactionalEmailClient();

      expect(
        () => emailClient.sendEmail(
          to: 'correo-invalido-sin-arroba',
          subject: 'Test',
          body: 'Test',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

