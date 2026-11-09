import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/arrival_alert.dart';
import '../models/daily_metrics.dart';
import '../models/mesa_model.dart';
import '../models/operations_config.dart';
import '../models/order_status_flow.dart';
import '../models/reservation_model.dart';
import '../models/restaurant_time.dart';
import '../models/table_live_status.dart';
import '../repositories/reservation_repository.dart';
import '../services/admin_alert_service.dart';
import '../services/operations_config_service.dart';
import '../services/reminder_service.dart';
import '../services/table_status_service.dart';

/// Estado operativo del día del restaurante, compartido por el dashboard (HU25),
/// las alertas de llegada (HU30), los pedidos (HU29) y las mesas (HU31).
///
/// Escucha en tiempo real las reservas de hoy y las mesas, y recalcula métricas,
/// alertas y estado de mesas cada vez que algo cambia y cada [tick] (el paso del
/// tiempo también cambia las alertas; con [tick] en cero no hay temporizador). Mientras está abierto registra las alertas
/// nuevas (sin duplicarlas) y procesa los recordatorios vencidos.
class AdminOperationsViewModel extends ChangeNotifier {
  final String restaurantId;
  final ReservationRepository _reservas;
  final TableStatusService _mesasService;
  final OperationsConfigService _configService;
  final AdminAlertService _alertService;
  final ReminderService _reminderService;
  final DateTime Function() _now;
  final Duration tick;
  final bool sincronizar;
  final String Function()? _usuarioId;

  OperationsConfig _config = const OperationsConfig();
  List<ReservationModel> _reservasHoy = const [];
  List<MesaModel> _mesas = const [];
  List<ArrivalAlert> _alertas = const [];
  List<TableLiveStatus> _estadosMesas = const [];
  DailyMetrics _metricas = DailyMetrics.vacias;

  bool _reservasListas = false;
  bool _mesasListas = false;
  String? _error;
  bool _sincronizando = false;
  bool _disposed = false;
  String _fechaEscuchada = '';

  StreamSubscription<List<ReservationModel>>? _reservasSub;
  StreamSubscription<List<MesaModel>>? _mesasSub;
  Timer? _timer;

  AdminOperationsViewModel({
    required this.restaurantId,
    ReservationRepository? reservas,
    TableStatusService? mesasService,
    OperationsConfigService? configService,
    AdminAlertService? alertService,
    ReminderService? reminderService,
    DateTime Function()? now,
    this.tick = const Duration(minutes: 1),
    this.sincronizar = true,
    String Function()? usuarioId,
  })  : _reservas = reservas ?? ReservationService(),
        _mesasService = mesasService ?? TableStatusService(),
        _configService = configService ?? OperationsConfigService(),
        _alertService = alertService ?? AdminAlertService(),
        _reminderService = reminderService ?? ReminderService(),
        _now = now ?? DateTime.now,
        // ignore: prefer_initializing_formals
        _usuarioId = usuarioId;

  /// Repositorio con el que se consultan y actualizan las reservas.
  ReservationRepository get reservasRepositorio => _reservas;

  /// Quién hace los cambios (para la trazabilidad).
  String get usuarioActual => _usuarioActual();

  OperationsConfig get config => _config;
  List<ReservationModel> get reservasHoy => List.unmodifiable(_reservasHoy);
  List<MesaModel> get mesas => List.unmodifiable(_mesas);
  List<ArrivalAlert> get alertas => List.unmodifiable(_alertas);
  List<TableLiveStatus> get estadosMesas => List.unmodifiable(_estadosMesas);
  DailyMetrics get metricas => _metricas;

  /// Primera carga todavía en curso (para mostrar el indicador de carga).
  bool get cargando => !(_reservasListas && _mesasListas) && _error == null;
  String? get error => _error;

  /// Reservas de hoy con preorden, de la más próxima a la más lejana (HU29).
  List<ReservationModel> get pedidos => [
        for (final r in _reservasHoy)
          if (r.tienePreorden && r.bloqueaMesas) r,
      ];

  /// Alerta de llegada de una reserva, si la tiene (HU30-RF03).
  ArrivalAlert? alertaDe(String reservaId) =>
      ArrivalAlertCalculator.deReserva(_alertas, reservaId);

  /// Estado de una mesa.
  TableLiveStatus? estadoDeMesa(String mesaId) {
    for (final e in _estadosMesas) {
      if (e.mesa.id == mesaId) return e;
    }
    return null;
  }

  /// Reserva de hoy por id.
  ReservationModel? reservaPorId(String id) {
    for (final r in _reservasHoy) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Carga los ajustes y empieza a escuchar las reservas de hoy y las mesas.
  Future<void> iniciar() async {
    _error = null;
    _reservasListas = false;
    _mesasListas = false;
    notifyListeners();
    try {
      _config = await _configService.cargar(restaurantId);
    } catch (_) {
      _config = const OperationsConfig();
    }
    if (_disposed) return;
    _suscribirReservas();
    _suscribirMesas();
    _timer?.cancel();
    if (tick > Duration.zero) {
      _timer = Timer.periodic(tick, (_) => _alTick());
    }
  }

  /// Vuelve a cargar todo (pull-to-refresh como respaldo del tiempo real).
  Future<void> refrescar() async {
    await _reservasSub?.cancel();
    await _mesasSub?.cancel();
    await iniciar();
    // Espera a que llegue la primera lectura para que el indicador se cierre bien.
    for (var i = 0; i < 50 && cargando && !_disposed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  String _hoy() => RestaurantTime.fechaLocalHoy(_config.zonaHoraria, _now());

  void _suscribirReservas() {
    _reservasSub?.cancel();
    _fechaEscuchada = _hoy();
    try {
      _reservasSub = _reservas
          .getReservationsStream(
            restauranteId: restaurantId,
            fechaLocal: _fechaEscuchada,
          )
          .listen(
        (lista) {
          _reservasHoy = ReservationModel.sortByStartTime(lista);
          _reservasListas = true;
          _error = null;
          _recalcular();
          unawaited(_sincronizar());
        },
        onError: (Object e) {
          _error = 'No se pudieron cargar las reservas del día.';
          notifyListeners();
        },
      );
    } catch (_) {
      _error = 'No se pudieron cargar las reservas del día.';
      notifyListeners();
    }
  }

  void _suscribirMesas() {
    _mesasSub?.cancel();
    try {
      _mesasSub = _mesasService.mesasStream(restaurantId).listen(
        (lista) {
          _mesas = lista;
          _mesasListas = true;
          _recalcular();
        },
        onError: (Object e) {
          _error = 'No se pudieron cargar las mesas.';
          notifyListeners();
        },
      );
    } catch (_) {
      _error = 'No se pudieron cargar las mesas.';
      notifyListeners();
    }
  }

  void _alTick() {
    // Cambió el día en el restaurante: se escuchan las reservas del nuevo día.
    if (_hoy() != _fechaEscuchada) {
      _reservasListas = false;
      _suscribirReservas();
    }
    _recalcular();
    unawaited(_sincronizar());
  }

  /// Recalcula métricas, alertas y estado de mesas con la hora actual.
  void _recalcular() {
    if (_disposed) return;
    final ahora = _now();
    _metricas = DailyMetrics.calcular(
      reservas: _reservasHoy,
      mesas: _mesas,
      ahora: ahora,
      zonaHoraria: _config.zonaHoraria,
    );
    _estadosMesas = TableLiveStatusCalculator.calcular(
      mesas: _mesas,
      reservas: _reservasHoy,
      ahora: ahora,
    );
    _alertas = ArrivalAlertCalculator.calcular(
      reservas: _reservasHoy,
      ahora: ahora,
      config: _config,
    );
    notifyListeners();
  }

  /// Registra las alertas nuevas y envía los recordatorios que ya tocan.
  Future<void> _sincronizar() async {
    if (!sincronizar || _sincronizando || !_reservasListas || _disposed) return;
    _sincronizando = true;
    try {
      final ahora = _now();
      try {
        await _alertService.sincronizar(
          restauranteId: restaurantId,
          reservas: _reservasHoy,
          ahora: ahora,
          config: _config,
        );
      } catch (_) {}
      try {
        await _reminderService.procesar(
          restauranteId: restaurantId,
          reservas: _reservasHoy,
          ahora: ahora,
          config: _config,
        );
      } catch (_) {}
    } finally {
      _sincronizando = false;
    }
  }

  String _usuarioActual() {
    try {
      return _usuarioId?.call() ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  /// Cambia el estado del pedido (HU29-RF02). Devuelve un mensaje de error o null.
  Future<String?> cambiarEstadoPedido(
    String reservaId,
    String nuevoEstado, {
    String? motivo,
  }) async {
    try {
      await _reservas.changeOrderState(
        reservationId: reservaId,
        nuevoEstado: nuevoEstado,
        usuarioId: _usuarioActual(),
        motivo: motivo,
        ahora: _now(),
      );
      return null;
    } on InvalidOrderTransitionException catch (e) {
      return e.motivo;
    } catch (_) {
      return 'No se pudo cambiar el estado del pedido. Revisa tu conexión e intenta de nuevo.';
    }
  }

  /// Marca una mesa fuera de servicio (HU31-RF02). Devuelve un mensaje de error o null.
  Future<String?> ponerMesaFueraDeServicio(String mesaId) async {
    try {
      await _mesasService.ponerFueraDeServicio(restaurantId, mesaId);
      return null;
    } catch (_) {
      return 'No se pudo cambiar el estado de la mesa. Intenta de nuevo.';
    }
  }

  /// Vuelve a activar una mesa (HU31-RF02). Devuelve un mensaje de error o null.
  Future<String?> reactivarMesa(String mesaId) async {
    try {
      await _mesasService.reactivar(restaurantId, mesaId);
      return null;
    } catch (_) {
      return 'No se pudo cambiar el estado de la mesa. Intenta de nuevo.';
    }
  }

  /// Guarda el umbral y las alertas (HU30-RF03). Devuelve un mensaje de error o null.
  Future<String?> guardarConfig(OperationsConfig nueva) async {
    try {
      await _configService.guardar(restaurantId, nueva);
      _config = nueva;
      _recalcular();
      return null;
    } on ArgumentError catch (e) {
      return e.message.toString();
    } catch (_) {
      return 'No se pudieron guardar los ajustes. Intenta de nuevo.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _reservasSub?.cancel();
    _mesasSub?.cancel();
    super.dispose();
  }
}
