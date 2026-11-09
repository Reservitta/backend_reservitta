import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/services/table_layout_service.dart';
import 'package:reservitta/services/table_service.dart';
import 'package:reservitta/viewmodels/table_selection_viewmodel.dart';
import 'package:reservitta/views/widgets/table_selection_step.dart';

const _dias = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];

final _restaurante = RestaurantModel(
  id: 'r1',
  nombre: 'Miel',
  estado: 'activo',
  capacidadMaxima: 40,
  diasAbiertos: _dias,
  horarios: {
    for (final d in _dias) d: const DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00'),
  },
);

final _ahora = DateTime(2026, 11, 8, 10);
final _fecha = DateTime(2026, 11, 12); // jueves

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  late TableLayoutService layout;
  late ReservationService reservas;
  late AvailabilityService disponibilidad;

  Finder k(String key) => find.byKey(ValueKey(key));

  setUp(() {
    db = FakeFirebaseFirestore();
    layout = TableLayoutService(firestore: db, now: () => _ahora);
    reservas = ReservationService(firestore: db);
    disponibilidad = AvailabilityService(reservas, tables: TableService(firestore: db), now: () => _ahora);
  });

  MesaModel mesa(String nombre, {int capacidad = 4, String? zona, double x = 20, double y = 20}) =>
      MesaModel(id: '', nombre: nombre, capacidad: capacidad, x: x, y: y, zonaId: zona);

  Future<TableSelectionViewModel> cargar({int personas = 2, List<String> inicial = const []}) async {
    final vm = TableSelectionViewModel(
      restaurant: _restaurante,
      availability: disponibilidad,
      fecha: _fecha,
      personas: personas,
      duracionMin: 90,
      onSelectionChanged: (_) {},
      initialSelectedIds: inicial,
    );
    addTearDown(vm.dispose);
    await vm.load();
    return vm;
  }

  group('Espacios en la selección de mesa (HU34-RF04)', () {
    test('un restaurante sin espacios muestra todas sus mesas y no tiene selector', () async {
      await layout.guardarPlano(restauranteId: 'r1', mesas: [mesa('A'), mesa('B', x: 200)]);
      final vm = await cargar();
      expect(vm.espacios, isEmpty);
      expect(vm.hayVariosEspacios, isFalse);
      expect(vm.zonaActivaId, isNull);
      expect(vm.mesasVisibles, hasLength(2));
    });

    test('un solo espacio tampoco muestra selector', () async {
      final z = await layout.crearZona('r1', 'Salón');
      await layout.guardarPlano(restauranteId: 'r1', mesas: [mesa('A', zona: z.id), mesa('B', zona: z.id, x: 200)]);
      final vm = await cargar();
      expect(vm.espacios, hasLength(1));
      expect(vm.hayVariosEspacios, isFalse);
      expect(vm.mesasVisibles, hasLength(2));
    });

    test('con varios espacios muestra uno a la vez, con el primero libre por defecto', () async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id),
        mesa('P1', zona: patio.id),
        mesa('P2', zona: patio.id, x: 200),
      ]);
      final vm = await cargar();
      expect(vm.hayVariosEspacios, isTrue);
      expect(vm.espacios.map((e) => e.nombre), ['Segundo piso', 'Patio']);
      expect(vm.zonaActivaId, piso.id);
      expect(vm.mesasVisibles.map((p) => p.mesa.nombre), ['A1']);

      vm.seleccionarZona(patio.id);
      expect(vm.zonaActivaId, patio.id);
      expect(vm.mesasVisibles.map((p) => p.mesa.nombre).toSet(), {'P1', 'P2'});
    });

    test('cuenta las mesas libres de cada espacio para el grupo', () async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id, capacidad: 2),
        mesa('A2', zona: piso.id, capacidad: 2, x: 200),
        mesa('P1', zona: patio.id, capacidad: 8),
      ]);
      final vm = await cargar(personas: 6);
      // Las mesas de 2 no alcanzan para 6 personas.
      expect(vm.disponiblesEn(piso.id), 0);
      expect(vm.disponiblesEn(patio.id), 1);
      // Se abre en el espacio que sí tiene mesa para el grupo.
      expect(vm.zonaActivaId, patio.id);
    });

    test('un espacio con todas sus mesas ocupadas no es el primero que se muestra', () async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      final r = await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id),
        mesa('P1', zona: patio.id),
      ]);
      final a1 = r.mesas.firstWhere((m) => m.nombre == 'A1');
      await reservas.createReservationVerified(ReservationModel.create(
        id: '',
        restauranteId: 'r1',
        usuarioId: 'u1',
        fechaLocal: '2026-11-12',
        inicio: DateTime(2026, 11, 12, 12),
        duracionMin: 600,
        personas: 4,
        mesaIds: [a1.id],
        mesasNombres: const ['A1'],
        estado: ReservationModel.estadoConfirmada,
      ));
      final vm = await cargar();
      expect(vm.disponiblesEn(piso.id), 0);
      expect(vm.zonaActivaId, patio.id);
    });

    test('abre en el espacio de la mesa que el visitante ya había elegido', () async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      final r = await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id),
        mesa('P1', zona: patio.id),
      ]);
      final p1 = r.mesas.firstWhere((m) => m.nombre == 'P1');
      final vm = await cargar(inicial: [p1.id]);
      expect(vm.selected.single.id, p1.id);
      expect(vm.zonaActivaId, patio.id);
    });

    test('las mesas sin espacio van en "Otras mesas" cuando ya hay espacios', () async {
      final patio = await layout.crearZona('r1', 'Patio');
      await layout.crearZona('r1', 'Salón');
      await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('P1', zona: patio.id),
        mesa('S1', zona: null, x: 200),
      ]);
      final vm = await cargar();
      expect(vm.espacios.map((e) => e.nombre), ['Patio', 'Otras mesas']);
      vm.seleccionarZona(TableSelectionViewModel.sinEspacioId);
      expect(vm.mesasVisibles.map((p) => p.mesa.nombre), ['S1']);
    });

    test('cambiar de espacio no pierde la mesa elegida', () async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id),
        mesa('P1', zona: patio.id),
      ]);
      final vm = await cargar();
      await vm.onTapMesa(vm.mesasVisibles.single.mesa);
      expect(vm.selected.single.nombre, 'A1');
      vm.seleccionarZona(patio.id);
      expect(vm.selected.single.nombre, 'A1');
    });
  });

  group('Pantalla del visitante', () {
    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: TableSelectionStep(
              restaurant: _restaurante,
              availability: disponibilidad,
              fecha: _fecha,
              personas: 2,
              duracionMin: 90,
              onSelectionChanged: (_) {},
              onChangeStep: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra un selector con las mesas libres de cada espacio', (tester) async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id),
        mesa('P1', zona: patio.id),
        mesa('P2', zona: patio.id, x: 200),
      ]);
      await abrir(tester);
      expect(k('selector_espacio'), findsOneWidget);
      expect(find.text('Segundo piso · 1 mesa libre'), findsOneWidget);
      expect(find.text('Patio · 2 mesas libres'), findsOneWidget);
    });

    testWidgets('al elegir un espacio solo se ven sus mesas', (tester) async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      final r = await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id),
        mesa('P1', zona: patio.id),
      ]);
      final a1 = r.mesas.firstWhere((m) => m.nombre == 'A1');
      final p1 = r.mesas.firstWhere((m) => m.nombre == 'P1');
      await abrir(tester);
      expect(k('table_tile_${a1.id}'), findsOneWidget);
      expect(k('table_tile_${p1.id}'), findsNothing);

      await tester.tap(k('chip_espacio_${patio.id}'));
      await tester.pumpAndSettle();
      expect(k('table_tile_${p1.id}'), findsOneWidget);
      expect(k('table_tile_${a1.id}'), findsNothing);
    });

    testWidgets('elegir una mesa de otro espacio la deja seleccionada con su espacio', (tester) async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      final r = await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id),
        mesa('P1', zona: patio.id),
      ]);
      final p1 = r.mesas.firstWhere((m) => m.nombre == 'P1');
      await abrir(tester);
      await tester.tap(k('chip_espacio_${patio.id}'));
      await tester.pumpAndSettle();
      await tester.tap(k('table_tile_${p1.id}'));
      await tester.pumpAndSettle();
      expect(k('selection_summary'), findsOneWidget);
      expect(find.descendant(of: k('selection_summary'), matching: find.textContaining('Patio')),
          findsWidgets);
    });

    testWidgets('con un solo espacio no hay selector', (tester) async {
      final z = await layout.crearZona('r1', 'Salón');
      await layout.guardarPlano(restauranteId: 'r1', mesas: [mesa('A1', zona: z.id)]);
      await abrir(tester);
      expect(k('selector_espacio'), findsNothing);
    });

    testWidgets('un espacio sin mesas libres lo dice', (tester) async {
      final piso = await layout.crearZona('r1', 'Segundo piso');
      final patio = await layout.crearZona('r1', 'Patio');
      await layout.guardarPlano(restauranteId: 'r1', mesas: [
        mesa('A1', zona: piso.id, capacidad: 1),
        mesa('P1', zona: patio.id),
      ]);
      await abrir(tester);
      expect(find.text('Segundo piso · sin mesas libres'), findsOneWidget);
    });
  });
}
