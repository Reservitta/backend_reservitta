import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/inventario_models.dart';
import '../models/pedido_model.dart';
import '../models/reservation_model.dart';

/// Datos de un movimiento manual no válidos (cantidad, saldo insuficiente…).
class InventarioException implements Exception {
  final String message;
  const InventarioException(this.message);
  @override
  String toString() => message;
}

/// Avisos del inventario para mostrar al administrador desde cualquier pantalla
/// (por ejemplo, "faltaron insumos" al pasar un pedido a preparando).
class InventarioAvisos extends ChangeNotifier {
  static final InventarioAvisos instancia = InventarioAvisos._();
  InventarioAvisos._();

  String? _ultimo;

  /// Lleva el aviso pendiente de mostrar y lo limpia.
  String? tomar() {
    final a = _ultimo;
    _ultimo = null;
    return a;
  }

  void publicar(String mensaje) {
    _ultimo = mensaje;
    notifyListeners();
  }
}

/// Inventario del restaurante.
///
/// - El catálogo de insumos es del restaurante (`restaurants/{id}/insumos`).
/// - Las existencias y los movimientos son de cada sucursal
///   (`sucursales/{sid}/existencias` y `sucursales/{sid}/movimientos`).
/// - Cada platillo puede tener una receta; al pasar un pedido a "preparando" se
///   descuentan sus insumos de la sucursal del pedido, una sola vez.
class InventarioService {
  final FirebaseFirestore? _firestoreInstance;

  InventarioService({FirebaseFirestore? firestore}) : _firestoreInstance = firestore;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  /// Sucursal que se usa cuando el restaurante no tiene ninguna registrada.
  static const String sucursalPorDefecto = 'principal';

  DocumentReference<Map<String, dynamic>> _restaurante(String rid) =>
      _db.collection('restaurants').doc(rid);

  CollectionReference<Map<String, dynamic>> _insumos(String rid) =>
      _restaurante(rid).collection('insumos');

  DocumentReference<Map<String, dynamic>> _sucursal(String rid, String sid) =>
      _restaurante(rid).collection('sucursales').doc(sid);

  CollectionReference<Map<String, dynamic>> _existencias(String rid, String sid) =>
      _sucursal(rid, sid).collection('existencias');

  CollectionReference<Map<String, dynamic>> _movimientos(String rid, String sid) =>
      _sucursal(rid, sid).collection('movimientos');

  // ---------------------------------------------------------------------------
  // Lecturas
  // ---------------------------------------------------------------------------

  Stream<List<InsumoModel>> insumosStream(String rid) {
    return _insumos(rid).snapshots().map((q) {
      final lista = q.docs.map((d) => InsumoModel.fromMap(d.id, d.data())).toList();
      lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return lista;
    });
  }

  /// Existencias de la sucursal por insumo (los insumos sin registro cuentan como 0).
  Stream<Map<String, ExistenciaModel>> existenciasStream(String rid, String sid) {
    return _existencias(rid, sid).snapshots().map((q) => {
          for (final d in q.docs) d.id: ExistenciaModel.fromMap(d.id, d.data()),
        });
  }

  Stream<List<MovimientoInventario>> movimientosStream(String rid, String sid, {int limite = 60}) {
    return _movimientos(rid, sid).orderBy('en', descending: true).limit(limite).snapshots().map(
          (q) => q.docs.map((d) => MovimientoInventario.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Ids de las sucursales del restaurante (o la sucursal por defecto si no hay).
  Future<List<String>> sucursalIds(String rid) async {
    try {
      final snap = await _restaurante(rid).collection('sucursales').get();
      if (snap.docs.isNotEmpty) return snap.docs.map((d) => d.id).toList();
    } catch (_) {}
    return const [sucursalPorDefecto];
  }

  Future<String> _sucursalPrincipal(String rid) async {
    try {
      final snap = await _restaurante(rid).collection('sucursales').get();
      if (snap.docs.isEmpty) return sucursalPorDefecto;
      for (final d in snap.docs) {
        if (d.data()['esPrincipal'] == true) return d.id;
      }
      return snap.docs.first.id;
    } catch (_) {
      return sucursalPorDefecto;
    }
  }

  // ---------------------------------------------------------------------------
  // Catálogo de insumos
  // ---------------------------------------------------------------------------

  static String _normalizar(String t) => t.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Valida nombre y unidad; devuelve el primer problema o null.
  static String? validarInsumo({required String nombre, required String unidad}) {
    if (nombre.trim().length < 2) return 'Escribe el nombre del insumo.';
    if (nombre.trim().length > 60) return 'El nombre es demasiado largo (máximo 60 caracteres).';
    if (!UnidadInsumo.todas.contains(unidad)) return 'Elige una unidad de medida.';
    return null;
  }

  Future<String> crearInsumo(
    String rid, {
    required String nombre,
    required String unidad,
  }) async {
    final problema = validarInsumo(nombre: nombre, unidad: unidad);
    if (problema != null) throw InventarioException(problema);
    final existentes = await _insumos(rid).get();
    final nuevo = _normalizar(nombre);
    if (existentes.docs.any((d) => _normalizar((d.data()['nombre'] as String?) ?? '') == nuevo)) {
      throw const InventarioException('Ya existe un insumo con ese nombre.');
    }
    final ref = await _insumos(rid).add(InsumoModel(id: '', nombre: nombre, unidad: unidad).toMap());
    return ref.id;
  }

  Future<void> actualizarInsumo(
    String rid,
    String insumoId, {
    required String nombre,
    required String unidad,
  }) async {
    final problema = validarInsumo(nombre: nombre, unidad: unidad);
    if (problema != null) throw InventarioException(problema);
    final existentes = await _insumos(rid).get();
    final nuevo = _normalizar(nombre);
    final repetido = existentes.docs.any(
      (d) => d.id != insumoId && _normalizar((d.data()['nombre'] as String?) ?? '') == nuevo,
    );
    if (repetido) throw const InventarioException('Ya existe un insumo con ese nombre.');
    await _insumos(rid).doc(insumoId).update({'nombre': nombre.trim(), 'unidad': unidad});
  }

  /// Mínimo de la sucursal: por debajo (o igual) se avisa de stock bajo.
  Future<void> definirMinimo(String rid, String sid, String insumoId, double minimo) async {
    if (minimo < 0) throw const InventarioException('El mínimo no puede ser negativo.');
    await _existencias(rid, sid).doc(insumoId).set(
      {'minimo': redondearCantidad(minimo)},
      SetOptions(merge: true),
    );
    await _recalcularSeguro(rid);
  }

  // ---------------------------------------------------------------------------
  // Entradas y salidas manuales
  // ---------------------------------------------------------------------------

  Future<void> registrarEntrada(
    String rid,
    String sid,
    InsumoModel insumo, {
    required double cantidad,
    String motivo = '',
    String por = '',
  }) =>
      _movimientoManual(rid, sid, insumo,
          tipo: MovimientoInventario.entrada, cantidad: cantidad, motivo: motivo, por: por);

  Future<void> registrarSalida(
    String rid,
    String sid,
    InsumoModel insumo, {
    required double cantidad,
    String motivo = '',
    String por = '',
  }) =>
      _movimientoManual(rid, sid, insumo,
          tipo: MovimientoInventario.salida, cantidad: cantidad, motivo: motivo, por: por);

  Future<void> _movimientoManual(
    String rid,
    String sid,
    InsumoModel insumo, {
    required String tipo,
    required double cantidad,
    required String motivo,
    required String por,
  }) async {
    final c = redondearCantidad(cantidad);
    if (c <= 0) throw const InventarioException('La cantidad debe ser mayor a cero.');
    if (c > 1000000) throw const InventarioException('La cantidad es demasiado grande.');

    final exRef = _existencias(rid, sid).doc(insumo.id);
    final movRef = _movimientos(rid, sid).doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(exRef);
      final actual = ExistenciaModel.fromMap(insumo.id, snap.data());
      final nueva = tipo == MovimientoInventario.entrada
          ? redondearCantidad(actual.cantidad + c)
          : redondearCantidad(actual.cantidad - c);
      if (nueva < 0) {
        throw InventarioException(
          'No hay suficiente ${insumo.nombre}: quedan ${formatoCantidad(actual.cantidad)} ${insumo.unidad}.',
        );
      }
      _escribirCantidad(tx, exRef, snap, nueva);
      tx.set(
        movRef,
        MovimientoInventario(
          insumoId: insumo.id,
          insumoNombre: insumo.nombre,
          unidad: insumo.unidad,
          tipo: tipo,
          cantidad: c,
          motivo: motivo.trim(),
          por: por,
        ).toMap(),
      );
    });
    await _recalcularSeguro(rid);
  }

  /// Crea el insumo y, si se indica, deja su mínimo y su existencia inicial (como entrada).
  Future<String> crearInsumoConExistencia(
    String rid,
    String sid, {
    required String nombre,
    required String unidad,
    double minimo = 0,
    double existenciaInicial = 0,
    String por = '',
  }) async {
    final id = await crearInsumo(rid, nombre: nombre, unidad: unidad);
    if (minimo > 0) await definirMinimo(rid, sid, id, minimo);
    if (existenciaInicial > 0) {
      await registrarEntrada(
        rid,
        sid,
        InsumoModel(id: id, nombre: nombre.trim(), unidad: unidad),
        cantidad: existenciaInicial,
        motivo: 'Existencia inicial',
        por: por,
      );
    }
    return id;
  }

  /// Guarda la cantidad sin tocar el mínimo: actualiza si el registro existe y lo crea si no.
  void _escribirCantidad(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    DocumentSnapshot<Map<String, dynamic>> actual,
    double cantidad,
  ) {
    if (actual.exists) {
      tx.update(ref, {'cantidad': cantidad});
    } else {
      tx.set(ref, {'cantidad': cantidad, 'minimo': 0});
    }
  }

  // ---------------------------------------------------------------------------
  // Descuento al preparar
  // ---------------------------------------------------------------------------

  /// Estados de la preorden a partir de los cuales ya se consumieron los insumos.
  static bool preordenYaEnCocina(String estado) =>
      estado == ReservationModel.preordenEnPreparacion ||
      estado == ReservationModel.preordenListo ||
      estado == ReservationModel.preordenEntregado;

  /// Estados del pedido en línea a partir de los cuales ya se consumieron los insumos.
  static bool pedidoYaEnCocina(String estado) =>
      estado == PedidoModel.estadoPreparando ||
      estado == PedidoModel.estadoListo ||
      estado == PedidoModel.estadoEnCamino ||
      estado == PedidoModel.estadoEntregado;

  Future<DescuentoResultado> descontarPorPedido(String rid, String pedidoId, {String por = ''}) {
    return _descontar(
      rid,
      _db.collection('pedidos').doc(pedidoId),
      origen: MovimientoInventario.origenPedido,
      por: por,
      itemsDe: (data) => [
        for (final i in (data['items'] as List?) ?? const [])
          if (i is Map) (i['platilloId'] as String? ?? '', (i['cantidad'] as num?)?.toInt() ?? 0),
      ],
    );
  }

  Future<DescuentoResultado> descontarPorPreorden(String rid, String reservaId, {String por = ''}) {
    return _descontar(
      rid,
      _db.collection('reservations').doc(reservaId),
      origen: MovimientoInventario.origenPreorden,
      por: por,
      itemsDe: (data) {
        final preorden = data['preorden'];
        final lista = (preorden is Map ? preorden['items'] : null) ?? data['preordenItems'];
        return [
          for (final i in (lista as List?) ?? const [])
            if (i is Map) (i['platilloId'] as String? ?? '', (i['cantidad'] as num?)?.toInt() ?? 0),
        ];
      },
    );
  }

  /// Llamar después de cambiar el estado de un pedido en línea. Descuenta (una sola
  /// vez) cuando ya está en cocina y avisa si faltaron insumos.
  Future<void> alCambiarEstadoPedido(String rid, String pedidoId, String estado, {String por = ''}) async {
    if (!pedidoYaEnCocina(estado)) return;
    await _descontarYAvisar(() => descontarPorPedido(rid, pedidoId, por: por));
  }

  /// Igual que [alCambiarEstadoPedido] para la preorden de una reserva.
  Future<void> alCambiarEstadoPreorden(String rid, String reservaId, String estado, {String por = ''}) async {
    if (!preordenYaEnCocina(estado)) return;
    await _descontarYAvisar(() => descontarPorPreorden(rid, reservaId, por: por));
  }

  Future<void> _descontarYAvisar(Future<DescuentoResultado> Function() accion) async {
    try {
      final r = await accion();
      final aviso = r.aviso;
      if (aviso != null) InventarioAvisos.instancia.publicar(aviso);
    } catch (_) {
      InventarioAvisos.instancia.publicar(
        'No se pudo descontar el inventario de este pedido. Revisa tu conexión.',
      );
    }
  }

  Future<DescuentoResultado> _descontar(
    String rid,
    DocumentReference<Map<String, dynamic>> ref, {
    required String origen,
    required String por,
    required List<(String, int)> Function(Map<String, dynamic> data) itemsDe,
  }) async {
    final principal = await _sucursalPrincipal(rid);
    final faltantes = <FaltanteInsumo>[];
    var aplicado = false;
    var yaDescontado = false;

    await _db.runTransaction((tx) async {
      faltantes.clear();
      aplicado = false;
      yaDescontado = false;

      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      if (data['inventarioDescontado'] == true) {
        yaDescontado = true;
        return;
      }
      final sid = (data['sucursalId'] as String?)?.isNotEmpty == true
          ? data['sucursalId'] as String
          : principal;

      // Lo que necesita el pedido de cada insumo, según las recetas.
      final porPlatillo = <String, int>{};
      for (final (platilloId, cantidad) in itemsDe(data)) {
        if (platilloId.isEmpty || cantidad <= 0) continue;
        porPlatillo[platilloId] = (porPlatillo[platilloId] ?? 0) + cantidad;
      }
      final requerido = <String, double>{};
      final infoInsumo = <String, RecetaItem>{};
      for (final entry in porPlatillo.entries) {
        final platillo = await tx.get(_restaurante(rid).collection('platillos').doc(entry.key));
        for (final r in (platillo.data()?['receta'] as List?) ?? const []) {
          if (r is! Map) continue;
          final item = RecetaItem.fromMap(Map<String, dynamic>.from(r));
          if (item.insumoId.isEmpty || item.cantidad <= 0) continue;
          requerido[item.insumoId] =
              redondearCantidad((requerido[item.insumoId] ?? 0) + item.cantidad * entry.value);
          infoInsumo[item.insumoId] = item;
        }
      }

      if (requerido.isEmpty) {
        // Nada que descontar: se marca para no volver a revisarlo.
        tx.update(ref, {'inventarioDescontado': true, 'inventarioSucursalId': sid});
        return;
      }

      final existencias = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in requerido.keys) {
        existencias[id] = await tx.get(_existencias(rid, sid).doc(id));
      }

      for (final id in requerido.keys) {
        final info = infoInsumo[id]!;
        final necesito = requerido[id]!;
        final hay = ExistenciaModel.fromMap(id, existencias[id]!.data()).cantidad;
        final disponible = hay < 0 ? 0.0 : hay;
        final descontado = necesito < disponible ? necesito : disponible;
        final falto = redondearCantidad(necesito - descontado);
        _escribirCantidad(
          tx,
          _existencias(rid, sid).doc(id),
          existencias[id]!,
          redondearCantidad(disponible - descontado),
        );
        tx.set(
          _movimientos(rid, sid).doc(),
          MovimientoInventario(
            insumoId: id,
            insumoNombre: info.nombre,
            unidad: info.unidad,
            tipo: MovimientoInventario.salida,
            cantidad: descontado,
            motivo: origen == MovimientoInventario.origenPedido
                ? 'Pedido en línea'
                : 'Preorden de reserva',
            origen: origen,
            refId: ref.id,
            faltante: falto,
            por: por,
          ).toMap(),
        );
        if (falto > 0) {
          faltantes.add(FaltanteInsumo(
            insumoId: id,
            nombre: info.nombre,
            unidad: info.unidad,
            requerido: necesito,
            disponible: disponible,
          ));
        }
      }
      tx.update(ref, {'inventarioDescontado': true, 'inventarioSucursalId': sid});
      aplicado = true;
    });

    if (aplicado) await _recalcularSeguro(rid);
    return DescuentoResultado(aplicado: aplicado, yaDescontado: yaDescontado, faltantes: List.of(faltantes));
  }

  // ---------------------------------------------------------------------------
  // Disponibilidad de los platillos
  // ---------------------------------------------------------------------------

  Future<void> _recalcularSeguro(String rid) async {
    try {
      await recalcularDisponibilidad(rid);
    } catch (_) {
      // El movimiento ya quedó guardado; la disponibilidad se corrige en el siguiente.
    }
  }

  /// Revisa los platillos con receta y marca como agotados los que no se pueden preparar.
  ///
  /// - Por sucursal: `agotadoSucursales` lista dónde faltan insumos.
  /// - Si faltan en todas las sucursales, el platillo pasa a `agotado` (y vuelve a
  ///   `activo` solo cuando lo marcó el sistema, nunca si el administrador lo apagó a mano).
  ///
  /// Devuelve cuántos platillos cambiaron.
  Future<int> recalcularDisponibilidad(String rid) async {
    final sids = await sucursalIds(rid);
    final stock = <String, Map<String, double>>{};
    for (final sid in sids) {
      final snap = await _existencias(rid, sid).get();
      stock[sid] = {
        for (final d in snap.docs) d.id: ExistenciaModel.fromMap(d.id, d.data()).cantidad,
      };
    }

    final platillos = await _restaurante(rid).collection('platillos').get();
    var cambios = 0;
    final batch = _db.batch();
    for (final doc in platillos.docs) {
      final data = doc.data();
      final receta = [
        for (final r in (data['receta'] as List?) ?? const [])
          if (r is Map) RecetaItem.fromMap(Map<String, dynamic>.from(r)),
      ].where((r) => r.insumoId.isNotEmpty && r.cantidad > 0).toList();

      final estado = (data['estado'] as String?) ?? 'activo';
      final auto = data['agotadoAuto'] == true;
      final previas = List<String>.from(data['agotadoSucursales'] as List? ?? const []);

      final faltan = <String>[];
      if (receta.isNotEmpty) {
        for (final sid in sids) {
          final hay = stock[sid] ?? const {};
          if (receta.any((r) => (hay[r.insumoId] ?? 0) < r.cantidad)) faltan.add(sid);
        }
      }
      final enTodas = faltan.isNotEmpty && faltan.length == sids.length;

      final cambio = <String, dynamic>{};
      if (!_mismos(previas, faltan)) cambio['agotadoSucursales'] = faltan;
      if (enTodas && estado == 'activo') {
        cambio['estado'] = 'agotado';
        cambio['agotadoAuto'] = true;
      } else if (!enTodas && auto) {
        if (estado == 'agotado') cambio['estado'] = 'activo';
        cambio['agotadoAuto'] = false;
      }
      if (cambio.isNotEmpty) {
        batch.update(doc.reference, cambio);
        cambios++;
      }
    }
    if (cambios > 0) await batch.commit();
    return cambios;
  }

  static bool _mismos(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }
}
