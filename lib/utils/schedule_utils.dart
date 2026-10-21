import '../models/restaurant_model.dart';

/// Utilidades de horarios, fechas y validación de apertura de restaurantes (HU03-RF01)
class ScheduleUtils {
  /// Lista canónica de días de la semana en español
  static const List<String> standardDays = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];

  /// Mapeo de número de día de DateTime.weekday (1=lunes ... 7=domingo) a nombre canónico
  static String dayOfWeekToName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'lunes';
      case DateTime.tuesday:
        return 'martes';
      case DateTime.wednesday:
        return 'miercoles';
      case DateTime.thursday:
        return 'jueves';
      case DateTime.friday:
        return 'viernes';
      case DateTime.saturday:
        return 'sabado';
      case DateTime.sunday:
        return 'domingo';
      default:
        return 'lunes';
    }
  }

  /// Normaliza una cadena de nombre de día: elimina acentos, espacios y pasa a minúsculas
  static String normalizeDayName(String day) {
    var clean = day.trim().toLowerCase();
    clean = clean.replaceAll('á', 'a');
    clean = clean.replaceAll('é', 'e');
    clean = clean.replaceAll('í', 'i');
    clean = clean.replaceAll('ó', 'o');
    clean = clean.replaceAll('ú', 'u');
    return clean;
  }

  /// Convierte una cadena de hora "HH:mm" a minutos totales desde la medianoche [0..1439]
  static int? parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;

    final trimmed = timeStr.trim();
    final parts = trimmed.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return hour * 60 + minute;
  }

  /// Determina si un minuto específico del día está dentro del rango [apertura, cierre].
  /// Soporta tanto horarios regulares (ej. 12:00 a 22:00) como horarios nocturnos que cruzan la medianoche (ej. 18:00 a 02:00).
  static bool isTimeWithinSchedule({
    required String apertura,
    required String cierre,
    required int targetMinutes,
  }) {
    final apMin = parseTimeToMinutes(apertura);
    final ciMin = parseTimeToMinutes(cierre);
    if (apMin == null || ciMin == null) return false;

    if (ciMin > apMin) {
      // Horario regular del mismo día
      return targetMinutes >= apMin && targetMinutes <= ciMin;
    } else if (ciMin < apMin) {
      // Horario nocturno que cruza la medianoche (ej. apertura 18:00, cierre 02:00)
      return targetMinutes >= apMin || targetMinutes <= ciMin;
    } else {
      // Apertura == Cierre: si es 00:00 - 00:00 se interpreta como abierto 24 horas
      if (apMin == 0 && ciMin == 0) return true;
      return targetMinutes == apMin;
    }
  }

  /// Determina si una fecha específica coincide con los días de cierre especial (Criterio 4).
  /// Soporta formatos 'YYYY-MM-DD', 'YYYY/MM/DD', 'DD-MM-YYYY', 'DD/MM/YYYY'.
  static bool isSpecialClosureDate({
    required List<String> cierresEspeciales,
    required DateTime dateTime,
  }) {
    if (cierresEspeciales.isEmpty) return false;

    final yearStr = dateTime.year.toString().padLeft(4, '0');
    final monthStr = dateTime.month.toString().padLeft(2, '0');
    final dayStr = dateTime.day.toString().padLeft(2, '0');

    final isoDate = '$yearStr-$monthStr-$dayStr';
    final altIsoDate = '$yearStr/$monthStr/$dayStr';
    final latDate = '$dayStr-$monthStr-$yearStr';
    final altLatDate = '$dayStr/$monthStr/$yearStr';

    for (final closure in cierresEspeciales) {
      final clean = closure.trim();
      if (clean == isoDate ||
          clean == altIsoDate ||
          clean == latDate ||
          clean == altLatDate) {
        return true;
      }
      // Intento de parseo directo como DateTime
      final parsed = DateTime.tryParse(clean);
      if (parsed != null &&
          parsed.year == dateTime.year &&
          parsed.month == dateTime.month &&
          parsed.day == dateTime.day) {
        return true;
      }
    }
    return false;
  }

  /// Verifica si un restaurante está abierto en una fecha y hora determinada (Criterios 1, 2 y 4).
  /// 1. Debe estar activo.
  /// 2. No debe estar en día de cierre especial.
  /// 3. El día debe estar en diasAbiertos.
  /// 4. El horario del día debe estar marcado como abierto y la hora dentro de [apertura, cierre].
  static bool isRestaurantOpenAt({
    required RestaurantModel restaurant,
    required DateTime dateTime,
  }) {
    // 1. Debe estar en estado 'activo'
    if (!restaurant.isActivo) return false;

    // 2. Respetar días de cierre especial (Criterio 4)
    if (isSpecialClosureDate(
      cierresEspeciales: restaurant.cierresEspeciales,
      dateTime: dateTime,
    )) {
      return false;
    }

    // 3. Obtener día canónico correspondiente a la fecha
    final currentDayCanonical = dayOfWeekToName(dateTime.weekday);

    // 4. Verificar si el día está en diasAbiertos
    final normalizedDiasAbiertos =
        restaurant.diasAbiertos.map(normalizeDayName).toSet();

    if (restaurant.diasAbiertos.isNotEmpty &&
        !normalizedDiasAbiertos.contains(currentDayCanonical)) {
      return false;
    }

    // 5. Verificar horario específico del día en el mapa de horarios
    DaySchedule? schedule;
    for (final entry in restaurant.horarios.entries) {
      if (normalizeDayName(entry.key) == currentDayCanonical) {
        schedule = entry.value;
        break;
      }
    }

    // Si no tiene horario guardado para ese día o está marcado como cerrado
    if (schedule == null || !schedule.abierto) {
      return false;
    }

    // 6. Verificar si la hora objetivo cae dentro de la ventana de apertura y cierre
    final targetMinutes = dateTime.hour * 60 + dateTime.minute;
    return isTimeWithinSchedule(
      apertura: schedule.apertura,
      cierre: schedule.cierre,
      targetMinutes: targetMinutes,
    );
  }

  /// Formatea un DateTime a cadena estándar 'YYYY-MM-DD' para consultas locales
  static String formatDateLocal(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Formatea hora y minuto a cadena estándar 'HH:mm'
  static String formatTimeHHmm(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
