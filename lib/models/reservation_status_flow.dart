import 'reservation_model.dart';

/// Se intentó una transición de estado que no está permitida (HU27-RF01 Criterio 4).
class InvalidStateTransitionException implements Exception {
  final String message;

  const InvalidStateTransitionException(this.message);

  @override
  String toString() => 'InvalidStateTransitionException: $message';
}

/// Estados operativos de una reserva y sus transiciones válidas (HU27-RF01).
///
/// pendiente de llegada → cliente llegó → en servicio → finalizada
/// Una reserva pendiente también puede cancelarse o marcarse como no-show; una que
/// ya llegó solo puede cancelarse antes de pasar a servicio. Finalizada, cancelada
/// y no-show son estados finales.
class ReservationStateMachine {
  const ReservationStateMachine._();

  /// Estados operativos válidos (HU27-RF01 Criterio 1).
  static const List<String> estados = [
    ReservationModel.estadoPendienteLlegada,
    ReservationModel.estadoClienteLlego,
    ReservationModel.estadoEnServicio,
    ReservationModel.estadoFinalizada,
    ReservationModel.estadoCancelada,
    ReservationModel.estadoNoShow,
  ];

  static const Map<String, List<String>> _transiciones = {
    ReservationModel.estadoPendienteLlegada: [
      ReservationModel.estadoClienteLlego,
      ReservationModel.estadoCancelada,
      ReservationModel.estadoNoShow,
    ],
    ReservationModel.estadoClienteLlego: [
      ReservationModel.estadoEnServicio,
      ReservationModel.estadoCancelada,
    ],
    ReservationModel.estadoEnServicio: [
      ReservationModel.estadoFinalizada,
    ],
    ReservationModel.estadoFinalizada: [],
    ReservationModel.estadoCancelada: [],
    ReservationModel.estadoNoShow: [],
  };

  /// Estado operativo normalizado ('pendiente' y 'confirmada' cuentan como
  /// pendiente de llegada).
  static String normalizar(String estado) {
    final norm = ReservationModel.normalizeStatus(estado);
    switch (norm) {
      case ReservationModel.estadoPendiente:
      case ReservationModel.estadoConfirmada:
        return ReservationModel.estadoPendienteLlegada;
      default:
        return norm;
    }
  }

  /// Estados a los que se puede pasar desde [desde] (HU27-RF02 Criterio 2).
  static List<String> siguientes(String desde) =>
      List.unmodifiable(_transiciones[normalizar(desde)] ?? const []);

  static bool esFinal(String estado) => siguientes(estado).isEmpty;

  static bool puedeTransicionar(String desde, String hacia) =>
      siguientes(desde).contains(normalizar(hacia));

  /// Pedir confirmación antes de cancelar o marcar como no-show (HU27-RF02 Criterio 4).
  static bool requiereConfirmacion(String hacia) {
    final norm = normalizar(hacia);
    return norm == ReservationModel.estadoCancelada ||
        norm == ReservationModel.estadoNoShow;
  }

  /// Estados que liberan la mesa de la reserva.
  static bool liberaMesa(String hacia) {
    final norm = normalizar(hacia);
    return norm == ReservationModel.estadoCancelada ||
        norm == ReservationModel.estadoNoShow ||
        norm == ReservationModel.estadoFinalizada;
  }

  /// Mensaje claro si la transición no es válida; null si se puede (HU27-RF01 Criterio 4).
  static String? validar(String desde, String hacia) {
    final origen = normalizar(desde);
    final destino = normalizar(hacia);
    if (!estados.contains(destino)) {
      return 'El estado "$hacia" no es válido.';
    }
    if (origen == destino) {
      return 'La reserva ya está en "${ReservationModel.etiquetaParaEstado(destino)}".';
    }
    if (!estados.contains(origen)) {
      return 'El estado actual "$desde" no es válido.';
    }
    if (esFinal(origen)) {
      return 'Una reserva "${ReservationModel.etiquetaParaEstado(origen)}" ya no puede cambiar de estado.';
    }
    if (!puedeTransicionar(origen, destino)) {
      return 'No se puede pasar de "${ReservationModel.etiquetaParaEstado(origen)}" a "${ReservationModel.etiquetaParaEstado(destino)}".';
    }
    return null;
  }

  /// Lanza [InvalidStateTransitionException] si la transición no es válida.
  static void exigirValida(String desde, String hacia) {
    final problema = validar(desde, hacia);
    if (problema != null) throw InvalidStateTransitionException(problema);
  }
}
