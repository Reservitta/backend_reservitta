import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/platillo_model.dart';
import '../services/platillo_service.dart';
import '../utils/validators.dart';

class PlatilloViewModel extends ChangeNotifier {
  final PlatilloService _platilloService;
  final ImagePicker _imagePicker;
  final String restaurantId;

  PlatilloViewModel({
    required this.restaurantId,
    PlatilloService? platilloService,
    ImagePicker? imagePicker,
  })  : _platilloService = platilloService ?? PlatilloService(),
        _imagePicker = imagePicker ?? ImagePicker();

  // Controladores para campos del formulario de platillo
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController precioController = TextEditingController();
  final TextEditingController placeholderObsController = TextEditingController();

  // Estado seleccionado del platillo
  String? categoriaSeleccionadaId;
  String estadoSeleccionado = PlatilloModel.estadoActivo;
  int ordenSeleccionado = 1;
  List<String> etiquetasSeleccionadas = [];

  // Lista sincronizada mediante listener en tiempo real (HU32-RF01)
  List<PlatilloModel> platillosEnTiempoReal = [];
  StreamSubscription<List<PlatilloModel>>? _platillosSubscription;

  // Estado para la imagen a subir a Cloud Storage
  Uint8List? imagenBytes;
  String? imagenExtension;
  String? imagenNombreArchivo;

  // Estados de carga y validación de errores
  bool isLoading = false;
  String? errorMessage;
  Map<String, String?> fieldErrors = {};

  /// Stream para VISITANTES (HU06): únicamente platillos con estado == 'activo'
  Stream<List<PlatilloModel>> get platillosVisitantesStream =>
      _platilloService.getPlatillosActivosStream(restaurantId);

  /// Stream para ADMINISTRADOR: todos los platillos (activos, agotados e inactivos)
  Stream<List<PlatilloModel>> get platillosAdminStream =>
      _platilloService.getAllPlatillosStream(restaurantId);

  /// Stream filtrado por categoría
  Stream<List<PlatilloModel>> getPlatillosPorCategoria(
    String categoriaId, {
    bool soloActivos = false,
  }) {
    return _platilloService.getPlatillosPorCategoriaStream(
      restaurantId,
      categoriaId,
      soloActivos: soloActivos,
    );
  }

  /// Inicia el listener en tiempo real para propagar cambios de platillos automáticamente (HU32-RF01)
  void iniciarEscuchaEnTiempoReal({bool soloActivos = false}) {
    _platillosSubscription?.cancel();
    final stream = soloActivos ? platillosVisitantesStream : platillosAdminStream;
    _platillosSubscription = stream.listen(
      (platillosActualizados) {
        platillosEnTiempoReal = platillosActualizados;
        notifyListeners();
      },
      onError: (Object error) {
        errorMessage = 'Error en la sincronización en tiempo real del menú.';
        notifyListeners();
      },
    );
  }

  /// Detiene el listener en tiempo real si ya no se requiere
  void detenerEscuchaEnTiempoReal() {
    _platillosSubscription?.cancel();
    _platillosSubscription = null;
  }

  /// Selecciona la categoría a la que pertenece el platillo
  void seleccionarCategoria(String? categoriaId) {
    categoriaSeleccionadaId = categoriaId;
    fieldErrors['categoria'] = null;
    notifyListeners();
  }

  /// Abre la galería para elegir una foto de platillo (opcional)
  Future<void> seleccionarImagenGaleria() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null) {
        imagenBytes = await picked.readAsBytes();
        imagenNombreArchivo = picked.name;
        final parts = picked.name.split('.');
        imagenExtension = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
        notifyListeners();
      }
    } catch (e) {
      errorMessage = 'No se pudo cargar la imagen seleccionada.';
      notifyListeners();
    }
  }

  /// Quita la imagen cargada en memoria (usará la imagen por defecto)
  void limpiarImagen() {
    imagenBytes = null;
    imagenExtension = null;
    imagenNombreArchivo = null;
    notifyListeners();
  }

  /// Carga los datos de un platillo existente en los controladores para editarlo en tiempo real
  void cargarPlatilloParaEdicion(PlatilloModel platillo) {
    nombreController.text = platillo.nombre;
    descripcionController.text = platillo.descripcion;
    precioController.text = platillo.precio.toStringAsFixed(2);
    placeholderObsController.text = platillo.placeholderObservacion;
    categoriaSeleccionadaId = platillo.categoriaId;
    estadoSeleccionado = platillo.estado;
    ordenSeleccionado = platillo.orden;
    etiquetasSeleccionadas = List<String>.from(platillo.etiquetas);
    limpiarImagen();
    fieldErrors.clear();
    errorMessage = null;
    notifyListeners();
  }

  /// Limpia todo el formulario para un registro nuevo
  void limpiarFormulario() {
    nombreController.clear();
    descripcionController.clear();
    precioController.clear();
    placeholderObsController.clear();
    categoriaSeleccionadaId = null;
    estadoSeleccionado = PlatilloModel.estadoActivo;
    ordenSeleccionado = 1;
    etiquetasSeleccionadas = [];
    limpiarImagen();
    fieldErrors.clear();
    errorMessage = null;
    notifyListeners();
  }

  /// Valida todos los campos obligatorios antes de invocar al servicio
  bool validarCampos({
    required String nombre,
    required String precioTexto,
    required String? categoriaId,
  }) {
    final errNombre = AppValidators.validateDishName(nombre);
    final errPrecio = AppValidators.validatePrice(precioTexto);
    final errCategoria = (categoriaId == null || categoriaId.trim().isEmpty)
        ? 'Debes seleccionar una categoría para el platillo.'
        : null;

    fieldErrors = {
      'nombre': errNombre,
      'precio': errPrecio,
      'categoria': errCategoria,
    };

    final esValido = errNombre == null && errPrecio == null && errCategoria == null;
    if (!esValido) {
      errorMessage = errNombre ?? errPrecio ?? errCategoria;
    } else {
      errorMessage = null;
    }

    notifyListeners();
    return esValido;
  }

  /// 1. Crear un platillo nuevo validando reglas de negocio y subiendo imagen si existe
  Future<bool> crearPlatillo({
    String? nombre,
    String? descripcion,
    String? precioTexto,
    String? categoriaId,
    Uint8List? customImageBytes,
    String? customImageExt,
  }) async {
    final nombreFinal = (nombre ?? nombreController.text).trim();
    final descFinal = (descripcion ?? descripcionController.text).trim();
    final precioStr = (precioTexto ?? precioController.text).trim();
    final catFinal = categoriaId ?? categoriaSeleccionadaId;

    if (!validarCampos(
      nombre: nombreFinal,
      precioTexto: precioStr,
      categoriaId: catFinal,
    )) {
      return false;
    }

    final double precioNumerico = double.parse(precioStr);

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final nuevoPlatillo = PlatilloModel(
        id: '',
        categoriaId: catFinal!,
        nombre: nombreFinal,
        descripcion: descFinal,
        precio: precioNumerico,
        imagenUrl: '',
        estado: estadoSeleccionado,
        orden: ordenSeleccionado,
        etiquetas: etiquetasSeleccionadas,
        placeholderObservacion: placeholderObsController.text.trim(),
      );

      await _platilloService.crearPlatillo(
        restaurantId: restaurantId,
        platillo: nuevoPlatillo,
        imageBytes: customImageBytes ?? imagenBytes,
        imageExtension: customImageExt ?? imagenExtension,
      );

      limpiarFormulario();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('ArgumentError: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 2. Actualizar un platillo existente en tiempo real (precio, descripción, imagen, disponibilidad)
  /// Los cambios se propagan a Firestore sin afectar reservaciones ya confirmadas (HU32-RF01)
  Future<bool> actualizarPlatillo(
    PlatilloModel platilloOriginal, {
    String? nombre,
    String? descripcion,
    String? precioTexto,
    String? categoriaId,
    String? nuevoEstado,
    Uint8List? nuevaImagenBytes,
    String? nuevaImagenExt,
  }) async {
    final nombreFinal = (nombre ?? nombreController.text).trim();
    final descFinal = (descripcion ?? descripcionController.text).trim();
    final precioStr = (precioTexto ?? precioController.text).trim();
    final catFinal = categoriaId ?? categoriaSeleccionadaId ?? platilloOriginal.categoriaId;
    final estadoFinal = nuevoEstado ?? estadoSeleccionado;

    if (!validarCampos(
      nombre: nombreFinal,
      precioTexto: precioStr,
      categoriaId: catFinal,
    )) {
      return false;
    }

    final double precioNumerico = double.parse(precioStr);

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final platilloActualizado = platilloOriginal.copyWith(
        nombre: nombreFinal,
        descripcion: descFinal,
        precio: precioNumerico,
        categoriaId: catFinal,
        estado: estadoFinal,
        orden: platilloOriginal.orden,
        etiquetas: etiquetasSeleccionadas.isNotEmpty ? etiquetasSeleccionadas : platilloOriginal.etiquetas,
        placeholderObservacion: placeholderObsController.text.trim().isNotEmpty
            ? placeholderObsController.text.trim()
            : platilloOriginal.placeholderObservacion,
      );

      await _platilloService.actualizarPlatillo(
        restaurantId: restaurantId,
        platillo: platilloActualizado,
        imageBytes: nuevaImagenBytes ?? imagenBytes,
        imageExtension: nuevaImagenExt ?? imagenExtension,
      );

      limpiarFormulario();
      return true;
    } catch (e) {
      errorMessage = 'No se pudo actualizar el platillo.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 3. Cambiar disponibilidad entre 'activo', 'agotado' o 'inactivo' (HU32-RF01 y HU06)
  /// No elimina el platillo del catálogo ni altera reservas ya confirmadas.
  Future<bool> cambiarDisponibilidad(PlatilloModel platillo, String nuevoEstado) async {
    if (!PlatilloModel.estadosValidos.contains(nuevoEstado)) {
      errorMessage = 'Estado de disponibilidad no válido.';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _platilloService.toggleEstadoPlatillo(
        restaurantId: restaurantId,
        platilloId: platillo.id,
        nuevoEstado: nuevoEstado,
      );
      return true;
    } catch (e) {
      errorMessage = 'No se pudo cambiar la disponibilidad del platillo.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Conmutar rápidamente entre activo e inactivo (compatibilidad HU06)
  Future<bool> cambiarEstadoActivo(PlatilloModel platillo, bool activar) {
    return cambiarDisponibilidad(
      platillo,
      activar ? PlatilloModel.estadoActivo : PlatilloModel.estadoInactivo,
    );
  }

  /// Marcar temporalmente un platillo como "agotado" sin eliminarlo del catálogo (HU32-RF01)
  Future<bool> marcarComoAgotado(PlatilloModel platillo) {
    return cambiarDisponibilidad(platillo, PlatilloModel.estadoAgotado);
  }

  /// 4. Consultar platillo por ID para el historial (activo, agotado o inactivo)
  Future<PlatilloModel?> obtenerPlatilloHistorial(String platilloId) async {
    try {
      return await _platilloService.getPlatilloById(restaurantId, platilloId);
    } catch (e) {
      errorMessage = 'No se pudo recuperar el platillo del historial.';
      notifyListeners();
      return null;
    }
  }

  /// 5. Genera el snapshot inmutable de preorden para una reservación confirmada (HU32-RF01).
  /// Congela el nombre y precio al momento de reservar para que cambios futuros en el menú
  /// no afecten las reservaciones ya confirmadas.
  Map<String, dynamic> generarPreordenItemHistorico(
    PlatilloModel platillo, {
    required int cantidad,
    String observacion = '',
    String mensajeFelicitacion = '',
  }) {
    if (!platillo.isActivo) {
      throw StateError(
        'No se puede preseleccionar un platillo que está ${platillo.estado}.',
      );
    }
    return platillo.toPreordenItemSnapshot(
      cantidad: cantidad,
      observacion: observacion,
      mensajeFelicitacion: mensajeFelicitacion,
    );
  }

  /// 6. Eliminar un platillo definitivamente del menú
  Future<bool> eliminarPlatillo(String platilloId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _platilloService.eliminarPlatillo(restaurantId, platilloId);
      return true;
    } catch (e) {
      errorMessage = 'No se pudo eliminar el platillo.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _platillosSubscription?.cancel();
    nombreController.dispose();
    descripcionController.dispose();
    precioController.dispose();
    placeholderObsController.dispose();
    super.dispose();
  }
}
