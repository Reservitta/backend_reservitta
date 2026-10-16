import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/platillo_model.dart';
import '../utils/validators.dart';
import 'storage_service.dart';

class PlatilloService {
  final FirebaseFirestore? _firestoreInstance;
  final StorageService? _storageServiceInstance;

  PlatilloService({
    FirebaseFirestore? firestore,
    StorageService? storageService,
  })  : _firestoreInstance = firestore,
        _storageServiceInstance = storageService;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;
  StorageService get _storageService =>
      _storageServiceInstance ?? StorageService();

  CollectionReference<Map<String, dynamic>> _getPlatillosRef(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('platillos');
  }

  /// 1. Stream de platillos ACTIVOS para visitantes (Criterio HU06 y HU32-RF01)
  /// Solo recupera platillos con estado == 'activo'
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) {
    return _getPlatillosRef(restaurantId)
        .where('estado', isEqualTo: PlatilloModel.estadoActivo)
        .snapshots()
        .map((snapshot) {
      final platillos = snapshot.docs
          .map((doc) => PlatilloModel.fromFirestore(doc))
          .toList();
      platillos.sort((a, b) => a.orden.compareTo(b.orden));
      return platillos;
    });
  }

  /// 2. Stream de TODOS los platillos para el administrador (activos, agotados e inactivos)
  /// Se propaga en tiempo real ante cualquier cambio en Firestore (HU32-RF01)
  Stream<List<PlatilloModel>> getAllPlatillosStream(String restaurantId) {
    return _getPlatillosRef(restaurantId)
        .snapshots()
        .map((snapshot) {
      final platillos = snapshot.docs
          .map((doc) => PlatilloModel.fromFirestore(doc))
          .toList();
      platillos.sort((a, b) => a.orden.compareTo(b.orden));
      return platillos;
    });
  }

  /// 3. Stream de platillos filtrados por categoría en tiempo real
  Stream<List<PlatilloModel>> getPlatillosPorCategoriaStream(
    String restaurantId,
    String categoriaId, {
    bool soloActivos = false,
  }) {
    Query<Map<String, dynamic>> query = _getPlatillosRef(restaurantId);

    if (soloActivos) {
      query = query.where('estado', isEqualTo: PlatilloModel.estadoActivo);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PlatilloModel.fromFirestore(doc))
          .where((p) => p.categoriaId == categoriaId)
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
    });
  }

  /// 4. Obtener un platillo por ID (para histórico de reservas pasadas)
  /// Aunque esté agotado o inactivo, la reserva puede consultar el catálogo si lo requiere
  Future<PlatilloModel?> getPlatilloById(String restaurantId, String platilloId) async {
    final doc = await _getPlatillosRef(restaurantId).doc(platilloId).get();
    if (!doc.exists) return null;
    return PlatilloModel.fromFirestore(doc);
  }

  /// 5. Cambiar disponibilidad: 'activo', 'agotado' o 'inactivo' (HU06 y HU32-RF01)
  /// No elimina el platillo del catálogo ni altera las reservaciones ya confirmadas
  Future<void> toggleEstadoPlatillo({
    required String restaurantId,
    required String platilloId,
    required String nuevoEstado,
  }) async {
    if (!PlatilloModel.estadosValidos.contains(nuevoEstado)) {
      throw ArgumentError(
        'Estado inválido "$nuevoEstado". Estados permitidos: ${PlatilloModel.estadosValidos.join(", ")}.',
      );
    }
    await _getPlatillosRef(restaurantId).doc(platilloId).update({
      'estado': nuevoEstado,
    });
  }

  /// 6. Crear un nuevo platillo con validación de precio y soporte de imagen
  Future<String> crearPlatillo({
    required String restaurantId,
    required PlatilloModel platillo,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final nombreErr = AppValidators.validateDishName(platillo.nombre);
    if (nombreErr != null) throw ArgumentError(nombreErr);

    final precioErr = AppValidators.validatePrice(platillo.precio.toString());
    if (precioErr != null) throw ArgumentError(precioErr);

    String urlImagen = platillo.imagenUrl;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      urlImagen = await _storageService.uploadRestaurantImage(
        restaurantId: restaurantId,
        folder: 'platillos',
        imageBytes: imageBytes,
        fileExtension: imageExtension ?? 'jpg',
      );
    } else if (urlImagen.trim().isEmpty) {
      urlImagen = PlatilloModel.imagenPorDefecto;
    }

    final data = platillo.copyWith(imagenUrl: urlImagen).toMap();
    final docRef = await _getPlatillosRef(restaurantId).add(data);
    return docRef.id;
  }

  /// 7. Actualizar un platillo en tiempo real (precio, descripción, imagen, disponibilidad)
  /// Los cambios impactan la colección de platillos sin tocar reservaciones ya confirmadas
  Future<void> actualizarPlatillo({
    required String restaurantId,
    required PlatilloModel platillo,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final nombreErr = AppValidators.validateDishName(platillo.nombre);
    if (nombreErr != null) throw ArgumentError(nombreErr);

    final precioErr = AppValidators.validatePrice(platillo.precio.toString());
    if (precioErr != null) throw ArgumentError(precioErr);

    if (!PlatilloModel.estadosValidos.contains(platillo.estado)) {
      throw ArgumentError('El estado de disponibilidad no es válido.');
    }

    String urlImagen = platillo.imagenUrl;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      urlImagen = await _storageService.uploadRestaurantImage(
        restaurantId: restaurantId,
        folder: 'platillos',
        imageBytes: imageBytes,
        fileExtension: imageExtension ?? 'jpg',
      );
    }

    final data = platillo.copyWith(imagenUrl: urlImagen).toMap();
    await _getPlatillosRef(restaurantId).doc(platillo.id).update(data);
  }

  /// 8. Eliminar platillo definitivamente
  Future<void> eliminarPlatillo(String restaurantId, String platilloId) async {
    await _getPlatillosRef(restaurantId).doc(platilloId).delete();
  }
}
