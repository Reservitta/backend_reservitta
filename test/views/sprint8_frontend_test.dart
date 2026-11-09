import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/operations_config.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/admin_alert_service.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/operations_config_service.dart';
import 'package:reservitta/services/reminder_inbox_service.dart';
import 'package:reservitta/services/reminder_service.dart';
import 'package:reservitta/services/reservation_management_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/services/table_service.dart';
import 'package:reservitta/services/table_status_service.dart';
import 'package:reservitta/viewmodels/admin_operations_viewmodel.dart';
import 'package:reservitta/viewmodels/admin_reservations_viewmodel.dart';
import 'package:reservitta/views/admin_reservations_view.dart';
import 'package:reservitta/views/dashboard_view.dart';
import 'package:reservitta/views/orders_view.dart';
import 'package:reservitta/views/reservation_confirmation_view.dart';
import 'package:reservitta/views/reservation_detail_view.dart';
import 'package:reservitta/views/reservation_management_view.dart';
import 'package:reservitta/views/table_management_view.dart';
import 'package:reservitta/views/widgets/alert_settings_sheet.dart';
import 'package:reservitta/views/widgets/order_state_control.dart';
import 'package:reservitta/views/widgets/upcoming_reminder_banner.dart';

/// Instante que corresponde a la hora de pared de Ciudad de México (UTC-6).
DateTime mx(int d, int h, [int mi = 0]) => DateTime.utc(2026, 10, d, h + 6, mi);

ReservationModel reserva({
  String id = 'a1',
  DateTime? inicio,
  String estado = ReservationModel.estadoConfirmada,
  List<String> mesas = const ['m1'],
  String nombre = 'Carlos',
  bool conPreorden = false,
  String estadoPreorden = 'pendiente',
  List<String> alergias = const [],
  int personas = 4,
}) {
  final i = inicio ?? mx(30, 14);
  return ReservationModel.create(
    id: id,
    restauranteId: 'r1',
    usuarioId: 'u1',
    restauranteNombre: 'Miel Test',
    contactoNombre: nombre,
    contactoTelefono: '4181234567',
    fechaLocal: '2026-10-30',
    inicio: i,
    duracionMin: 90,
    personas: personas,
    mesaIds: mesas,
    mesasNombres: [for (final m in mesas) m.toUpperCase()],
    estado: estado,
    estadoPreorden: estadoPreorden,
    preordenItems: conPreorden
        ? [
            {'platilloId': 'p1', 'nombre': 'Pasta', 'cantidad': 2, 'precio': 100.0},
          ]
        : const [],
    alergias: alergias,
  );
}

class _NoPush implements AdminPushGateway {
  final mensajes = <AdminPushMessage>[];
  @override
  Future<void> enviar(AdminPushMessage m) async => mensajes.add(m);
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  var ahora = mx(30, 13, 45);

  Finder k(String key) => find.byKey(ValueKey(key));

  Future<void> guardarReserva(ReservationModel r) =>
      db.collection('reservations').doc(r.id).set(r.toMap());

  Future<void> guardarMesa(String id, String nombre, int cap,
      {double? x, double? y, String? estadoManual}) {
    return db.collection('restaurants').doc('r1').collection('mesas').doc(id).set({
      'nombre': nombre,
      'capacidad': cap,
      'forma': 'cuadrada',
      'ancho': 100.0,
      'alto': 100.0,
      'estadoManual': estadoManual,
      'x': ?x,
      'y': ?y,
    });
  }

  AdminOperationsViewModel crearVm(WidgetTester tester, {bool sincronizar = false, _NoPush? push}) {
    final vm = AdminOperationsViewModel(
      restaurantId: 'r1',
      reservas: ReservationService(firestore: db),
      mesasService: TableStatusService(firestore: db),
      configService: OperationsConfigService(firestore: db),
      alertService: AdminAlertService(firestore: db, gateway: push ?? _NoPush()),
      reminderService: ReminderService(firestore: db),
      now: () => ahora,
      tick: Duration.zero,
      sincronizar: sincronizar,
      usuarioId: () => 'admin1',
    );
    addTearDown(vm.dispose);
    return vm;
  }

  void pantallaGrande(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  setUp(() async {
    ahora = mx(30, 13, 45);
    db = FakeFirebaseFirestore();
    await db.collection('restaurants').doc('r1').set({
      'nombre': 'Miel Test',
      'zonaHoraria': 'America/Mexico_City',
      'configuracion': {'umbralAlertaMin': 30, 'recordatorioMin': 120},
    });
  });

  Future<void> abrirDashboard(
    WidgetTester tester,
    AdminOperationsViewModel vm, {
    void Function(ReservationModel)? onAbrir,
    VoidCallback? onReservas,
    VoidCallback? onMesas,
  }) async {
    pantallaGrande(tester);
    await vm.iniciar();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardView(
          operaciones: vm,
          restauranteNombre: 'Miel Test',
          onIrAReservas: onReservas ?? () {},
          onIrAMesas: onMesas ?? () {},
          onIrAPedidos: () {},
          onAbrirReserva: onAbrir ?? (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  String valor(WidgetTester tester, String key) => tester
      .widget<Text>(find.descendant(of: k(key), matching: k('metrica_valor')))
      .data!;

  group('HU25-RF02 dashboard', () {
    testWidgets('muestra un indicador de carga mientras llegan los datos', (tester) async {
      final vm = crearVm(tester);
      pantallaGrande(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DashboardView(
            operaciones: vm,
            onIrAReservas: () {},
            onIrAMesas: () {},
            onAbrirReserva: (_) {},
          ),
        ),
      ));
      expect(k('dashboard_cargando'), findsOneWidget);
      await vm.iniciar();
      await tester.pumpAndSettle();
      expect(k('dashboard_cargando'), findsNothing);
      expect(k('dashboard_contenido'), findsOneWidget);
    });

    testWidgets('muestra las cuatro métricas del día', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      await guardarMesa('m2', 'M2', 4);
      await guardarMesa('m3', 'M3', 2);
      await guardarReserva(reserva(id: 'a', conPreorden: true, inicio: mx(30, 13, 30)));
      await guardarReserva(reserva(id: 'b', mesas: ['m2'], personas: 2, inicio: mx(30, 20)));
      await guardarReserva(reserva(
          id: 'c', estado: ReservationModel.estadoCancelada, personas: 9, mesas: ['m3']));
      await abrirDashboard(tester, crearVm(tester));

      expect(valor(tester, 'metrica_reservas'), '2');
      expect(valor(tester, 'metrica_personas'), '6');
      expect(valor(tester, 'metrica_mesas'), '1 / 3');
      expect(valor(tester, 'metrica_pedidos'), '1');
      expect(find.text('Reservas de hoy'), findsOneWidget);
      expect(find.text('Personas esperadas'), findsOneWidget);
    });

    testWidgets('sin datos muestra todo en cero y no un error', (tester) async {
      await abrirDashboard(tester, crearVm(tester));
      expect(valor(tester, 'metrica_reservas'), '0');
      expect(valor(tester, 'metrica_personas'), '0');
      expect(valor(tester, 'metrica_mesas'), '0 / 0');
      expect(valor(tester, 'metrica_pedidos'), '0');
      expect(k('dashboard_error'), findsNothing);
    });

    testWidgets('se actualiza solo cuando llega una reserva nueva', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      await abrirDashboard(tester, crearVm(tester));
      expect(valor(tester, 'metrica_reservas'), '0');

      await guardarReserva(reserva(id: 'nueva', personas: 5));
      await tester.pumpAndSettle();
      expect(valor(tester, 'metrica_reservas'), '1');
      expect(valor(tester, 'metrica_personas'), '5');

      await db.collection('reservations').doc('nueva').update({'estado': 'cancelada'});
      await tester.pumpAndSettle();
      expect(valor(tester, 'metrica_reservas'), '0');
    });

    testWidgets('tiene pull-to-refresh como respaldo', (tester) async {
      await abrirDashboard(tester, crearVm(tester));
      expect(k('dashboard_refresh'), findsOneWidget);
      await guardarReserva(reserva(id: 'x'));
      await tester.fling(k('dashboard_contenido'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(valor(tester, 'metrica_reservas'), '1');
    });

    testWidgets('los accesos llevan a las reservas, las mesas y los pedidos', (tester) async {
      var destino = '';
      await abrirDashboard(
        tester,
        crearVm(tester),
        onReservas: () => destino = 'reservas',
        onMesas: () => destino = 'mesas',
      );
      await tester.tap(k('acceso_reservas'));
      expect(destino, 'reservas');
      await tester.tap(k('acceso_mesas'));
      expect(destino, 'mesas');
      expect(k('acceso_pedidos'), findsOneWidget);
    });

    testWidgets('muestra las próximas llegadas y al tocarlas abre la reserva', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      await guardarReserva(reserva(id: 'pronto', nombre: 'Ana López', inicio: mx(30, 14)));
      await guardarReserva(reserva(id: 'lejos', mesas: ['m2'], inicio: mx(30, 20)));
      ReservationModel? abierta;
      await abrirDashboard(tester, crearVm(tester), onAbrir: (r) => abierta = r);

      expect(k('alerta_pronto'), findsOneWidget);
      expect(k('alerta_lejos'), findsNothing);
      expect(find.textContaining('Llega en 15 min'), findsOneWidget);
      expect(find.textContaining('Ana López'), findsOneWidget);

      await tester.tap(k('alerta_pronto'));
      expect(abierta?.id, 'pronto');
    });

    testWidgets('el aviso cambia a "Tarde" cuando pasa la hora', (tester) async {
      await guardarReserva(reserva(id: 'tarde', inicio: mx(30, 13, 30)));
      await abrirDashboard(tester, crearVm(tester));
      expect(find.textContaining('Tarde 15 min'), findsOneWidget);
    });

    testWidgets('sin llegadas próximas lo dice con el umbral', (tester) async {
      await guardarReserva(reserva(id: 'lejos', inicio: mx(30, 20)));
      await abrirDashboard(tester, crearVm(tester));
      expect(k('alertas_vacias'), findsOneWidget);
      expect(find.textContaining('30 minutos'), findsOneWidget);
    });

    testWidgets('con las alertas desactivadas no las muestra', (tester) async {
      await db.collection('restaurants').doc('r1').update({'configuracion.alertasActivas': false});
      await guardarReserva(reserva(id: 'pronto', inicio: mx(30, 14)));
      await abrirDashboard(tester, crearVm(tester));
      expect(k('alertas_desactivadas'), findsOneWidget);
      expect(k('alerta_pronto'), findsNothing);
    });

    testWidgets('si falla la carga muestra el error con "Reintentar"', (tester) async {
      final vm = AdminOperationsViewModel(
        restaurantId: 'r1',
        reservas: _ReservasRotas(),
        mesasService: TableStatusService(firestore: db),
        configService: OperationsConfigService(firestore: db),
        alertService: AdminAlertService(firestore: db, gateway: _NoPush()),
        reminderService: ReminderService(firestore: db),
        now: () => ahora,
        tick: Duration.zero,
        sincronizar: false,
      );
      addTearDown(vm.dispose);
      await abrirDashboard(tester, vm);
      expect(k('dashboard_error'), findsOneWidget);
      expect(k('dashboard_reintentar'), findsOneWidget);
    });

    testWidgets('el administrador ajusta el umbral de las alertas desde el dashboard', (tester) async {
      await guardarReserva(reserva(id: 'pronto', inicio: mx(30, 14)));
      final vm = crearVm(tester);
      await abrirDashboard(tester, vm);
      expect(k('alerta_pronto'), findsOneWidget);

      await tester.tap(k('btn_ajustes_alertas'));
      await tester.pumpAndSettle();
      expect(k('hoja_ajustes_alertas'), findsOneWidget);
      await tester.tap(k('chip_umbral_10'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_guardar_ajustes_alertas'));
      await tester.pumpAndSettle();

      // Faltan 15 min y el umbral ahora es 10: ya no hay alerta.
      expect(vm.config.umbralAlertaMin, 10);
      expect(k('alerta_pronto'), findsNothing);
      final guardado = await OperationsConfigService(firestore: db).cargar('r1');
      expect(guardado.umbralAlertaMin, 10);
    });
  });

  group('HU30-RF03 ajustes de las alertas', () {
    Future<List<OperationsConfig>> abrirHoja(WidgetTester tester, OperationsConfig config,
        {String? error}) async {
      final guardados = <OperationsConfig>[];
      pantallaGrande(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => AlertSettingsSheet.mostrar(
                  context,
                  config: config,
                  onGuardar: (n) async {
                    guardados.add(n);
                    return error;
                  },
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return guardados;
    }

    testWidgets('permite desactivar las alertas', (tester) async {
      final guardados = await abrirHoja(tester, const OperationsConfig());
      await tester.tap(k('switch_alertas'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_guardar_ajustes_alertas'));
      await tester.pumpAndSettle();
      expect(guardados.single.alertasActivas, isFalse);
    });

    testWidgets('con las alertas desactivadas no deja elegir el umbral', (tester) async {
      await abrirHoja(tester, const OperationsConfig(alertasActivas: false));
      final chip = tester.widget<ChoiceChip>(k('chip_umbral_15'));
      expect(chip.onSelected, isNull);
    });

    testWidgets('permite elegir el umbral y la anticipación del recordatorio', (tester) async {
      final guardados = await abrirHoja(tester, const OperationsConfig());
      await tester.tap(k('chip_umbral_45'));
      await tester.tap(k('chip_recordatorio_180'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_guardar_ajustes_alertas'));
      await tester.pumpAndSettle();
      expect(guardados.single.umbralAlertaMin, 45);
      expect(guardados.single.recordatorioMin, 180);
      expect(k('hoja_ajustes_alertas'), findsNothing);
    });

    testWidgets('si no se pudo guardar muestra el error y no cierra', (tester) async {
      await abrirHoja(tester, const OperationsConfig(), error: 'No se pudo guardar');
      await tester.tap(k('btn_guardar_ajustes_alertas'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo guardar'), findsOneWidget);
      expect(k('hoja_ajustes_alertas'), findsOneWidget);
    });

    testWidgets('un umbral guardado que no está en la lista también aparece', (tester) async {
      await abrirHoja(tester, const OperationsConfig(umbralAlertaMin: 25));
      expect(k('chip_umbral_25'), findsOneWidget);
    });
  });

  group('HU30-RF03 alertas en el listado de reservas', () {
    Future<void> abrirListado(WidgetTester tester, AdminOperationsViewModel vm) async {
      pantallaGrande(tester);
      await vm.iniciar();
      final repo = ReservationService(firestore: db);
      await tester.pumpWidget(MaterialApp(
        home: AdminReservationsView(
          restaurantId: 'r1',
          showAppBar: false,
          operaciones: vm,
          viewModel: AdminReservationsViewModel(
            restaurantId: 'r1',
            reservationRepository: repo,
            initialDate: DateTime(2026, 10, 30),
            usuarioId: () => 'admin1',
          ),
          cargarCategorias: () async => const {},
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('destaca con "llega en X min" las reservas próximas', (tester) async {
      await guardarReserva(reserva(id: 'pronto', inicio: mx(30, 14)));
      await guardarReserva(reserva(id: 'lejos', mesas: ['m2'], inicio: mx(30, 20)));
      await abrirListado(tester, crearVm(tester));

      expect(k('alerta_chip_pronto'), findsOneWidget);
      expect(k('alerta_chip_lejos'), findsNothing);
      expect(find.text('Llega en 15 min'), findsWidgets);
      expect(find.text('1 llegada próxima'), findsOneWidget);
    });

    testWidgets('al tocar la alerta abre el detalle de esa reserva', (tester) async {
      await guardarReserva(reserva(id: 'pronto', nombre: 'Ana López', inicio: mx(30, 14)));
      await abrirListado(tester, crearVm(tester));
      await tester.tap(k('alerta_pronto'));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationDetailView), findsOneWidget);
      expect(find.text('Ana López'), findsWidgets);
    });

    testWidgets('abre los ajustes de las alertas', (tester) async {
      await abrirListado(tester, crearVm(tester));
      expect(find.text('Sin llegadas próximas'), findsOneWidget);
      await tester.tap(k('btn_ajustes_alertas_reservas'));
      await tester.pumpAndSettle();
      expect(k('hoja_ajustes_alertas'), findsOneWidget);
    });

    testWidgets('sin el estado operativo el listado funciona igual', (tester) async {
      pantallaGrande(tester);
      await guardarReserva(reserva(id: 'pronto', inicio: mx(30, 14)));
      await tester.pumpWidget(MaterialApp(
        home: AdminReservationsView(
          restaurantId: 'r1',
          showAppBar: false,
          viewModel: AdminReservationsViewModel(
            restaurantId: 'r1',
            reservationRepository: ReservationService(firestore: db),
            initialDate: DateTime(2026, 10, 30),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(k('alertas_llegada'), findsNothing);
      expect(k('item_reserva_pronto'), findsOneWidget);
    });
  });

  group('HU29-RF02 gestión del estado del pedido', () {
    Future<void> abrirPedidos(WidgetTester tester, AdminOperationsViewModel vm,
        {void Function(ReservationModel)? onAbrir}) async {
      pantallaGrande(tester);
      await vm.iniciar();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OrdersView(operaciones: vm, onAbrirReserva: onAbrir ?? (_) {}),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('lista solo los pedidos del día con su estado', (tester) async {
      await guardarReserva(reserva(id: 'a', conPreorden: true, nombre: 'Ana'));
      await guardarReserva(reserva(id: 'b', mesas: ['m2'], conPreorden: true, estadoPreorden: 'listo'));
      await guardarReserva(reserva(id: 'sin', mesas: ['m3']));
      await guardarReserva(reserva(
          id: 'cancelada',
          mesas: ['m4'],
          conPreorden: true,
          estado: ReservationModel.estadoCancelada));
      await abrirPedidos(tester, crearVm(tester));

      expect(k('pedido_a'), findsOneWidget);
      expect(k('pedido_b'), findsOneWidget);
      expect(k('pedido_sin'), findsNothing);
      expect(k('pedido_cancelada'), findsNothing);
      expect(find.descendant(of: k('pedido_estado_a'), matching: find.text('Pendiente')),
          findsOneWidget);
      expect(find.descendant(of: k('pedido_estado_b'), matching: find.text('Listo')),
          findsOneWidget);
      expect(find.textContaining('2 platillos'), findsNWidgets(2));
    });

    testWidgets('sin pedidos muestra el estado vacío', (tester) async {
      await abrirPedidos(tester, crearVm(tester));
      expect(k('pedidos_vacio'), findsOneWidget);
    });

    testWidgets('con un solo toque avanza de pendiente a en preparación y a listo', (tester) async {
      await guardarReserva(reserva(id: 'a', conPreorden: true));
      await abrirPedidos(tester, crearVm(tester));

      await tester.tap(k('btn_pedido_avanzar_a'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('pedido_estado_a'), matching: find.text('En preparación')),
          findsOneWidget);
      expect(find.text('Marcar como listo'), findsOneWidget);

      await tester.tap(k('btn_pedido_avanzar_a'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('pedido_estado_a'), matching: find.text('Listo')),
          findsOneWidget);
      expect(k('btn_pedido_avanzar_a'), findsNothing);
      expect(k('pedido_listo_a'), findsOneWidget);

      final guardada = await ReservationService(firestore: db).getReservationById('a');
      expect(guardada!.estadoPreorden, 'listo');
      expect(guardada.historialPedido, hasLength(2));
      expect(guardada.historialPedido.last['por'], 'admin1');
    });

    testWidgets('el pedido listo antes de la llegada no cambia la reserva', (tester) async {
      await guardarReserva(reserva(id: 'a', conPreorden: true, estadoPreorden: 'en_preparacion'));
      await abrirPedidos(tester, crearVm(tester));
      await tester.tap(k('btn_pedido_avanzar_a'));
      await tester.pumpAndSettle();
      expect(find.textContaining('esperando al cliente'), findsOneWidget);
      final guardada = await ReservationService(firestore: db).getReservationById('a');
      expect(guardada!.estadoOperativo, ReservationModel.estadoPendienteLlegada);
    });

    testWidgets('regresar un paso pide el motivo', (tester) async {
      await guardarReserva(reserva(id: 'a', conPreorden: true, estadoPreorden: 'listo'));
      await abrirPedidos(tester, crearVm(tester));

      await tester.tap(k('btn_pedido_regresar_a'));
      await tester.pumpAndSettle();
      expect(k('dialogo_reversa_pedido'), findsOneWidget);

      // Sin motivo no se aplica.
      await tester.tap(k('btn_confirmar_reversa'));
      await tester.pumpAndSettle();
      expect(k('dialogo_reversa_pedido'), findsOneWidget);

      await tester.enterText(k('campo_motivo_reversa'), 'El cliente cambió el platillo');
      await tester.tap(k('btn_confirmar_reversa'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('pedido_estado_a'), matching: find.text('En preparación')),
          findsOneWidget);
      final guardada = await ReservationService(firestore: db).getReservationById('a');
      expect(guardada!.historialPedido.last['motivo'], 'El cliente cambió el platillo');
    });

    testWidgets('cancelar el cuadro de motivo no cambia el pedido', (tester) async {
      await guardarReserva(reserva(id: 'a', conPreorden: true, estadoPreorden: 'listo'));
      await abrirPedidos(tester, crearVm(tester));
      await tester.tap(k('btn_pedido_regresar_a'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_cancelar_reversa'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('pedido_estado_a'), matching: find.text('Listo')),
          findsOneWidget);
    });

    testWidgets('el cambio se refleja en otro dispositivo conectado', (tester) async {
      await guardarReserva(reserva(id: 'a', conPreorden: true));
      final cocina = crearVm(tester);
      final recepcion = crearVm(tester);
      await recepcion.iniciar();
      await abrirPedidos(tester, cocina);
      expect(recepcion.reservaPorId('a')!.estadoPreorden, 'pendiente');

      await tester.tap(k('btn_pedido_avanzar_a'));
      await tester.pumpAndSettle();
      expect(recepcion.reservaPorId('a')!.estadoPreorden, 'en_preparacion');
    });

    testWidgets('el control es un botón grande, operable con un toque', (tester) async {
      await guardarReserva(reserva(id: 'a', conPreorden: true));
      await abrirPedidos(tester, crearVm(tester));
      final tam = tester.getSize(k('btn_pedido_avanzar_a'));
      expect(tam.height, greaterThanOrEqualTo(48));
    });

    testWidgets('destaca la alerta de llegada y las alergias del pedido', (tester) async {
      await guardarReserva(reserva(
          id: 'a', conPreorden: true, inicio: mx(30, 14), alergias: const ['Nueces']));
      await abrirPedidos(tester, crearVm(tester));
      expect(find.text('Llega en 15 min'), findsOneWidget);
      expect(find.text('Alergias o restricciones'), findsOneWidget);
    });

    testWidgets('al tocar el pedido abre la reserva', (tester) async {
      await guardarReserva(reserva(id: 'a', conPreorden: true));
      ReservationModel? abierta;
      await abrirPedidos(tester, crearVm(tester), onAbrir: (r) => abierta = r);
      await tester.tap(k('pedido_abrir_a'));
      expect(abierta?.id, 'a');
    });

    testWidgets('si el cambio falla muestra un aviso y no cambia el estado', (tester) async {
      pantallaGrande(tester);
      String? mensaje;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OrderStateControl(
            reservaId: 'a',
            estadoActual: 'pendiente',
            onChange: (n, {motivo}) async {
              mensaje = 'Sin conexión';
              return mensaje;
            },
          ),
        ),
      ));
      await tester.tap(k('btn_pedido_avanzar_a'));
      await tester.pumpAndSettle();
      expect(k('snack_pedido_error'), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('los estados tienen color, ícono y etiqueta distintos', (tester) async {
      final estilos = [
        for (final e in ['pendiente', 'en_preparacion', 'listo']) OrderStateStyle.of(e),
      ];
      expect({for (final s in estilos) s.label}, hasLength(3));
      expect({for (final s in estilos) s.foreground}, hasLength(3));
      expect({for (final s in estilos) s.icon}, hasLength(3));
    });

    testWidgets('el detalle de la reserva muestra el control del pedido', (tester) async {
      pantallaGrande(tester);
      await guardarReserva(reserva(id: 'a', conPreorden: true));
      final repo = ReservationService(firestore: db);
      await tester.pumpWidget(MaterialApp(
        home: ReservationDetailView(
          reservationId: 'a',
          repository: repo,
          onChangeState: (_) async => null,
          onChangeOrderState: (nuevo, {motivo}) async {
            await repo.changeOrderState(
                reservationId: 'a', nuevoEstado: nuevo, usuarioId: 'admin1', motivo: motivo);
            return null;
          },
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_pedido_avanzar_a'));
      await tester.pumpAndSettle();
      expect(find.text('Pedido: En preparación'), findsOneWidget);
    });
  });

  group('HU31-RF02 vista de gestión de mesas', () {
    Future<void> abrirMesas(WidgetTester tester, AdminOperationsViewModel vm,
        {void Function(ReservationModel)? onAbrir}) async {
      pantallaGrande(tester);
      await vm.iniciar();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TableManagementView(operaciones: vm, onAbrirReserva: onAbrir ?? (_) {}),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('sin plano muestra una lista con el estado de cada mesa', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      await guardarMesa('m2', 'M2', 2);
      await guardarMesa('m3', 'M3', 6, estadoManual: 'fuera_de_servicio');
      await guardarReserva(reserva(id: 'a', inicio: mx(30, 13, 30)));
      await abrirMesas(tester, crearVm(tester));

      expect(k('mesas_lista'), findsOneWidget);
      expect(k('mesas_plano'), findsNothing);
      expect(find.descendant(of: k('mesa_m1'), matching: find.textContaining('Ocupada')),
          findsOneWidget);
      expect(find.descendant(of: k('mesa_m2'), matching: find.textContaining('Disponible')),
          findsOneWidget);
      expect(find.descendant(of: k('mesa_m3'), matching: find.textContaining('Fuera de servicio')),
          findsOneWidget);
      expect(find.descendant(of: k('mesa_m1'), matching: find.textContaining('Capacidad 4')),
          findsOneWidget);
      expect(k('mesas_leyenda'), findsOneWidget);
    });

    testWidgets('con plano reutiliza las posiciones de las mesas', (tester) async {
      await guardarMesa('m1', 'M1', 4, x: 0, y: 0);
      await guardarMesa('m2', 'M2', 2, x: 150, y: 0);
      await abrirMesas(tester, crearVm(tester));
      expect(k('mesas_plano'), findsOneWidget);
      expect(k('mesas_lista'), findsNothing);
      expect(k('mesa_m1'), findsOneWidget);
      expect(k('mesa_m2'), findsOneWidget);
    });

    testWidgets('cada mesa muestra identificador, capacidad e ícono del estado', (tester) async {
      await guardarMesa('m1', 'M1', 4, x: 0, y: 0);
      await abrirMesas(tester, crearVm(tester));
      expect(find.descendant(of: k('mesa_m1'), matching: find.text('M1')), findsOneWidget);
      expect(find.descendant(of: k('mesa_m1'), matching: find.text('4 pers.')), findsOneWidget);
      expect(find.descendant(of: k('mesa_m1'), matching: find.byIcon(Icons.check_circle_outline)),
          findsOneWidget);
    });

    testWidgets('al tocar una mesa ocupada muestra su reserva con acceso al detalle', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      await guardarReserva(reserva(id: 'a', nombre: 'Ana López', inicio: mx(30, 13, 30)));
      ReservationModel? abierta;
      await abrirMesas(tester, crearVm(tester), onAbrir: (r) => abierta = r);

      await tester.tap(k('mesa_m1'));
      await tester.pumpAndSettle();
      expect(k('hoja_mesa_m1'), findsOneWidget);
      expect(find.descendant(of: k('mesa_reserva'), matching: find.text('Ana López')),
          findsOneWidget);
      await tester.tap(k('btn_ver_reserva_mesa'));
      await tester.pumpAndSettle();
      expect(abierta?.id, 'a');
    });

    testWidgets('una mesa disponible indica que no tiene reserva', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      await abrirMesas(tester, crearVm(tester));
      await tester.tap(k('mesa_m1'));
      await tester.pumpAndSettle();
      expect(k('mesa_sin_reserva'), findsOneWidget);
      expect(k('btn_ver_reserva_mesa'), findsNothing);
    });

    testWidgets('las mesas combinadas muestran con cuáles están agrupadas', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      await guardarMesa('m2', 'M2', 4);
      await guardarReserva(reserva(id: 'a', mesas: ['m1', 'm2'], inicio: mx(30, 13, 30)));
      await abrirMesas(tester, crearVm(tester));
      await tester.tap(k('mesa_m1'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('hoja_mesa_m1'), matching: find.text('Combinada')),
          findsOneWidget);
      expect(find.text('Combinada con M2'), findsOneWidget);
      expect(k('mesa_reserva'), findsOneWidget);
    });

    testWidgets('se marca fuera de servicio y se vuelve a activar', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      final vm = crearVm(tester);
      await abrirMesas(tester, vm);

      await tester.tap(k('mesa_m1'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_mesa_fuera_servicio'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('mesa_m1'), matching: find.textContaining('Fuera de servicio')),
          findsOneWidget);
      var doc = await db.collection('restaurants').doc('r1').collection('mesas').doc('m1').get();
      expect(doc.data()!['estadoManual'], MesaModel.estadoFueraDeServicio);

      await tester.tap(k('mesa_m1'));
      await tester.pumpAndSettle();
      expect(k('btn_mesa_fuera_servicio'), findsNothing);
      await tester.tap(k('btn_mesa_reactivar'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('mesa_m1'), matching: find.textContaining('Disponible')),
          findsOneWidget);
      doc = await db.collection('restaurants').doc('r1').collection('mesas').doc('m1').get();
      expect(doc.data()!['estadoManual'], isNull);
    });

    testWidgets('una mesa fuera de servicio deja de ofrecerse para reservar', (tester) async {
      await guardarMesa('m1', 'M1', 4, x: 0, y: 0, estadoManual: 'fuera_de_servicio');
      await guardarMesa('m2', 'M2', 4, x: 150, y: 0);
      final servicio = AvailabilityService(
        ReservationService(firestore: db),
        tables: TableService(firestore: db),
        now: () => ahora,
      );
      final restaurante = RestaurantModel(id: 'r1', nombre: 'Miel Test');
      final plano = await servicio.getFloorPlanForDate(
        restaurant: restaurante,
        fecha: DateTime(2026, 11, 20),
      );
      expect(plano.mesas.map((m) => m.mesa.id), ['m2']);
    });

    testWidgets('el estado cambia en tiempo real cuando llega la reserva', (tester) async {
      await guardarMesa('m1', 'M1', 4);
      await abrirMesas(tester, crearVm(tester));
      expect(find.descendant(of: k('mesa_m1'), matching: find.textContaining('Disponible')),
          findsOneWidget);
      await guardarReserva(reserva(id: 'a', inicio: mx(30, 13, 30)));
      await tester.pumpAndSettle();
      expect(find.descendant(of: k('mesa_m1'), matching: find.textContaining('Ocupada')),
          findsOneWidget);
    });

    testWidgets('sin mesas muestra un estado vacío', (tester) async {
      await abrirMesas(tester, crearVm(tester));
      expect(k('mesas_vacio'), findsOneWidget);
    });
  });

  group('Sincronización de alertas y recordatorios desde la app abierta', () {
    testWidgets('registra la alerta una sola vez y la manda a la cola de push', (tester) async {
      await guardarReserva(reserva(id: 'pronto', inicio: mx(30, 14)));
      final push = _NoPush();
      final vm = crearVm(tester, sincronizar: true, push: push);
      await vm.iniciar();
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(push.mensajes, hasLength(1));
      expect(push.mensajes.single.clave, 'pronto_proxima_30');

      // Otra pasada con la misma alerta no la repite.
      await guardarReserva(reserva(id: 'otra', mesas: ['m2'], inicio: mx(30, 20)));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(push.mensajes, hasLength(1));
    });
  });

  group('HU21-RF02 recordatorio visible para el cliente', () {
    final reservaConfirmada = reserva(id: 'conf', inicio: DateTime(2026, 10, 30, 14));

    testWidgets('la confirmación indica el recordatorio y su anticipación', (tester) async {
      pantallaGrande(tester);
      await tester.pumpWidget(MaterialApp(
        home: ReservationConfirmationView(
          reservation: reservaConfirmada,
          operaciones: const OperationsConfig(recordatorioMin: 120),
          now: () => DateTime(2026, 10, 29, 10),
        ),
      ));
      expect(k('aviso_recordatorio'), findsOneWidget);
      expect(find.text('Te enviaremos un recordatorio 2 horas antes de tu reserva.'),
          findsOneWidget);
    });

    testWidgets('usa la anticipación configurada por el restaurante', (tester) async {
      pantallaGrande(tester);
      await tester.pumpWidget(MaterialApp(
        home: ReservationConfirmationView(
          reservation: reservaConfirmada,
          operaciones: const OperationsConfig(recordatorioMin: 45),
          now: () => DateTime(2026, 10, 29, 10),
        ),
      ));
      expect(find.textContaining('45 minutos antes'), findsOneWidget);
    });

    testWidgets('si se reservó con muy poca anticipación no promete un recordatorio', (tester) async {
      pantallaGrande(tester);
      await tester.pumpWidget(MaterialApp(
        home: ReservationConfirmationView(
          reservation: reservaConfirmada,
          operaciones: const OperationsConfig(recordatorioMin: 120),
          now: () => DateTime(2026, 10, 30, 13),
        ),
      ));
      expect(k('aviso_recordatorio'), findsNothing);
    });

    testWidgets('si el restaurante lo envía de inmediato lo avisa', (tester) async {
      pantallaGrande(tester);
      await tester.pumpWidget(MaterialApp(
        home: ReservationConfirmationView(
          reservation: reservaConfirmada,
          operaciones: const OperationsConfig(
              recordatorioMin: 120, recordatorioTardioInmediato: true),
          now: () => DateTime(2026, 10, 30, 13),
        ),
      ));
      expect(find.textContaining('en unos minutos'), findsOneWidget);
    });

    testWidgets('la gestión de la reserva muestra el recordatorio', (tester) async {
      pantallaGrande(tester);
      final repo = ReservationService(firestore: db);
      final base = DateTime(2026, 10, 30, 14);
      final guardada = await repo.createReservationVerified(ReservationModel.create(
        id: '',
        restauranteId: 'r1',
        usuarioId: 'u1',
        restauranteNombre: 'Miel Test',
        fechaLocal: '2026-10-30',
        inicio: base,
        duracionMin: 90,
        personas: 4,
        mesaIds: const ['m1'],
        mesasNombres: const ['M1'],
        estado: ReservationModel.estadoConfirmada,
        tokenGestion: 'ABCDEFGHJKMNPQRSTUVW',
      ));
      expect(guardada.tokenGestion, isNotEmpty);
      final ahoraLocal = DateTime(2026, 10, 30, 9);
      await tester.pumpWidget(MaterialApp(
        home: ReservationManagementView(
          initialCode: 'ABCDEFGHJKMNPQRSTUVW',
          service: ReservationManagementService(
            firestore: db,
            availability: AvailabilityService(repo, now: () => ahoraLocal),
            now: () => ahoraLocal,
          ),
          now: () => ahoraLocal,
          cargarRestaurante: (_) async => RestaurantModel(
            id: 'r1',
            nombre: 'Miel Test',
            operaciones: const OperationsConfig(recordatorioMin: 180),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(k('aviso_recordatorio'), findsOneWidget);
      expect(find.text('Te enviaremos un recordatorio 3 horas antes de tu reserva.'),
          findsOneWidget);
    });

    testWidgets('el visitante con sesión ve el recordatorio dentro de la app', (tester) async {
      final r = reserva(id: 'conf', inicio: DateTime(2026, 10, 30, 14));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UpcomingReminderBanner(
            cargar: () async => [
              UpcomingReminder(reserva: r, programadoPara: DateTime(2026, 10, 30, 12)),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(k('banner_recordatorio'), findsOneWidget);
      expect(find.text('Recordatorio: tu reserva en Miel Test es hoy a las 14:00.'),
          findsOneWidget);
    });

    testWidgets('sin recordatorios o si falla la consulta no muestra nada', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: UpcomingReminderBanner(cargar: () async => const [])),
      ));
      await tester.pumpAndSettle();
      expect(k('banner_recordatorio'), findsNothing);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UpcomingReminderBanner(cargar: () async => throw Exception('sin red')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(k('banner_recordatorio'), findsNothing);
    });

    test('el buzón solo trae reservas vigentes dentro de su ventana de recordatorio', () async {
      final repo = ReservationService(firestore: db);
      Future<void> crear(String token, DateTime inicio, {String estado = 'confirmada', String usuario = 'u1'}) =>
          repo.createReservationVerified(ReservationModel.create(
            id: '',
            restauranteId: 'r1',
            usuarioId: usuario,
            restauranteNombre: 'Miel Test',
            fechaLocal: '2026-10-30',
            inicio: inicio,
            duracionMin: 90,
            personas: 2,
            mesaIds: [token],
            mesasNombres: [token],
            estado: estado,
          ));
      await crear('m1', DateTime(2026, 10, 30, 14)); // dentro de la ventana (2 h)
      await crear('m2', DateTime(2026, 10, 30, 20)); // todavía lejos
      await crear('m3', DateTime(2026, 10, 30, 13, 30), usuario: 'otro'); // de otra persona
      await crear('m4', DateTime(2026, 10, 30, 13, 45), estado: 'cancelada'); // cancelada
      final lista = await ReminderInboxService(firestore: db)
          .proximos('u1', ahora: DateTime(2026, 10, 30, 12, 30));
      expect(lista, hasLength(1));
      expect(lista.single.reserva.mesaIds, ['m1']);
      expect(lista.single.texto, contains('14:00'));
    });
  });
}

class _ReservasRotas extends ReservationService {
  @override
  Stream<List<ReservationModel>> getReservationsStream({
    required String restauranteId,
    String? fechaLocal,
    String? estado,
  }) =>
      Stream.error(Exception('sin permisos'));
}
