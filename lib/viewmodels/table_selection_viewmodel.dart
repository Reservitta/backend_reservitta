import 'package:flutter/foundation.dart';

import '../models/mesa_model.dart';
import '../models/restaurant_model.dart';
import '../services/availability_service.dart';

/// Estado visual de una mesa en el mapa (HU10-RF02).
enum TableVisualState {
  disponible,
  ocupada,
  noAdecuada,
  seleccionada,
  noDisponible,
}

/// Mensaje cuando no hay mesas adecuadas (HU09-RF03).
class TableEmptyMessage {
  final String title;
  final String detail;
  final List<String> suggestions;

  /// Máximo de personas permitido cuando el grupo excede la capacidad.
  final int? maxPersonas;

  const TableEmptyMessage({
    required this.title,
    required this.detail,
    this.suggestions = const [],
    this.maxPersonas,
  });

  static const List<String> _cambios = [
    'Cambiar la fecha de la visita',
    'Reducir la duración',
    'Cambiar la cantidad de personas',
  ];

  factory TableEmptyMessage.noTables({
    required int personas,
    required int capacidadMaxima,
    AvailabilityFailure? reason,
    bool sinMesasRegistradas = false,
  }) {
    if (sinMesasRegistradas) {
      return const TableEmptyMessage(
        title: 'Aún no hay mesas registradas',
        detail: 'Este restaurante todavía no configura sus mesas, por lo que no es posible elegir una.',
      );
    }
    if (capacidadMaxima > 0 && personas > capacidadMaxima) {
      return TableEmptyMessage(
        title: 'Tu grupo excede la capacidad del restaurante',
        detail:
            'El máximo permitido es de $capacidadMaxima personas. Tu grupo es de $personas.',
        suggestions: const ['Reducir la cantidad de personas'],
        maxPersonas: capacidadMaxima,
      );
    }
    if (reason != null && reason != AvailabilityFailure.sinDisponibilidad) {
      return TableEmptyMessage(
        title: 'No se puede reservar en esa fecha',
        detail: DateValidationResult.invalid(reason).message ?? '',
        suggestions: const ['Cambiar la fecha de la visita'],
      );
    }
    return TableEmptyMessage(
      title: 'No hay mesas adecuadas',
      detail:
          'No encontramos mesas libres para $personas ${personas == 1 ? 'persona' : 'personas'} en la fecha y duración elegidas.',
      suggestions: _cambios,
    );
  }
}

/// Selección de mesa o combinación de mesas sobre el plano (HU10-RF02, RF03 y RF04).
class TableSelectionViewModel extends ChangeNotifier {
  final RestaurantModel restaurant;
  final AvailabilityService availability;
  final DateTime fecha;
  final int personas;
  final int duracionMin;

  /// Se llama con la selección válida (o vacía) cada vez que cambia, para
  /// guardarla en el borrador.
  final void Function(List<MesaModel> mesas) onSelectionChanged;
  final List<String> initialSelectedIds;

  TableSelectionViewModel({
    required this.restaurant,
    required this.availability,
    required this.fecha,
    required this.personas,
    required this.duracionMin,
    required this.onSelectionChanged,
    this.initialSelectedIds = const [],
  });

  bool _isLoading = true;
  String? _error;
  FloorPlanResult _plan = const FloorPlanResult.sinPlano();
  TableSuggestionResult _suggestions = const TableSuggestionResult();
  final List<MesaModel> _selected = [];
  bool _combineMode = false;
  String? _message;
  bool _busy = false;
  MesaModel? _pendingTap;

  bool get isLoading => _isLoading;
  String? get error => _error;
  FloorPlanResult get plan => _plan;
  List<MesaModel> get selected => List.unmodifiable(_selected);
  bool get combineMode => _combineMode;

  /// Último motivo por el que no se pudo seleccionar una mesa.
  String? get message => _message;

  bool get hasPlan => _plan.configurado;

  /// Sin mesas adecuadas: no hay ninguna individual ni combinación posible.
  bool get hasNoOptions =>
      !_isLoading && _error == null && !_suggestions.hayOpciones;

  /// Hay al menos una mesa individual que cubre al grupo.
  bool get hasIndividualOptions => _suggestions.mesas.isNotEmpty;

  /// Solo existen combinaciones para el grupo.
  bool get needsCombination =>
      _suggestions.mesas.isEmpty && _suggestions.combinaciones.isNotEmpty;

  int get capacidadSeleccionada =>
      _selected.fold<int>(0, (acc, m) => acc + m.capacidad);

  /// La selección actual cubre al grupo y las mesas se pueden usar juntas.
  bool get isValidSelection {
    if (_selected.isEmpty) return false;
    if (capacidadSeleccionada < personas) return false;
    if (_selected.length == 1) return true;
    return _isConnected(_selected);
  }

  int get capacidadMaxima {
    if (_plan.mesas.isNotEmpty) {
      return AvailabilityService.maxGroupSize(
        _plan.mesas.map((p) => p.mesa).toList(),
      );
    }
    return restaurant.capacidadTotal;
  }

  TableEmptyMessage? get emptyMessage {
    if (!hasNoOptions) return null;
    return TableEmptyMessage.noTables(
      personas: personas,
      capacidadMaxima: capacidadMaxima,
      reason: _suggestions.reason ?? _plan.reason,
      sinMesasRegistradas: _plan.mesas.isEmpty,
    );
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _plan = await availability.getFloorPlanForDate(
        restaurant: restaurant,
        fecha: fecha,
        duracionMin: duracionMin,
      );
      _suggestions = await availability.findSuitableTablesForDate(
        restaurant: restaurant,
        fecha: fecha,
        personas: personas,
        duracionMin: duracionMin,
      );
      _restoreSelection();
    } catch (e) {
      _error =
          'No se pudo cargar la disponibilidad de mesas. Intenta de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _restoreSelection() {
    _selected.clear();
    _combineMode = needsCombination;
    if (initialSelectedIds.isEmpty) return;
    final previas = _plan.mesas
        .where(
          (p) =>
              initialSelectedIds.contains(p.mesa.id) &&
              p.estado == MesaEstado.disponible,
        )
        .map((p) => p.mesa)
        .toList();
    if (previas.length != initialSelectedIds.length) return;
    _selected.addAll(previas);
    _combineMode = previas.length > 1 || needsCombination;
  }

  // ---------------------------------------------------------------------------
  // Estados y motivos
  // ---------------------------------------------------------------------------

  PlanoMesa? _planoDe(MesaModel mesa) {
    for (final p in _plan.mesas) {
      if (p.mesa.id == mesa.id) return p;
    }
    return null;
  }

  TableVisualState stateOf(MesaModel mesa) {
    if (_selected.any((m) => m.id == mesa.id)) {
      return TableVisualState.seleccionada;
    }
    final estado = _planoDe(mesa)?.estado ?? MesaEstado.noDisponible;
    if (estado == MesaEstado.noDisponible) return TableVisualState.noDisponible;
    if (estado == MesaEstado.ocupada) return TableVisualState.ocupada;
    if (_combineMode) {
      if (!mesa.combinable) return TableVisualState.noAdecuada;
    } else if (mesa.capacidad < personas) {
      return TableVisualState.noAdecuada;
    }
    return TableVisualState.disponible;
  }

  /// Motivo por el que una mesa no se puede seleccionar; null si sí se puede.
  String? reasonFor(MesaModel mesa) {
    switch (stateOf(mesa)) {
      case TableVisualState.disponible:
      case TableVisualState.seleccionada:
        return null;
      case TableVisualState.ocupada:
        return '${mesa.nombre} no tiene horarios libres para esa fecha y duración.';
      case TableVisualState.noDisponible:
        final reason = _plan.reason;
        return reason == null
            ? 'La fecha elegida no está disponible.'
            : DateValidationResult.invalid(reason).message;
      case TableVisualState.noAdecuada:
        if (_combineMode) {
          return '${mesa.nombre} no se puede combinar con otras mesas.';
        }
        final base =
            '${mesa.nombre} tiene capacidad para ${mesa.capacidad}; tu grupo es de $personas.';
        return mesa.combinable
            ? '$base Activa "Combinar mesas" para unirla con otra.'
            : base;
    }
  }

  // ---------------------------------------------------------------------------
  // Selección
  // ---------------------------------------------------------------------------

  void setCombineMode(bool value) {
    if (_combineMode == value) return;
    _combineMode = value;
    _selected.clear();
    _message = null;
    _commit();
    notifyListeners();
  }

  /// Toca una mesa: la selecciona, la cambia, la quita o informa el motivo.
  Future<void> onTapMesa(MesaModel mesa) async {
    if (_busy) {
      // Un toque durante la verificación no se pierde: se atiende al terminar.
      _pendingTap = mesa;
      return;
    }
    _message = null;
    final estado = stateOf(mesa);

    if (estado == TableVisualState.seleccionada) {
      _selected.removeWhere((m) => m.id == mesa.id);
      _commit();
      notifyListeners();
      return;
    }

    if (estado != TableVisualState.disponible) {
      _message = reasonFor(mesa);
      notifyListeners();
      return;
    }

    if (!_combineMode) {
      _selected
        ..clear()
        ..add(mesa);
      _commit();
      notifyListeners();
      return;
    }

    final candidata = [..._selected, mesa];
    if (!_isConnected(candidata)) {
      _message =
          '${mesa.nombre} no se puede combinar con ${_selected.map((m) => m.nombre).join(', ')}.';
      notifyListeners();
      return;
    }

    _busy = true;
    try {
      final comunes = await availability.getAvailableTimeSlots(
        restaurant: restaurant,
        fecha: fecha,
        duracionMin: duracionMin,
        mesaIds: candidata.map((m) => m.id).toList(),
      );
      if (comunes.isEmpty) {
        _message = 'Esas mesas no tienen un horario libre en común para esa fecha y duración.';
      } else {
        _selected.add(mesa);
        _commit();
      }
    } catch (_) {
      _message = 'No se pudo verificar la disponibilidad. Intenta de nuevo.';
    } finally {
      _busy = false;
      notifyListeners();
    }
    final siguiente = _pendingTap;
    _pendingTap = null;
    if (siguiente != null) await onTapMesa(siguiente);
  }

  /// Quita una mesa de la combinación (HU10-RF04).
  void removeMesa(String mesaId) {
    _selected.removeWhere((m) => m.id == mesaId);
    _message = null;
    _commit();
    notifyListeners();
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  void _commit() =>
      onSelectionChanged(isValidSelection ? List.of(_selected) : const []);

  /// Todas las mesas quedan unidas entre sí por enlaces de combinación.
  bool _isConnected(List<MesaModel> mesas) {
    if (mesas.length < 2) return true;
    final visitadas = <String>{mesas.first.id};
    final pendientes = [mesas.first];
    while (pendientes.isNotEmpty) {
      final actual = pendientes.removeLast();
      for (final otra in mesas) {
        if (!visitadas.contains(otra.id) && actual.puedeCombinarCon(otra)) {
          visitadas.add(otra.id);
          pendientes.add(otra);
        }
      }
    }
    return visitadas.length == mesas.length;
  }
}
