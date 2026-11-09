import 'package:flutter/foundation.dart';

import '../models/mesa_model.dart';
import '../models/table_layout_validator.dart';
import '../models/zona_model.dart';
import '../services/table_layout_service.dart';

/// Editor del plano de mesas del administrador (HU34-RF03).
///
/// Los espacios (pisos, patio…) se guardan en cuanto se crean, renombran o eliminan.
/// Las mesas se editan en un borrador y se guardan juntas con [guardar] (todo o nada).
class PlanEditorViewModel extends ChangeNotifier {
  /// Espacio que agrupa las mesas que no tienen espacio asignado.
  static const String sinEspacioId = '__sin_espacio__';

  static const double paso = 10;

  /// Espacio libre entre mesas nuevas: deja lugar a las sillas de ambas.
  static const double separacionEntreMesas = 56;
  static const double anchoLienzo = 1200;
  static const double altoLienzo = 800;

  final String restaurantId;
  final TableLayoutService _service;

  List<ZonaModel> _zonas = [];
  List<MesaModel> _mesas = [];
  List<MesaModel> _guardadas = [];
  String? _zonaActivaId;
  String? _seleccionadaId;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  Map<String, String> _camposConError = {};
  int _contadorTemporal = 0;

  PlanEditorViewModel({
    required this.restaurantId,
    TableLayoutService? service,
  }) : _service = service ?? TableLayoutService();

  // ---------------------------------------------------------------------------
  // Estado
  // ---------------------------------------------------------------------------

  List<ZonaModel> get zonas => List.unmodifiable(_zonas);
  List<MesaModel> get mesas => List.unmodifiable(_mesas);
  bool get cargando => _cargando;
  bool get guardando => _guardando;

  /// Último error (guardar, espacios); null si no hay.
  String? get error => _error;

  /// Campos de la mesa seleccionada con error, tras intentar guardar.
  Map<String, String> get camposConError => Map.unmodifiable(_camposConError);

  String? get zonaActivaId => _zonaActivaId;
  String? get seleccionadaId => _seleccionadaId;

  MesaModel? get seleccionada {
    for (final m in _mesas) {
      if (m.id == _seleccionadaId) return m;
    }
    return null;
  }

  /// Hay mesas sin espacio mientras ya existen espacios: se muestran en su propia pestaña.
  bool get hayMesasSinEspacio => _zonas.isNotEmpty && _mesas.any((m) => _sinZona(m));

  /// Pestañas del editor: los espacios y, si hace falta, "Sin espacio".
  List<ZonaModel> get pestanas => [
        ..._zonas,
        if (hayMesasSinEspacio) const ZonaModel(id: sinEspacioId, nombre: 'Sin espacio', orden: 9999),
      ];

  /// Mesas del espacio activo.
  List<MesaModel> get mesasVisibles => [
        for (final m in _mesas)
          if (_perteneceA(m, _zonaActivaId)) m,
      ];

  bool get hayCambios => !_iguales(_mesas, _guardadas);

  bool _sinZona(MesaModel m) =>
      m.zonaId == null || m.zonaId!.isEmpty || !_zonas.any((z) => z.id == m.zonaId);

  bool _perteneceA(MesaModel m, String? zonaId) {
    if (_zonas.isEmpty || zonaId == null) return true;
    if (zonaId == sinEspacioId) return _sinZona(m);
    return m.zonaId == zonaId;
  }

  static bool _iguales(List<MesaModel> a, List<MesaModel> b) {
    if (a.length != b.length) return false;
    final mapa = {for (final m in b) m.id: m};
    for (final m in a) {
      final o = mapa[m.id];
      if (o == null) return false;
      if (m.nombre != o.nombre ||
          m.capacidad != o.capacidad ||
          m.forma != o.forma ||
          m.ancho != o.ancho ||
          m.alto != o.alto ||
          m.x != o.x ||
          m.y != o.y ||
          m.zonaId != o.zonaId ||
          m.combinable != o.combinable ||
          !listEquals([...m.combinableCon]..sort(), [...o.combinableCon]..sort())) {
        return false;
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Carga
  // ---------------------------------------------------------------------------

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _zonas = await _service.getZonas(restaurantId);
      _guardadas = await _service.getMesas(restaurantId);
      _mesas = List.of(_guardadas);
      _camposConError = {};
      if (_zonaActivaId == null || !pestanas.any((z) => z.id == _zonaActivaId)) {
        _zonaActivaId = pestanas.isEmpty ? null : pestanas.first.id;
      }
      if (seleccionada == null) _seleccionadaId = null;
    } catch (_) {
      _error = 'No se pudo cargar el plano. Revisa tu conexión e intenta de nuevo.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Descarta los cambios de mesas no guardados y vuelve al último plano guardado.
  void descartar() {
    _mesas = List.of(_guardadas);
    _seleccionadaId = null;
    _camposConError = {};
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Espacios (se guardan al momento)
  // ---------------------------------------------------------------------------

  void seleccionarZona(String id) {
    _zonaActivaId = id;
    _seleccionadaId = null;
    notifyListeners();
  }

  /// Crea un espacio y lo deja activo. Devuelve un mensaje de error o null.
  Future<String?> agregarZona(String nombre) async {
    try {
      final zona = await _service.crearZona(restaurantId, nombre);
      _zonas = [..._zonas, zona];
      _zonaActivaId = zona.id;
      _seleccionadaId = null;
      _error = null;
      notifyListeners();
      return null;
    } on LayoutException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo crear el espacio. Intenta de nuevo.';
    }
  }

  Future<String?> renombrarZona(String id, String nombre) async {
    try {
      await _service.renombrarZona(restaurantId, id, nombre);
      _zonas = [
        for (final z in _zonas)
          if (z.id == id) ZonaModel(id: z.id, nombre: nombre.trim(), orden: z.orden) else z,
      ];
      notifyListeners();
      return null;
    } on LayoutException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo renombrar el espacio. Intenta de nuevo.';
    }
  }

  /// Cuántas mesas del borrador pertenecen a un espacio.
  int mesasEnZona(String id) => _mesas.where((m) => m.zonaId == id).length;

  Future<String?> eliminarZona(String id) async {
    final enBorrador = mesasEnZona(id);
    if (enBorrador > 0) {
      return 'Este espacio todavía tiene $enBorrador ${enBorrador == 1 ? 'mesa' : 'mesas'}. '
          'Muévelas a otro espacio o elimínalas antes de borrarlo.';
    }
    try {
      await _service.eliminarZona(restaurantId, id);
      _zonas = _zonas.where((z) => z.id != id).toList();
      if (_zonaActivaId == id) {
        _zonaActivaId = pestanas.isEmpty ? null : pestanas.first.id;
      }
      notifyListeners();
      return null;
    } on LayoutException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo eliminar el espacio. Intenta de nuevo.';
    }
  }

  // ---------------------------------------------------------------------------
  // Mesas (borrador)
  // ---------------------------------------------------------------------------

  static ({double ancho, double alto, int capacidad}) _medidasPorDefecto(String forma) {
    switch (forma) {
      case MesaModel.formaRedonda:
        return (ancho: 100, alto: 100, capacidad: 4);
      case MesaModel.formaRectangular:
        return (ancho: 180, alto: 90, capacidad: 6);
      default:
        return (ancho: 100, alto: 100, capacidad: 4);
    }
  }

  String _nombreNuevo() {
    final usados = _mesas.map((m) => TableLayoutValidator.normalizarNombre(m.nombre)).toSet();
    var n = _mesas.length + 1;
    while (usados.contains(TableLayoutValidator.normalizarNombre('Mesa $n'))) {
      n++;
    }
    return 'Mesa $n';
  }

  String _idTemporal() => '${TableLayoutService.prefijoTemporal}${++_contadorTemporal}';

  String? get _zonaParaMesaNueva {
    final z = _zonaActivaId;
    if (z == null || z == sinEspacioId || _zonas.isEmpty) return null;
    return z;
  }

  /// Agrega una mesa en un lugar libre del espacio activo y la selecciona.
  MesaModel agregarMesa({String forma = MesaModel.formaCuadrada}) {
    final medidas = _medidasPorDefecto(forma);
    final lugar = TableLayoutValidator.primerLugarLibre(
      existentes: mesasVisibles,
      ancho: medidas.ancho,
      alto: medidas.alto,
      anchoPlano: anchoLienzo,
      separacion: separacionEntreMesas,
    );
    final mesa = MesaModel(
      id: _idTemporal(),
      nombre: _nombreNuevo(),
      capacidad: medidas.capacidad,
      forma: forma,
      ancho: medidas.ancho,
      alto: medidas.alto,
      x: lugar.x,
      y: lugar.y,
      zonaId: _zonaParaMesaNueva,
    );
    _mesas = [..._mesas, mesa];
    _seleccionadaId = mesa.id;
    _camposConError = {};
    notifyListeners();
    return mesa;
  }

  MesaModel? _buscar(String id) {
    for (final m in _mesas) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _reemplazar(MesaModel nueva) {
    _mesas = [for (final m in _mesas) if (m.id == nueva.id) nueva else m];
    _camposConError.remove('nombre');
  }

  void seleccionar(String? id) {
    if (_seleccionadaId == id) return;
    _seleccionadaId = id;
    _camposConError = {};
    notifyListeners();
  }

  /// Mueve una mesa a ([x], [y]), alineada a la cuadrícula y dentro del lienzo.
  void moverMesa(String id, double x, double y) {
    final m = _buscar(id);
    if (m == null) return;
    final nx = TableLayoutValidator.alinear(x, paso: paso).clamp(0, anchoLienzo - m.ancho).toDouble();
    final ny = TableLayoutValidator.alinear(y, paso: paso).clamp(0, altoLienzo - m.alto).toDouble();
    if (nx == m.x && ny == m.y) return;
    _reemplazar(m.copyWith(x: nx, y: ny));
    notifyListeners();
  }

  /// Mueve una mesa en relación con su posición actual (arrastre).
  void arrastrarMesa(String id, double dx, double dy) {
    final m = _buscar(id);
    if (m == null) return;
    // Se mueve libre mientras se arrastra y se alinea al soltar con [soltarMesa].
    final nx = ((m.x ?? 0) + dx).clamp(0, anchoLienzo - m.ancho).toDouble();
    final ny = ((m.y ?? 0) + dy).clamp(0, altoLienzo - m.alto).toDouble();
    _reemplazar(m.copyWith(x: nx, y: ny));
    notifyListeners();
  }

  /// Alinea la mesa a la cuadrícula al soltarla.
  void soltarMesa(String id) {
    final m = _buscar(id);
    if (m == null) return;
    moverMesa(id, m.x ?? 0, m.y ?? 0);
  }

  void cambiarNombre(String id, String nombre) {
    final m = _buscar(id);
    if (m == null) return;
    _reemplazar(m.copyWith(nombre: nombre));
    notifyListeners();
  }

  /// Suma o resta sillas a la mesa con el valor actual (no el de la pantalla anterior).
  void ajustarCapacidad(String id, int delta) {
    final m = _buscar(id);
    if (m == null) return;
    cambiarCapacidad(id, m.capacidad + delta);
  }

  void cambiarCapacidad(String id, int capacidad) {
    final m = _buscar(id);
    if (m == null) return;
    final c = capacidad.clamp(
      TableLayoutValidator.capacidadMinima,
      TableLayoutValidator.capacidadMaxima,
    );
    _reemplazar(m.copyWith(capacidad: c));
    _camposConError.remove('capacidad');
    notifyListeners();
  }

  void cambiarForma(String id, String forma) {
    final m = _buscar(id);
    if (m == null || !MesaModel.formasValidas.contains(forma)) return;
    // Al pasar a cuadrada o redonda las medidas se igualan; la rectangular las conserva.
    var ancho = m.ancho;
    var alto = m.alto;
    if (forma != MesaModel.formaRectangular) {
      final lado = ancho < alto ? ancho : alto;
      ancho = lado;
      alto = lado;
    } else if (ancho == alto) {
      ancho = (alto * 1.8).clamp(TableLayoutValidator.tamanoMinimo, TableLayoutValidator.tamanoMaximo).toDouble();
    }
    _reemplazar(m.copyWith(forma: forma, ancho: ancho, alto: alto));
    notifyListeners();
  }

  void cambiarTamano(String id, {double? ancho, double? alto}) {
    final m = _buscar(id);
    if (m == null) return;
    var a = (ancho ?? m.ancho).clamp(TableLayoutValidator.tamanoMinimo, TableLayoutValidator.tamanoMaximo).toDouble();
    var h = (alto ?? m.alto).clamp(TableLayoutValidator.tamanoMinimo, TableLayoutValidator.tamanoMaximo).toDouble();
    // Una mesa redonda o cuadrada mantiene lados iguales.
    if (m.forma != MesaModel.formaRectangular) {
      if (ancho != null) h = a;
      if (alto != null && ancho == null) a = h;
    }
    _reemplazar(m.copyWith(ancho: a, alto: h));
    notifyListeners();
  }

  void cambiarCombinable(String id, bool valor) {
    final m = _buscar(id);
    if (m == null) return;
    _reemplazar(m.copyWith(combinable: valor, combinableCon: valor ? m.combinableCon : const []));
    if (!valor) {
      // Las demás dejan de listar a esta mesa.
      _mesas = [
        for (final o in _mesas)
          if (o.combinableCon.contains(id))
            o.copyWith(combinableCon: o.combinableCon.where((c) => c != id).toList())
          else
            o,
      ];
    }
    notifyListeners();
  }

  /// Une o separa dos mesas combinables.
  void alternarCombinacion(String id, String otraId) {
    final a = _buscar(id);
    final b = _buscar(otraId);
    if (a == null || b == null || id == otraId || !a.combinable || !b.combinable) return;
    final unidas = a.combinableCon.contains(otraId);
    final nuevaA = unidas
        ? a.combinableCon.where((c) => c != otraId).toList()
        : [...a.combinableCon, otraId];
    final nuevaB = unidas
        ? b.combinableCon.where((c) => c != id).toList()
        : [...b.combinableCon, id];
    _reemplazar(a.copyWith(combinableCon: nuevaA));
    _reemplazar(b.copyWith(combinableCon: nuevaB));
    notifyListeners();
  }

  /// Pasa la mesa a otro espacio (y la deja en un lugar libre de ese espacio).
  void moverAEspacio(String id, String zonaId) {
    final m = _buscar(id);
    if (m == null) return;
    final destino = zonaId == sinEspacioId ? null : zonaId;
    final enDestino = [
      for (final o in _mesas)
        if (o.id != id && (destino == null ? _sinZona(o) : o.zonaId == destino)) o,
    ];
    final lugar = TableLayoutValidator.primerLugarLibre(
      existentes: enDestino,
      ancho: m.ancho,
      alto: m.alto,
      anchoPlano: anchoLienzo,
      separacion: separacionEntreMesas,
    );
    final movida = MesaModel(
      id: m.id,
      nombre: m.nombre,
      capacidad: m.capacidad,
      combinable: m.combinable,
      combinableCon: m.combinableCon,
      zonaId: destino,
      x: lugar.x,
      y: lugar.y,
      forma: m.forma,
      ancho: m.ancho,
      alto: m.alto,
      estadoManual: m.estadoManual,
    );
    _reemplazar(movida);
    if (_zonaActivaId != null && zonaId != _zonaActivaId) {
      _zonaActivaId = zonaId;
    }
    notifyListeners();
  }

  /// Copia la mesa con otro nombre, a un lado, y la selecciona.
  MesaModel? duplicarMesa(String id) {
    final m = _buscar(id);
    if (m == null) return null;
    final lugar = TableLayoutValidator.primerLugarLibre(
      existentes: mesasVisibles,
      ancho: m.ancho,
      alto: m.alto,
      anchoPlano: anchoLienzo,
      separacion: separacionEntreMesas,
    );
    final copia = MesaModel(
      id: _idTemporal(),
      nombre: _nombreNuevo(),
      capacidad: m.capacidad,
      forma: m.forma,
      ancho: m.ancho,
      alto: m.alto,
      x: lugar.x,
      y: lugar.y,
      zonaId: m.zonaId,
    );
    _mesas = [..._mesas, copia];
    _seleccionadaId = copia.id;
    notifyListeners();
    return copia;
  }

  void eliminarMesa(String id) {
    _mesas = [
      for (final m in _mesas)
        if (m.id != id)
          m.combinableCon.contains(id)
              ? m.copyWith(combinableCon: m.combinableCon.where((c) => c != id).toList())
              : m,
    ];
    if (_seleccionadaId == id) _seleccionadaId = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Validación y guardado
  // ---------------------------------------------------------------------------

  /// Errores de la mesa [id] con el borrador actual, para mostrarlos junto a sus campos.
  Map<String, String> erroresDe(String id) {
    final m = _buscar(id);
    if (m == null) return const {};
    return TableLayoutValidator.validarMesa(
      m,
      otras: _mesas,
      zonaIds: {for (final z in _zonas) z.id},
    );
  }

  /// Mesas del borrador con algún error.
  List<MesaModel> get mesasConError => [
        for (final m in _mesas)
          if (erroresDe(m.id).isNotEmpty) m,
      ];

  /// Guarda el plano. Devuelve true si se guardó.
  Future<bool> guardar() async {
    final conError = mesasConError;
    if (conError.isNotEmpty) {
      final primera = conError.first;
      _seleccionadaId = primera.id;
      if (_zonaActivaId != null &&
          _zonas.isNotEmpty &&
          !_perteneceA(primera, _zonaActivaId)) {
        _zonaActivaId = _sinZona(primera) ? sinEspacioId : primera.zonaId;
      }
      _camposConError = erroresDe(primera.id);
      final nombre = primera.nombre.trim().isEmpty ? 'Una mesa' : primera.nombre.trim();
      _error = '$nombre: ${_camposConError.values.first}';
      notifyListeners();
      return false;
    }

    _guardando = true;
    _error = null;
    _camposConError = {};
    notifyListeners();
    try {
      await _service.guardarPlano(
        restauranteId: restaurantId,
        mesas: _mesas,
      );
      _guardando = false;
      await cargar();
      return true;
    } on LayoutException catch (e) {
      _error = e.message;
      _camposConError = e.campos;
      return false;
    } catch (_) {
      _error = 'No se pudo guardar el plano. Revisa tu conexión e intenta de nuevo.';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }
}
