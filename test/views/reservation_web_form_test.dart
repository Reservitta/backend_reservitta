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
import 'package:reservitta/views/reservation_flow_view.dart';
import 'package:reservitta/views/widgets/reservation_web_form.dart';
import 'package:reservitta/views/widgets/table_selection_step.dart';

const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

final _mesas = [
  const MesaModel(id: 'M2', nombre: 'M2', capacidad: 4, x: 0, y: 0),
  const MesaModel(id: 'M3', nombre: 'M3', capacidad: 6, x: 120, y: 0),
];

RestaurantModel _restaurant() => RestaurantModel(
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
          'domingo',
        ])
          d: _horario,
      },
    );

void main() {
  final ahora = DateTime(2026, 10, 25, 10);
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

  Future<ReservationDraftViewModel> abrir(
    WidgetTester tester, {
    double ancho = 1400,
  }) async {
    tester.view.physicalSize = Size(ancho, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vm = ReservationDraftViewModel(restaurant: _restaurant(), clock: () => ahora);
    vm.selectBranch(sucursal);
    vm.goToStep(1);
    final reservas = ReservationService(firestore: db);
    final disponibilidad = AvailabilityService(reservas, now: () => ahora);
    await tester.pumpWidget(MaterialApp(
      home: ReservationFlowView(
        restaurant: _restaurant(),
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

  Future<void> elegir(WidgetTester tester, String clave, String texto) async {
    await tester.tap(find.byKey(ValueKey(clave)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }

  bool habilitado(WidgetTester tester, String clave) {
    final dynamic menu = tester.widget(
      find.descendant(
        of: find.byKey(ValueKey(clave)),
        matching: find.byWidgetPredicate((w) => w is DropdownButton),
      ),
    );
    return menu.onChanged != null;
  }

  group('Reserva en una sola pantalla (web)', () {
    testWidgets('la barra de estado queda en la esquina superior derecha', (tester) async {
      await abrir(tester);

      final barra = tester.getRect(find.byType(BarraEstadoReserva));
      final titulo = tester.getRect(find.text('Haz tu reserva'));
      expect(barra.center.dx, greaterThan(700), reason: 'está en la mitad derecha');
      expect(barra.top, lessThan(120), reason: 'arriba');
      expect(titulo.right, lessThan(barra.left));
      for (final etapa in etapasReserva) {
        expect(
          find.descendant(of: find.byType(BarraEstadoReserva), matching: find.text(etapa)),
          findsOneWidget,
        );
      }
    });

    testWidgets('al inicio solo la fecha está habilitada y no hay mapa', (tester) async {
      await abrir(tester);

      expect(find.byKey(const ValueKey('campo_fecha')), findsOneWidget);
      expect(habilitado(tester, 'campo_duracion'), isFalse);
      expect(habilitado(tester, 'campo_personas'), isFalse);
      expect(habilitado(tester, 'campo_horario'), isFalse);
      expect(find.byKey(const ValueKey('mapa_pendiente')), findsOneWidget);
      expect(find.byType(TableSelectionStep), findsNothing);
      final continuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_web')));
      expect(continuar.onPressed, isNull);
    });

    testWidgets('cada campo se habilita al completar el anterior', (tester) async {
      final vm = await abrir(tester);

      vm.selectDate(viernes);
      await tester.pumpAndSettle();
      expect(habilitado(tester, 'campo_duracion'), isTrue);
      expect(habilitado(tester, 'campo_personas'), isFalse);

      await elegir(tester, 'campo_duracion', '2 horas');
      expect(vm.draft.duracionMin, 120);
      expect(habilitado(tester, 'campo_personas'), isTrue);
      expect(habilitado(tester, 'campo_horario'), isFalse);

      await elegir(tester, 'campo_personas', '3 personas');
      expect(vm.draft.personas, 3);
      expect(habilitado(tester, 'campo_horario'), isTrue);
      expect(find.byKey(const ValueKey('mapa_pendiente')), findsOneWidget);
    });

    testWidgets('con el horario elegido aparece el mapa y se puede continuar al resumen', (tester) async {
      final vm = await abrir(tester);
      vm.selectDate(viernes);
      await tester.pumpAndSettle();
      await elegir(tester, 'campo_duracion', '2 horas');
      await elegir(tester, 'campo_personas', '3 personas');
      await elegir(tester, 'campo_horario', '14:00');

      expect(vm.draft.horario, const TimeOfDay(hour: 14, minute: 0));
      expect(find.byType(TableSelectionStep), findsOneWidget);
      expect(find.byKey(const ValueKey('mapa_pendiente')), findsNothing);

      // Hasta elegir mesa no se puede continuar.
      var continuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_web')));
      expect(continuar.onPressed, isNull);

      vm.setSelectedTables([_mesas.first], conservarHorario: true);
      await tester.pumpAndSettle();
      expect(vm.draft.horario, isNotNull, reason: 'elegir mesa no borra la hora');
      continuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_web')));
      expect(continuar.onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('btn_continuar_web')));
      await tester.pumpAndSettle();
      expect(vm.currentStep, 6, reason: 'pasa a la pantalla del resumen');
      expect(find.byType(FormularioReservaWeb), findsNothing);
    });

    testWidgets('cambiar la hora descarta la mesa elegida', (tester) async {
      final vm = await abrir(tester);
      vm.selectDate(viernes);
      await tester.pumpAndSettle();
      await elegir(tester, 'campo_duracion', '2 horas');
      await elegir(tester, 'campo_personas', '3 personas');
      await elegir(tester, 'campo_horario', '14:00');
      vm.setSelectedTables([_mesas.first], conservarHorario: true);
      await tester.pumpAndSettle();
      expect(vm.draft.mesaIds, ['M2']);

      await elegir(tester, 'campo_horario', '15:00');
      expect(vm.draft.horario, const TimeOfDay(hour: 15, minute: 0));
      expect(vm.draft.mesaIds, isEmpty);
    });

    testWidgets('cambiar la fecha reinicia horario y mesa', (tester) async {
      final vm = await abrir(tester);
      vm.selectDate(viernes);
      await tester.pumpAndSettle();
      await elegir(tester, 'campo_duracion', '2 horas');
      await elegir(tester, 'campo_personas', '3 personas');
      await elegir(tester, 'campo_horario', '14:00');

      vm.selectDate(DateTime(2026, 10, 31));
      await tester.pumpAndSettle();
      expect(vm.draft.horario, isNull);
      expect(vm.draft.mesaIds, isEmpty);
      expect(find.byKey(const ValueKey('mapa_pendiente')), findsOneWidget);
    });

    testWidgets('el horario solo ofrece horas libres de ese día', (tester) async {
      // M2 y M3 ocupadas a las 14:00 por otra reserva: el mapa lo refleja.
      for (final id in ['M2', 'M3']) {
        await ReservationService(firestore: db).createReservationVerified(
          ReservationModel.create(
            id: 'otro_$id',
            restauranteId: 'r1',
            usuarioId: 'otro',
            fechaLocal: '2026-10-30',
            inicio: DateTime(2026, 10, 30, 14),
            duracionMin: 120,
            mesaIds: [id],
            estado: ReservationModel.estadoConfirmada,
          ),
        );
      }
      final vm = await abrir(tester);
      vm.selectDate(viernes);
      await tester.pumpAndSettle();
      await elegir(tester, 'campo_duracion', '2 horas');
      await elegir(tester, 'campo_personas', '3 personas');
      await elegir(tester, 'campo_horario', '14:00');

      expect(find.byType(TableSelectionStep), findsOneWidget);
      expect(vm.draft.mesaIds, isEmpty);
      final continuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_web')));
      expect(continuar.onPressed, isNull, reason: 'sin mesa libre no se avanza');
    });
  });

  group('Resumen con la opción de personalizar la visita', () {
    Future<ReservationDraftViewModel> enResumen(WidgetTester tester, {double ancho = 1400}) async {
      final vm = await abrir(tester, ancho: ancho);
      vm.selectDate(viernes);
      vm.selectDuration(120);
      vm.setPartySize(3);
      vm.setSelectedTables([_mesas.first]);
      vm.selectTime(TimeSlot(
        inicio: DateTime(2026, 10, 30, 14),
        fin: DateTime(2026, 10, 30, 16),
      ));
      vm.goToStep(6);
      await tester.pumpAndSettle();
      return vm;
    }

    testWidgets('el resumen ofrece personalizar sin crear la reserva', (tester) async {
      final vm = await enResumen(tester);

      expect(find.byKey(const ValueKey('tarjeta_personalizar')), findsOneWidget);
      expect(find.text('Personaliza tu visita'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_personalizar_resumen')), findsOneWidget);
      expect(vm.draft.tienePersonalizacion, isFalse);
      // El estado de la barra marca "Resumen" como etapa en curso.
      expect(find.byType(BarraEstadoReserva), findsOneWidget);
    });

    testWidgets('con personalización la tarjeta lo indica y se puede quitar', (tester) async {
      final vm = await enResumen(tester);
      vm.setPreordenItems([
        {'nombre': 'Tacos', 'cantidad': 2, 'precio': 50.0, 'total': 100.0},
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Tu visita está personalizada'), findsOneWidget);
      expect(find.text('1 platillo pre-ordenado'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('btn_quitar_personalizacion')));
      await tester.pumpAndSettle();
      expect(vm.draft.tienePersonalizacion, isFalse);
      expect(find.text('Personaliza tu visita'), findsOneWidget);
    });

    testWidgets('personalizar queda al lado del título y a su altura', (tester) async {
      await enResumen(tester);

      final titulo = tester.getRect(find.text('Resumen de tu reserva'));
      final tarjeta = tester.getRect(find.byKey(const ValueKey('tarjeta_personalizar')));
      expect(tarjeta.left, greaterThan(titulo.right), reason: 'a un lado del título');
      expect(tarjeta.top, lessThan(titulo.bottom), reason: 'a la misma altura');
      expect(tarjeta.bottom, greaterThan(titulo.top));
    });

    testWidgets('el resumen y el formulario ocupan todo el ancho de la pantalla', (tester) async {
      await enResumen(tester);
      final ticket = tester.getRect(find.byKey(const ValueKey('summary_card_restaurante')));
      expect(ticket.width, greaterThan(1200), reason: 'no se encierra en una columna angosta');

      final vm = tester.state<State>(find.byType(ReservationFlowView));
      expect(vm, isNotNull);
      tester.view.physicalSize = const Size(1800, 1400);
      await tester.pumpAndSettle();
      final ancho = tester.getRect(find.byKey(const ValueKey('summary_card_restaurante'))).width;
      expect(ancho, greaterThan(1600));
    });

    testWidgets('en pantallas angostas no aparece (usa el paso aparte)', (tester) async {
      await enResumen(tester, ancho: 800);
      expect(find.byKey(const ValueKey('tarjeta_personalizar')), findsNothing);
    });
  });

  group('Pantallas angostas conservan los pasos separados', () {
    testWidgets('a 800 px no se muestra la pantalla única', (tester) async {
      await abrir(tester, ancho: 800);
      expect(find.byType(FormularioReservaWeb), findsNothing);
      expect(find.byType(BarraEstadoReserva), findsNothing);
    });
  });
}
