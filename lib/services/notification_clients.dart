import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ============================================================================
/// CONFIGURACIÓN DE ENVÍO DE CORREO TRANSACCIONAL
/// ============================================================================
/// URL del microservicio de correo (Nodemailer + Gmail SMTP en Render / local).
/// Configúrala en `.env` (EMAIL_BACKEND_URL=https://...) o mediante
/// `--dart-define=EMAIL_BACKEND_URL=https://...`.
String get kEmailBackendUrl {
  const dartDefineUrl = String.fromEnvironment('EMAIL_BACKEND_URL');
  if (dartDefineUrl.isNotEmpty) return dartDefineUrl.trim();

  try {
    if (dotenv.isInitialized) {
      final envUrl = (dotenv.env['EMAIL_BACKEND_URL'] ?? '').trim();
      if (envUrl.isNotEmpty) return envUrl;
    }
  } catch (_) {}

  return '';
}

/// Resend API Key (respaldo nativo opcional si no se usa [kEmailBackendUrl]).
String get kResendApiKey {
  // 1. Intenta leer de --dart-define en tiempo de compilación
  const dartDefineKey = String.fromEnvironment('RESEND_API_KEY');
  if (dartDefineKey.isNotEmpty) return dartDefineKey;

  // 2. Si no está en dart-define, intenta leer del archivo .env (en ejecución)
  try {
    if (dotenv.isInitialized) {
      final envKey = dotenv.env['RESEND_API_KEY'] ?? '';
      if (envKey.isNotEmpty) return envKey;
    }
  } catch (_) {}

  
  return '';
}

/// Remitente predeterminado de prueba de Resend.
const String kResendDefaultSender = 'Reservitta <onboarding@resend.dev>';

/// Contrato para clientes de correo electrónico transaccional (HU14-RF03 Criterio 2).
abstract class TransactionalEmailClient {
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  });
}

/// Contrato para clientes de WhatsApp Business API (HU14-RF03 Criterio 2).
abstract class WhatsAppBusinessApiClient {
  Future<bool> sendWhatsAppMessage({
    required String toPhone,
    required String message,
  });
}

/// Implementación de cliente de correo transaccional.
/// Prioriza el backend HTTP propio (Nodemailer + Gmail SMTP) cuando [emailBackendUrl]
/// está configurado, evitando problemas de CORS en Web y exposición de secretos.
class DefaultTransactionalEmailClient implements TransactionalEmailClient {
  final String emailBackendUrl;
  final String apiKey;
  final String senderEmail;
  final FirebaseFirestore? firestore;
  final String mailCollection;
  final http.Client? _customHttpClient;
  final Future<String?> Function()? _idTokenProvider;

  DefaultTransactionalEmailClient({
    String? emailBackendUrl,
    String? apiKey,
    String? senderEmail,
    this.firestore,
    this.mailCollection = 'mail',
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
  })  : emailBackendUrl = (emailBackendUrl ?? kEmailBackendUrl).trim(),
        apiKey = (apiKey ??
                (const String.fromEnvironment('RESEND_API_KEY').isNotEmpty
                    ? const String.fromEnvironment('RESEND_API_KEY')
                    : (const String.fromEnvironment('EMAIL_SERVICE_KEY').isNotEmpty
                        ? const String.fromEnvironment('EMAIL_SERVICE_KEY')
                        : kResendApiKey)))
            .trim(),
        senderEmail = senderEmail ?? kResendDefaultSender,
        _customHttpClient = httpClient,
        _idTokenProvider = idTokenProvider;

  Future<String?> _resolveFirebaseIdToken() async {
    if (_idTokenProvider != null) {
      return await _idTokenProvider();
    }
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    final cleanTo = to.trim().toLowerCase();
    if (cleanTo.isEmpty || !cleanTo.contains('@')) {
      throw const FormatException('Dirección de correo electrónico inválida.');
    }

    // -------------------------------------------------------------------------
    // 1. Envío mediante Backend SMTP propio (Web + Móvil, sin CORS ni secretos)
    // -------------------------------------------------------------------------
    if (emailBackendUrl.isNotEmpty) {
      final base = emailBackendUrl.endsWith('/')
          ? emailBackendUrl.substring(0, emailBackendUrl.length - 1)
          : emailBackendUrl;
      final uri = Uri.parse('$base/api/send-confirmation');
      final client = _customHttpClient ?? http.Client();
      try {
        final idToken = await _resolveFirebaseIdToken();
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (idToken != null && idToken.isNotEmpty)
            'Authorization': 'Bearer $idToken',
        };

        debugPrint('[EmailClient] Despachando correo vía Backend SMTP a: $cleanTo');
        final response = await client
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'to': cleanTo,
                'subject': subject,
                'text': body,
                'html': _buildHtmlMessage(subject, body),
              }),
            )
            .timeout(const Duration(seconds: 45));

        debugPrint('[EmailClient] Respuesta Backend SMTP (HTTP ${response.statusCode}): ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }

        throw Exception(
          'Error al enviar correo (Status ${response.statusCode}): ${response.body}',
        );
      } finally {
        if (_customHttpClient == null) {
          client.close();
        }
      }
    }

    // -------------------------------------------------------------------------
    // 2. Respaldo directo con Resend API (solo en plataformas nativas sin CORS)
    // -------------------------------------------------------------------------
    if (!kIsWeb && apiKey.isNotEmpty) {
      final client = _customHttpClient ?? http.Client();
      try {
        debugPrint('[EmailClient] Despachando correo vía Resend API a: $cleanTo');
        final uri = Uri.parse('https://api.resend.com/emails');
        final response = await client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'from': senderEmail,
            'to': [cleanTo],
            'subject': subject,
            'text': body,
            'html': _buildHtmlMessage(subject, body),
          }),
        );

        debugPrint('[EmailClient] Respuesta de Resend (HTTP ${response.statusCode}): ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }

        throw Exception(
          'Error al enviar correo con Resend (Status ${response.statusCode}): ${response.body}',
        );
      } finally {
        if (_customHttpClient == null) {
          client.close();
        }
      }
    }

    // -------------------------------------------------------------------------
    // 3. Respaldo vía Firestore si fue configurado
    // -------------------------------------------------------------------------
    if (firestore != null) {
      try {
        await firestore!.collection(mailCollection).add({
          'to': [cleanTo],
          'message': {
            'subject': subject,
            'text': body,
            'html': _buildHtmlMessage(subject, body),
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (_) {}
    }

    // En compilación release (Web o nativo) no debemos fingir éxito si falta configurar el servicio.
    if (kReleaseMode) {
      throw StateError(
        kIsWeb
            ? 'EMAIL_BACKEND_URL no está configurada en esta compilación Web (--dart-define=EMAIL_BACKEND_URL=...).'
            : 'EMAIL_BACKEND_URL o RESEND_API_KEY no están configuradas en esta compilación.',
      );
    }

    // Modo simulado / sandbox solo para desarrollo/pruebas cuando no hay backend ni API Key
    return true;
  }

  /// Construye una plantilla HTML responsive con los colores institucionales de Reservitta
  String _buildHtmlMessage(String subject, String body) {
    final lines = body.split('\n');
    final formattedBody = lines.map((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return '<br/>';
      if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        return '<p style="margin: 4px 0 4px 16px; color: #2E241E;">$trimmed</p>';
      }
      if (trimmed.endsWith(':')) {
        return '<p style="margin: 14px 0 4px 0; font-weight: bold; color: #B34A26;">$trimmed</p>';
      }
      return '<p style="margin: 6px 0; color: #2E241E;">$trimmed</p>';
    }).join('');

    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$subject</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #FAF6F0; margin: 0; padding: 24px; color: #2E241E;">
  <div style="max-width: 580px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #EDE4D8; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
    <div style="background-color: #B34A26; padding: 24px; text-align: center; color: #ffffff;">
      <h1 style="margin: 0; font-size: 24px; font-weight: bold; letter-spacing: 0.5px;">Reservitta</h1>
      <p style="margin: 4px 0 0 0; font-size: 13px; opacity: 0.9;">Confirmación de Reserva</p>
    </div>
    <div style="padding: 24px 28px; line-height: 1.6; font-size: 14px;">
      $formattedBody
    </div>
    <div style="background-color: #FAF6F0; padding: 16px 24px; text-align: center; border-top: 1px solid #EDE4D8; font-size: 12px; color: #7A6E65;">
      <p style="margin: 0;">Gracias por reservar con <strong>Reservitta</strong>.</p>
      <p style="margin: 4px 0 0 0;">Si necesitas consultar o gestionar tu reserva, ingresa a la aplicación.</p>
    </div>
  </div>
</body>
</html>
''';
  }
}

/// Implementación predeterminada de WhatsApp Business API (Meta Cloud API).
class DefaultWhatsAppBusinessApiClient implements WhatsAppBusinessApiClient {
  final String accessToken;
  final String phoneNumberId;
  final http.Client? _customHttpClient;

  DefaultWhatsAppBusinessApiClient({
    String? accessToken,
    String? phoneNumberId,
    http.Client? httpClient,
  })  : accessToken = accessToken ??
            (const String.fromEnvironment('WHATSAPP_TOKEN').isNotEmpty
                ? const String.fromEnvironment('WHATSAPP_TOKEN')
                : (_getEnvSafely('WHATSAPP_TOKEN'))),
        phoneNumberId = phoneNumberId ??
            (const String.fromEnvironment('WHATSAPP_PHONE_ID').isNotEmpty
                ? const String.fromEnvironment('WHATSAPP_PHONE_ID')
                : (_getEnvSafely('WHATSAPP_PHONE_ID'))),
        _customHttpClient = httpClient;

  @override
  Future<bool> sendWhatsAppMessage({
    required String toPhone,
    required String message,
  }) async {
    final cleanPhone = toPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      throw const FormatException('Número telefónico inválido para WhatsApp (requiere al menos 10 dígitos).');
    }

    // Modo simulado / sandbox seguro si no hay token configurado
    if (accessToken.isEmpty || phoneNumberId.isEmpty) {
      return true;
    }

    final client = _customHttpClient ?? http.Client();
    try {
      final uri = Uri.parse('https://graph.facebook.com/v19.0/$phoneNumberId/messages');
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'to': cleanPhone,
          'type': 'text',
          'text': {'body': message},
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      throw Exception('Error de WhatsApp Business API (Status ${response.statusCode}): ${response.body}');
    } finally {
      if (_customHttpClient == null) {
        client.close();
      }
    }
  }
}

/// Función auxiliar segura para leer variables de dotenv sin romper si no está inicializado
String _getEnvSafely(String key) {
  try {
    return dotenv.env[key] ?? '';
  } catch (_) {
    return '';
  }
}