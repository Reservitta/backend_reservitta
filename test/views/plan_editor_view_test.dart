
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/services/admin_alert_service.dart';
import 'package:reservitta/services/operations_config_service.dart';
import 'package:reservitta/services/reminder_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/services/table_layout_service.dart';
import 'package:reservitta/services/table_status_service.dart';
import 'package:reservitta/viewmodels/admin_operations_viewmodel.dart';
import 'package:reservitta/views/plan_editor_view.dart';
import 'package:reservitta/views/table_management_view.dart';

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

  void pantalla(WidgetTester tester, {double ancho = 1300, double alto = 900}) {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> abrir(WidgetTester tester, {double ancho = 1300}) async {
    pantalla(tester, ancho: ancho);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlanEditorView(restaurantId: 'r1', service: svc),
                ),
              ),
              child: const Text('abrir editor'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir editor'));
    await tester.pumpAndSettle();
  }

  Future<List<Map<String, dynamic>>> guardadas() async {
    final s = await db.collection('restaurants').doc('r1').collection('mesas').get();
    return [for (final d in s.docs) {...d.data(), 'id': d.id}];
  }

  group('Lienzo vacío', () {
    testWidgets('muestra la guía y los botones para agregar mesas', (tester) async {
      await abrir(tester);
      expect(k('plano_vacio'), findsOneWidget);
      expect(k('texto_sin_espacios'), findsOneWidget);
      for (final f in ['cuadrada', 'redonda', 'rectangular']) {
        expect(k('btn_agregar_mesa_$f'), findsOneWidget);
      }
      // Sin cambios no se puede guardar ni descartar.
      expect(tester.widget<FilledButton>(k('btn_guardar_plano')).onPressed, isNull);
      expect(tester.widget<TextButton>(k('btn_descartar_plano')).onPressed, isNull);
    });
  });

  group('Agregar y editar mesas', () {
    testWidgets('cada forma agrega una mesa y abre su panel', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.tap(k('btn_agregar_mesa_redonda'));
      await tester.tap(k('btn_agregar_mesa_rectangular'));
      await tester.pumpAndSettle();
      expect(k('mesa_tmp_1'), findsOneWidget);
      expect(k('mesa_tmp_2'), findsOneWidget);
      expect(k('mesa_tmp_3'), findsOneWidget);
      expect(k('plano_vacio'), findsNothing);
      expect(k('panel_mesa'), findsOneWidget);
      expect(find.text('Mesa 3'), findsWidgets);
      // La rectangular muestra ancho y alto por separado.
      expect(k('slider_alto'), findsOneWidget);
    });

    testWidgets('las sillas suben y bajan con los botones y se muestran en la mesa', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(k('texto_capacidad')).data, '4');
      await tester.tap(k('btn_capacidad_mas'));
      await tester.tap(k('btn_capacidad_mas'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(k('texto_capacidad')).data, '6');
      expect(find.descendant(of: k('mesa_tmp_1'), matching: find.text('6 sillas')), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.tap(k('btn_capacidad_menos'));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(k('texto_capacidad')).data, '1');
      expect(find.descendant(of: k('mesa_tmp_1'), matching: find.text('1 silla')), findsOneWidget);
      expect(tester.widget<IconButton>(k('btn_capacidad_menos')).onPressed, isNull);
    });

    testWidgets('cambiar la forma redibuja la mesa', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      expect(k('slider_alto'), findsNothing);
      await tester.tap(k('chip_forma_rectangular'));
      await tester.pumpAndSettle();
      expect(k('slider_alto'), findsOneWidget);
      await tester.tap(k('chip_forma_redonda'));
      await tester.pumpAndSettle();
      expect(k('slider_alto'), findsNothing);
      final deco = tester.widget<Container>(find.descendant(
        of: k('mesa_tmp_1'),
        matching: find.byType(Container),
      ).first).decoration as BoxDecoration;
      expect(deco.shape, BoxShape.circle);
    });

    testWidgets('arrastrar una mesa la mueve y la alinea a la cuadrícula', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      final antes = tester.getTopLeft(k('mesa_tmp_1'));
      await tester.drag(k('mesa_tmp_1'), const Offset(120, 80));
      await tester.pumpAndSettle();
      final despues = tester.getTopLeft(k('mesa_tmp_1'));
      expect(despues.dx, greaterThan(antes.dx + 50));
      expect(despues.dy, greaterThan(antes.dy + 30));
    });

    testWidgets('el nombre se edita y un nombre repetido muestra el error', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_mesa_nombre'), 'Barra 1');
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('mesa_tmp_2'), matching: find.text('Barra 1')), findsOneWidget);
      await tester.enterText(k('campo_mesa_nombre'), 'mesa 1');
      await tester.pumpAndSettle();
      expect(find.text('Ya hay una mesa llamada "mesa 1".'), findsOneWidget);
      await tester.enterText(k('campo_mesa_nombre'), '');
      await tester.pumpAndSettle();
      expect(find.text('Escribe el nombre o número de la mesa.'), findsOneWidget);
    });

    testWidgets('al cambiar de mesa el campo muestra su nombre', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.tap(k('btn_agregar_mesa_redonda'));
      await tester.pumpAndSettle();
      await tester.tap(k('mesa_tmp_1'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(k('campo_mesa_nombre')).controller!.text, 'Mesa 1');
      await tester.tap(k('mesa_tmp_2'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(k('campo_mesa_nombre')).controller!.text, 'Mesa 2');
    });

    testWidgets('tocar el fondo deselecciona y cerrar el panel también', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      expect(k('panel_mesa'), findsOneWidget);
      await tester.tap(k('btn_cerrar_panel'));
      await tester.pumpAndSettle();
      expect(k('panel_mesa'), findsNothing);
      await tester.tap(k('mesa_tmp_1'));
      await tester.pumpAndSettle();
      expect(k('panel_mesa'), findsOneWidget);
      await tester.tapAt(const Offset(700, 700));
      await tester.pumpAndSettle();
      expect(k('panel_mesa'), findsNothing);
    });

    testWidgets('duplicar crea otra mesa con otro nombre', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_redonda'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_duplicar_mesa'));
      await tester.pumpAndSettle();
      expect(k('mesa_tmp_2'), findsOneWidget);
      expect(tester.widget<TextField>(k('campo_mesa_nombre')).controller!.text, isNot('Mesa 1'));
    });

    testWidgets('eliminar pide confirmación', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_eliminar_mesa'));
      await tester.pumpAndSettle();
      expect(k('dialogo_eliminar_mesa'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(k('mesa_tmp_1'), findsOneWidget);
      await tester.tap(k('btn_eliminar_mesa'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_confirmar_eliminar_mesa'));
      await tester.pumpAndSettle();
      expect(k('mesa_tmp_1'), findsNothing);
      expect(k('plano_vacio'), findsOneWidget);
    });

    testWidgets('combinar mesas con los chips', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('switch_combinable'));
      await tester.tap(k('switch_combinable'));
      await tester.pumpAndSettle();
      expect(k('texto_sin_candidatas'), findsOneWidget);
      await tester.tap(k('mesa_tmp_1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('switch_combinable'));
      await tester.tap(k('switch_combinable'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('chip_combinar_tmp_2'));
      expect(k('chip_combinar_tmp_2'), findsOneWidget);
      await tester.tap(k('chip_combinar_tmp_2'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(k('chip_combinar_tmp_2')).selected, isTrue);
    });
  });

  group('Espacios', () {
    testWidgets('crear un espacio con el diálogo agrega su pestaña', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_espacio'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_espacio_nombre'), 'Segundo piso');
      await tester.tap(k('btn_guardar_espacio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Segundo piso (0)'), findsOneWidget);
      expect(k('texto_sin_espacios'), findsNothing);
    });

    testWidgets('un espacio vacío o repetido muestra el error en el diálogo', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_espacio'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_guardar_espacio'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el nombre del espacio.'), findsOneWidget);
      await tester.enterText(k('campo_espacio_nombre'), 'Patio');
      await tester.tap(k('btn_guardar_espacio'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_agregar_espacio'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_espacio_nombre'), 'PATIO');
      await tester.tap(k('btn_guardar_espacio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ya existe un espacio'), findsOneWidget);
      expect(k('dialogo_espacio'), findsOneWidget);
      await tester.tap(k('btn_cancelar_espacio'));
      await tester.pumpAndSettle();
      expect(k('dialogo_espacio'), findsNothing);
    });

    testWidgets('cada espacio tiene sus propias mesas', (tester) async {
      await abrir(tester);
      Future<void> espacio(String nombre) async {
        await tester.tap(k('btn_agregar_espacio'));
        await tester.pumpAndSettle();
        await tester.enterText(k('campo_espacio_nombre'), nombre);
        await tester.tap(k('btn_guardar_espacio'));
        await tester.pumpAndSettle();
      }

      await espacio('Planta baja');
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await espacio('Patio');
      await tester.tap(k('btn_agregar_mesa_redonda'));
      await tester.tap(k('btn_agregar_mesa_redonda'));
      await tester.pumpAndSettle();
      expect(k('mesa_tmp_1'), findsNothing);
      expect(k('mesa_tmp_2'), findsOneWidget);
      expect(k('mesa_tmp_3'), findsOneWidget);
      expect(find.textContaining('Patio (2)'), findsOneWidget);
      expect(find.textContaining('Planta baja (1)'), findsOneWidget);

      final pestanaPlanta = find.textContaining('Planta baja (1)');
      await tester.tap(pestanaPlanta);
      await tester.pumpAndSettle();
      expect(k('mesa_tmp_1'), findsOneWidget);
      expect(k('mesa_tmp_2'), findsNothing);
    });

    testWidgets('renombrar y eliminar un espacio vacío', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_espacio'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_espacio_nombre'), 'Patio');
      await tester.tap(k('btn_guardar_espacio'));
      await tester.pumpAndSettle();

      await tester.tap(k('btn_renombrar_espacio'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_espacio_nombre'), 'Jardín');
      await tester.tap(k('btn_guardar_espacio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jardín (0)'), findsOneWidget);

      await tester.tap(k('btn_eliminar_espacio'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_confirmar_eliminar_espacio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jardín'), findsNothing);
    });

    testWidgets('no deja eliminar un espacio con mesas y explica por qué', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_espacio'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_espacio_nombre'), 'Patio');
      await tester.tap(k('btn_guardar_espacio'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_eliminar_espacio'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_confirmar_eliminar_espacio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('todavía tiene 1 mesa'), findsOneWidget);
      expect(find.textContaining('Patio (1)'), findsOneWidget);
    });
  });

  group('Guardar y descartar', () {
    testWidgets('guarda el plano completo en Firestore', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_redonda'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_mesa_nombre'), 'Barra');
      await tester.tap(k('btn_capacidad_mas'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_agregar_mesa_rectangular'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(k('btn_guardar_plano')).onPressed, isNotNull);

      await tester.tap(k('btn_guardar_plano'));
      await tester.pumpAndSettle();

      final mesas = await guardadas();
      expect(mesas, hasLength(2));
      final barra = mesas.firstWhere((m) => m['nombre'] == 'Barra');
      expect(barra['forma'], 'redonda');
      expect(barra['capacidad'], 5);
      expect(mesas.any((m) => m['forma'] == 'rectangular'), isTrue);
      expect(find.text('Plano guardado.'), findsOneWidget);
      expect(tester.widget<FilledButton>(k('btn_guardar_plano')).onPressed, isNull);
    });

    testWidgets('con un error no guarda nada y muestra el motivo', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.enterText(k('campo_mesa_nombre'), 'mesa 1');
      await tester.pumpAndSettle();
      await tester.tap(k('btn_guardar_plano'));
      await tester.pumpAndSettle();
      expect(k('error_plano'), findsOneWidget);
      expect(find.descendant(of: k('error_plano'), matching: find.textContaining('Ya hay una mesa')),
          findsOneWidget);
      expect(await guardadas(), isEmpty);
    });

    testWidgets('descartar quita las mesas sin guardar', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_descartar_plano'));
      await tester.pumpAndSettle();
      expect(k('mesa_tmp_1'), findsNothing);
      expect(k('plano_vacio'), findsOneWidget);
    });

    testWidgets('abre con las mesas ya guardadas y las pone en su lugar', (tester) async {
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        const MesaModel(id: '', nombre: 'A1', capacidad: 2, x: 100, y: 100),
        const MesaModel(id: '', nombre: 'A2', capacidad: 8, forma: 'redonda', x: 400, y: 200),
      ]);
      await abrir(tester);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('8 sillas'), findsOneWidget);
      expect(k('plano_vacio'), findsNothing);
      expect(tester.widget<FilledButton>(k('btn_guardar_plano')).onPressed, isNull);
    });

    testWidgets('editar una mesa guardada y volver a guardar la actualiza', (tester) async {
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        const MesaModel(id: '', nombre: 'A1', capacidad: 2, x: 100, y: 100),
      ]);
      await abrir(tester);
      final id = (await guardadas()).single['id'] as String;
      await tester.tap(k('mesa_$id'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_capacidad_mas'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_guardar_plano'));
      await tester.pumpAndSettle();
      final despues = await guardadas();
      expect(despues, hasLength(1));
      expect(despues.single['capacidad'], 3);
    });
  });

  group('Salir con cambios sin guardar', () {
    testWidgets('pide confirmación y se puede seguir editando', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(k('dialogo_cambios_sin_guardar'), findsOneWidget);
      await tester.tap(k('btn_seguir_editando'));
      await tester.pumpAndSettle();
      expect(k('dialogo_cambios_sin_guardar'), findsNothing);
      expect(find.text('Plano de mesas'), findsOneWidget);
    });

    testWidgets('salir sin guardar descarta y cierra el editor', (tester) async {
      await abrir(tester);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(k('btn_salir_sin_guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Plano de mesas'), findsNothing);
      expect(await guardadas(), isEmpty);
    });

    testWidgets('sin cambios sale directo', (tester) async {
      await abrir(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(k('dialogo_cambios_sin_guardar'), findsNothing);
      expect(find.text('Plano de mesas'), findsNothing);
    });
  });

  group('Pantalla angosta', () {
    testWidgets('el panel de la mesa aparece debajo del plano', (tester) async {
      await abrir(tester, ancho: 500);
      await tester.tap(k('btn_agregar_mesa_cuadrada'));
      await tester.pumpAndSettle();
      expect(k('panel_mesa'), findsOneWidget);
      expect(tester.getTopLeft(k('panel_mesa')).dy, greaterThan(tester.getTopLeft(k('plano_lienzo')).dy));
    });
  });

  group('Sillas dibujadas', () {
    const tam = Size(100, 100);

    test('hay una silla por cada lugar, fuera de la mesa', () {
      for (final forma in ['cuadrada', 'redonda', 'rectangular']) {
        for (final n in [1, 2, 4, 6, 12, 50]) {
          final sillas = SillasPainter.posiciones(n, forma, tam);
          expect(sillas, hasLength(n), reason: '$forma/$n');
          for (final p in sillas) {
            final dentro = forma == 'redonda'
                // En una mesa redonda, "dentro" es estar a menos de un radio del centro.
                ? (p - const Offset(50, 50)).distance <= 50
                : p.dx > 0 && p.dx < 100 && p.dy > 0 && p.dy < 100;
            expect(dentro, isFalse, reason: '$forma/$n en $p');
          }
        }
      }
    });

    test('las sillas se reparten por todos los lados de una mesa cuadrada', () {
      final s = SillasPainter.posiciones(8, 'cuadrada', tam);
      expect(s.any((p) => p.dy < 0), isTrue);
      expect(s.any((p) => p.dy > 100), isTrue);
      expect(s.any((p) => p.dx < 0), isTrue);
      expect(s.any((p) => p.dx > 100), isTrue);
    });

    test('una capacidad fuera de rango no rompe el dibujo', () {
      expect(SillasPainter.posiciones(-3, 'cuadrada', tam), isEmpty);
      expect(SillasPainter.posiciones(500, 'redonda', tam), hasLength(50));
    });
  });

  group('Acceso desde la vista de mesas del administrador', () {
    testWidgets('sin mesas ofrece "Crear mi plano" y abre el editor', (tester) async {
      pantalla(tester);
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
      expect(find.text('Crear mi plano'), findsOneWidget);
      expect(find.textContaining('Toca "Crear mi plano"'), findsOneWidget);
      await tester.tap(k('btn_editar_plano'));
      await tester.pumpAndSettle();
      expect(find.text('Plano de mesas'), findsOneWidget);
    });

    AdminOperationsViewModel crearOps() {
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
      return ops;
    }

    testWidgets('las mesas sin espacio no se esconden: tienen su propia pestaña', (tester) async {
      pantalla(tester);
      final patio = await svc.crearZona('r1', 'Patio');
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        MesaModel(id: '', nombre: 'P1', capacidad: 4, x: 20, y: 20, zonaId: patio.id),
        const MesaModel(id: '', nombre: 'Suelta 1', capacidad: 2, x: 20, y: 20),
        const MesaModel(id: '', nombre: 'Suelta 2', capacidad: 2, x: 200, y: 20),
      ]);
      final ops = crearOps();
      await ops.iniciar();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TableManagementView(operaciones: ops, onAbrirReserva: (_) {})),
      ));
      await tester.pumpAndSettle();
      expect(k('chip_espacio_admin_sin_espacio'), findsOneWidget);
      expect(find.text('Sin espacio (2)'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      await tester.tap(k('chip_espacio_admin_sin_espacio'));
      await tester.pumpAndSettle();
      expect(find.text('Suelta 1'), findsOneWidget);
      expect(find.text('Suelta 2'), findsOneWidget);
      expect(find.text('P1'), findsNothing);
    });

    testWidgets('si todas las mesas tienen espacio no aparece "Sin espacio"', (tester) async {
      pantalla(tester);
      final patio = await svc.crearZona('r1', 'Patio');
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        MesaModel(id: '', nombre: 'P1', capacidad: 4, x: 20, y: 20, zonaId: patio.id),
      ]);
      final ops = crearOps();
      await ops.iniciar();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TableManagementView(operaciones: ops, onAbrirReserva: (_) {})),
      ));
      await tester.pumpAndSettle();
      expect(k('chip_espacio_admin_sin_espacio'), findsNothing);
    });

    testWidgets('una mesa lejos del origen se dibuja arriba a la izquierda, no arrinconada', (tester) async {
      pantalla(tester);
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        const MesaModel(id: '', nombre: 'Lejos', capacidad: 4, x: 900, y: 600),
      ]);
      final ops = crearOps();
      await ops.iniciar();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TableManagementView(operaciones: ops, onAbrirReserva: (_) {})),
      ));
      await tester.pumpAndSettle();
      // El plano se ajusta a sus mesas: una sola mesa queda al centro, no en una esquina.
      final plano = tester.getCenter(k('mesas_plano'));
      final mesa = tester.getCenter(find.text('Lejos'));
      expect((mesa.dx - plano.dx).abs(), lessThan(80));
      expect((mesa.dy - plano.dy).abs(), lessThan(80));
    });

    testWidgets('con espacios muestra una pestaña por espacio y filtra sus mesas', (tester) async {
      pantalla(tester);
      final piso = await svc.crearZona('r1', 'Segundo piso');
      final patio = await svc.crearZona('r1', 'Patio');
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        MesaModel(id: '', nombre: 'A1', capacidad: 2, x: 20, y: 20, zonaId: piso.id),
        MesaModel(id: '', nombre: 'P1', capacidad: 4, x: 20, y: 20, zonaId: patio.id),
        MesaModel(id: '', nombre: 'P2', capacidad: 4, x: 200, y: 20, zonaId: patio.id),
      ]);
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
      expect(k('selector_espacio_admin'), findsOneWidget);
      expect(find.text('Editar plano'), findsOneWidget);
      // Se abre en el primer espacio.
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('P1'), findsNothing);
      await tester.tap(k('chip_espacio_admin_${patio.id}'));
      await tester.pumpAndSettle();
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
      expect(find.text('A1'), findsNothing);
    });
  });
}
