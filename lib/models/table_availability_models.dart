import 'mesa_model.dart';
import 'zona_model.dart';

/// Estado de una mesa en el intervalo consultado (HU08-RF03, HU10-RF01).
/// [noDisponible] se usa cuando la fecha u horario completo no se puede reservar.
enum MesaEstado { disponible, ocupada, noDisponible }

/// Motivo por el que una fecha u horario no se puede reservar.
enum AvailabilityFailure {
  restauranteInactivo,
  fechaPasada,
  fechaMuyLejana,
  sinHorariosHoy,
  cierreEspecial,
  diaCerrado,
  fueraDeHorario,
  sinDisponibilidad,
}

/// Horario de inicio disponible con su hora de fin (HU11-RF01).
class TimeSlot {
  final DateTime inicio;
  final DateTime fin;

  const TimeSlot({required this.inicio, required this.fin});

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.inicio == inicio && other.fin == fin;

  @override
  int get hashCode => Object.hash(inicio, fin);
}

/// Una mesa libre cuya capacidad cubre al grupo (HU09-RF02 Criterios 2 y 5).
class TableOption {
  final MesaModel mesa;
  final int personas;

  const TableOption({required this.mesa, required this.personas});

  /// Su capacidad cubre al grupo; toda opción devuelta lo cumple.
  bool get adecuada => mesa.capacidad >= personas;

  /// Capacidad sobrante respecto al grupo.
  int get holgura => mesa.capacidad - personas;

  /// Tiene más capacidad de la necesaria: se marca pero no se descarta.
  bool get sobrada => holgura > 0;
}

/// Conjunto de mesas combinables cuya capacidad sumada cubre al grupo (HU09-RF02 Criterio 3).
class TableCombination {
  final List<MesaModel> mesas;
  final int personas;

  const TableCombination({required this.mesas, required this.personas});

  int get capacidadTotal => mesas.fold<int>(0, (acc, m) => acc + m.capacidad);
  int get holgura => capacidadTotal - personas;
  List<String> get mesaIds => mesas.map((m) => m.id).toList();
}

/// Resultado de buscar mesas adecuadas para un grupo (HU09-RF02).
class TableSuggestionResult {
  final AvailabilityFailure? reason;

  /// Mesas libres individuales que cubren al grupo, de menor a mayor holgura.
  final List<TableOption> mesas;

  /// Solo se llena si ninguna mesa individual alcanza.
  final List<TableCombination> combinaciones;

  const TableSuggestionResult({
    this.reason,
    this.mesas = const [],
    this.combinaciones = const [],
  });

  bool get hayOpciones => mesas.isNotEmpty || combinaciones.isNotEmpty;
}

/// Mesa del plano con su estado para el intervalo consultado.
class PlanoMesa {
  final MesaModel mesa;
  final MesaEstado estado;

  const PlanoMesa({required this.mesa, required this.estado});
}

/// Plano completo del restaurante con el estado de cada mesa (HU10-RF01 Criterio 4).
class FloorPlanResult {
  /// Falso si el restaurante no tiene mesas con posición: estado controlado (Criterio 5).
  final bool configurado;
  final List<PlanoMesa> mesas;
  final List<ZonaModel> zonas;

  /// Motivo si la fecha u horario no son reservables; las mesas salen [MesaEstado.noDisponible].
  final AvailabilityFailure? reason;

  const FloorPlanResult({
    required this.configurado,
    this.mesas = const [],
    this.zonas = const [],
    this.reason,
  });

  const FloorPlanResult.sinPlano()
    : configurado = false,
      mesas = const [],
      zonas = const [],
      reason = null;

  /// Mesas de una zona; null agrupa las que no tienen zona.
  List<PlanoMesa> mesasDeZona(String? zonaId) =>
      mesas.where((p) => p.mesa.zonaId == zonaId).toList();
}
