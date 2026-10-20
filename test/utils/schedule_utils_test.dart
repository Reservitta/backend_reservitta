import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/utils/schedule_utils.dart';

void main() {
  group('HU03-RF01 ScheduleUtils: Validación de horarios y aperturas', () {
    test('dayOfWeekToName mapea correctamente los números de día de DateTime', () {
      expect(ScheduleUtils.dayOfWeekToName(DateTime.monday), 'lunes');
      expect(ScheduleUtils.dayOfWeekToName(DateTime.tuesday), 'martes');
      expect(ScheduleUtils.dayOfWeekToName(DateTime.wednesday), 'miercoles');
      expect(ScheduleUtils.dayOfWeekToName(DateTime.thursday), 'jueves');
      expect(ScheduleUtils.dayOfWeekToName(DateTime.friday), 'viernes');
      expect(ScheduleUtils.dayOfWeekToName(DateTime.saturday), 'sabado');
      expect(ScheduleUtils.dayOfWeekToName(DateTime.sunday), 'domingo');
    });

    test('normalizeDayName remueve acentos, mayúsculas y espacios', () {
      expect(ScheduleUtils.normalizeDayName('  MiÉrCoLeS  '), 'miercoles');
      expect(ScheduleUtils.normalizeDayName('SÁBADO'), 'sabado');
      expect(ScheduleUtils.normalizeDayName('domingo'), 'domingo');
    });

    test('parseTimeToMinutes convierte HH:mm a minutos totales y valida límites', () {
      expect(ScheduleUtils.parseTimeToMinutes('00:00'), 0);
      expect(ScheduleUtils.parseTimeToMinutes('09:30'), 570);
      expect(ScheduleUtils.parseTimeToMinutes('13:45'), 825);
      expect(ScheduleUtils.parseTimeToMinutes('23:59'), 1439);

      // Inválidos
      expect(ScheduleUtils.parseTimeToMinutes(null), isNull);
      expect(ScheduleUtils.parseTimeToMinutes(''), isNull);
      expect(ScheduleUtils.parseTimeToMinutes('hora:invalida'), isNull);
      expect(ScheduleUtils.parseTimeToMinutes('25:00'), isNull);
      expect(ScheduleUtils.parseTimeToMinutes('12:65'), isNull);
    });

    test('isTimeWithinSchedule valida horarios diurnos regulares', () {
      // 12:00 (720 min) a 22:00 (1320 min)
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '12:00',
          cierre: '22:00',
          targetMinutes: 719,
        ),
        isFalse,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '12:00',
          cierre: '22:00',
          targetMinutes: 720,
        ),
        isTrue,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '12:00',
          cierre: '22:00',
          targetMinutes: 900,
        ),
        isTrue,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '12:00',
          cierre: '22:00',
          targetMinutes: 1320,
        ),
        isTrue,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '12:00',
          cierre: '22:00',
          targetMinutes: 1321,
        ),
        isFalse,
      );
    });

    test('isTimeWithinSchedule valida horarios nocturnos que cruzan la medianoche', () {
      // 18:00 (1080 min) a 02:00 (120 min)
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '18:00',
          cierre: '02:00',
          targetMinutes: 1079, // 17:59
        ),
        isFalse,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '18:00',
          cierre: '02:00',
          targetMinutes: 1080, // 18:00
        ),
        isTrue,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '18:00',
          cierre: '02:00',
          targetMinutes: 1410, // 23:30
        ),
        isTrue,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '18:00',
          cierre: '02:00',
          targetMinutes: 60, // 01:00
        ),
        isTrue,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '18:00',
          cierre: '02:00',
          targetMinutes: 120, // 02:00
        ),
        isTrue,
      );
      expect(
        ScheduleUtils.isTimeWithinSchedule(
          apertura: '18:00',
          cierre: '02:00',
          targetMinutes: 125, // 02:05
        ),
        isFalse,
      );
    });

    test('isSpecialClosureDate detecta correctamente fechas de cierre especial (Criterio 4)', () {
      final closures = ['2026-12-25', '2026-01-01', '15/09/2026'];

      // Fecha en lista
      final christmas = DateTime(2026, 12, 25, 14, 0);
      expect(
        ScheduleUtils.isSpecialClosureDate(
          cierresEspeciales: closures,
          dateTime: christmas,
        ),
        isTrue,
      );

      // Fecha no en lista
      final normalDay = DateTime(2026, 12, 24, 14, 0);
      expect(
        ScheduleUtils.isSpecialClosureDate(
          cierresEspeciales: closures,
          dateTime: normalDay,
        ),
        isFalse,
      );

      // Fecha formato alterno
      final independenceDay = DateTime(2026, 9, 15, 20, 0);
      expect(
        ScheduleUtils.isSpecialClosureDate(
          cierresEspeciales: closures,
          dateTime: independenceDay,
        ),
        isTrue,
      );
    });

    test('isRestaurantOpenAt verifica integralmente estado, cierres, días y horarios', () {
      final restaurant = RestaurantModel(
        id: 'rest_1',
        nombre: 'Bistró Central',
        estado: 'activo',
        diasAbiertos: ['lunes', 'miercoles', 'viernes'],
        horarios: {
          'lunes': const DaySchedule(abierto: true, apertura: '13:00', cierre: '22:00'),
          'miercoles': const DaySchedule(abierto: true, apertura: '13:00', cierre: '22:00'),
          'viernes': const DaySchedule(abierto: true, apertura: '14:00', cierre: '23:30'),
        },
        cierresEspeciales: ['2026-11-20'],
      );

      // 1. Lunes a las 15:00 -> Abierto
      // 2026-10-19 fue Lunes
      final lunesAbierto = DateTime(2026, 10, 19, 15, 0);
      expect(
        ScheduleUtils.isRestaurantOpenAt(
          restaurant: restaurant,
          dateTime: lunesAbierto,
        ),
        isTrue,
      );

      // 2. Lunes a las 11:00 -> Cerrado (antes de apertura)
      final lunesTemprano = DateTime(2026, 10, 19, 11, 0);
      expect(
        ScheduleUtils.isRestaurantOpenAt(
          restaurant: restaurant,
          dateTime: lunesTemprano,
        ),
        isFalse,
      );

      // 3. Martes -> Cerrado (no está en diasAbiertos)
      // 2026-10-20 fue Martes
      final martesCerrado = DateTime(2026, 10, 20, 15, 0);
      expect(
        ScheduleUtils.isRestaurantOpenAt(
          restaurant: restaurant,
          dateTime: martesCerrado,
        ),
        isFalse,
      );

      // 4. Día de cierre especial -> Cerrado (Criterio 4)
      // 2026-11-20 es Viernes, pero tiene cierre especial
      final viernesCierreEspecial = DateTime(2026, 11, 20, 15, 0);
      expect(
        ScheduleUtils.isRestaurantOpenAt(
          restaurant: restaurant,
          dateTime: viernesCierreEspecial,
        ),
        isFalse,
      );

      // 5. Restaurante inactivo -> Siempre cerrado
      final inactivo = restaurant.copyWith(estado: 'inactivo');
      expect(
        ScheduleUtils.isRestaurantOpenAt(
          restaurant: inactivo,
          dateTime: lunesAbierto,
        ),
        isFalse,
      );
    });
  });
}
