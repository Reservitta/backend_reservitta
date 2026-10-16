import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/utils/validators.dart';
import 'package:reservitta/viewmodels/categoria_viewmodel.dart';
import 'package:reservitta/viewmodels/platillo_viewmodel.dart';

/// Servicio simulado en memoria con StreamController en tiempo real para CategoriaViewModel
class FakeCategoriaService extends CategoriaService {
  final List<CategoriaModel> categoriasEnMemoria = [];
  final Map<String, int> platillosPorCategoria = {};
  final StreamController<List<CategoriaModel>> _streamController =
      StreamController<List<CategoriaModel>>.broadcast();

  void _emitirCambios() {
    final copia = List<CategoriaModel>.from(categoriasEnMemoria)
      ..sort((a, b) => a.orden.compareTo(b.orden));
    _streamController.add(copia);
  }

  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) {
    return _streamController.stream;
  }

  @override
  Future<String> crearCategoria({
    required String restaurantId,
    required String nombre,
    String tipo = 'general',
    int? orden,
  }) async {
    final norm = CategoriaModel.normalizarNombre(nombre);
    final duplicado = categoriasEnMemoria.any((c) => c.nombreNormalizado == norm);
    if (duplicado) {
      throw Exception('Ya existe una categoría con este nombre en tu restaurante.');
    }
    final nuevoId = 'cat_${categoriasEnMemoria.length + 1}';
    categoriasEnMemoria.add(
      CategoriaModel(
        id: nuevoId,
        nombre: nombre.trim(),
        nombreNormalizado: norm,
        orden: orden ?? (categoriasEnMemoria.length + 1),
        tipo: tipo,
      ),
    );
    _emitirCambios();
    return nuevoId;
  }

  @override
  Future<void> actualizarCategoria({
    required String restaurantId,
    required String categoriaId,
    required String nuevoNombre,
    String? nuevoTipo,
  }) async {
    final norm = CategoriaModel.normalizarNombre(nuevoNombre);
    final duplicado = categoriasEnMemoria.any(
      (c) => c.nombreNormalizado == norm && c.id != categoriaId,
    );
    if (duplicado) {
      throw Exception('Ya existe una categoría con este nombre en tu restaurante.');
    }
    final idx = categoriasEnMemoria.indexWhere((c) => c.id == categoriaId);
    if (idx != -1) {
      categoriasEnMemoria[idx] = categoriasEnMemoria[idx].copyWith(
        nombre: nuevoNombre.trim(),
        nombreNormalizado: norm,
        tipo: nuevoTipo,
      );
      _emitirCambios();
    }
  }

  @override
  Future<int> contarPlatillosAsociados({
    required String restaurantId,
    required String categoriaId,
  }) async {
    return platillosPorCategoria[categoriaId] ?? 0;
  }

  @override
  Future<void> eliminarCategoria({
    required String restaurantId,
    required String categoriaId,
  }) async {
    categoriasEnMemoria.removeWhere((c) => c.id == categoriaId);
    _emitirCambios();
  }

  @override
  Future<void> reordenarCategorias({
    required String restaurantId,
    required List<CategoriaModel> categoriasOrdenadas,
  }) async {
    categoriasEnMemoria
      ..clear()
      ..addAll(categoriasOrdenadas);
    _emitirCambios();
  }
}

/// Servicio simulado en memoria con StreamController en tiempo real para PlatilloViewModel
class FakePlatilloService extends PlatilloService {
  final List<PlatilloModel> platillosEnMemoria = [];
  final StreamController<List<PlatilloModel>> _adminStreamController =
      StreamController<List<PlatilloModel>>.broadcast();
  final StreamController<List<PlatilloModel>> _visitantesStreamController =
      StreamController<List<PlatilloModel>>.broadcast();

  void _emitirCambios() {
    final todos = List<PlatilloModel>.from(platillosEnMemoria)
      ..sort((a, b) => a.orden.compareTo(b.orden));
    _adminStreamController.add(todos);

    final activos = todos.where((p) => p.isActivo).toList();
    _visitantesStreamController.add(activos);
  }

  @override
  Stream<List<PlatilloModel>> getAllPlatillosStream(String restaurantId) {
    return _adminStreamController.stream;
  }

  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) {
    return _visitantesStreamController.stream;
  }

  @override
  Future<String> crearPlatillo({
    required String restaurantId,
    required PlatilloModel platillo,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final nuevoId = 'plat_${platillosEnMemoria.length + 1}';
    final urlFinal = (imageBytes != null && imageBytes.isNotEmpty)
        ? 'https://storage.googleapis.com/reservitta/platillos/$nuevoId.jpg'
        : PlatilloModel.imagenPorDefecto;

    platillosEnMemoria.add(
      platillo.copyWith(id: nuevoId, imagenUrl: urlFinal),
    );
    _emitirCambios();
    return nuevoId;
  }

  @override
  Future<void> actualizarPlatillo({
    required String restaurantId,
    required PlatilloModel platillo,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final idx = platillosEnMemoria.indexWhere((p) => p.id == platillo.id);
    if (idx != -1) {
      String urlFinal = platillo.imagenUrl;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        urlFinal = 'https://storage.googleapis.com/reservitta/platillos/${platillo.id}_edit.jpg';
      }
      platillosEnMemoria[idx] = platillo.copyWith(imagenUrl: urlFinal);
      _emitirCambios();
    }
  }

  @override
  Future<void> toggleEstadoPlatillo({
    required String restaurantId,
    required String platilloId,
    required String nuevoEstado,
  }) async {
    if (!PlatilloModel.estadosValidos.contains(nuevoEstado)) {
      throw ArgumentError('Estado inválido');
    }
    final idx = platillosEnMemoria.indexWhere((p) => p.id == platilloId);
    if (idx != -1) {
      platillosEnMemoria[idx] = platillosEnMemoria[idx].copyWith(estado: nuevoEstado);
      _emitirCambios();
    }
  }

  @override
  Future<PlatilloModel?> getPlatilloById(String restaurantId, String platilloId) async {
    for (final p in platillosEnMemoria) {
      if (p.id == platilloId) return p;
    }
    return null;
  }
}

void main() {
  group('Validadores de Categoría y Platillo (AppValidators)', () {
    test('validateCategoryName rechaza nombres vacíos o menores a 2 caracteres', () {
      expect(AppValidators.validateCategoryName(''), isNotNull);
      expect(AppValidators.validateCategoryName('  '), isNotNull);
      expect(AppValidators.validateCategoryName('A'), isNotNull);
      expect(AppValidators.validateCategoryName('Entradas'), isNull);
    });

    test('validateDishName rechaza nombres vacíos o menores a 2 caracteres', () {
      expect(AppValidators.validateDishName(''), isNotNull);
      expect(AppValidators.validateDishName('  '), isNotNull);
      expect(AppValidators.validateDishName('P'), isNotNull);
      expect(AppValidators.validateDishName('Tacos al Pastor'), isNull);
    });

    test('validatePrice exige valor numérico y estrictamente mayor a cero', () {
      expect(AppValidators.validatePrice(''), isNotNull);
      expect(AppValidators.validatePrice('abc'), isNotNull);
      expect(AppValidators.validatePrice('0'), isNotNull);
      expect(AppValidators.validatePrice('-15.50'), isNotNull);
      expect(AppValidators.validatePrice('120.00'), isNull);
      expect(AppValidators.validatePrice('45.5'), isNull);
    });
  });

  group('CategoriaModel y PlatilloModel', () {
    test('normalizarNombre limpia espacios y convierte a minúsculas', () {
      expect(CategoriaModel.normalizarNombre('  Entradas Especiales  '), 'entradas especiales');
      expect(CategoriaModel.normalizarNombre('POSTRES'), 'postres');
    });

    test('PlatilloModel asigna imagen por defecto si la URL viene vacía', () {
      final platillo = PlatilloModel(
        id: 'plat_1',
        categoriaId: 'cat_1',
        nombre: 'Sopa Azteca',
        descripcion: 'Tortilla, aguacate y queso',
        precio: 85.0,
        imagenUrl: '',
      );

      expect(platillo.imagenUrl, PlatilloModel.imagenPorDefecto);
      expect(platillo.tieneImagenEnNube, isFalse);
    });
  });

  group('Controlador CategoriaViewModel', () {
    late FakeCategoriaService fakeService;
    late CategoriaViewModel controller;

    setUp(() {
      fakeService = FakeCategoriaService();
      controller = CategoriaViewModel(
        restaurantId: 'rest_demo',
        categoriaService: fakeService,
      );
    });

    test('crea categoría válida y rechaza duplicados dentro del mismo restaurante', () async {
      final ok1 = await controller.crearCategoria(nombre: 'Entradas');
      expect(ok1, isTrue);
      expect(fakeService.categoriasEnMemoria.length, 1);

      final okDuplicado = await controller.crearCategoria(nombre: '  entradas ');
      expect(okDuplicado, isFalse);
      expect(controller.errorMessage, contains('Ya existe una categoría'));
    });

    test('eliminar categoría con platillos asociados exige confirmación explícita', () async {
      await controller.crearCategoria(nombre: 'Platos Fuertes');
      final catId = fakeService.categoriasEnMemoria.first.id;
      fakeService.platillosPorCategoria[catId] = 3;

      final borrado1 = await controller.eliminarCategoria(catId);
      expect(borrado1, isFalse);
      expect(controller.requiereConfirmacionEliminacion, isTrue);
      expect(controller.platillosAsociadosCount, 3);

      final borrado2 = await controller.eliminarCategoria(
        catId,
        confirmadoExplicitamente: true,
      );
      expect(borrado2, isTrue);
      expect(controller.requiereConfirmacionEliminacion, isFalse);
      expect(fakeService.categoriasEnMemoria.isEmpty, isTrue);
    });
  });

  group('Controlador PlatilloViewModel y HU32-RF01 (Edición en tiempo real)', () {
    late FakePlatilloService fakeService;
    late PlatilloViewModel controller;

    setUp(() {
      fakeService = FakePlatilloService();
      controller = PlatilloViewModel(
        restaurantId: 'rest_demo',
        platilloService: fakeService,
      );
    });

    test('crea platillo con precio > 0 y usa imagen por defecto si no se sube foto', () async {
      final exito = await controller.crearPlatillo(
        nombre: 'Guacamole',
        descripcion: 'Aguacate con totopos',
        precioTexto: '125.00',
        categoriaId: 'cat_1',
      );

      expect(exito, isTrue);
      expect(fakeService.platillosEnMemoria.length, 1);
      expect(
        fakeService.platillosEnMemoria.first.imagenUrl,
        PlatilloModel.imagenPorDefecto,
      );
    });

    test('HU32-RF01: propaga cambios de precio, descripción e imagen mediante listeners en tiempo real', () async {
      controller.iniciarEscuchaEnTiempoReal();

      await controller.crearPlatillo(
        nombre: 'Enchiladas Suizas',
        descripcion: 'Con salsa verde y queso gratinado',
        precioTexto: '140.00',
        categoriaId: 'cat_fuertes',
      );

      await Future<void>.delayed(Duration.zero);
      expect(controller.platillosEnTiempoReal.length, 1);
      expect(controller.platillosEnTiempoReal.first.precio, 140.0);

      // Editar precio, descripción e imagen en tiempo real
      final original = controller.platillosEnTiempoReal.first;
      await controller.actualizarPlatillo(
        original,
        nombre: 'Enchiladas Suizas Especiales',
        descripcion: 'Receta renovada con pollo orgánico',
        precioTexto: '165.00',
        categoriaId: 'cat_fuertes',
        nuevaImagenBytes: Uint8List.fromList([1, 2, 3]),
        nuevaImagenExt: 'jpg',
      );

      await Future<void>.delayed(Duration.zero);
      final actualizado = controller.platillosEnTiempoReal.first;
      expect(actualizado.nombre, 'Enchiladas Suizas Especiales');
      expect(actualizado.descripcion, 'Receta renovada con pollo orgánico');
      expect(actualizado.precio, 165.0);
      expect(actualizado.tieneImagenEnNube, isTrue);
    });

    test('HU32-RF01: marca platillo como "agotado" o "inactivo" temporalmente sin eliminarlo del catálogo', () async {
      await controller.crearPlatillo(
        nombre: 'Pastel de Chocolate',
        descripcion: 'Rebanada individual',
        precioTexto: '95.0',
        categoriaId: 'cat_postres',
      );
      final platilloCreado = fakeService.platillosEnMemoria.first;

      // 1. Marcar como "agotado" temporalmente
      final okAgotado = await controller.marcarComoAgotado(platilloCreado);
      expect(okAgotado, isTrue);
      expect(fakeService.platillosEnMemoria.first.isAgotado, isTrue);
      expect(fakeService.platillosEnMemoria.length, 1); // No se eliminó del catálogo

      // 2. Marcar como "inactivo" temporalmente
      final okInactivo = await controller.cambiarEstadoActivo(platilloCreado, false);
      expect(okInactivo, isTrue);
      expect(fakeService.platillosEnMemoria.first.isInactivo, isTrue);

      // Sigue recuperándose en el catálogo por ID
      final enCatalogo = await controller.obtenerPlatilloHistorial(platilloCreado.id);
      expect(enCatalogo, isNotNull);
    });

    test('HU32-RF01: cambios posteriores al platillo NO afectan reservaciones ya confirmadas (dato histórico)', () async {
      await controller.crearPlatillo(
        nombre: 'Rib Eye 400g',
        descripcion: 'Término medio',
        precioTexto: '380.00',
        categoriaId: 'cat_cortes',
      );
      final platilloAlReservar = fakeService.platillosEnMemoria.first;

      // Una reservación se confirma preseleccionando 2 órdenes a $380.00 c/u ($760.00 total)
      final preordenConfirmada = controller.generarPreordenItemHistorico(
        platilloAlReservar,
        cantidad: 2,
        observacion: 'Término tres cuartos',
      );

      expect(preordenConfirmada['precio'], 380.00);
      expect(preordenConfirmada['total'], 760.00);
      expect(preordenConfirmada['nombre'], 'Rib Eye 400g');

      // Posteriormente el restaurante sube el precio a $450.00 y lo marca como "agotado"
      await controller.actualizarPlatillo(
        platilloAlReservar,
        nombre: 'Rib Eye Premium 400g',
        descripcion: 'Nueva guarnición',
        precioTexto: '450.00',
        nuevoEstado: PlatilloModel.estadoAgotado,
      );

      // Verificamos que el catálogo cambió a $450.00 y está agotado...
      final platilloEnCatalogo = fakeService.platillosEnMemoria.first;
      expect(platilloEnCatalogo.precio, 450.00);
      expect(platilloEnCatalogo.isAgotado, isTrue);

      // ...pero la reservación ya confirmada conserva intacto su dato histórico ($380.00 y total $760.00)
      expect(preordenConfirmada['precio'], 380.00);
      expect(preordenConfirmada['total'], 760.00);
      expect(preordenConfirmada['nombre'], 'Rib Eye 400g');
    });
  });
}
