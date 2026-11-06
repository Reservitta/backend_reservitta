import 'dart:convert';
import 'dart:io';

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

/// Implementación predeterminada de cliente de correo transaccional.
///
/// Soporta configuración mediante variables de entorno (`EMAIL_SERVICE_KEY`),
/// o modo de simulación/sandbox si no hay proveedor configurado aún en desarrollo.
class DefaultTransactionalEmailClient implements TransactionalEmailClient {
  final String apiKey;
  final String senderEmail;
  final HttpClient? _customHttpClient;

  DefaultTransactionalEmailClient({
    this.apiKey = const String.fromEnvironment('EMAIL_SERVICE_KEY', defaultValue: ''),
    this.senderEmail = 'confirmaciones@reservitta.com',
    HttpClient? httpClient,
  }) : _customHttpClient = httpClient;

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

    // Modo simulado / sandbox si no hay API Key de producción configurada
    if (apiKey.isEmpty) {
      return true;
    }

    final client = _customHttpClient ?? HttpClient();
    try {
      final uri = Uri.parse('https://api.reservitta.com/v1/emails/send');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.add('Authorization', 'Bearer $apiKey');
      request.write(
        jsonEncode({
          'from': senderEmail,
          'to': cleanTo,
          'subject': subject,
          'text': body,
        }),
      );
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      throw HttpException('Error del proveedor de correo (Status ${response.statusCode})');
    } finally {
      if (_customHttpClient == null) {
        client.close();
      }
    }
  }
}

/// Implementación predeterminada de WhatsApp Business API (Meta Cloud API).
///
/// Las credenciales se inyectan en el constructor o provienen de variables de entorno:
/// - `WHATSAPP_TOKEN`: Token de acceso de Meta Graph API.
/// - `WHATSAPP_PHONE_ID`: Identificador del número de teléfono en WhatsApp Business.
///
/// Si no se proporcionan credenciales (entorno de pruebas o desarrollo local),
/// funciona en modo sandbox simulando el envío con éxito sin exponer credenciales en el código.
class DefaultWhatsAppBusinessApiClient implements WhatsAppBusinessApiClient {
  final String accessToken;
  final String phoneNumberId;
  final HttpClient? _customHttpClient;

  DefaultWhatsAppBusinessApiClient({
    this.accessToken = const String.fromEnvironment('WHATSAPP_TOKEN', defaultValue: ''),
    this.phoneNumberId = const String.fromEnvironment('WHATSAPP_PHONE_ID', defaultValue: ''),
    HttpClient? httpClient,
  }) : _customHttpClient = httpClient;

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

    final client = _customHttpClient ?? HttpClient();
    try {
      final uri = Uri.parse('https://graph.facebook.com/v19.0/$phoneNumberId/messages');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.add('Authorization', 'Bearer $accessToken');
      request.write(
        jsonEncode({
          'messaging_product': 'whatsapp',
          'recipient_type': 'individual',
          'to': cleanPhone,
          'type': 'text',
          'text': {'preview_url': false, 'body': message},
        }),
      );
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      throw HttpException('Error de WhatsApp Business API (Status ${response.statusCode})');
    } finally {
      if (_customHttpClient == null) {
        client.close();
      }
    }
  }
}

