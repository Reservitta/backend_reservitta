import 'reservation_model.dart';
import 'table_availability_models.dart';

/// Motivo por el que la mesa u horario elegidos ya no son válidos (HU12-RF02).
enum SelectionIssue { fechaInvalida, horarioPasado, fueraDeHorario, mesaOcupada }

/// Resultado de revalidar la selección antes de mostrar el resumen (HU12-RF02).
/// No bloquea la reserva: solo informa si la selección sigue disponible.
class SelectionValidation {
  final SelectionIssue? issue;
  final AvailabilityFailure? dateReason;

  /// Mesas de la selección que ya tienen otra reserva en ese horario.
  final Set<String> mesasEnConflicto;

  /// Horarios libres para las mismas mesas, de más cercano a más lejano.
  final List<TimeSlot> alternativas;

  /// Paso del flujo al que se redirige: 1 fecha, 4 mesa o 5 horario.
  final int redirectStep;

  const SelectionValidation.valid()
      : issue = null,
        dateReason = null,
        mesasEnConflicto = const {},
        alternativas = const [],
        redirectStep = -1;

  const SelectionValidation.invalid({
    required SelectionIssue this.issue,
    required this.redirectStep,
    this.dateReason,
    this.mesasEnConflicto = const {},
    this.alternativas = const [],
  });

  bool get isValid => issue == null;

  /// Mensaje listo para mostrar al usuario.
  String? get message {
    switch (issue) {
      case SelectionIssue.fechaInvalida:
        return DateValidationResult.invalid(
              dateReason ?? AvailabilityFailure.diaCerrado,
            ).message ??
            'La fecha elegida ya no está disponible.';
      case SelectionIssue.horarioPasado:
        return 'Ese horario ya pasó. Elige otro horario.';
      case SelectionIssue.fueraDeHorario:
        return 'El horario elegido queda fuera del horario de atención.';
      case SelectionIssue.mesaOcupada:
        return alternativas.isEmpty
            ? 'La mesa elegida ya no tiene horarios libres. Elige otra mesa.'
            : 'La mesa elegida acaba de reservarse en ese horario. Elige otro horario.';
      case null:
        return null;
    }
  }
}

/// Otra persona reservó alguna de las mesas en ese horario (HU11-RF04).
class ReservationConflictException implements Exception {
  final Set<String> mesaIds;

  const ReservationConflictException(this.mesaIds);

  @override
  String toString() =>
      'ReservationConflictException: mesas ocupadas ${mesaIds.join(', ')}';
}

/// Falló la conexión durante la confirmación; no se guardó nada (HU11-RF04).
class ReservationConnectionException implements Exception {
  final String? code;

  const ReservationConnectionException([this.code]);

  /// Códigos de Firestore que indican problemas de red o de disponibilidad.
  static bool isConnectionCode(String code) =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network-request-failed' ||
      code == 'cancelled';

  @override
  String toString() => 'ReservationConnectionException($code)';
}

/// Intervalo que una reserva ocupa en una mesa. Los minutos se miden desde la
/// medianoche del día de la reserva y pueden superar 1440 si cruza la medianoche.
class OccupancyInterval {
  final String reservaId;
  final int inicioMin;
  final int finMin;

  const OccupancyInterval({
    required this.reservaId,
    required this.inicioMin,
    required this.finMin,
  });

  factory OccupancyInterval.fromMap(Map<String, dynamic> map) {
    return OccupancyInterval(
      reservaId: (map['reservaId'] as String?) ?? '',
      inicioMin: (map['inicioMin'] as num?)?.toInt() ?? 0,
      finMin: (map['finMin'] as num?)?.toInt() ?? 0,
    );
  }

  /// Lee la lista `intervalos` de un documento de ocupación; tolera documentos
  /// vacíos o con datos mal formados.
  static List<OccupancyInterval> listFromData(Map<String, dynamic>? data) {
    final raw = data?['intervalos'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) OccupancyInterval.fromMap(Map<String, dynamic>.from(item)),
    ];
  }

  Map<String, dynamic> toMap() => {
        'reservaId': reservaId,
        'inicioMin': inicioMin,
        'finMin': finMin,
      };

  /// Identificador del documento de ocupación de una mesa en una fecha.
  static String docId(String mesaId, String fechaLocal) =>
      '${mesaId}_$fechaLocal';

  /// Se traslapa con [inicio, fin) medido desde la medianoche del día de la nueva
  /// reserva. [shiftMin] mueve este intervalo si su documento es de otro día
  /// (-1440 el día anterior, 1440 el siguiente). Terminar justo cuando empieza
  /// otra no cuenta como traslape; [margenMin] agrega tiempo de limpieza.
  bool overlaps(int inicio, int fin, {int shiftMin = 0, int margenMin = 0}) {
    final miInicio = inicioMin + shiftMin;
    final miFin = finMin + shiftMin + margenMin;
    return inicio < miFin && fin > miInicio;
  }
}

/// Resultado de confirmar una reserva (HU11-RF04).
sealed class BookingResult {
  const BookingResult();
}

/// La reserva se guardó y quedó asociada al usuario.
final class BookingConfirmed extends BookingResult {
  final ReservationModel reservation;

  const BookingConfirmed(this.reservation);
}

/// Otra persona reservó la mesa; se ofrecen horarios alternativos.
final class BookingConflict extends BookingResult {
  final String message;
  final Set<String> mesasEnConflicto;
  final List<TimeSlot> alternativas;

  const BookingConflict({
    required this.message,
    required this.mesasEnConflicto,
    this.alternativas = const [],
  });
}

/// La selección dejó de ser válida antes de intentar guardar (HU12-RF02).
final class BookingRejected extends BookingResult {
  final SelectionValidation validation;

  const BookingRejected(this.validation);
}

/// No se pudo completar; no queda ninguna reserva a medias.
final class BookingFailed extends BookingResult {
  final String message;

  /// Es un problema de conexión y vale la pena reintentar.
  final bool retryable;

  const BookingFailed({required this.message, this.retryable = false});
}
