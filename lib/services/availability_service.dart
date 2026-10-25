import '../models/mesa_model.dart';
import '../models/reservation_model.dart';
import '../models/restaurant_model.dart';
import '../models/table_availability_models.dart';
import '../models/zona_model.dart';
import '../repositories/reservation_repository.dart';
import '../repositories/table_repository.dart';
import '../utils/schedule_utils.dart';

export '../models/table_availability_models.dart';

/// Resultado de validar una fecha contra el calendario del restaurante (HU07-RF03).
class DateValidationResult {
  final bool isValid;
  final AvailabilityFailure? reason;

  const DateValidationResult.valid() : isValid = true, reason = null;

  const DateValidationResult.invalid(AvailabilityFailure this.reason)
    : isValid = false;

  /// Mensaje listo para mostrar al visitante.
  String? get message {
    switch (reason) {
      case AvailabilityFailure.restauranteInactivo:
        return 'El restaurante no está recibiendo reservaciones.';
      case AvailabilityFailure.fechaPasada:
        return 'Selecciona una fecha de hoy en adelante.';
      case AvailabilityFailure.fechaMuyLejana:
        return 'Aún no se aceptan reservaciones para una fecha tan lejana.';
      case AvailabilityFailure.sinHorariosHoy:
        return 'Ya no hay horarios disponibles el día de hoy.';
      case AvailabilityFailure.cierreEspecial:
        return 'El restaurante permanecerá cerrado ese día.';
      case AvailabilityFailure.diaCerrado:
        return 'El restaurante no abre ese día de la semana.';
      case AvailabilityFailure.fueraDeHorario:
        return 'El horario elegido queda fuera del horario de atención.';
      case AvailabilityFailure.sinDisponibilidad:
        return 'No hay disponibilidad en el horario elegido.';
      case null:
        return null;
    }
  }
}

/// Resultado del cálculo de disponibilidad por traslape (HU08-RF03).
class AvailabilityResult {
  final bool isAvailable;
  final AvailabilityFailure? reason;
  final Set<String> mesasBloqueadasIds;
  final List<MesaModel> mesasLibres;

  /// Estado de cada mesa del restaurante, por id.
  final Map<String, MesaEstado> estadoPorMesa;

  /// Personas ya comprometidas en el intervalo; solo se calcula cuando el
  /// restaurante no tiene mesas registradas.
  final int personasReservadas;

  const AvailabilityResult({
    required this.isAvailable,
    this.reason,
    this.mesasBloqueadasIds = const {},
    this.mesasLibres = const [],
    this.estadoPorMesa = const {},
    this.personasReservadas = 0,
  });

  const AvailabilityResult.unavailable(AvailabilityFailure this.reason)
    : isAvailable = false,
      mesasBloqueadasIds = const {},
      mesasLibres = const [],
      estadoPorMesa = const {},
      personasReservadas = 0;
}

/// Motor de disponibilidad: valida fechas y calcula traslapes (HU07-RF03, HU08-RF03).
/// No toca Firestore directamente; consulta reservaciones a través de [ReservationRepository].
class AvailabilityService {
  final ReservationRepository _reservations;
  final DateTime Function() _now;

  /// Días máximos de anticipación para reservar (HU07-RF03).
  final int maxAnticipacionDias;

  /// Minutos de limpieza tras cada reservación; 0 = sin margen (HU08-RF03).
  final int margenLimpiezaMin;

  /// Fuente de mesas y zonas. Si es null se usan las mesas del [RestaurantModel].
  final TableRepository? _tables;

  AvailabilityService(
    this._reservations, {
    TableRepository? tables,
    DateTime Function()? now,
    this.maxAnticipacionDias = 90,
    this.margenLimpiezaMin = 0,
    // ignore: prefer_initializing_formals
  }) : _tables = tables,
       _now = now ?? DateTime.now;

  // ---------------------------------------------------------------------------
  // HU07-RF03: validación de fecha contra el calendario del restaurante
  // ---------------------------------------------------------------------------

  /// Valida que [fecha] (solo se usa año/mes/día) sea reservable:
  /// restaurante activo, no pasada, sin cierre especial y con día de atención.
  DateValidationResult validateDate({
    required RestaurantModel restaurant,
    required DateTime fecha,
  }) {
    if (!restaurant.isActivo) {
      return const DateValidationResult.invalid(
        AvailabilityFailure.restauranteInactivo,
      );
    }

    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(fecha.year, fecha.month, fecha.day);
    if (target.isBefore(today)) {
      return const DateValidationResult.invalid(
        AvailabilityFailure.fechaPasada,
      );
    }

    if (target.isAfter(today.add(Duration(days: maxAnticipacionDias)))) {
      return const DateValidationResult.invalid(
        AvailabilityFailure.fechaMuyLejana,
      );
    }

    if (ScheduleUtils.isSpecialClosureDate(
      cierresEspeciales: restaurant.cierresEspeciales,
      dateTime: target,
    )) {
      return const DateValidationResult.invalid(
        AvailabilityFailure.cierreEspecial,
      );
    }

    final dayName = ScheduleUtils.dayOfWeekToName(target.weekday);
    final diasAbiertos = restaurant.diasAbiertos
        .map(ScheduleUtils.normalizeDayName)
        .toSet();
    if (diasAbiertos.isNotEmpty && !diasAbiertos.contains(dayName)) {
      return const DateValidationResult.invalid(AvailabilityFailure.diaCerrado);
    }

    final schedule = _scheduleFor(restaurant, dayName);
    if (schedule == null || !schedule.abierto) {
      return const DateValidationResult.invalid(AvailabilityFailure.diaCerrado);
    }

    // Hoy solo es válido si el restaurante aún no ha cerrado.
    if (target == today && !_hasTimeLeftToday(schedule, now)) {
      return const DateValidationResult.invalid(
        AvailabilityFailure.sinHorariosHoy,
      );
    }

    return const DateValidationResult.valid();
  }

  bool _hasTimeLeftToday(DaySchedule schedule, DateTime now) {
    final apertura = ScheduleUtils.parseTimeToMinutes(schedule.apertura);
    final cierre = ScheduleUtils.parseTimeToMinutes(schedule.cierre);
    if (apertura == null || cierre == null) return false;
    if (apertura == 0 && cierre == 0) return true;
    // Cierra de madrugada: hoy aún hay turno.
    if (cierre < apertura) return true;
    return now.hour * 60 + now.minute < cierre;
  }

  // ---------------------------------------------------------------------------
  // HU08-RF03: disponibilidad por traslape
  // ---------------------------------------------------------------------------

  /// Dos intervalos [aInicio, aFin) y [bInicio, bFin) se traslapan si
  /// aInicio < bFin y aFin > bInicio. Que uno termine justo cuando empieza
  /// el otro no cuenta como traslape.
  static bool intervalsOverlap(
    DateTime aInicio,
    DateTime aFin,
    DateTime bInicio,
    DateTime bFin,
  ) {
    return aInicio.isBefore(bFin) && aFin.isAfter(bInicio);
  }

  /// Indica si todo el intervalo [inicio, inicio + duracion] cabe en el horario
  /// de atención. Contempla horarios que cruzan la medianoche: una hora de inicio
  /// de madrugada se evalúa contra el horario del día anterior.
  bool isWithinOperatingHours({
    required RestaurantModel restaurant,
    required DateTime inicio,
    required int duracionMin,
  }) {
    final startMin = inicio.hour * 60 + inicio.minute;

    final hoy = _scheduleFor(
      restaurant,
      ScheduleUtils.dayOfWeekToName(inicio.weekday),
    );
    if (hoy != null && hoy.abierto && _fits(hoy, startMin, duracionMin)) {
      return true;
    }

    final ayer = _scheduleFor(
      restaurant,
      ScheduleUtils.dayOfWeekToName(
        inicio.subtract(const Duration(days: 1)).weekday,
      ),
    );
    if (ayer == null || !ayer.abierto) return false;
    return _fits(ayer, startMin + 1440, duracionMin);
  }

  /// [startMin] se mide desde la medianoche del día en que abre el horario
  /// (puede superar 1440 si el inicio cae en la madrugada siguiente).
  bool _fits(DaySchedule schedule, int startMin, int duracionMin) {
    final apertura = ScheduleUtils.parseTimeToMinutes(schedule.apertura);
    final cierre = ScheduleUtils.parseTimeToMinutes(schedule.cierre);
    if (apertura == null || cierre == null) return false;

    if (apertura == 0 && cierre == 0) return startMin + duracionMin <= 2880;

    final cierreAbsoluto = cierre < apertura ? cierre + 1440 : cierre;
    if (cierre >= apertura && startMin >= 1440) return false;
    return startMin >= apertura && startMin + duracionMin <= cierreAbsoluto;
  }

  /// Calcula la disponibilidad de [restaurant] para [inicio] con [duracionMin].
  ///
  /// Con mesas registradas: la disponibilidad son las mesas no bloqueadas por
  /// reservaciones activas que se traslapan. Sin mesas: se compara [personas]
  /// contra la capacidad restante.
  Future<AvailabilityResult> checkAvailability({
    required RestaurantModel restaurant,
    required DateTime inicio,
    int duracionMin = 90,
    int personas = 1,
  }) async {
    final duracion = duracionMin > 0 ? duracionMin : 90;

    final dateCheck = validateDate(restaurant: restaurant, fecha: inicio);
    if (!dateCheck.isValid) {
      return AvailabilityResult.unavailable(dateCheck.reason!);
    }

    if (!isWithinOperatingHours(
      restaurant: restaurant,
      inicio: inicio,
      duracionMin: duracion,
    )) {
      return const AvailabilityResult.unavailable(
        AvailabilityFailure.fueraDeHorario,
      );
    }

    final mesasDelRestaurante = await _loadMesas(restaurant);
    final fin = inicio.add(Duration(minutes: duracion));
    final overlapping = await _overlappingReservations(
      restauranteId: restaurant.id,
      inicio: inicio,
      fin: fin,
    );

    if (mesasDelRestaurante.isEmpty) {
      final reservadas = overlapping.fold<int>(0, (acc, r) => acc + r.personas);
      final capacidad = restaurant.capacidadTotal;
      final cabe = capacidad > 0 && reservadas + personas <= capacidad;
      return AvailabilityResult(
        isAvailable: cabe,
        reason: cabe ? null : AvailabilityFailure.sinDisponibilidad,
        personasReservadas: reservadas,
      );
    }

    final bloqueadas = <String>{};
    for (final res in overlapping) {
      bloqueadas.addAll(res.mesaIds);
    }
    final estados = {
      for (final m in mesasDelRestaurante)
        m.id: bloqueadas.contains(m.id)
            ? MesaEstado.ocupada
            : MesaEstado.disponible,
    };
    final libres = mesasDelRestaurante
        .where((m) => !bloqueadas.contains(m.id))
        .toList();

    return AvailabilityResult(
      isAvailable: libres.isNotEmpty,
      reason: libres.isEmpty ? AvailabilityFailure.sinDisponibilidad : null,
      mesasBloqueadasIds: bloqueadas,
      mesasLibres: libres,
      estadoPorMesa: estados,
    );
  }

  // ---------------------------------------------------------------------------
  // HU09-RF02: mesas adecuadas para el grupo
  // ---------------------------------------------------------------------------

  /// Número máximo de mesas que se unen en una combinación.
  static const int maxMesasPorCombinacion = 4;

  /// Máximo de combinaciones que se devuelven.
  static const int maxCombinaciones = 10;

  /// Mesas libres en [inicio, inicio + duracionMin] que cubren a [personas].
  /// Si ninguna mesa individual alcanza, devuelve combinaciones de mesas combinables.
  Future<TableSuggestionResult> findSuitableTables({
    required RestaurantModel restaurant,
    required DateTime inicio,
    required int personas,
    int duracionMin = 90,
  }) async {
    final disponibilidad = await checkAvailability(
      restaurant: restaurant,
      inicio: inicio,
      duracionMin: duracionMin,
      personas: personas,
    );
    if (disponibilidad.reason != null &&
        disponibilidad.reason != AvailabilityFailure.sinDisponibilidad) {
      return TableSuggestionResult(reason: disponibilidad.reason);
    }

    final libres = disponibilidad.mesasLibres;
    final individuales =
        libres
            .where((m) => m.capacidad >= personas)
            .map((m) => TableOption(mesa: m, personas: personas))
            .toList()
          ..sort((a, b) {
            final byHolgura = a.holgura.compareTo(b.holgura);
            return byHolgura != 0
                ? byHolgura
                : a.mesa.nombre.compareTo(b.mesa.nombre);
          });

    if (individuales.isNotEmpty) {
      return TableSuggestionResult(mesas: individuales);
    }

    final combinaciones = _findCombinations(libres, personas);
    return TableSuggestionResult(
      reason: combinaciones.isEmpty
          ? AvailabilityFailure.sinDisponibilidad
          : null,
      combinaciones: combinaciones,
    );
  }

  /// Conjuntos conectados de mesas combinables cuya capacidad suma al menos [personas].
  /// Solo se devuelven combinaciones mínimas: ninguna mesa sobra para cubrir al grupo.
  List<TableCombination> _findCombinations(
    List<MesaModel> libres,
    int personas,
  ) {
    final candidatas = libres.where((m) => m.combinable).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final encontradas = <TableCombination>[];
    final vistas = <String>{};

    void explorar(List<MesaModel> actual, int desde) {
      final capacidad = actual.fold<int>(0, (acc, m) => acc + m.capacidad);
      if (actual.length >= 2 && capacidad >= personas) {
        if (_esConexa(actual) && _esMinima(actual, personas)) {
          final key = (actual.map((m) => m.id).toList()..sort()).join('|');
          if (vistas.add(key)) {
            encontradas.add(
              TableCombination(mesas: List.of(actual), personas: personas),
            );
          }
        }
        return;
      }
      if (actual.length >= maxMesasPorCombinacion) return;
      for (var i = desde; i < candidatas.length; i++) {
        explorar([...actual, candidatas[i]], i + 1);
      }
    }

    explorar(const [], 0);

    encontradas.sort((a, b) {
      final byHolgura = a.holgura.compareTo(b.holgura);
      if (byHolgura != 0) return byHolgura;
      return a.mesas.length.compareTo(b.mesas.length);
    });
    return encontradas.take(maxCombinaciones).toList();
  }

  /// Todas las mesas quedan unidas entre sí mediante enlaces de combinación.
  bool _esConexa(List<MesaModel> mesas) {
    final visitadas = <String>{mesas.first.id};
    final pendientes = [mesas.first];
    while (pendientes.isNotEmpty) {
      final actual = pendientes.removeLast();
      for (final otra in mesas) {
        if (!visitadas.contains(otra.id) && actual.puedeCombinarCon(otra)) {
          visitadas.add(otra.id);
          pendientes.add(otra);
        }
      }
    }
    return visitadas.length == mesas.length;
  }

  /// Quitar cualquier mesa dejaría al grupo sin lugar suficiente.
  bool _esMinima(List<MesaModel> mesas, int personas) {
    final total = mesas.fold<int>(0, (acc, m) => acc + m.capacidad);
    return mesas.every((m) => total - m.capacidad < personas);
  }

  // ---------------------------------------------------------------------------
  // HU10-RF01: plano del restaurante con el estado de cada mesa
  // ---------------------------------------------------------------------------

  /// Plano completo del restaurante con el estado de cada mesa para el intervalo.
  /// Sin mesas posicionadas devuelve [FloorPlanResult.sinPlano] (estado controlado).
  Future<FloorPlanResult> getFloorPlan({
    required RestaurantModel restaurant,
    required DateTime inicio,
    int duracionMin = 90,
  }) async {
    final mesas = (await _loadMesas(restaurant))
        .where((m) => m.tienePosicion)
        .toList();
    if (mesas.isEmpty) return const FloorPlanResult.sinPlano();

    final zonas = await _loadZonas(restaurant.id);
    final disponibilidad = await checkAvailability(
      restaurant: restaurant,
      inicio: inicio,
      duracionMin: duracionMin,
    );

    final reason =
        disponibilidad.reason == AvailabilityFailure.sinDisponibilidad
        ? null
        : disponibilidad.reason;

    return FloorPlanResult(
      configurado: true,
      zonas: zonas,
      reason: reason,
      mesas: [
        for (final m in mesas)
          PlanoMesa(
            mesa: m,
            estado: reason != null
                ? MesaEstado.noDisponible
                : (disponibilidad.mesasBloqueadasIds.contains(m.id)
                      ? MesaEstado.ocupada
                      : MesaEstado.disponible),
          ),
      ],
    );
  }

  Future<List<MesaModel>> _loadMesas(RestaurantModel restaurant) async {
    final repo = _tables;
    if (repo == null) return restaurant.mesas;
    final desdeRepo = await repo.getMesas(restaurant.id);
    return desdeRepo.isNotEmpty ? desdeRepo : restaurant.mesas;
  }

  Future<List<ZonaModel>> _loadZonas(String restaurantId) async {
    final repo = _tables;
    if (repo == null) return const [];
    return repo.getZonas(restaurantId);
  }

  /// Reservaciones activas que se traslapan con [inicio, fin). Consulta también el
  /// día anterior porque una reservación nocturna puede terminar después de la medianoche.
  Future<List<ReservationModel>> _overlappingReservations({
    required String restauranteId,
    required DateTime inicio,
    required DateTime fin,
  }) async {
    final fechas = <String>{
      ScheduleUtils.formatDateLocal(inicio),
      ScheduleUtils.formatDateLocal(inicio.subtract(const Duration(days: 1))),
      ScheduleUtils.formatDateLocal(fin),
    };

    final result = <ReservationModel>[];
    final vistos = <String>{};
    for (final fecha in fechas) {
      final delDia = await _reservations
          .getActiveReservationsByRestaurantAndDate(
            restauranteId: restauranteId,
            fechaLocal: fecha,
          );
      for (final res in delDia) {
        if (res.id.isNotEmpty && !vistos.add(res.id)) continue;
        if (intervalsOverlap(
          inicio,
          fin,
          res.effectiveStart,
          res.effectiveEnd.add(Duration(minutes: margenLimpiezaMin)),
        )) {
          result.add(res);
        }
      }
    }
    return result;
  }

  DaySchedule? _scheduleFor(RestaurantModel restaurant, String dayName) {
    for (final entry in restaurant.horarios.entries) {
      if (ScheduleUtils.normalizeDayName(entry.key) == dayName) {
        return entry.value;
      }
    }
    return null;
  }
}
