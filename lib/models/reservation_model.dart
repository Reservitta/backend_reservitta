import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo inmutable de Reservación para gestión de reservaciones, disponibilidad y bloqueo de mesas
/// Implementación de HU08-RF02 y HU03-RF01.
class ReservationModel {
  // Constantes de estado (HU08-RF02 Criterio 1)
  static const String estadoPendiente = 'pendiente';
  static const String estadoConfirmada = 'confirmada';
  static const String estadoCancelada = 'cancelada';

  /// Lista exhaustiva de estados oficiales permitidos
  static const List<String> estadosValidos = [
    estadoPendiente,
    estadoConfirmada,
    estadoCancelada,
  ];

  /// Valida si una cadena coincide con un estado oficial admitido
  static bool isValidStatus(String? status) {
    if (status == null) return false;
    final normalized = status.trim().toLowerCase();
    return estadosValidos.contains(normalized);
  }

  /// Criterio 2: La hora de fin se calcula como hora de inicio + duración.
  static DateTime calculateEndTime({
    required DateTime inicio,
    required int duracionMin,
  }) {
    final minutes = duracionMin > 0 ? duracionMin : 90;
    return inicio.add(Duration(minutes: minutes));
  }

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
  final String estado; // 'pendiente', 'confirmada', 'cancelada'
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
    this.estado = estadoConfirmada,
    this.creadaEn,
  });

  /// Constructor factoría para instanciación con cálculo automático de hora de fin (Criterio 2)
  factory ReservationModel.create({
    required String id,
    required String restauranteId,
    String usuarioId = '',
    String restauranteNombre = '',
    String contactoNombre = '',
    String contactoCorreo = '',
    String contactoTelefono = '',
    required String fechaLocal,
    DateTime? inicio,
    DateTime? fin,
    int duracionMin = 90,
    int personas = 2,
    List<String> mesaIds = const [],
    List<String> mesasNombres = const [],
    String estado = estadoPendiente,
    DateTime? creadaEn,
  }) {
    final effectiveFin = fin ??
        (inicio != null
            ? calculateEndTime(inicio: inicio, duracionMin: duracionMin)
            : null);

    return ReservationModel(
      id: id,
      restauranteId: restauranteId,
      usuarioId: usuarioId,
      restauranteNombre: restauranteNombre,
      contactoNombre: contactoNombre,
      contactoCorreo: contactoCorreo,
      contactoTelefono: contactoTelefono,
      fechaLocal: fechaLocal,
      inicio: inicio,
      fin: effectiveFin,
      duracionMin: duracionMin,
      personas: personas,
      mesaIds: mesaIds,
      mesasNombres: mesasNombres,
      estado: estado,
      creadaEn: creadaEn,
    );
  }

  /// Alias semántico para cantidad de personas (Criterio 1)
  int get cantidadPersonas => personas;

  /// Criterio 3: Solo las reservaciones con estado activo (pendiente/confirmada) bloquean mesas.
  bool get bloqueaMesas {
    final st = estado.trim().toLowerCase();
    return st == estadoPendiente || st == estadoConfirmada;
  }

  /// Alias de compatibilidad: indica si la reservación está activa y ocupa lugares
  bool get isActiva => bloqueaMesas;

  /// Indica si el estado actual es 'pendiente'
  bool get isPendiente => estado.trim().toLowerCase() == estadoPendiente;

  /// Indica si el estado actual es 'confirmada'
  bool get isConfirmada => estado.trim().toLowerCase() == estadoConfirmada;

  /// Indica si el estado actual es 'cancelada'
  bool get isCancelada => estado.trim().toLowerCase() == estadoCancelada;

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

  /// Retorna la hora de fin efectiva calculada como hora de inicio + duración (Criterio 2)
  DateTime get effectiveEnd {
    if (fin != null) return fin!;
    return calculateEndTime(inicio: effectiveStart, duracionMin: duracionMin);
  }

  /// Determina si esta reservación se traslapa con un intervalo de tiempo dado.
  /// Criterio 3: Si no tiene estado activo (pendiente o confirmada), no bloquea y retorna false.
  bool overlapsWith(DateTime targetDateTime, {int durationMin = 90}) {
    if (!bloqueaMesas) return false;

    final targetStart = targetDateTime;
    final targetEnd = targetDateTime.add(
      Duration(minutes: durationMin > 0 ? durationMin : 90),
    );

    final resStart = effectiveStart;
    final resEnd = effectiveEnd;

    // Dos intervalos [A, B) y [C, D) se traslapan si A < D y B > C
    return resStart.isBefore(targetEnd) && resEnd.isAfter(targetStart);
  }

  /// Criterio 3: Verifica si una mesa específica está bloqueada por esta reservación en [targetDateTime]
  bool isTableBlocked(
    String mesaId, {
    required DateTime targetDateTime,
    int durationMin = 90,
  }) {
    if (!bloqueaMesas) return false;
    if (!mesaIds.contains(mesaId)) return false;
    return overlapsWith(targetDateTime, durationMin: durationMin);
  }

  /// Criterio 3: Verifica si alguna de las mesas en [targetMesaIds] está bloqueada por esta reservación
  bool anyTableBlocked(
    Iterable<String> targetMesaIds, {
    required DateTime targetDateTime,
    int durationMin = 90,
  }) {
    if (!bloqueaMesas) return false;
    final hasTableMatch = targetMesaIds.any((id) => mesaIds.contains(id));
    if (!hasTableMatch) return false;
    return overlapsWith(targetDateTime, durationMin: durationMin);
  }

  factory ReservationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ReservationModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory ReservationModel.fromMap(String id, Map<String, dynamic> data) {
    // Normalizar restauranteId (puede ser DocumentReference o String, con clave 'restauranteId' o 'restaurante')
    String restId = '';
    final rawRestId = data['restauranteId'] ?? data['restaurante'];
    if (rawRestId is DocumentReference) {
      restId = rawRestId.id;
    } else if (rawRestId is String) {
      restId = rawRestId;
    }

    // Normalizar usuarioId
    String usrId = '';
    final rawUsrId = data['usuarioId'] ?? data['usuario'];
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

    final inicioParsed = parseTimestamp(data['inicio']);
    final duracionParsed = (data['duracionMin'] as num?)?.toInt() ?? 90;

    // Criterio 2: La hora de fin se calcula como inicio + duración si no está explícita
    final finParsed = parseTimestamp(data['fin']) ??
        (inicioParsed != null
            ? calculateEndTime(inicio: inicioParsed, duracionMin: duracionParsed)
            : null);

    // Mesas (soporta 'mesaIds' o 'mesas')
    final rawMesaIds = (data['mesaIds'] ?? data['mesas']) as List<dynamic>? ?? [];
    final mesaIdsList = <String>[];
    for (final m in rawMesaIds) {
      if (m is DocumentReference) {
        mesaIdsList.add(m.id);
      } else if (m is String) {
        mesaIdsList.add(m);
      }
    }

    // Fecha (soporta 'fechaLocal' o 'fecha')
    String fechaStr = '';
    final rawFecha = data['fechaLocal'] ?? data['fecha'];
    if (rawFecha is String) {
      fechaStr = rawFecha;
    } else if (rawFecha is Timestamp) {
      final dt = rawFecha.toDate();
      fechaStr = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } else if (rawFecha is DateTime) {
      fechaStr = '${rawFecha.year.toString().padLeft(4, '0')}-${rawFecha.month.toString().padLeft(2, '0')}-${rawFecha.day.toString().padLeft(2, '0')}';
    }

    // Cantidad de personas (soporta 'personas' o 'cantidadPersonas')
    final personasCount = (data['personas'] ?? data['cantidadPersonas'] ?? data['cantidad_personas'] as num?)?.toInt() ?? 2;

    return ReservationModel(
      id: id,
      restauranteId: restId,
      usuarioId: usrId,
      restauranteNombre: (data['restauranteNombre'] as String?) ?? '',
      contactoNombre: (contactoMap['nombre'] as String?) ?? '',
      contactoCorreo: (contactoMap['correo'] as String?) ?? '',
      contactoTelefono: (contactoMap['telefono'] as String?) ?? '',
      fechaLocal: fechaStr,
      inicio: inicioParsed,
      fin: finParsed,
      duracionMin: duracionParsed,
      personas: personasCount,
      mesaIds: mesaIdsList,
      mesasNombres: List<String>.from(data['mesasNombres'] as List<dynamic>? ?? []),
      estado: (data['estado'] as String?) ?? estadoConfirmada,
      creadaEn: parseTimestamp(data['creadaEn']),
    );
  }

  Map<String, dynamic> toMap() {
    // Criterio 2: Asegurar cálculo de fin al serializar
    final effectiveFin = fin ??
        (inicio != null
            ? calculateEndTime(inicio: inicio!, duracionMin: duracionMin)
            : null);

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
      'fin': effectiveFin != null ? Timestamp.fromDate(effectiveFin) : null,
      'duracionMin': duracionMin,
      'personas': personas,
      'cantidadPersonas': personas,
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
