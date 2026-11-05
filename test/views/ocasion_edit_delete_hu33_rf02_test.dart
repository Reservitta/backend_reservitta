import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/experiencia_model.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/services/ocasion_service.dart';
import 'package:reservitta/viewmodels/ocasion_viewmodel.dart';
import 'package:reservitta/views/ocasion_list_view.dart';
import 'package:reservitta/views/widgets/ocasion_form_dialog.dart';

class _FakeOcasionService extends OcasionService {
  final List<OcasionModel> ocasionesMemoria = [];
  bool actualizarLlamado = false;
  bool eliminarLlamado = false;
  bool eliminarExpLlamado = false;

  @override
  Stream<List<OcasionModel>> getOcasionesStream(String restaurantId) {
    return Stream.value(ocasionesMemoria);
  }

  @override
  Future<List<OcasionModel>> getOcasiones(String restaurantId) async {
    return ocasionesMemoria;
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
    final nueva = OcasionModel(
      id: 'oc_${ocasionesMemoria.length + 1}',
      restaurantId: restaurantId,
      nombre: nombre,
      tipoPredefinido: tipoPredefinido ?? 'Otro',
      descripcion: descripcion,
      icono: icono ?? 'celebration',
      experiencias: experiencias,
    );
    ocasionesMemoria.add(nueva);
    return nueva.id;
  }

  @override
  Future<void> actualizarOcasion({
    required String restaurantId,
    required String ocasionId,
    required String nombre,
    String? tipoPredefinido,
    String descripcion = '',
    String? icono,
    required List<ExperienciaModel> experiencias,
  }) async {
    actualizarLlamado = true;
    final idx = ocasionesMemoria.indexWhere((o) => o.id == ocasionId);
    if (idx != -1) {
      ocasionesMemoria[idx] = ocasionesMemoria[idx].copyWith(
        nombre: nombre,
        tipoPredefinido: tipoPredefinido,
        descripcion: descripcion,
        icono: icono,
        experiencias: experiencias,
      );
    }
  }

  @override
  Future<void> eliminarExperienciaIndividual({
    required String restaurantId,
    required String ocasionId,
    required String experienciaId,
  }) async {
    eliminarExpLlamado = true;
    final idx = ocasionesMemoria.indexWhere((o) => o.id == ocasionId);
    if (idx != -1) {
      final actual = ocasionesMemoria[idx];
      final filtradas = actual.experiencias.where((e) => e.id != experienciaId).toList();
      ocasionesMemoria[idx] = actual.copyWith(experiencias: filtradas);
    }
  }

  @override
  Future<void> eliminarOcasion({
    required String restaurantId,
    required String ocasionId,
  }) async {
    eliminarLlamado = true;
    ocasionesMemoria.removeWhere((o) => o.id == ocasionId);
  }
}

void main() {
  group('HU33-RF02: Editar o eliminar ocasión especial y sus experiencias', () {
    late _FakeOcasionService fakeService;
    late OcasionViewModel viewModel;

    setUp(() {
      fakeService = _FakeOcasionService();
      viewModel = OcasionViewModel(
        restaurantId: 'rest_demo',
        ocasionService: fakeService,
      );

      // Precargar una ocasión con 2 experiencias
      fakeService.ocasionesMemoria.add(
        const OcasionModel(
          id: 'oc_1',
          restaurantId: 'rest_demo',
          nombre: 'Cumpleaños',
          tipoPredefinido: 'Cumpleaños',
          descripcion: 'Festejo con nosotros',
          icono: 'cake',
          experiencias: [
            ExperienciaModel(
              id: 'exp_1',
              nombre: 'Pastel con vela',
              precio: 0.0,
              esGratis: true,
            ),
            ExperienciaModel(
              id: 'exp_2',
              nombre: 'Botella de champaña',
              precio: 650.0,
              esGratis: false,
            ),
          ],
        ),
      );
    });

    test('ViewModel: Cargar ocasión para edición precarga datos y experiencias', () {
      final oc = fakeService.ocasionesMemoria.first;
      viewModel.cargarOcasionParaEdicion(oc);

      expect(viewModel.esModoEdicion, isTrue);
      expect(viewModel.ocasionEnEdicionId, equals('oc_1'));
      expect(viewModel.nombrePredefinidoSeleccionado, equals('Cumpleaños'));
      expect(viewModel.experienciasTemporales.length, equals(2));
      expect(viewModel.experienciasTemporales.first.esGratis, isTrue);
    });

    test('ViewModel: Alternar precio de \$0 a monto quita la gratuidad, y \$0 vuelve a Gratis', () {
      final oc = fakeService.ocasionesMemoria.first;
      viewModel.cargarOcasionParaEdicion(oc);

      // 1. Cambiar la primera experiencia de 0 a 150
      viewModel.actualizarExperienciaTemporal(0, nombre: 'Pastel Gourmet', precio: 150.0);
      expect(viewModel.experienciasTemporales[0].esGratis, isFalse);
      expect(viewModel.experienciasTemporales[0].precioFormateado, equals('\$150.00 MXN'));

      // 2. Cambiar la segunda experiencia de 650 a 0 (Cortesía)
      viewModel.actualizarExperienciaTemporal(1, nombre: 'Copa de cortesía', precio: 0.0);
      expect(viewModel.experienciasTemporales[1].esGratis, isTrue);
      expect(viewModel.experienciasTemporales[1].precioFormateado, equals('Gratis'));
    });

    test('ViewModel: Guardar en modo edición invoca actualizarOcasion', () async {
      final oc = fakeService.ocasionesMemoria.first;
      viewModel.cargarOcasionParaEdicion(oc);
      viewModel.setDescripcion('Nueva descripción actualizada');

      final ok = await viewModel.guardarOcasion();
      expect(ok, isTrue);
      expect(fakeService.actualizarLlamado, isTrue);
      expect(fakeService.ocasionesMemoria.first.descripcion, equals('Nueva descripción actualizada'));
    });

    testWidgets('Widget: OcasionListView muestra botones de editar y eliminar ocasión y experiencias', (tester) async {
      viewModel.iniciarEscucha();

      await tester.pumpWidget(
        MaterialApp(
          home: OcasionListView(
            restaurantId: 'rest_demo',
            ocasionService: fakeService,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('card_ocasion_oc_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_editar_ocasion_oc_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_eliminar_ocasion_oc_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_editar_experiencia_exp_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_eliminar_experiencia_exp_1')), findsOneWidget);

      // Eliminar experiencia individual con confirmación
      await tester.tap(find.byKey(const ValueKey('boton_eliminar_experiencia_exp_1')));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar experiencia?'), findsOneWidget);
      await tester.tap(find.text('Eliminar experiencia'));
      await tester.pumpAndSettle();

      expect(fakeService.eliminarExpLlamado, isTrue);
    });

    testWidgets('Widget: Eliminar ocasión completa muestra diálogo de confirmación con advertencia histórica', (tester) async {
      viewModel.iniciarEscucha();

      await tester.pumpWidget(
        MaterialApp(
          home: OcasionListView(
            restaurantId: 'rest_demo',
            ocasionService: fakeService,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('boton_eliminar_ocasion_oc_1')));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar ocasión especial?'), findsOneWidget);
      expect(find.textContaining('conservarán su dato histórico intacto'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(fakeService.eliminarLlamado, isTrue);
    });
  });
}

