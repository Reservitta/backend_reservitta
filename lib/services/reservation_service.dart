import 'package:cloud_firestore/cloud_firestore.dart';
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

    await _reservationsRef.doc(reservationId).update({
      'estado': estadoNormalizado,
      'estadoActualizadoEn': FieldValue.serverTimestamp(),
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
