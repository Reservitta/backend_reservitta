import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/elemento_plano.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/admin_alert_service.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/ocasion_service.dart';
import 'package:reservitta/services/operations_config_service.dart';
import 'package:reservitta/services/reminder_service.dart';
import 'package:reservitta/services/table_status_service.dart';
import 'package:reservitta/viewmodels/admin_operations_viewmodel.dart';
import 'package:reservitta/viewmodels/pedido_viewmodel.dart';
import 'package:reservitta/views/personalize_visit_view.dart';
import 'package:reservitta/views/table_management_view.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/services/table_layout_service.dart';
import 'package:reservitta/viewmodels/auth_modal_viewmodel.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/auth_modal_dialog.dart';
import 'package:reservitta/views/landing_view.dart';
import 'package:reservitta/views/plan_editor_view.dart';
import 'package:reservitta/views/reservation_confirmation_view.dart';
import 'package:reservitta/views/reservation_flow_view.dart';
import 'package:reservitta/views/restaurant_detail_view.dart';

/// Recorre las pantallas con el ancho de un celular (390 × 844) y comprueba que no
/// haya textos cortados ni desbordes: Flutter los reporta como error en las pruebas.
class _Restaurantes extends RestaurantService {
  _Restaurantes({super.firestore});

  @override
  Future<List<ServiceCatalogModel>> getServicesCatalog() async => [];

  @override
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    dynamic startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async =>
      PaginatedRestaurantsResult(
        restaurants: [_restaurante(nombre: 'Restaurante con un nombre bastante largo para probar')],
        lastDocument: null,
        hasMore: false,
      );
}

class _NoPush implements AdminPushGateway {
  @override
  Future<void> enviar(AdminPushMessage mensaje) async {}
}

class _Ocasiones extends OcasionService {
  @override
  Future<List<OcasionModel>> getOcasiones(String restaurantId) async => const [];
}

class _Categorias extends CategoriaService {
  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) => Stream.value(const []);
}

class _Platillos extends PlatilloService {
  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) => Stream.value(const []);
}

const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

RestaurantModel _restaurante({String nombre = 'Miel Test', bool conMesas = true}) => RestaurantModel(
      id: 'r1',
      nombre: nombre,
      estado: 'activo',
      direccion: 'Calle Francisco Montes de Oca 16, Independencia, San Miguel de Allende',
      telefono: '4155668881',
      correo: 'contacto@restaurante.com',
      descripcion: 'Cocina mexicana con ingredientes locales y un salón con vista al jardín.',
      serviciosIds: const ['reservaciones', 'wifi', 'acceso_discapacidad', 'musica_en_vivo'],
      mesas: conMesas
          ? const [
              MesaModel(id: 'M2', nombre: 'M2', capacidad: 4, x: 0, y: 0),
              MesaModel(id: 'M3', nombre: 'M3', capacidad: 6, x: 120, y: 0),
            ]
          : const [],
      horarios: {
        for (final d in ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo']) d: _horario,
      },
    );

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  final ahora = DateTime(2026, 10, 25, 10);
  final viernes = DateTime(2026, 10, 30);
  const sucursal = BranchModel(id: 'b1', nombre: 'Centro', direccion: 'Calle 1', telefono: '1', esPrincipal: true);

  void celular(WidgetTester tester, {double ancho = 390, double alto = 844, double escalaTexto = 1}) {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> revisar(WidgetTester tester, Widget pantalla) async {
    final anterior = FlutterError.onError;
    FlutterError.onError = (d) {
      final texto = d.toDiagnosticsNode().toStringDeep();
      final pista = RegExp(r'lib/[A-Za-z_/]+\.dart:[0-9]+').allMatches(texto).map((m) => m.group(0)).toSet().join(' ');
      debugPrint('DETALLE ${d.exceptionAsString().split(String.fromCharCode(10)).first} => $pista');
      anterior?.call(d);
    };
    addTearDown(() => FlutterError.onError = anterior);
    await tester.pumpWidget(MaterialApp(home: pantalla));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final escala in [1.0, 1.3]) {
    final sufijo = escala == 1 ? '' : ' (letra grande x$escala)';

    group('Celular: inicio y detalle$sufijo', () {
      testWidgets('inicio sin sesión', (tester) async {
        celular(tester, escalaTexto: escala);
        final vm = PublicCatalogViewModel(restaurantService: _Restaurantes(), isAuthenticated: false);
        await revisar(tester, LandingView(viewModel: vm));
        expect(find.byKey(const ValueKey('boton_header_iniciar_sesion')), findsOneWidget);
      });

      testWidgets('inicio con sesión', (tester) async {
        celular(tester, escalaTexto: escala);
        final vm = PublicCatalogViewModel(
          restaurantService: _Restaurantes(),
          isAuthenticated: true,
          currentUserName: 'Gael Quevedo Morales',
        );
        await revisar(tester, LandingView(viewModel: vm));
      });

      testWidgets('detalle de un restaurante', (tester) async {
        celular(tester, escalaTexto: escala);
        await revisar(
          tester,
          RestaurantDetailView(
            restaurant: _restaurante(nombre: 'Restaurante con un nombre bastante largo para probar'),
            categoriaService: _Categorias(),
            platilloService: _Platillos(),
            bypassAuthForTesting: true,
          ),
        );
        expect(find.byKey(const ValueKey('boton_reservar_mesa')), findsOneWidget);
      });
    });

    group('Celular: inicio de sesión y registro$sufijo', () {
      for (final modo in AuthMode.values) {
        testWidgets('modal en modo ${modo.name}', (tester) async {
          celular(tester, escalaTexto: escala);
          await revisar(tester, Scaffold(body: AuthModalDialog(initialMode: modo, showGuestOption: true)));
        });
      }
    });

    group('Celular: flujo de reserva$sufijo', () {
      Future<ReservationDraftViewModel> flujo(
        WidgetTester tester, {
        required int paso,
        bool conMesas = true,
        bool contacto = false,
      }) async {
        celular(tester, escalaTexto: escala);
        final db = FakeFirebaseFirestore();
        final restaurante = _restaurante(conMesas: conMesas);
        final vm = ReservationDraftViewModel(restaurant: restaurante, clock: () => ahora);
        vm.selectBranch(sucursal);
        vm.selectDate(viernes);
        vm.selectDuration(120);
        vm.setPartySize(3);
        if (conMesas) vm.setSelectedTables([restaurante.mesas.first]);
        vm.selectTime(TimeSlot(inicio: DateTime(2026, 10, 30, 14), fin: DateTime(2026, 10, 30, 16)));
        if (!conMesas) vm.definirSinMesas(true);
        vm.goToStep(paso);
        final reservas = ReservationService(firestore: db);
        final disponibilidad = AvailabilityService(reservas, now: () => ahora);
        await revisar(
          tester,
          ReservationFlowView(
            restaurant: restaurante,
            viewModel: vm,
            availabilityService: disponibilidad,
            bookingService: ReservationBookingService(disponibilidad, reservas),
            isAuthenticated: true,
            currentUserId: 'u1',
            enableContactStep: contacto,
          ),
        );
        return vm;
      }

      testWidgets('paso 0: sucursal', (tester) async {
        await flujo(tester, paso: 0);
      });
      testWidgets('paso 1: fecha', (tester) async {
        await flujo(tester, paso: 1);
      });
      testWidgets('paso 2: duración', (tester) async {
        await flujo(tester, paso: 2);
      });
      testWidgets('paso 3: personas', (tester) async {
        await flujo(tester, paso: 3);
      });
      testWidgets('paso 4: mesa', (tester) async {
        await flujo(tester, paso: 4);
      });
      testWidgets('paso 4 sin mesas configuradas', (tester) async {
        await flujo(tester, paso: 4, conMesas: false);
      });
      testWidgets('paso 5: horario', (tester) async {
        await flujo(tester, paso: 5);
      });
      testWidgets('paso 6: resumen', (tester) async {
        await flujo(tester, paso: 6);
      });
      testWidgets('paso 7: datos de contacto', (tester) async {
        await flujo(tester, paso: 7, contacto: true);
      });
    });

    group('Celular: confirmación$sufijo', () {
      testWidgets('reserva confirmada', (tester) async {
        celular(tester, escalaTexto: escala);
        final r = ReservationModel.create(
          id: 'res_abc123',
          restauranteId: 'r1',
          restauranteNombre: 'Restaurante con un nombre bastante largo para probar',
          fechaLocal: '2026-11-20',
          inicio: DateTime(2026, 11, 20, 14),
          duracionMin: 90,
          personas: 4,
          mesaIds: const ['m1', 'm2'],
          mesasNombres: const ['Mesa Terraza 1', 'Mesa Terraza 2'],
          usuarioId: 'u',
          contactoNombre: 'Gael Quevedo Morales',
          contactoCorreo: 'gael.quevedo.morales@correo-largo.com',
          contactoTelefono: '4181517764',
          estado: 'confirmada',
          tokenGestion: 'ABCDEFGHJKMNPQRSTUVW',
        );
        await revisar(tester, ReservationConfirmationView(reservation: r));
      });
    });

    group('Celular: personalizar y panel de mesas$sufijo', () {
      testWidgets('personalizar la visita', (tester) async {
        celular(tester, escalaTexto: escala);
        final r = _restaurante();
        await revisar(
          tester,
          PersonalizeVisitView(
            restaurant: r,
            draft: ReservationDraftModel(restaurant: r),
            pedidoViewModel: PedidoViewModel(),
            platilloService: _Platillos(),
            ocasionService: _Ocasiones(),
            isAuthenticated: true,
            textoConfirmar: 'Guardar y volver al resumen',
          ),
        );
        await tester.tap(find.byIcon(Icons.health_and_safety_outlined));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'pestaña de alergias');
      });

      testWidgets('estado de las mesas del administrador', (tester) async {
        celular(tester, escalaTexto: escala);
        final db = FakeFirebaseFirestore();
        await TableLayoutService(firestore: db).guardarPlano(
          restauranteId: 'r1',
          mesas: const [
            MesaModel(id: '', nombre: 'M1', capacidad: 4, x: 100, y: 100, rotacion: 45),
            MesaModel(id: '', nombre: 'M2', capacidad: 6, forma: 'redonda', ancho: 130, alto: 130, x: 400, y: 200),
          ],
          elementos: const [
            ElementoPlano(id: '', tipo: 'barra', x: 100, y: 400, ancho: 260, alto: 60, etiqueta: 'Barra'),
          ],
        );
        final ops = AdminOperationsViewModel(
          restaurantId: 'r1',
          reservas: ReservationService(firestore: db),
          mesasService: TableStatusService(firestore: db),
          configService: OperationsConfigService(firestore: db),
          alertService: AdminAlertService(firestore: db, gateway: _NoPush()),
          reminderService: ReminderService(firestore: db),
          tick: Duration.zero,
          sincronizar: false,
        );
        addTearDown(ops.dispose);
        await ops.iniciar();
        await revisar(tester, Scaffold(body: TableManagementView(operaciones: ops, onAbrirReserva: (_) {})));
      });
    });

    group('Celular: plano de mesas$sufijo', () {
      testWidgets('editor del plano', (tester) async {
        celular(tester, escalaTexto: escala);
        final db = FakeFirebaseFirestore();
        final svc = TableLayoutService(firestore: db);
        await svc.guardarPlano(
          restauranteId: 'r1',
          mesas: const [
            MesaModel(id: '', nombre: 'M1', capacidad: 4, x: 100, y: 100, rotacion: 30),
            MesaModel(id: '', nombre: 'M2', capacidad: 6, forma: 'redonda', ancho: 130, alto: 130, x: 400, y: 200),
          ],
          elementos: const [
            ElementoPlano(id: '', tipo: 'barra', x: 100, y: 400, ancho: 260, alto: 60, etiqueta: 'Barra'),
          ],
        );
        await revisar(tester, PlanEditorView(restaurantId: 'r1', service: svc));
        await tester.tap(find.byKey(const ValueKey('btn_agregar_mesa_cuadrada')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'con una mesa seleccionada y su panel');
      });
    });
  }
}
