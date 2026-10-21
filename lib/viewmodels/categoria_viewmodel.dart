import 'dart:async';
import 'package:flutter/material.dart';
import '../models/categoria_model.dart';
import '../services/categoria_service.dart';
import '../utils/validators.dart';

class CategoriaViewModel extends ChangeNotifier {
  final CategoriaService _categoriaService;
  final String restaurantId;

  CategoriaViewModel({
    required this.restaurantId,
    CategoriaService? categoriaService,
  }) : _categoriaService = categoriaService ?? CategoriaService();

  // Controlador de texto para formularios
  final TextEditingController nombreController = TextEditingController();
  String tipoSeleccionado = 'general';

  // Lista sincronizada mediante listener en tiempo real (HU32-RF01)
  List<CategoriaModel> categoriasEnTiempoReal = [];
  StreamSubscription<List<CategoriaModel>>? _categoriasSubscription;

  // Estado de carga y errores
  bool isLoading = false;
  String? errorMessage;
  String? nombreFieldError;

  // Estado para confirmación explícita al eliminar categorías con platillos (Criterio 4)
  bool requiereConfirmacionEliminacion = false;
  int platillosAsociadosCount = 0;
  String? categoriaPendienteEliminarId;

  /// Stream en tiempo real de las categorías ordenadas por 'orden'
  Stream<List<CategoriaModel>> get categoriasStream =>
      _categoriaService.getCategoriasStream(restaurantId);

  /// Inicia el listener en tiempo real para propagar cambios de categorías automáticamente (HU32-RF01)
  void iniciarEscuchaEnTiempoReal() {
    _categoriasSubscription?.cancel();
    _categoriasSubscription = categoriasStream.listen(
      (categoriasActualizadas) {
        categoriasEnTiempoReal = categoriasActualizadas;
        notifyListeners();
      },
      onError: (Object error) {
        errorMessage = 'Error en la sincronización en tiempo real de categorías.';
        notifyListeners();
      },
    );
  }

  /// Detiene el listener en tiempo real si ya no se requiere
  void detenerEscuchaEnTiempoReal() {
    _categoriasSubscription?.cancel();
    _categoriasSubscription = null;
  }

  /// Limpia errores actuales
  void limpiarErrores() {
    errorMessage = null;
    nombreFieldError = null;
    notifyListeners();
  }

  /// Obtiene la cantidad de platillos asociados a una categoría
  Future<int> contarPlatillosAsociados(String categoriaId) async {
    try {
      return await _categoriaService.contarPlatillosAsociados(
        restaurantId: restaurantId,
        categoriaId: categoriaId,
      );
    } catch (_) {
      return 0;
    }
  }

  /// 1. Crear una nueva categoría validando que no sea vacía ni duplicada
  Future<bool> crearCategoria({
    String? nombre,
    String? tipo,
    int? orden,
  }) async {
    final nombreFinal = (nombre ?? nombreController.text).trim();
    final tipoFinal = tipo ?? tipoSeleccionado;

    final validacion = AppValidators.validateCategoryName(nombreFinal);
    if (validacion != null) {
      nombreFieldError = validacion;
      errorMessage = validacion;
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    nombreFieldError = null;
    notifyListeners();

    try {
      await _categoriaService.crearCategoria(
        restaurantId: restaurantId,
        nombre: nombreFinal,
        tipo: tipoFinal,
        orden: orden,
      );
      nombreController.clear();
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      errorMessage = msg;
      nombreFieldError = msg;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 2. Editar una categoría existente en tiempo real validando unicidad de nombre
  Future<bool> actualizarCategoria({
    required String categoriaId,
    required String nuevoNombre,
    String? nuevoTipo,
  }) async {
    final validacion = AppValidators.validateCategoryName(nuevoNombre);
    if (validacion != null) {
      nombreFieldError = validacion;
      errorMessage = validacion;
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    nombreFieldError = null;
    notifyListeners();

    try {
      await _categoriaService.actualizarCategoria(
        restaurantId: restaurantId,
        categoriaId: categoriaId,
        nuevoNombre: nuevoNombre,
        nuevoTipo: nuevoTipo,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      errorMessage = msg;
      nombreFieldError = msg;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 3. Reordenar categorías cuando el administrador cambia su posición
  Future<bool> reordenarCategorias(
    List<CategoriaModel> categoriasActuales,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final listaReordenada = List<CategoriaModel>.from(categoriasActuales);
    final itemMovido = listaReordenada.removeAt(oldIndex);
    listaReordenada.insert(newIndex, itemMovido);

    // Reasignar índices de orden secuenciales (1..N)
    for (int i = 0; i < listaReordenada.length; i++) {
      listaReordenada[i] = listaReordenada[i].copyWith(orden: i + 1);
    }
    categoriasEnTiempoReal = List<CategoriaModel>.from(listaReordenada);

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _categoriaService.reordenarCategorias(
        restaurantId: restaurantId,
        categoriasOrdenadas: listaReordenada,
      );
      return true;
    } catch (e) {
      errorMessage = 'No se pudo actualizar el orden de las categorías.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 3b. Mover categoría hacia arriba mediante botón de flecha
  Future<bool> moverArriba(int index) async {
    if (index <= 0 || index >= categoriasEnTiempoReal.length) return false;
    return await reordenarCategorias(
      categoriasEnTiempoReal,
      index,
      index - 1,
    );
  }

  /// 3c. Mover categoría hacia abajo mediante botón de flecha
  Future<bool> moverAbajo(int index) async {
    if (index < 0 || index >= categoriasEnTiempoReal.length - 1) return false;
    return await reordenarCategorias(
      categoriasEnTiempoReal,
      index,
      index + 2,
    );
  }

  /// 4. Eliminar categoría: verifica primero si tiene platillos asociados.
  /// Si tiene platillos y [confirmadoExplicitamente] es false, detiene el borrado y activa
  /// [requiereConfirmacionEliminacion] para pedir confirmación al administrador.
  Future<bool> eliminarCategoria(
    String categoriaId, {
    bool confirmadoExplicitamente = false,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (!confirmadoExplicitamente) {
        final asociados = await _categoriaService.contarPlatillosAsociados(
          restaurantId: restaurantId,
          categoriaId: categoriaId,
        );

        if (asociados > 0) {
          requiereConfirmacionEliminacion = true;
          platillosAsociadosCount = asociados;
          categoriaPendienteEliminarId = categoriaId;
          return false;
        }
      }

      await _categoriaService.eliminarCategoria(
        restaurantId: restaurantId,
        categoriaId: categoriaId,
      );

      cancelarEliminacionPendiente();
      return true;
    } catch (e) {
      errorMessage = 'Error al intentar eliminar la categoría.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Cancela el estado de alerta de eliminación pendiente
  void cancelarEliminacionPendiente() {
    requiereConfirmacionEliminacion = false;
    platillosAsociadosCount = 0;
    categoriaPendienteEliminarId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _categoriasSubscription?.cancel();
    nombreController.dispose();
    super.dispose();
  }
}
