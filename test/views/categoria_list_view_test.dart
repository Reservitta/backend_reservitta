import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/viewmodels/categoria_viewmodel.dart';
import 'package:reservitta/views/categoria_list_view.dart';
import 'package:reservitta/views/widgets/categoria_empty_state.dart';

class TestCategoriaService extends CategoriaService {
  final List<CategoriaModel> categoriasEnMemoria;
  final Map<String, int> platillosPorCategoria;
  final StreamController<List<CategoriaModel>> _controller =
      StreamController<List<CategoriaModel>>.broadcast();

  TestCategoriaService({
    List<CategoriaModel>? categorias,
    Map<String, int>? platillos,
  })  : categoriasEnMemoria = categorias ?? [],
        platillosPorCategoria = platillos ?? {};

  void _emitir() {
    final copia = List<CategoriaModel>.from(categoriasEnMemoria)
      ..sort((a, b) => a.orden.compareTo(b.orden));
    _controller.add(copia);
  }

  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) {
    Future.microtask(_emitir);
    return _controller.stream;
  }

  @override
  Future<String> crearCategoria({
    required String restaurantId,
    required String nombre,
    String tipo = 'general',
    int? orden,
  }) async {
    final nuevoId = 'cat_${categoriasEnMemoria.length + 1}';
    final nueva = CategoriaModel(
      id: nuevoId,
      nombre: nombre.trim(),
      nombreNormalizado: CategoriaModel.normalizarNombre(nombre),
      orden: orden ?? (categoriasEnMemoria.length + 1),
      tipo: tipo,
    );
    categoriasEnMemoria.add(nueva);
    _emitir();
    return nuevoId;
  }

  @override
  Future<void> actualizarCategoria({
    required String restaurantId,
    required String categoriaId,
    required String nuevoNombre,
    String? nuevoTipo,
  }) async {
    final index = categoriasEnMemoria.indexWhere((c) => c.id == categoriaId);
    if (index != -1) {
      categoriasEnMemoria[index] = categoriasEnMemoria[index].copyWith(
        nombre: nuevoNombre.trim(),
        nombreNormalizado: CategoriaModel.normalizarNombre(nuevoNombre),
        tipo: nuevoTipo,
      );
      _emitir();
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
    _emitir();
  }

  @override
  Future<void> reordenarCategorias({
    required String restaurantId,
    required List<CategoriaModel> categoriasOrdenadas,
  }) async {
    categoriasEnMemoria.clear();
    for (int i = 0; i < categoriasOrdenadas.length; i++) {
      categoriasEnMemoria.add(categoriasOrdenadas[i].copyWith(orden: i + 1));
    }
    _emitir();
  }

  void dispose() {
    _controller.close();
  }
}

Widget _crearWidgetPrueba({
  required CategoriaViewModel viewModel,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE4572E)),
      useMaterial3: true,
    ),
    home: CategoriaListView(
      restaurantId: viewModel.restaurantId,
      viewModel: viewModel,
    ),
  );
}

void main() {
  group('HU24-RF02 Gestión de categorías (backend_reservitta)', () {
    testWidgets('Criterio 3: Muestra mensaje de estado vacío si no hay categorías creadas',
        (WidgetTester tester) async {
      final service = TestCategoriaService(categorias: []);
      final viewModel = CategoriaViewModel(
        restaurantId: 'rest_1',
        categoriaService: service,
      );

      await tester.pumpWidget(_crearWidgetPrueba(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byType(CategoriaEmptyState), findsOneWidget);
      expect(find.text('Aún no hay categorías creadas'), findsOneWidget);
      expect(find.text('Crear primera categoría'), findsOneWidget);

      service.dispose();
    });

    testWidgets('Criterio 1: Lista las categorías existentes y permite agregar nueva',
        (WidgetTester tester) async {
      final service = TestCategoriaService(
        categorias: [
          const CategoriaModel(
            id: 'c1',
            nombre: 'Entradas',
            nombreNormalizado: 'entradas',
            orden: 1,
            tipo: 'alimentos',
          ),
          const CategoriaModel(
            id: 'c2',
            nombre: 'Platos Fuertes',
            nombreNormalizado: 'platos fuertes',
            orden: 2,
            tipo: 'alimentos',
          ),
        ],
      );
      final viewModel = CategoriaViewModel(
        restaurantId: 'rest_1',
        categoriaService: service,
      );

      await tester.pumpWidget(_crearWidgetPrueba(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.text('Entradas'), findsOneWidget);
      expect(find.text('Platos Fuertes'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);

      // Abrir modal de agregar categoría
      await tester.tap(find.text('Nueva Categoría').first);
      await tester.pumpAndSettle();

      expect(find.text('Nombre de la categoría *'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);

      // Ingresar nombre y guardar
      await tester.enterText(find.byType(TextFormField), 'Bebidas Frías');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Bebidas Frías'), findsOneWidget);

      service.dispose();
    });

    testWidgets('Criterio 1: Permite editar categoría existente',
        (WidgetTester tester) async {
      final service = TestCategoriaService(
        categorias: [
          const CategoriaModel(
            id: 'c1',
            nombre: 'Postres',
            nombreNormalizado: 'postres',
            orden: 1,
            tipo: 'postres',
          ),
        ],
      );
      final viewModel = CategoriaViewModel(
        restaurantId: 'rest_1',
        categoriaService: service,
      );

      await tester.pumpWidget(_crearWidgetPrueba(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Abrir edición
      await tester.tap(find.byTooltip('Editar categoría'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Categoría'), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Postres Gourmet');
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();

      expect(find.text('Postres Gourmet'), findsOneWidget);

      service.dispose();
    });

    testWidgets('Criterio 1: Permite reordenar categorías mediante botones de flechas',
        (WidgetTester tester) async {
      final service = TestCategoriaService(
        categorias: [
          const CategoriaModel(
            id: 'c1',
            nombre: 'Primero',
            nombreNormalizado: 'primero',
            orden: 1,
            tipo: 'general',
          ),
          const CategoriaModel(
            id: 'c2',
            nombre: 'Segundo',
            nombreNormalizado: 'segundo',
            orden: 2,
            tipo: 'general',
          ),
        ],
      );
      final viewModel = CategoriaViewModel(
        restaurantId: 'rest_1',
        categoriaService: service,
      );

      await tester.pumpWidget(_crearWidgetPrueba(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Mover hacia abajo el primer elemento
      final flechaBajar = find.byTooltip('Mover hacia abajo').first;
      await tester.tap(flechaBajar);
      await tester.pumpAndSettle();

      expect(viewModel.categoriasEnTiempoReal[0].nombre, 'Segundo');
      expect(viewModel.categoriasEnTiempoReal[1].nombre, 'Primero');

      service.dispose();
    });

    testWidgets('Criterio 2: Confirmación antes de eliminar categoría con alerta de platillos',
        (WidgetTester tester) async {
      final service = TestCategoriaService(
        categorias: [
          const CategoriaModel(
            id: 'c1',
            nombre: 'Pizzas',
            nombreNormalizado: 'pizzas',
            orden: 1,
            tipo: 'alimentos',
          ),
        ],
        platillos: {
          'c1': 5, // Tiene 5 platillos asociados
        },
      );
      final viewModel = CategoriaViewModel(
        restaurantId: 'rest_1',
        categoriaService: service,
      );

      await tester.pumpWidget(_crearWidgetPrueba(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Pulsar eliminar
      await tester.tap(find.byTooltip('Eliminar categoría'));
      await tester.pumpAndSettle();

      // Diálogo de confirmación
      expect(find.text('¿Eliminar categoría?'), findsOneWidget);
      expect(find.textContaining('Pizzas'), findsWidgets);
      expect(find.textContaining('5 platillo(s) asociado(s)'), findsOneWidget);
      expect(find.text('Sí, eliminar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Pizzas'), findsOneWidget);

      // Confirmar eliminación
      await tester.tap(find.byTooltip('Eliminar categoría'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, eliminar'));
      await tester.pumpAndSettle();

      // Ahora está vacía (Criterio 3)
      expect(find.byType(CategoriaEmptyState), findsOneWidget);

      service.dispose();
    });

    testWidgets('Criterio 2: Confirmación antes de eliminar categoría sin platillos asociados',
        (WidgetTester tester) async {
      final service = TestCategoriaService(
        categorias: [
          const CategoriaModel(
            id: 'c1',
            nombre: 'Ensaladas',
            nombreNormalizado: 'ensaladas',
            orden: 1,
            tipo: 'alimentos',
          ),
        ],
        platillos: {
          'c1': 0,
        },
      );
      final viewModel = CategoriaViewModel(
        restaurantId: 'rest_1',
        categoriaService: service,
      );

      await tester.pumpWidget(_crearWidgetPrueba(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Pulsar eliminar
      await tester.tap(find.byTooltip('Eliminar categoría'));
      await tester.pumpAndSettle();

      // Diálogo de confirmación obligatorio
      expect(find.text('¿Eliminar categoría?'), findsOneWidget);
      expect(find.textContaining('Ensaladas'), findsWidgets);
      expect(find.text('Sí, eliminar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Ensaladas'), findsOneWidget);

      // Confirmar eliminación
      await tester.tap(find.byTooltip('Eliminar categoría'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, eliminar'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoriaEmptyState), findsOneWidget);

      service.dispose();
    });
  });
}
