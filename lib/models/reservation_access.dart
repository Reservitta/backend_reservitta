import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'reservation_model.dart';
import 'reservation_status_flow.dart';

/// Token único y enlace para gestionar una reserva sin iniciar sesión (HU20-RF01).
class ReservationAccess {
  const ReservationAccess._();

  /// Sin caracteres que se confunden (0/O, 1/I/L).
  static const String _alfabeto = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Longitud del token: 20 caracteres de un alfabeto de 31 (~99 bits), imposible
  /// de adivinar por fuerza bruta (HU20-RNF01).
  static const int longitud = 20;

  /// Dirección base del enlace. En web se usa el origen de la app; en otras
  /// plataformas, esta URL (se puede cambiar al desplegar).
  static String baseUrl = 'https://reservitta.app';

  /// Genera un token aleatorio criptográficamente seguro.
  static String generarToken({Random? random}) {
    final rng = random ?? Random.secure();
    return List.generate(longitud, (_) => _alfabeto[rng.nextInt(_alfabeto.length)])
        .join();
  }

  /// Deja el código como se guarda: mayúsculas y sin guiones, espacios ni símbolos.
  static String normalizar(String codigo) =>
      codigo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// ¿Tiene la forma de un token válido? (no consulta nada).
  static bool esValido(String codigo) {
    final n = normalizar(codigo);
    return n.length == longitud && n.split('').every(_alfabeto.contains);
  }

  /// Código corto legible, en grupos de cuatro: ABCD-EFGH-JKMN-PQRS-TUVW.
  static String formatear(String token) {
    final n = normalizar(token);
    return [
      for (var i = 0; i < n.length; i += 4)
        n.substring(i, min(i + 4, n.length)),
    ].join('-');
  }

  /// Enlace que abre la gestión de la reserva.
  static String enlace(String token, {String? base}) {
    final origen = base ?? (kIsWeb ? Uri.base.origin : baseUrl);
    return '${origen.replaceAll(RegExp(r'/+$'), '')}/?reserva=${normalizar(token)}';
  }

  /// Token que viene en el enlace (`?reserva=...`), o null si no hay.
  static String? tokenDeEnlace(Uri uri) {
    final valor = uri.queryParameters['reserva'];
    if (valor == null || valor.trim().isEmpty) return null;
    final n = normalizar(valor);
    return n.isEmpty ? null : n;
  }

  /// El token vale hasta el final del día siguiente a la visita (HU20-RF01 Criterio 4).
  static DateTime expiracion(String fechaLocal, DateTime respaldo) {
    final p = fechaLocal.split('-');
    final y = p.length == 3 ? int.tryParse(p[0]) : null;
    final m = p.length == 3 ? int.tryParse(p[1]) : null;
    final d = p.length == 3 ? int.tryParse(p[2]) : null;
    final dia = (y != null && m != null && d != null)
        ? DateTime(y, m, d)
        : DateTime(respaldo.year, respaldo.month, respaldo.day);
    return DateTime(dia.year, dia.month, dia.day + 2);
  }
}

/// Regla de tiempo límite para cancelar o modificar (HU20-RF02).
class ReservationChangePolicy {
  /// Minutos antes de la hora de la reserva hasta los que se permite cambiar.
  final int limiteMin;

  const ReservationChangePolicy({this.limiteMin = 120});

  /// Último momento en que se puede cancelar o modificar.
  DateTime limite(DateTime inicio) =>
      inicio.subtract(Duration(minutes: limiteMin));

  bool permite(DateTime inicio, DateTime ahora) =>
      !ahora.isAfter(limite(inicio));

  String get _textoLimite {
    if (limiteMin % 60 == 0) {
      final h = limiteMin ~/ 60;
      return '$h ${h == 1 ? 'hora' : 'horas'}';
    }
    return '$limiteMin minutos';
  }

  /// Mensaje claro cuando ya pasó el límite (HU20-RF02 Criterio 2).
  String get mensajeFueraDeTiempo =>
      'Ya no puedes cancelar ni modificar esta reserva: solo se permite hasta '
      '$_textoLimite antes de la hora reservada. Comunícate con el restaurante.';
}

/// Por qué una reserva no se puede gestionar con el enlace.
enum ManagementFailure {
  noEncontrada,
  expirada,
  fueraDeTiempo,
  estadoNoPermitido,
  disponibilidad,
  datosInvalidos,
}

class ManagementException implements Exception {
  final ManagementFailure failure;
  final String message;

  const ManagementException(this.failure, this.message);

  @override
  String toString() => 'ManagementException($failure): $message';
}

/// Lo que ve quien abre el enlace (HU20-RF01 Criterio 3): solo su reserva, sin
/// datos de contacto ni de otras reservas.
class ManagedReservation {
  final String token;
  final String reservaId;
  final String restauranteId;
  final String restauranteNombre;
  final String fechaLocal;
  final DateTime inicio;
  final DateTime fin;
  final int duracionMin;
  final int personas;
  final List<String> mesaIds;
  final List<String> mesasNombres;
  final String estado;
  final DateTime expiraEn;

  const ManagedReservation({
    required this.token,
    required this.reservaId,
    required this.restauranteId,
    required this.restauranteNombre,
    required this.fechaLocal,
    required this.inicio,
    required this.fin,
    required this.duracionMin,
    required this.personas,
    required this.mesaIds,
    required this.mesasNombres,
    required this.estado,
    required this.expiraEn,
  });

  factory ManagedReservation.fromMap(String token, Map<String, dynamic> data) {
    DateTime fecha(Object? v, DateTime respaldo) =>
        v is Timestamp ? v.toDate() : (v is DateTime ? v : respaldo);
    final inicio = fecha(data['inicio'], DateTime.fromMillisecondsSinceEpoch(0));
    final duracion = (data['duracionMin'] as num?)?.toInt() ?? 90;
    return ManagedReservation(
      token: token,
      reservaId: (data['reservaId'] as String?) ?? '',
      restauranteId: (data['restauranteId'] as String?) ?? '',
      restauranteNombre: (data['restauranteNombre'] as String?) ?? '',
      fechaLocal: (data['fechaLocal'] as String?) ?? '',
      inicio: inicio,
      fin: fecha(data['fin'], inicio.add(Duration(minutes: duracion))),
      duracionMin: duracion,
      personas: (data['personas'] as num?)?.toInt() ?? 1,
      mesaIds: [for (final m in (data['mesaIds'] as List? ?? const [])) m.toString()],
      mesasNombres: [
        for (final m in (data['mesasNombres'] as List? ?? const [])) m.toString(),
      ],
      estado: (data['estado'] as String?) ?? ReservationModel.estadoConfirmada,
      expiraEn: fecha(data['expiraEn'], DateTime.fromMillisecondsSinceEpoch(0)),
    );
  }

  /// Datos de la reserva que se publican en el documento de gestión: solo lo
  /// necesario para mostrar el resumen (sin contacto ni preorden).
  static Map<String, dynamic> proyeccion(ReservationModel r, DateTime expiraEn) => {
        'reservaId': r.id,
        'restauranteId': r.restauranteId,
        'restauranteNombre': r.restauranteNombre,
        'usuarioId': r.usuarioId,
        'fechaLocal': r.fechaLocal,
        'inicio': r.inicio != null ? Timestamp.fromDate(r.inicio!) : null,
        'fin': r.fin != null ? Timestamp.fromDate(r.fin!) : null,
        'duracionMin': r.duracionMin,
        'personas': r.personas,
        'mesaIds': r.mesaIds,
        'mesasNombres': r.mesasNombres,
        'estado': r.estadoOperativo,
        'expiraEn': Timestamp.fromDate(expiraEn),
        'creadaEn': FieldValue.serverTimestamp(),
      };

  String get estadoOperativo => ReservationStateMachine.normalizar(estado);
  bool get estaCancelada => estadoOperativo == ReservationModel.estadoCancelada;
  bool estaExpirada(DateTime ahora) => ahora.isAfter(expiraEn);

  /// Mesas para mostrar ("M1 + M2").
  String get mesasTexto =>
      (mesasNombres.isNotEmpty ? mesasNombres : mesaIds).join(' + ');

  /// Motivo por el que no se puede cancelar ni modificar; null si sí se puede.
  ManagementException? motivoNoGestionable(
    DateTime ahora, {
    ReservationChangePolicy politica = const ReservationChangePolicy(),
  }) {
    if (estaExpirada(ahora)) {
      return const ManagementException(
        ManagementFailure.expirada,
        'Este enlace ya no es válido. Comunícate con el restaurante.',
      );
    }
    if (estaCancelada) {
      return const ManagementException(
        ManagementFailure.estadoNoPermitido,
        'Esta reserva ya fue cancelada.',
      );
    }
    if (estadoOperativo != ReservationModel.estadoPendienteLlegada) {
      return const ManagementException(
        ManagementFailure.estadoNoPermitido,
        'Esta reserva ya no se puede cambiar porque ya fue atendida o cerrada.',
      );
    }
    if (!politica.permite(inicio, ahora)) {
      return ManagementException(
        ManagementFailure.fueraDeTiempo,
        politica.mensajeFueraDeTiempo,
      );
    }
    return null;
  }

  bool puedeGestionar(
    DateTime ahora, {
    ReservationChangePolicy politica = const ReservationChangePolicy(),
  }) =>
      motivoNoGestionable(ahora, politica: politica) == null;
}
