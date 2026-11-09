import 'operations_config.dart';
import 'reservation_model.dart';
import 'restaurant_time.dart';

/// Tipo de alerta de llegada (HU30-RF01).
enum TipoAlertaLlegada {
  /// Falta poco para la hora de la reserva.
  proxima,

  /// Ya pasó la hora y el cliente no llega: posible no-show.
  retraso,
}

/// Alerta de llegada de una reserva "pendiente de llegada" (HU30-RF01).
class ArrivalAlert {
  final ReservationModel reserva;
  final TipoAlertaLlegada tipo;

  /// Minutos que faltan para la hora de la reserva; si es un retraso, los minutos
  /// que pasaron desde la hora (siempre positivo, ver [tipo]).
  final int minutos;

  /// Umbral con el que se generó la alerta.
  final int umbralMin;

  const ArrivalAlert({
    required this.reserva,
    required this.tipo,
    required this.minutos,
    required this.umbralMin,
  });

  bool get esRetraso => tipo == TipoAlertaLlegada.retraso;

  /// Texto corto para el listado: "Llega en 12 min", "Es ahora", "Tarde 7 min".
  String get texto {
    if (esRetraso) return 'Tarde $minutos min';
    if (minutos <= 0) return 'Es ahora';
    return 'Llega en $minutos min';
  }

  /// Clave única por reserva, tipo y umbral: evita avisar dos veces lo mismo (HU30-RNF02).
  String get clave => '${reserva.id}_${tipo.name}_$umbralMin';

  /// El pedido ya está listo antes de que el cliente llegue (HU29-RF03).
  bool get pedidoListo =>
      reserva.tienePreorden &&
      ReservationModel.normalizePreordenStatus(reserva.estadoPreorden) ==
          ReservationModel.preordenListo;

  /// Tiene preorden que todavía hay que preparar.
  bool get pedidoPorPreparar => reserva.tienePreorden && !pedidoListo;
}

/// Calcula las alertas de llegada del día (HU30-RF01).
class ArrivalAlertCalculator {
  ArrivalAlertCalculator._();

  /// Alertas de las [reservas] en el instante [ahora].
  ///
  /// - Solo reservas "pendiente de llegada" (si el cliente llegó o se canceló, la
  ///   alerta se desactiva).
  /// - Solo las del día de hoy en la zona horaria del restaurante.
  /// - Es [TipoAlertaLlegada.proxima] cuando faltan [OperationsConfig.umbralAlertaMin]
  ///   minutos o menos, y [TipoAlertaLlegada.retraso] cuando la hora ya pasó.
  /// - Sin alertas si el administrador las desactivó.
  static List<ArrivalAlert> calcular({
    required Iterable<ReservationModel> reservas,
    required DateTime ahora,
    OperationsConfig config = const OperationsConfig(),
  }) {
    if (!config.alertasActivas) return const [];
    final hoy = RestaurantTime.fechaLocalHoy(config.zonaHoraria, ahora);
    final alertas = <ArrivalAlert>[];
    for (final r in reservas) {
      if (r.estadoOperativo != ReservationModel.estadoPendienteLlegada) continue;
      if (!r.bloqueaMesas || r.fechaLocal != hoy) continue;
      final segundos = r.effectiveStart.difference(ahora).inSeconds;
      if (segundos >= 0) {
        final minutos = (segundos / 60).ceil();
        if (minutos > config.umbralAlertaMin) continue;
        alertas.add(ArrivalAlert(
          reserva: r,
          tipo: TipoAlertaLlegada.proxima,
          minutos: minutos,
          umbralMin: config.umbralAlertaMin,
        ));
      } else {
        final minutos = ((-segundos) / 60).ceil();
        alertas.add(ArrivalAlert(
          reserva: r,
          tipo: TipoAlertaLlegada.retraso,
          minutos: minutos < 1 ? 1 : minutos,
          umbralMin: config.umbralAlertaMin,
        ));
      }
    }
    alertas.sort((a, b) =>
        a.reserva.effectiveStart.compareTo(b.reserva.effectiveStart));
    return alertas;
  }

  /// La alerta de la [reservaId], si la tiene.
  static ArrivalAlert? deReserva(List<ArrivalAlert> alertas, String reservaId) {
    for (final a in alertas) {
      if (a.reserva.id == reservaId) return a;
    }
    return null;
  }
}
