import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch_model.dart';
import '../models/restaurant_model.dart';
import '../models/service_catalog_model.dart';

class RestaurantService {
  final FirebaseFirestore _firestore;

  RestaurantService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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

  /// Obtiene los datos de un restaurante por su ID
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    try {
      final doc =
          await _firestore.collection('restaurants').doc(restaurantId).get();
      if (!doc.exists) return null;
      return RestaurantModel.fromFirestore(doc);
    } catch (e) {
      // Re-throw para ser manejado por el ViewModel si es crítico
      rethrow;
    }
  }

  /// Stream de todos los restaurantes (para listados públicos o dashboard)
  Stream<List<RestaurantModel>> getRestaurantsStream() {
    return _firestore.collection('restaurants').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RestaurantModel.fromFirestore(doc);
      }).toList();
    });
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
