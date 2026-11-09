import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/order_status_flow.dart';
import '../models/reservation_model.dart';
import '../models/reservation_status_flow.dart';
import '../repositories/reservation_repository.dart';

/// ViewModel para la consulta y pantalla de listado de reservas del restaurante (HU26-RF01 y HU26-RF02)
class AdminReservationsViewModel extends ChangeNotifier {
  final String restaurantId;
  final ReservationRepository _reservationRepository;
  final String Function()? _usuarioId;

  DateTime _fechaSeleccionada;
  String? _estadoFiltro;
  bool _isLoading = false;
  String? _errorMessage;
  List<ReservationModel> _reservasDelDia = [];

  StreamSubscription<List<ReservationModel>>? _subscription;

  AdminReservationsViewModel({
    required this.restaurantId,
    ReservationRepository? reservationRepository,
    DateTime? initialDate,

    /// Quién cambia los estados (para la trazabilidad); por defecto el usuario con sesión.
    String Function()? usuarioId,
  })  : _reservationRepository = reservationRepository ?? ReservationService(),
        // ignore: prefer_initializing_formals
        _usuarioId = usuarioId,
        _fechaSeleccionada = _normalizarFecha(initialDate ?? DateTime.now());

  static DateTime _normalizarFecha(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  DateTime get fechaSeleccionada => _fechaSeleccionada;

  /// Fecha seleccionada en formato 'YYYY-MM-DD'
  String get fechaLocalSeleccionada =>
      ReservationService.formatDateLocal(_fechaSeleccionada);

  /// Indica si la fecha seleccionada corresponde al día de hoy
  bool get esHoy {
    final hoy = _normalizarFecha(DateTime.now());
    return _fechaSeleccionada.year == hoy.year &&
        _fechaSeleccionada.month == hoy.month &&
        _fechaSeleccionada.day == hoy.day;
  }

  /// Filtro de estado actual (null = todas las reservas del día)
  String? get estadoFiltro => _estadoFiltro;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  bool get hasError => _errorMessage != null;

  /// Todas las reservas del día actual ordenadas cronológicamente por hora de inicio (HU26-RF01 Criterio 1)
  List<ReservationModel> get todasLasReservasDelDia =>
      List.unmodifiable(_reservasDelDia);

  /// Reservas del día filtradas por estado y ordenadas cronológicamente por hora de inicio (HU26-RF01 y HU26-RF02)
  List<ReservationModel> get reservas {
    if (_estadoFiltro == null || _estadoFiltro!.trim().isEmpty) {
      return List.unmodifiable(_reservasDelDia);
    }
    return List.unmodifiable(
      _reservasDelDia
          .where((r) => r.matchesEstadoFiltro(_estadoFiltro))
          .toList(),
    );
  }

  /// Cuenta cuántas reservas del día coinciden con un estado específico (o todas si [estado] es null)
  int contarPorEstado(String? estado) {
    if (estado == null || estado.trim().isEmpty) {
      return _reservasDelDia.length;
    }
    return _reservasDelDia.where((r) => r.matchesEstadoFiltro(estado)).length;
  }

  /// Inicia o reinicia la suscripción en tiempo real a las reservas del restaurante para la fecha seleccionada (HU26-RF02 Criterio 5)
  void iniciarEscuchaEnTiempoReal() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _subscription = _reservationRepository
          .getReservationsStream(
            restauranteId: restaurantId,
            fechaLocal: fechaLocalSeleccionada,
          )
          .listen(
            (lista) {
              _reservasDelDia = ReservationModel.sortByStartTime(lista);
              _isLoading = false;
              _errorMessage = null;
              notifyListeners();
            },
            onError: (Object error) {
              _isLoading = false;
              _errorMessage =
                  'No se pudieron cargar las reservas: ${error.toString().replaceFirst("Exception: ", "")}';
              notifyListeners();
            },
          );
    } catch (error) {
      _isLoading = false;
      _errorMessage =
          'No se pudieron cargar las reservas: ${error.toString().replaceFirst("Exception: ", "")}';
      notifyListeners();
    }
  }

  /// Cambia la fecha de consulta y actualiza la escucha en tiempo real (HU26-RF02 Criterio 2)
  void seleccionarFecha(DateTime nuevaFecha) {
    final normalizada = _normalizarFecha(nuevaFecha);
    if (normalizada == _fechaSeleccionada && _subscription != null && !hasError) {
      return;
    }
    _fechaSeleccionada = normalizada;
    iniciarEscuchaEnTiempoReal();
  }

  /// Avanza o retrocede días respecto a la fecha seleccionada
  void cambiarDia(int diasOffset) {
    seleccionarFecha(_fechaSeleccionada.add(Duration(days: diasOffset)));
  }

  /// Restablece la fecha seleccionada al día de hoy
  void irAHoy() {
    seleccionarFecha(DateTime.now());
  }

  /// Aplica o limpia el filtro por estado (HU26-RF01 Criterio 3)
  void seleccionarFiltroEstado(String? nuevoEstado) {
    final limpio = (nuevoEstado == null ||
            nuevoEstado.trim().isEmpty ||
            nuevoEstado.trim().toLowerCase() == 'todos')
        ? null
        : ReservationModel.normalizeStatus(nuevoEstado);

    if (_estadoFiltro == limpio) return;
    _estadoFiltro = limpio;
    notifyListeners();
  }

  /// Repositorio con el que se consultan y actualizan las reservas.
  ReservationRepository get repositorio => _reservationRepository;

  String _usuarioActual() {
    try {
      return _usuarioId?.call() ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  /// Cambia el estado operativo de una reserva (HU27-RF02). Devuelve un mensaje
  /// de error si no se pudo, o null si se aplicó; el listado se actualiza solo
  /// por la escucha en tiempo real.
  Future<String?> cambiarEstado(String reservaId, String nuevoEstado) async {
    try {
      await _reservationRepository.changeOperationalState(
        reservationId: reservaId,
        nuevoEstado: nuevoEstado,
        usuarioId: _usuarioActual(),
      );
      return null;
    } on InvalidStateTransitionException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo cambiar el estado. Revisa tu conexión e intenta de nuevo.';
    }
  }

  /// Cambia el estado del pedido preordenado (HU29-RF02). Devuelve un mensaje de error
  /// si no se pudo, o null si se aplicó.
  Future<String?> cambiarEstadoPedido(
    String reservaId,
    String nuevoEstado, {
    String? motivo,
  }) async {
    try {
      await _reservationRepository.changeOrderState(
        reservationId: reservaId,
        nuevoEstado: nuevoEstado,
        usuarioId: _usuarioActual(),
        motivo: motivo,
      );
      return null;
    } on InvalidOrderTransitionException catch (e) {
      return e.motivo;
    } catch (_) {
      return 'No se pudo cambiar el estado del pedido. Revisa tu conexión e intenta de nuevo.';
    }
  }

  /// Reintenta la carga en caso de error (HU26-RF02 Criterio 4)
  void reintentar() {
    iniciarEscuchaEnTiempoReal();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
