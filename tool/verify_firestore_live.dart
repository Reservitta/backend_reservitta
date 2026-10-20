// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Script de verificación directa de backend contra Cloud Firestore y Firebase Auth
/// Proyecto: reservitta-dev
void main() async {
  print('=================================================================');
  print(' INICIANDO VERIFICACIÓN EN VIVO CONTRA CLOUD FIRESTORE');
  print('=================================================================');

  final client = HttpClient();
  const apiKey = 'AIzaSyAuBzM8uNCeU1Twd1R3MXumreqn_7CqNT4';
  const projectId = 'reservitta-dev';
  const testEmail = 'test_backend_runner@reservitta.com';
  const testPassword = 'Password123!';
  const restaurantId = 'restaurante_prueba_backend';

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final catId = 'cat_prueba_$timestamp';
  final platilloId = 'platillo_prueba_$timestamp';

  try {
    // 1. Autenticar en Firebase Auth
    print('\n[1/5] Autenticando usuario de prueba en Firebase Auth...');
    final authUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
    );
    final authRequest = await client.postUrl(authUri);
    authRequest.headers.contentType = ContentType.json;
    authRequest.write(
      jsonEncode({
        'email': testEmail,
        'password': testPassword,
        'returnSecureToken': true,
      }),
    );
    final authResponse = await authRequest.close();
    final authBody = await authResponse.transform(utf8.decoder).join();
    final authJson = jsonDecode(authBody) as Map<String, dynamic>;

    final idToken = authJson['idToken'] as String?;
    if (idToken == null) {
      throw Exception('Fallo de autenticación: $authBody');
    }
    print(' Autenticado con éxito. Token obtenido.');

    // 2. Subir Categoría a Firestore
    print('\n[2/5] Subiendo Categoría a Firestore en subcolección:');
    print('      restaurants/$restaurantId/categorias/$catId ...');
    final catUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/restaurants/$restaurantId/categorias?documentId=$catId',
    );
    final catRequest = await client.postUrl(catUri);
    catRequest.headers.contentType = ContentType.json;
    catRequest.headers.set('Authorization', 'Bearer $idToken');
    catRequest.write(
      jsonEncode({
        'fields': {
          'nombre': {'stringValue': 'Entradas Especiales $timestamp'},
          'nombreNormalizado': {'stringValue': 'entradas especiales $timestamp'},
          'orden': {'integerValue': 1},
          'tipo': {'stringValue': 'entrada'},
        },
      }),
    );
    final catResponse = await catRequest.close();
    final catBody = await catResponse.transform(utf8.decoder).join();
    final catJson = jsonDecode(catBody) as Map<String, dynamic>;
    print(' Categoría guardada en Firestore: ${catJson['name']}');

    // 3. Subir Platillo a Firestore
    print('\n[3/5] Subiendo Platillo a Firestore en subcolección:');
    print('      restaurants/$restaurantId/platillos/$platilloId ...');
    final platUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/restaurants/$restaurantId/platillos?documentId=$platilloId',
    );
    final platRequest = await client.postUrl(platUri);
    platRequest.headers.contentType = ContentType.json;
    platRequest.headers.set('Authorization', 'Bearer $idToken');
    platRequest.write(
      jsonEncode({
        'fields': {
          'categoriaId': {'stringValue': catId},
          'nombre': {'stringValue': 'Guacamole con Totopos y Pico de Gallo'},
          'descripcion': {
            'stringValue':
                'Aguacate fresco, cebolla, cilantro, tomate y totopos crocantes',
          },
          'precio': {'doubleValue': 125.50},
          'imagenUrl': {'stringValue': 'assets/images/default_platillo.png'},
          'estado': {'stringValue': 'activo'},
          'orden': {'integerValue': 1},
          'etiquetas': {
            'arrayValue': {
              'values': [
                {'stringValue': 'vegano'},
                {'stringValue': 'para compartir'},
              ],
            },
          },
          'placeholderObservacion': {'stringValue': 'Ej. Sin cebolla'},
          'limiteCaracteresObs': {'integerValue': 150},
        },
      }),
    );
    final platResponse = await platRequest.close();
    final platBody = await platResponse.transform(utf8.decoder).join();
    final platJson = jsonDecode(platBody) as Map<String, dynamic>;
    print(' Platillo guardado en Firestore: ${platJson['name']}');

    // 4. Consultar (GET) directamente desde Firestore para verificar
    print('\n[4/5] Leyendo documentos directamente desde Firestore...');
    final getPlatUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/restaurants/$restaurantId/platillos/$platilloId',
    );
    final getRequest = await client.getUrl(getPlatUri);
    getRequest.headers.set('Authorization', 'Bearer $idToken');
    final getResponse = await getRequest.close();
    final getBody = await getResponse.transform(utf8.decoder).join();
    final getJson = jsonDecode(getBody) as Map<String, dynamic>;
    final fields = getJson['fields'] as Map<String, dynamic>;

    print(' Nombre leído:   ${fields['nombre']['stringValue']}');
    print(' Precio leído:   \$${fields['precio']['doubleValue']}');
    print(' Estado leído:   ${fields['estado']['stringValue']}');
    print(' Imagen leída:   ${fields['imagenUrl']['stringValue']}');

    // 5. Probar actualización en tiempo real (HU32-RF01: marcar agotado y nuevo precio)
    print('\n[5/5] Probando HU32-RF01: Actualizar precio (\$145.0) y estado a "agotado"...');
    final patchUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/restaurants/$restaurantId/platillos/$platilloId',
    );
    final patchRequest = await client.patchUrl(patchUri);
    patchRequest.headers.contentType = ContentType.json;
    patchRequest.headers.set('Authorization', 'Bearer $idToken');
    patchRequest.write(
      jsonEncode({
        'fields': {
          ...fields,
          'precio': {'doubleValue': 145.00},
          'estado': {'stringValue': 'agotado'},
        },
      }),
    );
    final patchResponse = await patchRequest.close();
    final patchBody = await patchResponse.transform(utf8.decoder).join();
    final patchJson = jsonDecode(patchBody) as Map<String, dynamic>;
    final patchFields = patchJson['fields'] as Map<String, dynamic>;

    print(' Nuevo precio en Firestore: \$${patchFields['precio']['doubleValue']}');
    print(' Nuevo estado en Firestore: ${patchFields['estado']['stringValue']}');

    print('\n=================================================================');
    print(' ¡VERIFICACIÓN EXITOSA! TODOS LOS DATOS SE SUBEN Y LEEN DE FIRESTORE');
    print('=================================================================');
  } catch (e) {
    print('Error en la verificación: $e');
  } finally {
    client.close();
  }
}
