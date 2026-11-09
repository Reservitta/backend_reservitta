import 'reservation_model.dart';

/// Se intentó una transición inválida del estado del pedido (HU29-RF01).
class InvalidOrderTransitionException implements Exception {
  final String origen;
  final String destino;
  final String motivo;

  const InvalidOrderTransitionException(this.origen, this.destino, this.motivo);

  @override
  String toString() => motivo;
}

/// Estado del pedido preordenado, independiente del estado de la reserva (HU29-RF01).
///
/// Solo avanza de forma secuencial: pendiente → en preparación → listo. Se puede
/// regresar un paso únicamente con un motivo escrito.
class OrderStateMachine {
  OrderStateMachine._();

  static const String pendiente = ReservationModel.preordenPendiente;
  static const String enPreparacion = ReservationModel.preordenEnPreparacion;
  static const String listo = ReservationModel.preordenListo;

  /// Estados que gestiona esta pantalla, en orden.
  static const List<String> secuencia = [pendiente, enPreparacion, listo];

  static String normalizar(String? estado) =>
      ReservationModel.normalizePreordenStatus(estado);

  /// Siguiente estado del pedido, o null si ya está listo (o en un estado final).
  static String? siguiente(String estado) {
    final i = secuencia.indexOf(normalizar(estado));
    if (i < 0 || i >= secuencia.length - 1) return null;
    return secuencia[i + 1];
  }

  /// Estado anterior, o null si es el inicial (o un estado final).
  static String? anterior(String estado) {
    final i = secuencia.indexOf(normalizar(estado));
    if (i <= 0) return null;
    return secuencia[i - 1];
  }

  /// Si el paso de [origen] a [destino] es hacia atrás.
  static bool esReversa(String origen, String destino) {
    final a = secuencia.indexOf(normalizar(origen));
    final b = secuencia.indexOf(normalizar(destino));
    return a >= 0 && b >= 0 && b < a;
  }

  /// Valida la transición. Lanza [InvalidOrderTransitionException] si no se permite.
  /// Una reversa exige [motivo] (reversa manual justificada).
  static void validar(String origen, String destino, {String? motivo}) {
    final o = normalizar(origen);
    final d = normalizar(destino);
    if (!secuencia.contains(o) || !secuencia.contains(d)) {
      throw InvalidOrderTransitionException(
        o,
        d,
        'El pedido en estado "$o" ya no se puede cambiar.',
      );
    }
    if (o == d) {
      throw InvalidOrderTransitionException(
        o,
        d,
        'El pedido ya está en estado "${etiqueta(d)}".',
      );
    }
    final indiceO = secuencia.indexOf(o);
    final indiceD = secuencia.indexOf(d);
    if (indiceD > indiceO) {
      if (indiceD != indiceO + 1) {
        throw InvalidOrderTransitionException(
          o,
          d,
          'El pedido debe avanzar paso a paso: de "${etiqueta(o)}" a "${etiqueta(siguiente(o)!)}".',
        );
      }
      return;
    }
    if (indiceD != indiceO - 1) {
      throw InvalidOrderTransitionException(
        o,
        d,
        'Solo se puede regresar un paso a la vez.',
      );
    }
    if (motivo == null || motivo.trim().isEmpty) {
      throw InvalidOrderTransitionException(
        o,
        d,
        'Para regresar el pedido a "${etiqueta(d)}" escribe el motivo.',
      );
    }
  }

  static String etiqueta(String estado) =>
      ReservationModel.etiquetaParaEstadoPreorden(normalizar(estado));

  /// Estado inicial de un pedido nuevo.
  static const String inicial = pendiente;
}
