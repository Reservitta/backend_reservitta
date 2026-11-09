import 'mesa_model.dart';
import 'reservation_model.dart';
import 'restaurant_time.dart';
import 'table_live_status.dart';

/// Métricas del día para el dashboard del administrador (HU25-RF01).
class DailyMetrics {
  /// Reservas activas del día (sin canceladas, finalizadas ni no-show).
  final int totalReservas;

  /// Personas esperadas en esas reservas.
  final int personasEsperadas;

  /// Mesas que se pueden usar hoy (todas menos las fuera de servicio).
  final int mesasActivas;

  /// Mesas en uso en este momento (ocupadas o combinadas).
  final int mesasOcupadas;

  /// Reservas activas que traen preorden.
  final int pedidosConPreorden;

  const DailyMetrics({
    this.totalReservas = 0,
    this.personasEsperadas = 0,
    this.mesasActivas = 0,
    this.mesasOcupadas = 0,
    this.pedidosConPreorden = 0,
  });

  /// Sin datos: todo en cero (no es un error).
  static const DailyMetrics vacias = DailyMetrics();

  bool get sinActividad => totalReservas == 0 && mesasOcupadas == 0;

  /// Calcula las métricas del día [fechaLocal] ('YYYY-MM-DD'; por defecto hoy en la
  /// zona [zonaHoraria] del restaurante) con las [reservas] y [mesas] dadas.
  static DailyMetrics calcular({
    required Iterable<ReservationModel> reservas,
    required List<MesaModel> mesas,
    required DateTime ahora,
    String? fechaLocal,
    String? zonaHoraria,
  }) {
    final dia = fechaLocal ?? RestaurantTime.fechaLocalHoy(zonaHoraria, ahora);
    final activas =
        reservas.where((r) => r.fechaLocal == dia && r.bloqueaMesas).toList();

    final estados = TableLiveStatusCalculator.calcular(
      mesas: mesas,
      reservas: activas,
      ahora: ahora,
    );

    return DailyMetrics(
      totalReservas: activas.length,
      personasEsperadas: activas.fold<int>(0, (a, r) => a + r.personas),
      mesasActivas: mesas.where((m) => !m.fueraDeServicio).length,
      mesasOcupadas: estados.where((e) => e.enUso).length,
      pedidosConPreorden: activas.where((r) => r.tienePreorden).length,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DailyMetrics &&
      other.totalReservas == totalReservas &&
      other.personasEsperadas == personasEsperadas &&
      other.mesasActivas == mesasActivas &&
      other.mesasOcupadas == mesasOcupadas &&
      other.pedidosConPreorden == pedidosConPreorden;

  @override
  int get hashCode => Object.hash(totalReservas, personasEsperadas, mesasActivas,
      mesasOcupadas, pedidosConPreorden);
}
