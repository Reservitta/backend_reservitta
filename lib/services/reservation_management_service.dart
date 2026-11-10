import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_models.dart';
import '../models/reservation_access.dart';
import '../models/reservation_model.dart';
import '../models/restaurant_model.dart';
import '../utils/schedule_utils.dart';
import 'availability_service.dart';

/// Consulta, cancela y modifica una reserva con su token, sin iniciar sesión
/// (HU20-RF01, HU20-RF02).
///
/// Quien abre el enlace no puede leer la colección de reservas: solo lee el
/// documento público `gestionReservas/{token}`, que tiene el resumen de su propia
/// reserva. Cada cambio se hace en una transacción que también actualiza ese
/// documento, y es lo que permite a las reglas de Firestore autorizarlo.
class ReservationManagementService {
  final FirebaseFirestore? _firestoreInstance;
  final AvailabilityService? _availability;
  final ReservationChangePolicy politica;
  final DateTime Function() _now;

  ReservationManagementService({
    FirebaseFirestore? firestore,
    AvailabilityService? availability,
    this.politica = const ReservationChangePolicy(),
    DateTime Function()? now,
  })  : _firestoreInstance = firestore,
        _availability = availability,
        _now = now ?? DateTime.now;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _gestionRef(String token) =>
      _firestore.collection('gestionReservas').doc(token);

  DocumentReference<Map<String, dynamic>> _reservaRef(String id) =>
      _firestore.collection('reservations').doc(id);

  CollectionReference<Map<String, dynamic>> _ocupacionRef(String restauranteId) =>
      _firestore
          .collection('restaurants')
          .doc(restauranteId)
          .collection('ocupacionMesas');

  // ---------------------------------------------------------------------------
  // Consulta
  // ---------------------------------------------------------------------------

  /// Abre la reserva a partir del código o enlace. Lanza [ManagementException]
  /// si el código no existe o ya venció.
  Future<ManagedReservation> consultar(String codigo) async {
    final token = ReservationAccess.normalizar(codigo);
    if (!ReservationAccess.esValido(token)) {
      throw const ManagementException(
        ManagementFailure.noEncontrada,
        'No encontramos una reserva con ese código. Revisa que esté completo.',
      );
    }
    final snap = await _gestionRef(token).get();
    return _leer(token, snap);
  }

  ManagedReservation _leer(
    String token,
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    if (!snap.exists) {
      throw const ManagementException(
        ManagementFailure.noEncontrada,
        'No encontramos una reserva con ese código. Revisa que esté completo.',
      );
    }
    final reserva = ManagedReservation.fromMap(token, snap.data() ?? {});
    if (reserva.estaExpirada(_now())) {
      throw const ManagementException(
        ManagementFailure.expirada,
        'Este enlace ya no es válido. Comunícate con el restaurante.',
      );
    }
    return reserva;
  }

  /// Datos para mostrar cuando ya no se puede cambiar (HU20-RF03 Criterio 2).
  Future<({String nombre, String telefono, String direccion})> contactoRestaurante(
    String restauranteId,
  ) async {
    final snap = await _firestore.collection('restaurants').doc(restauranteId).get();
    final data = snap.data() ?? {};
    return (
      nombre: (data['nombre'] as String?) ?? '',
      telefono: (data['telefono'] as String?) ?? '',
      direccion: (data['direccion'] as String?) ?? '',
    );
  }

  // ---------------------------------------------------------------------------
  // Cancelar (HU20-RF02 Criterios 1, 2 y 4)
  // ---------------------------------------------------------------------------

  /// Cancela la reserva y libera su mesa. Solo hasta el límite de tiempo.
  Future<ManagedReservation> cancelar(String codigo) async {
    final token = ReservationAccess.normalizar(codigo);
    final ahora = _now();

    return _firestore.runTransaction<ManagedReservation>((tx) async {
      final gestionSnap = await tx.get(_gestionRef(token));
      final reserva = _leer(token, gestionSnap);
      final problema = reserva.motivoNoGestionable(ahora, politica: politica);
      if (problema != null) throw problema;

      final ocupacion = _ocupacionRef(reserva.restauranteId);
      final ocupaciones = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final mesaId in reserva.mesaIds) {
        ocupaciones.add(await tx.get(
          ocupacion.doc(OccupancyInterval.docId(mesaId, reserva.fechaLocal)),
        ));
      }

      tx.update(_reservaRef(reserva.reservaId), {
        'estado': ReservationModel.estadoCancelada,
        'estadoActualizadoPor': 'visitante (enlace)',
        'estadoActualizadoEn': Timestamp.fromDate(ahora),
        'historialEstados': FieldValue.arrayUnion([
          {
            'de': reserva.estadoOperativo,
            'a': ReservationModel.estadoCancelada,
            'por': 'visitante (enlace)',
            'en': Timestamp.fromDate(ahora),
          },
        ]),
      });
      for (final snap in ocupaciones) {
        if (!snap.exists) continue;
        final restantes = OccupancyInterval.listFromData(snap.data())
            .where((i) => i.reservaId != reserva.reservaId)
            .map((i) => i.toMap())
            .toList();
        tx.update(snap.reference, {'intervalos': restantes});
      }
      tx.update(_gestionRef(token), {
        'estado': ReservationModel.estadoCancelada,
        'ultimaOperacionEn': FieldValue.serverTimestamp(),
      });

      return ManagedReservation.fromMap(token, {
        ...gestionSnap.data()!,
        'estado': ReservationModel.estadoCancelada,
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Modificar (HU20-RF02 Criterios 1, 2 y 3)
  // ---------------------------------------------------------------------------

  /// Cambia fecha, hora, duración, personas o mesas. Vuelve a validar la
  /// disponibilidad sin contar la propia reserva y la guarda en una transacción
  /// que evita reservas dobles. Solo hasta el límite de tiempo.
  Future<ManagedReservation> modificar(
    String codigo, {
    required RestaurantModel restaurant,
    required DateTime fecha,
    required DateTime inicio,
    required int duracionMin,
    required int personas,
    required List<String> mesaIds,
    required List<String> mesasNombres,
    int margenLimpiezaMin = 0,
  }) async {
    final token = ReservationAccess.normalizar(codigo);
    final ahora = _now();
    if (duracionMin <= 0 || personas < 1) {
      throw const ManagementException(
        ManagementFailure.datosInvalidos,
        'Elige horario y número de personas para modificar la reserva.',
      );
    }

    // Se valida antes de la transacción para dar un mensaje claro.
    final actual = await consultar(token);
    final problema = actual.motivoNoGestionable(ahora, politica: politica);
    if (problema != null) throw problema;

    final disponibilidad = _availability;
    if (disponibilidad != null) {
      final validacion = await disponibilidad.revalidateSelection(
        restaurant: restaurant,
        inicio: inicio,
        duracionMin: duracionMin,
        mesaIds: mesaIds,
        ignorarReservaId: actual.reservaId,
      );
      if (!validacion.isValid) {
        throw ManagementException(
          ManagementFailure.disponibilidad,
          validacion.message ?? 'La nueva mesa u horario ya no está disponible.',
        );
      }
    }

    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final fechaLocal = ScheduleUtils.formatDateLocal(dia);
    final fin = inicio.add(Duration(minutes: duracionMin));
    final inicioMin = inicio.difference(dia).inMinutes;
    final finMin = fin.difference(dia).inMinutes;

    return _firestore.runTransaction<ManagedReservation>((tx) async {
      final gestionSnap = await tx.get(_gestionRef(token));
      final reserva = _leer(token, gestionSnap);
      final bloqueo = reserva.motivoNoGestionable(ahora, politica: politica);
      if (bloqueo != null) throw bloqueo;

      final ocupacion = _ocupacionRef(reserva.restauranteId);

      // Documentos de ocupación que se leen: los de la reserva actual y, por cada
      // mesa nueva, el día anterior, el día y el siguiente.
      final docs = <String, ({String mesaId, String fecha})>{};
      for (final mesaId in reserva.mesaIds) {
        docs[OccupancyInterval.docId(mesaId, reserva.fechaLocal)] =
            (mesaId: mesaId, fecha: reserva.fechaLocal);
      }
      final porMesaYOffset = <String, Map<int, String>>{};
      for (final mesaId in mesaIds) {
        for (final offset in const [-1, 0, 1]) {
          final f = ScheduleUtils.formatDateLocal(
            DateTime(dia.year, dia.month, dia.day + offset),
          );
          final id = OccupancyInterval.docId(mesaId, f);
          docs[id] = (mesaId: mesaId, fecha: f);
          porMesaYOffset.putIfAbsent(mesaId, () => {})[offset] = id;
        }
      }

      final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in docs.keys) {
        snaps[id] = await tx.get(ocupacion.doc(id));
      }
      final intervalos = <String, List<OccupancyInterval>>{
        for (final e in snaps.entries)
          e.key: OccupancyInterval.listFromData(e.value.data()),
      };

      // Conflictos con otras reservas (sin contar la propia).
      final enConflicto = <String>{};
      for (final mesaId in mesaIds) {
        for (final offset in const [-1, 0, 1]) {
          final id = porMesaYOffset[mesaId]![offset]!;
          final choca = intervalos[id]!.any((i) =>
              i.reservaId != reserva.reservaId &&
              i.overlaps(inicioMin, finMin,
                  shiftMin: offset * 1440, margenMin: margenLimpiezaMin));
          if (choca) enConflicto.add(mesaId);
        }
      }
      if (enConflicto.isNotEmpty) {
        throw const ManagementException(
          ManagementFailure.disponibilidad,
          'La mesa elegida acaba de reservarse en ese horario. Elige otro horario o mesa.',
        );
      }

      // Se quita la reserva de las mesas anteriores y se agrega en las nuevas.
      for (final id in intervalos.keys) {
        intervalos[id] = [
          for (final i in intervalos[id]!)
            if (i.reservaId != reserva.reservaId) i,
        ];
      }
      for (final mesaId in mesaIds) {
        final id = porMesaYOffset[mesaId]![0]!;
        intervalos[id] = [
          ...intervalos[id]!,
          OccupancyInterval(
            reservaId: reserva.reservaId,
            inicioMin: inicioMin,
            finMin: finMin,
          ),
        ];
      }

      tx.update(_reservaRef(reserva.reservaId), {
        'fechaLocal': fechaLocal,
        'inicio': Timestamp.fromDate(inicio),
        'fin': Timestamp.fromDate(fin),
        'duracionMin': duracionMin,
        'personas': personas,
        'cantidadPersonas': personas,
        'mesaIds': mesaIds,
        'mesasNombres': mesasNombres,
        'ultimaModificacionEn': Timestamp.fromDate(ahora),
      });
      for (final entry in docs.entries) {
        final lista = intervalos[entry.key]!;
        final snap = snaps[entry.key]!;
        if (!snap.exists && lista.isEmpty) continue;
        tx.set(ocupacion.doc(entry.key), {
          'mesaId': entry.value.mesaId,
          'fechaLocal': entry.value.fecha,
          'intervalos': lista.map((i) => i.toMap()).toList(),
        });
      }
      final nuevaExpiracion = ReservationAccess.expiracion(fechaLocal, inicio);
      tx.update(_gestionRef(token), {
        'fechaLocal': fechaLocal,
        'inicio': Timestamp.fromDate(inicio),
        'fin': Timestamp.fromDate(fin),
        'duracionMin': duracionMin,
        'personas': personas,
        'mesaIds': mesaIds,
        'mesasNombres': mesasNombres,
        'expiraEn': Timestamp.fromDate(nuevaExpiracion),
        'ultimaOperacionEn': FieldValue.serverTimestamp(),
      });

      return ManagedReservation.fromMap(token, {
        ...gestionSnap.data()!,
        'fechaLocal': fechaLocal,
        'inicio': Timestamp.fromDate(inicio),
        'fin': Timestamp.fromDate(fin),
        'duracionMin': duracionMin,
        'personas': personas,
        'mesaIds': mesaIds,
        'mesasNombres': mesasNombres,
        'expiraEn': Timestamp.fromDate(nuevaExpiracion),
      });
    });
  }
}
