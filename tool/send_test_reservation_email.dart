// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  print('=================================================================');
  print(' PRUEBA EN VIVO: ENVÍO DE CONFIRMACIÓN DE RESERVACIÓN POR CORREO');
  print('=================================================================\n');

  // 1. Leer API Key del archivo .env
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ Error: No se encontró el archivo .env en la raíz.');
    return;
  }

  String apiKey = '';
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('RESEND_API_KEY=')) {
      apiKey = trimmed.substring('RESEND_API_KEY='.length).trim();
      break;
    }
  }

  if (apiKey.isEmpty || apiKey.startsWith('re_tu_')) {
    print('❌ Error: No se encontró una clave válida de RESEND_API_KEY en .env');
    return;
  }

  print('✅ Clave de Resend detectada: ${apiKey.substring(0, 7)}...');

  const destinatario = 'leyotorres1501@gmail.com';
  const remitente = 'Reservitta <onboarding@resend.dev>';
  const subject = '¡Tu reserva en La Trattoria Bella está confirmada!';

  final bodyTexto = '''
¡Hola, Leyo Torres! Tu reserva en La Trattoria Bella ha sido confirmada con éxito.

Detalles de tu visita:
- Restaurante: La Trattoria Bella
- Sucursal: Providencia
- Fecha: Viernes, 14 de Noviembre de 2026
- Horario: 20:00 – 21:30
- Duración: 90 minutos
- Personas: 2
- Mesa(s): Mesa 4 (Terraza)
- Código de reservación: RES-78921

Resumen de tu preorden:
  • 1x Pizza Napolitana Artesanal (\$210.00)
  • 1x Pasta Carbonara Tradicional (\$195.00)
  • 1x Tiramisú della Casa (\$110.00)

Celebración: Cena Especial
  • Nota: Celebración en pareja

Alergias reportadas: Ninguna

¡Te esperamos! Si necesitas modificar tu visita o tienes dudas, ponte en contacto con nosotros.
'''.trim();

  // Construir HTML con el diseño oficial de Reservitta (Terracota #B34A26 y Crema #FAF6F0)
  final bodyHtml = '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>$subject</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #FAF6F0; margin: 0; padding: 24px; color: #2E241E;">
  <div style="max-width: 580px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #EDE4D8; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
    
    <!-- Encabezado Terracota -->
    <div style="background-color: #B34A26; padding: 28px 24px; text-align: center; color: #ffffff;">
      <h1 style="margin: 0; font-size: 26px; font-weight: bold; letter-spacing: 0.5px;">Reservitta</h1>
      <p style="margin: 6px 0 0 0; font-size: 14px; opacity: 0.95;">Confirmación de Reserva</p>
    </div>

    <!-- Cuerpo del mensaje -->
    <div style="padding: 28px; line-height: 1.6; font-size: 14px; color: #2E241E;">
      <h2 style="color: #2E241E; font-size: 18px; margin-top: 0;">¡Hola, Leyo Torres! 👋</h2>
      <p style="font-size: 15px; margin-bottom: 20px;">Tu reserva en <strong>La Trattoria Bella</strong> ha sido confirmada con éxito.</p>
      
      <!-- Tarjeta de Detalles -->
      <div style="background-color: #FAF6F0; border-radius: 12px; padding: 18px; border: 1px solid #EDE4D8; margin-bottom: 22px;">
        <p style="margin: 0 0 10px 0; font-weight: bold; color: #B34A26; font-size: 15px;">📍 Detalles de tu visita</p>
        <p style="margin: 4px 0;"><strong>Restaurante:</strong> La Trattoria Bella</p>
        <p style="margin: 4px 0;"><strong>Sucursal:</strong> Providencia</p>
        <p style="margin: 4px 0;"><strong>Fecha:</strong> Viernes, 14 de Noviembre de 2026</p>
        <p style="margin: 4px 0;"><strong>Horario:</strong> 20:00 – 21:30 (90 minutos)</p>
        <p style="margin: 4px 0;"><strong>Personas:</strong> 2 comensales</p>
        <p style="margin: 4px 0;"><strong>Mesa(s):</strong> Mesa 4 (Terraza)</p>
        <p style="margin: 4px 0;"><strong>Código de reserva:</strong> <span style="background-color: #EDE4D8; padding: 2px 8px; border-radius: 6px; font-weight: bold; font-family: monospace;">RES-78921</span></p>
      </div>

      <!-- Preorden -->
      <div style="background-color: #FAF6F0; border-radius: 12px; padding: 18px; border: 1px solid #EDE4D8; margin-bottom: 22px;">
        <p style="margin: 0 0 10px 0; font-weight: bold; color: #B34A26; font-size: 15px;">🍕 Resumen de tu preorden de alimentos</p>
        <ul style="margin: 0; padding-left: 20px;">
          <li style="margin: 4px 0;">1x Pizza Napolitana Artesanal (\$210.00)</li>
          <li style="margin: 4px 0;">1x Pasta Carbonara Tradicional (\$195.00)</li>
          <li style="margin: 4px 0;">1x Tiramisú della Casa (\$110.00)</li>
        </ul>
        <p style="margin: 10px 0 0 0; font-weight: bold; text-align: right; color: #2E241E;">Total Preorden: \$515.00 MXN</p>
      </div>

      <!-- Ocasión Especial -->
      <div style="background-color: #FAF6F0; border-radius: 12px; padding: 18px; border: 1px solid #EDE4D8; margin-bottom: 22px;">
        <p style="margin: 0 0 10px 0; font-weight: bold; color: #B34A26; font-size: 15px;">🎉 Ocasión especial</p>
        <p style="margin: 4px 0;"><strong>Motivo:</strong> Cena Especial en pareja</p>
        <p style="margin: 4px 0;"><strong>Alergias / Restricciones:</strong> Ninguna</p>
      </div>

      <p style="margin-top: 24px; font-size: 14px; color: #7A6E65;">
        ¡Te esperamos con entusiasmo! Si necesitas modificar tu visita o tienes dudas, puedes consultar tu reserva directamente en la aplicación.
      </p>
    </div>

    <!-- Pie de página -->
    <div style="background-color: #FAF6F0; padding: 18px 24px; text-align: center; border-top: 1px solid #EDE4D8; font-size: 12px; color: #7A6E65;">
      <p style="margin: 0;">Gracias por confiar en <strong>Reservitta</strong>.</p>
      <p style="margin: 4px 0 0 0;">Este es un correo transaccional generado automáticamente.</p>
    </div>
  </div>
</body>
</html>
''';

  print('📡 Conectando con los servidores de Resend...');
  print('   Destinatario: $destinatario');
  print('   Remitente:    $remitente');

  final client = HttpClient();
  try {
    final uri = Uri.parse('https://api.resend.com/emails');
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.add('Authorization', 'Bearer $apiKey');

    final payload = {
      'from': remitente,
      'to': [destinatario],
      'subject': subject,
      'text': bodyTexto,
      'html': bodyHtml,
    };

    request.write(jsonEncode(payload));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    print('\n-----------------------------------------------------------------');
    print('RESULTADO DE LA RESPUESTA DE RESEND:');
    print('Código HTTP: ${response.statusCode}');
    print('Respuesta:   $responseBody');
    print('-----------------------------------------------------------------\n');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      final emailId = jsonResponse['id'] ?? '';
      print('🎉 ¡CORREO ENVIADO CON ÉXITO A $destinatario!');
      print('🆔 Email ID en Resend: $emailId');
      print('📬 Por favor revisa tu bandeja de entrada (o carpeta de Promociones/Spam) en $destinatario');
    } else {
      print('❌ Falló el envío. Error reportado por Resend:');
      print(responseBody);
    }
  } catch (e) {
    print('❌ Error de conexión: $e');
  } finally {
    client.close();
  }
}
