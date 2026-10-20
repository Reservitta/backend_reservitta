import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo inmutable de Reservación para gestión de capacidad y disponibilidad (HU03-RF01)
class ReservationModel {
  final String id;
  final String restauranteId;
  final String usuarioId;
  final String restauranteNombre;
  final String contactoNombre;
  final String contactoCorreo;
  final String contactoTelefono;
  final String fechaLocal; // Formato 'YYYY-MM-DD'
  final DateTime? inicio;
  final DateTime? fin;
  final int duracionMin;
  final int personas;
  final List<String> mesaIds;
  final List<String> mesasNombres;
  final String estado; // 'pendiente', 'confirmada', 'cancelada', 'finalizada', etc.
  final DateTime? creadaEn;

  const ReservationModel({
    required this.id,
    required this.restauranteId,
    this.usuarioId = '',
    this.restauranteNombre = '',
    this.contactoNombre = '',
    this.contactoCorreo = '',
    this.contactoTelefono = '',
    required this.fechaLocal,
    this.inicio,
    this.fin,
    this.duracionMin = 90,
    this.personas = 2,
    this.mesaIds = const [],
    this.mesasNombres = const [],
    this.estado = 'confirmada',
    this.creadaEn,
  });

  /// Indica si la reservación está activa y por tanto ocupa lugares
  bool get isActiva {
    final st = estado.trim().toLowerCase();
    return st != 'cancelada' &&
        st != 'rechazada' &&
        st != 'no_asistio' &&
        st != 'expirada';
  }

  /// Retorna la hora de inicio efectiva
  DateTime get effectiveStart {
    if (inicio != null) return inicio!;
    // Intentar construir a partir de fechaLocal
    try {
      final parts = fechaLocal.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          12,
          0,
        );
      }
    } catch (_) {}
    return DateTime.now();
  }

  /// Retorna la hora de fin efectiva
  DateTime get effectiveEnd {
    if (fin != null) return fin!;
    return effectiveStart.add(Duration(minutes: duracionMin > 0 ? duracionMin : 90));
  }

  /// Determina si esta reservación se traslapa con un intervalo de tiempo dado
  bool overlapsWith(DateTime targetDateTime, {int durationMin = 90}) {
    if (!isActiva) return false;

    final targetStart = targetDateTime;
    final targetEnd = targetDateTime.add(Duration(minutes: durationMin > 0 ? durationMin : 90));

    final resStart = effectiveStart;
    final resEnd = effectiveEnd;

    // Dos intervalos [A, B] y [C, D] se traslapan si A < D y B > C
    return resStart.isBefore(targetEnd) && resEnd.isAfter(targetStart);
  }

  factory ReservationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ReservationModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory ReservationModel.fromMap(String id, Map<String, dynamic> data) {
    // Normalizar restauranteId (puede ser DocumentReference o String)
    String restId = '';
    final rawRestId = data['restauranteId'];
    if (rawRestId is DocumentReference) {
      restId = rawRestId.id;
    } else if (rawRestId is String) {
      restId = rawRestId;
    }

    // Normalizar usuarioId
    String usrId = '';
    final rawUsrId = data['usuarioId'];
    if (rawUsrId is DocumentReference) {
      usrId = rawUsrId.id;
    } else if (rawUsrId is String) {
      usrId = rawUsrId;
    }

    // Contacto
    final contactoMap = data['contacto'] as Map<String, dynamic>? ?? {};

    // Timestamps
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    // Mesas
    final rawMesaIds = data['mesaIds'] as List<dynamic>? ?? [];
    final mesaIdsList = <String>[];
    for (final m in rawMesaIds) {
      if (m is DocumentReference) {
        mesaIdsList.add(m.id);
      } else if (m is String) {
        mesaIdsList.add(m);
      }
    }

    return ReservationModel(
      id: id,
      restauranteId: restId,
      usuarioId: usrId,
      restauranteNombre: (data['restauranteNombre'] as String?) ?? '',
      contactoNombre: (contactoMap['nombre'] as String?) ?? '',
      contactoCorreo: (contactoMap['correo'] as String?) ?? '',
      contactoTelefono: (contactoMap['telefono'] as String?) ?? '',
      fechaLocal: (data['fechaLocal'] as String?) ?? '',
      inicio: parseTimestamp(data['inicio']),
      fin: parseTimestamp(data['fin']),
      duracionMin: (data['duracionMin'] as num?)?.toInt() ?? 90,
      personas: (data['personas'] as num?)?.toInt() ?? 2,
      mesaIds: mesaIdsList,
      mesasNombres: List<String>.from(data['mesasNombres'] as List<dynamic>? ?? []),
      estado: (data['estado'] as String?) ?? 'confirmada',
      creadaEn: parseTimestamp(data['creadaEn']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restauranteId': restauranteId,
      'usuarioId': usuarioId,
      'restauranteNombre': restauranteNombre,
      'contacto': {
        'nombre': contactoNombre,
        'correo': contactoCorreo,
        'telefono': contactoTelefono,
      },
      'fechaLocal': fechaLocal,
      'inicio': inicio != null ? Timestamp.fromDate(inicio!) : null,
      'fin': fin != null ? Timestamp.fromDate(fin!) : null,
      'duracionMin': duracionMin,
      'personas': personas,
      'mesaIds': mesaIds,
      'mesasNombres': mesasNombres,
      'estado': estado,
      'creadaEn': creadaEn != null
          ? Timestamp.fromDate(creadaEn!)
          : FieldValue.serverTimestamp(),
    };
  }

  ReservationModel copyWith({
    String? id,
    String? restauranteId,
    String? usuarioId,
    String? restauranteNombre,
    String? contactoNombre,
    String? contactoCorreo,
    String? contactoTelefono,
    String? fechaLocal,
    DateTime? inicio,
    DateTime? fin,
    int? duracionMin,
    int? personas,
    List<String>? mesaIds,
    List<String>? mesasNombres,
    String? estado,
    DateTime? creadaEn,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      restauranteId: restauranteId ?? this.restauranteId,
      usuarioId: usuarioId ?? this.usuarioId,
      restauranteNombre: restauranteNombre ?? this.restauranteNombre,
      contactoNombre: contactoNombre ?? this.contactoNombre,
      contactoCorreo: contactoCorreo ?? this.contactoCorreo,
      contactoTelefono: contactoTelefono ?? this.contactoTelefono,
      fechaLocal: fechaLocal ?? this.fechaLocal,
      inicio: inicio ?? this.inicio,
      fin: fin ?? this.fin,
      duracionMin: duracionMin ?? this.duracionMin,
      personas: personas ?? this.personas,
      mesaIds: mesaIds ?? this.mesaIds,
      mesasNombres: mesasNombres ?? this.mesasNombres,
      estado: estado ?? this.estado,
      creadaEn: creadaEn ?? this.creadaEn,
    );
  }
}
