import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/table_availability_models.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/reservation_flow_view.dart';
import 'package:reservitta/views/widgets/prepare_visit_step.dart';

class _DummyReservationRepository implements ReservationRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAvailabilityService extends AvailabilityService {
  _FakeAvailabilityService() : super(_DummyReservationRepository());

  @override
  int get margenLimpiezaMin => 15;

  @override
  Future<SelectionValidation> revalidateSelection({
    required RestaurantModel restaurant,
    required DateTime inicio,
    required int duracionMin,
    required List<String> mesaIds,
    int maxAlternativas = 4,
  }) async {
    return const SelectionValidation.valid();
  }
}

class _SpyReservationBookingService extends ReservationBookingService {
  ReservationDraftModel? lastDraftConfirmed;
  String? lastUsuarioId;
  int confirmCallCount = 0;

  _SpyReservationBookingService()
      : super(_FakeAvailabilityService(), _DummyReservationRepository());

  @override
  Future<BookingResult> confirm({
    required RestaurantModel restaurant,
    required ReservationDraftModel draft,
    required String usuarioId,
    String contactoNombre = '',
    String contactoCorreo = '',
    String contactoTelefono = '',
  }) async {
    confirmCallCount++;
    lastDraftConfirmed = draft;
    lastUsuarioId = usuarioId;

    final dummyReserva = ReservationModel.create(
      id: 'res_mock_123',
      restauranteId: restaurant.id,
      usuarioId: usuarioId,
      restauranteNombre: restaurant.nombre,
      contactoNombre: contactoNombre,
      contactoCorreo: contactoCorreo,
      contactoTelefono: contactoTelefono,
      fechaLocal: '2026-11-10',
      inicio: draft.inicio ?? DateTime(2026, 11, 10, 14, 0),
      duracionMin: draft.duracionMin,
      personas: draft.personas,
      mesaIds: draft.mesaIds,
      mesasNombres: draft.mesasNombres,
      estado: ReservationModel.estadoConfirmada,
      preordenItems: draft.preordenItems,
      alergias: draft.alergias,
      notasAlergias: draft.notasAlergias,
      ocasionEspecial: draft.ocasionEspecial,
      experiencias: draft.experiencias,
    );

    return BookingConfirmed(dummyReserva);
  }
}

RestaurantModel _buildRestaurant() {
  return RestaurantModel(
    id: 'rest_demo_1',
    nombre: 'Terraza Gourmet',
    descripcion: 'Cocina de autor',
    direccion: 'Av. Reforma 123',
    telefono: '555-1234',
    diasAbiertos: const ['martes'],
    horarios: {
      'martes': const DaySchedule(abierto: true, apertura: '12:00', cierre: '23:00'),
    },
    capacidadMaxima: 40,
    estado: 'activo',
  );
}

ReservationDraftViewModel _buildDraftViewModel(RestaurantModel r) {
  final vm = ReservationDraftViewModel(
    restaurant: r,
    clock: () => DateTime(2026, 11, 10, 10, 0),
  );
  vm.selectBranch(
    const BranchModel(
      id: 'b1',
      nombre: 'Matriz',
      direccion: 'Av. Reforma 123',
      telefono: '555-1234',
      esPrincipal: true,
    ),
  );
  vm.selectDate(DateTime(2026, 11, 10));
  vm.selectDuration(90);
  vm.setPartySize(3);
  vm.setSelectedTables([
    const MesaModel(
      id: 'mesa_1',
      nombre: 'Mesa 1',
      capacidad: 4,
    ),
  ]);
  vm.selectTime(
    TimeSlot(
      inicio: DateTime(2026, 11, 10, 14, 0),
      fin: DateTime(2026, 11, 10, 15, 30),
    ),
  );
  vm.setContactName('Carlos Morales');
  vm.setContactEmail('carlos@test.com');
  vm.setContactPhone('4181234567');
  return vm;
}

void main() {
  group('HU15-RF01: Pantalla "¿Quieres preparar tu visita?"', () {
    testWidgets('Muestra dos tarjetas: "Reservar solamente" y "Personalizar mi visita"', (tester) async {
      final r = _buildRestaurant();
      final vm = _buildDraftViewModel(r);
      vm.goToStep(8);

      bool soloReservarCalled = false;
      bool personalizarCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrepareVisitStep(
              draft: vm.draft,
              onSoloReservar: () => soloReservarCalled = true,
              onPersonalizarVisita: () => personalizarCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿Quieres preparar tu visita?'), findsOneWidget);
      expect(find.byKey(const ValueKey('card_reservar_solamente')), findsOneWidget);
      expect(find.byKey(const ValueKey('card_personalizar_visita')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_solo_reservar')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_personalizar_visita')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('btn_solo_reservar')));
      await tester.pump();
      expect(soloReservarCalled, isTrue);

      await tester.tap(find.byKey(const ValueKey('btn_personalizar_visita')));
      await tester.pump();
      expect(personalizarCalled, isTrue);
    });

    testWidgets('Botón "Solo reservar" confirma la reserva directamente sin duplicar pasos', (tester) async {
      final r = _buildRestaurant();
      final vm = _buildDraftViewModel(r);
      final spyBooking = _SpyReservationBookingService();

      vm.goToStep(7); // Paso de contacto

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationFlowView(
            restaurant: r,
            viewModel: vm,
            enableContactStep: true,
            enablePrepareVisitStep: true,
            createReservationOnConfirm: true,
            bookingService: spyBooking,
            isAuthenticated: true,
            currentUserId: 'user_carlos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En paso 7, pulsar continuar
      await tester.tap(find.byKey(const ValueKey('btn_continuar_step_7')));
      await tester.pumpAndSettle();

      // Debe estar en paso 8: PrepareVisitStep
      expect(vm.currentStep, equals(8));
      expect(find.byKey(const ValueKey('step_preparar_visita')), findsOneWidget);

      // Pulsar "Solo reservar"
      await tester.tap(find.byKey(const ValueKey('btn_solo_reservar')));
      await tester.pumpAndSettle();

      expect(spyBooking.confirmCallCount, equals(1));
      expect(spyBooking.lastDraftConfirmed?.tienePersonalizacion, isFalse);
    });

    testWidgets('El usuario puede volver atrás desde paso 8 para modificar datos de contacto', (tester) async {
      final r = _buildRestaurant();
      final vm = _buildDraftViewModel(r);

      vm.goToStep(8);

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationFlowView(
            restaurant: r,
            viewModel: vm,
            enableContactStep: true,
            enablePrepareVisitStep: true,
            createReservationOnConfirm: true,
            isAuthenticated: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_preparar_visita')), findsOneWidget);

      // Pulsar botón atrás en el stepper
      await tester.tap(find.byKey(const ValueKey('btn_stepper_back')));
      await tester.pumpAndSettle();

      expect(vm.currentStep, equals(7));
      expect(find.byKey(const ValueKey('step_contacto')), findsOneWidget);
    });
  });

  group('HU15-RF02: Reutilización de endpoints entre ambos caminos', () {
    testWidgets('Ambos caminos consumen el mismo bookingService.confirm sin duplicar validaciones', (tester) async {
      final r = _buildRestaurant();
      final vm = _buildDraftViewModel(r);
      final spyBooking = _SpyReservationBookingService();

      // Camino 1: Reserva directa
      await spyBooking.confirm(
        restaurant: r,
        draft: vm.draft,
        usuarioId: 'user_1',
        contactoNombre: vm.draft.contactoNombre,
        contactoCorreo: vm.draft.contactoCorreo,
        contactoTelefono: vm.draft.contactoTelefono,
      );

      expect(spyBooking.confirmCallCount, equals(1));
      expect(spyBooking.lastDraftConfirmed?.preordenItems.isEmpty, isTrue);
      expect(spyBooking.lastDraftConfirmed?.alergias.isEmpty, isTrue);

      // Camino 2: Reserva con personalización (agrega preorden y alergias al payload)
      final draftPersonalizado = vm.draft.copyWith(
        preordenItems: [
          {'platilloId': 'p1', 'nombre': 'Guacamole', 'precio': 120.0, 'cantidad': 2, 'total': 240.0}
        ],
        alergias: ['Gluten', 'Mariscos'],
        notasAlergias: 'Sin condimentos picantes',
        ocasionEspecial: () => {'id': 'oc_1', 'nombre': 'Cumpleaños'},
        experiencias: [
          {'id': 'exp_1', 'nombre': 'Pastel', 'precio': 150.0, 'esGratis': false}
        ],
      );

      await spyBooking.confirm(
        restaurant: r,
        draft: draftPersonalizado,
        usuarioId: 'user_1',
        contactoNombre: draftPersonalizado.contactoNombre,
        contactoCorreo: draftPersonalizado.contactoCorreo,
        contactoTelefono: draftPersonalizado.contactoTelefono,
      );

      expect(spyBooking.confirmCallCount, equals(2));
      expect(spyBooking.lastDraftConfirmed?.preordenItems.length, equals(1));
      expect(spyBooking.lastDraftConfirmed?.alergias, contains('Gluten'));
      expect(spyBooking.lastDraftConfirmed?.subtotalPreorden, equals(240.0));
      expect(spyBooking.lastDraftConfirmed?.totalPersonalizacion, equals(390.0));
    });
  });
}
