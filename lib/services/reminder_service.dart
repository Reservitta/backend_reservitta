import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operations_config.dart';
import '../models/reservation_model.dart';
import '../models/reservation_notification_payload.dart';
import 'confirmation_notification_service.dart';

/// Estados de un recordatorio (HU21-RF01).
class ReminderState {
  ReminderState._();

  static const String programado = 'programado';
  static const String enviado = 'enviado';
  static const String omitido = 'omitido';
  static const String cancelado = 'cancelado';
  static const String fallido = 'fallido';
}

/// Qué se hará con el recordatorio de una reserva.
class ReminderPlan {
  /// [ReminderState.programado] u [ReminderState.omitido].
  final String estado;

  /// Cuándo se debe enviar; null si se omite.
  final DateTime? programadoPara;
  final String? motivo;

  const ReminderPlan({required this.estado, this.programadoPara, this.motivo});

  bool get seEnvia => estado == ReminderState.programado;
}

/// Reglas del recordatorio (HU21-RF01).
class ReminderPolicy {
  ReminderPolicy._();

  /// Margen de entrega permitido respecto a lo programado (HU21-RNF01).
  static const Duration margenEntrega = Duration(minutes: 5);

  /// Máximo de intentos de envío antes de marcar el recordatorio como fallido.
  static const int maxIntentos = 3;

  /// Decide cuándo enviar el recordatorio de una reserva que empieza en [inicio].
  ///
  /// Se programa [OperationsConfig.recordatorioMin] antes. Si la reserva se creó con
  /// menos anticipación que eso, no se envía, o se envía de inmediato si el
  /// restaurante lo configuró así. Si la visita ya empezó, no se envía.
  static ReminderPlan planear({
    required DateTime inicio,
    required DateTime ahora,
    required OperationsConfig config,
  }) {
    if (!inicio.isAfter(ahora)) {
      return const ReminderPlan(
        estado: ReminderState.omitido,
        motivo: 'La reserva ya comenzó.',
      );
    }
    final programado = inicio.subtract(Duration(minutes: config.recordatorioMin));
    if (programado.isAfter(ahora)) {
      return ReminderPlan(
        estado: ReminderState.programado,
        programadoPara: programado,
      );
    }
    if (config.recordatorioTardioInmediato) {
      return ReminderPlan(
        estado: ReminderState.programado,
        programadoPara: ahora,
      );
    }
    return const ReminderPlan(
      estado: ReminderState.omitido,
      motivo: 'La reserva se hizo con menos anticipación que el recordatorio.',
    );
  }
}

/// Resultado de [ReminderService.procesar].
class ReminderRunResult {
  final List<String> enviados;
  final List<String> reprogramados;
  final List<String> cancelados;
  final List<String> fallidos;

  const ReminderRunResult({
    this.enviados = const [],
    this.reprogramados = const [],
    this.cancelados = const [],
    this.fallidos = const [],
  });
}

/// Programa, reprograma, cancela y envía los recordatorios de reservas (HU21-RF01).
///
/// Cada recordatorio es un documento `restaurants/{id}/recordatorios/{reservaId}`. El
/// envío reutiliza [ConfirmationNotificationService] (mismo canal que la confirmación,
/// HU14-RF03). [procesar] concilia los recordatorios con el estado actual de las
/// reservas, de modo que una cancelación o un cambio de fecha/hora (que el visitante
/// hace con su enlace, sin permiso para tocar este documento) se reflejan en la
/// siguiente pasada.
class ReminderService {
  final FirebaseFirestore? _firestoreInstance;
  final ConfirmationNotificationService? _notificacionesInstance;
  final DateTime Function() _now;

  ReminderService({
    FirebaseFirestore? firestore,
    ConfirmationNotificationService? notificaciones,
    DateTime Function()? now,
  })  : _firestoreInstance = firestore,
        _notificacionesInstance = notificaciones,
        _now = now ?? DateTime.now;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  ConfirmationNotificationService get _notificaciones =>
      _notificacionesInstance ??
      ConfirmationNotificationService(firestore: _firestoreInstance);

  DocumentReference<Map<String, dynamic>> _ref(String restauranteId, String reservaId) =>
      _db
          .collection('restaurants')
          .doc(restauranteId)
          .collection('recordatorios')
          .doc(reservaId);

  Future<OperationsConfig> _config(String restauranteId) async {
    final snap = await _db.collection('restaurants').doc(restauranteId).get();
    return OperationsConfig.fromRestaurantData(snap.data());
  }

  /// Programa el recordatorio al confirmarse la reserva. Devuelve el plan aplicado.
  Future<ReminderPlan> programar(
    ReservationModel reserva, {
    OperationsConfig? config,
    DateTime? ahora,
  }) async {
    final cfg = config ?? await _config(reserva.restauranteId);
    final momento = ahora ?? _now();
    final plan = ReminderPolicy.planear(
      inicio: reserva.effectiveStart,
      ahora: momento,
      config: cfg,
    );
    await _guardarPlan(reserva, plan, cfg, momento);
    return plan;
  }

  Future<void> _guardarPlan(
    ReservationModel reserva,
    ReminderPlan plan,
    OperationsConfig cfg,
    DateTime ahora,
  ) {
    return _ref(reserva.restauranteId, reserva.id).set({
      'reservaId': reserva.id,
      'restauranteId': reserva.restauranteId,
      'usuarioId': reserva.usuarioId,
      'estado': plan.estado,
      'programadoPara':
          plan.programadoPara != null ? Timestamp.fromDate(plan.programadoPara!) : null,
      'inicio': Timestamp.fromDate(reserva.effectiveStart),
      'minutosAntes': cfg.recordatorioMin,
      if (plan.motivo != null) 'motivo': plan.motivo,
      'intentos': 0,
      'actualizadoEn': Timestamp.fromDate(ahora),
    });
  }

  /// Cancela el recordatorio (la reserva se canceló).
  Future<void> cancelar(String restauranteId, String reservaId, {DateTime? ahora}) async {
    final ref = _ref(restauranteId, reservaId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()!['estado'] != ReminderState.programado) return;
    await ref.update({
      'estado': ReminderState.cancelado,
      'actualizadoEn': Timestamp.fromDate(ahora ?? _now()),
    });
  }

  /// Recordatorio de una reserva, o null si no tiene.
  Future<Map<String, dynamic>?> obtener(String restauranteId, String reservaId) async {
    final snap = await _ref(restauranteId, reservaId).get();
    return snap.data();
  }

  /// Concilia y envía los recordatorios vencidos de las [reservas] del restaurante.
  Future<ReminderRunResult> procesar({
    required String restauranteId,
    required Iterable<ReservationModel> reservas,
    required DateTime ahora,
    OperationsConfig? config,
  }) async {
    final cfg = config ?? await _config(restauranteId);
    final enviados = <String>[];
    final reprogramados = <String>[];
    final cancelados = <String>[];
    final fallidos = <String>[];

    for (final r in reservas) {
      if (r.id.isEmpty) continue;
      final ref = _ref(restauranteId, r.id);
      final snap = await ref.get();
      final doc = snap.data();
      final estadoDoc = doc?['estado'] as String?;
      final vigente =
          r.estadoOperativo == ReservationModel.estadoPendienteLlegada && r.bloqueaMesas;

      if (!vigente) {
        if (estadoDoc == ReminderState.programado) {
          await ref.update({
            'estado': ReminderState.cancelado,
            'actualizadoEn': Timestamp.fromDate(ahora),
          });
          cancelados.add(r.id);
        }
        continue;
      }

      final inicioDoc = (doc?['inicio'] as Timestamp?)?.toDate();
      final inicioActual = r.effectiveStart;
      final cambioHorario =
          inicioDoc != null && !inicioDoc.isAtSameMomentAs(inicioActual);
      final minutosCambio = doc != null &&
          doc['minutosAntes'] != cfg.recordatorioMin &&
          estadoDoc == ReminderState.programado;

      if (doc == null || cambioHorario || minutosCambio) {
        // Sin recordatorio (la reserva es anterior a HU21) o reprogramación por
        // cambio de fecha/hora. Se toma como momento de referencia la creación de la
        // reserva si es la primera vez, o ahora si se modificó.
        final referencia = doc == null ? (r.creadaEn ?? ahora) : ahora;
        final plan = ReminderPolicy.planear(
          inicio: inicioActual,
          ahora: referencia.isAfter(ahora) ? ahora : referencia,
          config: cfg,
        );
        await _guardarPlan(r, plan, cfg, ahora);
        if (doc != null) reprogramados.add(r.id);
        if (!plan.seEnvia || plan.programadoPara!.isAfter(ahora)) continue;
        // Si ya venció, se envía en esta misma pasada.
        await _enviar(r, ahora, cfg, enviados, fallidos);
        continue;
      }

      if (estadoDoc != ReminderState.programado) continue;
      final programadoPara = (doc['programadoPara'] as Timestamp?)?.toDate();
      if (programadoPara == null || programadoPara.isAfter(ahora)) continue;
      await _enviar(r, ahora, cfg, enviados, fallidos);
    }

    return ReminderRunResult(
      enviados: enviados,
      reprogramados: reprogramados,
      cancelados: cancelados,
      fallidos: fallidos,
    );
  }

  Future<void> _enviar(
    ReservationModel r,
    DateTime ahora,
    OperationsConfig cfg,
    List<String> enviados,
    List<String> fallidos,
  ) async {
    final ref = _ref(r.restauranteId, r.id);
    final snap = await ref.get();
    final intentos = ((snap.data()?['intentos'] as num?)?.toInt() ?? 0) + 1;
    final programadoPara = (snap.data()?['programadoPara'] as Timestamp?)?.toDate();

    String? error;
    try {
      // El servicio solo acepta reservas confirmadas: el recordatorio es de una
      // reserva vigente, aunque su estado operativo sea "pendiente de llegada".
      final payload = ReservationNotificationPayload.fromReservation(
        r.copyWith(estado: ReservationModel.estadoConfirmada),
        tipo: ReservationNotificationPayload.tipoRecordatorio,
      );
      final resultado = await _notificaciones.sendNotification(payload);
      if (resultado.exitoso) {
        await ref.update({
          'estado': ReminderState.enviado,
          'enviadoEn': Timestamp.fromDate(ahora),
          'retrasoSeg': programadoPara == null
              ? 0
              : ahora.difference(programadoPara).inSeconds,
          'dentroDeMargen': programadoPara == null ||
              ahora.difference(programadoPara) <= ReminderPolicy.margenEntrega,
          'intentos': intentos,
          'actualizadoEn': Timestamp.fromDate(ahora),
        });
        enviados.add(r.id);
        return;
      }
      error = resultado.error ?? 'No se pudo enviar el recordatorio.';
    } catch (e) {
      error = e.toString();
    }

    final agotado = intentos >= ReminderPolicy.maxIntentos;
    await ref.update({
      'estado': agotado ? ReminderState.fallido : ReminderState.programado,
      'intentos': intentos,
      'ultimoError': error,
      'actualizadoEn': Timestamp.fromDate(ahora),
    });
    if (agotado) fallidos.add(r.id);
  }
}
