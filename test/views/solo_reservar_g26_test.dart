import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/reservation_confirmation_view.dart';
import 'package:reservitta/views/reservation_flow_view.dart';

RestaurantModel _restaurant() {
  return RestaurantModel(
    id: 'rest_demo_1',
    nombre: 'Terraza Gourmet',
    estado: 'activo',
    diasAbiertos: const ['martes'],
    horarios: const {
      'martes': DaySchedule(abierto: true, apertura: '12:00', cierre: '23:00'),
    },
    capacidadMaxima: 40,
  );
}

Map<String, dynamic> _linea(String id, String nombre, String observacion) => {
      'platilloId': id,
      'nombre': nombre,
      'precio': 100.0,
      'cantidad': 1,
      'total': 100.0,
      'observacion': observacion,
    };

/// Borrador en el paso "¿Quieres preparar tu visita?" con personalización vieja:
/// el visitante llegó a armar un pedido y luego decidió solo reservar.
ReservationDraftViewModel _draftConPersonalizacion(RestaurantModel r) {
  final vm = ReservationDraftViewModel(
    restaurant: r,
    clock: () => DateTime(2026, 11, 9, 10),
  );
  vm.selectBranch(const BranchModel(
    id: 'b1',
    nombre: 'Matriz',
    direccion: 'Av. Reforma 123',
    telefono: '555-1234',
    esPrincipal: true,
  ));
  vm.selectDate(DateTime(2026, 11, 10));
  vm.selectDuration(90);
  vm.setPartySize(3);
  vm.setSelectedTables([
    const MesaModel(id: 'mesa_1', nombre: 'Mesa 1', capacidad: 4),
  ]);
  vm.selectTime(TimeSlot(
    inicio: DateTime(2026, 11, 10, 14),
    fin: DateTime(2026, 11, 10, 15, 30),
  ));
  vm.setContactName('Carlos Morales');
  vm.setContactEmail('carlos@test.com');
  vm.setContactPhone('4181234567');
  vm.setPreordenItems([_linea('p1', 'Pasta', 'sin gluten')]);
  vm.setAlergias(['Nueces'], notas: 'Una persona celíaca');
  return vm;
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  testWidgets(
      '"Solo reservar" guarda la reserva sin ningún registro de restricciones',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = FakeFirebaseFirestore();
    final repo = ReservationService(firestore: db);
    final availability =
        AvailabilityService(repo, now: () => DateTime(2026, 11, 9, 10));
    final r = _restaurant();
    final vm = _draftConPersonalizacion(r);
    expect(vm.draft.tienePersonalizacion, isTrue);
    vm.goToStep(8);

    await tester.pumpWidget(MaterialApp(
      home: ReservationFlowView(
        restaurant: r,
        viewModel: vm,
        enableContactStep: true,
        enablePrepareVisitStep: true,
        createReservationOnConfirm: true,
        availabilityService: availability,
        bookingService: ReservationBookingService(availability, repo),
        isAuthenticated: true,
        currentUserId: 'user_carlos',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('btn_solo_reservar')));
    await tester.pumpAndSettle();

    expect(find.byType(ReservationConfirmationView), findsOneWidget);
    final docs = (await db.collection('reservations').get()).docs;
    expect(docs, hasLength(1));
    final data = docs.single.data();
    expect(data['usuarioId'], 'user_carlos');
    for (final clave in [
      'preorden',
      'totales',
      'alergias',
      'notasAlergias',
      'tieneRestricciones',
      'tieneObservaciones',
    ]) {
      expect(data.containsKey(clave), isFalse, reason: 'no debe existir "$clave"');
    }
    expect(data['tienePreorden'], isFalse);
  });
}
