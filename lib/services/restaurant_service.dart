import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch_model.dart';
import '../models/restaurant_model.dart';
import '../models/restaurant_with_distance.dart';
import '../models/service_catalog_model.dart';
import '../utils/geo_utils.dart';

/// Resultado paginado para navegación de restaurantes con scroll infinito (HU01-RF01, HU01-RF02)
class PaginatedRestaurantsResult {
  final List<RestaurantModel> restaurants;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const PaginatedRestaurantsResult({
    required this.restaurants,
    this.lastDocument,
    required this.hasMore,
  });
}

/// Excepción controlada para errores en consultas de restaurantes (HU01-RF01 Criterio 4)
class ControlledRestaurantQueryException implements Exception {
  final String message;
  final Object? originalError;

  const ControlledRestaurantQueryException(
    this.message, {
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Resultado seguro de consulta para evitar cierres o excepciones no capturadas
class RestaurantQueryResult {
  final List<RestaurantModel> restaurants;
  final String? errorMessage;
  final bool hasError;

  const RestaurantQueryResult.success(this.restaurants)
      : errorMessage = null,
        hasError = false;

  const RestaurantQueryResult.failure(this.errorMessage)
      : restaurants = const [],
        hasError = true;
}

/// Contrato del Repositorio de Restaurantes (HU01-RF01, HU02-RF02)
abstract class RestaurantRepository {
  /// Consulta de restaurantes asociados con estado 'activo' (HU01-RF01 Criterio 2)
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit});

  /// Consulta de restaurantes asociados activos retornando un resultado seguro (HU01-RF01 Criterio 4)
  Future<RestaurantQueryResult> getActiveRestaurantsResult({int? limit});

  /// Stream en tiempo real de restaurantes asociados activos
  Stream<List<RestaurantModel>> getActiveRestaurantsStream();

  /// Obtiene los datos de un restaurante por su ID
  Future<RestaurantModel?> getRestaurantById(String restaurantId);

  /// HU02-RF02: Consulta y filtra restaurantes activos dentro de un radio en km
  /// respecto a la ubicación del usuario, ordenados del más cercano al más lejano.
  /// Excluye aquellos sin coordenadas válidas.
  Future<List<RestaurantModel>> getActiveRestaurantsByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  });

  /// HU02-RF02: Versión segura que devuelve RestaurantQueryResult sin lanzar excepciones
  Future<RestaurantQueryResult> getActiveRestaurantsByRadiusResult({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  });

  /// HU02-RF02: Stream en tiempo real de restaurantes filtrados por radio y ordenados por distancia
  Stream<List<RestaurantModel>> getActiveRestaurantsByRadiusStream({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  });

  /// HU02-RF02: Retorna lista de pares RestaurantWithDistance
  Future<List<RestaurantWithDistance>> getRestaurantsWithDistanceByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  });
}

/// Servicio y Repositorio de Restaurantes (HU01-RF01, HU01-RF02, HU02-RF02)
class RestaurantService implements RestaurantRepository {
  final FirebaseFirestore? _firestoreInstance;

  RestaurantService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  static const List<Map<String, String>> defaultServicesList = [
    {'id': 'reservaciones', 'nombre': 'Reservaciones', 'icono': 'event_seat'},
    {'id': 'preorden', 'nombre': 'Preorden', 'icono': 'restaurant_menu'},
    {'id': 'estacionamiento', 'nombre': 'Estacionamiento', 'icono': 'local_parking'},
    {'id': 'acceso_discapacidad', 'nombre': 'Acceso para discapacidad', 'icono': 'accessible'},
    {'id': 'terraza', 'nombre': 'Terraza', 'icono': 'deck'},
    {'id': 'wifi', 'nombre': 'Wi-Fi', 'icono': 'wifi'},
    {'id': 'musica_en_vivo', 'nombre': 'Música en vivo', 'icono': 'music_note'},
    {'id': 'pet_friendly', 'nombre': 'Apto para mascotas', 'icono': 'pets'},
  ];

  /// Obtiene los datos de un restaurante por su ID con manejo de error controlado
  @override
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    try {
      final doc =
          await _firestore.collection('restaurants').doc(restaurantId).get();
      if (!doc.exists) return null;
      return RestaurantModel.fromFirestore(doc);
    } catch (e) {
      // HU01-RF01 Criterio 4: Error controlado sin cerrar la app
      return null;
    }
  }

  /// HU01-RF01 Criterio 2: Consulta de restaurantes asociados con estado activo.
  /// HU01-RF01 Criterio 4: Manejo controlado de fallas sin cerrar la app.
  @override
  Future<List<RestaurantModel>> getActiveRestaurants({int? limit}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('restaurants')
          .where('estado', isEqualTo: 'activo');

      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final list = snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .where((r) => r.isActivo)
          .toList();

      // Ordenar alfabéticamente por nombre para consistencia
      list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return list;
    } catch (e) {
      // HU01-RF01 Criterio 4: Si la consulta falla, el repositorio devuelve un error controlado
      throw ControlledRestaurantQueryException(
        'Error controlado al consultar restaurantes asociados activos: $e',
        originalError: e,
      );
    }
  }

  /// HU01-RF01 Criterio 4: Consulta segura que retorna RestaurantQueryResult y no cierra la app
  @override
  Future<RestaurantQueryResult> getActiveRestaurantsResult({int? limit}) async {
    try {
      final list = await getActiveRestaurants(limit: limit);
      return RestaurantQueryResult.success(list);
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
    } catch (e) {
      return RestaurantQueryResult.failure('Error inesperado al consultar restaurantes: $e');
    }
  }

  /// HU01-RF01 Criterio 2 y 4: Stream en tiempo real de restaurantes activos con manejo de error controlado
  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsStream() {
    return _firestore
        .collection('restaurants')
        .where('estado', isEqualTo: 'activo')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .where((r) => r.isActivo)
          .toList();
      list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return list;
    }).handleError((error) {
      // HU01-RF01 Criterio 4: Error controlado en el stream sin cerrar la app
      return <RestaurantModel>[];
    });
  }

  /// HU02-RF02: Consulta y filtra restaurantes activos dentro de un radio en km.
  /// - Calcula distancia por Haversine (Criterio 1).
  /// - Filtra por radio (Criterio 2).
  /// - Ordena del más cercano al más lejano (Criterio 3).
  /// - Excluye restaurantes sin coordenadas válidas (Criterio 4).
  @override
  Future<List<RestaurantModel>> getActiveRestaurantsByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    try {
      if (radiusKm <= 0) {
        throw ArgumentError('El radio de búsqueda debe ser mayor a 0 km.');
      }
      if (!GeoUtils.isValidCoordinate(userLatitude, userLongitude)) {
        throw ArgumentError(
          'Coordenadas de usuario inválidas: ($userLatitude, $userLongitude)',
        );
      }

      final activeList = await getActiveRestaurants();

      return GeoUtils.filterAndSortByDistance(
        restaurants: activeList,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radiusKm: radiusKm,
      );
    } catch (e) {
      if (e is ControlledRestaurantQueryException) rethrow;
      throw ControlledRestaurantQueryException(
        'Error controlado al consultar restaurantes por radio: $e',
        originalError: e,
      );
    }
  }

  /// HU02-RF02: Consulta segura por radio retornando RestaurantQueryResult
  @override
  Future<RestaurantQueryResult> getActiveRestaurantsByRadiusResult({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    try {
      final list = await getActiveRestaurantsByRadius(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radiusKm: radiusKm,
      );
      return RestaurantQueryResult.success(list);
    } on ControlledRestaurantQueryException catch (e) {
      return RestaurantQueryResult.failure(e.message);
    } catch (e) {
      return RestaurantQueryResult.failure(
        'Error inesperado al filtrar restaurantes por radio: $e',
      );
    }
  }

  /// HU02-RF02: Stream en tiempo real de restaurantes filtrados por radio
  @override
  Stream<List<RestaurantModel>> getActiveRestaurantsByRadiusStream({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) {
    return getActiveRestaurantsStream().map((restaurants) {
      if (!GeoUtils.isValidCoordinate(userLatitude, userLongitude) ||
          radiusKm <= 0) {
        return <RestaurantModel>[];
      }
      return GeoUtils.filterAndSortByDistance(
        restaurants: restaurants,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radiusKm: radiusKm,
      );
    }).handleError((_) {
      return <RestaurantModel>[];
    });
  }

  /// HU02-RF02: Retorna lista de pares RestaurantWithDistance
  @override
  Future<List<RestaurantWithDistance>> getRestaurantsWithDistanceByRadius({
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) async {
    final list = await getActiveRestaurantsByRadius(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      radiusKm: radiusKm,
    );

    return list
        .map((r) => RestaurantWithDistance(
              restaurant: r,
              distanceKm: r.distanciaKm ?? 0.0,
            ))
        .toList();
  }

  /// Stream de todos los restaurantes (para dashboard de administrador)
  Stream<List<RestaurantModel>> getRestaurantsStream() {
    return _firestore.collection('restaurants').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RestaurantModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// Consulta paginada de restaurantes activos para la interfaz pública (HU01-RF01 Criterios 2, 3, 5)
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('restaurants')
          .where('estado', isEqualTo: 'activo');

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      query = query.limit(limit + 1);

      final snapshot = await query.get();
      final docs = snapshot.docs;

      final bool hasMore = docs.length > limit;
      final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

      List<RestaurantModel> items = pageDocs.map((doc) {
        return RestaurantModel.fromFirestore(doc);
      }).toList();

      if (servicioId != null && servicioId.isNotEmpty) {
        items = items.where((r) => r.serviciosIds.contains(servicioId)).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final queryClean = searchQuery.trim().toLowerCase();
        items = items.where((r) {
          final nombreMatch = r.nombre.toLowerCase().contains(queryClean);
          final descMatch = r.descripcion.toLowerCase().contains(queryClean);
          final dirMatch = r.direccion.toLowerCase().contains(queryClean);
          return nombreMatch || descMatch || dirMatch;
        }).toList();
      }

      return PaginatedRestaurantsResult(
        restaurants: items,
        lastDocument: pageDocs.isNotEmpty ? pageDocs.last : null,
        hasMore: hasMore,
      );
    } catch (e) {
      // HU01-RF01 Criterio 5: Retorno con error controlado sin cerrar la app
      throw Exception('No fue posible consultar los restaurantes disponibles. Por favor, reintenta.');
    }
  }

  /// Guarda el perfil completo del restaurante junto con su sucursal principal y sucursales adicionales
  Future<void> saveFullRestaurantProfile({
    required String restaurantId,
    required RestaurantModel restaurant,
    required BranchModel mainBranch,
    required List<BranchModel> additionalBranches,
  }) async {
    final restaurantRef = _firestore.collection('restaurants').doc(restaurantId);

    // 1. Actualizar el documento del restaurante con respaldo de sucursales en la raíz
    final restaurantData = restaurant.toMap();
    restaurantData['perfilCompleto'] = true;
    restaurantData['estado'] = 'activo';
    restaurantData['sucursalPrincipal'] = {
      'nombre': mainBranch.nombre.isNotEmpty ? mainBranch.nombre : 'Sucursal Principal',
      'direccion': restaurant.direccion,
      'telefono': restaurant.telefono,
      'esPrincipal': true,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    restaurantData['sucursalesAdicionales'] =
        additionalBranches.map((b) => b.toMap()).toList();

    // Guardar el documento del restaurante primero
    await restaurantRef.set(restaurantData, SetOptions(merge: true));

    // 2. Guardar en la subcolección 'sucursales' (protegido ante falta de reglas en consola remota)
    try {
      final batch = _firestore.batch();
      final mainBranchRef = restaurantRef.collection('sucursales').doc('principal');
      batch.set(mainBranchRef, {
        'nombre': mainBranch.nombre.isNotEmpty ? mainBranch.nombre : 'Sucursal Principal',
        'direccion': restaurant.direccion,
        'telefono': restaurant.telefono,
        'esPrincipal': true,
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final branch in additionalBranches) {
        final branchRef = branch.id.isNotEmpty
            ? restaurantRef.collection('sucursales').doc(branch.id)
            : restaurantRef.collection('sucursales').doc();
        batch.set(branchRef, {
          'nombre': branch.nombre,
          'direccion': branch.direccion,
          'telefono': branch.telefono,
          'esPrincipal': false,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (_) {
      // Si la consola de Firebase aún no tiene desplegadas las reglas para la subcolección sucursales,
      // la información ya quedó guardada e íntegra en el documento principal del restaurante.
    }
  }

  /// Obtiene las sucursales de un restaurante de forma segura
  Future<List<BranchModel>> getBranches(String restaurantId) async {
    try {
      final snap = await _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('sucursales')
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => BranchModel.fromFirestore(d)).toList();
      }
    } catch (_) {}

    // Fallback: leer del documento raíz si la subcolección no tiene reglas aún en consola
    try {
      final doc =
          await _firestore.collection('restaurants').doc(restaurantId).get();
      final data = doc.data() ?? {};
      final list = <BranchModel>[];
      if (data['sucursalPrincipal'] is Map<String, dynamic>) {
        list.add(BranchModel.fromMap(
          'principal',
          data['sucursalPrincipal'] as Map<String, dynamic>,
        ));
      }
      if (data['sucursalesAdicionales'] is List) {
        for (final item in data['sucursalesAdicionales'] as List) {
          if (item is Map<String, dynamic>) {
            list.add(BranchModel.fromMap(
              item['id'] as String? ?? '',
              item,
            ));
          }
        }
      }
      if (list.isNotEmpty) return list;
    } catch (_) {}

    return [];
  }

  /// Stream en tiempo real de sucursales de un restaurante
  Stream<List<BranchModel>> getBranchesStream(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('sucursales')
        .snapshots()
        .map((snap) => snap.docs.map((d) => BranchModel.fromFirestore(d)).toList());
  }

  /// Agrega una sucursal adicional
  Future<String> addBranch(String restaurantId, BranchModel branch) async {
    final ref = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('sucursales')
        .doc();

    await ref.set({
      'nombre': branch.nombre,
      'direccion': branch.direccion,
      'telefono': branch.telefono,
      'esPrincipal': false,
      'creadoEn': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Actualiza una sucursal adicional
  Future<void> updateBranch(String restaurantId, BranchModel branch) async {
    if (branch.esPrincipal) {
      throw Exception('La sucursal principal no se puede editar directamente desde aquí.');
    }
    final ref = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('sucursales')
        .doc(branch.id);

    await ref.update({
      'nombre': branch.nombre,
      'direccion': branch.direccion,
      'telefono': branch.telefono,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina una sucursal adicional (la principal está protegida)
  Future<void> deleteBranch(String restaurantId, String branchId) async {
    if (branchId == 'principal') {
      throw Exception('No es posible eliminar la sucursal principal.');
    }
    await _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('sucursales')
        .doc(branchId)
        .delete();
  }

  /// Obtiene el catálogo predefinido de servicios (con fallback robusto en memoria)
  Future<List<ServiceCatalogModel>> getServicesCatalog() async {
    try {
      final snap = await _firestore.collection('serviciosCatalogo').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => ServiceCatalogModel.fromFirestore(d))
            .toList();
      }
    } catch (_) {
      // Si falla por permisos o colección inexistente en consola remota, usar catálogo base
    }

    return defaultServicesList.map((item) {
      return ServiceCatalogModel(
        id: item['id']!,
        nombre: item['nombre']!,
        icono: item['icono']!,
        activo: true,
      );
    }).toList();
  }
}
