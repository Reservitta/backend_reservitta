import 'restaurant_time.dart';

/// Ajustes operativos del restaurante usados por las alertas de llegada (HU30) y los
/// recordatorios (HU21). Viven en `restaurants/{id}.configuracion`.
class OperationsConfig {
  static const int umbralAlertaPorDefecto = 30;
  static const int recordatorioPorDefecto = 120;

  /// Anticipaciones que el administrador puede elegir para la alerta de llegada.
  static const List<int> umbralesPermitidos = [10, 15, 20, 30, 45, 60];

  /// Si se activan las alertas de llegada (HU30-RF03: se pueden desactivar).
  final bool alertasActivas;

  /// Minutos antes de la hora de la reserva en que se genera la alerta (HU30-RF01).
  final int umbralAlertaMin;

  /// Minutos antes de la reserva en que se envía el recordatorio (HU21-RF01).
  final int recordatorioMin;

  /// Si la reserva se hace con menos anticipación que el recordatorio: true lo envía
  /// de inmediato, false (por defecto) no lo envía.
  final bool recordatorioTardioInmediato;

  /// Zona horaria IANA del restaurante (HU30-RNF01).
  final String zonaHoraria;

  const OperationsConfig({
    this.alertasActivas = true,
    this.umbralAlertaMin = umbralAlertaPorDefecto,
    this.recordatorioMin = recordatorioPorDefecto,
    this.recordatorioTardioInmediato = false,
    this.zonaHoraria = RestaurantTime.zonaPorDefecto,
  });

  /// Lee los ajustes del documento del restaurante; lo que falte toma el valor por defecto.
  factory OperationsConfig.fromRestaurantData(Map<String, dynamic>? data) {
    final conf = data?['configuracion'];
    final c = conf is Map
        ? Map<String, dynamic>.from(conf)
        : const <String, dynamic>{};
    final umbral = (c['umbralAlertaMin'] as num?)?.toInt();
    final recordatorio = (c['recordatorioMin'] as num?)?.toInt();
    final zona = data?['zonaHoraria'];
    return OperationsConfig(
      alertasActivas: c['alertasActivas'] as bool? ?? true,
      umbralAlertaMin:
          umbral != null && umbral > 0 ? umbral : umbralAlertaPorDefecto,
      recordatorioMin: recordatorio != null && recordatorio > 0
          ? recordatorio
          : recordatorioPorDefecto,
      recordatorioTardioInmediato:
          c['recordatorioTardioInmediato'] as bool? ?? false,
      zonaHoraria: zona is String && zona.trim().isNotEmpty
          ? zona.trim()
          : RestaurantTime.zonaPorDefecto,
    );
  }

  OperationsConfig copyWith({
    bool? alertasActivas,
    int? umbralAlertaMin,
    int? recordatorioMin,
    bool? recordatorioTardioInmediato,
    String? zonaHoraria,
  }) {
    return OperationsConfig(
      alertasActivas: alertasActivas ?? this.alertasActivas,
      umbralAlertaMin: umbralAlertaMin ?? this.umbralAlertaMin,
      recordatorioMin: recordatorioMin ?? this.recordatorioMin,
      recordatorioTardioInmediato:
          recordatorioTardioInmediato ?? this.recordatorioTardioInmediato,
      zonaHoraria: zonaHoraria ?? this.zonaHoraria,
    );
  }

  /// Texto de la anticipación del recordatorio: "2 horas", "1 hora", "45 minutos".
  String get textoRecordatorio => textoAnticipacion(recordatorioMin);

  static String textoAnticipacion(int minutos) {
    if (minutos >= 60 && minutos % 60 == 0) {
      final h = minutos ~/ 60;
      return h == 1 ? '1 hora' : '$h horas';
    }
    if (minutos > 60) {
      final h = minutos ~/ 60;
      final m = minutos % 60;
      return '${h == 1 ? '1 hora' : '$h horas'} y $m minutos';
    }
    return minutos == 1 ? '1 minuto' : '$minutos minutos';
  }
}
