import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/views/platillo_list_view.dart';

class TestPlatilloService extends PlatilloService {
  final List<PlatilloModel> platillosEnMemoria;
  final StreamController<List<PlatilloModel>> _controller =
      StreamController<List<PlatilloModel>>.broadcast();

  TestPlatilloService({List<PlatilloModel>? platillos})
      : platillosEnMemoria = platillos ?? [];

  void _emitir() {
    final copia = List<PlatilloModel>.from(platillosEnMemoria);
    _controller.add(copia);
  }

  @override
  Stream<List<PlatilloModel>> getAllPlatillosStream(String restaurantId) {
    Future.microtask(_emitir);
    return _controller.stream;
  }

  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) {
    Future.microtask(_emitir);
    return _controller.stream.map((list) => list.where((p) => p.isActivo).toList());
  }

  @override
  Future<String> crearPlatillo({
    required String restaurantId,
    required PlatilloModel platillo,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final nuevoId = 'plat_${platillosEnMemoria.length + 1}';
    final nuevo = platillo.copyWith(
      id: nuevoId,
      imagenUrl: platillo.imagenUrl.isEmpty
          ? PlatilloModel.imagenPorDefecto
          : platillo.imagenUrl,
    );
    platillosEnMemoria.add(nuevo);
    _emitir();
    return nuevoId;
  }

  @override
  Future<void> actualizarPlatillo({
    required String restaurantId,
    required PlatilloModel platillo,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final index = platillosEnMemoria.indexWhere((p) => p.id == platillo.id);
    if (index != -1) {
      platillosEnMemoria[index] = platillo;
      _emitir();
    }
  }

  @override
  Future<void> toggleEstadoPlatillo({
    required String restaurantId,
    required String platilloId,
    required String nuevoEstado,
  }) async {
    final index = platillosEnMemoria.indexWhere((p) => p.id == platilloId);
    if (index != -1) {
      platillosEnMemoria[index] = platillosEnMemoria[index].copyWith(
        estado: nuevoEstado,
      );
      _emitir();
    }
  }

  @override
  Future<void> eliminarPlatillo(String restaurantId, String platilloId) async {
    platillosEnMemoria.removeWhere((p) => p.id == platilloId);
    _emitir();
  }
}

class TestCategoriaService extends CategoriaService {
  final List<CategoriaModel> categorias;
  final StreamController<List<CategoriaModel>> _controller =
      StreamController<List<CategoriaModel>>.broadcast();

  TestCategoriaService({List<CategoriaModel>? categorias})
      : categorias = categorias ?? [];

  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) {
    Future.microtask(() => _controller.add(categorias));
    return _controller.stream;
  }
}

void main() {
  group('HU24-RF04: Formulario de alta/edición de platillo y gestión de menú', () {
    late TestPlatilloService platilloService;
    late TestCategoriaService categoriaService;

    final categoriaPrueba = CategoriaModel(
      id: 'cat_tacos',
      nombre: 'Tacos y Especialidades',
      nombreNormalizado: 'tacos y especialidades',
      orden: 1,
    );

    final platilloPrueba = PlatilloModel(
      id: 'plat_1',
      categoriaId: 'cat_tacos',
      nombre: 'Taco al Pastor',
      descripcion: 'Tortilla de maíz con piña y cilantro',
      precio: 25.0,
      imagenUrl: 'https://images.unsplash.com/photo-example',
      estado: PlatilloModel.estadoActivo,
    );

    setUp(() {
      platilloService = TestPlatilloService(platillos: [platilloPrueba]);
      categoriaService = TestCategoriaService(categorias: [categoriaPrueba]);
    });

    Widget createWidgetUnderTest({bool showAppBar = true}) {
      return MaterialApp(
        home: PlatilloListView(
          restaurantId: 'rest_123',
          platilloService: platilloService,
          categoriaService: categoriaService,
          showAppBar: showAppBar,
        ),
      );
    }

    testWidgets('Criterio 1: Muestra platillos existentes con nombre, precio y categoría',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Taco al Pastor'), findsOneWidget);
      expect(find.text('\$25.00'), findsOneWidget);
      expect(find.text('Tacos y Especialidades'), findsWidgets);
      expect(find.text('Disponible'), findsOneWidget);
    });

    testWidgets(
        'Criterio 2: Un switch permite marcar un platillo como disponible/agotado con un solo toque y muestra SnackBar',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El platillo inicia activo
      expect(platilloService.platillosEnMemoria.first.isActivo, isTrue);

      // Localizamos el switch en el PlatilloCard
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Tocamos el switch con un solo toque
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // El platillo debe pasar a estado "agotado"
      expect(platilloService.platillosEnMemoria.first.isAgotado, isTrue);

      // Criterio 4: Se muestra confirmación visual breve (SnackBar)
      expect(
        find.text('Platillo "Taco al Pastor" marcado como agotado.'),
        findsOneWidget,
      );

      // Si volvemos a tocarlo, regresa a "disponible" (activo)
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(platilloService.platillosEnMemoria.first.isActivo, isTrue);
      expect(
        find.text('Platillo "Taco al Pastor" marcado como disponible.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Criterio 1: Administrador puede editar precio y descripción sin salir de la lista principal',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Buscamos el botón de editar en el PlatilloCard
      final botonEditar = find.byTooltip('Editar platillo');
      expect(botonEditar, findsOneWidget);

      await tester.tap(botonEditar);
      await tester.pumpAndSettle();

      // Se abre el diálogo modal de edición sin salir de la lista principal
      expect(find.text('Editar Platillo'), findsOneWidget);
      expect(find.text('Taco al Pastor'), findsWidgets);

      // Cambiamos el precio de 25.00 a 32.50
      final precioField = find.widgetWithText(TextFormField, '25.00');
      expect(precioField, findsOneWidget);
      await tester.enterText(precioField, '32.50');

      // Modificamos la descripción
      final descField = find.widgetWithText(
        TextFormField,
        'Tortilla de maíz con piña y cilantro',
      );
      expect(descField, findsOneWidget);
      await tester.enterText(descField, 'Con piña asada, cebolla y salsa especial');

      // Guardamos los cambios presionando el botón 'Actualizar'
      final botonGuardar = find.widgetWithText(ElevatedButton, 'Actualizar');
      expect(botonGuardar, findsOneWidget);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      // No salimos de la lista principal, el diálogo se cerró
      expect(find.text('Editar Platillo'), findsNothing);

      // Criterio 4: SnackBar breve de confirmación
      expect(
        find.text('Platillo "Taco al Pastor" actualizado exitosamente.'),
        findsOneWidget,
      );

      // Criterio 3: Reflejado de inmediato en la lista
      expect(find.text('\$32.50'), findsOneWidget);
      expect(
        find.text('Con piña asada, cebolla y salsa especial'),
        findsOneWidget,
      );
    });

    testWidgets('Formulario de alta crea un nuevo platillo con validaciones',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Presionamos el botón "+ Nuevo Platillo"
      final botonNuevo = find.text('Nuevo Platillo');
      expect(botonNuevo, findsWidgets);

      await tester.tap(botonNuevo.first);
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Platillo'), findsWidgets);

      // Si intentamos guardar vacío, muestra errores de validación de AppValidators
      final botonGuardar = find.widgetWithText(ElevatedButton, 'Guardar Platillo');
      await tester.tap(botonGuardar);
      await tester.pump();

      expect(find.text('Por favor ingresa el nombre del platillo.'), findsOneWidget);
      expect(find.text('Por favor ingresa el precio del platillo.'), findsOneWidget);

      // Llenamos el formulario
      final nombreInputs = find.byType(TextFormField);
      // Primer campo: Nombre
      await tester.enterText(nombreInputs.at(0), 'Gringa al Pastor');
      // Segundo campo: Precio
      await tester.enterText(nombreInputs.at(1), '65.00');
      // Tercer campo: Descripción
      await tester.enterText(nombreInputs.at(2), 'Con queso Oaxaca fundido');

      // Seleccionamos categoría
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tacos y Especialidades').last);
      await tester.pumpAndSettle();

      // Guardamos
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      // SnackBar de confirmación
      expect(
        find.text('Platillo agregado al menú con éxito.'),
        findsOneWidget,
      );

      // Se visualiza el nuevo platillo en la lista
      expect(find.text('Gringa al Pastor'), findsOneWidget);
      expect(find.text('\$65.00'), findsOneWidget);
    });

    testWidgets('Embedded mode (showAppBar: false) muestra el título Menú en estilo serif',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(showAppBar: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Menú'), findsOneWidget);
      expect(
        find.text(
          'Administra los platillos de tu restaurante, precios y disponibilidad en tiempo real.',
        ),
        findsOneWidget,
      );
    });
  });
}
