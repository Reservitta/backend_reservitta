import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/anticipo_reserva.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/payment_config.dart';
import 'package:reservitta/models/pedido_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/comprobante_service.dart';
import 'package:reservitta/services/pagos_config_service.dart';
import 'package:reservitta/services/pedido_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/utils/image_data_uri.dart';

const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');
const _cuenta = DatosBancarios(banco: 'BBVA', beneficiario: 'Casa Sabores', cuenta: '012345678901234567');

RestaurantModel _restaurant({
  AnticipoConfig anticipo = const AnticipoConfig(),
  DatosBancarios cuenta = const DatosBancarios(),
}) {
  return RestaurantModel(
    id: 'r1',
    nombre: 'Miel Test',
    estado: 'activo',
    datosBancarios: cuenta,
    anticipo: anticipo,
    horarios: {
      for (final d in ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'])
        d: _horario,
    },
  );
}

PedidoModel _pedido({
  String tipo = PedidoModel.entregaRecoger,
  String direccion = '',
  String nombre = 'Ana López',
  String telefono = '5512345678',
  List<PedidoLinea>? lineas,
}) {
  return PedidoModel(
    id: '',
    restauranteId: 'r1',
    restauranteNombre: 'Miel Test',
    usuarioId: 'u1',
    contactoNombre: nombre,
    contactoTelefono: telefono,
    lineas: lineas ??
        const [
          PedidoLinea(platilloId: 'a', nombre: 'Taco', precio: 30, cantidad: 3),
          PedidoLinea(platilloId: 'b', nombre: 'Agua', precio: 20, cantidad: 1),
        ],
    tipoEntrega: tipo,
    direccion: direccion,
  );
}

void main() {
  late FakeFirebaseFirestore db;
  late ReservationService repo;

  final now = DateTime(2026, 10, 25, 10);
  final viernes = DateTime(2026, 10, 30);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ReservationService(firestore: db);
  });

  group('Reserva con anticipo', () {
    ReservationDraftModel draft(RestaurantModel r) => ReservationDraftModel(
          restaurant: r,
          fecha: viernes,
          duracionMin: 90,
          personas: 4,
          mesaIds: const ['m1'],
          mesasNombres: const ['M1'],
          horario: const TimeOfDay(hour: 14, minute: 0),
        );

    ReservationBookingService booking() =>
        ReservationBookingService(AvailabilityService(repo, now: () => now), repo);

    test('con anticipo activo la reserva queda pendiente y guarda el anticipo', () async {
      final r = _restaurant(
        anticipo: const AnticipoConfig(activo: true, monto: 200, politicaCancelacion: 'Reembolso 24 h antes'),
        cuenta: _cuenta,
      );
      final result = await booking().confirm(
        restaurant: r,
        draft: draft(r),
        usuarioId: 'u1',
        contactoNombre: 'Mirza',
      );
      final ok = result as BookingConfirmed;
      expect(ok.reservation.estado, ReservationModel.estadoPendiente);
      expect(ok.reservation.anticipo?.monto, 200);
      expect(ok.reservation.anticipo?.estado, AnticipoReserva.estadoPendiente);
      expect(ok.reservation.anticipo?.cuenta.cuenta, '012345678901234567');

      final doc = await db.collection('reservations').doc(ok.reservation.id).get();
      expect(doc.data()!['estado'], ReservationModel.estadoPendiente);
      expect((doc.data()!['anticipo'] as Map)['politicaCancelacion'], 'Reembolso 24 h antes');
    });

    test('la reserva pendiente por anticipo bloquea la mesa', () async {
      final r = _restaurant(anticipo: const AnticipoConfig(activo: true, monto: 200), cuenta: _cuenta);
      await booking().confirm(restaurant: r, draft: draft(r), usuarioId: 'u1');
      final segundo = await booking().confirm(restaurant: r, draft: draft(r), usuarioId: 'u2');
      // La revalidación ve la mesa apartada antes de intentar guardar.
      expect(segundo, isA<BookingRejected>());
      expect((await db.collection('reservations').get()).docs, hasLength(1));
    });

    test('sin anticipo activo la reserva se confirma como siempre', () async {
      final r = _restaurant(cuenta: _cuenta);
      final ok = await booking().confirm(restaurant: r, draft: draft(r), usuarioId: 'u1') as BookingConfirmed;
      expect(ok.reservation.estado, ReservationModel.estadoConfirmada);
      expect(ok.reservation.anticipo, isNull);
    });

    test('con anticipo activo pero sin cuenta no se pide anticipo', () async {
      final r = _restaurant(anticipo: const AnticipoConfig(activo: true, monto: 200));
      final ok = await booking().confirm(restaurant: r, draft: draft(r), usuarioId: 'u1') as BookingConfirmed;
      expect(ok.reservation.estado, ReservationModel.estadoConfirmada);
      expect(ok.reservation.anticipo, isNull);
    });
  });

  group('Revisión del anticipo', () {
    Future<String> reservaConAnticipo() async {
      final r = ReservationModel.create(
        id: '',
        restauranteId: 'r1',
        usuarioId: 'u1',
        contactoNombre: 'Mirza',
        fechaLocal: '2026-10-30',
        inicio: DateTime(2026, 10, 30, 14),
        mesaIds: const ['m1'],
        estado: ReservationModel.estadoPendiente,
        anticipo: const AnticipoReserva(monto: 200, cuenta: _cuenta),
      );
      return (await repo.createReservationVerified(r)).id;
    }

    Future<Map<String, dynamic>> datos(String id) async =>
        (await db.collection('reservations').doc(id).get()).data()!;

    test('al subir el comprobante queda por revisar', () async {
      final id = await reservaConAnticipo();
      await repo.marcarComprobanteEnviado(id);
      final d = await datos(id);
      expect((d['anticipo'] as Map)['estado'], AnticipoReserva.estadoComprobanteEnviado);
      expect(d['estado'], ReservationModel.estadoPendiente);
    });

    test('al confirmar el anticipo la reserva queda confirmada', () async {
      final id = await reservaConAnticipo();
      await repo.marcarComprobanteEnviado(id);
      await repo.confirmarAnticipo(reservationId: id, usuarioId: 'admin1');
      final d = await datos(id);
      expect(d['estado'], ReservationModel.estadoConfirmada);
      expect((d['anticipo'] as Map)['estado'], AnticipoReserva.estadoConfirmado);
      expect(d['estadoActualizadoPor'], 'admin1');
    });

    test('al rechazar, el cliente ve el motivo y puede subir otro comprobante', () async {
      final id = await reservaConAnticipo();
      await repo.marcarComprobanteEnviado(id);
      await repo.rechazarAnticipo(reservationId: id, motivo: 'El monto no coincide');
      var a = (await datos(id))['anticipo'] as Map;
      expect(a['estado'], AnticipoReserva.estadoRechazado);
      expect(a['motivoRechazo'], 'El monto no coincide');

      await repo.marcarComprobanteEnviado(id);
      a = (await datos(id))['anticipo'] as Map;
      expect(a['estado'], AnticipoReserva.estadoComprobanteEnviado);
      expect(a.containsKey('motivoRechazo'), isFalse);
    });

    test('no se confirma el anticipo de una reserva cancelada', () async {
      final id = await reservaConAnticipo();
      await repo.changeOperationalState(
        reservationId: id,
        nuevoEstado: ReservationModel.estadoCancelada,
        usuarioId: 'admin1',
      );
      await expectLater(
        repo.confirmarAnticipo(reservationId: id, usuarioId: 'admin1'),
        throwsA(isA<StateError>()),
      );
    });

    test('cancelar una reserva pendiente por anticipo libera la mesa', () async {
      final id = await reservaConAnticipo();
      await repo.changeOperationalState(
        reservationId: id,
        nuevoEstado: ReservationModel.estadoCancelada,
        usuarioId: 'admin1',
      );
      final otra = ReservationModel.create(
        id: '',
        restauranteId: 'r1',
        usuarioId: 'u2',
        fechaLocal: '2026-10-30',
        inicio: DateTime(2026, 10, 30, 14),
        mesaIds: const ['m1'],
      );
      expect((await repo.createReservationVerified(otra)).id, isNotEmpty);
    });

    test('una reserva sin anticipo no se puede confirmar como anticipo', () async {
      final r = ReservationModel.create(
        id: '',
        restauranteId: 'r1',
        usuarioId: 'u1',
        fechaLocal: '2026-10-30',
        inicio: DateTime(2026, 10, 30, 14),
      );
      final id = (await repo.createReservationVerified(r)).id;
      await expectLater(
        repo.confirmarAnticipo(reservationId: id, usuarioId: 'admin1'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Pedidos', () {
    late PedidoService service;
    setUp(() => service = PedidoService(firestore: db));

    test('guarda el pedido como recibido y recalcula el total', () async {
      final guardado = await service.crear(_pedido());
      expect(guardado.total, 110);
      expect(guardado.estado, PedidoModel.estadoRecibido);
      expect(guardado.estadoPago, PedidoModel.pagoPendiente);
      final doc = await db.collection('pedidos').doc(guardado.id).get();
      expect(doc.data()!['restauranteId'], 'r1');
      expect(doc.data()!['total'], 110);
    });

    test('usa el id reservado para el concepto de la transferencia', () async {
      final id = service.nuevoId();
      final guardado = await service.crear(_pedido(), id: id);
      expect(guardado.id, id);
      expect((await db.collection('pedidos').doc(id).get()).exists, isTrue);
    });

    test('a domicilio exige la dirección', () async {
      await expectLater(
        service.crear(_pedido(tipo: PedidoModel.entregaDomicilio, direccion: 'Calle')),
        throwsA(isA<PedidoInvalidoException>()),
      );
      expect(
        PedidoService.validar(_pedido(tipo: PedidoModel.entregaDomicilio, direccion: 'Calle 1 #2, Centro')),
        isNull,
      );
    });

    test('para recoger no pide dirección', () {
      expect(PedidoService.validar(_pedido()), isNull);
    });

    test('exige nombre, teléfono y al menos un platillo', () {
      expect(PedidoService.validar(_pedido(nombre: ' ')), isNotNull);
      expect(PedidoService.validar(_pedido(telefono: '123')), isNotNull);
      expect(PedidoService.validar(_pedido(lineas: const [])), isNotNull);
    });

    test('no guarda un pedido inválido', () async {
      await expectLater(service.crear(_pedido(lineas: const [])), throwsA(isA<PedidoInvalidoException>()));
      expect((await db.collection('pedidos').get()).docs, isEmpty);
    });

    test('para recoger avanza recibido → preparando → listo → entregado', () async {
      final p = await service.crear(_pedido());
      for (final siguiente in [
        PedidoModel.estadoPreparando,
        PedidoModel.estadoListo,
        PedidoModel.estadoEntregado,
      ]) {
        await service.cambiarEstado(p.id, siguiente);
        expect((await db.collection('pedidos').doc(p.id).get()).data()!['estado'], siguiente);
      }
    });

    test('a domicilio pasa por "en camino"', () async {
      final p = await service.crear(
        _pedido(tipo: PedidoModel.entregaDomicilio, direccion: 'Calle 1 #2, Centro'),
      );
      await service.cambiarEstado(p.id, PedidoModel.estadoPreparando);
      await service.cambiarEstado(p.id, PedidoModel.estadoListo);
      await service.cambiarEstado(p.id, PedidoModel.estadoEnCamino);
      await service.cambiarEstado(p.id, PedidoModel.estadoEntregado);
      expect((await db.collection('pedidos').doc(p.id).get()).data()!['estado'], PedidoModel.estadoEntregado);
    });

    test('no se salta pasos ni se retrocede', () async {
      final p = await service.crear(_pedido());
      await expectLater(service.cambiarEstado(p.id, PedidoModel.estadoListo), throwsA(isA<StateError>()));
      await service.cambiarEstado(p.id, PedidoModel.estadoPreparando);
      await expectLater(service.cambiarEstado(p.id, PedidoModel.estadoRecibido), throwsA(isA<StateError>()));
      // Para recoger no existe "en camino".
      await service.cambiarEstado(p.id, PedidoModel.estadoListo);
      await expectLater(service.cambiarEstado(p.id, PedidoModel.estadoEnCamino), throwsA(isA<StateError>()));
    });

    test('se puede cancelar mientras no se entregue y luego ya no cambia', () async {
      final p = await service.crear(_pedido());
      await service.cambiarEstado(p.id, PedidoModel.estadoPreparando);
      await service.cambiarEstado(p.id, PedidoModel.estadoCancelado);
      expect((await db.collection('pedidos').doc(p.id).get()).data()!['estado'], PedidoModel.estadoCancelado);
      await expectLater(service.cambiarEstado(p.id, PedidoModel.estadoPreparando), throwsA(isA<StateError>()));
    });

    test('un pedido entregado ya no se cancela', () async {
      final p = await service.crear(_pedido());
      for (final e in [PedidoModel.estadoPreparando, PedidoModel.estadoListo, PedidoModel.estadoEntregado]) {
        await service.cambiarEstado(p.id, e);
      }
      await expectLater(service.cambiarEstado(p.id, PedidoModel.estadoCancelado), throwsA(isA<StateError>()));
    });

    test('el pago por transferencia pasa de comprobante a confirmado o rechazado', () async {
      final p = await service.crear(
        PedidoModel(
          id: '',
          restauranteId: 'r1',
          usuarioId: 'u1',
          contactoNombre: 'Ana',
          contactoTelefono: '5512345678',
          lineas: const [PedidoLinea(platilloId: 'a', nombre: 'Taco', precio: 30, cantidad: 1)],
          metodoPago: PedidoModel.pagoTransferencia,
        ),
      );
      Future<String> pago() async =>
          ((await db.collection('pedidos').doc(p.id).get()).data()!['pago'] as Map)['estado'] as String;

      await service.marcarComprobanteEnviado(p.id);
      expect(await pago(), PedidoModel.pagoComprobanteEnviado);
      await service.rechazarPago(p.id);
      expect(await pago(), PedidoModel.pagoRechazado);
      await service.marcarComprobanteEnviado(p.id);
      await service.confirmarPago(p.id);
      expect(await pago(), PedidoModel.pagoConfirmado);
    });

    test('el restaurante solo ve sus pedidos, los más nuevos primero', () async {
      final a = await service.crear(_pedido());
      await db.collection('pedidos').doc(a.id).update({
        'creadoEn': Timestamp.fromDate(DateTime(2026, 11, 1, 10)),
      });
      final b = await service.crear(_pedido());
      await db.collection('pedidos').doc(b.id).update({
        'creadoEn': Timestamp.fromDate(DateTime(2026, 11, 1, 12)),
      });
      await db.collection('pedidos').add({
        ..._pedido().toMap(),
        'restauranteId': 'otro',
      });

      final lista = await service.pedidosDelRestaurante('r1').first;
      expect(lista.map((p) => p.id), [b.id, a.id]);
    });

    test('el cliente sigue su pedido en tiempo real', () async {
      final p = await service.crear(_pedido());
      final estados = <String>[];
      final sub = service.seguir(p.id).listen((x) => estados.add(x!.estado));
      await Future<void>.delayed(Duration.zero);
      await service.cambiarEstado(p.id, PedidoModel.estadoPreparando);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(estados, containsAllInOrder([PedidoModel.estadoRecibido, PedidoModel.estadoPreparando]));
    });
  });

  group('Comprobantes', () {
    late ComprobanteService service;
    setUp(() => service = ComprobanteService(firestore: db));

    test('guarda el comprobante en su propio documento y se puede leer', () async {
      final bytes = Uint8List.fromList(List.generate(200, (i) => i % 256));
      await service.guardar(
        tipo: 'reserva',
        refId: 'abc',
        restauranteId: 'r1',
        usuarioId: 'u1',
        bytes: bytes,
        extension: 'png',
      );
      final doc = await db.collection('comprobantes').doc('reserva_abc').get();
      expect(doc.data()!['restauranteId'], 'r1');
      expect(doc.data()!['usuarioId'], 'u1');

      final leido = await service.obtener('reserva', 'abc');
      expect(leido, isNotNull);
      expect(leido!.bytes, bytes);
    });

    test('subir otro comprobante reemplaza el anterior', () async {
      Future<void> subir(int valor) => service.guardar(
            tipo: 'pedido',
            refId: 'p1',
            restauranteId: 'r1',
            usuarioId: 'u1',
            bytes: Uint8List.fromList([valor, valor, valor]),
            extension: 'jpg',
          );
      await subir(1);
      await subir(2);
      expect((await db.collection('comprobantes').get()).docs, hasLength(1));
      expect((await service.obtener('pedido', 'p1'))!.bytes, Uint8List.fromList([2, 2, 2]));
    });

    test('rechaza una imagen demasiado pesada', () async {
      await expectLater(
        service.guardar(
          tipo: 'reserva',
          refId: 'abc',
          restauranteId: 'r1',
          usuarioId: 'u1',
          bytes: Uint8List(ComprobanteService.maxCaracteres),
          extension: 'jpg',
        ),
        throwsA(isA<ImageTooLargeException>()),
      );
      expect((await db.collection('comprobantes').get()).docs, isEmpty);
    });

    test('sin comprobante devuelve null', () async {
      expect(await service.obtener('reserva', 'nada'), isNull);
    });
  });

  group('Registro del restaurante', () {
    Future<Map<String, dynamic>> registrar({required bool delivery}) async {
      final auth = AuthService(auth: MockFirebaseAuth(), firestore: db);
      final user = await auth.registerAdmin(
        nombre: 'Mirza Morales',
        correo: 'mirza@test.com',
        telefono: '5512345678',
        password: 'Secreta123',
        nombreRestaurante: 'Casa Sabores',
        ofreceDelivery: delivery,
      );
      final rest = await db.collection('restaurants').get();
      expect(rest.docs, hasLength(1));
      expect(user.uid, isNotEmpty);
      return rest.docs.single.data();
    }

    test('guarda si el restaurante ofrece pedidos a domicilio', () async {
      expect((await registrar(delivery: true))['ofreceDelivery'], isTrue);
    });

    test('por defecto no ofrece delivery', () async {
      expect((await registrar(delivery: false))['ofreceDelivery'], isFalse);
    });
  });

  group('Configuración de pagos', () {
    test('validar: el anticipo exige monto y cuenta completa', () {
      expect(
        PagosConfigService.validar(
          cuenta: const DatosBancarios(),
          anticipo: const AnticipoConfig(activo: true, monto: 200),
        ),
        isNotNull,
      );
      expect(
        PagosConfigService.validar(
          cuenta: _cuenta,
          anticipo: const AnticipoConfig(activo: true, monto: 0),
        ),
        isNotNull,
      );
      expect(
        PagosConfigService.validar(
          cuenta: _cuenta,
          anticipo: const AnticipoConfig(activo: true, monto: 200, horasLimite: 0),
        ),
        isNotNull,
      );
      expect(
        PagosConfigService.validar(
          cuenta: _cuenta,
          anticipo: const AnticipoConfig(activo: true, monto: 200),
        ),
        isNull,
      );
    });

    test('validar: sin anticipo la cuenta es opcional, pero no puede quedar a medias', () {
      expect(PagosConfigService.validar(cuenta: const DatosBancarios(), anticipo: const AnticipoConfig()), isNull);
      expect(
        PagosConfigService.validar(
          cuenta: const DatosBancarios(banco: 'BBVA'),
          anticipo: const AnticipoConfig(),
        ),
        isNotNull,
      );
    });

    test('guardar escribe la configuración sin borrar el resto del restaurante', () async {
      await db.collection('restaurants').doc('r1').set({'nombre': 'Casa', 'telefono': '555'});
      await PagosConfigService(firestore: db).guardar(
        restaurantId: 'r1',
        ofreceDelivery: true,
        cuenta: const DatosBancarios(banco: ' BBVA ', beneficiario: 'Casa', cuenta: '0123 4567 8901 2345 67'),
        anticipo: const AnticipoConfig(activo: true, monto: 300, politicaCancelacion: ' Sin reembolso '),
      );
      final data = (await db.collection('restaurants').doc('r1').get()).data()!;
      expect(data['nombre'], 'Casa');
      expect(data['telefono'], '555');
      expect(data['ofreceDelivery'], isTrue);
      expect((data['datosBancarios'] as Map)['banco'], 'BBVA');
      expect((data['datosBancarios'] as Map)['cuenta'], '012345678901234567');
      expect((data['anticipo'] as Map)['monto'], 300);
      expect((data['anticipo'] as Map)['politicaCancelacion'], 'Sin reembolso');

      final r = RestaurantModel.fromMap('r1', data);
      expect(r.requiereAnticipo, isTrue);
      expect(r.ofreceDelivery, isTrue);
    });
  });
}
