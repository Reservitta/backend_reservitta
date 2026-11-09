import 'mesa_model.dart';
import 'reservation_model.dart';

/// Estado de una mesa en este momento (HU31-RF01).
enum EstadoMesaVivo { disponible, ocupada, combinada, fueraDeServicio }

/// Estado en tiempo real de una mesa, derivado de las reservas activas.
class TableLiveStatus {
  final MesaModel mesa;
  final EstadoMesaVivo estado;

  /// Reserva a la que pertenece la mesa ahora, si la hay. También se informa cuando la
  /// mesa está fuera de servicio por decisión manual pero tiene una reserva en curso.
  final ReservationModel? reserva;

  /// Nombres de las otras mesas con las que está combinada (solo si [estado] es combinada).
  final List<String> combinadaCon;

  /// El administrador fijó el estado a mano (no se deriva de las reservas).
  final bool forzada;

  const TableLiveStatus({
    required this.mesa,
    required this.estado,
    this.reserva,
    this.combinadaCon = const [],
    this.forzada = false,
  });

  bool get estaLibre => estado == EstadoMesaVivo.disponible;

  /// Mesa en uso (ocupada o combinada).
  bool get enUso =>
      estado == EstadoMesaVivo.ocupada || estado == EstadoMesaVivo.combinada;

  String get etiqueta {
    switch (estado) {
      case EstadoMesaVivo.disponible:
        return 'Disponible';
      case EstadoMesaVivo.ocupada:
        return 'Ocupada';
      case EstadoMesaVivo.combinada:
        return 'Combinada';
      case EstadoMesaVivo.fueraDeServicio:
        return 'Fuera de servicio';
    }
  }
}

/// Deriva el estado de cada mesa a partir de las reservas (HU31-RF01).
class TableLiveStatusCalculator {
  TableLiveStatusCalculator._();

  /// Si [r] tiene a sus mesas en uso en el instante [ahora]:
  /// - el cliente ya llegó o está en servicio (hasta que la reserva se finalice), o
  /// - la reserva está vigente y su horario incluye [ahora].
  static bool enCurso(ReservationModel r, DateTime ahora) {
    if (!r.bloqueaMesas) return false;
    final inicio = r.effectiveStart;
    if (inicio.isAfter(ahora)) return false;
    final op = r.estadoOperativo;
    if (op == ReservationModel.estadoClienteLlego ||
        op == ReservationModel.estadoEnServicio) {
      return true;
    }
    final fin = r.fin ?? inicio.add(Duration(minutes: r.duracionMin));
    return ahora.isBefore(fin);
  }

  /// Estado de todas las [mesas] en el instante [ahora], en el mismo orden.
  static List<TableLiveStatus> calcular({
    required List<MesaModel> mesas,
    required Iterable<ReservationModel> reservas,
    required DateTime ahora,
  }) {
    final nombrePorId = {for (final m in mesas) m.id: m.nombre};
    final enCurso_ = reservas.where((r) => enCurso(r, ahora)).toList()
      ..sort((a, b) => a.effectiveStart.compareTo(b.effectiveStart));

    ReservationModel? reservaDe(String mesaId) {
      for (final r in enCurso_) {
        if (r.mesaIds.contains(mesaId)) return r;
      }
      return null;
    }

    return [
      for (final mesa in mesas)
        _estadoDe(mesa, reservaDe(mesa.id), nombrePorId),
    ];
  }

  static TableLiveStatus _estadoDe(
    MesaModel mesa,
    ReservationModel? reserva,
    Map<String, String> nombrePorId,
  ) {
    final otras = reserva == null
        ? const <String>[]
        : [
            for (final id in reserva.mesaIds)
              if (id != mesa.id) nombrePorId[id] ?? id,
          ];

    if (mesa.fueraDeServicio) {
      return TableLiveStatus(
        mesa: mesa,
        estado: EstadoMesaVivo.fueraDeServicio,
        reserva: reserva,
        forzada: true,
      );
    }
    if (reserva == null) {
      return TableLiveStatus(mesa: mesa, estado: EstadoMesaVivo.disponible);
    }
    if (otras.isNotEmpty) {
      return TableLiveStatus(
        mesa: mesa,
        estado: EstadoMesaVivo.combinada,
        reserva: reserva,
        combinadaCon: otras,
      );
    }
    return TableLiveStatus(
      mesa: mesa,
      estado: EstadoMesaVivo.ocupada,
      reserva: reserva,
    );
  }
}
