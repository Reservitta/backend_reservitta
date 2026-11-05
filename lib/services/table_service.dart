import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mesa_model.dart';
import '../models/zona_model.dart';
import '../repositories/table_repository.dart';

/// Implementación de [TableRepository] sobre Cloud Firestore (HU09-RF02, HU10-RF01).
class TableService implements TableRepository {
  final FirebaseFirestore? _firestoreInstance;

  TableService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _restaurantRef(String id) =>
      _firestore.collection('restaurants').doc(id);

  @override
  Future<List<MesaModel>> getMesas(String restaurantId) async {
    final snap = await _restaurantRef(restaurantId).collection('mesas').get();
    return snap.docs.map(MesaModel.fromFirestore).toList();
  }

  @override
  Future<List<ZonaModel>> getZonas(String restaurantId) async {
    final snap = await _restaurantRef(restaurantId).collection('zonas').get();
    final zonas = snap.docs.map(ZonaModel.fromFirestore).toList();
    zonas.sort((a, b) => a.orden.compareTo(b.orden));
    return zonas;
  }
}
