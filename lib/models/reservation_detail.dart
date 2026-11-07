import 'reservation_model.dart';

/// Línea del pedido tal como la ve el administrador (HU28-RF01).
class DetallePlatillo {
  final String platilloId;
  final String nombre;
  final int cantidad;

  /// Nota de modificación que el visitante escribió para este platillo.
  final String nota;
  final String mensajeFelicitacion;

  const DetallePlatillo({
    required this.platilloId,
    required this.nombre,
    required this.cantidad,
    this.nota = '',
    this.mensajeFelicitacion = '',
  });

  bool get tieneNota => nota.isNotEmpty;
}

/// Experiencia elegida para la ocasión especial (HU28-RF01).
class DetalleExperiencia {
  final String nombre;
  final double precio;
  final bool esGratis;
  final String mensajeFelicitacion;

  const DetalleExperiencia({
    required this.nombre,
    required this.precio,
    required this.esGratis,
    this.mensajeFelicitacion = '',
  });

  String get precioFormateado =>
      esGratis || precio <= 0 ? 'Gratis' : '\$${precio.toStringAsFixed(2)} MXN';
}

/// Detalle completo de una reserva para el administrador (HU28-RF01).
/// Lo que el visitante no indicó se muestra como "No indicado" sin causar error
/// (Criterio 2).
class ReservationDetail {
  static const String noIndicado = 'No indicado';

  final String id;
  final String restauranteId;

  final String clienteNombre;
  final String clienteCorreo;
  final String clienteTelefono;

  final String fechaLocal;
  final DateTime? inicio;
  final DateTime? fin;
  final int duracionMin;
  final int personas;
  final List<String> mesas;

  final String estadoOperativo;
  final String etiquetaEstado;
  final String estadoPreorden;
  final String etiquetaEstadoPreorden;

  /// Platillos preseleccionados agrupados (entrada, plato fuerte...), con sus notas.
  final Map<String, List<DetallePlatillo>> platillosPorGrupo;
  final double subtotalPreorden;

  final List<String> alergias;
  final String notasAlergias;
  final List<String> observacionesPorPlatillo;

  final String? tipoOcasion;
  final String detalleOcasion;
  final List<DetalleExperiencia> experiencias;
  final double totalExperiencias;

  const ReservationDetail({
    required this.id,
    required this.restauranteId,
    required this.clienteNombre,
    required this.clienteCorreo,
    required this.clienteTelefono,
    required this.fechaLocal,
    required this.inicio,
    required this.fin,
    required this.duracionMin,
    required this.personas,
    required this.mesas,
    required this.estadoOperativo,
    required this.etiquetaEstado,
    required this.estadoPreorden,
    required this.etiquetaEstadoPreorden,
    required this.platillosPorGrupo,
    required this.subtotalPreorden,
    required this.alergias,
    required this.notasAlergias,
    required this.observacionesPorPlatillo,
    required this.tipoOcasion,
    required this.detalleOcasion,
    required this.experiencias,
    required this.totalExperiencias,
  });

  factory ReservationDetail.fromReservation(
    ReservationModel r, {
    Map<String, String>? categoriasPorId,
    Map<String, String>? categoriaPorPlatilloId,
  }) {
    final agrupado = r.agruparPreordenPorCategoria(
      categoriasPorId: categoriasPorId,
      categoriaPorPlatilloId: categoriaPorPlatilloId,
    );

    final platillos = <String, List<DetallePlatillo>>{
      for (final entry in agrupado.entries)
        entry.key: [
          for (final item in entry.value)
            DetallePlatillo(
              platilloId: (item['platilloId'] ?? '').toString(),
              nombre: (item['nombre'] ?? 'Platillo').toString(),
              cantidad: (item['cantidad'] as num?)?.toInt() ?? 1,
              nota: (item['observacion'] ?? '').toString().trim(),
              mensajeFelicitacion:
                  (item['mensajeFelicitacion'] ?? '').toString().trim(),
            ),
        ],
    };

    final ocasion = r.ocasionEspecial;
    final nombreOcasion = (ocasion?['nombre'] ?? '').toString().trim();

    return ReservationDetail(
      id: r.id,
      restauranteId: r.restauranteId,
      clienteNombre: _o(r.contactoNombre),
      clienteCorreo: _o(r.contactoCorreo),
      clienteTelefono: _o(r.contactoTelefono),
      fechaLocal: r.fechaLocal,
      inicio: r.inicio,
      fin: r.fin ?? r.inicio?.add(Duration(minutes: r.duracionMin)),
      duracionMin: r.duracionMin,
      personas: r.personas,
      mesas: r.mesasNombres.isNotEmpty ? r.mesasNombres : r.mesaIds,
      estadoOperativo: r.estadoOperativo,
      etiquetaEstado: r.etiquetaEstado,
      estadoPreorden: r.estadoPreorden,
      etiquetaEstadoPreorden: r.etiquetaEstadoPreorden,
      platillosPorGrupo: platillos,
      subtotalPreorden: r.subtotalPreorden,
      alergias: List.unmodifiable(r.alergias),
      notasAlergias: r.notasAlergias.trim(),
      observacionesPorPlatillo: [
        for (final p in r.restriccionesPorPlatillo)
          '${p.nombre}: ${p.observacion}',
      ],
      tipoOcasion: nombreOcasion.isNotEmpty
          ? nombreOcasion
          : (r.experiencias.isNotEmpty ? 'Ocasión especial' : null),
      detalleOcasion: (ocasion?['detalle'] ?? '').toString().trim(),
      experiencias: [
        for (final e in r.experiencias)
          DetalleExperiencia(
            nombre: (e['nombre'] ?? 'Experiencia').toString(),
            precio: (e['precio'] as num?)?.toDouble() ?? 0.0,
            esGratis: e['esGratis'] == true ||
                ((e['precio'] as num?)?.toDouble() ?? 0.0) <= 0,
            mensajeFelicitacion:
                (e['mensajeFelicitacion'] ?? '').toString().trim(),
          ),
      ],
      totalExperiencias: r.totalExperiencias,
    );
  }

  static String _o(String valor) =>
      valor.trim().isEmpty ? noIndicado : valor.trim();

  bool get tienePreorden => platillosPorGrupo.isNotEmpty;
  bool get tieneAlergias => alergias.isNotEmpty || notasAlergias.isNotEmpty;
  bool get tieneObservaciones => observacionesPorPlatillo.isNotEmpty;
  bool get esOcasionEspecial => tipoOcasion != null;

  /// Cuántos platillos (con cantidades) trae el pedido.
  int get totalPlatillos => platillosPorGrupo.values
      .expand((l) => l)
      .fold<int>(0, (acc, p) => acc + p.cantidad);

  /// Textos listos para la pantalla: nunca vacíos, nunca fallan (Criterio 2).
  String get resumenPreorden => tienePreorden
      ? '$totalPlatillos ${totalPlatillos == 1 ? 'platillo' : 'platillos'}'
      : noIndicado;

  String get resumenAlergias {
    if (!tieneAlergias) return noIndicado;
    return [
      if (alergias.isNotEmpty) alergias.join(', '),
      if (notasAlergias.isNotEmpty) notasAlergias,
    ].join(' · ');
  }

  String get resumenOcasion {
    if (!esOcasionEspecial) return noIndicado;
    return detalleOcasion.isNotEmpty
        ? '$tipoOcasion: $detalleOcasion'
        : tipoOcasion!;
  }

  String get horario {
    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (inicio == null) return noIndicado;
    return fin == null ? hhmm(inicio!) : '${hhmm(inicio!)} – ${hhmm(fin!)}';
  }

  String get mesasTexto => mesas.isEmpty ? noIndicado : mesas.join(' + ');
}
