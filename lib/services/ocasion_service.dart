import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experiencia_model.dart';
import '../models/ocasion_model.dart';

/// Servicio de gestión de Ocasiones Especiales y Experiencias
/// Implementa HU33-RF01 y HU33-RF02 (Administración) y soporte para HU18-RF01 (Consulta).
class OcasionService {
  final FirebaseFirestore? _firestoreInstance;

  OcasionService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _getOcasionesRef(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('ocasiones');
  }

  /// Valida los datos requeridos para la creación o edición de una ocasión y sus experiencias (HU33-RF01 y HU33-RF02)
  static void validarOcasion({
    required String restaurantId,
    required String nombre,
    required List<ExperienciaModel> experiencias,
  }) {
    if (restaurantId.trim().isEmpty) {
      throw ArgumentError('El ID del restaurante del administrador es obligatorio.');
    }

    if (nombre.trim().isEmpty) {
      throw ArgumentError('El nombre de la ocasión especial es obligatorio.');
    }

    if (experiencias.isEmpty) {
      throw ArgumentError('Debes agregar al menos una experiencia para guardar la ocasión especial.');
    }

    for (int i = 0; i < experiencias.length; i++) {
      final exp = experiencias[i];
      if (exp.nombre.trim().isEmpty) {
        throw ArgumentError('El nombre de la experiencia #${i + 1} es obligatorio.');
      }
      if (exp.precio < 0) {
        throw ArgumentError('El precio de la experiencia "${exp.nombre}" no puede ser negativo.');
      }
    }
  }

  /// Guarda una nueva ocasión especial con sus experiencias asociadas al restaurante del administrador (HU33-RF01 Criterios 1 a 7)
  Future<String> crearOcasion({
    required String restaurantId,
    required String nombre,
    String? tipoPredefinido,
    String descripcion = '',
    String? icono,
    required List<ExperienciaModel> experiencias,
  }) async {
    // 1. Validaciones obligatorias de negocio (Criterios 1, 2, 4)
    validarOcasion(
      restaurantId: restaurantId,
      nombre: nombre,
      experiencias: experiencias,
    );

    final ocasionesRef = _getOcasionesRef(restaurantId);
    final ocasionDocRef = ocasionesRef.doc();
    final ocasionId = ocasionDocRef.id;

    final tipoFinal = tipoPredefinido ??
        (OcasionModel.nombresPredefinidos.contains(nombre) ? nombre : 'Otro');
    final iconoFinal = icono ?? OcasionModel.iconoPorNombre(tipoFinal);

    // 2. Procesar experiencias garantizando que si precio <= 0 se marque como Gratis (Criterio 3)
    final experienciasProcesadas = <ExperienciaModel>[];
    for (int i = 0; i < experiencias.length; i++) {
      final exp = experiencias[i];
      final expId = exp.id.isNotEmpty ? exp.id : '${ocasionId}_exp_${i + 1}';
      final esGratisCalculado = exp.precio <= 0.0;
      final procesada = exp.copyWith(
        id: expId,
        esGratis: esGratisCalculado,
        orden: exp.orden > 0 ? exp.orden : i + 1,
      );
      experienciasProcesadas.add(procesada);
    }

    // 3. Crear modelo de ocasión
    final nuevaOcasion = OcasionModel(
      id: ocasionId,
      restaurantId: restaurantId,
      nombre: nombre.trim(),
      tipoPredefinido: tipoFinal,
      descripcion: descripcion.trim(),
      icono: iconoFinal,
      activo: true,
      experiencias: experienciasProcesadas,
    );

    // 4. Guardar documento principal con resumen de experiencias embebidas para consulta inmediata (Criterio 5 y 7)
    final batch = _firestore.batch();
    batch.set(ocasionDocRef, nuevaOcasion.toMap());

    // 5. Guardar también en la subcolección de experiencias para consultas relacionales detalladas
    final experienciasRef = ocasionDocRef.collection('experiencias');
    for (final exp in experienciasProcesadas) {
      final expDoc = experienciasRef.doc(exp.id);
      batch.set(expDoc, exp.toMap());
    }

    await batch.commit();
    return ocasionId;
  }

  /// Actualiza una ocasión especial existente y sus experiencias (HU33-RF02 Criterios 1, 2 y 5).
  /// Permite editar nombre, ícono, descripción y precio/gratuidad de las experiencias.
  Future<void> actualizarOcasion({
    required String restaurantId,
    required String ocasionId,
    required String nombre,
    String? tipoPredefinido,
    String descripcion = '',
    String? icono,
    required List<ExperienciaModel> experiencias,
  }) async {
    validarOcasion(
      restaurantId: restaurantId,
      nombre: nombre,
      experiencias: experiencias,
    );

    final ocasionesRef = _getOcasionesRef(restaurantId);
    final ocasionDocRef = ocasionesRef.doc(ocasionId);

    final tipoFinal = tipoPredefinido ??
        (OcasionModel.nombresPredefinidos.contains(nombre) ? nombre : 'Otro');
    final iconoFinal = icono ?? OcasionModel.iconoPorNombre(tipoFinal);

    // Procesar experiencias recalculando esGratis según precio (HU33-RF02 Criterio 2)
    final experienciasProcesadas = <ExperienciaModel>[];
    for (int i = 0; i < experiencias.length; i++) {
      final exp = experiencias[i];
      final expId = exp.id.isNotEmpty && !exp.id.startsWith('temp_')
          ? exp.id
          : '${ocasionId}_exp_${i + 1}';
      final esGratisCalculado = exp.precio <= 0.0;
      final procesada = exp.copyWith(
        id: expId,
        esGratis: esGratisCalculado,
        orden: exp.orden > 0 ? exp.orden : i + 1,
      );
      experienciasProcesadas.add(procesada);
    }

    final batch = _firestore.batch();
    batch.update(ocasionDocRef, {
      'nombre': nombre.trim(),
      'tipoPredefinido': tipoFinal,
      'descripcion': descripcion.trim(),
      'icono': iconoFinal,
      'experiencias': experienciasProcesadas.map((e) => e.toMap()..['id'] = e.id).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Sincronizar subcolección de experiencias
    final subColeccion = await ocasionDocRef.collection('experiencias').get();
    final idsActuales = experienciasProcesadas.map((e) => e.id).toSet();
    for (final doc in subColeccion.docs) {
      if (!idsActuales.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final exp in experienciasProcesadas) {
      final expDoc = ocasionDocRef.collection('experiencias').doc(exp.id);
      batch.set(expDoc, exp.toMap());
    }

    await batch.commit();
  }

  /// Elimina una experiencia individual de una ocasión (HU33-RF02 Criterio 3 y 4).
  /// Las reservas confirmadas que ya la seleccionaron conservan su snapshot histórico intacto.
  Future<void> eliminarExperienciaIndividual({
    required String restaurantId,
    required String ocasionId,
    required String experienciaId,
  }) async {
    final ocasionDocRef = _getOcasionesRef(restaurantId).doc(ocasionId);
    final docSnapshot = await ocasionDocRef.get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data() ?? {};
    final rawList = data['experiencias'] as List<dynamic>? ?? [];
    final filtradas = rawList.where((it) {
      if (it is Map) {
        return it['id'] != experienciaId;
      }
      return true;
    }).toList();

    final batch = _firestore.batch();
    batch.update(ocasionDocRef, {
      'experiencias': filtradas,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final expDoc = ocasionDocRef.collection('experiencias').doc(experienciaId);
    batch.delete(expDoc);

    await batch.commit();
  }

  /// Stream en tiempo real de ocasiones del restaurante (HU33-RF01 Criterio 7, HU33-RF02 Criterio 5)
  Stream<List<OcasionModel>> getOcasionesStream(String restaurantId) {
    if (restaurantId.trim().isEmpty) {
      return Stream.value(<OcasionModel>[]);
    }

    return _getOcasionesRef(restaurantId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return OcasionModel.fromFirestore(doc, restaurantId);
      }).toList();
    });
  }

  /// Consulta de ocasiones activas con sus experiencias para HU18-RF01 (Criterio 5)
  Future<List<OcasionModel>> getOcasiones(String restaurantId) async {
    if (restaurantId.trim().isEmpty) return [];

    final query = await _getOcasionesRef(restaurantId)
        .where('activo', isEqualTo: true)
        .get();

    final List<OcasionModel> result = [];
    for (final doc in query.docs) {
      final ocasion = OcasionModel.fromFirestore(doc, restaurantId);
      result.add(ocasion);
    }
    return result;
  }

  /// Elimina una ocasión especial del restaurante (HU33-RF01, HU33-RF02 Criterio 3 y 4).
  /// Las reservas existentes conservan su dato histórico intacto en el documento de reservación.
  Future<void> eliminarOcasion({
    required String restaurantId,
    required String ocasionId,
  }) async {
    final ocasionDocRef = _getOcasionesRef(restaurantId).doc(ocasionId);

    // Eliminar subcolección experiencias
    final sub = await ocasionDocRef.collection('experiencias').get();
    final batch = _firestore.batch();
    for (final doc in sub.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(ocasionDocRef);
    await batch.commit();
  }

  /// Activa o desactiva una ocasión especial
  Future<void> toggleOcasionActiva({
    required String restaurantId,
    required String ocasionId,
    required bool nuevoEstado,
  }) async {
    await _getOcasionesRef(restaurantId).doc(ocasionId).update({
      'activo': nuevoEstado,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
