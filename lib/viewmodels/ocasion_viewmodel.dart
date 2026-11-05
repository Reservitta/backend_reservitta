import 'dart:async';
import 'package:flutter/material.dart';
import '../models/experiencia_model.dart';
import '../models/ocasion_model.dart';
import '../services/ocasion_service.dart';

/// ViewModel para la administración de ocasiones especiales y sus experiencias (HU33-RF01 y HU33-RF02)
class OcasionViewModel extends ChangeNotifier {
  final String restaurantId;
  final OcasionService _ocasionService;

  StreamSubscription<List<OcasionModel>>? _subscription;
  List<OcasionModel> _ocasiones = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Estado del formulario de creación y edición (HU33-RF01 y HU33-RF02)
  String? _ocasionEnEdicionId;
  String _nombrePredefinidoSeleccionado = OcasionModel.nombresPredefinidos.first;
  String _nombrePersonalizado = '';
  String _descripcion = '';
  final List<ExperienciaModel> _experienciasTemporales = [];

  OcasionViewModel({
    required this.restaurantId,
    OcasionService? ocasionService,
  }) : _ocasionService = ocasionService ?? OcasionService();

  // Getters generales
  List<OcasionModel> get ocasiones => List.unmodifiable(_ocasiones);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Getters del formulario
  bool get esModoEdicion => _ocasionEnEdicionId != null;
  String? get ocasionEnEdicionId => _ocasionEnEdicionId;
  String get nombrePredefinidoSeleccionado => _nombrePredefinidoSeleccionado;
  String get nombrePersonalizado => _nombrePersonalizado;
  String get descripcion => _descripcion;
  List<ExperienciaModel> get experienciasTemporales =>
      List.unmodifiable(_experienciasTemporales);

  /// Retorna el nombre final efectivo de la ocasión (Criterio 1)
  String get nombreFinal {
    if (_nombrePredefinidoSeleccionado == OcasionModel.tipoOtro) {
      return _nombrePersonalizado.trim();
    }
    return _nombrePredefinidoSeleccionado;
  }

  /// Indica si la ocasión cuenta con los requisitos mínimos para ser guardada (Criterios 1, 4 y 6)
  bool get puedeGuardar =>
      nombreFinal.isNotEmpty && _experienciasTemporales.isNotEmpty && !_isLoading;

  /// Inicia la escucha en tiempo real de las ocasiones del restaurante (HU33-RF01 y HU33-RF02 Criterio 5)
  void iniciarEscucha() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _ocasionService.getOcasionesStream(restaurantId).listen(
      (list) {
        _ocasiones = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = 'Error al cargar ocasiones: $err';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Modificadores del formulario
  void setNombrePredefinido(String nuevoNombre) {
    _nombrePredefinidoSeleccionado = nuevoNombre;
    notifyListeners();
  }

  void setNombrePersonalizado(String valor) {
    _nombrePersonalizado = valor;
    notifyListeners();
  }

  void setDescripcion(String valor) {
    _descripcion = valor;
    notifyListeners();
  }

  /// Carga los datos de una ocasión existente en el formulario para edición (HU33-RF02)
  void cargarOcasionParaEdicion(OcasionModel ocasion) {
    _ocasionEnEdicionId = ocasion.id;
    final esPredefinido = OcasionModel.nombresPredefinidos.contains(ocasion.tipoPredefinido);
    if (esPredefinido && ocasion.tipoPredefinido != OcasionModel.tipoOtro) {
      _nombrePredefinidoSeleccionado = ocasion.tipoPredefinido;
      _nombrePersonalizado = '';
    } else {
      _nombrePredefinidoSeleccionado = OcasionModel.tipoOtro;
      _nombrePersonalizado = ocasion.nombre;
    }
    _descripcion = ocasion.descripcion;
    _experienciasTemporales.clear();
    _experienciasTemporales.addAll(ocasion.experiencias);
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Agrega una experiencia en memoria a la ocasión antes de guardar (HU33-RF01 Criterios 2, 3, 4 y 6)
  /// Si el precio es <= 0, se marca automáticamente como "Gratis" (Criterio 3).
  bool agregarExperienciaTemporal({
    required String nombre,
    String descripcionCorta = '',
    required double precio,
  }) {
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) {
      _errorMessage = 'El nombre de la experiencia es obligatorio.';
      notifyListeners();
      return false;
    }

    if (precio < 0) {
      _errorMessage = 'El precio de la experiencia no puede ser negativo.';
      notifyListeners();
      return false;
    }

    final esGratis = precio <= 0.0;
    final nuevaExperiencia = ExperienciaModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${_experienciasTemporales.length + 1}',
      nombre: nombreLimpio,
      descripcionCorta: descripcionCorta.trim(),
      precio: precio,
      esGratis: esGratis,
      orden: _experienciasTemporales.length + 1,
    );

    _experienciasTemporales.add(nuevaExperiencia);
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Actualiza una experiencia existente en la lista temporal (HU33-RF02 Criterio 2)
  /// Permite modificar nombre, descripción y alternar gratuidad ($0 -> gratis, >0 -> precio).
  bool actualizarExperienciaTemporal(
    int index, {
    required String nombre,
    String descripcionCorta = '',
    required double precio,
  }) {
    if (index < 0 || index >= _experienciasTemporales.length) return false;
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) {
      _errorMessage = 'El nombre de la experiencia es obligatorio.';
      notifyListeners();
      return false;
    }
    if (precio < 0) {
      _errorMessage = 'El precio de la experiencia no puede ser negativo.';
      notifyListeners();
      return false;
    }

    final actual = _experienciasTemporales[index];
    final esGratis = precio <= 0.0;
    _experienciasTemporales[index] = actual.copyWith(
      nombre: nombreLimpio,
      descripcionCorta: descripcionCorta.trim(),
      precio: precio,
      esGratis: esGratis,
    );
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Remueve una experiencia de la lista temporal antes de guardar
  void removerExperienciaTemporal(int index) {
    if (index >= 0 && index < _experienciasTemporales.length) {
      _experienciasTemporales.removeAt(index);
      notifyListeners();
    }
  }

  /// Restablece el formulario a su estado original
  void resetFormulario() {
    _ocasionEnEdicionId = null;
    _nombrePredefinidoSeleccionado = OcasionModel.nombresPredefinidos.first;
    _nombrePersonalizado = '';
    _descripcion = '';
    _experienciasTemporales.clear();
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Guarda la ocasión especial (creación o edición) con todas sus experiencias asociadas (HU33-RF01 y HU33-RF02)
  Future<bool> guardarOcasion() async {
    final nombre = nombreFinal;
    if (nombre.isEmpty) {
      _errorMessage = 'El nombre de la ocasión especial es obligatorio.';
      notifyListeners();
      return false;
    }

    if (_experienciasTemporales.isEmpty) {
      _errorMessage = 'Debes agregar al menos una experiencia antes de guardar.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (esModoEdicion) {
        await _ocasionService.actualizarOcasion(
          restaurantId: restaurantId,
          ocasionId: _ocasionEnEdicionId!,
          nombre: nombre,
          tipoPredefinido: _nombrePredefinidoSeleccionado,
          descripcion: _descripcion,
          experiencias: _experienciasTemporales,
        );
        _successMessage = 'Ocasión "$nombre" y sus experiencias actualizadas con éxito.';
      } else {
        await _ocasionService.crearOcasion(
          restaurantId: restaurantId,
          nombre: nombre,
          tipoPredefinido: _nombrePredefinidoSeleccionado,
          descripcion: _descripcion,
          experiencias: _experienciasTemporales,
        );
        _successMessage = 'Ocasión "$nombre" y sus experiencias creadas con éxito.';
      }

      resetFormulario();
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar ocasión: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina una experiencia individual directamente de una ocasión ya guardada (HU33-RF02 Criterio 3)
  Future<bool> eliminarExperienciaIndividual({
    required String ocasionId,
    required String experienciaId,
  }) async {
    try {
      await _ocasionService.eliminarExperienciaIndividual(
        restaurantId: restaurantId,
        ocasionId: ocasionId,
        experienciaId: experienciaId,
      );
      _successMessage = 'Experiencia eliminada correctamente.';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar experiencia: $e';
      notifyListeners();
      return false;
    }
  }

  /// Elimina una ocasión existente y sus experiencias (HU33-RF01, HU33-RF02 Criterio 3 y 4)
  Future<void> eliminarOcasion(String ocasionId) async {
    try {
      await _ocasionService.eliminarOcasion(
        restaurantId: restaurantId,
        ocasionId: ocasionId,
      );
      _successMessage = 'Ocasión eliminada correctamente.';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al eliminar ocasión: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
