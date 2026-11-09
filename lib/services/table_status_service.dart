import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mesa_model.dart';

/// Estado manual de las mesas (HU31-RF01): el administrador puede marcar una mesa
/// fuera de servicio (por ejemplo, por mantenimiento) y volver a activarla. Ese
/// estado se guarda en la mesa (`estadoManual`) y manda sobre el derivado de las reservas.
class TableStatusService {
  final FirebaseFirestore? _firestoreInstance;

  TableStatusService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _mesaRef(String restauranteId, String mesaId) =>
      _db.collection('restaurants').doc(restauranteId).collection('mesas').doc(mesaId);

  /// Marca la mesa fuera de servicio.
  Future<void> ponerFueraDeServicio(String restauranteId, String mesaId) =>
      _mesaRef(restauranteId, mesaId)
          .update({'estadoManual': MesaModel.estadoFueraDeServicio});

  /// Vuelve a activar la mesa: su estado se deriva otra vez de las reservas.
  Future<void> reactivar(String restauranteId, String mesaId) =>
      _mesaRef(restauranteId, mesaId).update({'estadoManual': null});

  /// Mesas del restaurante en tiempo real.
  Stream<List<MesaModel>> mesasStream(String restauranteId) {
    return _db
        .collection('restaurants')
        .doc(restauranteId)
        .collection('mesas')
        .snapshots()
        .map((s) {
      final lista = s.docs.map(MesaModel.fromFirestore).toList();
      lista.sort((a, b) => a.nombre.compareTo(b.nombre));
      return lista;
    });
  }
}
