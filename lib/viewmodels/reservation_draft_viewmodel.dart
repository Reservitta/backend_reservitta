import 'package:flutter/material.dart';
import '../models/branch_model.dart';
import '../models/reservation_draft_model.dart';
import '../models/restaurant_model.dart';
import '../services/restaurant_service.dart';
import '../utils/schedule_utils.dart';

/// ViewModel que orquesta el flujo de reserva y la gestión del borrador (HU07, HU08, HU09).
/// Administra el estado incremental de sucursal, fecha, duración y personas.
class ReservationDraftViewModel extends ChangeNotifier {
  final RestaurantModel restaurant;
  final RestaurantService? restaurantService;
  final DateTime Function() _clock;
  final int maxAnticipacionDias;

  ReservationDraftModel _draft;
  int _currentStep = 0; // 0: Sucursal, 1: Fecha, 2: Duración, 3: Personas
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
    DateTime Function()? clock,
    this.maxAnticipacionDias = 60,
  })  : _clock = clock ?? DateTime.now,
        _draft = ReservationDraftModel(
          restaurant: restaurant,
          duracionMin: duracionPorDefectoMin,
          personas: 2,
        ) {
    _initBranches();
  }

  // Getters
  ReservationDraftModel get draft => _draft;
  int get currentStep => _currentStep;
  List<BranchModel> get branches => List.unmodifiable(_branches);
  bool get isLoadingBranches => _isLoadingBranches;
  String? get errorMessage => _errorMessage;

  /// Capacidad máxima permitida para el grupo (HU09-RF01)
  int get maxPartySize {
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

  // ---------------------------------------------------------------------------
  // Manejo de Sucursal (Paso 0)
  // ---------------------------------------------------------------------------
  void selectBranch(BranchModel branch) {
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

    _draft = _draft.copyWith(fecha: () => target);
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
    _draft = _draft.copyWith(duracionMin: minutes);
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
    _draft = _draft.copyWith(personas: count);
    notifyListeners();
  }

  void incrementPartySize() {
    if (_draft.personas < maxPartySize) {
      _draft = _draft.copyWith(personas: _draft.personas + 1);
      notifyListeners();
    }
  }

  void decrementPartySize() {
    if (_draft.personas > minPartySize) {
      _draft = _draft.copyWith(personas: _draft.personas - 1);
      notifyListeners();
    }
  }

  bool get canContinueFromPeople =>
      _draft.personas >= minPartySize && _draft.personas <= maxPartySize;

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
      default:
        return false;
    }
  }

  void nextStep() {
    if (canAdvanceCurrentStep && _currentStep < 3) {
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
    if (step >= 0 && step <= 3) {
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
