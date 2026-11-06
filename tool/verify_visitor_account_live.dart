// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Script de verificación en vivo de creación de cuenta de visitante (HU14-RF02)
/// Proyecto: reservitta-dev
///
/// Ejecución:
///   dart run tool/verify_visitor_account_live.dart
///   o pasando correo personalizado:
///   dart run tool/verify_visitor_account_live.dart mi_correo@ejemplo.com
void main(List<String> args) async {
  print('=================================================================');
  print(' HU14-RF02: CREACIÓN Y ASOCIACIÓN DE CUENTA DE VISITANTE (EN VIVO)');
  print(' Proyecto Firebase: reservitta-dev');
  print('=================================================================\n');

  final client = HttpClient();
  const apiKey = 'AIzaSyAuBzM8uNCeU1Twd1R3MXumreqn_7CqNT4';
  const projectId = 'reservitta-dev';

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final email = args.isNotEmpty ? args[0] : 'visitante_$timestamp@reservitta.com';
  const password = 'Password123!';
  const nombre = 'Alejandro Morales Demo';
  const telefono = '5511223344';

  try {
    // -------------------------------------------------------------
    // CRITERIO 1: Crear usuario en el proveedor de autenticación
    // -------------------------------------------------------------
    print('[PASO 1/3] Creando usuario en Firebase Authentication...');
    print('          Correo: $email');
    print('          Contraseña: $password');

    final signUpUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );
    final signUpReq = await client.postUrl(signUpUri);
    signUpReq.headers.contentType = ContentType.json;
    signUpReq.write(
      jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final signUpRes = await signUpReq.close();
    final signUpBody = await signUpRes.transform(utf8.decoder).join();
    final signUpJson = jsonDecode(signUpBody) as Map<String, dynamic>;

    if (signUpRes.statusCode != 200) {
      final errorMsg = signUpJson['error']?['message'] ?? signUpBody;
      throw Exception('Fallo al crear usuario en Authentication: $errorMsg');
    }

    final uid = signUpJson['localId'] as String;
    final idToken = signUpJson['idToken'] as String;
    print('          -> Usuario creado con éxito en Authentication!');
    print('          -> UID generado: $uid');

    // -------------------------------------------------------------
    // CRITERIO 1 (Continuación): Crear documento de perfil en Firestore
    // -------------------------------------------------------------
    print('\n[PASO 2/3] Creando documento de usuario en Firestore (users/$uid)...');
    final userDocUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$uid',
    );
    final userDocReq = await client.patchUrl(userDocUri);
    userDocReq.headers.contentType = ContentType.json;
    userDocReq.headers.add('Authorization', 'Bearer $idToken');
    userDocReq.write(
      jsonEncode({
        'fields': {
          'uid': {'stringValue': uid},
          'nombre': {'stringValue': nombre},
          'correo': {'stringValue': email},
          'telefono': {'stringValue': telefono},
          'rol': {'stringValue': 'visitante'},
          'canalPreferido': {'stringValue': 'email'},
          'fechaAlta': {
            'timestampValue': DateTime.now().toUtc().toIso8601String(),
          },
        },
      }),
    );
    final userDocRes = await userDocReq.close();
    final userDocBody = await userDocRes.transform(utf8.decoder).join();

    if (userDocRes.statusCode != 200) {
      throw Exception('Error al escribir en Firestore (users): $userDocBody');
    }
    print('          -> Documento creado en Firestore: users/$uid con rol "visitante".');

    // -------------------------------------------------------------
    // CRITERIO 2: Asociar usuarioId a la reservación en curso
    // -------------------------------------------------------------
    print('\n[PASO 3/3] Creando reservación vinculada a la cuenta (reservations)...');
    final reservationId = 'res_demo_$timestamp';
    final resDocUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/reservations/$reservationId',
    );
    final resDocReq = await client.patchUrl(resDocUri);
    resDocReq.headers.contentType = ContentType.json;
    resDocReq.headers.add('Authorization', 'Bearer $idToken');
    resDocReq.write(
      jsonEncode({
        'fields': {
          'id': {'stringValue': reservationId},
          'restauranteId': {'stringValue': 'rest_bistro_cdmx'},
          'usuarioId': {'stringValue': uid}, // <- Vinculado al UID recién creado
          'contactoNombre': {'stringValue': nombre},
          'contactoCorreo': {'stringValue': email},
          'contactoTelefono': {'stringValue': telefono},
          'fechaLocal': {'stringValue': DateTime.now().toIso8601String().substring(0, 10)},
          'duracionMin': {'integerValue': '90'},
          'personas': {'integerValue': '2'},
          'mesaIds': {
            'arrayValue': {
              'values': [
                {'stringValue': 'mesa_01'}
              ]
            }
          },
          'estado': {'stringValue': 'pendiente'},
        },
      }),
    );
    final resDocRes = await resDocReq.close();
    final resDocBody = await resDocRes.transform(utf8.decoder).join();

    if (resDocRes.statusCode != 200) {
      throw Exception('Error al escribir en Firestore (reservations): $resDocBody');
    }
    print('          -> Reservación creada: reservations/$reservationId');
    print('          -> usuarioId asociado: $uid');

    // -------------------------------------------------------------
    // RESUMEN PARA EL USUARIO
    // -------------------------------------------------------------
    print('\n=================================================================');
    print(' VERIFICACIÓN EXITOSA');
    print('=================================================================');
    print('Ya puedes abrir la consola de Firebase (proyecto: reservitta-dev) y revisar:');
    print('1. Authentication > pestaña Users:');
    print('   - Identificador: $email');
    print('   - UID: $uid');
    print('2. Firestore Database > colección users:');
    print('   - Documento: users/$uid');
    print('3. Firestore Database > colección reservations:');
    print('   - Documento: reservations/$reservationId (campo usuarioId = "$uid")');
    print('=================================================================\n');
  } catch (e) {
    print('\n[ERROR] Ocurrió una falla durante la verificación: $e');
  } finally {
    client.close();
  }
}

