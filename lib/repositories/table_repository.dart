import '../models/mesa_model.dart';
import '../models/zona_model.dart';
export '../services/table_service.dart' show TableService;

/// Contrato de lectura de mesas y zonas de un restaurante (HU09-RF02, HU10-RF01).
abstract class TableRepository {
  /// Mesas de `restaurants/{id}/mesas`.
  Future<List<MesaModel>> getMesas(String restaurantId);

  /// Zonas de `restaurants/{id}/zonas`, ordenadas por `orden`.
  Future<List<ZonaModel>> getZonas(String restaurantId);
}
