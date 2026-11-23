import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/anticipo_reserva.dart';
import 'package:reservitta/models/payment_config.dart';
import 'package:reservitta/models/pedido_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/viewmodels/carrito_viewmodel.dart';

PlatilloModel _platillo(String id, double precio) => PlatilloModel(
      id: id,
      categoriaId: 'c1',
      nombre: 'Platillo $id',
      descripcion: '',
      precio: precio,
    );

void main() {
  group('Concepto de la transferencia', () {
    test('lleva un código corto y el nombre del cliente', () {
      expect(
        ConceptoTransferencia.generar(prefijo: 'RES', id: 'abc123xyz', nombre: 'Juan Pérez'),
        'RES ABC12 JUAN PEREZ',
      );
    });

    test('quita acentos y símbolos', () {
      expect(
        ConceptoTransferencia.generar(prefijo: 'PED', id: 'k9', nombre: 'Ñandú & Co.'),
        'PED K9 NANDU CO',
      );
    });

    test('no pasa de 30 caracteres', () {
      final c = ConceptoTransferencia.generar(
        prefijo: 'RES',
        id: 'abcdef',
        nombre: 'Maria Guadalupe Hernandez Rodriguez',
      );
      expect(c.length, lessThanOrEqualTo(ConceptoTransferencia.maxLongitud));
      expect(c, startsWith('RES ABCDE MARIA'));
    });

    test('sin nombre queda solo el código', () {
      expect(ConceptoTransferencia.generar(prefijo: 'RES', id: 'abc', nombre: '  '), 'RES ABC');
    });

    test('es estable para el mismo registro', () {
      final a = ConceptoTransferencia.generar(prefijo: 'RES', id: 'id1', nombre: 'Ana');
      final b = ConceptoTransferencia.generar(prefijo: 'RES', id: 'id1', nombre: 'Ana');
      expect(a, b);
    });
  });

  group('Datos bancarios', () {
    test('piden banco, beneficiario y de 10 a 18 dígitos', () {
      expect(DatosBancarios.validar(banco: '', beneficiario: 'A', cuenta: '0123456789'), isNotNull);
      expect(DatosBancarios.validar(banco: 'BBVA', beneficiario: '', cuenta: '0123456789'), isNotNull);
      expect(DatosBancarios.validar(banco: 'BBVA', beneficiario: 'A', cuenta: '123'), isNotNull);
      expect(DatosBancarios.validar(banco: 'BBVA', beneficiario: 'A', cuenta: '12345678901234567890'), isNotNull);
      expect(DatosBancarios.validar(banco: 'BBVA', beneficiario: 'A', cuenta: '0123 4567 8901 2345 67'), isNull);
    });

    test('la cuenta se guarda solo con dígitos', () {
      expect(DatosBancarios.limpiarCuenta('0123 4567-89'), '0123456789');
    });

    test('un restaurante solo pide anticipo con monto y cuenta completa', () {
      const cuenta = DatosBancarios(banco: 'BBVA', beneficiario: 'Casa', cuenta: '0123456789');
      const anticipo = AnticipoConfig(activo: true, monto: 200);
      expect(const RestaurantModel(id: 'r', nombre: 'R', anticipo: anticipo).requiereAnticipo, isFalse);
      expect(
        const RestaurantModel(id: 'r', nombre: 'R', datosBancarios: cuenta, anticipo: anticipo).requiereAnticipo,
        isTrue,
      );
      expect(
        const RestaurantModel(
          id: 'r',
          nombre: 'R',
          datosBancarios: cuenta,
          anticipo: AnticipoConfig(activo: true, monto: 0),
        ).requiereAnticipo,
        isFalse,
      );
    });

    test('el restaurante lee su configuración de Firestore', () {
      final r = RestaurantModel.fromMap('r1', {
        'nombre': 'Casa',
        'ofreceDelivery': true,
        'datosBancarios': {'banco': 'BBVA', 'beneficiario': 'Casa SA', 'cuenta': '0123456789'},
        'anticipo': {'activo': true, 'monto': 150, 'horasLimite': 12, 'politicaCancelacion': 'Sin reembolso'},
      });
      expect(r.ofreceDelivery, isTrue);
      expect(r.datosBancarios.banco, 'BBVA');
      expect(r.anticipo.monto, 150);
      expect(r.anticipo.horasLimite, 12);
      expect(r.requiereAnticipo, isTrue);
      expect(r.aceptaTransferencia, isTrue);
    });

    test('un restaurante sin configuración no ofrece delivery ni anticipo', () {
      final r = RestaurantModel.fromMap('r1', {'nombre': 'Casa'});
      expect(r.ofreceDelivery, isFalse);
      expect(r.requiereAnticipo, isFalse);
      expect(r.aceptaTransferencia, isFalse);
    });
  });

  group('Anticipo de la reserva', () {
    const cuenta = DatosBancarios(banco: 'BBVA', beneficiario: 'Casa', cuenta: '0123456789');

    test('vence en el plazo configurado', () {
      final ahora = DateTime(2026, 11, 1, 10);
      final a = AnticipoReserva.desdeConfig(
        config: const AnticipoConfig(activo: true, monto: 200, horasLimite: 24),
        cuenta: cuenta,
        ahora: ahora,
        inicioReserva: DateTime(2026, 11, 20, 20),
      );
      expect(a.venceEn, DateTime(2026, 11, 2, 10));
      expect(a.pendiente, isTrue);
      expect(a.estaVencido(DateTime(2026, 11, 1, 23)), isFalse);
      expect(a.estaVencido(DateTime(2026, 11, 2, 11)), isTrue);
    });

    test('no da más tiempo que el que falta para la reserva', () {
      final inicio = DateTime(2026, 11, 1, 14);
      final a = AnticipoReserva.desdeConfig(
        config: const AnticipoConfig(activo: true, monto: 200),
        cuenta: cuenta,
        ahora: DateTime(2026, 11, 1, 10),
        inicioReserva: inicio,
      );
      expect(a.venceEn, inicio);
    });

    test('un anticipo confirmado nunca está vencido', () {
      final a = AnticipoReserva(
        monto: 200,
        estado: AnticipoReserva.estadoConfirmado,
        venceEn: DateTime(2026, 1, 1),
      );
      expect(a.estaVencido(DateTime(2026, 12, 1)), isFalse);
    });

    test('solo se sube comprobante si está pendiente o fue rechazado', () {
      expect(const AnticipoReserva(monto: 1).aceptaComprobante, isTrue);
      expect(const AnticipoReserva(monto: 1, estado: AnticipoReserva.estadoRechazado).aceptaComprobante, isTrue);
      expect(const AnticipoReserva(monto: 1, estado: AnticipoReserva.estadoComprobanteEnviado).aceptaComprobante, isFalse);
      expect(const AnticipoReserva(monto: 1, estado: AnticipoReserva.estadoConfirmado).aceptaComprobante, isFalse);
    });

    test('se guarda y se lee completo, con la cuenta copiada', () {
      final original = AnticipoReserva(
        monto: 250.5,
        venceEn: DateTime(2026, 11, 2, 10),
        cuenta: cuenta,
        politicaCancelacion: 'Reembolso 24 h antes',
      );
      final leido = AnticipoReserva.fromMap(original.toMap());
      expect(leido.monto, 250.5);
      expect(leido.venceEn, DateTime(2026, 11, 2, 10));
      expect(leido.cuenta.cuenta, '0123456789');
      expect(leido.politicaCancelacion, 'Reembolso 24 h antes');
    });

    test('la reserva lo conserva al serializarse', () {
      final reserva = ReservationModel.create(
        id: 'r1',
        restauranteId: 'rest',
        fechaLocal: '2026-11-20',
        inicio: DateTime(2026, 11, 20, 20),
        estado: ReservationModel.estadoPendiente,
        anticipo: const AnticipoReserva(monto: 200),
      );
      expect(reserva.esperaAnticipo, isTrue);
      final map = reserva.toMap();
      expect((map['anticipo'] as Map)['monto'], 200);
      final leida = ReservationModel.fromMap('r1', map);
      expect(leida.anticipo?.monto, 200);
      expect(leida.esperaAnticipo, isTrue);
    });

    test('una reserva sin anticipo no lo escribe', () {
      final reserva = ReservationModel.create(
        id: 'r1',
        restauranteId: 'rest',
        fechaLocal: '2026-11-20',
        inicio: DateTime(2026, 11, 20, 20),
      );
      expect(reserva.toMap().containsKey('anticipo'), isFalse);
      expect(reserva.esperaAnticipo, isFalse);
    });

    test('una reserva pendiente por anticipo sigue bloqueando la mesa', () {
      final reserva = ReservationModel.create(
        id: 'r1',
        restauranteId: 'rest',
        fechaLocal: '2026-11-20',
        inicio: DateTime(2026, 11, 20, 20),
        mesaIds: const ['m1'],
        estado: ReservationModel.estadoPendiente,
        anticipo: const AnticipoReserva(monto: 200),
      );
      expect(reserva.bloqueaMesas, isTrue);
    });
  });

  group('Pedido a domicilio o para recoger', () {
    PedidoModel pedido({
      String tipo = PedidoModel.entregaRecoger,
      String estado = PedidoModel.estadoRecibido,
    }) =>
        PedidoModel(id: 'p1', restauranteId: 'r1', tipoEntrega: tipo, estado: estado);

    test('recoger no pasa por "en camino"', () {
      expect(PedidoModel.flujo(PedidoModel.entregaRecoger), [
        PedidoModel.estadoRecibido,
        PedidoModel.estadoPreparando,
        PedidoModel.estadoListo,
        PedidoModel.estadoEntregado,
      ]);
    });

    test('domicilio sí pasa por "en camino"', () {
      expect(PedidoModel.flujo(PedidoModel.entregaDomicilio), contains(PedidoModel.estadoEnCamino));
    });

    test('el siguiente estado sigue el flujo y termina en entregado', () {
      expect(pedido().siguienteEstado, PedidoModel.estadoPreparando);
      expect(pedido(estado: PedidoModel.estadoListo).siguienteEstado, PedidoModel.estadoEntregado);
      expect(
        pedido(tipo: PedidoModel.entregaDomicilio, estado: PedidoModel.estadoListo).siguienteEstado,
        PedidoModel.estadoEnCamino,
      );
      expect(pedido(estado: PedidoModel.estadoEntregado).siguienteEstado, isNull);
      expect(pedido(estado: PedidoModel.estadoCancelado).siguienteEstado, isNull);
    });

    test('las etiquetas dependen de cómo se entrega', () {
      expect(PedidoModel.etiquetaEstado(PedidoModel.estadoListo), 'Listo para recoger');
      expect(
        PedidoModel.etiquetaEstado(PedidoModel.estadoListo, tipoEntrega: PedidoModel.entregaDomicilio),
        'Listo para salir',
      );
    });

    test('se guarda y se lee completo', () {
      final original = PedidoModel(
        id: 'p1',
        restauranteId: 'r1',
        restauranteNombre: 'Casa',
        usuarioId: 'u1',
        contactoNombre: 'Ana',
        contactoTelefono: '5512345678',
        lineas: const [
          PedidoLinea(platilloId: 'a', nombre: 'Taco', precio: 30, cantidad: 3),
        ],
        total: 90,
        tipoEntrega: PedidoModel.entregaDomicilio,
        direccion: 'Calle 1 #2, Centro',
        referencias: 'Portón negro',
        metodoPago: PedidoModel.pagoTransferencia,
        creadoEn: DateTime(2026, 11, 1, 12),
      );
      final leido = PedidoModel.fromMap('p1', original.toMap()
        ..['creadoEn'] = Timestamp.fromDate(DateTime(2026, 11, 1, 12)));
      expect(leido.lineas.single.cantidad, 3);
      expect(leido.total, 90);
      expect(leido.esDomicilio, isTrue);
      expect(leido.direccion, 'Calle 1 #2, Centro');
      expect(leido.esTransferencia, isTrue);
      expect(leido.estadoPago, PedidoModel.pagoPendiente);
    });

    test('para recoger no guarda dirección', () {
      final map = PedidoModel(id: 'p', restauranteId: 'r', direccion: 'Algo').toMap();
      expect((map['entrega'] as Map).containsKey('direccion'), isFalse);
    });
  });

  group('Carrito', () {
    test('suma, quita y calcula el total', () {
      final c = CarritoViewModel();
      final taco = _platillo('taco', 30);
      final agua = _platillo('agua', 20);
      c.agregar(taco);
      c.agregar(taco);
      c.agregar(agua);
      expect(c.totalPlatillos, 3);
      expect(c.total, 80);
      expect(c.cantidadDe('taco'), 2);

      c.quitar('taco');
      expect(c.cantidadDe('taco'), 1);
      c.quitar('taco');
      expect(c.cantidadDe('taco'), 0);
      expect(c.lineas.map((l) => l.platilloId), ['agua']);
    });

    test('limita las unidades por platillo', () {
      final c = CarritoViewModel();
      final taco = _platillo('taco', 10);
      for (var i = 0; i < CarritoViewModel.maxPorPlatillo + 5; i++) {
        c.agregar(taco);
      }
      expect(c.cantidadDe('taco'), CarritoViewModel.maxPorPlatillo);
      c.sumar('taco');
      expect(c.cantidadDe('taco'), CarritoViewModel.maxPorPlatillo);
    });

    test('quitar o sumar algo que no está no hace nada', () {
      final c = CarritoViewModel();
      c.quitar('nada');
      c.sumar('nada');
      expect(c.vacio, isTrue);
    });

    test('limpiar vacía el carrito y avisa', () {
      final c = CarritoViewModel();
      c.agregar(_platillo('a', 10));
      var avisos = 0;
      c.addListener(() => avisos++);
      c.limpiar();
      expect(c.vacio, isTrue);
      expect(avisos, 1);
    });
  });
}
