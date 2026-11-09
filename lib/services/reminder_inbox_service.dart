import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operations_config.dart';
import '../models/reservation_model.dart';

/// Recordatorio de una reserva próxima, para mostrarlo dentro de la app (HU21-RF02).
class UpcomingReminder {
  final ReservationModel reserva;

  /// Cuándo se programó el recordatorio (inicio menos la anticipación).
  final DateTime programadoPara;

  const UpcomingReminder({required this.reserva, required this.programadoPara});

  String get texto {
    final r = reserva;
    final inicio = r.effectiveStart;
    final hora =
        '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';
    final nombre = r.restauranteNombre.trim().isEmpty ? 'el restaurante' : r.restauranteNombre.trim();
    return 'Recordatorio: tu reserva en $nombre es hoy a las $hora.';
  }
}

/// Reservas del visitante que ya están en su ventana de recordatorio (HU21-RF02): las
/// que empiezan pronto y todavía están vigentes.
class ReminderInboxService {
  final FirebaseFirestore? _firestoreInstance;

  ReminderInboxService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  static String _fecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<UpcomingReminder>> proximos(
    String usuarioId, {
    DateTime? ahora,
  }) async {
    if (usuarioId.isEmpty) return const [];
    final momento = ahora ?? DateTime.now();
    final hoy = _fecha(momento);
    final manana = _fecha(momento.add(const Duration(days: 1)));

    final snap = await _db
        .collection('reservations')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('fechaLocal', whereIn: [hoy, manana])
        .get();

    final configs = <String, OperationsConfig>{};
    final resultado = <UpcomingReminder>[];
    for (final doc in snap.docs) {
      final r = ReservationModel.fromFirestore(doc);
      if (r.estadoOperativo != ReservationModel.estadoPendienteLlegada || !r.bloqueaMesas) {
        continue;
      }
      final inicio = r.effectiveStart;
      if (!inicio.isAfter(momento)) continue;

      var config = configs[r.restauranteId];
      if (config == null) {
        try {
          final rest = await _db.collection('restaurants').doc(r.restauranteId).get();
          config = OperationsConfig.fromRestaurantData(rest.data());
        } catch (_) {
          config = const OperationsConfig();
        }
        configs[r.restauranteId] = config;
      }
      final programado = inicio.subtract(Duration(minutes: config.recordatorioMin));
      if (momento.isBefore(programado)) continue;
      resultado.add(UpcomingReminder(reserva: r, programadoPara: programado));
    }
    resultado.sort((a, b) =>
        a.reserva.effectiveStart.compareTo(b.reserva.effectiveStart));
    return resultado;
  }
}
