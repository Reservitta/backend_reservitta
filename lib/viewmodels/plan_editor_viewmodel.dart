import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../models/elemento_plano.dart';
import '../models/mesa_model.dart';
import '../models/plantillas_plano.dart';
import '../models/table_layout_validator.dart';
import '../models/zona_model.dart';
import '../services/table_layout_service.dart';

/// Cómo se alinean varios elementos seleccionados.
enum Alineacion { izquierda, centroHorizontal, derecha, arriba, centroVertical, abajo }

/// Mesa lista para arrastrar desde la paleta del editor.
class PresetMesa {
  final String id;
  final String etiqueta;
  final String forma;
  final int capacidad;
  final double ancho;
  final double alto;
  final String tipo;

  const PresetMesa({
    required this.id,
    required this.etiqueta,
    required this.forma,
    required this.capacidad,
    required this.ancho,
    required this.alto,
    this.tipo = MesaModel.tipoRegular,
  });
}

class _Instantanea {
  final List<MesaModel> mesas;
  final List<ElementoPlano> elementos;

  const _Instantanea(this.mesas, this.elementos);
}

/// Editor del plano de mesas del administrador (HU34-RF03).
///
/// Los espacios (pisos, patio…) se guardan en cuanto se crean, renombran o eliminan.
/// Las mesas y los elementos decorativos se editan en un borrador y se guardan juntos
/// con [guardar] (todo o nada). El borrador admite deshacer y rehacer.
class PlanEditorViewModel extends ChangeNotifier {
  /// Espacio que agrupa las mesas que no tienen espacio asignado.
  static const String sinEspacioId = '__sin_espacio__';

  static const double paso = 10;

  /// Espacio libre entre mesas nuevas: deja lugar a las sillas de ambas.
  static const double separacionEntreMesas = 56;
  static const double anchoLienzo = 1200;
  static const double altoLienzo = 800;

  /// Cuántos pasos se pueden deshacer.
  static const int maxHistorial = 60;

  /// Mesas que se pueden agregar desde la paleta.
  static const List<PresetMesa> presetsMesa = [
    PresetMesa(id: 'cuadrada_2', etiqueta: 'Cuadrada · 2', forma: MesaModel.formaCuadrada, capacidad: 2, ancho: 80, alto: 80),
    PresetMesa(id: 'cuadrada_4', etiqueta: 'Cuadrada · 4', forma: MesaModel.formaCuadrada, capacidad: 4, ancho: 100, alto: 100),
    PresetMesa(id: 'redonda_2', etiqueta: 'Redonda · 2', forma: MesaModel.formaRedonda, capacidad: 2, ancho: 80, alto: 80),
    PresetMesa(id: 'redonda_4', etiqueta: 'Redonda · 4', forma: MesaModel.formaRedonda, capacidad: 4, ancho: 100, alto: 100),
    PresetMesa(id: 'redonda_6', etiqueta: 'Redonda · 6', forma: MesaModel.formaRedonda, capacidad: 6, ancho: 130, alto: 130),
    PresetMesa(id: 'redonda_8', etiqueta: 'Redonda · 8', forma: MesaModel.formaRedonda, capacidad: 8, ancho: 160, alto: 160),
    PresetMesa(id: 'rectangular_4', etiqueta: 'Rectangular · 4', forma: MesaModel.formaRectangular, capacidad: 4, ancho: 140, alto: 80),
    PresetMesa(id: 'rectangular_6', etiqueta: 'Rectangular · 6', forma: MesaModel.formaRectangular, capacidad: 6, ancho: 180, alto: 90),
    PresetMesa(id: 'rectangular_8', etiqueta: 'Rectangular · 8', forma: MesaModel.formaRectangular, capacidad: 8, ancho: 230, alto: 90),
    PresetMesa(id: 'rectangular_10', etiqueta: 'Rectangular · 10', forma: MesaModel.formaRectangular, capacidad: 10, ancho: 280, alto: 90),
    PresetMesa(id: 'banqueta', etiqueta: 'Banqueta de barra', forma: MesaModel.formaRedonda, capacidad: 1, ancho: 50, alto: 50, tipo: MesaModel.tipoBarra),
    PresetMesa(id: 'alta_2', etiqueta: 'Mesa alta · 2', forma: MesaModel.formaRedonda, capacidad: 2, ancho: 70, alto: 70, tipo: MesaModel.tipoAlta),
    PresetMesa(id: 'sillon_3', etiqueta: 'Sillón · 3', forma: MesaModel.formaRectangular, capacidad: 3, ancho: 150, alto: 70, tipo: MesaModel.tipoSillon),
  ];

  final String restaurantId;
  final TableLayoutService _service;

  List<ZonaModel> _zonas = [];
  List<MesaModel> _mesas = [];
  List<MesaModel> _guardadas = [];
  List<ElementoPlano> _elementos = [];
  List<ElementoPlano> _elementosGuardados = [];
  String? _zonaActivaId;
  String? _seleccionadaId;
  String? _elementoSeleccionadoId;
  final Set<String> _multi = {};
  bool _modoMultiple = false;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  Map<String, String> _camposConError = {};
  int _contadorTemporal = 0;

  final List<_Instantanea> _deshacer = [];
  final List<_Instantanea> _rehacer = [];
  String? _ultimaClave;
  DateTime? _ultimoRegistro;

  PlanEditorViewModel({
    required this.restaurantId,
    TableLayoutService? service,
  }) : _service = service ?? TableLayoutService();

  // ---------------------------------------------------------------------------
  // Estado
  // ---------------------------------------------------------------------------

  List<ZonaModel> get zonas => List.unmodifiable(_zonas);
  List<MesaModel> get mesas => List.unmodifiable(_mesas);
  List<ElementoPlano> get elementos => List.unmodifiable(_elementos);
  bool get cargando => _cargando;
  bool get guardando => _guardando;

  /// Último error (guardar, espacios); null si no hay.
  String? get error => _error;

  /// Campos de la mesa seleccionada con error, tras intentar guardar.
  Map<String, String> get camposConError => Map.unmodifiable(_camposConError);

  String? get zonaActivaId => _zonaActivaId;
  String? get seleccionadaId => _seleccionadaId;
  String? get elementoSeleccionadoId => _elementoSeleccionadoId;
  bool get modoMultiple => _modoMultiple;

  MesaModel? get seleccionada {
    for (final m in _mesas) {
      if (m.id == _seleccionadaId) return m;
    }
    return null;
  }

  ElementoPlano? get elementoSeleccionado {
    for (final e in _elementos) {
      if (e.id == _elementoSeleccionadoId) return e;
    }
    return null;
  }

  /// Hay mesas sin espacio mientras ya existen espacios: se muestran en su propia pestaña.
  bool get hayMesasSinEspacio => _zonas.isNotEmpty && _mesas.any((m) => _sinZona(m.zonaId));

  /// Pestañas del editor: los espacios y, si hace falta, "Sin espacio".
  List<ZonaModel> get pestanas => [
        ..._zonas,
        if (hayMesasSinEspacio) const ZonaModel(id: sinEspacioId, nombre: 'Sin espacio', orden: 9999),
      ];

  /// Mesas del espacio activo.
  List<MesaModel> get mesasVisibles => [
        for (final m in _mesas)
          if (_perteneceA(m.zonaId, _zonaActivaId)) m,
      ];

  /// Elementos decorativos del espacio activo.
  List<ElementoPlano> get elementosVisibles => [
        for (final e in _elementos)
          if (_perteneceA(e.zonaId, _zonaActivaId)) e,
      ];

  bool get hayCambios =>
      !_iguales(_mesas, _guardadas) || !_igualesElementos(_elementos, _elementosGuardados);

  bool get puedeDeshacer => _deshacer.isNotEmpty;
  bool get puedeRehacer => _rehacer.isNotEmpty;

  bool _sinZona(String? zonaId) =>
      zonaId == null || zonaId.isEmpty || !_zonas.any((z) => z.id == zonaId);

  bool _perteneceA(String? zona, String? zonaId) {
    if (_zonas.isEmpty || zonaId == null) return true;
    if (zonaId == sinEspacioId) return _sinZona(zona);
    return zona == zonaId;
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
          m.rotacion != o.rotacion ||
          m.tipo != o.tipo ||
          m.minPersonas != o.minPersonas ||
          m.maxPersonas != o.maxPersonas ||
          !listEquals([...m.combinableCon]..sort(), [...o.combinableCon]..sort())) {
        return false;
      }
    }
    return true;
  }

  static bool _igualesElementos(List<ElementoPlano> a, List<ElementoPlano> b) {
    if (a.length != b.length) return false;
    final mapa = {for (final e in b) e.id: e};
    for (final e in a) {
      final o = mapa[e.id];
      if (o == null) return false;
      if (e.tipo != o.tipo ||
          e.x != o.x ||
          e.y != o.y ||
          e.ancho != o.ancho ||
          e.alto != o.alto ||
          e.rotacion != o.rotacion ||
          e.etiqueta != o.etiqueta ||
          e.zonaId != o.zonaId) {
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
      _elementosGuardados = await _service.getElementos(restaurantId);
      _mesas = List.of(_guardadas);
      _elementos = List.of(_elementosGuardados);
      _camposConError = {};
      _deshacer.clear();
      _rehacer.clear();
      _ultimaClave = null;
      if (_zonaActivaId == null || !pestanas.any((z) => z.id == _zonaActivaId)) {
        _zonaActivaId = pestanas.isEmpty ? null : pestanas.first.id;
      }
      if (seleccionada == null) _seleccionadaId = null;
      if (elementoSeleccionado == null) _elementoSeleccionadoId = null;
      _multi.clear();
    } catch (_) {
      _error = 'No se pudo cargar el plano. Revisa tu conexión e intenta de nuevo.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Descarta los cambios no guardados y vuelve al último plano guardado.
  void descartar() {
    _mesas = List.of(_guardadas);
    _elementos = List.of(_elementosGuardados);
    _seleccionadaId = null;
    _elementoSeleccionadoId = null;
    _multi.clear();
    _camposConError = {};
    _error = null;
    _deshacer.clear();
    _rehacer.clear();
    _ultimaClave = null;
    notifyListeners();
  }

  /// Últimos cambios guardados del plano.
  Future<List<PlanCambio>> historial() async {
    try {
      return await _service.getHistorial(restaurantId);
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Deshacer y rehacer
  // ---------------------------------------------------------------------------

  /// Guarda el estado actual antes de un cambio. Los cambios seguidos de la misma
  /// [clave] (arrastrar, deslizar un tamaño, escribir un nombre) cuentan como uno solo.
  void _registrar(String clave, {bool agrupar = false}) {
    final ahora = DateTime.now();
    final seguido = agrupar &&
        clave == _ultimaClave &&
        _ultimoRegistro != null &&
        ahora.difference(_ultimoRegistro!) < const Duration(milliseconds: 900);
    _ultimoRegistro = ahora;
    _ultimaClave = clave;
    if (seguido) return;
    _deshacer.add(_Instantanea(List.of(_mesas), List.of(_elementos)));
    if (_deshacer.length > maxHistorial) _deshacer.removeAt(0);
    _rehacer.clear();
  }

  void _restaurar(_Instantanea s) {
    _mesas = List.of(s.mesas);
    _elementos = List.of(s.elementos);
    _camposConError = {};
    if (seleccionada == null) _seleccionadaId = null;
    if (elementoSeleccionado == null) _elementoSeleccionadoId = null;
    final ids = {..._mesas.map((m) => m.id), ..._elementos.map((e) => e.id)};
    _multi.removeWhere((id) => !ids.contains(id));
    _ultimaClave = null;
  }

  void deshacer() {
    if (_deshacer.isEmpty) return;
    _rehacer.add(_Instantanea(List.of(_mesas), List.of(_elementos)));
    _restaurar(_deshacer.removeLast());
    notifyListeners();
  }

  void rehacer() {
    if (_rehacer.isEmpty) return;
    _deshacer.add(_Instantanea(List.of(_mesas), List.of(_elementos)));
    _restaurar(_rehacer.removeLast());
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Espacios (se guardan al momento)
  // ---------------------------------------------------------------------------

  void seleccionarZona(String id) {
    _zonaActivaId = id;
    _seleccionadaId = null;
    _elementoSeleccionadoId = null;
    _multi.clear();
    notifyListeners();
  }

  /// Crea un espacio y lo deja activo. Devuelve un mensaje de error o null.
  Future<String?> agregarZona(String nombre) async {
    try {
      final zona = await _service.crearZona(restaurantId, nombre);
      _zonas = [..._zonas, zona];
      _zonaActivaId = zona.id;
      _seleccionadaId = null;
      _elementoSeleccionadoId = null;
      _multi.clear();
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

  /// Cuántos elementos decorativos del borrador pertenecen a un espacio.
  int elementosEnZona(String id) => _elementos.where((e) => e.zonaId == id).length;

  Future<String?> eliminarZona(String id) async {
    final enBorrador = mesasEnZona(id);
    if (enBorrador > 0) {
      return 'Este espacio todavía tiene $enBorrador ${enBorrador == 1 ? 'mesa' : 'mesas'}. '
          'Muévelas a otro espacio o elimínalas antes de borrarlo.';
    }
    final decoracion = elementosEnZona(id);
    if (decoracion > 0) {
      return 'Este espacio todavía tiene $decoracion ${decoracion == 1 ? 'elemento' : 'elementos'} de decoración. '
          'Elimínalos antes de borrar el espacio.';
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

  static PresetMesa _presetPorForma(String forma) {
    switch (forma) {
      case MesaModel.formaRedonda:
        return presetsMesa.firstWhere((p) => p.id == 'redonda_4');
      case MesaModel.formaRectangular:
        return presetsMesa.firstWhere((p) => p.id == 'rectangular_6');
      default:
        return presetsMesa.firstWhere((p) => p.id == 'cuadrada_4');
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

  String? get _zonaParaNuevo {
    final z = _zonaActivaId;
    if (z == null || z == sinEspacioId || _zonas.isEmpty) return null;
    return z;
  }

  /// Primer lugar libre del espacio activo para algo de [ancho] x [alto], contando
  /// mesas y elementos decorativos.
  ({double x, double y}) _lugarLibre(double ancho, double alto) {
    final ocupados = <Rect>[
      for (final m in mesasVisibles)
        if (m.tienePosicion) m.cajaRotada.inflate(separacionEntreMesas / 2),
      for (final e in elementosVisibles) e.cajaRotada.inflate(separacionEntreMesas / 4),
    ];
    bool choca(double x, double y) {
      final r = Rect.fromLTWH(x, y, ancho, alto);
      return ocupados.any((o) => o.overlaps(r));
    }

    for (var y = 20.0; y < 4000; y += 20) {
      for (var x = 20.0; x + ancho <= anchoLienzo; x += 20) {
        if (!choca(x, y)) return (x: x, y: y);
      }
    }
    return (x: 20, y: 20);
  }

  /// Agrega una mesa en un lugar libre del espacio activo y la selecciona.
  MesaModel agregarMesa({String forma = MesaModel.formaCuadrada}) =>
      agregarPreset(_presetPorForma(forma));

  /// Agrega una mesa de la paleta (forma, sillas y tamaño ya definidos).
  MesaModel agregarPreset(PresetMesa p) {
    _registrar('agregar-mesa');
    final lugar = _lugarLibre(p.ancho, p.alto);
    final mesa = MesaModel(
      id: _idTemporal(),
      nombre: _nombreNuevo(),
      capacidad: p.capacidad,
      forma: p.forma,
      ancho: p.ancho,
      alto: p.alto,
      tipo: p.tipo,
      x: lugar.x,
      y: lugar.y,
      zonaId: _zonaParaNuevo,
    );
    _mesas = [..._mesas, mesa];
    _seleccionarSolo(mesaId: mesa.id);
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

  ElementoPlano? _buscarElemento(String id) {
    for (final e in _elementos) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _reemplazar(MesaModel nueva) {
    _mesas = [for (final m in _mesas) if (m.id == nueva.id) nueva else m];
    _camposConError.remove('nombre');
  }

  void _reemplazarElemento(ElementoPlano nuevo) {
    _elementos = [for (final e in _elementos) if (e.id == nuevo.id) nuevo else e];
  }

  void _seleccionarSolo({String? mesaId, String? elementoId}) {
    _seleccionadaId = mesaId;
    _elementoSeleccionadoId = elementoId;
    _multi.clear();
  }

  void seleccionar(String? id) {
    if (_modoMultiple && id != null) {
      alternarEnSeleccion(id);
      return;
    }
    if (_seleccionadaId == id && _elementoSeleccionadoId == null && _multi.isEmpty) return;
    _seleccionarSolo(mesaId: id);
    _camposConError = {};
    notifyListeners();
  }

  void seleccionarElemento(String? id) {
    if (_modoMultiple && id != null) {
      alternarEnSeleccion(id);
      return;
    }
    if (_elementoSeleccionadoId == id && _seleccionadaId == null && _multi.isEmpty) return;
    _seleccionarSolo(elementoId: id);
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
    _registrar('mover-mesa', agrupar: true);
    _reemplazar(m.copyWith(x: nx, y: ny));
    notifyListeners();
  }

  /// Mueve una mesa en relación con su posición actual (arrastre). Si hay varias
  /// seleccionadas y esta es una de ellas, se mueven todas juntas.
  void arrastrarMesa(String id, double dx, double dy) {
    if (_modoMultiple && _multi.contains(id) && _multi.length > 1) {
      _moverGrupo(dx, dy);
      return;
    }
    final m = _buscar(id);
    if (m == null) return;
    _registrar('arrastrar:$id', agrupar: true);
    // Se mueve libre mientras se arrastra y se alinea al soltar con [soltarMesa].
    final nx = ((m.x ?? 0) + dx).clamp(0, anchoLienzo - m.ancho).toDouble();
    final ny = ((m.y ?? 0) + dy).clamp(0, altoLienzo - m.alto).toDouble();
    _reemplazar(m.copyWith(x: nx, y: ny));
    notifyListeners();
  }

  /// Alinea la mesa a la cuadrícula al soltarla.
  void soltarMesa(String id) {
    if (_modoMultiple && _multi.contains(id) && _multi.length > 1) {
      _soltarGrupo();
      return;
    }
    final m = _buscar(id);
    if (m == null) return;
    moverMesa(id, m.x ?? 0, m.y ?? 0);
    _ultimaClave = null;
  }

  void cambiarNombre(String id, String nombre) {
    final m = _buscar(id);
    if (m == null) return;
    _registrar('nombre:$id', agrupar: true);
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
    _registrar('capacidad:$id');
    // El mínimo y el máximo de personas nunca pasan de las sillas.
    final min = m.minPersonas.clamp(1, c);
    final max = m.maxPersonas == null ? null : m.maxPersonas!.clamp(min, c);
    _reemplazar(m.copyWith(capacidad: c, minPersonas: min, maxPersonas: max, sinMaximo: max == null));
    _camposConError.remove('capacidad');
    notifyListeners();
  }

  /// Cambia el mínimo de personas que acepta la mesa.
  void cambiarMinimo(String id, int minimo) {
    final m = _buscar(id);
    if (m == null) return;
    _registrar('minimo:$id');
    final min = minimo.clamp(1, m.capacidad);
    final max = m.maxPersonas == null ? null : m.maxPersonas!.clamp(min, m.capacidad);
    _reemplazar(m.copyWith(minPersonas: min, maxPersonas: max, sinMaximo: max == null));
    notifyListeners();
  }

  /// Cambia el máximo de personas; null lo iguala al número de sillas.
  void cambiarMaximo(String id, int? maximo) {
    final m = _buscar(id);
    if (m == null) return;
    _registrar('maximo:$id');
    if (maximo == null || maximo >= m.capacidad) {
      _reemplazar(m.copyWith(sinMaximo: true));
    } else {
      _reemplazar(m.copyWith(maxPersonas: maximo.clamp(m.minPersonas, m.capacidad)));
    }
    notifyListeners();
  }

  void cambiarTipo(String id, String tipo) {
    final m = _buscar(id);
    if (m == null || !MesaModel.tiposValidos.contains(tipo) || m.tipo == tipo) return;
    _registrar('tipo:$id');
    _reemplazar(m.copyWith(tipo: tipo));
    notifyListeners();
  }

  void cambiarForma(String id, String forma) {
    final m = _buscar(id);
    if (m == null || !MesaModel.formasValidas.contains(forma)) return;
    _registrar('forma:$id');
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
    _registrar('tamano:$id', agrupar: true);
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

  static double _normalizarGrados(double g) => ((g % 360) + 360) % 360;

  /// Gira la mesa [delta] grados.
  void rotarMesa(String id, double delta) {
    final m = _buscar(id);
    if (m == null) return;
    _registrar('rotar:$id', agrupar: true);
    _reemplazar(m.copyWith(rotacion: _normalizarGrados(m.rotacion + delta)));
    notifyListeners();
  }

  /// Fija el giro de la mesa en [grados] (0 a 359).
  void fijarRotacionMesa(String id, double grados) {
    final m = _buscar(id);
    if (m == null) return;
    _registrar('rotar:$id', agrupar: true);
    _reemplazar(m.copyWith(rotacion: _normalizarGrados(grados)));
    notifyListeners();
  }

  void cambiarCombinable(String id, bool valor) {
    final m = _buscar(id);
    if (m == null) return;
    _registrar('combinable:$id');
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
    _registrar('combinacion');
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
    _registrar('espacio:$id');
    final destino = zonaId == sinEspacioId ? null : zonaId;
    final enDestino = [
      for (final o in _mesas)
        if (o.id != id && (destino == null ? _sinZona(o.zonaId) : o.zonaId == destino)) o,
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
      rotacion: m.rotacion,
      tipo: m.tipo,
      minPersonas: m.minPersonas,
      maxPersonas: m.maxPersonas,
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
    _registrar('duplicar-mesa');
    final lugar = _lugarLibre(m.cajaRotada.width, m.cajaRotada.height);
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
      rotacion: m.rotacion,
      tipo: m.tipo,
      minPersonas: m.minPersonas,
      maxPersonas: m.maxPersonas,
    );
    _mesas = [..._mesas, copia];
    _seleccionarSolo(mesaId: copia.id);
    notifyListeners();
    return copia;
  }

  void eliminarMesa(String id) {
    if (_buscar(id) == null) return;
    _registrar('eliminar-mesa');
    _mesas = [
      for (final m in _mesas)
        if (m.id != id)
          m.combinableCon.contains(id)
              ? m.copyWith(combinableCon: m.combinableCon.where((c) => c != id).toList())
              : m,
    ];
    if (_seleccionadaId == id) _seleccionadaId = null;
    _multi.remove(id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Elementos decorativos (borrador)
  // ---------------------------------------------------------------------------

  /// Agrega un elemento decorativo (barra, pared, puerta…) y lo selecciona.
  ElementoPlano agregarElemento(String tipo) {
    final t = ElementoPlano.tiposValidos.contains(tipo) ? tipo : ElementoPlano.texto;
    final estilo = ElementoPlano.estilo(t);
    _registrar('agregar-elemento');
    final lugar = _lugarLibre(estilo.ancho, estilo.alto);
    final e = ElementoPlano(
      id: _idTemporal(),
      tipo: t,
      x: lugar.x,
      y: lugar.y,
      ancho: estilo.ancho,
      alto: estilo.alto,
      etiqueta: ElementoPlano.textoInicial(t),
      zonaId: _zonaParaNuevo,
    );
    _elementos = [..._elementos, e];
    _seleccionarSolo(elementoId: e.id);
    notifyListeners();
    return e;
  }

  void arrastrarElemento(String id, double dx, double dy) {
    if (_modoMultiple && _multi.contains(id) && _multi.length > 1) {
      _moverGrupo(dx, dy);
      return;
    }
    final e = _buscarElemento(id);
    if (e == null) return;
    _registrar('arrastrar:$id', agrupar: true);
    final nx = (e.x + dx).clamp(0, anchoLienzo - e.ancho).toDouble();
    final ny = (e.y + dy).clamp(0, altoLienzo - e.alto).toDouble();
    _reemplazarElemento(e.copyWith(x: nx, y: ny));
    notifyListeners();
  }

  void soltarElemento(String id) {
    if (_modoMultiple && _multi.contains(id) && _multi.length > 1) {
      _soltarGrupo();
      return;
    }
    final e = _buscarElemento(id);
    if (e == null) return;
    final nx = TableLayoutValidator.alinear(e.x, paso: paso).clamp(0, anchoLienzo - e.ancho).toDouble();
    final ny = TableLayoutValidator.alinear(e.y, paso: paso).clamp(0, altoLienzo - e.alto).toDouble();
    if (nx != e.x || ny != e.y) {
      _registrar('mover-elemento', agrupar: true);
      _reemplazarElemento(e.copyWith(x: nx, y: ny));
      notifyListeners();
    }
    _ultimaClave = null;
  }

  void cambiarTextoElemento(String id, String texto) {
    final e = _buscarElemento(id);
    if (e == null) return;
    _registrar('texto:$id', agrupar: true);
    _reemplazarElemento(e.copyWith(etiqueta: texto));
    notifyListeners();
  }

  void cambiarTamanoElemento(String id, {double? ancho, double? alto}) {
    final e = _buscarElemento(id);
    if (e == null) return;
    _registrar('tamano:$id', agrupar: true);
    var a = (ancho ?? e.ancho).clamp(ElementoPlano.tamanoMinimo, ElementoPlano.tamanoMaximo).toDouble();
    var h = (alto ?? e.alto).clamp(ElementoPlano.tamanoMinimo, ElementoPlano.tamanoMaximo).toDouble();
    if (e.esCircular) {
      if (ancho != null) h = a;
      if (alto != null && ancho == null) a = h;
    }
    _reemplazarElemento(e.copyWith(ancho: a, alto: h));
    notifyListeners();
  }

  void rotarElemento(String id, double delta) {
    final e = _buscarElemento(id);
    if (e == null) return;
    _registrar('rotar:$id', agrupar: true);
    _reemplazarElemento(e.copyWith(rotacion: _normalizarGrados(e.rotacion + delta)));
    notifyListeners();
  }

  void fijarRotacionElemento(String id, double grados) {
    final e = _buscarElemento(id);
    if (e == null) return;
    _registrar('rotar:$id', agrupar: true);
    _reemplazarElemento(e.copyWith(rotacion: _normalizarGrados(grados)));
    notifyListeners();
  }

  ElementoPlano? duplicarElemento(String id) {
    final e = _buscarElemento(id);
    if (e == null) return null;
    _registrar('duplicar-elemento');
    final lugar = _lugarLibre(e.cajaRotada.width, e.cajaRotada.height);
    final copia = ElementoPlano(
      id: _idTemporal(),
      tipo: e.tipo,
      x: lugar.x,
      y: lugar.y,
      ancho: e.ancho,
      alto: e.alto,
      rotacion: e.rotacion,
      etiqueta: e.etiqueta,
      zonaId: e.zonaId,
    );
    _elementos = [..._elementos, copia];
    _seleccionarSolo(elementoId: copia.id);
    notifyListeners();
    return copia;
  }

  void eliminarElemento(String id) {
    if (_buscarElemento(id) == null) return;
    _registrar('eliminar-elemento');
    _elementos = [for (final e in _elementos) if (e.id != id) e];
    if (_elementoSeleccionadoId == id) _elementoSeleccionadoId = null;
    _multi.remove(id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Plantillas
  // ---------------------------------------------------------------------------

  /// El espacio activo ya tiene mesas o decoración.
  bool get espacioActivoConPiezas => mesasVisibles.isNotEmpty || elementosVisibles.isNotEmpty;

  /// Pone una plantilla en el espacio activo. Con [reemplazar] quita antes lo que hay
  /// en ese espacio; si no, la agrega junto a lo que ya está. Se puede deshacer.
  void aplicarPlantilla(PlantillaPlano plantilla, {required bool reemplazar}) {
    _registrar('plantilla');
    if (reemplazar) {
      final idsMesas = {for (final m in mesasVisibles) m.id};
      final idsElementos = {for (final e in elementosVisibles) e.id};
      _mesas = [
        for (final m in _mesas)
          if (!idsMesas.contains(m.id))
            m.copyWith(combinableCon: m.combinableCon.where((x) => !idsMesas.contains(x)).toList()),
      ];
      _elementos = [for (final e in _elementos) if (!idsElementos.contains(e.id)) e];
    }

    final zona = _zonaParaNuevo;
    final nuevos = <String>{};
    for (final pm in plantilla.mesas) {
      final preset = presetsMesa.firstWhere((p) => p.id == pm.preset);
      final mesa = MesaModel(
        id: _idTemporal(),
        nombre: _nombreNuevo(),
        capacidad: preset.capacidad,
        forma: preset.forma,
        ancho: preset.ancho,
        alto: preset.alto,
        tipo: preset.tipo,
        x: pm.x,
        y: pm.y,
        rotacion: pm.rotacion,
        zonaId: zona,
      );
      _mesas = [..._mesas, mesa];
      nuevos.add(mesa.id);
    }
    for (final pe in plantilla.elementos) {
      final medidas = PlantillaPlano.medidasDe(pe);
      final e = ElementoPlano(
        id: _idTemporal(),
        tipo: pe.tipo,
        x: pe.x,
        y: pe.y,
        ancho: medidas.ancho,
        alto: medidas.alto,
        rotacion: pe.rotacion,
        etiqueta: medidas.texto,
        zonaId: zona,
      );
      _elementos = [..._elementos, e];
      nuevos.add(e.id);
    }
    _seleccionadaId = null;
    _elementoSeleccionadoId = null;
    _multi
      ..clear()
      ..addAll(nuevos);
    _modoMultiple = true;
    _camposConError = {};
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Selección múltiple, alinear y distribuir
  // ---------------------------------------------------------------------------

  /// Activa o desactiva la selección de varias piezas a la vez.
  void alternarModoMultiple() {
    _modoMultiple = !_modoMultiple;
    _multi.clear();
    if (_modoMultiple) {
      // Lo que estaba seleccionado pasa a ser el primer elemento del grupo.
      if (_seleccionadaId != null) _multi.add(_seleccionadaId!);
      if (_elementoSeleccionadoId != null) _multi.add(_elementoSeleccionadoId!);
    }
    _seleccionadaId = null;
    _elementoSeleccionadoId = null;
    notifyListeners();
  }

  /// Agrega o quita una pieza (mesa o elemento) de la selección múltiple.
  void alternarEnSeleccion(String id) {
    if (!_modoMultiple) _modoMultiple = true;
    if (!_multi.add(id)) _multi.remove(id);
    notifyListeners();
  }

  /// Selecciona todas las piezas del espacio activo.
  void seleccionarTodo() {
    _modoMultiple = true;
    _seleccionadaId = null;
    _elementoSeleccionadoId = null;
    _multi
      ..clear()
      ..addAll(mesasVisibles.map((m) => m.id))
      ..addAll(elementosVisibles.map((e) => e.id));
    notifyListeners();
  }

  void limpiarSeleccion() {
    _seleccionadaId = null;
    _elementoSeleccionadoId = null;
    _multi.clear();
    notifyListeners();
  }

  /// Ids de las piezas seleccionadas (una o varias).
  Set<String> get idsSeleccionados {
    if (_modoMultiple) return Set.unmodifiable(_multi);
    return {
      if (_seleccionadaId != null) _seleccionadaId!,
      if (_elementoSeleccionadoId != null) _elementoSeleccionadoId!,
    };
  }

  bool estaSeleccionada(String id) => idsSeleccionados.contains(id);

  int get cantidadSeleccionada => idsSeleccionados.length;

  /// Rectángulo (con giro) de una pieza, o null si no existe.
  Rect? _caja(String id) {
    final m = _buscar(id);
    if (m != null) return m.cajaRotada;
    return _buscarElemento(id)?.cajaRotada;
  }

  void _desplazar(String id, double dx, double dy) {
    final m = _buscar(id);
    if (m != null) {
      _reemplazar(m.copyWith(x: (m.x ?? 0) + dx, y: (m.y ?? 0) + dy));
      return;
    }
    final e = _buscarElemento(id);
    if (e != null) _reemplazarElemento(e.copyWith(x: e.x + dx, y: e.y + dy));
  }

  void _moverGrupo(double dx, double dy) {
    final cajas = [for (final id in _multi) ?_caja(id)];
    if (cajas.isEmpty) return;
    var minX = cajas.first.left, minY = cajas.first.top;
    var maxX = cajas.first.right, maxY = cajas.first.bottom;
    for (final c in cajas) {
      if (c.left < minX) minX = c.left;
      if (c.top < minY) minY = c.top;
      if (c.right > maxX) maxX = c.right;
      if (c.bottom > maxY) maxY = c.bottom;
    }
    final ddx = dx.clamp(-minX, anchoLienzo - maxX).toDouble();
    final ddy = dy.clamp(-minY, altoLienzo - maxY).toDouble();
    _registrar('arrastrar-grupo', agrupar: true);
    for (final id in _multi) {
      _desplazar(id, ddx, ddy);
    }
    notifyListeners();
  }

  void _soltarGrupo() {
    final cajas = [for (final id in _multi) ?_caja(id)];
    if (cajas.isEmpty) return;
    final izq = cajas.map((c) => c.left).reduce((a, b) => a < b ? a : b);
    final arriba = cajas.map((c) => c.top).reduce((a, b) => a < b ? a : b);
    final dx = TableLayoutValidator.alinear(izq, paso: paso) - izq;
    final dy = TableLayoutValidator.alinear(arriba, paso: paso) - arriba;
    if (dx != 0 || dy != 0) {
      for (final id in _multi) {
        _desplazar(id, dx, dy);
      }
      notifyListeners();
    }
    _ultimaClave = null;
  }

  /// Alinea las piezas seleccionadas (hacen falta al menos dos).
  void alinear(Alineacion a) {
    final ids = idsSeleccionados.toList();
    if (ids.length < 2) return;
    final cajas = {for (final id in ids) id: _caja(id)};
    cajas.removeWhere((_, c) => c == null);
    if (cajas.length < 2) return;
    final izq = cajas.values.map((c) => c!.left).reduce((a, b) => a < b ? a : b);
    final der = cajas.values.map((c) => c!.right).reduce((a, b) => a > b ? a : b);
    final arriba = cajas.values.map((c) => c!.top).reduce((a, b) => a < b ? a : b);
    final abajo = cajas.values.map((c) => c!.bottom).reduce((a, b) => a > b ? a : b);
    _registrar('alinear');
    cajas.forEach((id, c) {
      final caja = c!;
      switch (a) {
        case Alineacion.izquierda:
          _desplazar(id, izq - caja.left, 0);
        case Alineacion.derecha:
          _desplazar(id, der - caja.right, 0);
        case Alineacion.centroHorizontal:
          _desplazar(id, (izq + der) / 2 - caja.center.dx, 0);
        case Alineacion.arriba:
          _desplazar(id, 0, arriba - caja.top);
        case Alineacion.abajo:
          _desplazar(id, 0, abajo - caja.bottom);
        case Alineacion.centroVertical:
          _desplazar(id, 0, (arriba + abajo) / 2 - caja.center.dy);
      }
    });
    notifyListeners();
  }

  /// Reparte las piezas seleccionadas con la misma separación (hacen falta tres).
  void distribuir({required bool horizontal}) {
    final ids = idsSeleccionados.toList();
    final piezas = <({String id, Rect caja})>[
      for (final id in ids)
        if (_caja(id) case final c?) (id: id, caja: c),
    ];
    if (piezas.length < 3) return;
    piezas.sort((a, b) => horizontal
        ? a.caja.center.dx.compareTo(b.caja.center.dx)
        : a.caja.center.dy.compareTo(b.caja.center.dy));
    final primero = horizontal ? piezas.first.caja.center.dx : piezas.first.caja.center.dy;
    final ultimo = horizontal ? piezas.last.caja.center.dx : piezas.last.caja.center.dy;
    final salto = (ultimo - primero) / (piezas.length - 1);
    _registrar('distribuir');
    for (var i = 1; i < piezas.length - 1; i++) {
      final objetivo = primero + salto * i;
      final actual = horizontal ? piezas[i].caja.center.dx : piezas[i].caja.center.dy;
      _desplazar(piezas[i].id, horizontal ? objetivo - actual : 0, horizontal ? 0 : objetivo - actual);
    }
    notifyListeners();
  }

  /// Gira todas las piezas seleccionadas [delta] grados.
  void girarSeleccion(double delta) {
    final ids = idsSeleccionados;
    if (ids.isEmpty) return;
    _registrar('girar-seleccion');
    for (final id in ids) {
      final m = _buscar(id);
      if (m != null) {
        _reemplazar(m.copyWith(rotacion: _normalizarGrados(m.rotacion + delta)));
        continue;
      }
      final e = _buscarElemento(id);
      if (e != null) _reemplazarElemento(e.copyWith(rotacion: _normalizarGrados(e.rotacion + delta)));
    }
    notifyListeners();
  }

  /// Mueve la selección un paso de la cuadrícula (flechas del teclado).
  void empujarSeleccion(double dx, double dy) {
    final ids = idsSeleccionados;
    if (ids.isEmpty) return;
    final cajas = [for (final id in ids) ?_caja(id)];
    if (cajas.isEmpty) return;
    final minX = cajas.map((c) => c.left).reduce((a, b) => a < b ? a : b);
    final minY = cajas.map((c) => c.top).reduce((a, b) => a < b ? a : b);
    final maxX = cajas.map((c) => c.right).reduce((a, b) => a > b ? a : b);
    final maxY = cajas.map((c) => c.bottom).reduce((a, b) => a > b ? a : b);
    final ddx = dx.clamp(-minX, anchoLienzo - maxX).toDouble();
    final ddy = dy.clamp(-minY, altoLienzo - maxY).toDouble();
    if (ddx == 0 && ddy == 0) return;
    _registrar('empujar', agrupar: true);
    for (final id in ids) {
      _desplazar(id, ddx, ddy);
    }
    notifyListeners();
  }

  /// Duplica todas las piezas seleccionadas.
  void duplicarSeleccion() {
    final ids = idsSeleccionados.toList();
    if (ids.isEmpty) return;
    if (ids.length == 1) {
      if (_buscar(ids.first) != null) {
        duplicarMesa(ids.first);
      } else {
        duplicarElemento(ids.first);
      }
      return;
    }
    _registrar('duplicar-seleccion');
    final nuevos = <String>{};
    for (final id in ids) {
      final m = _buscar(id);
      if (m != null) {
        final lugar = _lugarLibre(m.cajaRotada.width, m.cajaRotada.height);
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
          rotacion: m.rotacion,
          tipo: m.tipo,
          minPersonas: m.minPersonas,
          maxPersonas: m.maxPersonas,
        );
        _mesas = [..._mesas, copia];
        nuevos.add(copia.id);
        continue;
      }
      final e = _buscarElemento(id);
      if (e != null) {
        final lugar = _lugarLibre(e.cajaRotada.width, e.cajaRotada.height);
        final copia = e.copyWith(id: _idTemporal(), x: lugar.x, y: lugar.y);
        _elementos = [..._elementos, copia];
        nuevos.add(copia.id);
      }
    }
    _multi
      ..clear()
      ..addAll(nuevos);
    notifyListeners();
  }

  /// Elimina todas las piezas seleccionadas.
  void eliminarSeleccion() {
    final ids = idsSeleccionados.toList();
    if (ids.isEmpty) return;
    _registrar('eliminar-seleccion');
    final idsMesas = {for (final id in ids) if (_buscar(id) != null) id};
    _mesas = [
      for (final m in _mesas)
        if (!idsMesas.contains(m.id))
          m.copyWith(combinableCon: m.combinableCon.where((c) => !idsMesas.contains(c)).toList()),
    ];
    _elementos = [for (final e in _elementos) if (!ids.contains(e.id)) e];
    _seleccionadaId = null;
    _elementoSeleccionadoId = null;
    _multi.clear();
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
      _seleccionarSolo(mesaId: primera.id);
      _modoMultiple = false;
      if (_zonaActivaId != null &&
          _zonas.isNotEmpty &&
          !_perteneceA(primera.zonaId, _zonaActivaId)) {
        _zonaActivaId = _sinZona(primera.zonaId) ? sinEspacioId : primera.zonaId;
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
        elementos: _elementos,
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
