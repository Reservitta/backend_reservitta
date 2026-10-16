import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/categoria_model.dart';
import '../utils/validators.dart';

class CategoriaService {
  final FirebaseFirestore? _firestoreInstance;

  CategoriaService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _getCategoriasRef(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('categorias');
  }

  CollectionReference<Map<String, dynamic>> _getPlatillosRef(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('platillos');
  }

  /// 1. Stream de categorías ordenadas ascendentemente por el campo 'orden'
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) {
    return _getCategoriasRef(restaurantId)
        .orderBy('orden', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CategoriaModel.fromFirestore(doc))
          .toList();
    });
  }

  /// 2. Valida si ya existe una categoría con el mismo nombre normalizado en el restaurante
  Future<bool> existeNombreCategoria({
    required String restaurantId,
    required String nombre,
    String? excludeCategoriaId,
  }) async {
    final String normalizado = CategoriaModel.normalizarNombre(nombre);
    final query = await _getCategoriasRef(restaurantId)
        .where('nombreNormalizado', isEqualTo: normalizado)
        .get();

    for (final doc in query.docs) {
      if (excludeCategoriaId == null || doc.id != excludeCategoriaId) {
        return true;
      }
    }
    return false;
  }

  /// 3. Crea una categoría validando no vacía y sin duplicados
  Future<String> crearCategoria({
    required String restaurantId,
    required String nombre,
    String tipo = 'general',
    int? orden,
  }) async {
    final validacion = AppValidators.validateCategoryName(nombre);
    if (validacion != null) {
      throw ArgumentError(validacion);
    }

    final yaExiste = await existeNombreCategoria(
      restaurantId: restaurantId,
      nombre: nombre,
    );
    if (yaExiste) {
      throw Exception('Ya existe una categoría con este nombre en tu restaurante.');
    }

    int nuevoOrden = orden ?? 0;
    if (orden == null) {
      final snapshot = await _getCategoriasRef(restaurantId)
          .orderBy('orden', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final maxOrden = (snapshot.docs.first.data()['orden'] as num?)?.toInt() ?? 0;
        nuevoOrden = maxOrden + 1;
      } else {
        nuevoOrden = 1;
      }
    }

    final docRef = await _getCategoriasRef(restaurantId).add({
      'nombre': nombre.trim(),
      'nombreNormalizado': CategoriaModel.normalizarNombre(nombre),
      'orden': nuevoOrden,
      'tipo': tipo,
    });

    return docRef.id;
  }

  /// 4. Actualiza nombre y tipo de una categoría validando no duplicados
  Future<void> actualizarCategoria({
    required String restaurantId,
    required String categoriaId,
    required String nuevoNombre,
    String? nuevoTipo,
  }) async {
    final validacion = AppValidators.validateCategoryName(nuevoNombre);
    if (validacion != null) {
      throw ArgumentError(validacion);
    }

    final yaExiste = await existeNombreCategoria(
      restaurantId: restaurantId,
      nombre: nuevoNombre,
      excludeCategoriaId: categoriaId,
    );
    if (yaExiste) {
      throw Exception('Ya existe una categoría con este nombre en tu restaurante.');
    }

    final data = <String, dynamic>{
      'nombre': nuevoNombre.trim(),
      'nombreNormalizado': CategoriaModel.normalizarNombre(nuevoNombre),
    };
    if (nuevoTipo != null) {
      data['tipo'] = nuevoTipo;
    }

    await _getCategoriasRef(restaurantId).doc(categoriaId).update(data);
  }

  /// 5. Reordena una lista completa de categorías mediante un lote atómico (WriteBatch)
  Future<void> reordenarCategorias({
    required String restaurantId,
    required List<CategoriaModel> categoriasOrdenadas,
  }) async {
    final batch = _firestore.batch();
    for (int i = 0; i < categoriasOrdenadas.length; i++) {
      final cat = categoriasOrdenadas[i];
      final docRef = _getCategoriasRef(restaurantId).doc(cat.id);
      batch.update(docRef, {'orden': i + 1});
    }
    await batch.commit();
  }

  /// 6. Cuenta cuántos platillos están asociados a una categoría (para confirmación de borrado)
  Future<int> contarPlatillosAsociados({
    required String restaurantId,
    required String categoriaId,
  }) async {
    final categoriaRef = _getCategoriasRef(restaurantId).doc(categoriaId);

    // Consulta por DocumentReference (esquema oficial)
    final snapRef = await _getPlatillosRef(restaurantId)
        .where('categoriaId', isEqualTo: categoriaRef)
        .count()
        .get();

    final int countRef = snapRef.count ?? 0;
    if (countRef > 0) return countRef;

    // Consulta por String ID (compatibilidad)
    final snapId = await _getPlatillosRef(restaurantId)
        .where('categoriaId', isEqualTo: categoriaId)
        .count()
        .get();

    return snapId.count ?? 0;
  }

  /// 7. Elimina la categoría de Firestore
  Future<void> eliminarCategoria({
    required String restaurantId,
    required String categoriaId,
  }) async {
    await _getCategoriasRef(restaurantId).doc(categoriaId).delete();
  }
}

