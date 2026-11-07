import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/reservation_detail.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/reservation_status_flow.dart';
import 'package:reservitta/services/reservation_service.dart';

ReservationModel _reserva({
  String id = '',
  String estado = ReservationModel.estadoConfirmada,
  List<Map<String, dynamic>> preorden = const [],
  List<String> alergias = const [],
  String notas = '',
  Map<String, dynamic>? ocasion,
  List<Map<String, dynamic>> experiencias = const [],
  String nombre = 'Carlos',
}) {
  return ReservationModel.create(
    id: id,
    restauranteId: 'r1',
    usuarioId: 'u1',
    restauranteNombre: 'Miel Test',
    contactoNombre: nombre,
    contactoCorreo: nombre.isEmpty ? '' : 'carlos@test.com',
    contactoTelefono: nombre.isEmpty ? '' : '4181234567',
    fechaLocal: '2026-10-30',
    inicio: DateTime(2026, 10, 30, 14),
    duracionMin: 90,
    personas: 4,
    mesaIds: const ['m1'],
    mesasNombres: const ['M1'],
    estado: estado,
    preordenItems: preorden,
    alergias: alergias,
    notasAlergias: notas,
    ocasionEspecial: ocasion,
    experiencias: experiencias,
  );
}

Map<String, dynamic> _linea(String id, String nombre, String categoria,
        {String obs = '', int cant = 1, double precio = 100}) =>
    {
      'platilloId': id,
      'nombre': nombre,
      'categoria': categoria,
      'precio': precio,
      'cantidad': cant,
      'total': precio * cant,
      'observacion': obs,
    };

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  group('HU27-RF01 máquina de estados', () {
    test('los estados operativos válidos son los seis del backlog', () {
      expect(ReservationStateMachine.estados, [
        'pendiente_llegada',
        'cliente_llego',
        'en_servicio',
        'finalizada',
        'cancelada',
        'no_show',
      ]);
    });

    test('el flujo normal avanza paso a paso', () {
      expect(ReservationStateMachine.siguientes('pendiente_llegada'),
          ['cliente_llego', 'cancelada', 'no_show']);
      expect(ReservationStateMachine.siguientes('cliente_llego'),
          ['en_servicio', 'cancelada']);
      expect(ReservationStateMachine.siguientes('en_servicio'), ['finalizada']);
    });

    test('finalizada, cancelada y no-show son estados finales', () {
      for (final e in ['finalizada', 'cancelada', 'no_show']) {
        expect(ReservationStateMachine.esFinal(e), isTrue, reason: e);
        expect(ReservationStateMachine.siguientes(e), isEmpty);
      }
    });

    test('no se puede pasar de finalizada a pendiente de llegada', () {
      expect(
        ReservationStateMachine.validar('finalizada', 'pendiente_llegada'),
        contains('ya no puede cambiar de estado'),
      );
    });

    test('una transición inválida se rechaza con un mensaje claro', () {
      expect(
        ReservationStateMachine.validar('pendiente_llegada', 'en_servicio'),
        'No se puede pasar de "Pendiente de llegada" a "En servicio".',
      );
      expect(
        () => ReservationStateMachine.exigirValida('en_servicio', 'cancelada'),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('pendiente y confirmada cuentan como pendiente de llegada', () {
      expect(ReservationStateMachine.normalizar('confirmada'), 'pendiente_llegada');
      expect(ReservationStateMachine.normalizar('pendiente'), 'pendiente_llegada');
      expect(ReservationStateMachine.puedeTransicionar('confirmada', 'cliente_llego'), isTrue);
    });

    test('mismo estado o estado desconocido se rechazan', () {
      expect(ReservationStateMachine.validar('cliente_llego', 'cliente_llego'),
          contains('ya está en'));
      expect(ReservationStateMachine.validar('cliente_llego', 'volando'),
          contains('no es válido'));
    });

    test('cancelar y no-show piden confirmación; finalizar libera la mesa', () {
      expect(ReservationStateMachine.requiereConfirmacion('cancelada'), isTrue);
      expect(ReservationStateMachine.requiereConfirmacion('no_show'), isTrue);
      expect(ReservationStateMachine.requiereConfirmacion('cliente_llego'), isFalse);
      expect(ReservationStateMachine.liberaMesa('finalizada'), isTrue);
      expect(ReservationStateMachine.liberaMesa('en_servicio'), isFalse);
    });

    test('el modelo reconoce los estados nuevos', () {
      expect(ReservationModel.normalizeStatus('No-Show'), 'no_show');
      expect(ReservationModel.normalizeStatus('Finalizada'), 'finalizada');
      final fin = _reserva(estado: 'finalizada');
      expect(fin.isFinalizada, isTrue);
      expect(fin.etiquetaEstado, 'Finalizada');
      expect(fin.bloqueaMesas, isFalse);
      final ns = _reserva(estado: 'no_show');
      expect(ns.isNoShow, isTrue);
      expect(ns.etiquetaEstado, 'No se presentó');
      expect(ns.bloqueaMesas, isFalse);
      expect(_reserva(estado: 'en_servicio').bloqueaMesas, isTrue);
      expect(fin.matchesEstadoFiltro('finalizada'), isTrue);
      expect(fin.matchesEstadoFiltro('no_show'), isFalse);
    });
  });

  group('HU27-RF01 cambio de estado con trazabilidad', () {
    late FakeFirebaseFirestore db;
    late ReservationService repo;
    final ahora = DateTime(2026, 10, 30, 13, 55);

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = ReservationService(firestore: db);
    });

    Future<String> crear() async {
      final r = await repo.createReservationVerified(_reserva());
      return r.id;
    }

    test('registra quién cambió el estado y cuándo', () async {
      final id = await crear();
      final r = await repo.changeOperationalState(
        reservationId: id,
        nuevoEstado: 'cliente_llego',
        usuarioId: 'admin_7',
        ahora: ahora,
      );
      expect(r.estadoOperativo, 'cliente_llego');

      final leida = (await repo.getReservationById(id))!;
      expect(leida.estado, 'cliente_llego');
      expect(leida.estadoActualizadoPor, 'admin_7');
      expect(leida.estadoActualizadoEn, ahora);
    });

    test('guarda el historial de cambios en orden', () async {
      final id = await crear();
      await repo.changeOperationalState(
          reservationId: id, nuevoEstado: 'cliente_llego', usuarioId: 'a1', ahora: ahora);
      await repo.changeOperationalState(
          reservationId: id,
          nuevoEstado: 'en_servicio',
          usuarioId: 'a2',
          ahora: ahora.add(const Duration(minutes: 10)));
      final leida = (await repo.getReservationById(id))!;
      expect(leida.historialEstados.map((h) => '${h['de']}>${h['a']}>${h['por']}'), [
        'pendiente_llegada>cliente_llego>a1',
        'cliente_llego>en_servicio>a2',
      ]);
    });

    test('una transición inválida se rechaza y no cambia nada', () async {
      final id = await crear();
      await expectLater(
        repo.changeOperationalState(
            reservationId: id, nuevoEstado: 'finalizada', usuarioId: 'a1'),
        throwsA(isA<InvalidStateTransitionException>().having(
            (e) => e.message, 'message', contains('No se puede pasar de'))),
      );
      final leida = (await repo.getReservationById(id))!;
      expect(leida.estadoOperativo, 'pendiente_llegada');
      expect(leida.historialEstados, isEmpty);
    });

    test('cancelar libera la mesa para reservarla de nuevo', () async {
      final id = await crear();
      await expectLater(
        repo.createReservationVerified(_reserva()),
        throwsA(isA<ReservationConflictException>()),
      );
      await repo.changeOperationalState(
          reservationId: id, nuevoEstado: 'cancelada', usuarioId: 'a1');
      await repo.createReservationVerified(_reserva());
    });

    test('no-show y finalizada también liberan la mesa', () async {
      final id = await crear();
      await repo.changeOperationalState(
          reservationId: id, nuevoEstado: 'no_show', usuarioId: 'a1');
      final otro = await repo.createReservationVerified(_reserva());
      await repo.changeOperationalState(
          reservationId: otro.id, nuevoEstado: 'cliente_llego', usuarioId: 'a1');
      await repo.changeOperationalState(
          reservationId: otro.id, nuevoEstado: 'en_servicio', usuarioId: 'a1');
      await repo.changeOperationalState(
          reservationId: otro.id, nuevoEstado: 'finalizada', usuarioId: 'a1');
      await repo.createReservationVerified(_reserva());
    });

    test('mientras está en servicio la mesa sigue ocupada', () async {
      final id = await crear();
      await repo.changeOperationalState(
          reservationId: id, nuevoEstado: 'cliente_llego', usuarioId: 'a1');
      await repo.changeOperationalState(
          reservationId: id, nuevoEstado: 'en_servicio', usuarioId: 'a1');
      await expectLater(
        repo.createReservationVerified(_reserva()),
        throwsA(isA<ReservationConflictException>()),
      );
    });

    test('una reserva inexistente avisa con un error', () async {
      await expectLater(
        repo.changeOperationalState(
            reservationId: 'nope', nuevoEstado: 'cancelada', usuarioId: 'a1'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('HU28-RF01 detalle completo de la reserva', () {
    test('devuelve cliente, fecha, mesas, platillos con notas, alergias y ocasión',
        () {
      final d = ReservationDetail.fromReservation(_reserva(
        preorden: [
          _linea('p1', 'Ensalada', 'Entrada'),
          _linea('p2', 'Filete', 'Plato fuerte', obs: 'término medio', cant: 2),
          _linea('p3', 'Pastel', 'Postre'),
        ],
        alergias: ['Nueces'],
        notas: 'Una persona celíaca',
        ocasion: {'ocasionId': 'o1', 'nombre': 'Cumpleaños'},
        experiencias: [
          {'nombre': 'Postre con felicitación', 'precio': 0.0, 'esGratis': true, 'mensajeFelicitacion': 'Feliz cumple Ana'},
        ],
      ));
      expect(d.clienteNombre, 'Carlos');
      expect(d.clienteCorreo, 'carlos@test.com');
      expect(d.fechaLocal, '2026-10-30');
      expect(d.horario, '14:00 – 15:30');
      expect(d.mesasTexto, 'M1');
      expect(d.personas, 4);
      expect(d.platillosPorGrupo.keys, ['Entrada', 'Plato fuerte', 'Postre']);
      final filete = d.platillosPorGrupo['Plato fuerte']!.single;
      expect(filete.nombre, 'Filete');
      expect(filete.cantidad, 2);
      expect(filete.nota, 'término medio');
      expect(d.alergias, ['Nueces']);
      expect(d.resumenAlergias, 'Nueces · Una persona celíaca');
      expect(d.observacionesPorPlatillo, ['Filete: término medio']);
      expect(d.esOcasionEspecial, isTrue);
      expect(d.resumenOcasion, 'Cumpleaños');
      expect(d.experiencias.single.mensajeFelicitacion, 'Feliz cumple Ana');
      expect(d.experiencias.single.precioFormateado, 'Gratis');
      expect(d.resumenPreorden, '4 platillos');
    });

    test('lo que no se indicó aparece como "No indicado" sin errores', () {
      final d = ReservationDetail.fromReservation(_reserva(nombre: ''));
      expect(d.clienteNombre, 'No indicado');
      expect(d.clienteCorreo, 'No indicado');
      expect(d.clienteTelefono, 'No indicado');
      expect(d.resumenPreorden, 'No indicado');
      expect(d.resumenAlergias, 'No indicado');
      expect(d.resumenOcasion, 'No indicado');
      expect(d.platillosPorGrupo, isEmpty);
      expect(d.tienePreorden, isFalse);
      expect(d.tieneAlergias, isFalse);
      expect(d.esOcasionEspecial, isFalse);
    });

    test('la ocasión "Otro" muestra lo que cuenta el visitante', () {
      final d = ReservationDetail.fromReservation(_reserva(
        ocasion: {'nombre': 'Otro', 'detalle': 'Ascenso de Luis'},
      ));
      expect(d.resumenOcasion, 'Otro: Ascenso de Luis');
    });

    test('se resuelve la categoría por id cuando el platillo no la trae', () {
      final d = ReservationDetail.fromReservation(
        _reserva(preorden: [
          {'platilloId': 'p9', 'nombre': 'Sopa', 'cantidad': 1, 'precio': 80.0, 'categoriaId': 'c1'},
        ]),
        categoriasPorId: {'c1': 'Entrada'},
      );
      expect(d.platillosPorGrupo.keys, ['Entrada']);
    });

    test('el servicio devuelve el detalle por id y null si no existe', () async {
      final db = FakeFirebaseFirestore();
      final repo = ReservationService(firestore: db);
      final r = await repo.createReservationVerified(_reserva(
        preorden: [_linea('p2', 'Filete', 'Plato fuerte', obs: 'sin sal')],
      ));
      final d = await repo.getReservationDetail(r.id);
      expect(d, isNotNull);
      expect(d!.platillosPorGrupo['Plato fuerte']!.single.nota, 'sin sal');
      expect(await repo.getReservationDetail('no_existe'), isNull);
    });
  });
}
