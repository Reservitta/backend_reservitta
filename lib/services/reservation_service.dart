import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_models.dart';
import '../models/reservation_model.dart';
import '../repositories/reservation_repository.dart';

/// Implementación del servicio de reservaciones sobre Cloud Firestore (HU08-RF02)
class ReservationService implements ReservationRepository {
  final FirebaseFirestore? _firestoreInstance;

  ReservationService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection('reservations');

  @override
  Future<ReservationModel> createReservation(ReservationModel reservation) async {
    final estadoNormalizado = reservation.estado.trim().toLowerCase();
    if (!ReservationModel.isValidStatus(estadoNormalizado)) {
      throw ArgumentError(
        'Estado inválido: "${reservation.estado}". '
        'Estados permitidos: ${ReservationModel.estadosValidos.join(", ")}',
      );
    }

    // Criterio 2: La hora de fin se calcula como hora de inicio + duración
    final effectiveFin = reservation.fin ??
        (reservation.inicio != null
            ? ReservationModel.calculateEndTime(
                inicio: reservation.inicio!,
                duracionMin: reservation.duracionMin,
              )
            : null);

    final modelToSave = reservation.copyWith(
      estado: estadoNormalizado,
      fin: effectiveFin,
    );

    DocumentReference<Map<String, dynamic>> docRef;
    if (modelToSave.id.isNotEmpty) {
      docRef = _reservationsRef.doc(modelToSave.id);
      await docRef.set(modelToSave.toMap(), SetOptions(merge: true));
    } else {
      docRef = await _reservationsRef.add(modelToSave.toMap());
    }

    return modelToSave.copyWith(id: docRef.id);
  }

  CollectionReference<Map<String, dynamic>> _occupancyRef(String restauranteId) =>
      _firestore
          .collection('restaurants')
          .doc(restauranteId)
          .collection('ocupacionMesas');

  @override
  Future<ReservationModel> createReservationVerified(
    ReservationModel reservation, {
    int margenLimpiezaMin = 0,
  }) async {
    final estado = reservation.estado.trim().toLowerCase();
    if (!ReservationModel.isValidStatus(estado)) {
      throw ArgumentError(
        'Estado inválido: "${reservation.estado}". '
        'Estados permitidos: ${ReservationModel.estadosValidos.join(", ")}',
      );
    }
    final inicio = reservation.inicio;
    if (inicio == null ||
        reservation.restauranteId.isEmpty ||
        reservation.mesaIds.isEmpty) {
      throw ArgumentError(
        'La reservación necesita restaurante, mesas y hora de inicio.',
      );
    }

    final fin = reservation.fin ??
        ReservationModel.calculateEndTime(
          inicio: inicio,
          duracionMin: reservation.duracionMin,
        );
    final dia = _parseDay(reservation.fechaLocal, inicio);
    final inicioMin = inicio.difference(dia).inMinutes;
    final finMin = fin.difference(dia).inMinutes;

    final docRef = reservation.id.isNotEmpty
        ? _reservationsRef.doc(reservation.id)
        : _reservationsRef.doc();
    final guardada = reservation.copyWith(
      id: docRef.id,
      estado: estado,
      fin: fin,
    );
    final ocupacion = _occupancyRef(reservation.restauranteId);

    try {
      await _firestore.runTransaction((tx) async {
        // Todas las lecturas van antes de las escrituras.
        final delDia = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        final enConflicto = <String>{};
        for (final mesaId in reservation.mesaIds) {
          // Una reserva nocturna del día anterior o del siguiente puede traslaparse.
          for (final offset in const [-1, 0, 1]) {
            final fecha = _formatDateLocal(
              DateTime(dia.year, dia.month, dia.day + offset),
            );
            final snap = await tx.get(
              ocupacion.doc(OccupancyInterval.docId(mesaId, fecha)),
            );
            if (offset == 0) delDia[mesaId] = snap;
            final choca = OccupancyInterval.listFromData(snap.data()).any(
              (i) => i.overlaps(
                inicioMin,
                finMin,
                shiftMin: offset * 1440,
                margenMin: margenLimpiezaMin,
              ),
            );
            if (choca) enConflicto.add(mesaId);
          }
        }
        if (enConflicto.isNotEmpty) {
          throw ReservationConflictException(enConflicto);
        }

        tx.set(docRef, guardada.toMap());
        for (final mesaId in reservation.mesaIds) {
          final snap = delDia[mesaId]!;
          final intervalos = [
            ...OccupancyInterval.listFromData(snap.data()),
            OccupancyInterval(
              reservaId: docRef.id,
              inicioMin: inicioMin,
              finMin: finMin,
            ),
          ];
          tx.set(snap.reference, {
            'mesaId': mesaId,
            'fechaLocal': reservation.fechaLocal,
            'intervalos': intervalos.map((i) => i.toMap()).toList(),
          });
        }
      });
    } on FirebaseException catch (e) {
      if (ReservationConnectionException.isConnectionCode(e.code)) {
        throw ReservationConnectionException(e.code);
      }
      rethrow;
    }
    return guardada;
  }

  /// Día de negocio de la reservación (medianoche); usa [respaldo] si la fecha no es válida.
  static DateTime _parseDay(String fechaLocal, DateTime respaldo) {
    final parts = fechaLocal.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateTime(respaldo.year, respaldo.month, respaldo.day);
  }

  @override
  Future<List<ReservationModel>> getReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async {
    // Criterio 4: Consulta por restaurante y fecha soportada por índice compuesto
    final querySnap = await _reservationsRef
        .where('restauranteId', isEqualTo: restauranteId)
        .where('fechaLocal', isEqualTo: fechaLocal)
        .get();

    return querySnap.docs
        .map((doc) => ReservationModel.fromFirestore(doc))
        .toList();
  }

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async {
    // Criterio 3: Solo las reservaciones con estado activo (pendiente/confirmada) bloquean mesas
    final all = await getReservationsByRestaurantAndDate(
      restauranteId: restauranteId,
      fechaLocal: fechaLocal,
    );
    return all.where((r) => r.bloqueaMesas).toList();
  }

  @override
  Future<ReservationModel?> getReservationById(String reservationId) async {
    final docSnap = await _reservationsRef.doc(reservationId).get();
    if (!docSnap.exists) return null;
    return ReservationModel.fromFirestore(docSnap);
  }

  @override
  Future<void> updateReservationStatus({
    required String reservationId,
    required String nuevoEstado,
  }) async {
    final estadoNormalizado = nuevoEstado.trim().toLowerCase();
    if (!ReservationModel.isValidStatus(estadoNormalizado)) {
      throw ArgumentError(
        'Estado inválido: "$nuevoEstado". '
        'Estados permitidos: ${ReservationModel.estadosValidos.join(", ")}',
      );
    }

    if (estadoNormalizado == ReservationModel.estadoCancelada) {
      await _cancelAndRelease(reservationId);
      return;
    }

    await _reservationsRef.doc(reservationId).update({
      'estado': estadoNormalizado,
      'estadoActualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Cancela y libera los intervalos de ocupación de sus mesas en una transacción.
  Future<void> _cancelAndRelease(String reservationId) async {
    await _firestore.runTransaction((tx) async {
      final resSnap = await tx.get(_reservationsRef.doc(reservationId));
      if (!resSnap.exists) {
        throw StateError('La reservación $reservationId no existe.');
      }
      final res = ReservationModel.fromFirestore(resSnap);
      final ocupacion = _occupancyRef(res.restauranteId);

      final ocupaciones = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final mesaId in res.mesaIds) {
        ocupaciones.add(
          await tx.get(
            ocupacion.doc(OccupancyInterval.docId(mesaId, res.fechaLocal)),
          ),
        );
      }

      tx.update(resSnap.reference, {
        'estado': ReservationModel.estadoCancelada,
        'estadoActualizadoEn': FieldValue.serverTimestamp(),
      });
      for (final snap in ocupaciones) {
        if (!snap.exists) continue;
        final restantes = OccupancyInterval.listFromData(snap.data())
            .where((i) => i.reservaId != reservationId)
            .map((i) => i.toMap())
            .toList();
        tx.update(snap.reference, {'intervalos': restantes});
      }
    });
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    // Criterio 3: Al cancelar, el estado deja de ser activo y ya no bloquea mesas
    await updateReservationStatus(
      reservationId: reservationId,
      nuevoEstado: ReservationModel.estadoCancelada,
    );
  }

  @override
  Future<bool> isTableAvailable({
    required String restauranteId,
    required String mesaId,
    required DateTime targetDateTime,
    int durationMin = 90,
  }) async {
    final dateString = _formatDateLocal(targetDateTime);
    final activeReservations = await getActiveReservationsByRestaurantAndDate(
      restauranteId: restauranteId,
      fechaLocal: dateString,
    );

    // Criterio 3: Solo las reservaciones activas bloquean la mesa
    return !activeReservations.any(
      (r) => r.isTableBlocked(
        mesaId,
        targetDateTime: targetDateTime,
        durationMin: durationMin,
      ),
    );
  }

  @override
  Future<Set<String>> getBlockedTableIds({
    required String restauranteId,
    required DateTime targetDateTime,
    int durationMin = 90,
  }) async {
    final dateString = _formatDateLocal(targetDateTime);
    final activeReservations = await getActiveReservationsByRestaurantAndDate(
      restauranteId: restauranteId,
      fechaLocal: dateString,
    );

    final blockedIds = <String>{};
    for (final res in activeReservations) {
      if (res.overlapsWith(targetDateTime, durationMin: durationMin)) {
        blockedIds.addAll(res.mesaIds);
      }
    }
    return blockedIds;
  }

  @override
  Stream<List<ReservationModel>> getReservationsStream({
    required String restauranteId,
    required String fechaLocal,
  }) {
    return _reservationsRef
        .where('restauranteId', isEqualTo: restauranteId)
        .where('fechaLocal', isEqualTo: fechaLocal)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => ReservationModel.fromFirestore(d)).toList());
  }

  static String _formatDateLocal(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
