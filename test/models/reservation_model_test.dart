import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/reservation_model.dart';

void main() {
  group('HU08-RF02 Modelo de reservaciones - Criterios de aceptación', () {
    test('Criterio 1: Colección reservations contiene campos requeridos y estados permitidos', () {
      final inicio = DateTime(2026, 10, 20, 19, 0);
      final fin = DateTime(2026, 10, 20, 20, 30);

      final reserva = ReservationModel(
        id: 'res_001',
        restauranteId: 'rest_el_mexicano',
        usuarioId: 'user_456',
        restauranteNombre: 'El Mexicano',
        contactoNombre: 'Carlos Santana',
        contactoCorreo: 'carlos@example.com',
        contactoTelefono: '555-9876',
        fechaLocal: '2026-10-20',
        inicio: inicio,
        fin: fin,
        duracionMin: 90,
        personas: 4,
        mesaIds: ['mesa_A1', 'mesa_A2'],
        mesasNombres: ['Mesa A1', 'Mesa A2'],
        estado: ReservationModel.estadoConfirmada,
      );

      expect(reserva.restauranteId, 'rest_el_mexicano');
      expect(reserva.mesaIds, ['mesa_A1', 'mesa_A2']);
      expect(reserva.fechaLocal, '2026-10-20');
      expect(reserva.inicio, inicio);
      expect(reserva.fin, fin);
      expect(reserva.personas, 4);
      expect(reserva.cantidadPersonas, 4);
      expect(reserva.estado, 'confirmada');

      // Validar constantes de estado
      expect(ReservationModel.estadosValidos, containsAll(['pendiente', 'confirmada', 'cancelada']));
      expect(ReservationModel.isValidStatus('pendiente'), isTrue);
      expect(ReservationModel.isValidStatus('confirmada'), isTrue);
      expect(ReservationModel.isValidStatus('cancelada'), isTrue);
      expect(ReservationModel.isValidStatus('invalido'), isFalse);

      // Serialización y deserialización
      final map = reserva.toMap();
      expect(map['restauranteId'], 'rest_el_mexicano');
      expect(map['fechaLocal'], '2026-10-20');
      expect(map['personas'], 4);
      expect(map['cantidadPersonas'], 4);
      expect(map['estado'], 'confirmada');

      final fromMap = ReservationModel.fromMap('res_001', map);
      expect(fromMap.restauranteId, 'rest_el_mexicano');
      expect(fromMap.mesaIds, ['mesa_A1', 'mesa_A2']);
      expect(fromMap.fechaLocal, '2026-10-20');
      expect(fromMap.personas, 4);
      expect(fromMap.estado, 'confirmada');
    });

    test('Criterio 2: La hora de fin se calcula como hora de inicio + duración', () {
      final inicio = DateTime(2026, 10, 20, 18, 0);

      // 1. Método estático calculateEndTime con 90 minutos
      final fin90 = ReservationModel.calculateEndTime(inicio: inicio, duracionMin: 90);
      expect(fin90, DateTime(2026, 10, 20, 19, 30));

      // 2. Método estático calculateEndTime con 120 minutos (2 horas)
      final fin120 = ReservationModel.calculateEndTime(inicio: inicio, duracionMin: 120);
      expect(fin120, DateTime(2026, 10, 20, 20, 0));

      // 3. Constructor ReservationModel.create calcula fin automáticamente si es nulo
      final reservaAuto = ReservationModel.create(
        id: 'res_auto',
        restauranteId: 'rest_01',
        fechaLocal: '2026-10-20',
        inicio: inicio,
        duracionMin: 60,
      );
      expect(reservaAuto.fin, DateTime(2026, 10, 20, 19, 0));
      expect(reservaAuto.effectiveEnd, DateTime(2026, 10, 20, 19, 0));

      // 4. fromMap calcula fin a partir de inicio + duracionMin si el campo fin no viene en Firestore
      final rawMap = {
        'restauranteId': 'rest_01',
        'fechaLocal': '2026-10-20',
        'inicio': '2026-10-20T21:00:00.000',
        'duracionMin': 45,
        'personas': 2,
        'estado': 'pendiente',
      };
      final parsed = ReservationModel.fromMap('doc_1', rawMap);
      expect(parsed.fin, DateTime(2026, 10, 20, 21, 45));

      // 5. toMap calcula y persiste fin automáticamente si el modelo no lo tenía explícito
      const reservaSinFin = ReservationModel(
        id: 'doc_2',
        restauranteId: 'rest_01',
        fechaLocal: '2026-10-20',
        duracionMin: 90,
      );
      final mapped = reservaSinFin.toMap();
      // Si inicio es null, fin en mapa queda null
      expect(mapped['fin'], isNull);
    });

    test('Criterio 3: Solo las reservaciones con estado activo (pendiente/confirmada) bloquean mesas', () {
      final inicio = DateTime(2026, 10, 20, 14, 0);
      final fin = DateTime(2026, 10, 20, 15, 30);

      final resPendiente = ReservationModel(
        id: 'res_pen',
        restauranteId: 'rest_01',
        fechaLocal: '2026-10-20',
        inicio: inicio,
        fin: fin,
        duracionMin: 90,
        mesaIds: ['mesa_1'],
        estado: ReservationModel.estadoPendiente,
      );

      final resConfirmada = ReservationModel(
        id: 'res_conf',
        restauranteId: 'rest_01',
        fechaLocal: '2026-10-20',
        inicio: inicio,
        fin: fin,
        duracionMin: 90,
        mesaIds: ['mesa_2'],
        estado: ReservationModel.estadoConfirmada,
      );

      final resCancelada = ReservationModel(
        id: 'res_canc',
        restauranteId: 'rest_01',
        fechaLocal: '2026-10-20',
        inicio: inicio,
        fin: fin,
        duracionMin: 90,
        mesaIds: ['mesa_3'],
        estado: ReservationModel.estadoCancelada,
      );

      // 1. Verificación del getter bloqueaMesas
      expect(resPendiente.bloqueaMesas, isTrue);
      expect(resPendiente.isActiva, isTrue);
      expect(resPendiente.isPendiente, isTrue);

      expect(resConfirmada.bloqueaMesas, isTrue);
      expect(resConfirmada.isActiva, isTrue);
      expect(resConfirmada.isConfirmada, isTrue);

      expect(resCancelada.bloqueaMesas, isFalse);
      expect(resCancelada.isActiva, isFalse);
      expect(resCancelada.isCancelada, isTrue);

      // 2. isTableBlocked: Reservaciones activas bloquean sus mesas en su horario
      final targetHorario = DateTime(2026, 10, 20, 14, 30);
      expect(
        resPendiente.isTableBlocked('mesa_1', targetDateTime: targetHorario),
        isTrue,
      );
      expect(
        resConfirmada.isTableBlocked('mesa_2', targetDateTime: targetHorario),
        isTrue,
      );

      // 3. isTableBlocked: Reservación cancelada NO bloquea su mesa aunque coincida en hora
      expect(
        resCancelada.isTableBlocked('mesa_3', targetDateTime: targetHorario),
        isFalse,
      );

      // 4. No bloquea mesas distintas
      expect(
        resPendiente.isTableBlocked('mesa_99', targetDateTime: targetHorario),
        isFalse,
      );

      // 5. No bloquea en horarios fuera del intervalo
      final targetHorarioLejano = DateTime(2026, 10, 20, 17, 0);
      expect(
        resPendiente.isTableBlocked('mesa_1', targetDateTime: targetHorarioLejano),
        isFalse,
      );

      // 6. anyTableBlocked evalúa listas de mesas
      expect(
        resConfirmada.anyTableBlocked(['mesa_2', 'mesa_8'], targetDateTime: targetHorario),
        isTrue,
      );
      expect(
        resCancelada.anyTableBlocked(['mesa_3'], targetDateTime: targetHorario),
        isFalse,
      );
    });

    test('HU03-RF01 overlapsWith detecta traslapes y respeta estados inactivos', () {
      final resStart = DateTime(2026, 10, 20, 14, 0);
      final resEnd = DateTime(2026, 10, 20, 15, 30);
      final reservation = ReservationModel(
        id: 'res_overlap',
        restauranteId: 'rest_1',
        fechaLocal: '2026-10-20',
        inicio: resStart,
        fin: resEnd,
        duracionMin: 90,
        personas: 2,
        estado: 'confirmada',
      );

      // Caso 1: Consulta a las 14:30 (dentro de la reservación) -> Traslape
      expect(
        reservation.overlapsWith(DateTime(2026, 10, 20, 14, 30), durationMin: 90),
        isTrue,
      );

      // Caso 2: Consulta a las 13:00 con duración 90 min (13:00 a 14:30) -> Traslape
      expect(
        reservation.overlapsWith(DateTime(2026, 10, 20, 13, 0), durationMin: 90),
        isTrue,
      );

      // Caso 3: Consulta a las 12:00 con duración 90 min (12:00 a 13:30) -> No traslape
      expect(
        reservation.overlapsWith(DateTime(2026, 10, 20, 12, 0), durationMin: 90),
        isFalse,
      );

      // Caso 4: Consulta a las 16:00 con duración 90 min (16:00 a 17:30) -> No traslape
      expect(
        reservation.overlapsWith(DateTime(2026, 10, 20, 16, 0), durationMin: 90),
        isFalse,
      );

      // Caso 5: Reservación cancelada -> Nunca se traslapa porque no bloquea
      final resCancelada = reservation.copyWith(estado: ReservationModel.estadoCancelada);
      expect(
        resCancelada.overlapsWith(DateTime(2026, 10, 20, 14, 30)),
        isFalse,
      );
    });
  });
}

