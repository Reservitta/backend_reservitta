import 'dart:ui' show Rect;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/elemento_plano.dart';
import 'package:reservitta/models/plantillas_plano.dart';
import 'package:reservitta/services/table_layout_service.dart';
import 'package:reservitta/viewmodels/plan_editor_viewmodel.dart';
import 'package:reservitta/views/plan_editor_view.dart';

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  late TableLayoutService svc;

  Finder k(String key) => find.byKey(ValueKey(key));

  setUp(() {
    db = FakeFirebaseFirestore();
    svc = TableLayoutService(firestore: db, now: () => DateTime(2026, 11, 8, 12));
  });

  Future<PlanEditorViewModel> crear() async {
    final vm = PlanEditorViewModel(restaurantId: 'r1', service: svc);
    addTearDown(vm.dispose);
    await vm.cargar();
    return vm;
  }

  group('Plantillas: datos', () {
    test('hay varias plantillas con nombre y descripción', () {
      expect(PlantillaPlano.todas.length, greaterThanOrEqualTo(5));
      expect(PlantillaPlano.todas.map((p) => p.id).toSet(), hasLength(PlantillaPlano.todas.length));
      for (final p in PlantillaPlano.todas) {
        expect(p.nombre, isNotEmpty);
        expect(p.descripcion, isNotEmpty);
        expect(p.mesas, isNotEmpty, reason: p.id);
      }
    });

    for (final p in PlantillaPlano.todas) {
      test('${p.nombre}: usa mesas de la paleta y todo cabe en el lienzo', () {
        final ids = PlanEditorViewModel.presetsMesa.map((m) => m.id).toSet();
        for (final m in p.mesas) {
          expect(ids, contains(m.preset), reason: '${p.id}: ${m.preset}');
          final preset = PlanEditorViewModel.presetsMesa.firstWhere((x) => x.id == m.preset);
          expect(m.x, greaterThanOrEqualTo(0));
          expect(m.y, greaterThanOrEqualTo(0));
          expect(m.x + preset.ancho, lessThanOrEqualTo(PlanEditorViewModel.anchoLienzo), reason: p.id);
          expect(m.y + preset.alto, lessThanOrEqualTo(PlanEditorViewModel.altoLienzo), reason: p.id);
        }
        for (final e in p.elementos) {
          expect(ElementoPlano.tiposValidos, contains(e.tipo), reason: p.id);
          final medidas = PlantillaPlano.medidasDe(e);
          final elemento = ElementoPlano(id: 'x', tipo: e.tipo, x: e.x, y: e.y, ancho: medidas.ancho, alto: medidas.alto);
          expect(elemento.validar(zonaIds: const {}), isEmpty, reason: '${p.id}: ${e.tipo} debe ser válido');
          expect(e.x + medidas.ancho, lessThanOrEqualTo(PlanEditorViewModel.anchoLienzo), reason: '${p.id}: ${e.tipo}');
          expect(e.y + medidas.alto, lessThanOrEqualTo(PlanEditorViewModel.altoLienzo), reason: '${p.id}: ${e.tipo}');
        }
      });

      test('${p.nombre}: las mesas no se montan unas sobre otras', () {
        final cajas = <Rect>[
          for (final m in p.mesas)
            Rect.fromLTWH(
              m.x,
              m.y,
              PlanEditorViewModel.presetsMesa.firstWhere((x) => x.id == m.preset).ancho,
              PlanEditorViewModel.presetsMesa.firstWhere((x) => x.id == m.preset).alto,
            ),
        ];
        for (var i = 0; i < cajas.length; i++) {
          for (var j = i + 1; j < cajas.length; j++) {
            expect(cajas[i].overlaps(cajas[j]), isFalse, reason: '${p.id}: mesas $i y $j');
          }
        }
      });
    }
  });

  group('Plantillas: aplicar', () {
    test('en un plano vacío agrega todas las piezas y todas son válidas', () async {
      for (final p in PlantillaPlano.todas) {
        final vm = await crear();
        vm.aplicarPlantilla(p, reemplazar: false);
        expect(vm.mesas, hasLength(p.mesas.length), reason: p.id);
        expect(vm.elementos, hasLength(p.elementos.length), reason: p.id);
        expect(vm.mesasConError, isEmpty, reason: p.id);
        expect(vm.mesas.map((m) => m.nombre).toSet(), hasLength(p.mesas.length), reason: 'nombres únicos en ${p.id}');
        expect(vm.hayCambios, isTrue);
      }
    });

    test('deja todo seleccionado para moverlo junto y se puede deshacer', () async {
      final vm = await crear();
      vm.aplicarPlantilla(PlantillaPlano.cafeteria, reemplazar: false);
      expect(vm.cantidadSeleccionada, PlantillaPlano.cafeteria.piezas);
      vm.deshacer();
      expect(vm.mesas, isEmpty);
      expect(vm.elementos, isEmpty);
    });

    test('agregar la plantilla conserva lo que ya había', () async {
      final vm = await crear();
      vm.agregarMesa();
      vm.aplicarPlantilla(PlantillaPlano.bar, reemplazar: false);
      expect(vm.mesas, hasLength(1 + PlantillaPlano.bar.mesas.length));
    });

    test('reemplazar quita lo que había en el espacio', () async {
      final vm = await crear();
      vm.agregarMesa();
      vm.agregarElemento(ElementoPlano.planta);
      expect(vm.espacioActivoConPiezas, isTrue);
      vm.aplicarPlantilla(PlantillaPlano.terraza, reemplazar: true);
      expect(vm.mesas, hasLength(PlantillaPlano.terraza.mesas.length));
      expect(vm.elementos, hasLength(PlantillaPlano.terraza.elementos.length));
    });

    test('reemplazar solo toca el espacio activo', () async {
      final vm = await crear();
      await vm.agregarZona('Piso 1');
      vm.agregarMesa();
      await vm.agregarZona('Patio');
      vm.agregarMesa();
      vm.aplicarPlantilla(PlantillaPlano.cafeteria, reemplazar: true);
      final piso1 = vm.zonas.first.id;
      expect(vm.mesas.where((m) => m.zonaId == piso1), hasLength(1));
      expect(vm.mesas.where((m) => m.zonaId == vm.zonaActivaId), hasLength(PlantillaPlano.cafeteria.mesas.length));
    });

    test('las piezas de la plantilla van al espacio activo', () async {
      final vm = await crear();
      await vm.agregarZona('Terraza');
      vm.aplicarPlantilla(PlantillaPlano.terraza, reemplazar: false);
      expect(vm.mesas.every((m) => m.zonaId == vm.zonaActivaId), isTrue);
      expect(vm.elementos.every((e) => e.zonaId == vm.zonaActivaId), isTrue);
    });

    test('se puede guardar y se recupera igual', () async {
      final vm = await crear();
      vm.aplicarPlantilla(PlantillaPlano.familiar, reemplazar: false);
      expect(await vm.guardar(), isTrue);
      final otra = await crear();
      expect(otra.mesas, hasLength(PlantillaPlano.familiar.mesas.length));
      expect(otra.elementos, hasLength(PlantillaPlano.familiar.elementos.length));
    });
  });

  group('Plantillas: pantalla', () {
    Future<PlanEditorViewModel> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = PlanEditorViewModel(restaurantId: 'r1', service: svc);
      addTearDown(vm.dispose);
      await tester.pumpWidget(MaterialApp(home: PlanEditorView(restaurantId: 'r1', service: svc, viewModel: vm)));
      await tester.pumpAndSettle();
      return vm;
    }

    testWidgets('el botón abre la lista y elegir una la aplica en un plano vacío', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_plantillas'));
      await tester.pumpAndSettle();
      expect(k('dialogo_plantillas'), findsOneWidget);
      for (final p in PlantillaPlano.todas) {
        expect(k('plantilla_${p.id}'), findsOneWidget, reason: p.id);
      }

      await tester.tap(k('plantilla_cafeteria'));
      await tester.pumpAndSettle();
      expect(k('dialogo_aplicar_plantilla'), findsNothing, reason: 'el plano estaba vacío');
      expect(vm.mesas, hasLength(PlantillaPlano.cafeteria.mesas.length));
      expect(find.text('Cambios sin guardar'), findsOneWidget);
    });

    testWidgets('con piezas en el espacio pregunta si reemplaza o agrega', (tester) async {
      final vm = await abrir(tester);
      vm.agregarMesa();
      await tester.pumpAndSettle();

      await tester.tap(k('btn_plantillas'));
      await tester.pumpAndSettle();
      await tester.tap(k('plantilla_eventos'));
      await tester.pumpAndSettle();
      expect(k('dialogo_aplicar_plantilla'), findsOneWidget);

      await tester.tap(k('btn_plantilla_agregar'));
      await tester.pumpAndSettle();
      expect(vm.mesas, hasLength(1 + PlantillaPlano.eventos.mesas.length));
    });

    testWidgets('reemplazar desde el diálogo deja solo la plantilla', (tester) async {
      final vm = await abrir(tester);
      vm.agregarMesa();
      await tester.pumpAndSettle();
      await tester.tap(k('btn_plantillas'));
      await tester.pumpAndSettle();
      await tester.tap(k('plantilla_bar'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_plantilla_reemplazar'));
      await tester.pumpAndSettle();
      expect(vm.mesas, hasLength(PlantillaPlano.bar.mesas.length));
    });

    testWidgets('cancelar no cambia nada', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_plantillas'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_cancelar_plantillas'));
      await tester.pumpAndSettle();
      expect(vm.mesas, isEmpty);
      expect(vm.hayCambios, isFalse);
    });
  });
}
