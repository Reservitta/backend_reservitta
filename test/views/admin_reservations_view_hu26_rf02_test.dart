import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/viewmodels/admin_reservations_viewmodel.dart';
import 'package:reservitta/views/admin_reservations_view.dart';

/// Repositorio simulado con StreamController en tiempo real para pruebas de HU26-RF02
class _StreamFakeReservationRepository implements ReservationRepository {
  final Map<String, List<ReservationModel>> _porFecha = {};
  final Map<String, StreamController<List<ReservationModel>>> _controllers = {};
  bool simularErrorEnSiguienteEscucha = false;

  String _key(String restId, String fecha) => '${restId}_$fecha';

  StreamController<List<ReservationModel>> _obtenerController(
    String restId,
    String fecha,
  ) {
    final k = _key(restId, fecha);
    return _controllers.putIfAbsent(
      k,
      () => StreamController<List<ReservationModel>>.broadcast(),
    );
  }

  void emitirParaFecha(
    String restId,
    String fecha,
    List<ReservationModel> reservas,
  ) {
    final k = _key(restId, fecha);
    _porFecha[k] = List<ReservationModel>.from(reservas);
    final ctrl = _obtenerController(restId, fecha);
    ctrl.add(ReservationModel.sortByStartTime(_porFecha[k]!));
  }

  void agregarOActualizarReservaEnTiempoReal(ReservationModel reserva) {
    final k = _key(reserva.restauranteId, reserva.fechaLocal);
    final lista = _porFecha.putIfAbsent(k, () => []);
    final idx = lista.indexWhere((r) => r.id == reserva.id);
    if (idx >= 0) {
      lista[idx] = reserva;
    } else {
      lista.add(reserva);
    }
    _obtenerController(
      reserva.restauranteId,
      reserva.fechaLocal,
    ).add(ReservationModel.sortByStartTime(lista));
  }

  @override
  Stream<List<ReservationModel>> getReservationsStream({
    required String restauranteId,
    required String fechaLocal,
  }) {
    final ctrl = _obtenerController(restauranteId, fechaLocal);
    if (simularErrorEnSiguienteEscucha) {
      Future.microtask(() {
        ctrl.addError(Exception('Fallo de conexión con el servidor'));
      });
    } else {
      final inicial = _porFecha[_key(restauranteId, fechaLocal)] ?? const [];
      Future.microtask(() {
        ctrl.add(ReservationModel.sortByStartTime(inicial));
      });
    }
    return ctrl.stream;
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('63.- HU26-RF02: Pantalla de listado de reservas', () {
    late _StreamFakeReservationRepository fakeRepo;
    const restId = 'rest_casa_sabores';
    final fechaBase = DateTime(2026, 11, 4);
    final fechaBaseStr = ReservationService.formatDateLocal(fechaBase);

    setUp(() {
      fakeRepo = _StreamFakeReservationRepository();
    });

    tearDown(() {
      fakeRepo.dispose();
    });

    Widget buildTestWidget(AdminReservationsViewModel vm) {
      return MaterialApp(
        home: AdminReservationsView(
          restaurantId: restId,
          viewModel: vm,
          showAppBar: false,
        ),
      );
    }

    testWidgets(
      'Criterio 1: Muestra lista/tabla con hora, cliente, personas, mesa y estado ordenada cronológicamente',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Emitimos 3 reservas desordenadas
        fakeRepo.emitirParaFecha(restId, fechaBaseStr, [
          ReservationModel(
            id: 'r_21',
            restauranteId: restId,
            contactoNombre: 'Roberto Díaz',
            fechaLocal: fechaBaseStr,
            inicio: DateTime(2026, 11, 4, 21, 0),
            personas: 6,
            mesaIds: ['m5', 'm6'],
            mesasNombres: ['Mesa 5', 'Mesa 6'],
            estado: ReservationModel.estadoPendienteLlegada,
          ),
          ReservationModel(
            id: 'r_13',
            restauranteId: restId,
            contactoNombre: 'Ana Belén',
            fechaLocal: fechaBaseStr,
            inicio: DateTime(2026, 11, 4, 13, 30),
            personas: 2,
            mesaIds: ['m1'],
            mesasNombres: ['Mesa 1'],
            estado: ReservationModel.estadoEnServicio,
          ),
          ReservationModel(
            id: 'r_18',
            restauranteId: restId,
            contactoNombre: 'Luis Fernando',
            fechaLocal: fechaBaseStr,
            inicio: DateTime(2026, 11, 4, 18, 15),
            personas: 4,
            mesaIds: ['m3'],
            mesasNombres: ['Mesa 3'],
            estado: ReservationModel.estadoClienteLlego,
          ),
        ]);

        final vm = AdminReservationsViewModel(
          restaurantId: restId,
          reservationRepository: fakeRepo,
          initialDate: fechaBase,
        );
        addTearDown(vm.dispose);

        await tester.pumpWidget(buildTestWidget(vm));
        await tester.pumpAndSettle();

        // Verifica que aparezcan todos los datos de cada reserva
        expect(find.text('13:30'), findsOneWidget);
        expect(find.text('Ana Belén'), findsOneWidget);
        expect(find.text('2 personas'), findsOneWidget);
        expect(find.text('Mesa 1'), findsOneWidget);
        expect(find.text('En servicio'), findsOneWidget);

        expect(find.text('18:15'), findsOneWidget);
        expect(find.text('Luis Fernando'), findsOneWidget);
        expect(find.text('4 personas'), findsOneWidget);
        expect(find.text('Mesa 3'), findsOneWidget);
        expect(find.text('Cliente llegó'), findsOneWidget);

        expect(find.text('21:00'), findsOneWidget);
        expect(find.text('Roberto Díaz'), findsOneWidget);
        expect(find.text('6 personas'), findsOneWidget);
        expect(find.text('Mesa 5, Mesa 6'), findsOneWidget);
        expect(find.text('Pendiente de llegada'), findsOneWidget);

        // Verifica el orden cronológico en pantalla (Y de 13:30 < Y de 18:15 < Y de 21:00)
        final pos13 = tester.getTopLeft(find.byKey(const ValueKey('item_reserva_r_13'))).dy;
        final pos18 = tester.getTopLeft(find.byKey(const ValueKey('item_reserva_r_18'))).dy;
        final pos21 = tester.getTopLeft(find.byKey(const ValueKey('item_reserva_r_21'))).dy;

        expect(pos13, lessThan(pos18));
        expect(pos18, lessThan(pos21));
      },
    );

    testWidgets(
      'Criterio 2: Se puede seleccionar una fecha distinta mediante el selector de fecha',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fechaManana = DateTime(2026, 11, 5);
        final fechaMananaStr = ReservationService.formatDateLocal(fechaManana);

        fakeRepo.emitirParaFecha(restId, fechaBaseStr, []);
        fakeRepo.emitirParaFecha(restId, fechaMananaStr, [
          ReservationModel(
            id: 'r_manana',
            restauranteId: restId,
            contactoNombre: 'Claudia Morales',
            fechaLocal: fechaMananaStr,
            inicio: DateTime(2026, 11, 5, 15, 0),
            personas: 3,
            mesaIds: ['m2'],
            mesasNombres: ['Mesa 2'],
            estado: ReservationModel.estadoConfirmada,
          ),
        ]);

        final vm = AdminReservationsViewModel(
          restaurantId: restId,
          reservationRepository: fakeRepo,
          initialDate: fechaBase,
        );
        addTearDown(vm.dispose);

        await tester.pumpWidget(buildTestWidget(vm));
        await tester.pumpAndSettle();

        // Inicialmente el día base no tiene reservas
        expect(find.text('No hay reservas para este día'), findsOneWidget);

        // Abrimos el selector de fecha (showDatePicker) y elegimos el día 5
        await tester.tap(find.byKey(const ValueKey('boton_selector_fecha_reservas')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('5'));
        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        expect(vm.fechaLocalSeleccionada, fechaMananaStr);
        expect(find.text('Claudia Morales'), findsOneWidget);
        expect(find.text('15:00'), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 3: Al tocar una reserva se despliega su descripción',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        fakeRepo.emitirParaFecha(restId, fechaBaseStr, [
          ReservationModel(
            id: 'r_desc',
            restauranteId: restId,
            contactoNombre: 'Fernando Herrera',
            contactoTelefono: '5599887766',
            contactoCorreo: 'fernando@correo.com',
            fechaLocal: fechaBaseStr,
            inicio: DateTime(2026, 11, 4, 14, 0),
            duracionMin: 90,
            personas: 4,
            mesaIds: ['m4'],
            mesasNombres: ['Mesa Terraza 4'],
            estado: ReservationModel.estadoConfirmada,
          ),
        ]);

        final vm = AdminReservationsViewModel(
          restaurantId: restId,
          reservationRepository: fakeRepo,
          initialDate: fechaBase,
        );
        addTearDown(vm.dispose);

        await tester.pumpWidget(buildTestWidget(vm));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('item_reserva_r_desc')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('dialogo_descripcion_reserva_r_desc')),
          findsOneWidget,
        );
        expect(find.text('Descripción de la reserva'), findsOneWidget);
        expect(find.text('14:00 - 15:30'), findsOneWidget);
        expect(find.text('fernando@correo.com'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('boton_cerrar_descripcion_reserva')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Descripción de la reserva'), findsNothing);
      },
    );

    testWidgets(
      'Criterio 4: Muestra estado vacío ("No hay reservas para este día") y manejo de errores con "Reintentar"',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Simulamos un error inicial
        fakeRepo.simularErrorEnSiguienteEscucha = true;

        final vm = AdminReservationsViewModel(
          restaurantId: restId,
          reservationRepository: fakeRepo,
          initialDate: fechaBase,
        );
        addTearDown(vm.dispose);

        await tester.pumpWidget(buildTestWidget(vm));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('vista_error_reservas')), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);

        // 2. Al presionar "Reintentar" tras restablecer la conexión, muestra el estado vacío
        fakeRepo.simularErrorEnSiguienteEscucha = false;
        fakeRepo.emitirParaFecha(restId, fechaBaseStr, []);

        await tester.tap(find.byKey(const ValueKey('boton_reintentar_reservas')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('vista_vacia_reservas')), findsOneWidget);
        expect(find.text('No hay reservas para este día'), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 5: La lista se actualiza en tiempo real si llega una nueva reserva o cambia su estado',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        fakeRepo.emitirParaFecha(restId, fechaBaseStr, [
          ReservationModel(
            id: 'r_tiempo_real',
            restauranteId: restId,
            contactoNombre: 'Patricia Vega',
            fechaLocal: fechaBaseStr,
            inicio: DateTime(2026, 11, 4, 19, 0),
            personas: 2,
            mesaIds: ['m1'],
            mesasNombres: ['Mesa 1'],
            estado: ReservationModel.estadoPendienteLlegada,
          ),
        ]);

        final vm = AdminReservationsViewModel(
          restaurantId: restId,
          reservationRepository: fakeRepo,
          initialDate: fechaBase,
        );
        addTearDown(vm.dispose);

        await tester.pumpWidget(buildTestWidget(vm));
        await tester.pumpAndSettle();

        expect(find.text('Patricia Vega'), findsOneWidget);
        expect(find.text('Pendiente de llegada'), findsOneWidget);

        // 1. Llega una nueva reserva en tiempo real
        fakeRepo.agregarOActualizarReservaEnTiempoReal(
          ReservationModel(
            id: 'r_nueva_rt',
            restauranteId: restId,
            contactoNombre: 'Jorge Campos',
            fechaLocal: fechaBaseStr,
            inicio: DateTime(2026, 11, 4, 17, 30),
            personas: 4,
            mesaIds: ['m2'],
            mesasNombres: ['Mesa 2'],
            estado: ReservationModel.estadoConfirmada,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Jorge Campos'), findsOneWidget);
        expect(find.text('17:30'), findsOneWidget);

        // 2. Cambia el estado de Patricia Vega a "En servicio" en tiempo real
        fakeRepo.agregarOActualizarReservaEnTiempoReal(
          ReservationModel(
            id: 'r_tiempo_real',
            restauranteId: restId,
            contactoNombre: 'Patricia Vega',
            fechaLocal: fechaBaseStr,
            inicio: DateTime(2026, 11, 4, 19, 0),
            personas: 2,
            mesaIds: ['m1'],
            mesasNombres: ['Mesa 1'],
            estado: ReservationModel.estadoEnServicio,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('En servicio'), findsOneWidget);
      },
    );
  });
}
