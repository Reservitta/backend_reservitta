import 'dart:async';
import 'package:flutter/material.dart';
import '../models/experiencia_model.dart';
import '../models/ocasion_model.dart';
import '../services/ocasion_service.dart';

/// ViewModel para la administración de ocasiones especiales y sus experiencias (HU33-RF01)
class OcasionViewModel extends ChangeNotifier {
  final String restaurantId;
  final OcasionService _ocasionService;

  StreamSubscription<List<OcasionModel>>? _subscription;
  List<OcasionModel> _ocasiones = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Estado del formulario de creación (HU33-RF01 Criterios 1, 2, 4 y 6)
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

  /// Inicia la escucha en tiempo real de las ocasiones del restaurante (Criterio 7)
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

  /// Agrega una experiencia en memoria a la ocasión antes de guardar (HU33-RF01 Criterios 2, 3, 4 y 6)
  /// Si el precio es 0, se marca automáticamente como "Gratis" (Criterio 3).
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

  /// Remueve una experiencia de la lista temporal antes de guardar
  void removerExperienciaTemporal(int index) {
    if (index >= 0 && index < _experienciasTemporales.length) {
      _experienciasTemporales.removeAt(index);
      notifyListeners();
    }
  }

  /// Restablece el formulario a su estado original
  void resetFormulario() {
    _nombrePredefinidoSeleccionado = OcasionModel.nombresPredefinidos.first;
    _nombrePersonalizado = '';
    _descripcion = '';
    _experienciasTemporales.clear();
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Guarda la ocasión especial con todas sus experiencias asociadas al restaurante (Criterios 5, 6 y 7)
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
      await _ocasionService.crearOcasion(
        restaurantId: restaurantId,
        nombre: nombre,
        tipoPredefinido: _nombrePredefinidoSeleccionado,
        descripcion: _descripcion,
        experiencias: _experienciasTemporales,
      );

      _successMessage = 'Ocasión "$nombre" y sus experiencias creadas con éxito.';
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

  /// Elimina una ocasión existente
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
