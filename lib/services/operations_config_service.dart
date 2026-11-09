import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operations_config.dart';

/// Lee y guarda los ajustes operativos del restaurante (umbral de alertas HU30-RF03,
/// anticipación del recordatorio HU21-RF01).
class OperationsConfigService {
  final FirebaseFirestore? _firestoreInstance;

  OperationsConfigService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String restauranteId) =>
      _db.collection('restaurants').doc(restauranteId);

  /// Ajustes del restaurante; los que falten toman su valor por defecto.
  Future<OperationsConfig> cargar(String restauranteId) async {
    final snap = await _ref(restauranteId).get();
    return OperationsConfig.fromRestaurantData(snap.data());
  }

  /// Guarda las alertas y el recordatorio. El umbral debe ser positivo.
  Future<void> guardar(String restauranteId, OperationsConfig config) {
    if (config.umbralAlertaMin <= 0) {
      throw ArgumentError('El umbral de la alerta debe ser mayor a 0 minutos.');
    }
    if (config.recordatorioMin <= 0) {
      throw ArgumentError('La anticipación del recordatorio debe ser mayor a 0.');
    }
    return _ref(restauranteId).update({
      'configuracion.alertasActivas': config.alertasActivas,
      'configuracion.umbralAlertaMin': config.umbralAlertaMin,
      'configuracion.recordatorioMin': config.recordatorioMin,
      'configuracion.recordatorioTardioInmediato':
          config.recordatorioTardioInmediato,
      'configuracion.procesamientoServidor': config.procesamientoServidor,
    });
  }
}
