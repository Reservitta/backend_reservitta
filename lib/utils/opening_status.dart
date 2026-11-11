import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../theme/app_theme.dart';
import 'schedule_utils.dart';

/// Estado de apertura de un restaurante en este momento, según sus horarios reales.
class EstadoApertura {
  final String texto;
  final Color color;
  final Color fondo;

  const EstadoApertura(this.texto, this.color, this.fondo);

  static const _verde = Color(0xFFE8F5E9);
  static const _rojo = Color(0xFFFDECEA);
  static const _ambar = Color(0xFFFFF3D6);

  /// Estado de hoy a la hora [ahora]. Devuelve null si el restaurante no registró
  /// horarios (no se muestra una etiqueta que no se puede respaldar).
  static EstadoApertura? hoy(RestaurantModel restaurante, DateTime ahora) {
    if (restaurante.horarios.isEmpty) return null;

    DaySchedule? hoy;
    final nombreHoy = ScheduleUtils.dayOfWeekToName(ahora.weekday);
    for (final e in restaurante.horarios.entries) {
      if (ScheduleUtils.normalizeDayName(e.key) == nombreHoy) {
        hoy = e.value;
        break;
      }
    }

    if (restaurante.isOpenAt(ahora)) {
      return EstadoApertura(
        hoy != null ? 'Abierto hasta ${hoy.cierre}' : 'Abierto',
        AppColors.exito,
        _verde,
      );
    }
    if (hoy != null && hoy.abierto && restaurante.isActivo) {
      final apertura = ScheduleUtils.parseTimeToMinutes(hoy.apertura);
      final minutos = ahora.hour * 60 + ahora.minute;
      if (apertura != null && minutos < apertura) {
        return EstadoApertura('Abre a las ${hoy.apertura}', AppColors.acento, _ambar);
      }
      return const EstadoApertura('Cerrado ahora', AppColors.error, _rojo);
    }
    return const EstadoApertura('Cerrado hoy', AppColors.error, _rojo);
  }
}
