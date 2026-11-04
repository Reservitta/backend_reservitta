import 'package:flutter/material.dart';
import 'branch_model.dart';
import 'reservation_contact_model.dart';
import '../utils/schedule_utils.dart';
import 'restaurant_model.dart';

/// Modelo de borrador de reservación para el flujo de reserva (HU07-RF01 y HU13-RF03).
/// Guarda de forma incremental los datos elegidos por el usuario:
/// sucursal, fecha, duración, cantidad de personas, mesa(s), horario
/// y datos de contacto (HU13).
///
/// Además soporta personalización de la visita (HU15-RF01, HU15-RF02, HU16):
/// preorden de platillos, especificación de alergias y ocasión especial.
///
/// La contraseña NO forma parte del borrador (HU14-RF01): solo vive en memoria
/// en el ViewModel hasta que se crea la cuenta.
class ReservationDraftModel {
  final RestaurantModel restaurant;
  final BranchModel? branch;
  final DateTime? fecha;
  final int duracionMin;
  final int personas;
  final List<String> mesaIds;
  final List<String> mesasNombres;
  final TimeOfDay? horario;

  // HU13: Datos de contacto (soporta modelo de objeto o campos primitivos)
  final ReservationContactModel? _explicitContactData;
  final String _contactoNombre;
  final String _contactoCorreo;
  final String _contactoTelefono;
  final bool _crearCuenta;

  // HU15-RF02 / HU16: Datos opcionales de personalización de la visita
  final List<Map<String, dynamic>> preordenItems;
  final List<String> alergias;
  final String notasAlergias;
  final Map<String, dynamic>? ocasionEspecial;
  final List<Map<String, dynamic>> experiencias;

  const ReservationDraftModel({
    required this.restaurant,
    this.branch,
    this.fecha,
    this.duracionMin = 90, // Sugerida por defecto: 1 h 30 min (HU08-RF01)
    this.personas = 2, // Mínimo 1 (HU09-RF01)
    this.mesaIds = const [],
    this.mesasNombres = const [],
    this.horario,
    ReservationContactModel? contactData,
    String contactoNombre = '',
    String contactoCorreo = '',
    String contactoTelefono = '',
    bool crearCuenta = false,
    this.preordenItems = const [],
    this.alergias = const [],
    this.notasAlergias = '',
    this.ocasionEspecial,
    this.experiencias = const [],
  })  : _explicitContactData = contactData,
        _contactoNombre = contactoNombre,
        _contactoCorreo = contactoCorreo,
        _contactoTelefono = contactoTelefono,
        _crearCuenta = crearCuenta;

  /// Retorna los datos de contacto estructurados
  ReservationContactModel? get contactData {
    if (_explicitContactData != null) return _explicitContactData;
    if (_contactoNombre.isNotEmpty || _contactoCorreo.isNotEmpty || _contactoTelefono.isNotEmpty) {
      return ReservationContactModel(
        nombre: _contactoNombre,
        correo: _contactoCorreo,
        telefono: _contactoTelefono,
        solicitaCrearCuenta: _crearCuenta,
      );
    }
    return null;
  }

  // Getters de conveniencia y compatibilidad con HU13-RF01 / HU13-RF03
  String get contactoNombre => _explicitContactData?.nombre ?? _contactoNombre;
  String get contactoCorreo => _explicitContactData?.correo ?? _contactoCorreo;
  String get contactoTelefono => _explicitContactData?.telefono ?? _contactoTelefono;
  String get contactoNotas => _explicitContactData?.notas ?? '';
  bool get crearCuenta => _explicitContactData?.solicitaCrearCuenta ?? _crearCuenta;
  bool get solicitaCrearCuenta => crearCuenta;

  // HU13-RF01: getters y alias de datos de contacto
  String get contactNombre => contactoNombre;
  String get contactCorreo => contactoCorreo;
  String get contactTelefono => contactoTelefono;
  bool get hasValidContactData =>
      contactoNombre.trim().isNotEmpty &&
      contactoCorreo.trim().isNotEmpty &&
      contactoTelefono.trim().isNotEmpty;
  bool get hasContactData =>
      (_explicitContactData != null && _explicitContactData!.isNotEmpty) ||
      hasValidContactData;

  /// Crea una copia inmutable actualizando únicamente los campos provistos.
  ReservationDraftModel copyWith({
    RestaurantModel? restaurant,
    BranchModel? Function()? branch,
    DateTime? Function()? fecha,
    int? duracionMin,
    int? personas,
    List<String>? mesaIds,
    List<String>? mesasNombres,
    TimeOfDay? Function()? horario,
    ReservationContactModel? Function()? contactData,
    String? contactoNombre,
    String? contactoCorreo,
    String? contactoTelefono,
    bool? crearCuenta,
    List<Map<String, dynamic>>? preordenItems,
    List<String>? alergias,
    String? notasAlergias,
    Map<String, dynamic>? Function()? ocasionEspecial,
    List<Map<String, dynamic>>? experiencias,
  }) {
    final nextContact = contactData != null ? contactData() : _explicitContactData;

    return ReservationDraftModel(
      restaurant: restaurant ?? this.restaurant,
      branch: branch != null ? branch() : this.branch,
      fecha: fecha != null ? fecha() : this.fecha,
      duracionMin: duracionMin ?? this.duracionMin,
      personas: personas ?? this.personas,
      mesaIds: mesaIds ?? this.mesaIds,
      mesasNombres: mesasNombres ?? this.mesasNombres,
      horario: horario != null ? horario() : this.horario,
      contactData: nextContact,
      contactoNombre: contactoNombre ?? (nextContact?.nombre ?? this.contactoNombre),
      contactoCorreo: contactoCorreo ?? (nextContact?.correo ?? this.contactoCorreo),
      contactoTelefono: contactoTelefono ?? (nextContact?.telefono ?? this.contactoTelefono),
      crearCuenta: crearCuenta ?? (nextContact?.solicitaCrearCuenta ?? this.crearCuenta),
      preordenItems: preordenItems ?? this.preordenItems,
      alergias: alergias ?? this.alergias,
      notasAlergias: notasAlergias ?? this.notasAlergias,
      ocasionEspecial: ocasionEspecial != null ? ocasionEspecial() : this.ocasionEspecial,
      experiencias: experiencias ?? this.experiencias,
    );
  }

  /// Limpia los campos de selección manteniendo el restaurante inicial.
  /// Los valores por defecto vacían también el contacto y desmarcan la cuenta.
  ReservationDraftModel clear() {
    return ReservationDraftModel(
      restaurant: restaurant,
      branch: null,
      fecha: null,
      duracionMin: 90,
      personas: 2,
      mesaIds: const [],
      mesasNombres: const [],
      horario: null,
      contactData: null,
      contactoNombre: '',
      contactoCorreo: '',
      contactoTelefono: '',
      crearCuenta: false,
      preordenItems: const [],
      alergias: const [],
      notasAlergias: '',
      ocasionEspecial: null,
      experiencias: const [],
    );
  }

  // Getters de validación por paso
  bool get hasBranch => branch != null;
  bool get hasDate => fecha != null;
  bool get hasDuration => duracionMin >= 30;
  bool get hasPeople => personas >= 1;
  bool get hasTables => mesaIds.isNotEmpty;
  bool get hasTime => horario != null;

  /// Indica si el borrador cuenta con todos los datos necesarios para el resumen (HU12-RF01).
  bool get isReadyForSummary =>
      hasDate && hasDuration && hasPeople && hasTables && hasTime;

  // HU15-RF02 / HU16: Getters de personalización
  bool get tienePersonalizacion =>
      preordenItems.isNotEmpty ||
      alergias.isNotEmpty ||
      notasAlergias.trim().isNotEmpty ||
      ocasionEspecial != null ||
      experiencias.isNotEmpty;

  double get subtotalPreorden {
    return preordenItems.fold<double>(0.0, (acc, item) {
      final total = (item['total'] as num?)?.toDouble();
      if (total != null) return acc + total;
      final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;
      return acc + (precio * cantidad);
    });
  }

  double get totalExperiencias {
    return experiencias.fold<double>(0.0, (acc, exp) {
      final esGratis = exp['esGratis'] == true;
      if (esGratis) return acc;
      final precio = (exp['precio'] as num?)?.toDouble() ?? 0.0;
      return acc + precio;
    });
  }

  double get totalPersonalizacion => subtotalPreorden + totalExperiencias;

  /// Inicio de la visita: fecha elegida más hora de inicio (HU11-RF02). Si el
  /// restaurante cierra de madrugada y la hora es anterior a la apertura, el
  /// inicio cae en el día siguiente (ej. 00:30 de un turno que abrió a las 22:00).
  DateTime? get inicio {
    if (fecha == null || horario == null) return null;
    final minutos = horario!.hour * 60 + horario!.minute;
    final dia = ScheduleUtils.dayOfWeekToName(fecha!.weekday);
    DaySchedule? turno;
    for (final e in restaurant.horarios.entries) {
      if (ScheduleUtils.normalizeDayName(e.key) == dia) turno = e.value;
    }
    final apertura = ScheduleUtils.parseTimeToMinutes(turno?.apertura);
    final cierre = ScheduleUtils.parseTimeToMinutes(turno?.cierre);
    final cruzaMedianoche =
        apertura != null && cierre != null && cierre < apertura;
    final alDiaSiguiente = cruzaMedianoche && minutos < apertura;
    return DateTime(
      fecha!.year,
      fecha!.month,
      fecha!.day + (alDiaSiguiente ? 1 : 0),
      horario!.hour,
      horario!.minute,
    );
  }

  /// Fin de la visita: inicio más duración.
  DateTime? get fin => inicio?.add(Duration(minutes: duracionMin));

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Rango legible del horario elegido (ej. "14:00 – 15:30").
  String get formattedTimeRange {
    final i = inicio;
    final f = fin;
    if (i == null || f == null) return '';
    return '${_hhmm(i)} – ${_hhmm(f)}';
  }

  /// Formato legible para pantalla de la fecha elegida (ej. "S, 31 de Octubre")
  String get formattedDate {
    final d = fecha;
    if (d == null) return '';
    const dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    final diaSemana = dias[d.weekday - 1];
    final mes = meses[d.month - 1];
    return '$diaSemana, ${d.day} de $mes';
  }

  /// Formato legible para pantalla de la duración elegida (ej. "1 hora 30 min")
  String get formattedDuration {
    final horas = duracionMin ~/ 60;
    final mins = duracionMin % 60;
    if (horas > 0 && mins > 0) {
      return '$horas ${horas == 1 ? "hora" : "horas"} $mins min';
    } else if (horas > 0) {
      return '$horas ${horas == 1 ? "hora" : "horas"}';
    } else {
      return '$mins min';
    }
  }

  @override
  String toString() {
    return 'ReservationDraftModel(restaurant: ${restaurant.nombre}, branch: ${branch?.nombre}, fecha: $fecha, duracionMin: $duracionMin, personas: $personas, contact: $contactData, tienePersonalizacion: $tienePersonalizacion)';
  }
}