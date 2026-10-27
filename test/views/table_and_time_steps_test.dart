import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/reservation_flow_view.dart';
import 'package:reservitta/views/widgets/table_selection_step.dart';
import 'package:reservitta/views/widgets/time_slot_step.dart';

class _FakeReservations implements ReservationRepository {
  final List<ReservationModel> data;
  _FakeReservations([this.data = const []]);

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async => data
      .where(
        (r) =>
            r.restauranteId == restauranteId &&
            r.fechaLocal == fechaLocal &&
            r.bloqueaMesas,
      )
      .toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MesaModel _mesa(
  String id,
  int cap, {
  double? x,
  double? y,
  bool combinable = false,
  List<String> con = const [],
  String forma = MesaModel.formaCuadrada,
}) => MesaModel(
  id: id,
  nombre: id,
  capacidad: cap,
  x: x,
  y: y,
  combinable: combinable,
  combinableCon: con,
  forma: forma,
);

RestaurantModel _restaurant(List<MesaModel> mesas) {
  const h = DaySchedule(abierto: true, apertura: '12:00', cierre: '16:00');
  return RestaurantModel(
    id: 'r1',
    nombre: 'Test',
    estado: 'activo',
    mesas: mesas,
    horarios: {
      for (final d in [
        'lunes',
        'martes',
        'miercoles',
        'jueves',
        'viernes',
        'sabado',
        'domingo',
      ])
        d: h,
    },
  );
}

ReservationModel _res(DateTime inicio, List<String> mesas, int duracion) {
  return ReservationModel.create(
    id: 'res_${mesas.join()}',
    restauranteId: 'r1',
    fechaLocal: '2026-10-30',
    inicio: inicio,
    duracionMin: duracion,
    mesaIds: mesas,
    estado: ReservationModel.estadoConfirmada,
  );
}

void main() {
  final now = DateTime(2026, 10, 25, 10);
  final fecha = DateTime(2026, 10, 30);

  AvailabilityService service([List<ReservationModel> data = const []]) =>
      AvailabilityService(_FakeReservations(data), now: () => now);

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final planoMesas = [
    _mesa('M1', 2, x: 0, y: 0, forma: MesaModel.formaRedonda),
    _mesa('M2', 4, x: 120, y: 0),
    _mesa('M3', 6, x: 240, y: 0, forma: MesaModel.formaRectangular),
  ];

  Future<void> pumpTables(
    WidgetTester tester, {
    required RestaurantModel restaurant,
    int personas = 4,
    AvailabilityService? availability,
    List<List<String>>? commits,
    List<int>? steps,
  }) async {
    bigScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TableSelectionStep(
              restaurant: restaurant,
              availability: availability ?? service(),
              fecha: fecha,
              personas: personas,
              duracionMin: 90,
              onSelectionChanged: (m) =>
                  commits?.add(m.map((e) => e.id).toList()),
              onChangeStep: (s) => steps?.add(s),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HU10-RF02 renderizado del mapa', () {
    testWidgets('dibuja el plano con cada mesa, su id y capacidad', (
      tester,
    ) async {
      await pumpTables(tester, restaurant: _restaurant(planoMesas));
      expect(find.byKey(const ValueKey('table_map')), findsOneWidget);
      for (final id in ['M1', 'M2', 'M3']) {
        expect(find.byKey(ValueKey('table_tile_$id')), findsOneWidget);
        expect(find.text(id), findsOneWidget);
      }
      expect(find.text('4 pers.'), findsOneWidget);
      expect(find.text('6 pers.'), findsOneWidget);
    });

    testWidgets('permite zoom y desplazamiento con gestos', (tester) async {
      await pumpTables(tester, restaurant: _restaurant(planoMesas));
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final iv = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(iv.maxScale, greaterThan(iv.minScale));
      expect(iv.panEnabled, isTrue);
      expect(iv.scaleEnabled, isTrue);
    });

    testWidgets('muestra una leyenda con los estados', (tester) async {
      await pumpTables(tester, restaurant: _restaurant(planoMesas));
      final leyenda = find.byKey(const ValueKey('table_legend'));
      expect(leyenda, findsOneWidget);
      for (final t in [
        'Disponible',
        'Seleccionada',
        'Ocupada',
        'No adecuada para el grupo',
      ]) {
        expect(
          find.descendant(of: leyenda, matching: find.text(t)),
          findsOneWidget,
        );
      }
    });

    testWidgets('los estados llevan icono además de color', (tester) async {
      await pumpTables(
        tester,
        restaurant: _restaurant(planoMesas),
        availability: service([
          _res(DateTime(2026, 10, 30, 12), ['M3'], 240),
        ]),
      );
      Icon iconOf(String id) => tester.widget<Icon>(
        find.descendant(
          of: find.byKey(ValueKey('table_tile_$id')),
          matching: find.byType(Icon),
        ),
      );
      expect(iconOf('M2').icon, Icons.check_circle_outline); // disponible
      expect(iconOf('M1').icon, Icons.group_off_outlined); // no adecuada
      expect(iconOf('M3').icon, Icons.lock_outline); // ocupada
    });

    testWidgets('sin plano configurado muestra una lista de mesas', (
      tester,
    ) async {
      await pumpTables(
        tester,
        restaurant: _restaurant([_mesa('P1', 4), _mesa('P2', 6)]),
      );
      expect(find.byKey(const ValueKey('table_map')), findsNothing);
      expect(find.byKey(const ValueKey('table_list')), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.textContaining('Capacidad 6'), findsOneWidget);
    });
  });

  group('HU10-RF03 selección de una mesa', () {
    testWidgets('tocar una mesa disponible la resalta y muestra el resumen', (
      tester,
    ) async {
      final commits = <List<String>>[];
      await pumpTables(
        tester,
        restaurant: _restaurant(planoMesas),
        commits: commits,
      );
      await tester.tap(find.byKey(const ValueKey('table_tile_M2')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selection_summary')), findsOneWidget);
      expect(find.text('Mesa elegida'), findsOneWidget);
      expect(find.textContaining('M2 · capacidad 4'), findsOneWidget);
      expect(commits.last, ['M2']);
      final icono = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('table_tile_M2')),
          matching: find.byType(Icon),
        ),
      );
      expect(icono.icon, Icons.check_circle);
    });

    testWidgets('tocar de nuevo deselecciona', (tester) async {
      final commits = <List<String>>[];
      await pumpTables(
        tester,
        restaurant: _restaurant(planoMesas),
        commits: commits,
      );
      await tester.tap(find.byKey(const ValueKey('table_tile_M2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('table_tile_M2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selection_summary')), findsNothing);
      expect(commits.last, isEmpty);
    });

    testWidgets('una mesa no adecuada informa el motivo y no se selecciona', (
      tester,
    ) async {
      await pumpTables(tester, restaurant: _restaurant(planoMesas));
      await tester.tap(find.byKey(const ValueKey('table_tile_M1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('table_selection_message')),
        findsOneWidget,
      );
      expect(find.textContaining('tu grupo es de 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('selection_summary')), findsNothing);
    });
  });

  group('HU10-RF04 combinación de mesas', () {
    final combinables = [
      _mesa('A', 2, x: 0, y: 0, combinable: true, con: ['B']),
      _mesa('B', 2, x: 120, y: 0, combinable: true, con: ['A', 'C']),
      _mesa('C', 2, x: 240, y: 0, combinable: true, con: ['B']),
    ];

    testWidgets('si ninguna mesa alcanza se activa el modo combinar', (
      tester,
    ) async {
      await pumpTables(tester, restaurant: _restaurant(combinables));
      expect(
        find.byKey(const ValueKey('combination_required_banner')),
        findsOneWidget,
      );
      final sw = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('combine_mode_switch')),
      );
      expect(sw.value, isTrue);
    });

    testWidgets('muestra la capacidad total y permite quitar una mesa', (
      tester,
    ) async {
      final commits = <List<String>>[];
      await pumpTables(
        tester,
        restaurant: _restaurant(combinables),
        commits: commits,
      );
      await tester.tap(find.byKey(const ValueKey('table_tile_A')));
      await tester.pumpAndSettle();
      expect(find.text('Capacidad total: 2 de 4 necesarias'), findsOneWidget);
      expect(find.textContaining('Faltan 2 lugares'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('table_tile_B')));
      await tester.pumpAndSettle();
      expect(find.text('Capacidad total: 4 de 4 necesarias'), findsOneWidget);
      expect(commits.last, ['A', 'B']);

      await tester.tap(find.byKey(const ValueKey('remove_mesa_B')));
      await tester.pumpAndSettle();
      expect(find.text('Capacidad total: 2 de 4 necesarias'), findsOneWidget);
      expect(commits.last, isEmpty);
    });

    testWidgets('informa el motivo si la mesa no se combina con las elegidas', (
      tester,
    ) async {
      await pumpTables(tester, restaurant: _restaurant(combinables));
      await tester.tap(find.byKey(const ValueKey('table_tile_A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('table_tile_C')));
      await tester.pumpAndSettle();
      expect(find.textContaining('no se puede combinar con A'), findsOneWidget);
    });
  });

  group('HU09-RF03 mensajes sin mesas adecuadas', () {
    testWidgets('sugiere cambiar fecha, duración o personas', (tester) async {
      final steps = <int>[];
      await pumpTables(
        tester,
        restaurant: _restaurant(planoMesas),
        personas: 3,
        steps: steps,
        availability: service([
          for (final id in ['M1', 'M2', 'M3'])
            _res(DateTime(2026, 10, 30, 12), [id], 240),
        ]),
      );
      expect(find.byKey(const ValueKey('tables_empty_state')), findsOneWidget);
      expect(find.text('No hay mesas adecuadas'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('btn_change_date')));
      await tester.tap(find.byKey(const ValueKey('btn_change_duration')));
      await tester.tap(find.byKey(const ValueKey('btn_change_people')));
      expect(steps, [1, 2, 3]);
    });

    testWidgets('si el grupo excede la capacidad informa el máximo', (
      tester,
    ) async {
      await pumpTables(
        tester,
        restaurant: _restaurant(planoMesas),
        personas: 40,
      );
      expect(
        find.text('Tu grupo excede la capacidad del restaurante'),
        findsOneWidget,
      );
      expect(
        find.textContaining('máximo permitido es de 6 personas'),
        findsOneWidget,
      );
    });
  });

  group('HU11-RF02 selector de horarios', () {
    Future<void> pumpSlots(
      WidgetTester tester, {
      List<ReservationModel> reservations = const [],
      void Function(TimeSlot)? onSelected,
      List<int>? steps,
    }) async {
      bigScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimeSlotStep(
                restaurant: _restaurant(planoMesas),
                availability: service(reservations),
                fecha: fecha,
                duracionMin: 90,
                mesaIds: const ['M2'],
                mesasNombres: const ['M2'],
                onSelected: onSelected ?? (_) {},
                onChangeStep: (s) => steps?.add(s),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra los horarios en una cuadrícula con inicio y fin', (
      tester,
    ) async {
      await pumpSlots(tester);
      expect(find.byKey(const ValueKey('slots_grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('slot_chip_1200')), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('a 13:30'), findsOneWidget);
    });

    testWidgets('quedan ordenados de menor a mayor', (tester) async {
      await pumpSlots(tester);
      final y1200 = tester.getTopLeft(
        find.byKey(const ValueKey('slot_chip_1200')),
      );
      final y1330 = tester.getTopLeft(
        find.byKey(const ValueKey('slot_chip_1330')),
      );
      expect(
        y1200.dy < y1330.dy || (y1200.dy == y1330.dy && y1200.dx < y1330.dx),
        isTrue,
      );
    });

    testWidgets('elegir un horario lo resalta y lo guarda', (tester) async {
      TimeSlot? elegido;
      await pumpSlots(tester, onSelected: (s) => elegido = s);
      await tester.tap(find.byKey(const ValueKey('slot_chip_1300')));
      await tester.pumpAndSettle();
      expect(elegido!.inicio, DateTime(2026, 10, 30, 13));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('slot_chip_1300')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin horarios ofrece elegir otra mesa u otra fecha', (
      tester,
    ) async {
      final steps = <int>[];
      await pumpSlots(
        tester,
        steps: steps,
        reservations: [
          _res(DateTime(2026, 10, 30, 12), ['M2'], 240),
        ],
      );
      expect(find.byKey(const ValueKey('slots_empty_state')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('btn_choose_other_table')));
      await tester.tap(find.byKey(const ValueKey('btn_choose_other_date')));
      expect(steps, [4, 1]);
    });
  });

  group('Flujo completo: mesa y horario', () {
    final sucursal = const BranchModel(
      id: 'b1',
      nombre: 'Centro',
      direccion: 'Calle 1',
      telefono: '1',
      esPrincipal: true,
    );

    testWidgets(
      'el botón Continuar solo se habilita con una selección válida',
      (tester) async {
        bigScreen(tester);
        final restaurant = _restaurant(planoMesas);
        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => now,
        );
        vm.selectBranch(sucursal);
        vm.nextStep();
        vm.selectDate(fecha);
        vm.nextStep();
        vm.selectDuration(90);
        vm.nextStep();
        vm.setPartySize(4);
        vm.nextStep(); // paso 4: mesa

        await tester.pumpWidget(
          MaterialApp(
            home: ReservationFlowView(
              restaurant: restaurant,
              viewModel: vm,
              availabilityService: service(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elige tu mesa'), findsOneWidget);
        FilledButton boton() => tester.widget<FilledButton>(
          find.byKey(const ValueKey('btn_continuar_step_4')),
        );
        expect(boton().onPressed, isNull);

        await tester.tap(find.byKey(const ValueKey('table_tile_M2')));
        await tester.pumpAndSettle();
        expect(vm.draft.mesaIds, ['M2']);
        expect(boton().onPressed, isNotNull);

        await tester.tap(find.byKey(const ValueKey('btn_continuar_step_4')));
        await tester.pumpAndSettle();

        // Paso 5: horario
        expect(find.text('Elige tu horario'), findsOneWidget);
        FilledButton botonHorario() => tester.widget<FilledButton>(
          find.byKey(const ValueKey('btn_continuar_step_5')),
        );
        expect(botonHorario().onPressed, isNull);

        await tester.tap(find.byKey(const ValueKey('slot_chip_1330')));
        await tester.pumpAndSettle();
        expect(vm.draft.horario, const TimeOfDay(hour: 13, minute: 30));
        expect(botonHorario().onPressed, isNotNull);

        await tester.tap(find.byKey(const ValueKey('btn_continuar_step_5')));
        await tester.pumpAndSettle();

        expect(find.text('¡Borrador guardado!'), findsOneWidget);
        expect(find.text('13:30 – 15:00'), findsOneWidget);
        expect(find.text('M2'), findsOneWidget);
      },
    );

    testWidgets('volver al paso de mesa conserva la mesa elegida', (
      tester,
    ) async {
      bigScreen(tester);
      final restaurant = _restaurant(planoMesas);
      final vm = ReservationDraftViewModel(
        restaurant: restaurant,
        clock: () => now,
      )..selectDate(fecha);
      vm.setPartySize(4);
      vm.setSelectedTables([planoMesas[1]]);
      vm.goToStep(4);

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationFlowView(
            restaurant: restaurant,
            viewModel: vm,
            availabilityService: service(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mesa elegida'), findsOneWidget);
      expect(find.textContaining('M2 · capacidad 4'), findsOneWidget);
    });
  });
}
