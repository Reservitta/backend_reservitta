import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/anticipo_reserva.dart';
import 'package:reservitta/models/payment_config.dart';
import 'package:reservitta/models/pedido_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/categoria_service.dart';
import 'package:reservitta/services/pagos_config_service.dart';
import 'package:reservitta/services/pedido_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/viewmodels/carrito_viewmodel.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/views/pagos_config_view.dart';
import 'package:reservitta/views/widgets/reservation_summary_step.dart';
import 'package:reservitta/views/pedido_checkout_view.dart';
import 'package:reservitta/views/pedido_online_view.dart';
import 'package:reservitta/views/pedido_seguimiento_view.dart';
import 'package:reservitta/views/pedidos_online_admin_view.dart';
import 'package:reservitta/views/reservation_confirmation_view.dart';
import 'package:reservitta/views/reservation_detail_view.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/views/restaurant_detail_view.dart';

const _cuenta = DatosBancarios(banco: 'BBVA', beneficiario: 'Casa Sabores', cuenta: '012345678901234567');

class _FakePlatillos extends PlatilloService {
  final List<PlatilloModel> lista;
  _FakePlatillos(this.lista);

  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) => Stream.value(lista);
}

class _FakeCategorias extends CategoriaService {
  @override
  Stream<List<CategoriaModel>> getCategoriasStream(String restaurantId) => Stream.value(const []);
}

PlatilloModel _platillo(String id, String nombre, double precio) =>
    PlatilloModel(id: id, categoriaId: 'c1', nombre: nombre, descripcion: 'Rico', precio: precio);

void _pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _escribir(WidgetTester tester, String key, String texto) async {
  final campo = find.byKey(ValueKey(key));
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
}

Future<void> _tocar(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  group('Pagos y pedidos (admin)', () {
    Future<void> abrir(WidgetTester tester, {RestaurantModel? r, VoidCallback? onGuardado}) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagosConfigView(
              restaurant: r ?? const RestaurantModel(id: 'r1', nombre: 'Casa'),
              service: PagosConfigService(firestore: db),
              onGuardado: onGuardado ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('guarda delivery, cuenta y anticipo', (tester) async {
      await db.collection('restaurants').doc('r1').set({'nombre': 'Casa'});
      var guardado = false;
      await abrir(tester, onGuardado: () => guardado = true);

      await _tocar(tester, 'switch_delivery');
      await _escribir(tester, 'campo_banco', 'BBVA');
      await _escribir(tester, 'campo_beneficiario', 'Casa Sabores');
      await _escribir(tester, 'campo_cuenta', '0123 4567 8901 2345 67');
      await _tocar(tester, 'switch_anticipo');
      await _escribir(tester, 'campo_monto_anticipo', '250');
      await _escribir(tester, 'campo_politica', 'Reembolso 24 h antes');
      await _tocar(tester, 'btn_guardar_pagos');

      expect(guardado, isTrue);
      final data = (await db.collection('restaurants').doc('r1').get()).data()!;
      expect(data['ofreceDelivery'], isTrue);
      expect((data['datosBancarios'] as Map)['cuenta'], '012345678901234567');
      expect((data['anticipo'] as Map)['activo'], isTrue);
      expect((data['anticipo'] as Map)['monto'], 250);
      expect((data['anticipo'] as Map)['politicaCancelacion'], 'Reembolso 24 h antes');
    });

    testWidgets('con anticipo sin cuenta explica qué falta y no guarda', (tester) async {
      await db.collection('restaurants').doc('r1').set({'nombre': 'Casa'});
      var guardado = false;
      await abrir(tester, onGuardado: () => guardado = true);

      await _tocar(tester, 'switch_anticipo');
      await _escribir(tester, 'campo_monto_anticipo', '250');
      await _tocar(tester, 'btn_guardar_pagos');

      expect(guardado, isFalse);
      expect(find.byKey(const ValueKey('pagos_error')), findsOneWidget);
      expect((await db.collection('restaurants').doc('r1').get()).data()!.containsKey('anticipo'), isFalse);
    });

    testWidgets('muestra lo que el restaurante ya configuró', (tester) async {
      await abrir(
        tester,
        r: const RestaurantModel(
          id: 'r1',
          nombre: 'Casa',
          ofreceDelivery: true,
          datosBancarios: _cuenta,
          anticipo: AnticipoConfig(activo: true, monto: 300, horasLimite: 12),
        ),
      );
      expect(find.text('BBVA'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('switch_delivery'))).value, isTrue);
    });
  });

  group('Pedido del cliente', () {
    late PedidoService pedidos;
    late AuthService auth;
    late CarritoViewModel carrito;

    const restaurante = RestaurantModel(
      id: 'r1',
      nombre: 'Casa Sabores',
      direccion: 'Av. Reforma 10',
      estado: 'activo',
      ofreceDelivery: true,
      datosBancarios: _cuenta,
    );

    setUp(() {
      pedidos = PedidoService(firestore: db);
      auth = AuthService(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
        firestore: db,
      );
      carrito = CarritoViewModel()
        ..agregar(_platillo('a', 'Taco', 30))
        ..agregar(_platillo('a', 'Taco', 30))
        ..agregar(_platillo('b', 'Agua', 20));
    });

    Future<void> abrirCheckout(WidgetTester tester, {RestaurantModel r = restaurante}) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PedidoCheckoutView(
            restaurant: r,
            carrito: carrito,
            pedidoService: pedidos,
            authService: auth,
          ),
        ),
      );
    }

    testWidgets('el menú permite agregar platillos y avanzar al pago', (tester) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PedidoOnlineView(
            restaurant: restaurante,
            platilloService: _FakePlatillos([_platillo('a', 'Taco', 30), _platillo('b', 'Agua', 20)]),
            categoriaService: _FakeCategorias(),
            pedidoService: pedidos,
            authService: auth,
            carrito: CarritoViewModel(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Taco'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_ver_carrito')), findsNothing);

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('card_platillo_a')),
        matching: find.byType(FilledButton),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('btn_ver_carrito')), findsOneWidget);
      expect(find.textContaining('\$30.00'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('btn_ver_carrito')));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar pedido'), findsOneWidget);
      expect(find.byKey(const ValueKey('linea_a')), findsOneWidget);
    });

    testWidgets('el menú de pedidos no muestra la etiqueta "Personalizable"', (tester) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PedidoOnlineView(
            restaurant: restaurante,
            platilloService: _FakePlatillos([_platillo('a', 'Taco', 30)]),
            categoriaService: _FakeCategorias(),
            pedidoService: pedidos,
            authService: auth,
            carrito: CarritoViewModel(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Taco'), findsOneWidget);
      expect(find.text('Personalizable'), findsNothing);
    });

    testWidgets('recoger en efectivo: se guarda y se sigue el pedido', (tester) async {
      await abrirCheckout(tester);
      expect(find.byKey(const ValueKey('total_carrito')), findsOneWidget);
      expect(find.text('\$80.00 MXN'), findsWidgets);

      await _escribir(tester, 'campo_nombre_pedido', 'Ana López');
      await _escribir(tester, 'campo_telefono_pedido', '5512345678');
      await _tocar(tester, 'btn_confirmar_pedido');

      final docs = (await db.collection('pedidos').get()).docs;
      expect(docs, hasLength(1));
      final p = PedidoModel.fromFirestore(docs.single);
      expect(p.estado, PedidoModel.estadoRecibido);
      expect(p.metodoPago, PedidoModel.pagoEfectivo);
      expect(p.tipoEntrega, PedidoModel.entregaRecoger);
      expect(p.total, 80);
      expect(p.usuarioId, 'u1');
      expect(p.restauranteId, 'r1');
      expect(carrito.vacio, isTrue);

      expect(find.byType(PedidoSeguimientoView), findsOneWidget);
      expect(find.byKey(const ValueKey('estado_pedido')), findsOneWidget);
      expect(find.text('Recibido'), findsWidgets);
    });

    testWidgets('a domicilio por transferencia: pide dirección y muestra los datos para pagar', (tester) async {
      await abrirCheckout(tester);

      await _tocar(tester, 'pago_transferencia');
      expect(find.byKey(const ValueKey('tarjeta_transferencia')), findsOneWidget);
      expect(find.text('BBVA'), findsOneWidget);
      expect(find.text('012345678901234567'), findsOneWidget);

      await _tocar(tester, 'entrega_domicilio');
      await _escribir(tester, 'campo_nombre_pedido', 'Ana López');
      await _escribir(tester, 'campo_telefono_pedido', '5512345678');

      // Sin dirección no avanza.
      await _tocar(tester, 'btn_confirmar_pedido');
      expect(find.byKey(const ValueKey('error_pedido')), findsOneWidget);
      expect((await db.collection('pedidos').get()).docs, isEmpty);

      await _escribir(tester, 'campo_direccion', 'Calle 1 #2, Col. Centro, CDMX');
      await _tocar(tester, 'btn_confirmar_pedido');

      final p = PedidoModel.fromFirestore((await db.collection('pedidos').get()).docs.single);
      expect(p.esDomicilio, isTrue);
      expect(p.direccion, 'Calle 1 #2, Col. Centro, CDMX');
      expect(p.esTransferencia, isTrue);

      // El cliente ve cómo pagar y dónde subir su comprobante.
      expect(find.byKey(const ValueKey('btn_elegir_comprobante')), findsOneWidget);
      expect(find.textContaining('PED'), findsWidgets);
    });

    testWidgets('el concepto de la transferencia lleva el nombre del cliente', (tester) async {
      await abrirCheckout(tester);
      await _tocar(tester, 'pago_transferencia');
      await _escribir(tester, 'campo_nombre_pedido', 'Ana López');
      await tester.pumpAndSettle();
      expect(find.textContaining('ANA LOPEZ'), findsOneWidget);
    });

    testWidgets('sin cuenta del restaurante solo se ofrece efectivo', (tester) async {
      await abrirCheckout(tester, r: restaurante.copyWith(datosBancarios: const DatosBancarios()));
      expect(find.byKey(const ValueKey('pago_efectivo')), findsOneWidget);
      expect(find.byKey(const ValueKey('pago_transferencia')), findsNothing);
    });

    testWidgets('con el carrito vacío no deja confirmar', (tester) async {
      carrito.limpiar();
      await abrirCheckout(tester);
      expect(find.byKey(const ValueKey('carrito_vacio')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_confirmar_pedido')), findsNothing);
    });

    testWidgets('el cliente ve el avance del pedido en tiempo real', (tester) async {
      final p = await pedidos.crear(
        PedidoModel(
          id: '',
          restauranteId: 'r1',
          restauranteNombre: 'Casa Sabores',
          usuarioId: 'u1',
          contactoNombre: 'Ana',
          contactoTelefono: '5512345678',
          lineas: const [PedidoLinea(platilloId: 'a', nombre: 'Taco', precio: 30, cantidad: 2)],
          tipoEntrega: PedidoModel.entregaDomicilio,
          direccion: 'Calle 1 #2, Centro',
        ),
      );
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(home: PedidoSeguimientoView(pedidoId: p.id, pedidoService: pedidos)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recibido'), findsWidgets);

      await pedidos.cambiarEstado(p.id, PedidoModel.estadoPreparando);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('estado_pedido'))).data, 'Preparando');

      await pedidos.cambiarEstado(p.id, PedidoModel.estadoCancelado);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('estado_pedido'))).data, 'Cancelado');
    });
  });

  group('Pedidos en el panel del restaurante', () {
    late PedidoService pedidos;
    setUp(() => pedidos = PedidoService(firestore: db));

    Future<PedidoModel> crear({String tipo = PedidoModel.entregaDomicilio, String metodo = PedidoModel.pagoEfectivo}) {
      return pedidos.crear(
        PedidoModel(
          id: '',
          restauranteId: 'r1',
          restauranteNombre: 'Casa',
          usuarioId: 'u1',
          contactoNombre: 'Ana López',
          contactoTelefono: '5512345678',
          lineas: const [PedidoLinea(platilloId: 'a', nombre: 'Taco', precio: 30, cantidad: 2)],
          tipoEntrega: tipo,
          direccion: tipo == PedidoModel.entregaDomicilio ? 'Calle 1 #2, Centro' : '',
          metodoPago: metodo,
        ),
      );
    }

    Future<void> abrir(WidgetTester tester) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PedidosOnlineAdminView(restaurantId: 'r1', service: pedidos)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin pedidos muestra el estado vacío', (tester) async {
      await abrir(tester);
      expect(find.byKey(const ValueKey('pedidos_online_vacio')), findsOneWidget);
    });

    testWidgets('el pedido nuevo aparece con su estado, dirección y total', (tester) async {
      final p = await crear();
      await abrir(tester);
      expect(find.byKey(ValueKey('pedido_${p.id}')), findsOneWidget);
      expect(find.text('Recibido'), findsOneWidget);
      expect(find.byKey(ValueKey('direccion_${p.id}')), findsOneWidget);
      expect(find.text('Calle 1 #2, Centro'), findsOneWidget);
      expect(find.byKey(ValueKey('total_${p.id}')), findsOneWidget);
      expect(find.text('\$60.00 MXN'), findsWidgets);
    });

    testWidgets('un toque avanza el estado y se refleja en el momento', (tester) async {
      final p = await crear();
      await abrir(tester);
      await _tocar(tester, 'avanzar_${p.id}');
      expect((await db.collection('pedidos').doc(p.id).get()).data()!['estado'], PedidoModel.estadoPreparando);
      expect(find.text('Preparando'), findsOneWidget);
    });

    testWidgets('cancelar pide confirmación y mueve el pedido al historial', (tester) async {
      final p = await crear();
      await abrir(tester);
      await _tocar(tester, 'cancelar_${p.id}');
      expect(find.text('Cancelar pedido'), findsWidgets);
      await _tocar(tester, 'btn_confirmar_cancelar_pedido');

      expect((await db.collection('pedidos').doc(p.id).get()).data()!['estado'], PedidoModel.estadoCancelado);
      expect(find.byKey(const ValueKey('pedidos_online_vacio')), findsOneWidget);

      await _tocar(tester, 'filtro_historial');
      expect(find.byKey(ValueKey('pedido_${p.id}')), findsOneWidget);
    });

    testWidgets('en efectivo se puede marcar cobrado', (tester) async {
      final p = await crear();
      await abrir(tester);
      expect(find.text('Efectivo · por cobrar'), findsOneWidget);
      await _tocar(tester, 'confirmar_pago_${p.id}');
      expect(
        ((await db.collection('pedidos').doc(p.id).get()).data()!['pago'] as Map)['estado'],
        PedidoModel.pagoConfirmado,
      );
      expect(find.text('Efectivo · cobrado'), findsOneWidget);
    });

    testWidgets('con transferencia solo se confirma el pago cuando llega el comprobante', (tester) async {
      final p = await crear(metodo: PedidoModel.pagoTransferencia);
      await abrir(tester);
      expect(find.byKey(ValueKey('confirmar_pago_${p.id}')), findsNothing);

      await pedidos.marcarComprobanteEnviado(p.id);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('confirmar_pago_${p.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('rechazar_pago_${p.id}')), findsOneWidget);
    });

    testWidgets('el resumen del dashboard cuenta los pedidos nuevos', (tester) async {
      await crear();
      await crear(tipo: PedidoModel.entregaRecoger);
      var abierto = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PedidosOnlineResumen(restaurantId: 'r1', service: pedidos, onVer: () => abierto = true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 pedidos nuevos'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('resumen_pedidos_online')));
      expect(abierto, isTrue);
    });
  });

  group('Anticipo en la confirmación de la reserva', () {
    ReservationModel reserva(AnticipoReserva? anticipo, {String estado = ReservationModel.estadoPendiente}) {
      return ReservationModel.create(
        id: 'abc123xyz',
        restauranteId: 'r1',
        usuarioId: 'u1',
        restauranteNombre: 'Casa',
        contactoNombre: 'Mirza Morales',
        fechaLocal: '2026-12-05',
        inicio: DateTime(2026, 12, 5, 20),
        mesaIds: const ['m1'],
        mesasNombres: const ['M1'],
        estado: estado,
        anticipo: anticipo,
      );
    }

    Future<void> abrir(WidgetTester tester, ReservationModel r, {Future<void> Function(String)? alEnviar}) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(
            reservation: r,
            now: () => DateTime(2026, 12, 1, 10),
            onComprobanteEnviado: alEnviar,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con anticipo pendiente muestra cómo pagarlo y el concepto', (tester) async {
      await abrir(
        tester,
        reserva(AnticipoReserva(
          monto: 200,
          cuenta: _cuenta,
          venceEn: DateTime(2026, 12, 2, 10),
          politicaCancelacion: 'Reembolso 24 h antes',
        )),
      );
      expect(find.text('¡Mesa apartada!'), findsOneWidget);
      expect(find.byKey(const ValueKey('tarjeta_anticipo')), findsOneWidget);
      expect(find.text('Anticipo de \$200.00 MXN'), findsOneWidget);
      expect(find.text('RES ABC12 MIRZA MORALES'), findsOneWidget);
      expect(find.text('BBVA'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_elegir_comprobante')), findsOneWidget);
      expect(find.byKey(const ValueKey('politica_cancelacion')), findsOneWidget);
    });

    testWidgets('con anticipo confirmado la reserva queda confirmada y sin pago pendiente', (tester) async {
      await abrir(
        tester,
        reserva(
          const AnticipoReserva(monto: 200, cuenta: _cuenta, estado: AnticipoReserva.estadoConfirmado),
          estado: ReservationModel.estadoConfirmada,
        ),
      );
      expect(find.text('¡Reserva confirmada!'), findsOneWidget);
      expect(find.text('Anticipo confirmado'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_elegir_comprobante')), findsNothing);
    });

    testWidgets('un comprobante ya enviado no pide subirlo otra vez', (tester) async {
      await abrir(
        tester,
        reserva(const AnticipoReserva(
          monto: 200,
          cuenta: _cuenta,
          estado: AnticipoReserva.estadoComprobanteEnviado,
        )),
      );
      expect(find.byKey(const ValueKey('comprobante_enviado')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_elegir_comprobante')), findsNothing);
    });

    testWidgets('si el comprobante fue rechazado explica por qué y deja subir otro', (tester) async {
      await abrir(
        tester,
        reserva(const AnticipoReserva(
          monto: 200,
          cuenta: _cuenta,
          estado: AnticipoReserva.estadoRechazado,
          motivoRechazo: 'El monto no coincide',
        )),
      );
      expect(find.byKey(const ValueKey('anticipo_rechazado')), findsOneWidget);
      expect(find.textContaining('El monto no coincide'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_elegir_comprobante')), findsOneWidget);
    });

    testWidgets('una reserva sin anticipo no muestra nada de pagos', (tester) async {
      await abrir(tester, reserva(null, estado: ReservationModel.estadoConfirmada));
      expect(find.byKey(const ValueKey('tarjeta_anticipo')), findsNothing);
      expect(find.text('¡Reserva confirmada!'), findsOneWidget);
    });
  });

  group('Revisión del anticipo en el detalle de la reserva', () {
    late ReservationService repo;
    late String id;
    var confirmado = false;
    String? rechazo;

    setUp(() async {
      repo = ReservationService(firestore: db);
      confirmado = false;
      rechazo = null;
      id = (await repo.createReservationVerified(
        ReservationModel.create(
          id: '',
          restauranteId: 'r1',
          usuarioId: 'u1',
          contactoNombre: 'Mirza Morales',
          fechaLocal: '2026-12-05',
          inicio: DateTime(2026, 12, 5, 20),
          mesaIds: const ['m1'],
          estado: ReservationModel.estadoPendiente,
          preordenItems: const [
            {'platilloId': 'a', 'nombre': 'Taco', 'precio': 100.0, 'cantidad': 3, 'total': 300.0},
          ],
          anticipo: const AnticipoReserva(monto: 200, cuenta: _cuenta),
        ),
      ))
          .id;
    });

    Future<void> abrir(WidgetTester tester) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationDetailView(
            reservationId: id,
            repository: repo,
            onChangeState: (_) async => null,
            onConfirmarAnticipo: () async {
              confirmado = true;
              await repo.confirmarAnticipo(reservationId: id, usuarioId: 'admin');
              return null;
            },
            onRechazarAnticipo: (motivo) async {
              rechazo = motivo;
              await repo.rechazarAnticipo(reservationId: id, motivo: motivo);
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el anticipo pendiente con su concepto', (tester) async {
      await abrir(tester);
      expect(find.byKey(const ValueKey('detalle_anticipo')), findsOneWidget);
      expect(find.text('Esperando anticipo'), findsOneWidget);
      expect(find.textContaining('MIRZA MORALES'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_confirmar_anticipo')), findsOneWidget);
      // Todavía no hay comprobante que rechazar.
      expect(find.byKey(const ValueKey('btn_rechazar_anticipo')), findsNothing);
    });

    testWidgets('confirmar el anticipo confirma la reserva y explica el descuento', (tester) async {
      await abrir(tester);
      await _tocar(tester, 'btn_confirmar_anticipo');
      expect(confirmado, isTrue);
      expect(
        (await db.collection('reservations').doc(id).get()).data()!['estado'],
        ReservationModel.estadoConfirmada,
      );
      expect(find.text('Anticipo confirmado'), findsOneWidget);
      expect(find.byKey(const ValueKey('anticipo_descuento')), findsOneWidget);
      expect(find.textContaining('por cobrar \$100.00 MXN'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_confirmar_anticipo')), findsNothing);
    });

    testWidgets('sin callbacks (abierto desde la lista) igual permite confirmar el anticipo', (tester) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationDetailView(
            reservationId: id,
            repository: repo,
            onChangeState: (_) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('btn_confirmar_anticipo')), findsOneWidget);
      await _tocar(tester, 'btn_confirmar_anticipo');
      expect(
        (await db.collection('reservations').doc(id).get()).data()!['estado'],
        ReservationModel.estadoConfirmada,
      );
      expect(find.text('Anticipo confirmado'), findsOneWidget);
    });

    testWidgets('rechazar el comprobante pide el motivo y lo guarda', (tester) async {
      await repo.marcarComprobanteEnviado(id);
      await abrir(tester);
      await _tocar(tester, 'btn_rechazar_anticipo');
      await tester.enterText(find.byKey(const ValueKey('campo_motivo_rechazo')), 'El monto no coincide');
      await _tocar(tester, 'btn_confirmar_rechazo');

      expect(rechazo, 'El monto no coincide');
      final a = (await db.collection('reservations').doc(id).get()).data()!['anticipo'] as Map;
      expect(a['estado'], AnticipoReserva.estadoRechazado);
      expect(a['motivoRechazo'], 'El monto no coincide');
    });
  });

  group('Resumen de la reserva', () {
    Future<void> abrir(WidgetTester tester, RestaurantModel r) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReservationSummaryStep(
                draft: ReservationDraftModel(
                  restaurant: r,
                  fecha: DateTime(2026, 12, 5),
                  duracionMin: 90,
                  personas: 2,
                  mesaIds: const ['m1'],
                  mesasNombres: const ['M1'],
                  horario: const TimeOfDay(hour: 19, minute: 0),
                ),
                onEditStep: (_) {},
                isAuthenticated: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('avisa del anticipo y de la política antes de reservar', (tester) async {
      await abrir(
        tester,
        const RestaurantModel(
          id: 'r1',
          nombre: 'Casa',
          datosBancarios: _cuenta,
          anticipo: AnticipoConfig(activo: true, monto: 250, politicaCancelacion: 'Reembolso 24 h antes'),
        ),
      );
      expect(find.byKey(const ValueKey('aviso_anticipo_resumen')), findsOneWidget);
      expect(find.textContaining('\$250.00 MXN'), findsOneWidget);
      expect(find.textContaining('Reembolso 24 h antes'), findsOneWidget);
    });

    testWidgets('sin anticipo no muestra el aviso', (tester) async {
      await abrir(tester, const RestaurantModel(id: 'r1', nombre: 'Casa'));
      expect(find.byKey(const ValueKey('aviso_anticipo_resumen')), findsNothing);
    });
  });

  group('Detalle del restaurante', () {
    Future<void> abrir(WidgetTester tester, RestaurantModel r) async {
      _pantallaGrande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: RestaurantDetailView(
            restaurant: r,
            bypassAuthForTesting: true,
            authService: AuthService(auth: MockFirebaseAuth(), firestore: db),
            categoriaService: _FakeCategorias(),
            platilloService: _FakePlatillos(const []),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con delivery hay dos botones: reservar y pedir', (tester) async {
      await abrir(tester, const RestaurantModel(id: 'r1', nombre: 'Casa', estado: 'activo', ofreceDelivery: true));
      expect(find.byKey(const ValueKey('boton_reservar_mesa')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_pedir_domicilio')), findsOneWidget);
    });

    testWidgets('sin delivery solo se puede reservar', (tester) async {
      await abrir(tester, const RestaurantModel(id: 'r1', nombre: 'Casa', estado: 'activo'));
      expect(find.byKey(const ValueKey('boton_reservar_mesa')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_pedir_domicilio')), findsNothing);
    });

    testWidgets('el botón de pedir abre el menú para pedir', (tester) async {
      await abrir(tester, const RestaurantModel(id: 'r1', nombre: 'Casa', estado: 'activo', ofreceDelivery: true));
      await _tocar(tester, 'boton_pedir_domicilio');
      expect(find.byType(PedidoOnlineView), findsOneWidget);
    });
  });
}
