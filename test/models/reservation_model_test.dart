import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/reservation_model.dart';

void main() {
  group('HU03-RF01 ReservationModel: Serialización y detección de traslapes', () {
    test('ReservationModel serializa y deserializa correctamente desde Map', () {
      final now = DateTime(2026, 10, 20, 14, 0);
      final model = ReservationModel(
        id: 'res_123',
        restauranteId: 'rest_01',
        usuarioId: 'user_01',
        restauranteNombre: 'Café Del Sol',
        contactoNombre: 'Laura Gómez',
        contactoCorreo: 'laura@example.com',
        contactoTelefono: '555-1234',
        fechaLocal: '2026-10-20',
        inicio: now,
        fin: now.add(const Duration(minutes: 90)),
        duracionMin: 90,
        personas: 4,
        mesaIds: ['mesa_1', 'mesa_2'],
        mesasNombres: ['Mesa 1', 'Mesa 2'],
        estado: 'confirmada',
      );

      final map = model.toMap();
      expect(map['restauranteId'], 'rest_01');
      expect(map['personas'], 4);
      expect(map['estado'], 'confirmada');

      final deserialized = ReservationModel.fromMap('res_123', map);
      expect(deserialized.id, 'res_123');
      expect(deserialized.restauranteId, 'rest_01');
      expect(deserialized.contactoNombre, 'Laura Gómez');
      expect(deserialized.personas, 4);
      expect(deserialized.isActiva, isTrue);
    });

    test('isActiva retorna falso para reservaciones canceladas, rechazadas o expiradas', () {
      const confirmada = ReservationModel(
        id: '1',
        restauranteId: 'r1',
        fechaLocal: '2026-10-20',
        estado: 'confirmada',
      );
      const cancelada = ReservationModel(
        id: '2',
        restauranteId: 'r1',
        fechaLocal: '2026-10-20',
        estado: 'cancelada',
      );
      const rechazada = ReservationModel(
        id: '3',
        restauranteId: 'r1',
        fechaLocal: '2026-10-20',
        estado: 'rechazada',
      );
      const noAsistio = ReservationModel(
        id: '4',
        restauranteId: 'r1',
        fechaLocal: '2026-10-20',
        estado: 'no_asistio',
      );

      expect(confirmada.isActiva, isTrue);
      expect(cancelada.isActiva, isFalse);
      expect(rechazada.isActiva, isFalse);
      expect(noAsistio.isActiva, isFalse);
    });

    test('overlapsWith detecta correctamente traslapes entre reservaciones y ventanas de tiempo', () {
      // Reservación de 14:00 a 15:30 (90 min)
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

      // Caso 1: Consulta a las 14:30 (coincide dentro de la reservación) -> Traslape
      expect(
        reservation.overlapsWith(DateTime(2026, 10, 20, 14, 30), durationMin: 90),
        isTrue,
      );

      // Caso 2: Consulta a las 13:00 con duración 90 min (13:00 a 14:30) -> Traslape
      expect(
        reservation.overlapsWith(DateTime(2026, 10, 20, 13, 0), durationMin: 90),
        isTrue,
      );

      // Caso 3: Consulta a las 12:00 con duración 90 min (12:00 a 13:30) -> No traslape (termina antes)
      expect(
        reservation.overlapsWith(DateTime(2026, 10, 20, 12, 0), durationMin: 90),
        isFalse,
      );

      // Caso 4: Consulta a las 16:00 con duración 90 min (16:00 a 17:30) -> No traslape (inicia después)
      expect(
        reservation.overlapsWith(DateTime(2026, 10, 20, 16, 0), durationMin: 90),
        isFalse,
      );

      // Caso 5: Reservación cancelada -> Nunca se traslapa porque no ocupa lugar
      final resCancelada = reservation.copyWith(estado: 'cancelada');
      expect(
        resCancelada.overlapsWith(DateTime(2026, 10, 20, 14, 30)),
        isFalse,
      );
    });
  });
}
