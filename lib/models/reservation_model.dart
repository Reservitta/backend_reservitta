import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo inmutable de Reservación para gestión de reservaciones, disponibilidad,
/// bloqueo de mesas, consulta administrativa y detalle de visita.
/// Implementación de HU08-RF02, HU03-RF01, HU15-RF02, HU16, HU26-RF01 y HU28-RF02.
class ReservationModel {
  // Constantes de estado de reserva (HU08-RF02 Criterio 1 y HU26-RF01 Criterio 3)
  static const String estadoPendiente = 'pendiente';
  static const String estadoConfirmada = 'confirmada';
  static const String estadoPendienteLlegada = 'pendiente_llegada';
  static const String estadoClienteLlego = 'cliente_llego';
  static const String estadoEnServicio = 'en_servicio';
  static const String estadoCancelada = 'cancelada';

  /// Estados operativos filtrables en el panel del restaurante (HU26-RF01 Criterio 3)
  static const List<String> estadosFiltroOperativo = [
    estadoPendienteLlegada,
    estadoClienteLlego,
    estadoEnServicio,
    estadoCancelada,
  ];

  /// Lista exhaustiva de estados oficiales permitidos
  static const List<String> estadosValidos = [
    estadoPendiente,
    estadoConfirmada,
    estadoPendienteLlegada,
    estadoClienteLlego,
    estadoEnServicio,
    estadoCancelada,
  ];

  // Constantes de estado del pedido / preorden (HU28-RF02 / HU29)
  static const String preordenPendiente = 'pendiente';
  static const String preordenEnPreparacion = 'en_preparacion';
  static const String preordenListo = 'listo';
  static const String preordenEntregado = 'entregado';
  static const String preordenCancelado = 'cancelado';

  static const List<String> estadosPreordenValidos = [
    preordenPendiente,
    preordenEnPreparacion,
    preordenListo,
    preordenEntregado,
    preordenCancelado,
  ];

  /// Normaliza una cadena de estado de reservación a su constante oficial
  static String normalizeStatus(String? status) {
    if (status == null) return '';
    final clean = status.trim().toLowerCase();
    switch (clean) {
      case 'pendiente de llegada':
      case 'pendiente_de_llegada':
      case 'pendiente_llegada':
        return estadoPendienteLlegada;
      case 'cliente llegó':
      case 'cliente llego':
      case 'cliente_llego':
        return estadoClienteLlego;
      case 'en servicio':
      case 'en_servicio':
        return estadoEnServicio;
      case 'cancelada':
      case 'cancelado':
        return estadoCancelada;
      case 'confirmada':
      case 'confirmado':
        return estadoConfirmada;
      case 'pendiente':
        return estadoPendiente;
      default:
        return clean;
    }
  }

  /// Valida si una cadena coincide con un estado oficial admitido
  static bool isValidStatus(String? status) {
    if (status == null) return false;
    final normalized = normalizeStatus(status);
    return estadosValidos.contains(normalized);
  }

  /// Normaliza el estado de la preorden/pedido
  static String normalizePreordenStatus(String? status) {
    if (status == null || status.trim().isEmpty) return preordenPendiente;
    final clean = status.trim().toLowerCase();
    switch (clean) {
      case 'pendiente':
        return preordenPendiente;
      case 'en preparación':
      case 'en preparacion':
      case 'en_preparacion':
      case 'preparando':
        return preordenEnPreparacion;
      case 'listo':
      case 'lista':
      case 'listo para servir':
        return preordenListo;
      case 'entregado':
      case 'entregada':
      case 'servido':
        return preordenEntregado;
      case 'cancelado':
      case 'cancelada':
        return preordenCancelado;
      default:
        return clean;
    }
  }

  /// Valida si el estado de preorden es válido
  static bool isValidPreordenStatus(String? status) {
    if (status == null) return false;
    return estadosPreordenValidos.contains(normalizePreordenStatus(status));
  }

  /// Criterio 2 (HU08-RF02): La hora de fin se calcula como hora de inicio + duración.
  static DateTime calculateEndTime({
    required DateTime inicio,
    required int duracionMin,
  }) {
    final minutes = duracionMin > 0 ? duracionMin : 90;
    return inicio.add(Duration(minutes: minutes));
  }

  /// HU26-RF01 Criterio 1: Ordena cronológicamente una lista de reservas por hora de inicio.
  static List<ReservationModel> sortByStartTime(
    Iterable<ReservationModel> reservations,
  ) {
    final list = List<ReservationModel>.from(reservations);
    list.sort((a, b) {
      final cmp = a.effectiveStart.compareTo(b.effectiveStart);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    return list;
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
  final String estado;
  final DateTime? creadaEn;

  // HU15-RF02, HU16 y HU28-RF02: Datos opcionales de personalización y preorden
  final List<Map<String, dynamic>> preordenItems;
  final String estadoPreorden;
  final List<String> alergias;
  final String notasAlergias;
  final Map<String, dynamic>? ocasionEspecial;
  final List<Map<String, dynamic>> experiencias;

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
    this.preordenItems = const [],
    this.estadoPreorden = preordenPendiente,
    this.alergias = const [],
    this.notasAlergias = '',
    this.ocasionEspecial,
    this.experiencias = const [],
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
    List<Map<String, dynamic>> preordenItems = const [],
    String estadoPreorden = preordenPendiente,
    List<String> alergias = const [],
    String notasAlergias = '',
    Map<String, dynamic>? ocasionEspecial,
    List<Map<String, dynamic>> experiencias = const [],
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
      preordenItems: preordenItems,
      estadoPreorden: estadoPreorden,
      alergias: alergias,
      notasAlergias: notasAlergias,
      ocasionEspecial: ocasionEspecial,
      experiencias: experiencias,
    );
  }

  /// Alias semántico para cantidad de personas (HU08-RF02 Criterio 1 y HU26-RF01 Criterio 2)
  int get cantidadPersonas => personas;

  /// Alias semántico para nombre del cliente (HU26-RF01 Criterio 2)
  String get nombreCliente =>
      contactoNombre.trim().isNotEmpty ? contactoNombre.trim() : 'Cliente sin nombre';

  /// Lista de mesas asignadas priorizando nombres legibles y con respaldo en IDs (HU26-RF01 Criterio 2)
  List<String> get mesasAsignadas =>
      mesasNombres.isNotEmpty ? mesasNombres : mesaIds;

  /// Texto formateado de mesa(s) asignada(s) (HU26-RF01 Criterio 2)
  String get mesasAsignadasTexto =>
      mesasAsignadas.isNotEmpty ? mesasAsignadas.join(', ') : 'Sin mesa asignada';

  /// Hora de inicio formateada en 'HH:mm' (HU26-RF01 Criterio 2)
  String get horaInicioFormateada {
    final dt = effectiveStart;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Hora de fin formateada en 'HH:mm'
  String get horaFinFormateada {
    final dt = effectiveEnd;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Rango horario formateado 'HH:mm - HH:mm'
  String get horarioFormateado => '$horaInicioFormateada - $horaFinFormateada';

  /// Estado operativo normalizado para el panel del restaurante (HU26-RF01 Criterio 3):
  /// - 'pendiente_llegada' (agrupa 'pendiente', 'confirmada' y 'pendiente_llegada')
  /// - 'cliente_llego'
  /// - 'en_servicio'
  /// - 'cancelada'
  String get estadoOperativo {
    final norm = normalizeStatus(estado);
    switch (norm) {
      case estadoClienteLlego:
        return estadoClienteLlego;
      case estadoEnServicio:
        return estadoEnServicio;
      case estadoCancelada:
        return estadoCancelada;
      case estadoPendiente:
      case estadoConfirmada:
      case estadoPendienteLlegada:
      default:
        return estadoPendienteLlegada;
    }
  }

  /// Etiqueta legible en español del estado operativo (HU26-RF01 / HU26-RF02)
  String get etiquetaEstado {
    switch (estadoOperativo) {
      case estadoClienteLlego:
        return 'Cliente llegó';
      case estadoEnServicio:
        return 'En servicio';
      case estadoCancelada:
        return 'Cancelada';
      case estadoPendienteLlegada:
      default:
        return 'Pendiente de llegada';
    }
  }

  /// Etiqueta legible para un filtro o constante de estado
  static String etiquetaParaEstado(String status) {
    final norm = normalizeStatus(status);
    switch (norm) {
      case estadoClienteLlego:
        return 'Cliente llegó';
      case estadoEnServicio:
        return 'En servicio';
      case estadoCancelada:
        return 'Cancelada';
      case estadoPendienteLlegada:
      case estadoPendiente:
      case estadoConfirmada:
        return 'Pendiente de llegada';
      default:
        return status;
    }
  }

  /// Etiqueta legible del estado de la preorden/pedido (HU28-RF02)
  String get etiquetaEstadoPreorden {
    return etiquetaParaEstadoPreorden(estadoPreorden);
  }

  static String etiquetaParaEstadoPreorden(String status) {
    switch (normalizePreordenStatus(status)) {
      case preordenEnPreparacion:
        return 'En preparación';
      case preordenListo:
        return 'Listo para servir';
      case preordenEntregado:
        return 'Entregado';
      case preordenCancelado:
        return 'Cancelado';
      case preordenPendiente:
      default:
        return 'Pendiente';
    }
  }

  /// Evalúa si la reservación coincide con el filtro de estado solicitado (HU26-RF01 Criterio 3)
  bool matchesEstadoFiltro(String? filtroEstado) {
    if (filtroEstado == null || filtroEstado.trim().isEmpty) return true;
    final cleanFilter = filtroEstado.trim().toLowerCase();
    if (cleanFilter == 'todos' || cleanFilter == 'todas') return true;

    final normFiltro = normalizeStatus(cleanFilter);
    final normActual = normalizeStatus(estado);

    // Si se filtra por 'pendiente_llegada' (o 'pendiente de llegada'), incluye
    // reservas recién confirmadas/pendientes que aún esperan la llegada del cliente.
    if (normFiltro == estadoPendienteLlegada) {
      return estadoOperativo == estadoPendienteLlegada;
    }
    if (normFiltro == estadoClienteLlego) {
      return estadoOperativo == estadoClienteLlego;
    }
    if (normFiltro == estadoEnServicio) {
      return estadoOperativo == estadoEnServicio;
    }
    if (normFiltro == estadoCancelada) {
      return estadoOperativo == estadoCancelada;
    }
    // Coincidencia exacta o por estado operativo para 'pendiente' / 'confirmada'
    return normActual == normFiltro || estadoOperativo == normFiltro;
  }

  /// Criterio 3 (HU08-RF02): Solo las reservaciones con estado activo (no canceladas) bloquean mesas.
  bool get bloqueaMesas {
    final norm = normalizeStatus(estado);
    return norm == estadoPendiente ||
        norm == estadoConfirmada ||
        norm == estadoPendienteLlegada ||
        norm == estadoClienteLlego ||
        norm == estadoEnServicio;
  }

  /// Alias de compatibilidad: indica si la reservación está activa y ocupa lugares
  bool get isActiva => bloqueaMesas;

  /// Indica si el estado actual es 'pendiente'
  bool get isPendiente => normalizeStatus(estado) == estadoPendiente;

  /// Indica si el estado actual es 'confirmada'
  bool get isConfirmada => normalizeStatus(estado) == estadoConfirmada;

  /// Indica si el estado operativo es 'pendiente_llegada'
  bool get isPendienteLlegada => estadoOperativo == estadoPendienteLlegada;

  /// Indica si el estado operativo es 'cliente_llego'
  bool get isClienteLlego => estadoOperativo == estadoClienteLlego;

  /// Indica si el estado operativo es 'en_servicio'
  bool get isEnServicio => estadoOperativo == estadoEnServicio;

  /// Indica si el estado actual es 'cancelada'
  bool get isCancelada => normalizeStatus(estado) == estadoCancelada;

  /// Getters de personalización (HU15-RF02, HU16, HU28-RF02)
  bool get tienePreorden => preordenItems.isNotEmpty;

  /// Indica si la reserva tiene alergias o notas de restricción alimentaria (HU28-RF02 Criterio 2)
  bool get tieneRestriccionesOAlergias =>
      alergias.isNotEmpty || notasAlergias.trim().isNotEmpty;

  /// Indica si la visita corresponde a una ocasión especial (HU28-RF02 Criterio 3)
  bool get esOcasionEspecial {
    if (ocasionEspecial != null) {
      final nombre = (ocasionEspecial!['nombre'] as String? ?? '').trim();
      if (nombre.isNotEmpty) return true;
    }
    return experiencias.isNotEmpty;
  }

  /// Nombre de la ocasión especial (ej. 'Cumpleaños', 'Aniversario')
  String get nombreOcasionEspecial {
    if (ocasionEspecial != null) {
      final nombre = (ocasionEspecial!['nombre'] as String? ?? '').trim();
      if (nombre.isNotEmpty) return nombre;
    }
    if (experiencias.isNotEmpty) return 'Ocasión Especial';
    return '';
  }

  bool get tienePersonalizacion =>
      preordenItems.isNotEmpty ||
      alergias.isNotEmpty ||
      notasAlergias.trim().isNotEmpty ||
      ocasionEspecial != null ||
      experiencias.isNotEmpty;

  /// HU28-RF02 Criterio 1: Agrupa los platillos preseleccionados por tipo/categoría
  /// (ej. 'Entrada', 'Plato fuerte', 'Postre', 'Bebida', etc.) conservando sus notas de modificación.
  ///
  /// Acepta mapas opcionales [categoriasPorId] (categoriaId -> nombre/tipo) y
  /// [categoriaPorPlatilloId] (platilloId -> nombre/tipo) para resolver categorías
  /// del catálogo cuando el ítem solo guardó el ID.
  Map<String, List<Map<String, dynamic>>> agruparPreordenPorCategoria({
    Map<String, String>? categoriasPorId,
    Map<String, String>? categoriaPorPlatilloId,
  }) {
    final agrupados = <String, List<Map<String, dynamic>>>{};

    for (final item in preordenItems) {
      final rawCat = (item['categoriaNombre'] ??
              item['categoria'] ??
              item['tipoCategoria'] ??
              item['tipo'] ??
              item['grupo'])
          ?.toString()
          .trim();

      String? resuelta = (rawCat != null && rawCat.isNotEmpty) ? rawCat : null;

      if (resuelta == null && categoriasPorId != null) {
        final catId = item['categoriaId']?.toString().trim() ?? '';
        if (catId.isNotEmpty && categoriasPorId.containsKey(catId)) {
          resuelta = categoriasPorId[catId];
        }
      }

      if (resuelta == null && categoriaPorPlatilloId != null) {
        final platId = item['platilloId']?.toString().trim() ?? '';
        if (platId.isNotEmpty && categoriaPorPlatilloId.containsKey(platId)) {
          resuelta = categoriaPorPlatilloId[platId];
        }
      }

      final etiquetaGrupo = _normalizarEtiquetaGrupoPlatillo(resuelta);
      agrupados.putIfAbsent(etiquetaGrupo, () => []).add(item);
    }

    // Ordenar las claves por orden lógico de tiempos de comida:
    // 1. Entrada, 2. Plato fuerte, 3. Postre, 4. Bebida, 5. Otros
    final entradasOrdenadas = agrupados.entries.toList()
      ..sort((a, b) =>
          _prioridadGrupoPlatillo(a.key).compareTo(_prioridadGrupoPlatillo(b.key)));

    return {
      for (final entry in entradasOrdenadas) entry.key: entry.value,
    };
  }

  static String _normalizarEtiquetaGrupoPlatillo(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Platillos preseleccionados';
    final lower = raw.trim().toLowerCase();
    if (lower == 'entrada' || lower == 'entradas') {
      return 'Entrada';
    }
    if (lower == 'plato_fuerte' ||
        lower == 'plato fuerte' ||
        lower == 'platos fuertes' ||
        lower == 'fuerte' ||
        lower == 'fuertes' ||
        lower == 'principal' ||
        lower == 'plato principal') {
      return 'Plato fuerte';
    }
    if (lower == 'postre' || lower == 'postres') {
      return 'Postre';
    }
    if (lower == 'bebida' || lower == 'bebidas') {
      return 'Bebida';
    }
    if (lower == 'general') {
      return 'Platillos preseleccionados';
    }
    final limpio = raw.trim();
    return limpio[0].toUpperCase() + limpio.substring(1);
  }

  static int _prioridadGrupoPlatillo(String grupo) {
    switch (grupo.toLowerCase()) {
      case 'entrada':
        return 1;
      case 'plato fuerte':
        return 2;
      case 'postre':
        return 3;
      case 'bebida':
        return 4;
      default:
        return 5;
    }
  }

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
  /// Criterio 3: Si no tiene estado activo, no bloquea y retorna false.
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
      fechaStr =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } else if (rawFecha is DateTime) {
      fechaStr =
          '${rawFecha.year.toString().padLeft(4, '0')}-${rawFecha.month.toString().padLeft(2, '0')}-${rawFecha.day.toString().padLeft(2, '0')}';
    }

    // Cantidad de personas (soporta 'personas' o 'cantidadPersonas')
    final personasCount = (data['personas'] ??
                data['cantidadPersonas'] ??
                data['cantidad_personas'] as num?)
            ?.toInt() ??
        2;

    // Preorden
    final rawPreorden = data['preorden'] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> preordenList = [];
    String estadoPreordenParsed = preordenPendiente;
    if (rawPreorden != null) {
      if (rawPreorden['estado'] is String) {
        estadoPreordenParsed = normalizePreordenStatus(rawPreorden['estado'] as String);
      }
      if (rawPreorden['items'] is List) {
        for (final item in rawPreorden['items']) {
          if (item is Map) {
            preordenList.add(Map<String, dynamic>.from(item));
          }
        }
      }
    } else if (data['preordenItems'] is List) {
      for (final item in data['preordenItems']) {
        if (item is Map) {
          preordenList.add(Map<String, dynamic>.from(item));
        }
      }
    }
    if (data['estadoPreorden'] is String) {
      estadoPreordenParsed = normalizePreordenStatus(data['estadoPreorden'] as String);
    }

    // Alergias
    final rawAlergias = data['alergias'] as List<dynamic>? ?? [];
    final alergiasList = rawAlergias.map((e) => e.toString()).toList();
    final notasAlergias = (data['notasAlergias'] as String?) ?? '';

    // Ocasión
    Map<String, dynamic>? ocasionMap;
    final rawOcasion = data['ocasion'] as Map<String, dynamic>? ??
        data['ocasionEspecial'] as Map<String, dynamic>?;
    if (rawOcasion != null) {
      ocasionMap = Map<String, dynamic>.from(rawOcasion);
    }

    // Experiencias
    final List<Map<String, dynamic>> experienciasList = [];
    if (rawOcasion != null && rawOcasion['experiencias'] is List) {
      for (final exp in rawOcasion['experiencias']) {
        if (exp is Map) {
          experienciasList.add(Map<String, dynamic>.from(exp));
        }
      }
    } else if (data['experiencias'] is List) {
      for (final exp in data['experiencias']) {
        if (exp is Map) {
          experienciasList.add(Map<String, dynamic>.from(exp));
        }
      }
    }

    final contactoNombreParsed = (contactoMap['nombre'] as String?) ??
        (data['contactoNombre'] as String?) ??
        (data['nombreCliente'] as String?) ??
        '';
    final contactoCorreoParsed = (contactoMap['correo'] as String?) ??
        (data['contactoCorreo'] as String?) ??
        '';
    final contactoTelefonoParsed = (contactoMap['telefono'] as String?) ??
        (data['contactoTelefono'] as String?) ??
        '';

    return ReservationModel(
      id: id,
      restauranteId: restId,
      usuarioId: usrId,
      restauranteNombre: (data['restauranteNombre'] as String?) ?? '',
      contactoNombre: contactoNombreParsed,
      contactoCorreo: contactoCorreoParsed,
      contactoTelefono: contactoTelefonoParsed,
      fechaLocal: fechaStr,
      inicio: inicioParsed,
      fin: finParsed,
      duracionMin: duracionParsed,
      personas: personasCount,
      mesaIds: mesaIdsList,
      mesasNombres:
          List<String>.from(data['mesasNombres'] as List<dynamic>? ?? []),
      estado: (data['estado'] as String?) ?? estadoConfirmada,
      creadaEn: parseTimestamp(data['creadaEn']),
      preordenItems: preordenList,
      estadoPreorden: estadoPreordenParsed,
      alergias: alergiasList,
      notasAlergias: notasAlergias,
      ocasionEspecial: ocasionMap,
      experiencias: experienciasList,
    );
  }

  Map<String, dynamic> toMap() {
    // Criterio 2: Asegurar cálculo de fin al serializar
    final effectiveFin = fin ??
        (inicio != null
            ? calculateEndTime(inicio: inicio!, duracionMin: duracionMin)
            : null);

    final map = <String, dynamic>{
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
      'tienePreorden': preordenItems.isNotEmpty,
      'tieneObservaciones': notasAlergias.trim().isNotEmpty,
      'alergias': alergias,
      'notasAlergias': notasAlergias,
    };

    if (preordenItems.isNotEmpty) {
      map['preorden'] = {
        'items': preordenItems,
        'estado': estadoPreorden,
        'subtotalPreorden': subtotalPreorden,
        'estadoActualizadoEn': FieldValue.serverTimestamp(),
      };
    }

    if (ocasionEspecial != null) {
      map['ocasion'] = {
        'ocasionId':
            ocasionEspecial!['ocasionId'] ?? ocasionEspecial!['id'] ?? '',
        'nombre': ocasionEspecial!['nombre'] ?? '',
        'icono': ocasionEspecial!['icono'] ?? 'celebration',
        'experiencias': experiencias,
      };
    }

    if (preordenItems.isNotEmpty || experiencias.isNotEmpty) {
      map['totales'] = {
        'subtotalPreorden': subtotalPreorden,
        'totalExperiencias': totalExperiencias,
        'total': totalPersonalizacion,
      };
    }

    return map;
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
    List<Map<String, dynamic>>? preordenItems,
    String? estadoPreorden,
    List<String>? alergias,
    String? notasAlergias,
    Map<String, dynamic>? Function()? ocasionEspecial,
    List<Map<String, dynamic>>? experiencias,
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
      preordenItems: preordenItems ?? this.preordenItems,
      estadoPreorden: estadoPreorden ?? this.estadoPreorden,
      alergias: alergias ?? this.alergias,
      notasAlergias: notasAlergias ?? this.notasAlergias,
      ocasionEspecial:
          ocasionEspecial != null ? ocasionEspecial() : this.ocasionEspecial,
      experiencias: experiencias ?? this.experiencias,
    );
  }
}
