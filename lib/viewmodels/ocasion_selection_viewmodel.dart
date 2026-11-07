import 'package:flutter/foundation.dart';

import '../models/experiencia_model.dart';
import '../models/occasion_booking.dart';
import '../models/ocasion_model.dart';
import '../models/platillo_model.dart';
import 'pedido_viewmodel.dart';

/// Selección de la ocasión especial, sus experiencias y los mensajes de felicitación
/// de los postres (HU18-RF02, HU18-RF03 y HU18-RF04).
class OcasionSelectionViewModel extends ChangeNotifier {
  /// Ocasiones disponibles del restaurante (con sus experiencias activas).
  final List<OcasionModel> ocasiones;

  /// Pedido del visitante: a él se agregan los postres elegidos para felicitar.
  final PedidoViewModel pedido;

  /// Catálogo completo de postres del restaurante.
  final List<PlatilloModel> catalogoPostres;

  /// Categorías que cuentan como postre, para reconocer los postres del pedido.
  final Set<String> categoriasPostre;

  static const String textoSinOcasion = 'No celebro nada especial, continuar';
  static const String avisoInformacionPendiente =
      'Completa la información de las experiencias seleccionadas para continuar';

  OcasionModel? _ocasion;
  String _detalleOtro = '';
  final List<String> _experienciaIds = [];

  /// Postres elegidos para felicitar, en orden, con su mensaje (aún sin guardar).
  final List<String> _postresFelicitados = [];
  final Map<String, String> _mensajes = {};

  /// Postres que se agregaron al pedido solo por la felicitación.
  final Set<String> _agregadosPorFelicitacion = {};

  /// Mensajes ya guardados (botón "Guardar n felicitaciones").
  final Map<String, String> _guardados = {};

  OcasionSelectionViewModel({
    required this.ocasiones,
    required this.pedido,
    this.catalogoPostres = const [],
    this.categoriasPostre = const {},
    Map<String, dynamic>? ocasionInicial,
    List<Map<String, dynamic>> experienciasIniciales = const [],
  }) {
    _restaurar(ocasionInicial, experienciasIniciales);
  }

  void _restaurar(Map<String, dynamic>? ocasion, List<Map<String, dynamic>> exps) {
    final id = (ocasion?['ocasionId'] ?? ocasion?['id'] ?? '').toString();
    for (final o in ocasiones) {
      if (o.id == id) _ocasion = o;
    }
    if (_ocasion == null) return;
    _detalleOtro = (ocasion?['detalle'] ?? '').toString();
    for (final e in exps) {
      final eid = (e['experienciaId'] ?? e['id'] ?? '').toString();
      if (experienciasDeOcasion.any((x) => x.id == eid)) _experienciaIds.add(eid);
    }
    // Felicitaciones que ya estaban en el pedido.
    for (final item in pedido.items) {
      if (item.mensajeFelicitacion.isNotEmpty) {
        _postresFelicitados.add(item.platilloId);
        _mensajes[item.platilloId] = item.mensajeFelicitacion;
        _guardados[item.platilloId] = item.mensajeFelicitacion;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // HU18-RF02: tipo de ocasión
  // ---------------------------------------------------------------------------

  OcasionModel? get ocasionSeleccionada => _ocasion;
  bool get hayOcasion => _ocasion != null;
  bool esSeleccionada(OcasionModel o) => _ocasion?.id == o.id;

  /// "Otro": se pide al visitante que cuente qué celebra.
  bool get esOtro =>
      _ocasion != null && _ocasion!.tipoPredefinido == OcasionModel.tipoOtro;

  String get detalleOtro => _detalleOtro;

  /// Solo una ocasión a la vez: elegir otra reemplaza la anterior y tocar la
  /// elegida la quita.
  void seleccionarOcasion(OcasionModel o) {
    if (_ocasion?.id == o.id) {
      limpiar();
      return;
    }
    _quitarFelicitaciones();
    _ocasion = o;
    _experienciaIds.clear();
    _detalleOtro = '';
    notifyListeners();
  }

  /// No celebra nada especial.
  void limpiar() {
    _quitarFelicitaciones();
    _ocasion = null;
    _experienciaIds.clear();
    _detalleOtro = '';
    notifyListeners();
  }

  void setDetalleOtro(String texto) {
    _detalleOtro = OccasionBooking.limpiar(texto, OccasionBooking.maxCaracteresDetalle);
    notifyListeners();
  }

  /// Texto del botón principal: sin ocasión avisa que se continúa sin experiencias.
  String get textoContinuar => hayOcasion ? 'Continuar' : textoSinOcasion;

  // ---------------------------------------------------------------------------
  // HU18-RF03: experiencias
  // ---------------------------------------------------------------------------

  List<ExperienciaModel> get experienciasDeOcasion {
    final lista = [
      for (final e in _ocasion?.experiencias ?? const <ExperienciaModel>[])
        if (e.activo) e,
    ]..sort((a, b) => a.orden.compareTo(b.orden));
    return lista;
  }

  List<ExperienciaModel> get experienciasSeleccionadas => [
        for (final e in experienciasDeOcasion)
          if (_experienciaIds.contains(e.id)) e,
      ];

  bool experienciaMarcada(ExperienciaModel e) => _experienciaIds.contains(e.id);

  void toggleExperiencia(ExperienciaModel e) {
    if (_ocasion == null) return;
    if (_experienciaIds.contains(e.id)) {
      _experienciaIds.remove(e.id);
      if (e.requiereInformacion) _quitarFelicitaciones();
    } else {
      _experienciaIds.add(e.id);
    }
    notifyListeners();
  }

  /// Costo adicional de las experiencias con precio; las gratuitas no suman.
  double get totalExperiencias => experienciasSeleccionadas
      .fold<double>(0.0, (acc, e) => acc + (e.esGratis ? 0.0 : e.precio));

  /// Hay una experiencia elegida que necesita datos del visitante y aún no los dio.
  bool get informacionPendiente {
    for (final e in experienciasSeleccionadas) {
      if (e.requiereInformacion && _guardados.isEmpty) return true;
    }
    return false;
  }

  /// "Continuar" se deshabilita mientras falte información (Criterio 3).
  bool get puedeContinuar => !informacionPendiente;

  bool get postreConFelicitacionElegido =>
      experienciasSeleccionadas.any((e) => e.requiereInformacion);

  // ---------------------------------------------------------------------------
  // HU18-RF04: postre con felicitación
  // ---------------------------------------------------------------------------

  bool esPostre(PedidoItem item) => categoriasPostre.contains(item.categoriaId);

  /// Postres que el visitante ya tiene en su pedido.
  List<PedidoItem> get postresEnPedido =>
      [for (final i in pedido.items) if (esPostre(i)) i];

  bool get tienePostresEnPedido => postresEnPedido.isNotEmpty;

  /// Postres del catálogo que todavía no se eligieron para felicitar.
  List<PlatilloModel> get postresParaAgregar => [
        for (final p in catalogoPostres)
          if (!_postresFelicitados.contains(p.id)) p,
      ];

  List<String> get postresFelicitados => List.unmodifiable(_postresFelicitados);

  String nombreDePostre(String platilloId) {
    final item = pedido.obtenerItem(platilloId);
    if (item != null) return item.nombre;
    for (final p in catalogoPostres) {
      if (p.id == platilloId) return p.nombre;
    }
    return platilloId;
  }

  String mensajeDe(String platilloId) => _mensajes[platilloId] ?? '';

  /// Elige un postre para felicitar. Si no estaba en el pedido se agrega con su
  /// costo normal; el mensaje nunca tiene costo.
  void elegirPostre(PlatilloModel postre) {
    if (_postresFelicitados.contains(postre.id)) return;
    if (pedido.obtenerItem(postre.id) == null) {
      pedido.agregarPlatillo(postre);
      _agregadosPorFelicitacion.add(postre.id);
    }
    _postresFelicitados.add(postre.id);
    _mensajes.putIfAbsent(postre.id, () => '');
    notifyListeners();
  }

  /// Elige un postre que ya estaba en el pedido.
  void elegirPostreDelPedido(PedidoItem item) {
    if (_postresFelicitados.contains(item.platilloId)) return;
    _postresFelicitados.add(item.platilloId);
    _mensajes.putIfAbsent(item.platilloId, () => item.mensajeFelicitacion);
    notifyListeners();
  }

  void quitarPostre(String platilloId) {
    _postresFelicitados.remove(platilloId);
    _mensajes.remove(platilloId);
    _guardados.remove(platilloId);
    pedido.establecerMensajeFelicitacion(platilloId, '');
    if (_agregadosPorFelicitacion.remove(platilloId)) {
      pedido.eliminarPlatillo(platilloId);
    }
    notifyListeners();
  }

  void setMensaje(String platilloId, String mensaje) {
    if (!_postresFelicitados.contains(platilloId)) return;
    _mensajes[platilloId] = OccasionBooking.limpiar(
      mensaje,
      OccasionBooking.maxCaracteresMensaje,
    );
    notifyListeners();
  }

  int get cantidadFelicitaciones => _postresFelicitados.length;

  /// Cada postre elegido necesita su mensaje.
  bool get puedeGuardarFelicitaciones =>
      _postresFelicitados.isNotEmpty &&
      _postresFelicitados.every((id) => mensajeDe(id).trim().isNotEmpty);

  String get textoGuardarFelicitaciones {
    final n = cantidadFelicitaciones;
    return 'Guardar $n ${n == 1 ? 'felicitación' : 'felicitaciones'}';
  }

  /// Confirma los mensajes y los asocia a cada línea de postre del pedido.
  bool guardarFelicitaciones() {
    if (!puedeGuardarFelicitaciones) return false;
    _guardados.clear();
    for (final id in _postresFelicitados) {
      final mensaje = mensajeDe(id).trim();
      pedido.establecerMensajeFelicitacion(id, mensaje);
      _guardados[id] = mensaje;
    }
    notifyListeners();
    return true;
  }

  int get felicitacionesGuardadas => _guardados.length;

  /// Deja el pedido como estaba antes de las felicitaciones.
  void _quitarFelicitaciones() {
    for (final id in List.of(_postresFelicitados)) {
      pedido.establecerMensajeFelicitacion(id, '');
      if (_agregadosPorFelicitacion.contains(id)) pedido.eliminarPlatillo(id);
    }
    _postresFelicitados.clear();
    _mensajes.clear();
    _guardados.clear();
    _agregadosPorFelicitacion.clear();
  }

  // ---------------------------------------------------------------------------
  // Resultado para el borrador de la reserva
  // ---------------------------------------------------------------------------

  /// Ocasión elegida para el borrador; null si no celebra nada.
  Map<String, dynamic>? get ocasionEspecialMap {
    final o = _ocasion;
    if (o == null) return null;
    return {
      'ocasionId': o.id,
      'nombre': o.nombre,
      'icono': o.icono,
      if (esOtro && _detalleOtro.trim().isNotEmpty) 'detalle': _detalleOtro.trim(),
    };
  }

  List<Map<String, dynamic>> get experienciasMaps => [
        for (final e in experienciasSeleccionadas)
          {
            'experienciaId': e.id,
            'nombre': e.nombre,
            'precio': e.precio,
            'esGratis': e.esGratis,
          },
      ];
}
