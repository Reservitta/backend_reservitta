import 'package:flutter/foundation.dart';

import '../models/restaurant_model.dart';
import '../services/availability_service.dart';

/// Carga y selección de horarios disponibles para la mesa elegida (HU11-RF02).
class TimeSlotViewModel extends ChangeNotifier {
  final RestaurantModel restaurant;
  final AvailabilityService availability;
  final DateTime fecha;
  final int duracionMin;
  final List<String> mesaIds;

  /// Hora ya elegida (al volver al paso), para conservar la selección.
  final DateTime? initialInicio;

  /// Se llama al elegir un horario para guardarlo en el borrador.
  final void Function(TimeSlot slot) onSelected;

  TimeSlotViewModel({
    required this.restaurant,
    required this.availability,
    required this.fecha,
    required this.duracionMin,
    required this.mesaIds,
    required this.onSelected,
    this.initialInicio,
  });

  bool _isLoading = true;
  String? _error;
  List<TimeSlot> _slots = const [];
  TimeSlot? _selected;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Horarios ordenados de menor a mayor.
  List<TimeSlot> get slots => _slots;
  TimeSlot? get selected => _selected;
  bool get hasNoSlots => !_isLoading && _error == null && _slots.isEmpty;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await availability.getAvailableTimeSlots(
        restaurant: restaurant,
        fecha: fecha,
        duracionMin: duracionMin,
        mesaIds: mesaIds,
      );
      _slots = [...result]..sort((a, b) => a.inicio.compareTo(b.inicio));
      _selected = null;
      if (initialInicio != null) {
        for (final s in _slots) {
          if (s.inicio == initialInicio) _selected = s;
        }
      }
    } catch (_) {
      _error = 'No se pudieron cargar los horarios. Intenta de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void select(TimeSlot slot) {
    _selected = slot;
    onSelected(slot);
    notifyListeners();
  }
}
