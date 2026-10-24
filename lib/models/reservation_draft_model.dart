import 'package:flutter/material.dart';
import 'branch_model.dart';
import 'restaurant_model.dart';

/// Modelo de borrador de reservación para el flujo de reserva (HU07-RF01).
/// Guarda de forma incremental los datos elegidos por el usuario:
/// sucursal, fecha, duración, cantidad de personas, mesa(s) y horario.
class ReservationDraftModel {
  final RestaurantModel restaurant;
  final BranchModel? branch;
  final DateTime? fecha;
  final int duracionMin;
  final int personas;
  final List<String> mesaIds;
  final List<String> mesasNombres;
  final TimeOfDay? horario;

  const ReservationDraftModel({
    required this.restaurant,
    this.branch,
    this.fecha,
    this.duracionMin = 90, // Sugerida por defecto: 1 h 30 min (HU08-RF01)
    this.personas = 2, // Mínimo 1 (HU09-RF01)
    this.mesaIds = const [],
    this.mesasNombres = const [],
    this.horario,
  });

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
  }) {
    return ReservationDraftModel(
      restaurant: restaurant ?? this.restaurant,
      branch: branch != null ? branch() : this.branch,
      fecha: fecha != null ? fecha() : this.fecha,
      duracionMin: duracionMin ?? this.duracionMin,
      personas: personas ?? this.personas,
      mesaIds: mesaIds ?? this.mesaIds,
      mesasNombres: mesasNombres ?? this.mesasNombres,
      horario: horario != null ? horario() : this.horario,
    );
  }

  /// Limpia los campos de selección manteniendo el restaurante inicial
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
    );
  }

  // Getters de validación por paso
  bool get hasBranch => branch != null;
  bool get hasDate => fecha != null;
  bool get hasDuration => duracionMin >= 30;
  bool get hasPeople => personas >= 1;

  /// Formato legible para pantalla de la fecha elegida (ej. "S, 31 de Octubre")
  String get formattedDate {
    if (fecha == null) return '';
    const dias = ['L', 'M', 'Mi', 'J', 'V', 'S', 'D'];
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
    final d = fecha!;
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
    return 'ReservationDraftModel(restaurant: ${restaurant.nombre}, branch: ${branch?.nombre}, fecha: $fecha, duracionMin: $duracionMin, personas: $personas)';
  }
}
