import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/reservation_flow_view.dart';
import 'package:reservitta/views/restaurant_detail_view.dart';

class _FakeCategoriaService extends CategoriaService {
  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) =>
      Stream.value(const []);
}

class _FakePlatilloService extends PlatilloService {
  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) =>
      Stream.value(const []);
}

class _NoReservations implements ReservationRepository {
  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testRestaurant = RestaurantModel(
    id: 'rest_miel_aurum',
    nombre: 'Miel Aurum',
    direccion: 'Calle Telesecundaria, Rio Laja, Dolores Hidalgo, Guanajuato',
    telefono: '418-123-4567',
    estado: 'activo',
    capacidadMaxima: 30,
    diasAbiertos: const ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'],
    horarios: const {
      'lunes': DaySchedule(abierto: true, apertura: '09:00', cierre: '22:00'),
      'martes': DaySchedule(abierto: true, apertura: '09:00', cierre: '22:00'),
      'miercoles': DaySchedule(abierto: true, apertura: '09:00', cierre: '22:00'),
      'jueves': DaySchedule(abierto: true, apertura: '09:00', cierre: '22:00'),
      'viernes': DaySchedule(abierto: true, apertura: '09:00', cierre: '22:00'),
      'sabado': DaySchedule(abierto: true, apertura: '09:00', cierre: '22:00'),
      'domingo': DaySchedule(abierto: true, apertura: '09:00', cierre: '22:00'),
    },
    cierresEspeciales: const ['2026-12-25'],
  );

  final testBranches = [
    const BranchModel(
      id: 'br_centro',
      nombre: 'Miel Aurum — Centro',
      direccion: 'Av. Principal 125, Centro Histórico',
      telefono: '418-111-2222',
      esPrincipal: true,
    ),
    const BranchModel(
      id: 'br_norte',
      nombre: 'Miel Aurum — Norte',
      direccion: 'Blvd. Norte 450, Fracc. Los Pinos',
      telefono: '418-333-4444',
      esPrincipal: false,
    ),
  ];

  group('HU07-RF01: Inicio del proceso de reserva y estado del borrador', () {
    test('ViewModel: Se crea un borrador de reserva con el restaurante y valores por defecto', () {
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => DateTime(2026, 10, 24, 12, 0),
      );

      expect(vm.draft.restaurant.id, equals('rest_miel_aurum'));
      expect(vm.draft.duracionMin, equals(90)); // Duración sugerida por defecto (HU08-RF01)
      expect(vm.draft.personas, equals(2)); // Mínimo inicial >= 1 (HU09-RF01)
      expect(vm.currentStep, equals(0)); // Inicia en selección de sucursal
    });

    test('ViewModel: El borrador guarda de forma incremental sucursal, fecha, duración y personas', () {
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => DateTime(2026, 10, 24, 12, 0),
      );

      // Paso 0: Sucursal
      vm.selectBranch(testBranches.first);
      expect(vm.draft.branch?.id, equals('br_centro'));
      expect(vm.canAdvanceCurrentStep, isTrue);

      vm.nextStep();
      expect(vm.currentStep, equals(1)); // Paso Fecha

      // Paso 1: Fecha
      final fechaElegida = DateTime(2026, 10, 28);
      vm.selectDate(fechaElegida);
      expect(vm.draft.fecha, equals(fechaElegida));
      expect(vm.canAdvanceCurrentStep, isTrue);

      vm.nextStep();
      expect(vm.currentStep, equals(2)); // Paso Duración

      // Paso 2: Duración
      vm.selectDuration(120); // 2 horas
      expect(vm.draft.duracionMin, equals(120));
      expect(vm.canAdvanceCurrentStep, isTrue);

      vm.nextStep();
      expect(vm.currentStep, equals(3)); // Paso Personas

      // Paso 3: Personas
      vm.setPartySize(5);
      expect(vm.draft.personas, equals(5));
      expect(vm.canAdvanceCurrentStep, isTrue);
    });

    test('ViewModel: Si el usuario retrocede en el flujo, conserva los datos ya elegidos', () {
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => DateTime(2026, 10, 24, 12, 0),
      );

      // Llenamos datos hasta el paso 3
      vm.selectBranch(testBranches.first);
      vm.nextStep(); // A paso 1
      final fechaElegida = DateTime(2026, 10, 28);
      vm.selectDate(fechaElegida);
      vm.nextStep(); // A paso 2
      vm.selectDuration(180);
      vm.nextStep(); // A paso 3
      vm.setPartySize(6);

      // Ahora retrocedemos paso por paso
      vm.previousStep(); // Vuelve a paso 2
      expect(vm.currentStep, equals(2));
      expect(vm.draft.personas, equals(6)); // Mantiene personas
      expect(vm.draft.duracionMin, equals(180)); // Mantiene duración

      vm.previousStep(); // Vuelve a paso 1
      expect(vm.currentStep, equals(1));
      expect(vm.draft.fecha, equals(fechaElegida)); // Mantiene fecha

      vm.previousStep(); // Vuelve a paso 0
      expect(vm.currentStep, equals(0));
      expect(vm.draft.branch?.id, equals('br_centro')); // Mantiene sucursal
    });

    test('ViewModel: Si el usuario cancela o sale del flujo, el borrador se descarta', () {
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => DateTime(2026, 10, 24, 12, 0),
      );

      vm.selectBranch(testBranches.first);
      vm.selectDate(DateTime(2026, 10, 28));
      vm.selectDuration(120);
      vm.setPartySize(8);

      // Descarta el borrador
      vm.discardDraft();

      expect(vm.draft.branch, isNull);
      expect(vm.draft.fecha, isNull);
      expect(vm.draft.duracionMin, equals(90));
      expect(vm.draft.personas, equals(2));
      expect(vm.currentStep, equals(0));
    });

    testWidgets('Widget: En RestaurantDetailView el botón Haz tu Reserva inicia el flujo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RestaurantDetailView(
          restaurant: testRestaurant,
          categoriaService: _FakeCategoriaService(),
          platilloService: _FakePlatilloService(),
          bypassAuthForTesting: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Solo un botón de reservar al final de la información del restaurante
      final botonReservar = find.byKey(const ValueKey('boton_reservar_mesa'));
      expect(botonReservar, findsOneWidget);
      expect(find.text('Haz tu Reserva'), findsOneWidget);

      // Al pulsar 'Haz tu Reserva', navega e inicia ReservationFlowView
      await tester.ensureVisible(botonReservar);
      await tester.tap(botonReservar);
      await tester.pumpAndSettle();

      expect(find.byType(ReservationFlowView), findsOneWidget);
      expect(find.text('SELECCIONA UNA SUCURSAL'), findsOneWidget);
    });
  });

  group('HU07-RF02: Selector de fecha de visita', () {
    test('ViewModel: Validación de fechas pasadas, límites máximos y cierres del restaurante', () {
      final clockTime = DateTime(2026, 10, 24, 12, 0); // Sábado 24 Octubre 2026
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => clockTime,
        maxAnticipacionDias: 60,
      );

      // Fecha de hoy: válida
      expect(vm.isDateSelectable(DateTime(2026, 10, 24)), isTrue);

      // Fecha pasada (ayer): deshabilitada
      expect(vm.isDateSelectable(DateTime(2026, 10, 23)), isFalse);

      // Fecha dentro de 60 días: válida (ej. dentro de 30 días)
      expect(vm.isDateSelectable(DateTime(2026, 11, 20)), isTrue);

      // Fecha más allá de 60 días: deshabilitada (ej. dentro de 70 días)
      expect(vm.isDateSelectable(DateTime(2027, 1, 15)), isFalse);

      // Fecha con cierre especial configurado (25 Dic 2026): deshabilitada
      expect(vm.isDateSelectable(DateTime(2026, 12, 25)), isFalse);
    });

    test('ViewModel: Restaurante con días cerrados deshabilita dichos días', () {
      final restConCierres = testRestaurant.copyWith(
        diasAbiertos: ['lunes', 'martes', 'miercoles', 'jueves', 'viernes'], // Cierra sábado y domingo
      );

      final clockTime = DateTime(2026, 10, 20, 10, 0); // Martes 20
      final vm = ReservationDraftViewModel(
        restaurant: restConCierres,
        clock: () => clockTime,
      );

      // Miércoles 21: abierto
      expect(vm.isDateSelectable(DateTime(2026, 10, 21)), isTrue);

      // Sábado 24: cerrado
      expect(vm.isDateSelectable(DateTime(2026, 10, 24)), isFalse);

      // Domingo 25: cerrado
      expect(vm.isDateSelectable(DateTime(2026, 10, 25)), isFalse);
    });

    testWidgets('Widget: Calendario muestra fecha y habilita Continuar solo al elegir fecha', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final clockTime = DateTime(2026, 10, 24, 12, 0);
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => clockTime,
      );

      // Preparamos para estar en el paso 1 (Fecha)
      vm.selectBranch(testBranches.first);
      vm.nextStep();

      await tester.pumpWidget(MaterialApp(
        home: ReservationFlowView(
          restaurant: testRestaurant,
          viewModel: vm,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('¿Qué día quieres visitarnos?'), findsOneWidget);

      // Botón Continuar deshabilitado inicialmente si no hay fecha seleccionada
      final btnContinuar = find.byKey(const ValueKey('btn_continuar_step_1'));
      expect(btnContinuar, findsOneWidget);
      final filledBtn = tester.widget<FilledButton>(btnContinuar);
      expect(filledBtn.onPressed, isNull);

      // Seleccionamos día 28 de Octubre
      final dayCell = find.byKey(const ValueKey('cal_day_2026_10_28'));
      expect(dayCell, findsOneWidget);
      await tester.ensureVisible(dayCell);
      await tester.tap(dayCell);
      await tester.pumpAndSettle();

      // La fecha se muestra en pantalla y el botón Continuar se habilita
      expect(find.byKey(const ValueKey('caja_fecha_elegida')), findsOneWidget);
      final filledBtnHabilitado = tester.widget<FilledButton>(btnContinuar);
      expect(filledBtnHabilitado.onPressed, isNotNull);
    });

    testWidgets('Widget: Los botones de acceso rápido permiten seleccionar la fecha de visita', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final clockTime = DateTime(2026, 10, 24, 12, 0);
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => clockTime,
      );

      vm.selectBranch(testBranches.first);
      vm.nextStep();

      await tester.pumpWidget(MaterialApp(
        home: ReservationFlowView(
          restaurant: testRestaurant,
          viewModel: vm,
        ),
      ));
      await tester.pumpAndSettle();

      // Botón de acceso rápido Hoy
      final chipHoy = find.byKey(const ValueKey('chip_rapido_Hoy'));
      expect(chipHoy, findsOneWidget);

      await tester.ensureVisible(chipHoy);
      await tester.tap(chipHoy);
      await tester.pumpAndSettle();

      expect(vm.draft.fecha, isNotNull);
      expect(vm.draft.fecha!.day, equals(24));
      expect(find.byKey(const ValueKey('caja_fecha_elegida')), findsOneWidget);

      // Botón de acceso rápido Mañana
      final chipManana = find.byKey(const ValueKey('chip_rapido_Mañana'));
      expect(chipManana, findsOneWidget);

      await tester.ensureVisible(chipManana);
      await tester.tap(chipManana);
      await tester.pumpAndSettle();

      expect(vm.draft.fecha!.day, equals(25));
    });
  });

  group('HU08-RF01: Selector de duración', () {
    test('ViewModel: Ofrece duraciones predefinidas en pasos de 30 min y sugerida de 1h 30m', () {
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => DateTime(2026, 10, 24, 12, 0),
      );

      // Duraciones disponibles
      expect(ReservationDraftViewModel.duracionesDisponibles,
          equals([60, 90, 120, 150, 180, 210, 240]));

      // Sugerida por defecto: 90 min (1 h 30 min)
      expect(vm.draft.duracionMin, equals(90));
      expect(vm.canContinueFromDuration, isTrue);

      // Seleccionar otra duración válida
      vm.selectDuration(150);
      expect(vm.draft.duracionMin, equals(150));
      expect(vm.draft.formattedDuration, equals('2 horas 30 min'));

      // Intentar una duración no permitida no modifica el valor
      vm.selectDuration(45);
      expect(vm.draft.duracionMin, equals(150));
    });

    testWidgets('Widget: Selector de duración lista opciones y permite cambiarla', (tester) async {
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => DateTime(2026, 10, 24, 12, 0),
      );

      vm.selectBranch(testBranches.first);
      vm.nextStep(); // Paso 1
      vm.selectDate(DateTime(2026, 10, 28));
      vm.nextStep(); // Paso 2

      await tester.pumpWidget(MaterialApp(
        home: ReservationFlowView(
          restaurant: testRestaurant,
          viewModel: vm,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('¿Cuánto tiempo planeas quedarte?'), findsOneWidget);
      expect(find.text('1 hora'), findsOneWidget);
      expect(find.text('1 hora 30 min'), findsOneWidget);
      expect(find.text('Sugerido'), findsOneWidget);
      expect(find.text('2 horas'), findsOneWidget);

      // Cambiar a 2 horas
      await tester.tap(find.byKey(const ValueKey('duracion_opcion_120')));
      await tester.pumpAndSettle();

      expect(vm.draft.duracionMin, equals(120));
      final btnContinuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_step_2')));
      expect(btnContinuar.onPressed, isNotNull);
    });
  });

  group('HU09-RF01: Selector de cantidad de personas', () {
    test('ViewModel: Stepper numérico respeta mínimo 1 y máximo según capacidad del restaurante', () {
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant, // Capacidad máxima: 30
        clock: () => DateTime(2026, 10, 24, 12, 0),
      );

      // Inicia con personas >= 1
      expect(vm.draft.personas, greaterThanOrEqualTo(1));
      expect(vm.minPartySize, equals(1));
      expect(vm.maxPartySize, equals(30));

      // Bajar hasta 1
      vm.setPartySize(1);
      expect(vm.draft.personas, equals(1));

      // No permite decrementar por debajo de 1 (ni cero ni negativo)
      vm.decrementPartySize();
      expect(vm.draft.personas, equals(1));

      // Incrementar
      vm.incrementPartySize();
      expect(vm.draft.personas, equals(2));

      // Subir hasta capacidad máxima
      vm.setPartySize(30);
      expect(vm.draft.personas, equals(30));

      // No permite incrementar por encima del máximo
      vm.incrementPartySize();
      expect(vm.draft.personas, equals(30));

      // Rechaza valores no válidos
      vm.setPartySize(-5);
      expect(vm.draft.personas, equals(30));
      vm.setPartySize(0);
      expect(vm.draft.personas, equals(30));
      vm.setPartySize(50); // Superior al máximo
      expect(vm.draft.personas, equals(30));
    });

    testWidgets('Widget: Botones stepper y rangos sugeridos actualizan la cantidad en pantalla', (tester) async {
      final vm = ReservationDraftViewModel(
        restaurant: testRestaurant,
        clock: () => DateTime(2026, 10, 24, 12, 0),
      );

      vm.selectBranch(testBranches.first);
      vm.nextStep(); // 1
      vm.selectDate(DateTime(2026, 10, 28));
      vm.nextStep(); // 2
      vm.selectDuration(90);
      vm.nextStep(); // 3 (Personas)

      await tester.pumpWidget(MaterialApp(
        home: ReservationFlowView(
          restaurant: testRestaurant,
          viewModel: vm,
          availabilityService: AvailabilityService(_NoReservations()),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('¿Para cuántas personas?'), findsOneWidget);
      expect(find.byKey(const ValueKey('texto_contador_personas')), findsOneWidget);

      // Pulsar botón más (+)
      final btnPlus = find.byKey(const ValueKey('stepper_btn_plus'));
      await tester.tap(btnPlus);
      await tester.pumpAndSettle();

      expect(vm.draft.personas, equals(3));
      final textCounter3 = tester.widget<Text>(find.byKey(const ValueKey('texto_contador_personas')));
      expect(textCounter3.data, equals('3'));

      // Pulsar rango sugerido "5–6 personas"
      final rango56 = find.byKey(const ValueKey('rango_sugerido_5_6'));
      expect(rango56, findsOneWidget);
      await tester.tap(rango56);
      await tester.pumpAndSettle();

      expect(vm.draft.personas, equals(6));
      final textCounter6 = tester.widget<Text>(find.byKey(const ValueKey('texto_contador_personas')));
      expect(textCounter6.data, equals('6'));

      // Botón "Ver mesas disponibles" habilitado
      final btnVerMesas = find.byKey(const ValueKey('btn_continuar_step_3'));
      expect(btnVerMesas, findsOneWidget);
      expect(find.text('Ver mesas disponibles'), findsOneWidget);

      // Al pulsar "Ver mesas disponibles" avanza al paso de mesa
      await tester.tap(btnVerMesas);
      await tester.pumpAndSettle();

      expect(vm.currentStep, equals(4));
      expect(find.text('Elige tu mesa'), findsOneWidget);
      expect(vm.draft.personas, equals(6));
    });
  });
}
