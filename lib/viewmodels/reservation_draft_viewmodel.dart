import 'package:flutter/material.dart';
import '../models/branch_model.dart';
import '../models/mesa_model.dart';
import '../models/reservation_draft_model.dart';
import '../models/restaurant_model.dart';
import '../repositories/table_repository.dart';
import '../services/availability_service.dart';
import '../services/restaurant_service.dart';
import '../utils/schedule_utils.dart';

/// ViewModel que orquesta el flujo de reserva y la gestión del borrador (HU07, HU08, HU09).
/// Administra el estado incremental de sucursal, fecha, duración y personas.
class ReservationDraftViewModel extends ChangeNotifier {
  final RestaurantModel restaurant;
  final RestaurantService? restaurantService;
  final TableRepository? tableRepository;
  final DateTime Function() _clock;
  final int maxAnticipacionDias;

  ReservationDraftModel _draft;
  int _currentStep = 0; // 0: Sucursal, 1: Fecha, 2: Duración, 3: Personas, 4: Mesa, 5: Horario, 6: Resumen
  int? _maxFromTables; // Mayor grupo que las mesas reales pueden sentar
  List<BranchModel> _branches = [];
  bool _isLoadingBranches = false;
  String? _errorMessage;

  // Duraciones predefinidas en pasos de 30 min de 1h a 4h (HU08-RF01)
  static const List<int> duracionesDisponibles = [
    60,  // 1 hora
    90,  // 1 hora 30 min (Sugerida por defecto)
    120, // 2 horas
    150, // 2 horas 30 min
    180, // 3 horas
    210, // 3 horas 30 min
    240, // 4 horas
  ];

  static const int duracionPorDefectoMin = 90;

  ReservationDraftViewModel({
    required this.restaurant,
    this.restaurantService,
    this.tableRepository,
    DateTime Function()? clock,
    this.maxAnticipacionDias = 60,
  })  : _clock = clock ?? DateTime.now,
        _draft = ReservationDraftModel(
          restaurant: restaurant,
          duracionMin: duracionPorDefectoMin,
          personas: 2,
        ) {
    _initBranches();
    _initTables();
  }

  // Getters
  ReservationDraftModel get draft => _draft;
  int get currentStep => _currentStep;
  List<BranchModel> get branches => List.unmodifiable(_branches);
  bool get isLoadingBranches => _isLoadingBranches;
  DateTime get clockNow => _clock();
  String? get errorMessage => _errorMessage;

  /// Capacidad máxima permitida para el grupo (HU09-RF01)
  int get maxPartySize {
    final desdeMesas = _maxFromTables;
    if (desdeMesas != null && desdeMesas > 0) return desdeMesas;
    if (restaurant.capacidadTotal > 0) {
      return restaurant.capacidadTotal;
    }
    return 20; // Capacidad combinable por defecto si no está especificada
  }

  int get minPartySize => 1;

  // ---------------------------------------------------------------------------
  // Inicialización de Sucursales
  // ---------------------------------------------------------------------------
  Future<void> _initBranches() async {
    _isLoadingBranches = true;
    notifyListeners();

    try {
      if (restaurantService != null) {
        final list = await restaurantService!.getBranches(restaurant.id);
        if (list.isNotEmpty) {
          _branches = list;
        } else {
          _branches = _generateDefaultBranches();
        }
      } else {
        _branches = _generateDefaultBranches();
      }
    } catch (_) {
      _branches = _generateDefaultBranches();
    } finally {
      _isLoadingBranches = false;
      notifyListeners();
    }
  }

  /// Si el restaurante no cuenta con sucursales creadas en la subcolección,
  /// provee una lista representativa de sucursales para la experiencia del usuario.
  List<BranchModel> _generateDefaultBranches() {
    final baseName = restaurant.nombre;
    final baseDir = restaurant.direccion.isNotEmpty
        ? restaurant.direccion
        : 'Av. Principal 125, Centro Histórico';

    return [
      BranchModel(
        id: '${restaurant.id}_centro',
        nombre: '$baseName — Centro',
        direccion: baseDir,
        telefono: restaurant.telefono,
        esPrincipal: true,
      ),
      BranchModel(
        id: '${restaurant.id}_norte',
        nombre: '$baseName — Norte',
        direccion: 'Blvd. Norte 450, Fracc. Los Pinos',
        telefono: restaurant.telefono,
        esPrincipal: false,
      ),
      BranchModel(
        id: '${restaurant.id}_plaza',
        nombre: '$baseName — Plaza',
        direccion: 'Plaza Comercial Sur, Local 12, Av. Industrial',
        telefono: restaurant.telefono,
        esPrincipal: false,
      ),
    ];
  }

  /// Calcula el máximo de personas con las mesas registradas del restaurante.
  Future<void> _initTables() async {
    final repo = tableRepository;
    if (repo == null) return;
    try {
      final mesas = await repo.getMesas(restaurant.id);
      if (mesas.isEmpty) return;
      _maxFromTables = AvailabilityService.maxGroupSize(mesas);
      if (_draft.personas > _maxFromTables!) {
        final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(personas: _maxFromTables);
        _invalidateTableSelection();
      }
      notifyListeners();
    } catch (_) {
      // Sin acceso a las mesas se conserva el máximo por capacidad del restaurante.
    }
  }

  // ---------------------------------------------------------------------------
  // Manejo de Sucursal (Paso 0)
  // ---------------------------------------------------------------------------
  void selectBranch(BranchModel branch) {
    final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(branch: () => branch);
    notifyListeners();
  }

  bool get canContinueFromBranch => _draft.branch != null;

  // ---------------------------------------------------------------------------
  // HU07-RF02: Selector de fecha de visita (Paso 1)
  // ---------------------------------------------------------------------------
  bool isDateSelectable(DateTime date) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    // 1. Fechas pasadas deshabilitadas
    if (target.isBefore(today)) {
      return false;
    }

    // 2. Límite máximo de anticipación (60 días)
    if (target.isAfter(today.add(Duration(days: maxAnticipacionDias)))) {
      return false;
    }

    // 3. Cierres especiales
    if (ScheduleUtils.isSpecialClosureDate(
      cierresEspeciales: restaurant.cierresEspeciales,
      dateTime: target,
    )) {
      return false;
    }

    // 4. Días en que el restaurante atiende
    if (restaurant.diasAbiertos.isNotEmpty) {
      final dayName = ScheduleUtils.dayOfWeekToName(target.weekday);
      final normalized = ScheduleUtils.normalizeDayName(dayName);
      final isOpenDay = restaurant.diasAbiertos
          .map(ScheduleUtils.normalizeDayName)
          .contains(normalized);
      if (!isOpenDay) {
        return false;
      }
    }

    // 5. Horario configurado como cerrado
    if (restaurant.horarios.isNotEmpty) {
      final dayName = ScheduleUtils.dayOfWeekToName(target.weekday);
      final normalized = ScheduleUtils.normalizeDayName(dayName);
      final schedule = restaurant.horarios[normalized];
      if (schedule != null && !schedule.abierto) {
        return false;
      }
    }

    return true;
  }

  void selectDate(DateTime date) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    // 1. Fechas pasadas deshabilitadas
    if (target.isBefore(today)) {
      return;
    }

    // 2. Límite máximo de anticipación (60 días)
    if (target.isAfter(today.add(Duration(days: maxAnticipacionDias)))) {
      return;
    }

    // HU12-RF02: Si se conserva la misma fecha, no se invalidan mesas ni horario
    if (_draft.fecha != null &&
        _draft.fecha!.year == target.year &&
        _draft.fecha!.month == target.month &&
        _draft.fecha!.day == target.day) {
      return;
    }

    if (_draft.fecha != null &&
        _draft.fecha!.year == target.year &&
        _draft.fecha!.month == target.month &&
        _draft.fecha!.day == target.day) {
      return;
    }
    final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(fecha: () => target);
    _invalidateTableSelection();
    notifyListeners();
  }

  bool get canContinueFromDate =>
      _draft.fecha != null && isDateSelectable(_draft.fecha!);

  // ---------------------------------------------------------------------------
  // HU08-RF01: Selector de duración (Paso 2)
  // ---------------------------------------------------------------------------
  void selectDuration(int minutes) {
    if (!duracionesDisponibles.contains(minutes)) {
      return;
    }
    // HU12-RF02: Si se conserva la misma duración, no se invalidan mesas ni horario
    if (_draft.duracionMin == minutes) {
      return;
    }
    if (_draft.duracionMin == minutes) return;
    final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(duracionMin: minutes);
    _invalidateTableSelection();
    notifyListeners();
  }

  bool get canContinueFromDuration =>
      _draft.duracionMin > 0 && duracionesDisponibles.contains(_draft.duracionMin);

  // ---------------------------------------------------------------------------
  // HU09-RF01: Selector de cantidad de personas (Paso 3)
  // ---------------------------------------------------------------------------
  void setPartySize(int count) {
    if (count < minPartySize || count > maxPartySize) {
      return;
    }
    // HU12-RF02: Si se conserva la misma cantidad de personas, no se invalidan mesas ni horario
    if (_draft.personas == count) {
      return;
    }
    if (_draft.personas == count) return;
    final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(personas: count);
    _invalidateTableSelection();
    notifyListeners();
  }

  void incrementPartySize() {
    if (_draft.personas < maxPartySize) {
      final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(personas: _draft.personas + 1);
      _invalidateTableSelection();
      notifyListeners();
    }
  }

  void decrementPartySize() {
    if (_draft.personas > minPartySize) {
      final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(personas: _draft.personas - 1);
      _invalidateTableSelection();
      notifyListeners();
    }
  }

  bool get canContinueFromPeople =>
      _draft.personas >= minPartySize && _draft.personas <= maxPartySize;

  // ---------------------------------------------------------------------------
  // HU10-RF03 / HU10-RF04: mesa o combinación elegida (Paso 4)
  // ---------------------------------------------------------------------------

  /// Guarda en el borrador la mesa o combinación elegida. Cambiar de mesa
  /// invalida el horario, porque los horarios libres dependen de las mesas.
  void setSelectedTables(List<MesaModel> mesas) {
    final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(
      mesaIds: newIds,
      mesasNombres: mesas.map((m) => m.nombre).toList(),
      horario: () => null,
    );
    notifyListeners();
  }

  bool get canContinueFromTables => _draft.mesaIds.isNotEmpty;

  // ---------------------------------------------------------------------------
  // HU11-RF02: horario elegido (Paso 5)
  // ---------------------------------------------------------------------------

  /// Guarda en el borrador la hora de inicio del [slot] elegido.
  void selectTime(TimeSlot slot) {
    final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(
      horario: () => TimeOfDay(hour: slot.inicio.hour, minute: slot.inicio.minute),
    );
    notifyListeners();
  }

  void clearTime() {
    final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(horario: () => null);
    notifyListeners();
  }

  bool get canContinueFromTime => _draft.horario != null;

  /// Fecha, duración o personas cambiaron: la mesa y el horario elegidos ya no valen.
  void _invalidateTableSelection() {
    if (_draft.mesaIds.isEmpty && _draft.horario == null) return;
    final newIds = mesas.map((m) => m.id).toList();
    final oldIds = _draft.mesaIds;
    final sameTables = newIds.length == oldIds.length &&
        newIds.toSet().containsAll(oldIds) &&
        oldIds.toSet().containsAll(newIds);
    if (sameTables && _draft.horario != null) {
      return;
    }
    _draft = _draft.copyWith(
      mesaIds: const [],
      mesasNombres: const [],
      horario: () => null,
    );
  }

  // ---------------------------------------------------------------------------
  // Navegación de pasos y retención / descarte del borrador (HU07-RF01)
  // ---------------------------------------------------------------------------
  bool get canAdvanceCurrentStep {
    switch (_currentStep) {
      case 0:
        return canContinueFromBranch;
      case 1:
        return canContinueFromDate;
      case 2:
        return canContinueFromDuration;
      case 3:
        return canContinueFromPeople;
      case 4:
        return canContinueFromTables;
      case 5:
        return canContinueFromTime;
      case 6:
        return canContinueFromSummary;
      default:
        return false;
    }
  }

  bool get canContinueFromSummary => _draft.isReadyForSummary;

  void nextStep() {
    if (canAdvanceCurrentStep && _currentStep < 6) {
      _currentStep++;
      notifyListeners();
    }
  }

  /// Retrocede en el flujo conservando los datos ya elegidos (HU07-RF01)
  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      // Los datos en _draft SE CONSERVAN íntegros
      notifyListeners();
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 6) {
      _currentStep = step;
      notifyListeners();
    }
  }

  /// Si el usuario cancela o sale del flujo, el borrador se descarta (HU07-RF01)
  void discardDraft() {
    _draft = _draft.clear();
    _currentStep = 0;
    notifyListeners();
  }
}
