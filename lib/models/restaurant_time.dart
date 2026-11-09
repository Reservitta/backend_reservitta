/// Hora del restaurante a partir de su zona horaria (HU30-RNF01).
///
/// Evita desfases cuando el dispositivo del administrador está en otra zona: el
/// "hoy" y la hora que se muestran son los del restaurante. Los minutos restantes
/// se calculan entre instantes absolutos, así que no dependen de la zona del
/// dispositivo. Si la zona no se conoce se usa la hora del dispositivo.
class RestaurantTime {
  RestaurantTime._();

  static const String zonaPorDefecto = 'America/Mexico_City';

  /// Zonas sin horario de verano: desfase fijo respecto a UTC, en minutos.
  static const Map<String, int> _fijas = {
    'America/Mexico_City': -360,
    'America/Monterrey': -360,
    'America/Merida': -360,
    'America/Guadalajara': -360,
    'America/Cancun': -300,
    'America/Chihuahua': -360,
    'America/Hermosillo': -420,
    'America/Mazatlan': -420,
    'America/Bogota': -300,
    'America/Lima': -300,
    'America/Guatemala': -360,
    'America/Costa_Rica': -360,
    'America/Panama': -300,
    'America/Argentina/Buenos_Aires': -180,
    'America/Sao_Paulo': -180,
    'America/Santiago': -240,
  };

  /// Zonas con horario de verano de EE. UU. (segundo domingo de marzo a primero de
  /// noviembre): desfase estándar respecto a UTC.
  static const Map<String, int> _estadosUnidos = {
    'America/Tijuana': -480,
    'America/Los_Angeles': -480,
    'America/Denver': -420,
    'America/Chicago': -360,
    'America/New_York': -300,
  };

  /// Zonas con horario de verano europeo: desfase estándar respecto a UTC.
  static const Map<String, int> _europa = {
    'Europe/Madrid': 60,
    'Europe/Paris': 60,
    'Europe/Rome': 60,
    'Europe/Berlin': 60,
    'Europe/Lisbon': 0,
    'Europe/London': 0,
  };

  /// Si la zona está en la tabla de zonas conocidas.
  static bool esConocida(String? zona) {
    final z = (zona ?? '').trim();
    return _fijas.containsKey(z) ||
        _estadosUnidos.containsKey(z) ||
        _europa.containsKey(z);
  }

  /// Desfase de la zona respecto a UTC en el [instante], o null si no se conoce.
  static int? offsetMinutos(String? zona, DateTime instante) {
    final z = (zona ?? '').trim();
    final utc = instante.toUtc();
    if (_fijas.containsKey(z)) return _fijas[z];
    if (_estadosUnidos.containsKey(z)) {
      final estandar = _estadosUnidos[z]!;
      return _horarioVeranoEeuu(utc, estandar) ? estandar + 60 : estandar;
    }
    if (_europa.containsKey(z)) {
      final estandar = _europa[z]!;
      return _horarioVeranoEuropa(utc) ? estandar + 60 : estandar;
    }
    return null;
  }

  static DateTime _nthSunday(int year, int month, int n) {
    var d = DateTime.utc(year, month, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(Duration(days: 7 * (n - 1)));
  }

  static DateTime _lastSunday(int year, int month) {
    var d = DateTime.utc(year, month + 1, 0);
    while (d.weekday != DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  static bool _horarioVeranoEeuu(DateTime utc, int estandarMin) {
    // El cambio ocurre a las 2:00 hora local (estándar al inicio, de verano al final).
    final inicio = _nthSunday(utc.year, 3, 2)
        .add(Duration(hours: 2, minutes: -estandarMin));
    final fin = _nthSunday(utc.year, 11, 1)
        .add(Duration(hours: 2, minutes: -(estandarMin + 60)));
    return !utc.isBefore(inicio) && utc.isBefore(fin);
  }

  static bool _horarioVeranoEuropa(DateTime utc) {
    final inicio = _lastSunday(utc.year, 3).add(const Duration(hours: 1));
    final fin = _lastSunday(utc.year, 10).add(const Duration(hours: 1));
    return !utc.isBefore(inicio) && utc.isBefore(fin);
  }

  /// Fecha y hora de pared del restaurante en el [instante] (solo los componentes,
  /// sin zona). Si la zona no se conoce devuelve la hora local del dispositivo.
  static DateTime ahoraEnRestaurante(String? zona, DateTime instante) {
    final off = offsetMinutos(zona, instante);
    if (off == null) return instante.toLocal();
    final u = instante.toUtc().add(Duration(minutes: off));
    return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
  }

  /// 'YYYY-MM-DD' del día de hoy en el restaurante.
  static String fechaLocalHoy(String? zona, DateTime instante) {
    final d = ahoraEnRestaurante(zona, instante);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
