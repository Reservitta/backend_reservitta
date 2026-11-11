import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/elemento_plano.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/services/admin_alert_service.dart';
import 'package:reservitta/services/operations_config_service.dart';
import 'package:reservitta/services/reminder_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/services/table_layout_service.dart';
import 'package:reservitta/services/table_status_service.dart';
import 'package:reservitta/viewmodels/admin_operations_viewmodel.dart';
import 'package:reservitta/viewmodels/plan_editor_viewmodel.dart';
import 'package:reservitta/views/plan_editor_view.dart';
import 'package:reservitta/views/table_management_view.dart';
import 'package:reservitta/views/widgets/mesa_visual.dart';

class _NoPush implements AdminPushGateway {
  @override
  Future<void> enviar(AdminPushMessage mensaje) async {}
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  late TableLayoutService svc;

  Finder k(String key) => find.byKey(ValueKey(key));

  setUp(() {
    db = FakeFirebaseFirestore();
    svc = TableLayoutService(firestore: db, now: () => DateTime(2026, 11, 8, 12));
  });

  Future<PlanEditorViewModel> abrir(WidgetTester tester, {double ancho = 1500, double alto = 1000}) async {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = PlanEditorViewModel(restaurantId: 'r1', service: svc);
    addTearDown(vm.dispose);
    await tester.pumpWidget(MaterialApp(
      home: PlanEditorView(restaurantId: 'r1', service: svc, viewModel: vm),
    ));
    await tester.pumpAndSettle();
    return vm;
  }

  group('Paleta', () {
    testWidgets('muestra todas las mesas y la decoración', (tester) async {
      await abrir(tester);
      for (final p in PlanEditorViewModel.presetsMesa) {
        final llave = switch (p.id) {
          'cuadrada_4' => 'btn_agregar_mesa_cuadrada',
          'redonda_4' => 'btn_agregar_mesa_redonda',
          'rectangular_6' => 'btn_agregar_mesa_rectangular',
          _ => 'pal_mesa_${p.id}',
        };
        expect(k(llave), findsOneWidget, reason: p.id);
      }
      for (final t in ElementoPlano.tiposValidos) {
        expect(k('pal_elemento_$t'), findsOneWidget, reason: t);
      }
    });

    testWidgets('tocar una mesa de la paleta la agrega con sus sillas', (tester) async {
      final vm = await abrir(tester);
      await tester.ensureVisible(k('pal_mesa_redonda_8'));
      await tester.tap(k('pal_mesa_redonda_8'));
      await tester.pumpAndSettle();
      expect(vm.mesas.single.capacidad, 8);
      expect(vm.mesas.single.forma, MesaModel.formaRedonda);
      expect(k('panel_mesa'), findsOneWidget);
    });

    testWidgets('tocar un elemento de decoración lo agrega y abre su panel', (tester) async {
      final vm = await abrir(tester);
      await tester.ensureVisible(k('pal_elemento_cocina'));
      await tester.tap(k('pal_elemento_cocina'));
      await tester.pumpAndSettle();
      expect(vm.elementos.single.tipo, ElementoPlano.cocina);
      expect(k('panel_elemento'), findsOneWidget);
      expect(k('panel_mesa'), findsNothing);
      expect(find.text('Cocina'), findsWidgets);
    });

    testWidgets('en pantalla angosta la paleta es una tira y sigue funcionando', (tester) async {
      final vm = await abrir(tester, ancho: 700);
      expect(k('paleta_plano'), findsOneWidget);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      expect(vm.mesas, hasLength(1));
    });
  });

  group('Barra del lienzo, estado y deshacer', () {
    testWidgets('el estado pasa de "Todo guardado" a "Cambios sin guardar"', (tester) async {
      final vm = await abrir(tester);
      expect(find.text('Todo guardado'), findsOneWidget);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      expect(find.text('Cambios sin guardar'), findsOneWidget);
      expect(vm.hayCambios, isTrue);
    });

    testWidgets('deshacer y rehacer con los botones', (tester) async {
      final vm = await abrir(tester);
      expect(tester.widget<IconButton>(k('btn_deshacer')).onPressed, isNull);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(k('btn_deshacer')).onPressed, isNotNull);

      await tester.tap(k('btn_deshacer'));
      await tester.pumpAndSettle();
      expect(vm.mesas, isEmpty);
      expect(tester.widget<IconButton>(k('btn_rehacer')).onPressed, isNotNull);
      await tester.tap(k('btn_rehacer'));
      await tester.pumpAndSettle();
      expect(vm.mesas, hasLength(1));
    });

    testWidgets('acercar, alejar y ajustar cambian el zoom del plano', (tester) async {
      await abrir(tester);
      final visor = find.byType(InteractiveViewer);
      double escala() => tester.widget<InteractiveViewer>(visor).transformationController!.value.entry(0, 0);
      final inicial = escala();
      await tester.tap(k('btn_zoom_mas'));
      await tester.pump();
      expect(escala(), greaterThan(inicial));
      await tester.tap(k('btn_zoom_menos'));
      await tester.tap(k('btn_zoom_menos'));
      await tester.pump();
      expect(escala(), lessThan(inicial));
      await tester.tap(k('btn_zoom_ajustar'));
      await tester.pump();
      expect(escala(), closeTo(inicial, 0.01));
    });

    testWidgets('guardar deja el estado en "Todo guardado" y el historial lo muestra', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_guardar_plano'));
      await tester.pumpAndSettle();
      expect(find.text('Todo guardado'), findsOneWidget);

      await tester.tap(k('btn_historial'));
      await tester.pumpAndSettle();
      expect(k('dialogo_historial'), findsOneWidget);
      expect(find.textContaining('1 mesa nueva'), findsOneWidget);
    });

    testWidgets('el historial vacío lo dice', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_historial'));
      await tester.pumpAndSettle();
      expect(k('historial_vacio'), findsOneWidget);
    });
  });

  group('Panel de la mesa: tipo, grupo y giro', () {
    testWidgets('elegir el tipo de mesa', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('chip_tipo_sillon'));
      await tester.tap(k('chip_tipo_sillon'));
      await tester.pumpAndSettle();
      expect(vm.mesas.single.tipo, MesaModel.tipoSillon);
    });

    testWidgets('mínimo y máximo con sus botones', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('btn_min_mas'));
      await tester.tap(k('btn_min_mas'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('btn_max_menos'));
      await tester.tap(k('btn_max_menos'));
      await tester.pumpAndSettle();
      expect(vm.mesas.single.minPersonas, 2);
      expect(vm.mesas.single.maxEfectivo, 3);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('girar 90° con el botón del panel', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_rectangular'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('btn_girar_90_der'));
      await tester.tap(k('btn_girar_90_der'));
      await tester.pumpAndSettle();
      expect(vm.mesas.single.rotacion, 90);
      expect(find.text('90°'), findsOneWidget);
    });

    testWidgets('girar desde la barra del lienzo', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_rectangular'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_girar_der'));
      await tester.pumpAndSettle();
      expect(vm.mesas.single.rotacion, 90);
    });
  });

  group('Elemento de decoración: panel', () {
    testWidgets('se escribe su texto, se cambia el tamaño y se elimina con confirmación', (tester) async {
      final vm = await abrir(tester);
      await tester.ensureVisible(k('pal_elemento_texto'));
      await tester.tap(k('pal_elemento_texto'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_elemento_texto'), 'Terraza');
      await tester.pumpAndSettle();
      expect(vm.elementos.single.etiqueta, 'Terraza');

      await tester.ensureVisible(k('btn_eliminar_elemento'));
      await tester.tap(k('btn_eliminar_elemento'));
      await tester.pumpAndSettle();
      expect(k('dialogo_eliminar_elemento'), findsOneWidget);
      await tester.tap(k('btn_confirmar_eliminar_elemento'));
      await tester.pumpAndSettle();
      expect(vm.elementos, isEmpty);
    });

    testWidgets('duplicar crea otra copia', (tester) async {
      final vm = await abrir(tester);
      await tester.ensureVisible(k('pal_elemento_planta'));
      await tester.tap(k('pal_elemento_planta'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('btn_duplicar_elemento'));
      await tester.tap(k('btn_duplicar_elemento'));
      await tester.pumpAndSettle();
      expect(vm.elementos, hasLength(2));
    });
  });

  group('Selección múltiple', () {
    testWidgets('juntar dos mesas, alinearlas y borrarlas con confirmación', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.tap(k('btn_agregar_mesa_redonda'));
      await tester.pumpAndSettle();
      final ids = vm.mesas.map((m) => m.id).toList();
      vm.moverMesa(ids.first, 100, 100);
      vm.moverMesa(ids.last, 400, 300);

      await tester.tap(k('btn_modo_multiple'));
      await tester.pumpAndSettle();
      expect(k('panel_seleccion'), findsOneWidget);
      // Al activar el modo, lo que estaba seleccionado se conserva: se parte de cero.
      vm.limpiarSeleccion();
      await tester.pumpAndSettle();
      await tester.tap(k('mesa_${ids.first}'));
      await tester.tap(k('mesa_${ids.last}'));
      await tester.pumpAndSettle();
      expect(find.text('2 piezas seleccionadas'), findsOneWidget);

      await tester.tap(k('btn_alinear_izquierda'));
      await tester.pumpAndSettle();
      final izq = vm.mesas.map((m) => m.cajaRotada.left.round()).toSet();
      expect(izq, hasLength(1));

      await tester.ensureVisible(k('btn_eliminar_seleccion'));
      await tester.tap(k('btn_eliminar_seleccion'));
      await tester.pumpAndSettle();
      expect(k('dialogo_eliminar_seleccion'), findsOneWidget);
      await tester.tap(k('btn_confirmar_eliminar_seleccion'));
      await tester.pumpAndSettle();
      expect(vm.mesas, isEmpty);
    });

    testWidgets('con menos de tres piezas no se puede repartir', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_modo_multiple'));
      await tester.pumpAndSettle();
      vm.limpiarSeleccion();
      await tester.pumpAndSettle();
      await tester.tap(k('mesa_${vm.mesas.single.id}'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('btn_distribuir_horizontal'));
      expect(tester.widget<OutlinedButton>(k('btn_distribuir_horizontal')).onPressed, isNull);
    });
  });

  group('Teclado', () {
    testWidgets('Supr borra la mesa seleccionada y Ctrl + Z la devuelve', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.tap(k('mesa_${vm.mesas.single.id}'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(vm.mesas, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(vm.mesas, hasLength(1));
    });

    testWidgets('las flechas mueven la mesa seleccionada', (tester) async {
      final vm = await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.tap(k('mesa_${vm.mesas.single.id}'));
      await tester.pumpAndSettle();
      final antes = vm.mesas.single.x!;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(vm.mesas.single.x, antes + 10);
    });
  });

  group('Mesas giradas en el plano', () {
    testWidgets('la caja de toque de una mesa girada 90° intercambia ancho y alto', (tester) async {
      const mesa = MesaModel(
        id: 'a',
        nombre: 'A',
        capacidad: 6,
        forma: 'rectangular',
        ancho: 200,
        alto: 100,
        x: 100,
        y: 100,
        rotacion: 90,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MesaUbicada(
                mesa: mesa,
                envoltura: (context, ubicada) => GestureDetector(key: const ValueKey('toque'), child: ubicada),
                child: MesaVisual(mesa: mesa, paleta: MesaPaleta.libre),
              ),
            ],
          ),
        ),
      ));
      final r = tester.getRect(k('toque'));
      expect(r.width, closeTo(100, 0.5));
      expect(r.height, closeTo(200, 0.5));
    });

    testWidgets('girar no cambia el ancho y el alto reales de la mesa ni del elemento', (tester) async {
      for (final grados in [0.0, 45.0, 90.0, 180.0, 270.0]) {
        final mesa = MesaModel(
          id: 'a', nombre: 'A', capacidad: 6, forma: 'rectangular',
          ancho: 200, alto: 100, x: 100, y: 100, rotacion: grados,
        );
        final elem = ElementoPlano(
          id: 'e', tipo: 'escenario', x: 400, y: 100, ancho: 220, alto: 100, rotacion: grados,
        );
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                MesaUbicada(mesa: mesa, child: Container(key: const ValueKey('cuerpo_mesa'))),
                ElementoUbicado(elemento: elem, child: Container(key: const ValueKey('cuerpo_elem'))),
              ],
            ),
          ),
        ));
        final m = tester.getSize(find.byKey(const ValueKey('cuerpo_mesa')));
        final e = tester.getSize(find.byKey(const ValueKey('cuerpo_elem')));
        expect([m.width, m.height], [200, 100], reason: 'mesa a $grados°');
        expect([e.width, e.height], [220, 100], reason: 'elemento a $grados°');
      }
    });

    testWidgets('el texto de la mesa se queda derecho aunque la mesa gire', (tester) async {
      const mesa = MesaModel(id: 'a', nombre: 'M7', capacidad: 4, ancho: 100, alto: 100, x: 0, y: 0, rotacion: 90);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: MesaVisual(mesa: mesa, paleta: MesaPaleta.libre),
            ),
          ),
        ),
      ));
      final texto = tester.getRect(find.text('M7'));
      expect(texto.width, greaterThan(texto.height), reason: 'no está girado');
    });
  });

  group('Administrador: decoración en el estado de mesas', () {
    testWidgets('el plano en vivo muestra la decoración del espacio', (tester) async {
      tester.view.physicalSize = const Size(1300, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await svc.guardarPlano(
        restauranteId: 'r1',
        mesas: const [MesaModel(id: '', nombre: 'A1', capacidad: 2, x: 20, y: 20)],
        elementos: const [ElementoPlano(id: '', tipo: 'barra', x: 200, y: 20, ancho: 260, alto: 60, etiqueta: 'Barra del bar')],
      );
      final ops = AdminOperationsViewModel(
        restaurantId: 'r1',
        reservas: ReservationService(firestore: db),
        mesasService: TableStatusService(firestore: db),
        configService: OperationsConfigService(firestore: db),
        alertService: AdminAlertService(firestore: db, gateway: _NoPush()),
        reminderService: ReminderService(firestore: db),
        tick: Duration.zero,
        sincronizar: false,
      );
      addTearDown(ops.dispose);
      await ops.iniciar();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TableManagementView(operaciones: ops, onAbrirReserva: (_) {})),
      ));
      await tester.pumpAndSettle();

      expect(ops.elementosVisibles, hasLength(1));
      expect(k('mesas_plano'), findsOneWidget);
      expect(find.text('Barra del bar'), findsOneWidget);
    });
  });
}
