import '../models/reservation_model.dart';

/// Formato JSON estándar de notificación para confirmaciones (HU19) y recordatorios (HU21).
///
/// Cumple con los criterios de aceptación de HU14-RF03 [#49]:
/// - Datos de contacto (nombre, correo, teléfono, canal preferido).
/// - Restaurante (id, nombre, dirección, sucursal si aplica).
/// - Fecha y horario.
/// - Duración y cantidad de personas.
/// - Mesa(s) asignada(s).
/// - Resumen de preorden (si aplica, HU15/HU16).
/// - Resumen de ocasión especial (si aplica, HU15/HU16).
/// - Alergias y notas.
class ReservationNotificationPayload {
  static const String tipoConfirmacion = 'confirmacion';
  static const String tipoRecordatorio = 'recordatorio';

  static const String canalEmail = 'email';
  static const String canalWhatsApp = 'whatsapp';

  final String reservaId;
  final String estadoReserva;
  final String tipo; // 'confirmacion' o 'recordatorio'
  final String contactoNombre;
  final String contactoCorreo;
  final String contactoTelefono;
  final String canalPreferido; // 'email' o 'whatsapp'
  final String restauranteId;
  final String restauranteNombre;
  final String restauranteDireccion;
  final String sucursalId;
  final String sucursalNombre;
  final String fecha; // 'YYYY-MM-DD' o fecha legible
  final String horario; // ej. '14:00' o '14:00 – 15:30'
  final int duracionMin;
  final int personas;
  final List<String> mesas;
  final List<Map<String, dynamic>> preordenItems;
  final Map<String, dynamic>? ocasionEspecial;
  final List<String> alergias;
  final String notas;
  final String usuarioId;

  const ReservationNotificationPayload({
    required this.reservaId,
    required this.estadoReserva,
    this.tipo = tipoConfirmacion,
    required this.contactoNombre,
    this.contactoCorreo = '',
    this.contactoTelefono = '',
    this.canalPreferido = canalEmail,
    required this.restauranteId,
    required this.restauranteNombre,
    this.restauranteDireccion = '',
    this.sucursalId = '',
    this.sucursalNombre = '',
    required this.fecha,
    required this.horario,
    this.duracionMin = 90,
    this.personas = 2,
    this.mesas = const [],
    this.preordenItems = const [],
    this.ocasionEspecial,
    this.alergias = const [],
    this.notas = '',
    this.usuarioId = '',
  });

  /// Crea una instancia del payload directamente desde un [ReservationModel]
  factory ReservationNotificationPayload.fromReservation(
    ReservationModel reservation, {
    String tipo = tipoConfirmacion,
    String canalPreferido = canalEmail,
    String notas = '',
    String sucursalId = '',
    String sucursalNombre = '',
  }) {
    final horaTexto = reservation.horaInicioFormateada.isNotEmpty
        ? reservation.horaInicioFormateada
        : (reservation.inicio != null
            ? '${reservation.inicio!.hour.toString().padLeft(2, '0')}:${reservation.inicio!.minute.toString().padLeft(2, '0')}'
            : '');

    final mesasNombres = reservation.mesasNombres.isNotEmpty
        ? reservation.mesasNombres
        : reservation.mesaIds;

    return ReservationNotificationPayload(
      reservaId: reservation.id,
      estadoReserva: reservation.estado,
      tipo: tipo,
      contactoNombre: reservation.contactoNombre,
      contactoCorreo: reservation.contactoCorreo,
      contactoTelefono: reservation.contactoTelefono,
      canalPreferido: canalPreferido,
      restauranteId: reservation.restauranteId,
      restauranteNombre: reservation.restauranteNombre,
      sucursalId: sucursalId,
      sucursalNombre: sucursalNombre,
      fecha: reservation.fechaLocal,
      horario: horaTexto,
      duracionMin: reservation.duracionMin,
      personas: reservation.personas,
      mesas: List<String>.from(mesasNombres),
      preordenItems: List<Map<String, dynamic>>.from(reservation.preordenItems),
      ocasionEspecial: reservation.ocasionEspecial != null
          ? Map<String, dynamic>.from(reservation.ocasionEspecial!)
          : null,
      alergias: List<String>.from(reservation.alergias),
      notas: notas.isNotEmpty ? notas : reservation.notasAlergias,
      usuarioId: reservation.usuarioId,
    );
  }

  /// Indica si la reserva cumple el Criterio 5 (está confirmada)
  bool get isReservaConfirmada =>
      ReservationModel.normalizeStatus(estadoReserva) ==
      ReservationModel.estadoConfirmada;

  bool get tienePreorden => preordenItems.isNotEmpty;
  bool get tieneOcasionEspecial => ocasionEspecial != null;
  bool get tieneAlergias => alergias.isNotEmpty;

  bool get hasPreorden => tienePreorden;
  bool get hasOcasionEspecial => tieneOcasionEspecial;
  bool get hasAlergias => tieneAlergias;

  double get preordenTotal => preordenItems.fold(
        0.0,
        (acc, item) =>
            acc +
            ((item['precio'] as num? ?? 0.0).toDouble() *
                ((item['cantidad'] as num? ?? 1).toInt())),
      );

  /// Serialización a Map estándar JSON (Criterio 1)
  Map<String, dynamic> toMap() {
    return {
      'reservaId': reservaId,
      'estadoReserva': estadoReserva,
      'tipo': tipo,
      'contacto': {
        'nombre': contactoNombre.trim(),
        'correo': contactoCorreo.trim().toLowerCase(),
        'telefono': contactoTelefono.trim(),
        'canalPreferido': canalPreferido,
      },
      'restaurante': {
        'id': restauranteId,
        'nombre': restauranteNombre.trim(),
        'direccion': restauranteDireccion.trim(),
        'sucursalId': sucursalId,
        'sucursalNombre': sucursalNombre,
      },
      'fecha': fecha,
      'horario': horario,
      'duracionMin': duracionMin,
      'personas': personas,
      'mesas': mesas,
      if (tienePreorden) 'preorden': preordenItems,
      if (tieneOcasionEspecial) 'ocasionEspecial': ocasionEspecial,
      if (tieneAlergias) 'alergias': alergias,
      if (notas.isNotEmpty) 'notas': notas,
      if (usuarioId.isNotEmpty) 'usuarioId': usuarioId,
    };
  }

  /// Deserialización desde Map JSON
  factory ReservationNotificationPayload.fromMap(Map<String, dynamic> map) {
    final contactoMap = (map['contacto'] as Map<String, dynamic>?) ?? {};
    final restMap = (map['restaurante'] as Map<String, dynamic>?) ?? {};

    return ReservationNotificationPayload(
      reservaId: map['reservaId'] as String? ?? '',
      estadoReserva: map['estadoReserva'] as String? ?? '',
      tipo: map['tipo'] as String? ?? tipoConfirmacion,
      contactoNombre: contactoMap['nombre'] as String? ?? '',
      contactoCorreo: contactoMap['correo'] as String? ?? '',
      contactoTelefono: contactoMap['telefono'] as String? ?? '',
      canalPreferido: contactoMap['canalPreferido'] as String? ?? canalEmail,
      restauranteId: restMap['id'] as String? ?? '',
      restauranteNombre: restMap['nombre'] as String? ?? '',
      restauranteDireccion: restMap['direccion'] as String? ?? '',
      sucursalId: restMap['sucursalId'] as String? ?? '',
      sucursalNombre: restMap['sucursalNombre'] as String? ?? '',
      fecha: map['fecha'] as String? ?? '',
      horario: map['horario'] as String? ?? '',
      duracionMin: (map['duracionMin'] as num?)?.toInt() ?? 90,
      personas: (map['personas'] as num?)?.toInt() ?? 2,
      mesas: (map['mesas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      preordenItems: (map['preorden'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      ocasionEspecial: map['ocasionEspecial'] != null
          ? Map<String, dynamic>.from(map['ocasionEspecial'] as Map)
          : null,
      alergias: (map['alergias'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notas: map['notas'] as String? ?? '',
      usuarioId: map['usuarioId'] as String? ?? '',
    );
  }

  ReservationNotificationPayload copyWith({
    String? reservaId,
    String? estadoReserva,
    String? tipo,
    String? contactoNombre,
    String? contactoCorreo,
    String? contactoTelefono,
    String? canalPreferido,
    String? restauranteId,
    String? restauranteNombre,
    String? restauranteDireccion,
    String? sucursalId,
    String? sucursalNombre,
    String? fecha,
    String? horario,
    int? duracionMin,
    int? personas,
    List<String>? mesas,
    List<Map<String, dynamic>>? preordenItems,
    Map<String, dynamic>? Function()? ocasionEspecial,
    List<String>? alergias,
    String? notas,
    String? usuarioId,
  }) {
    return ReservationNotificationPayload(
      reservaId: reservaId ?? this.reservaId,
      estadoReserva: estadoReserva ?? this.estadoReserva,
      tipo: tipo ?? this.tipo,
      contactoNombre: contactoNombre ?? this.contactoNombre,
      contactoCorreo: contactoCorreo ?? this.contactoCorreo,
      contactoTelefono: contactoTelefono ?? this.contactoTelefono,
      canalPreferido: canalPreferido ?? this.canalPreferido,
      restauranteId: restauranteId ?? this.restauranteId,
      restauranteNombre: restauranteNombre ?? this.restauranteNombre,
      restauranteDireccion: restauranteDireccion ?? this.restauranteDireccion,
      sucursalId: sucursalId ?? this.sucursalId,
      sucursalNombre: sucursalNombre ?? this.sucursalNombre,
      fecha: fecha ?? this.fecha,
      horario: horario ?? this.horario,
      duracionMin: duracionMin ?? this.duracionMin,
      personas: personas ?? this.personas,
      mesas: mesas ?? this.mesas,
      preordenItems: preordenItems ?? this.preordenItems,
      ocasionEspecial: ocasionEspecial != null ? ocasionEspecial() : this.ocasionEspecial,
      alergias: alergias ?? this.alergias,
      notas: notas ?? this.notas,
      usuarioId: usuarioId ?? this.usuarioId,
    );
  }
}
