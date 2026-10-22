import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/utils/validators.dart';
import 'package:reservitta/viewmodels/platillo_viewmodel.dart';
import 'package:reservitta/views/widgets/platillo_card.dart';
import 'package:reservitta/views/widgets/platillo_form_dialog.dart';
import 'package:reservitta/views/widgets/preorden_item_dialog.dart';

class MockPlatilloService extends PlatilloService {
  final List<PlatilloModel> platillos;
  final StreamController<List<PlatilloModel>> _controller =
      StreamController<List<PlatilloModel>>.broadcast();

  MockPlatilloService({List<PlatilloModel>? platillos})
      : platillos = platillos ?? [];

  void _emitir() {
    _controller.add(List<PlatilloModel>.from(platillos));
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
    final id = 'plat_${platillos.length + 1}';
    final nuevo = platillo.copyWith(id: id);
    platillos.add(nuevo);
    _emitir();
    return id;
  }

  @override
  Future<void> actualizarPlatillo({
    required String restaurantId,
    required PlatilloModel platillo,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final idx = platillos.indexWhere((p) => p.id == platillo.id);
    if (idx != -1) {
      platillos[idx] = platillo;
      _emitir();
    }
  }
}

class MockCategoriaService extends CategoriaService {
  final List<CategoriaModel> categorias;
  final StreamController<List<CategoriaModel>> _controller =
      StreamController<List<CategoriaModel>>.broadcast();

  MockCategoriaService({List<CategoriaModel>? categorias})
      : categorias = categorias ?? [];

  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) {
    Future.microtask(() => _controller.add(categorias));
    return _controller.stream;
  }
}

void main() {
  const restaurantId = 'rest_test_01';

  final testCategoria = const CategoriaModel(
    id: 'cat_cortes',
    nombre: 'Cortes Finos',
    nombreNormalizado: 'cortes finos',
    orden: 1,
  );

  group('HU24-RF05: Campo de personalización del cliente - Pruebas de Modelo y Snapshot', () {
    test('Criterio 1 y 2: Platillo admite placeholder y límite de caracteres configurado por el admin', () {
      final platillo = PlatilloModel(
        id: 'p1',
        categoriaId: 'cat_cortes',
        nombre: 'Rib Eye Steak',
        descripcion: 'Corte magro de 350g a la parrilla',
        precio: 380.00,
        permitePersonalizacion: true,
        placeholderObservacion: 'Ej. Término medio, sin sal en grano',
        limiteCaracteresObs: 150,
      );

      expect(platillo.permitePersonalizacion, isTrue);
      expect(platillo.placeholderObservacion, 'Ej. Término medio, sin sal en grano');
      expect(platillo.limiteCaracteresObs, 150);
    });

    test('Criterio 3: El texto del cliente se guarda en el snapshot de preorden sin alterar el platillo del menú', () {
      final platillo = PlatilloModel(
        id: 'p1',
        categoriaId: 'cat_cortes',
        nombre: 'Rib Eye Steak',
        descripcion: 'Corte magro de 350g a la parrilla',
        precio: 380.00,
        permitePersonalizacion: true,
        placeholderObservacion: 'Ej. Término medio',
        limiteCaracteresObs: 150,
      );

      final snapshot = platillo.toPreordenItemSnapshot(
        cantidad: 2,
        observacion: 'Término tres cuartos, sin cebolla asada',
      );

      // Snapshot para la reservación
      expect(snapshot['platilloId'], 'p1');
      expect(snapshot['nombre'], 'Rib Eye Steak');
      expect(snapshot['precio'], 380.00);
      expect(snapshot['cantidad'], 2);
      expect(snapshot['total'], 760.00);
      expect(snapshot['observacion'], 'Término tres cuartos, sin cebolla asada');

      // El catálogo del platillo no se modifica
      expect(platillo.descripcion, 'Corte magro de 350g a la parrilla');
      expect(platillo.placeholderObservacion, 'Ej. Término medio');
    });

    test('Criterio 4: Lanza ArgumentError si la personalización excede el límite máximo de caracteres', () {
      final platillo = PlatilloModel(
        id: 'p1',
        categoriaId: 'cat_cortes',
        nombre: 'Rib Eye Steak',
        descripcion: 'Corte',
        precio: 380.00,
        permitePersonalizacion: true,
        limiteCaracteresObs: 50,
      );

      final observacionLarga = 'A' * 51;

      expect(
        () => platillo.toPreordenItemSnapshot(
          cantidad: 1,
          observacion: observacionLarga,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('no puede exceder el límite de 50 caracteres'),
        )),
      );
    });

    test('Si permitePersonalizacion es falso, rechaza modificaciones con ArgumentError', () {
      final platillo = PlatilloModel(
        id: 'p2',
        categoriaId: 'cat_cortes',
        nombre: 'Platillo Fijo',
        descripcion: 'Receta inmutable',
        precio: 200.00,
        permitePersonalizacion: false,
      );

      expect(
        () => platillo.toPreordenItemSnapshot(
          cantidad: 1,
          observacion: 'Quitar pimienta',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('no admite personalizaciones'),
        )),
      );
    });
  });

  group('HU24-RF05: Validadores de personalización (AppValidators)', () {
    test('validatePlaceholder valida límite máximo de 80 caracteres para el administrador', () {
      expect(AppValidators.validatePlaceholder(null), isNull);
      expect(AppValidators.validatePlaceholder(''), isNull);
      expect(AppValidators.validatePlaceholder('Ej. Sin picante'), isNull);

      final demasiadoLargo = 'P' * 81;
      expect(
        AppValidators.validatePlaceholder(demasiadoLargo),
        'El texto de ejemplo no puede exceder los 80 caracteres.',
      );
    });

    test('validateCustomization valida notas del cliente con límite dinámico (default 150)', () {
      expect(AppValidators.validateCustomization(null), isNull);
      expect(AppValidators.validateCustomization(''), isNull);
      expect(AppValidators.validateCustomization('Sin crema y salsa aparte'), isNull);

      final nota151 = 'X' * 151;
      expect(
        AppValidators.validateCustomization(nota151, maxCharacters: 150),
        'Las modificaciones no pueden exceder los 150 caracteres.',
      );

      final nota101 = 'Y' * 101;
      expect(
        AppValidators.validateCustomization(nota101, maxCharacters: 100),
        'Las modificaciones no pueden exceder los 100 caracteres.',
      );
    });
  });

  group('HU24-RF05: Interfaz de Administración en PlatilloFormDialog y PlatilloCard', () {
    testWidgets('PlatilloCard muestra badge "Personalizable" cuando la opción está activa', (tester) async {
      final platillo = PlatilloModel(
        id: 'p1',
        categoriaId: testCategoria.id,
        nombre: 'Corte Especial',
        descripcion: 'Delicioso corte',
        precio: 350.00,
        permitePersonalizacion: true,
        placeholderObservacion: 'Ej. Término de la carne',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatilloCard(
              platillo: platillo,
              categoriaNombre: testCategoria.nombre,
              onToggleDisponibilidad: (_) {},
              onEditar: () {},
              onEliminar: () {},
            ),
          ),
        ),
      );

      expect(find.text('Personalizable'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('PlatilloFormDialog permite configurar switch de personalización, placeholder y límite', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockPlatilloService();
      final catService = MockCategoriaService(categorias: [testCategoria]);
      final vm = PlatilloViewModel(restaurantId: restaurantId, platilloService: service);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatilloFormDialog(
              restaurantId: restaurantId,
              viewModel: vm,
              categoriaService: catService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // El switch de personalización debe estar presente y activado por defecto
      final switchFinder = find.byKey(const ValueKey('switch_permite_personalizacion'));
      expect(switchFinder, findsOneWidget);

      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      final placeholderInput = find.byKey(const ValueKey('input_placeholder_observacion'));
      expect(placeholderInput, findsOneWidget);

      final wrapLimite = find.byKey(const ValueKey('wrap_limite_caracteres'));
      expect(wrapLimite, findsOneWidget);
      expect(find.byKey(const ValueKey('chip_limite_150')), findsOneWidget);

      // Desactivamos el switch de personalización
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Al desactivarse, los campos internos ya no se muestran
      expect(find.byKey(const ValueKey('input_placeholder_observacion')), findsNothing);

      // Lo reactivamos
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('input_placeholder_observacion')), findsOneWidget);
    });
  });

  group('HU24-RF05: Interfaz de Preorden del Cliente (PreordenItemDialog)', () {
    testWidgets('PreordenItemDialog muestra el placeholder del admin y respeta el límite de caracteres', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final platillo = PlatilloModel(
        id: 'p1',
        categoriaId: testCategoria.id,
        nombre: 'Corte Rib Eye',
        descripcion: 'Carne jugosa',
        precio: 300.0,
        permitePersonalizacion: true,
        placeholderObservacion: 'Ej. Término medio, con papas en lugar de verduras',
        limiteCaracteresObs: 150,
      );

      Map<String, dynamic>? resultadoSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const ValueKey('btn_abrir_preorden'),
                onPressed: () async {
                  resultadoSnapshot = await PreordenItemDialog.show(ctx, platillo: platillo);
                },
                child: const Text('Abrir Preorden'),
              ),
            ),
          ),
        ),
      );

      // Abrir el diálogo modal
      await tester.tap(find.byKey(const ValueKey('btn_abrir_preorden')));
      await tester.pumpAndSettle();

      // Verificar que el diálogo está visible
      expect(find.text('Preordenar Platillo'), findsOneWidget);
      expect(find.text('Corte Rib Eye'), findsOneWidget);

      // Criterio 2: El placeholder configurado por el admin se muestra en el input
      expect(find.text('Ej. Término medio, con papas en lugar de verduras'), findsOneWidget);

      // Incrementar cantidad a 2
      await tester.tap(find.byKey(const ValueKey('btn_incrementar_preorden')));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('\$600.00 MXN'), findsOneWidget);

      // Criterio 1: Escribir modificación del cliente
      final inputObs = find.byKey(const ValueKey('input_preorden_observacion'));
      await tester.enterText(inputObs, 'Sin sal en grano, término 3/4');
      await tester.pumpAndSettle();

      // Confirmar adición a la preorden
      await tester.tap(find.byKey(const ValueKey('btn_confirmar_preorden_item')));
      await tester.pumpAndSettle();

      // Verificar el snapshot devuelto (Criterio 3)
      expect(resultadoSnapshot, isNotNull);
      expect(resultadoSnapshot!['platilloId'], 'p1');
      expect(resultadoSnapshot!['nombre'], 'Corte Rib Eye');
      expect(resultadoSnapshot!['cantidad'], 2);
      expect(resultadoSnapshot!['total'], 600.0);
      expect(resultadoSnapshot!['observacion'], 'Sin sal en grano, término 3/4');
    });

    testWidgets('PreordenItemDialog para platillo sin personalización muestra aviso informativo', (tester) async {
      final platillo = PlatilloModel(
        id: 'p2',
        categoriaId: testCategoria.id,
        nombre: 'Vino Tinto Reserva',
        descripcion: 'Botella de vino 750ml',
        precio: 450.0,
        permitePersonalizacion: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreordenItemDialog(platillo: platillo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No debe existir el campo de texto de observaciones
      expect(find.byKey(const ValueKey('input_preorden_observacion')), findsNothing);
      expect(find.text('Este platillo se elabora con receta estándar y no admite modificaciones personalizadas.'), findsOneWidget);
    });
  });
}
