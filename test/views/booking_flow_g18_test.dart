import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/reservation_confirmation_view.dart';
import 'package:reservitta/views/reservation_flow_view.dart';

const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

final _mesas = [
  const MesaModel(id: 'M2', nombre: 'M2', capacidad: 4, x: 0, y: 0),
  const MesaModel(id: 'M3', nombre: 'M3', capacidad: 6, x: 120, y: 0),
];

RestaurantModel _restaurant() {
  return RestaurantModel(
    id: 'r1',
    nombre: 'Miel Test',
    estado: 'activo',
    mesas: _mesas,
    horarios: {
      for (final d in [
        'lunes',
        'martes',
        'miercoles',
        'jueves',
        'viernes',
        'sabado',
        'domingo'
      ])
        d: _horario,
    },
  );
}

ReservationModel _reservaDeOtro(DateTime inicio, {int duracion = 90}) {
  return ReservationModel.create(
    id: 'otro_${inicio.hour}',
    restauranteId: 'r1',
    usuarioId: 'otro',
    fechaLocal: '2026-10-30',
    inicio: inicio,
    duracionMin: duracion,
    mesaIds: const ['M2'],
    estado: ReservationModel.estadoConfirmada,
  );
}

/// Simula que otra persona reserva la mesa justo entre la revalidación y el guardado.
class _RaceRepo extends ReservationService {
  _RaceRepo(FakeFirebaseFirestore db) : super(firestore: db);

  @override
  Future<ReservationModel> createReservationVerified(
    ReservationModel reservation, {
    int margenLimpiezaMin = 0,
  }) async {
    throw const ReservationConflictException({'M2'});
  }
}

class _OfflineRepo extends ReservationService {
  _OfflineRepo(FakeFirebaseFirestore db) : super(firestore: db);

  @override
  Future<ReservationModel> createReservationVerified(
    ReservationModel reservation, {
    int margenLimpiezaMin = 0,
  }) async {
    throw const ReservationConnectionException('unavailable');
  }
}

void main() {
  final now = DateTime(2026, 10, 25, 10);
  final viernes = DateTime(2026, 10, 30);
  const sucursal = BranchModel(
    id: 'b1',
    nombre: 'Centro',
    direccion: 'Calle 1',
    telefono: '1',
    esPrincipal: true,
  );

  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Borrador listo en el paso indicado (5 = horario, 6 = resumen) con M2 a las 14:00.
  ReservationDraftViewModel draftAt(int step) {
    final vm = ReservationDraftViewModel(
      restaurant: _restaurant(),
      clock: () => now,
    );
    vm.selectBranch(sucursal);
    vm.selectDate(viernes);
    vm.setPartySize(4);
    vm.setSelectedTables([_mesas.first]);
    vm.selectTime(TimeSlot(inicio: DateTime(2026, 10, 30, 14), fin: DateTime(2026, 10, 30, 15, 30)));
    vm.goToStep(step);
    return vm;
  }

  Future<void> pumpFlow(
    WidgetTester tester,
    ReservationDraftViewModel vm, {
    ReservationService? repo,
    bool booking = false,
  }) async {
    bigScreen(tester);
    final reservations = repo ?? ReservationService(firestore: db);
    final availability = AvailabilityService(reservations, now: () => now);
    await tester.pumpWidget(MaterialApp(
      home: ReservationFlowView(
        restaurant: _restaurant(),
        viewModel: vm,
        availabilityService: availability,
        bookingService: ReservationBookingService(availability, reservations),
        isAuthenticated: true,
        currentUserId: 'user_42',
        createReservationOnConfirm: booking,
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('HU12-RF02 revalidación antes del resumen', () {
    testWidgets('si la mesa sigue libre pasa al resumen', (tester) async {
      final vm = draftAt(5);
      await pumpFlow(tester, vm);

      await tester.tap(find.byKey(const ValueKey('btn_continuar_step_5')));
      await tester.pumpAndSettle();

      expect(vm.currentStep, 6);
      expect(find.text('Resumen de la reserva'), findsOneWidget);
    });

    testWidgets(
        'si otra persona reservó la mesa informa y regresa a elegir horario',
        (tester) async {
      final vm = draftAt(5);
      await pumpFlow(tester, vm);
      // Otra persona reserva M2 mientras el usuario estaba en el paso de horario.
      await db
          .collection('reservations')
          .doc('otro')
          .set(_reservaDeOtro(DateTime(2026, 10, 30, 14)).toMap());

      await tester.tap(find.byKey(const ValueKey('btn_continuar_step_5')));
      await tester.pumpAndSettle();

      expect(vm.currentStep, 5);
      expect(vm.draft.horario, isNull);
      expect(find.byKey(const ValueKey('snack_flow_message')), findsOneWidget);
      expect(find.textContaining('Elige otro horario'), findsOneWidget);
      // El horario ocupado ya no se ofrece.
      expect(find.byKey(const ValueKey('slot_chip_1400')), findsNothing);
      expect(find.byKey(const ValueKey('slot_chip_1600')), findsOneWidget);
    });

    testWidgets('si a la mesa no le quedan horarios regresa a elegir mesa',
        (tester) async {
      final vm = draftAt(5);
      await pumpFlow(tester, vm);
      await db
          .collection('reservations')
          .doc('otro')
          .set(_reservaDeOtro(DateTime(2026, 10, 30, 12), duracion: 600).toMap());

      await tester.tap(find.byKey(const ValueKey('btn_continuar_step_5')));
      await tester.pumpAndSettle();

      expect(vm.currentStep, 4);
      expect(vm.draft.mesaIds, isEmpty);
      expect(find.textContaining('Elige otra mesa'), findsOneWidget);
    });
  });

  group('HU11-RF04 confirmación de la reserva', () {
    testWidgets('guarda la reserva y muestra la pantalla de confirmación',
        (tester) async {
      final vm = draftAt(6);
      await pumpFlow(tester, vm, booking: true);

      await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
      await tester.pumpAndSettle();

      expect(find.byType(ReservationConfirmationView), findsOneWidget);
      expect(find.text('¡Reserva confirmada!'), findsOneWidget);
      expect(find.text('Miel Test'), findsOneWidget);
      expect(find.text('14:00 – 15:30'), findsOneWidget);
      expect(find.text('M2'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);

      final guardadas = await db.collection('reservations').get();
      expect(guardadas.docs, hasLength(1));
      expect(guardadas.docs.single.data()['usuarioId'], 'user_42');
    });

    testWidgets('si la mesa ya fue reservada ofrece horarios alternativos',
        (tester) async {
      final vm = draftAt(6);
      await pumpFlow(tester, vm, repo: _RaceRepo(db), booking: true);

      await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('booking_conflict_dialog')), findsOneWidget);
      expect(find.textContaining('acaba de ser reservada por otra persona'),
          findsOneWidget);
      expect(find.byType(ActionChip), findsWidgets);
      expect(await db.collection('reservations').get().then((s) => s.docs), isEmpty);
    });

    testWidgets('elegir un horario alternativo lo guarda y vuelve al resumen',
        (tester) async {
      final vm = draftAt(6);
      await pumpFlow(tester, vm, repo: _RaceRepo(db), booking: true);

      await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
      await tester.pumpAndSettle();
      final chip = find.byType(ActionChip).first;
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('booking_conflict_dialog')), findsNothing);
      expect(vm.currentStep, 6);
      expect(vm.draft.horario, isNotNull);
    });

    testWidgets('"Elegir otra mesa" regresa al paso de mesa', (tester) async {
      final vm = draftAt(6);
      await pumpFlow(tester, vm, repo: _RaceRepo(db), booking: true);

      await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('btn_conflict_other_table')));
      await tester.pumpAndSettle();

      expect(vm.currentStep, 4);
      expect(vm.draft.mesaIds, isEmpty);
    });

    testWidgets('si falla la conexión informa, permite reintentar y no guarda',
        (tester) async {
      final vm = draftAt(6);
      await pumpFlow(tester, vm, repo: _OfflineRepo(db), booking: true);

      await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Se perdió la conexión'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.byType(ReservationConfirmationView), findsNothing);
      expect(vm.currentStep, 6);
      expect(await db.collection('reservations').get().then((s) => s.docs), isEmpty);
    });

    testWidgets('sin el modo de reserva activo conserva el flujo anterior',
        (tester) async {
      final vm = draftAt(6);
      await pumpFlow(tester, vm); // createReservationOnConfirm = false

      await tester.tap(find.byKey(const ValueKey('btn_confirmar_reserva')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('snack_continuar_contacto')), findsOneWidget);
      expect(await db.collection('reservations').get().then((s) => s.docs), isEmpty);
    });
  });

  group('Pantalla de confirmación', () {
    testWidgets('muestra los datos de la reserva y el código', (tester) async {
      bigScreen(tester);
      final reserva = ReservationModel.create(
        id: 'abc123',
        restauranteId: 'r1',
        restauranteNombre: 'Miel Test',
        fechaLocal: '2026-10-30',
        inicio: DateTime(2026, 10, 30, 17),
        duracionMin: 90,
        personas: 6,
        mesaIds: const ['m1', 'm2'],
        mesasNombres: const ['T1', 'T2'],
        estado: ReservationModel.estadoConfirmada,
      );
      var terminado = false;
      await tester.pumpWidget(MaterialApp(
        home: ReservationConfirmationView(
          reservation: reserva,
          onDone: () => terminado = true,
        ),
      ));

      expect(find.text('¡Reserva confirmada!'), findsOneWidget);
      expect(find.text('V, 30 de Octubre'), findsOneWidget);
      expect(find.text('17:00 – 18:30'), findsOneWidget);
      expect(find.text('1 h 30 min'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('T1 + T2'), findsOneWidget);
      expect(find.text('Mesas'), findsOneWidget);
      expect(find.text('abc123'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('btn_confirmation_done')));
      expect(terminado, isTrue);
    });
  });
}
