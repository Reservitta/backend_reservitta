import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/experiencia_model.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/services/ocasion_service.dart';
import 'package:reservitta/viewmodels/ocasion_viewmodel.dart';
import 'package:reservitta/views/ocasion_list_view.dart';
import 'package:reservitta/views/widgets/ocasion_form_dialog.dart';

class MockOcasionService extends OcasionService {
  final List<OcasionModel> ocasiones = [];
  final StreamController<List<OcasionModel>> _ctrl = StreamController<List<OcasionModel>>.broadcast();

  void _emitir() {
    _ctrl.add(List.unmodifiable(ocasiones));
  }

  @override
  Stream<List<OcasionModel>> getOcasionesStream(String restaurantId) {
    Future.microtask(_emitir);
    return _ctrl.stream;
  }

  @override
  Future<String> crearOcasion({
    required String restaurantId,
    required String nombre,
    String? tipoPredefinido,
    String descripcion = '',
    String? icono,
    required List<ExperienciaModel> experiencias,
  }) async {
    final ocasionId = 'oc_${ocasiones.length + 1}';
    final nueva = OcasionModel(
      id: ocasionId,
      restaurantId: restaurantId,
      nombre: nombre,
      tipoPredefinido: tipoPredefinido ?? 'Otro',
      descripcion: descripcion,
      icono: icono ?? 'celebration',
      activo: true,
      experiencias: experiencias.map((e) => e.copyWith(esGratis: e.precio <= 0)).toList(),
    );
    ocasiones.add(nueva);
    _emitir();
    return ocasionId;
  }

  @override
  Future<void> eliminarOcasion({
    required String restaurantId,
    required String ocasionId,
  }) async {
    ocasiones.removeWhere((o) => o.id == ocasionId);
    _emitir();
  }
}

void main() {
  group('72.- HU33-RF01: Crear ocasión especial y sus experiencias (Pruebas de Widgets e Interfaz)', () {
    late MockOcasionService mockService;
    const adminRestaurantId = 'rest_admin_123';

    setUp(() {
      mockService = MockOcasionService();
    });

    testWidgets('UI: Muestra estado vacío cuando el restaurante no tiene ocasiones creadas', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: OcasionListView(
            restaurantId: adminRestaurantId,
            ocasionService: mockService,
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('vista_vacia_ocasiones')), findsOneWidget);
      expect(find.text('Aún no tienes ocasiones especiales creadas'), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_crear_primera_ocasion')), findsOneWidget);
    });

    testWidgets('UI Criterios 1, 2, 3, 4, 6: Diálogo de creación con nombres predefinidos, stepper de experiencias y validaciones', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final vm = OcasionViewModel(restaurantId: adminRestaurantId, ocasionService: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const ValueKey('btn_abrir_modal_test'),
                onPressed: () => OcasionFormDialog.show(ctx, viewModel: vm),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir modal de creación
      await tester.tap(find.byKey(const ValueKey('btn_abrir_modal_test')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialogo_crear_ocasion')), findsOneWidget);

      // Criterio 4: Inicialmente botón guardar deshabilitado (sin experiencias agregadas)
      final btnGuardar = find.byKey(const ValueKey('boton_guardar_ocasion'));
      expect(btnGuardar, findsOneWidget);
      expect(tester.widget<FilledButton>(btnGuardar).onPressed, isNull);
      expect(find.byKey(const ValueKey('aviso_sin_experiencias')), findsOneWidget);

      // Criterio 6: Botón "Agregar experiencia"
      final btnAgregarExp = find.byKey(const ValueKey('boton_agregar_experiencia'));
      expect(btnAgregarExp, findsOneWidget);

      // 1. Agregar primera experiencia con precio 0 (Criterio 3: Gratis)
      await tester.tap(btnAgregarExp);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialogo_nueva_experiencia')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('input_nombre_experiencia')), 'Pastel de Cumpleaños');
      await tester.enterText(find.byKey(const ValueKey('input_precio_experiencia')), '0');
      await tester.pumpAndSettle();

      // Criterio 3: Verificamos etiqueta "Gratis" en tiempo real
      expect(find.text('Gratis'), findsWidgets);

      await tester.enterText(find.byKey(const ValueKey('input_descripcion_experiencia')), 'Pastel individual con velita');
      await tester.tap(find.byKey(const ValueKey('boton_confirmar_agregar_experiencia')));
      await tester.pumpAndSettle();

      // La primera experiencia aparece en la lista
      expect(find.text('Pastel de Cumpleaños'), findsOneWidget);
      expect(find.text('Gratis'), findsWidgets);

      // 2. Agregar segunda experiencia antes de guardar (Criterio 6)
      await tester.tap(btnAgregarExp);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('input_nombre_experiencia')), 'Mañanitas con Mariachi');
      await tester.enterText(find.byKey(const ValueKey('input_precio_experiencia')), '350.00');
      await tester.enterText(find.byKey(const ValueKey('input_descripcion_experiencia')), 'Canción sorpresa en la mesa');
      await tester.tap(find.byKey(const ValueKey('boton_confirmar_agregar_experiencia')));
      await tester.pumpAndSettle();

      expect(find.text('Mañanitas con Mariachi'), findsOneWidget);
      expect(find.text('\$350.00 MXN'), findsOneWidget);

      // Ahora que hay 2 experiencias y nombre por defecto 'Cumpleaños', el botón Guardar debe estar habilitado
      expect(tester.widget<FilledButton>(btnGuardar).onPressed, isNotNull);

      // 3. Guardar ocasión
      await tester.tap(btnGuardar);
      await tester.pumpAndSettle();

      // El diálogo se cierra
      expect(find.byKey(const ValueKey('dialogo_crear_ocasion')), findsNothing);

      // Verificamos que se guardó en el servicio
      expect(mockService.ocasiones.length, equals(1));
      expect(mockService.ocasiones.first.nombre, equals('Cumpleaños'));
      expect(mockService.ocasiones.first.experiencias.length, equals(2));
      expect(mockService.ocasiones.first.experiencias[0].esGratis, isTrue);
      expect(mockService.ocasiones.first.experiencias[1].precio, equals(350.0));
    });

    testWidgets('UI Criterio 1: Opción "Otro" permite ingresar nombre personalizado', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final vm = OcasionViewModel(restaurantId: adminRestaurantId, ocasionService: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const ValueKey('btn_abrir_modal_otro'),
                onPressed: () => OcasionFormDialog.show(ctx, viewModel: vm),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('btn_abrir_modal_otro')));
      await tester.pumpAndSettle();

      // Cambiar directamente en el viewModel o vía dropdown
      vm.setNombrePredefinido('Otro');
      await tester.pumpAndSettle();

      // Debe aparecer el campo de texto para nombre personalizado
      final inputPersonalizado = find.byKey(const ValueKey('input_nombre_ocasion_personalizado'));
      expect(inputPersonalizado, findsOneWidget);

      await tester.enterText(inputPersonalizado, 'Reunión de Negocios VIP');
      await tester.pumpAndSettle();

      expect(vm.nombreFinal, equals('Reunión de Negocios VIP'));
    });

    testWidgets('UI Flujo Completo: Crear ocasión desde OcasionListView y verla reflejada en la tarjeta', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final vm = OcasionViewModel(restaurantId: adminRestaurantId, ocasionService: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: OcasionListView(
            restaurantId: adminRestaurantId,
            ocasionService: mockService,
            viewModel: vm,
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Presionar botón Nueva ocasión en el AppBar o empty state
      final btnNueva = find.byKey(const ValueKey('boton_crear_primera_ocasion'));
      expect(btnNueva, findsOneWidget);
      await tester.tap(btnNueva);
      await tester.pumpAndSettle();

      // Agregar experiencia
      await tester.tap(find.byKey(const ValueKey('boton_agregar_experiencia')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('input_nombre_experiencia')), 'Decoración con Rosas');
      await tester.enterText(find.byKey(const ValueKey('input_precio_experiencia')), '200');
      await tester.tap(find.byKey(const ValueKey('boton_confirmar_agregar_experiencia')));
      await tester.pumpAndSettle();

      // Guardar ocasión
      await tester.tap(find.byKey(const ValueKey('boton_guardar_ocasion')));
      await tester.pumpAndSettle();

      // Ahora debe mostrarse la tarjeta de la ocasión en la lista
      expect(find.byKey(const ValueKey('vista_vacia_ocasiones')), findsNothing);
      expect(find.text('Cumpleaños'), findsOneWidget);
      expect(find.text('Decoración con Rosas'), findsOneWidget);
      expect(find.text('\$200.00 MXN'), findsOneWidget);
    });
  });
}
