import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/reservation_flow_view.dart';

const _dias = [
  'lunes',
  'martes',
  'miercoles',
  'jueves',
  'viernes',
  'sabado',
  'domingo',
];

RestaurantModel _restaurante({Map<String, DaySchedule>? horarios}) {
  return RestaurantModel(
    id: 'r1',
    nombre: 'Miel Test',
    estado: 'activo',
    horarios: horarios ??
        {
          for (final d in _dias)
            d: const DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00'),
        },
  );
}

void main() {
  // Viernes 30 de octubre de 2026.
  DateTime hora(int h, [int m = 0]) => DateTime(2026, 10, 30, h, m);

  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<void> conSucursal() async {
    await db.collection('restaurants').doc('r1').set({
      'nombre': 'Miel Test',
      'sucursalPrincipal': {
        'nombre': 'Miel Centro',
        'direccion': 'Calle 1',
        'telefono': '555',
      },
    });
  }

  Future<ReservationDraftViewModel> abrir(
    WidgetTester tester, {
    required DateTime ahora,
    RestaurantModel? restaurante,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final r = restaurante ?? _restaurante();
    final reservas = ReservationService(firestore: db);
    final disponibilidad = AvailabilityService(reservas, now: () => ahora);
    final vm = ReservationDraftViewModel(
      restaurant: r,
      restaurantService: RestaurantService(firestore: db),
      clock: () => ahora,
    );
    await tester.pumpWidget(MaterialApp(
      home: ReservationFlowView(
        restaurant: r,
        viewModel: vm,
        availabilityService: disponibilidad,
        bookingService: ReservationBookingService(disponibilidad, reservas),
        isAuthenticated: true,
        currentUserId: 'u1',
      ),
    ));
    await tester.pumpAndSettle();
    return vm;
  }

  group('Paso de sucursal: sin sucursales no se reserva', () {
    testWidgets('sin sucursales registradas avisa y no deja comenzar', (tester) async {
      await db.collection('restaurants').doc('r1').set({'nombre': 'Miel Test'});
      final vm = await abrir(tester, ahora: hora(14));

      expect(vm.sinSucursales, isTrue);
      expect(find.byKey(const ValueKey('sin_sucursales')), findsOneWidget);
      expect(find.text('Este restaurante aún no tiene sucursales disponibles'), findsOneWidget);
      expect(find.text('No hay sucursales disponibles para reservar'), findsOneWidget);

      final boton = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_comenzar_reserva')));
      expect(boton.onPressed, isNull);
      expect(vm.canAdvanceCurrentStep, isFalse);
    });

    testWidgets('no se inventan sucursales de ejemplo', (tester) async {
      await db.collection('restaurants').doc('r1').set({'nombre': 'Miel Test'});
      await abrir(tester, ahora: hora(14));

      expect(find.textContaining('Norte'), findsNothing);
      expect(find.textContaining('Plaza'), findsNothing);
      expect(find.textContaining('Blvd'), findsNothing);
    });

    testWidgets('con una sucursal real se muestra y se puede comenzar', (tester) async {
      await conSucursal();
      final vm = await abrir(tester, ahora: hora(14));

      expect(vm.sinSucursales, isFalse);
      expect(find.text('Miel Centro'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('branch_card_principal')));
      await tester.pumpAndSettle();
      final boton = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_comenzar_reserva')));
      expect(boton.onPressed, isNotNull);
    });

    testWidgets('ya no hay tarjetas informativas fijas, solo una línea', (tester) async {
      await conSucursal();
      await abrir(tester, ahora: hora(14));

      expect(find.text('Selecciona fecha y duración'), findsNothing);
      expect(find.text('Elige tu mesa'), findsNothing);
      expect(find.text('Confirmación inmediata'), findsNothing);
      expect(find.textContaining('Después elegirás la fecha'), findsOneWidget);
    });
  });

  group('Paso de sucursal: estado de apertura con horarios reales', () {
    testWidgets('dentro del horario dice hasta qué hora abre', (tester) async {
      await conSucursal();
      await abrir(tester, ahora: hora(14));
      expect(find.text('Abierto hasta 22:00'), findsOneWidget);
    });

    testWidgets('antes de abrir dice a qué hora abre', (tester) async {
      await conSucursal();
      await abrir(tester, ahora: hora(10));
      expect(find.text('Abre a las 12:00'), findsOneWidget);
    });

    testWidgets('después de cerrar dice cerrado ahora', (tester) async {
      await conSucursal();
      await abrir(tester, ahora: hora(23, 30));
      expect(find.text('Cerrado ahora'), findsOneWidget);
    });

    testWidgets('si hoy no abre dice cerrado hoy', (tester) async {
      await conSucursal();
      final cerradoViernes = _restaurante(horarios: {
        for (final d in _dias)
          d: DaySchedule(abierto: d != 'viernes', apertura: '12:00', cierre: '22:00'),
      });
      await abrir(tester, ahora: hora(14), restaurante: cerradoViernes);
      expect(find.text('Cerrado hoy'), findsOneWidget);
    });

    testWidgets('sin horarios registrados no muestra etiqueta falsa', (tester) async {
      await conSucursal();
      await abrir(tester, ahora: hora(14), restaurante: _restaurante(horarios: const {}));
      expect(find.text('Abierto'), findsNothing);
      expect(find.textContaining('Abierto hasta'), findsNothing);
      expect(find.text('Cerrado hoy'), findsNothing);
    });
  });
}
