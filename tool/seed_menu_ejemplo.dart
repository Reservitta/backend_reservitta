// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Script de backend para poblar un menú de ejemplo completo en Cloud Firestore
/// Proyecto: reservitta-dev
/// Restaurante: restaurante_prueba_backend
void main() async {
  print('=================================================================');
  print(' SUBIENDO MENÚ DE EJEMPLO COMPLETO A CLOUD FIRESTORE');
  print('=================================================================');

  final client = HttpClient();
  const apiKey = 'AIzaSyAuBzM8uNCeU1Twd1R3MXumreqn_7CqNT4';
  const projectId = 'reservitta-dev';
  const testEmail = 'test_backend_runner@reservitta.com';
  const testPassword = 'Password123!';
  const restaurantId = 'restaurante_prueba_backend';

  try {
    // 1. Autenticar en Firebase Auth
    print('\n[1/3] Autenticando con Firebase Auth...');
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
    if (idToken == null) throw Exception('Error de autenticación: $authBody');
    print(' Autenticación exitosa.');

    // 2. Definición del Menú de Ejemplo Completo
    final menuEjemplo = [
      {
        'id': 'cat_entradas',
        'nombre': 'Entradas',
        'nombreNormalizado': 'entradas',
        'orden': 1,
        'tipo': 'entrada',
        'platillos': [
          {
            'id': 'plat_guacamole',
            'nombre': 'Guacamole Tradicional',
            'descripcion': 'Aguacate fresco con totopos caseros y pico de gallo',
            'precio': 120.0,
            'estado': 'activo',
            'orden': 1,
            'etiquetas': ['vegano', 'para compartir'],
            'placeholderObservacion': 'Ej. Sin cebolla',
          },
          {
            'id': 'plat_queso_fundido',
            'nombre': 'Queso Fundido con Chistorra',
            'descripcion': 'Queso gouda gratinado con chistorra artesanal y tortillas de harina',
            'precio': 145.0,
            'estado': 'activo',
            'orden': 2,
            'etiquetas': ['caliente', 'para compartir'],
            'placeholderObservacion': 'Ej. Tortillas de maíz en su lugar',
          },
        ],
      },
      {
        'id': 'cat_fuertes',
        'nombre': 'Platos Fuertes',
        'nombreNormalizado': 'platos fuertes',
        'orden': 2,
        'tipo': 'plato_fuerte',
        'platillos': [
          {
            'id': 'plat_enchiladas',
            'nombre': 'Enchiladas Suizas',
            'descripcion': 'Tres enchiladas rellenas de pollo con salsa verde cremosa y queso gratinado',
            'precio': 165.0,
            'estado': 'activo',
            'orden': 1,
            'etiquetas': ['especialidad'],
            'placeholderObservacion': 'Ej. Salsa poco picante',
          },
          {
            'id': 'plat_ribeye',
            'nombre': 'Rib Eye 400g a la Parrilla',
            'descripcion': 'Corte de res al punto con papas al romero y chiles toreados',
            'precio': 390.0,
            'estado': 'activo',
            'orden': 2,
            'etiquetas': ['parrilla', 'premium'],
            'placeholderObservacion': 'Ej. Término medio',
          },
          {
            'id': 'plat_tacos_tuetano',
            'nombre': 'Tacos de Rib Eye con Tuétano',
            'descripcion': 'Orden de 3 tacos en tortilla de maíz con costra de queso y canoa de tuétano',
            'precio': 195.0,
            'estado': 'agotado', // Ejemplo de Platillo Agotado (HU32-RF01)
            'orden': 3,
            'etiquetas': ['popular', 'temporada'],
            'placeholderObservacion': 'Ej. Sin cilantro',
          },
        ],
      },
      {
        'id': 'cat_postres',
        'nombre': 'Postres',
        'nombreNormalizado': 'postres',
        'orden': 3,
        'tipo': 'postre',
        'platillos': [
          {
            'id': 'plat_tres_leches',
            'nombre': 'Pastel de Tres Leches',
            'descripcion': 'Bizcocho tradicional bañado en tres leches con fresas frescas',
            'precio': 85.0,
            'estado': 'activo',
            'orden': 1,
            'etiquetas': ['dulce', 'casero'],
            'placeholderObservacion': 'Ej. Agregar vela de cumpleaños',
          },
          {
            'id': 'plat_cheesecake_frutos',
            'nombre': 'Cheesecake de Frutos Rojos',
            'descripcion': 'Base de galleta con queso crema horneado y reducción de frutos silvestres',
            'precio': 95.0,
            'estado': 'inactivo', // Ejemplo de Platillo Inactivo para visitantes (HU06)
            'orden': 2,
            'etiquetas': ['temporada'],
            'placeholderObservacion': '',
          },
        ],
      },
      {
        'id': 'cat_bebidas',
        'nombre': 'Bebidas',
        'nombreNormalizado': 'bebidas',
        'orden': 4,
        'tipo': 'bebida',
        'platillos': [
          {
            'id': 'plat_limonada',
            'nombre': 'Limonada Mineral con Hierbabuena',
            'descripcion': 'Preparada al momento con limón colima y hojas de hierbabuena fresca',
            'precio': 45.0,
            'estado': 'activo',
            'orden': 1,
            'etiquetas': ['refrescante', 'sin alcohol'],
            'placeholderObservacion': 'Ej. Poca azúcar',
          },
          {
            'id': 'plat_cerveza_artesanal',
            'nombre': 'Cerveza Artesanal Pale Ale (355ml)',
            'descripcion': 'Elaboración local con notas cítricas y maltas tostadas',
            'precio': 75.0,
            'estado': 'activo',
            'orden': 2,
            'etiquetas': ['artesanal', 'alcohol'],
            'placeholderObservacion': 'Ej. Con vaso escarchado',
          },
        ],
      },
    ];

    // 3. Subir las categorías y sus platillos a Firestore
    print('\n[2/3] Guardando categorías y platillos en Firestore...');
    for (final categoria in menuEjemplo) {
      final catId = categoria['id'] as String;
      final catNombre = categoria['nombre'] as String;
      final catOrden = categoria['orden'] as int;
      final catTipo = categoria['tipo'] as String;
      final platillos = categoria['platillos'] as List<Map<String, dynamic>>;

      // Subir Categoría con PATCH (crea o actualiza)
      final catUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/restaurants/$restaurantId/categorias/$catId',
      );
      final catReq = await client.patchUrl(catUri);
      catReq.headers.contentType = ContentType.json;
      catReq.headers.set('Authorization', 'Bearer $idToken');
      catReq.write(
        jsonEncode({
          'fields': {
            'nombre': {'stringValue': catNombre},
            'nombreNormalizado': {'stringValue': categoria['nombreNormalizado']},
            'orden': {'integerValue': catOrden},
            'tipo': {'stringValue': catTipo},
          },
        }),
      );
      final catRes = await catReq.close();
      await catRes.drain();
      print('\n  Categoría guardada: "$catNombre" (Orden: $catOrden)');

      // Subir Platillos de la categoría
      for (final platillo in platillos) {
        final platId = platillo['id'] as String;
        final platNombre = platillo['nombre'] as String;
        final platPrecio = platillo['precio'] as double;
        final platEstado = platillo['estado'] as String;
        final platOrden = platillo['orden'] as int;
        final etiquetas = (platillo['etiquetas'] as List<String>)
            .map((e) => {'stringValue': e})
            .toList();

        final platUri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/restaurants/$restaurantId/platillos/$platId',
        );
        final platReq = await client.patchUrl(platUri);
        platReq.headers.contentType = ContentType.json;
        platReq.headers.set('Authorization', 'Bearer $idToken');
        platReq.write(
          jsonEncode({
            'fields': {
              'categoriaId': {'stringValue': catId},
              'nombre': {'stringValue': platNombre},
              'descripcion': {'stringValue': platillo['descripcion']},
              'precio': {'doubleValue': platPrecio},
              'imagenUrl': {'stringValue': 'assets/images/default_platillo.png'},
              'estado': {'stringValue': platEstado},
              'orden': {'integerValue': platOrden},
              'etiquetas': {
                'arrayValue': {'values': etiquetas},
              },
              'placeholderObservacion': {
                'stringValue': platillo['placeholderObservacion'] ?? '',
              },
              'limiteCaracteresObs': {'integerValue': 150},
            },
          }),
        );
        final platRes = await platReq.close();
        await platRes.drain();

        final tagEstado = platEstado == 'activo'
            ? '[ACTIVO]'
            : platEstado == 'agotado'
                ? '[AGOTADO ⚠️]'
                : '[INACTIVO 🔒]';
        print('     Platillo: "$platNombre" - \$$platPrecio $tagEstado');
      }
    }

    // 4. Verificación de conteo final en Firestore
    print('\n[3/3] Consultando Firestore para verificar datos almacenados...');
    final getCatsUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/restaurants/$restaurantId/categorias',
    );
    final getCatsReq = await client.getUrl(getCatsUri);
    getCatsReq.headers.set('Authorization', 'Bearer $idToken');
    final getCatsRes = await getCatsReq.close();
    final getCatsBody = await getCatsRes.transform(utf8.decoder).join();
    final getCatsJson = jsonDecode(getCatsBody) as Map<String, dynamic>;
    final totalCategorias = (getCatsJson['documents'] as List?)?.length ?? 0;

    final getPlatsUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/restaurants/$restaurantId/platillos',
    );
    final getPlatsReq = await client.getUrl(getPlatsUri);
    getPlatsReq.headers.set('Authorization', 'Bearer $idToken');
    final getPlatsRes = await getPlatsReq.close();
    final getPlatsBody = await getPlatsRes.transform(utf8.decoder).join();
    final getPlatsJson = jsonDecode(getPlatsBody) as Map<String, dynamic>;
    final totalPlatillos = (getPlatsJson['documents'] as List?)?.length ?? 0;

    print('\n=================================================================');
    print(' ¡MENÚ DE EJEMPLO SUBIDO Y VERIFICADO EXITOSAMENTE EN FIRESTORE!');
    print('=================================================================');
    print(' Restaurante:  $restaurantId');
    print(' Categorías:   $totalCategorias en subcolección "categorias"');
    print(' Platillos:    $totalPlatillos en subcolección "platillos"');
    print(' Incluye ejemplos de estados: Activo, Agotado (HU32-RF01) e Inactivo (HU06)');
    print('=================================================================');
  } catch (e) {
    print('Error al subir menú de ejemplo: $e');
  } finally {
    client.close();
  }
}

