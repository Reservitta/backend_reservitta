import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/table_availability_models.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/reservation_flow_view.dart';
import 'package:reservitta/views/widgets/reservation_summary_step.dart';

class _MockReservationRepo implements ReservationRepository {
  int createCalls = 0;

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #createReservation ||
        invocation.memberName.toString().contains('create')) {
      createCalls++;
    }
    return super.noSuchMethod(invocation);
  }
}

MesaModel _mesa(
  String id,
  int cap, {
  double? x,
  double? y,
  bool combinable = false,
  List<String> con = const [],
  String forma = MesaModel.formaCuadrada,
}) =>
    MesaModel(
      id: id,
      nombre: id,
      capacidad: cap,
      x: x,
      y: y,
      combinable: combinable,
      combinableCon: con,
      forma: forma,
    );

RestaurantModel _buildRestaurant(List<MesaModel> mesas) {
  const h = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');
  return RestaurantModel(
    id: 'rest_aurum',
    nombre: 'Miel Aurum',
    direccion: 'Av. Hidalgo 100, Centro',
    telefono: '418-123-4567',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 10, 30);
  final testClock = DateTime(2026, 10, 24, 10);
  final sucursal = const BranchModel(
    id: 'br_centro',
    nombre: 'Miel Aurum — Matriz Centro',
    direccion: 'Av. Hidalgo 100, Centro',
    telefono: '418-123-4567',
    esPrincipal: true,
  );

  final mesasRestaurante = [
    _mesa('M1', 2, x: 0, y: 0),
    _mesa('M2', 4, x: 100, y: 0),
    _mesa('M3', 6, x: 200, y: 0),
  ];

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  ReservationDraftModel createCompleteDraft({
    RestaurantModel? restaurant,
    int personas = 4,
    int duracion = 90,
  }) {
    final r = restaurant ?? _buildRestaurant(mesasRestaurante);
    return ReservationDraftModel(
      restaurant: r,
      branch: sucursal,
      fecha: testDate,
      duracionMin: duracion,
      personas: personas,
      mesaIds: const ['M2'],
      mesasNombres: const ['Mesa M2'],
      horario: const TimeOfDay(hour: 14, minute: 0),
    );
  }

  group('HU12-RF01 y HU11-RF03: Widget autónomo ReservationSummaryStep', () {
    testWidgets(
      'muestra resumen con restaurante, fecha, horario, duración, personas y mesa(s)',
      (tester) async {
        setLargeScreen(tester);
        final draft = createCompleteDraft();
        final editedSteps = <int>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReservationSummaryStep(
                  draft: draft,
                  onEditStep: (s) => editedSteps.add(s),
                  isAuthenticated: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Restaurante y sucursal
        expect(find.byKey(const ValueKey('summary_card_restaurante')), findsOneWidget);
        expect(find.text('Miel Aurum'), findsOneWidget);
        expect(find.text('Miel Aurum — Matriz Centro'), findsOneWidget);

        // 2. Fecha
        expect(find.byKey(const ValueKey('summary_card_fecha')), findsOneWidget);
        expect(find.text(draft.formattedDate), findsOneWidget);

        // 3. Duración
        expect(find.byKey(const ValueKey('summary_card_duracion')), findsOneWidget);
        expect(find.text(draft.formattedDuration), findsOneWidget);

        // 4. Cantidad de personas
        expect(find.byKey(const ValueKey('summary_card_personas')), findsOneWidget);
        expect(find.text('4 personas'), findsOneWidget);

        // 5. Mesa(s)
        expect(find.byKey(const ValueKey('summary_card_mesas')), findsOneWidget);
        expect(find.text('Mesa M2'), findsOneWidget);

        // 6. Horario
        expect(find.byKey(const ValueKey('summary_card_horario')), findsOneWidget);
        expect(find.text(draft.formattedTimeRange), findsOneWidget);

        // Insignia de borrador guardado y aviso de solo confirmación
        expect(find.text('¡Borrador guardado!'), findsOneWidget);
        expect(
          find.textContaining('Esta pantalla es de solo confirmación; no crea la reserva todavía'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'cada campo tiene un botón Modificar que invoca el paso correspondiente',
      (tester) async {
        setLargeScreen(tester);
        final draft = createCompleteDraft();
        final editedSteps = <int>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReservationSummaryStep(
                  draft: draft,
                  onEditStep: (s) => editedSteps.add(s),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tocar Modificar en Sucursal (paso 0)
        await tester.tap(find.byKey(const ValueKey('btn_modificar_sucursal')));
        await tester.pumpAndSettle();
        expect(editedSteps.last, equals(0));

        // Tocar Modificar en Fecha (paso 1)
        await tester.tap(find.byKey(const ValueKey('btn_modificar_fecha')));
        await tester.pumpAndSettle();
        expect(editedSteps.last, equals(1));

        // Tocar Modificar en Duración (paso 2)
        await tester.tap(find.byKey(const ValueKey('btn_modificar_duracion')));
        await tester.pumpAndSettle();
        expect(editedSteps.last, equals(2));

        // Tocar Modificar en Personas (paso 3)
        await tester.tap(find.byKey(const ValueKey('btn_modificar_personas')));
        await tester.pumpAndSettle();
        expect(editedSteps.last, equals(3));

        // Tocar Modificar en Mesas (paso 4)
        await tester.tap(find.byKey(const ValueKey('btn_modificar_mesas')));
        await tester.pumpAndSettle();
        expect(editedSteps.last, equals(4));

        // Tocar Modificar en Horario (paso 5)
        await tester.tap(find.byKey(const ValueKey('btn_modificar_horario')));
        await tester.pumpAndSettle();
        expect(editedSteps.last, equals(5));

        expect(editedSteps, equals([0, 1, 2, 3, 4, 5]));
      },
    );

    testWidgets(
      'visitante sin sesión muestra banner informativo de inicio de sesión requerido',
      (tester) async {
        setLargeScreen(tester);
        final draft = createCompleteDraft();
        bool authRequested = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReservationSummaryStep(
                  draft: draft,
                  onEditStep: (_) {},
                  isAuthenticated: false,
                  onRequireAuth: () => authRequested = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('auth_required_banner')), findsOneWidget);
        expect(find.textContaining('Tu borrador se conservará intacto al volver'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('btn_iniciar_sesion_resumen')));
        await tester.pumpAndSettle();
        expect(authRequested, isTrue);
      },
    );

    testWidgets(
      'el botón Confirmar reserva se deshabilita mientras se procesa (HU11-RF03)',
      (tester) async {
        setLargeScreen(tester);
        final draft = createCompleteDraft();
        bool confirmCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReservationSummaryStep(
                  draft: draft,
                  onEditStep: (_) {},
                  onConfirm: () => confirmCalled = true,
                  isProcessing: true,
                  showActionButton: true,
                ),
              ),
            ),
          ),
        );
        // Usar pump() en lugar de pumpAndSettle() porque CircularProgressIndicator anima indefinidamente
        await tester.pump();

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('btn_confirmar_reserva')),
        );
        expect(button.onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
        await tester.pump();
        expect(confirmCalled, isFalse);
      },
    );
  });

  group('HU12-RF02: Invalidación y conservación de datos en ReservationDraftViewModel', () {
    test(
      'modificar un campo sin cambiar el valor conserva todos los datos sin invalidar',
      () {
        final restaurant = _buildRestaurant(mesasRestaurante);
        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => testClock,
        );

        vm.selectBranch(sucursal);
        vm.selectDate(testDate);
        vm.selectDuration(90);
        vm.setPartySize(4);
        vm.setSelectedTables([mesasRestaurante[1]]);
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 14, 0),
          fin: DateTime(2026, 10, 30, 15, 30),
        ));

        expect(vm.draft.isReadyForSummary, isTrue);
        expect(vm.draft.mesaIds, equals(['M2']));
        expect(vm.draft.horario, isNotNull);

        // Volver a seleccionar la misma fecha -> No invalida
        vm.selectDate(testDate);
        expect(vm.draft.mesaIds, equals(['M2']));
        expect(vm.draft.horario, isNotNull);

        // Volver a seleccionar la misma duración -> No invalida
        vm.selectDuration(90);
        expect(vm.draft.mesaIds, equals(['M2']));
        expect(vm.draft.horario, isNotNull);

        // Volver a seleccionar la misma cantidad de personas -> No invalida
        vm.setPartySize(4);
        expect(vm.draft.mesaIds, equals(['M2']));
        expect(vm.draft.horario, isNotNull);

        // Volver a seleccionar la misma mesa -> No invalida horario
        vm.setSelectedTables([mesasRestaurante[1]]);
        expect(vm.draft.horario, isNotNull);
      },
    );

    test(
      'modificar horario a uno nuevo conserva fecha, duración, personas y mesa',
      () {
        final restaurant = _buildRestaurant(mesasRestaurante);
        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => testClock,
        );

        vm.selectBranch(sucursal);
        vm.selectDate(testDate);
        vm.selectDuration(90);
        vm.setPartySize(4);
        vm.setSelectedTables([mesasRestaurante[1]]);
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 14, 0),
          fin: DateTime(2026, 10, 30, 15, 30),
        ));

        // Cambiar únicamente el horario
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 15, 0),
          fin: DateTime(2026, 10, 30, 16, 30),
        ));

        // Todos los demás campos se mantienen
        expect(vm.draft.branch?.id, equals('br_centro'));
        expect(vm.draft.fecha, equals(testDate));
        expect(vm.draft.duracionMin, equals(90));
        expect(vm.draft.personas, equals(4));
        expect(vm.draft.mesaIds, equals(['M2']));
        expect(vm.draft.horario, equals(const TimeOfDay(hour: 15, minute: 0)));
      },
    );

    test(
      'modificar cantidad de personas invalida mesa y horario pero mantiene fecha y duración',
      () {
        final restaurant = _buildRestaurant(mesasRestaurante);
        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => testClock,
        );

        vm.selectBranch(sucursal);
        vm.selectDate(testDate);
        vm.selectDuration(90);
        vm.setPartySize(4);
        vm.setSelectedTables([mesasRestaurante[1]]);
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 14, 0),
          fin: DateTime(2026, 10, 30, 15, 30),
        ));

        // Cambiar personas de 4 a 6 (HU12-RF02)
        vm.setPartySize(6);

        // Mesas y horario se invalidan porque cambia la adecuación
        expect(vm.draft.personas, equals(6));
        expect(vm.draft.mesaIds, isEmpty);
        expect(vm.draft.horario, isNull);

        // Fecha y duración se conservan
        expect(vm.draft.fecha, equals(testDate));
        expect(vm.draft.duracionMin, equals(90));
        expect(vm.draft.branch?.id, equals('br_centro'));
      },
    );

    test(
      'modificar mesa a una diferente invalida horario pero mantiene fecha, duración y personas',
      () {
        final restaurant = _buildRestaurant(mesasRestaurante);
        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => testClock,
        );

        vm.selectBranch(sucursal);
        vm.selectDate(testDate);
        vm.selectDuration(90);
        vm.setPartySize(2);
        vm.setSelectedTables([mesasRestaurante[0]]); // M1
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 14, 0),
          fin: DateTime(2026, 10, 30, 15, 30),
        ));

        // Cambiar de mesa M1 a M2
        vm.setSelectedTables([mesasRestaurante[1]]);

        // Horario se invalida porque la nueva mesa tiene su propia disponibilidad
        expect(vm.draft.mesaIds, equals(['M2']));
        expect(vm.draft.horario, isNull);

        // Fecha, duración y personas se conservan
        expect(vm.draft.fecha, equals(testDate));
        expect(vm.draft.duracionMin, equals(90));
        expect(vm.draft.personas, equals(2));
      },
    );

    test('goToStep navega a cualquiera de los pasos (0 a 6)', () {
      final restaurant = _buildRestaurant(mesasRestaurante);
      final vm = ReservationDraftViewModel(restaurant: restaurant);

      vm.goToStep(6);
      expect(vm.currentStep, equals(6));

      vm.goToStep(2);
      expect(vm.currentStep, equals(2));

      vm.goToStep(0);
      expect(vm.currentStep, equals(0));
    });
  });

  group('HU12-RF01 y HU11-RF03: Integración completa en ReservationFlowView', () {
    testWidgets(
      'flujo completo avanza hasta el paso 6 (Resumen) y muestra todos los datos capturados',
      (tester) async {
        setLargeScreen(tester);
        final restaurant = _buildRestaurant(mesasRestaurante);
        final mockRepo = _MockReservationRepo();
        final availability = AvailabilityService(mockRepo, now: () => testClock);

        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => testClock,
        );

        // Paso 0: Sucursal
        vm.selectBranch(sucursal);
        vm.nextStep(); // 1: Fecha
        vm.selectDate(testDate);
        vm.nextStep(); // 2: Duración
        vm.selectDuration(90);
        vm.nextStep(); // 3: Personas
        vm.setPartySize(4);
        vm.nextStep(); // 4: Mesa
        vm.setSelectedTables([mesasRestaurante[1]]);
        vm.nextStep(); // 5: Horario
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 14, 0),
          fin: DateTime(2026, 10, 30, 15, 30),
        ));
        vm.nextStep(); // 6: Resumen

        expect(vm.currentStep, equals(6));

        await tester.pumpWidget(
          MaterialApp(
            home: ReservationFlowView(
              restaurant: restaurant,
              viewModel: vm,
              availabilityService: availability,
              isAuthenticated: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // En el paso 6 se muestra la pantalla de resumen
        expect(find.text('Resumen de la reserva'), findsOneWidget);
        expect(find.text('Miel Aurum'), findsOneWidget);
        expect(find.text('4 personas'), findsOneWidget);
        expect(find.text(vm.draft.formattedTimeRange), findsOneWidget);
        expect(find.textContaining('M2'), findsWidgets);

        // Botón Confirmar reserva / Continuar está visible y habilitado
        expect(find.byKey(const ValueKey('btn_confirmar_reserva')), findsOneWidget);
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('btn_confirmar_reserva')),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'pulsar Modificar en fecha regresa al paso 1 sin perder el resto de los datos ya capturados',
      (tester) async {
        setLargeScreen(tester);
        final restaurant = _buildRestaurant(mesasRestaurante);
        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => testClock,
        );

        vm.selectBranch(sucursal);
        vm.nextStep();
        vm.selectDate(testDate);
        vm.nextStep();
        vm.selectDuration(90);
        vm.nextStep();
        vm.setPartySize(4);
        vm.nextStep();
        vm.setSelectedTables([mesasRestaurante[1]]);
        vm.nextStep();
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 14, 0),
          fin: DateTime(2026, 10, 30, 15, 30),
        ));
        vm.nextStep(); // Paso 6: Resumen

        await tester.pumpWidget(
          MaterialApp(
            home: ReservationFlowView(
              restaurant: restaurant,
              viewModel: vm,
              availabilityService: AvailabilityService(_MockReservationRepo(), now: () => testClock),
              isAuthenticated: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Resumen de la reserva'), findsOneWidget);

        // Tocar botón Modificar en Fecha
        await tester.tap(find.byKey(const ValueKey('btn_modificar_fecha')));
        await tester.pumpAndSettle();

        // Regresó al paso 1 (Fecha)
        expect(vm.currentStep, equals(1));
        expect(find.textContaining('visitarnos'), findsWidgets);

        // Los demás datos capturados en el borrador se conservan
        expect(vm.draft.branch?.id, equals('br_centro'));
        expect(vm.draft.duracionMin, equals(90));
        expect(vm.draft.personas, equals(4));
        expect(vm.draft.mesaIds, equals(['M2']));
        expect(vm.draft.horario, isNotNull);
      },
    );

    testWidgets(
      'si visitante no tiene sesión iniciada, al confirmar se pide iniciar sesión y borrador se conserva',
      (tester) async {
        setLargeScreen(tester);
        final restaurant = _buildRestaurant(mesasRestaurante);
        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => testClock,
        );

        vm.selectBranch(sucursal);
        vm.nextStep();
        vm.selectDate(testDate);
        vm.nextStep();
        vm.selectDuration(90);
        vm.nextStep();
        vm.setPartySize(4);
        vm.nextStep();
        vm.setSelectedTables([mesasRestaurante[1]]);
        vm.nextStep();
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 14, 0),
          fin: DateTime(2026, 10, 30, 15, 30),
        ));
        vm.nextStep(); // Paso 6

        bool authCallbackTriggered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: ReservationFlowView(
              restaurant: restaurant,
              viewModel: vm,
              availabilityService: AvailabilityService(_MockReservationRepo(), now: () => testClock),
              isAuthenticated: false, // Visitante sin sesión
              onRequireAuth: () => authCallbackTriggered = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Intenta confirmar la reserva
        await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
        await tester.pumpAndSettle();

        // Se le pide iniciar sesión o registrarse
        expect(authCallbackTriggered, isTrue);

        // El borrador se conserva intacto
        expect(vm.draft.branch?.id, equals('br_centro'));
        expect(vm.draft.fecha, equals(testDate));
        expect(vm.draft.duracionMin, equals(90));
        expect(vm.draft.personas, equals(4));
        expect(vm.draft.mesaIds, equals(['M2']));
        expect(vm.draft.horario, equals(const TimeOfDay(hour: 14, minute: 0)));
      },
    );

    testWidgets(
      'el botón Continuar avanza al paso de captura de datos de contacto (HU13) sin crear la reserva',
      (tester) async {
        setLargeScreen(tester);
        final restaurant = _buildRestaurant(mesasRestaurante);
        final mockRepo = _MockReservationRepo();
        final vm = ReservationDraftViewModel(
          restaurant: restaurant,
          clock: () => testClock,
        );

        vm.selectBranch(sucursal);
        vm.nextStep();
        vm.selectDate(testDate);
        vm.nextStep();
        vm.selectDuration(90);
        vm.nextStep();
        vm.setPartySize(4);
        vm.nextStep();
        vm.setSelectedTables([mesasRestaurante[1]]);
        vm.nextStep();
        vm.selectTime(TimeSlot(
          inicio: DateTime(2026, 10, 30, 14, 0),
          fin: DateTime(2026, 10, 30, 15, 30),
        ));
        vm.nextStep(); // Paso 6

        ReservationDraftModel? receivedDraft;

        await tester.pumpWidget(
          MaterialApp(
            home: ReservationFlowView(
              restaurant: restaurant,
              viewModel: vm,
              availabilityService: AvailabilityService(mockRepo, now: () => testClock),
              isAuthenticated: true,
              onProceedToContact: (d) => receivedDraft = d,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pulsar el botón para avanzar a HU13
        await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // HU12-RF01 Criterio 4: Avanza al paso de captura de datos de contacto
        expect(receivedDraft, isNotNull);
        expect(receivedDraft!.personas, equals(4));
        expect(receivedDraft!.mesaIds, equals(['M2']));

        // HU12-RF01 Criterio 5: La pantalla es de solo confirmación; no crea la reserva todavía
        expect(mockRepo.createCalls, equals(0));
      },
    );
  });
}
