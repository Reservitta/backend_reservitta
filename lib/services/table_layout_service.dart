import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/elemento_plano.dart';
import '../models/mesa_model.dart';
import '../models/reservation_model.dart';
import '../models/table_layout_validator.dart';
import '../models/zona_model.dart';

/// Resultado de guardar el plano.
class PlanSaveResult {
  /// Mesas guardadas, ya con su id (las nuevas lo reciben al guardarse).
  final List<MesaModel> mesas;
  final List<ElementoPlano> elementos;
  final int creadas;
  final int actualizadas;
  final int eliminadas;

  const PlanSaveResult({
    required this.mesas,
    this.elementos = const [],
    required this.creadas,
    required this.actualizadas,
    required this.eliminadas,
  });
}

/// Una entrada del historial de cambios del plano.
class PlanCambio {
  final DateTime fecha;
  final String resumen;

  const PlanCambio({required this.fecha, required this.resumen});
}

/// Crea y edita los espacios y las mesas del restaurante (HU34-RF01, HU34-RF02).
///
/// Todo se guarda en `restaurants/{id}/zonas` y `restaurants/{id}/mesas`.
class TableLayoutService {
  final FirebaseFirestore? _firestoreInstance;
  final DateTime Function() _now;

  TableLayoutService({FirebaseFirestore? firestore, DateTime Function()? now})
      : _firestoreInstance = firestore,
        _now = now ?? DateTime.now;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _zonas(String rid) =>
      _db.collection('restaurants').doc(rid).collection('zonas');

  CollectionReference<Map<String, dynamic>> _mesas(String rid) =>
      _db.collection('restaurants').doc(rid).collection('mesas');

  CollectionReference<Map<String, dynamic>> _elementos(String rid) =>
      _db.collection('restaurants').doc(rid).collection('elementos');

  CollectionReference<Map<String, dynamic>> _historial(String rid) =>
      _db.collection('restaurants').doc(rid).collection('planHistorial');

  // ---------------------------------------------------------------------------
  // Espacios (HU34-RF01)
  // ---------------------------------------------------------------------------

  Stream<List<ZonaModel>> zonasStream(String rid) {
    return _zonas(rid).snapshots().map((s) {
      final lista = s.docs.map(ZonaModel.fromFirestore).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      return lista;
    });
  }

  Future<List<ZonaModel>> getZonas(String rid) async {
    final snap = await _zonas(rid).get();
    return snap.docs.map(ZonaModel.fromFirestore).toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
  }

  Future<List<MesaModel>> getMesas(String rid) async {
    final snap = await _mesas(rid).get();
    return snap.docs.map(MesaModel.fromFirestore).toList();
  }

  Future<List<ElementoPlano>> getElementos(String rid) async {
    final snap = await _elementos(rid).get();
    return snap.docs.map(ElementoPlano.fromFirestore).toList();
  }

  /// Últimos cambios guardados del plano, del más reciente al más antiguo.
  Future<List<PlanCambio>> getHistorial(String rid, {int limite = 20}) async {
    final snap = await _historial(rid).get();
    final lista = <PlanCambio>[
      for (final d in snap.docs)
        PlanCambio(
          fecha: (d.data()['fecha'] is Timestamp)
              ? (d.data()['fecha'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(0),
          resumen: (d.data()['resumen'] as String?) ?? '',
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista.take(limite).toList();
  }

  /// Crea un espacio al final de la lista. Lanza [LayoutException] si el nombre no es válido.
  Future<ZonaModel> crearZona(String rid, String nombre) async {
    final existentes = await getZonas(rid);
    final error = TableLayoutValidator.validarNombreZona(nombre, existentes);
    if (error != null) throw LayoutException(error, campos: {'nombre': error});
    final orden = existentes.isEmpty
        ? 1
        : existentes.map((z) => z.orden).reduce((a, b) => a > b ? a : b) + 1;
    final ref = _zonas(rid).doc();
    final zona = ZonaModel(id: ref.id, nombre: nombre.trim(), orden: orden);
    await ref.set(zona.toMap());
    return zona;
  }

  Future<void> renombrarZona(String rid, String zonaId, String nombre) async {
    final existentes = await getZonas(rid);
    final error = TableLayoutValidator.validarNombreZona(
      nombre,
      existentes,
      ignorarId: zonaId,
    );
    if (error != null) throw LayoutException(error, campos: {'nombre': error});
    await _zonas(rid).doc(zonaId).update({'nombre': nombre.trim()});
  }

  /// Reordena los espacios según [idsEnOrden].
  Future<void> reordenarZonas(String rid, List<String> idsEnOrden) async {
    final batch = _db.batch();
    for (var i = 0; i < idsEnOrden.length; i++) {
      batch.update(_zonas(rid).doc(idsEnOrden[i]), {'orden': i + 1});
    }
    await batch.commit();
  }

  /// Elimina un espacio vacío. Si tiene mesas lanza [LayoutException] con cuántas son.
  Future<void> eliminarZona(String rid, String zonaId) async {
    final mesas = (await getMesas(rid)).where((m) => m.zonaId == zonaId).toList();
    if (mesas.isNotEmpty) {
      final n = mesas.length;
      throw LayoutException(
        'Este espacio todavía tiene $n ${n == 1 ? 'mesa' : 'mesas'}. '
        'Muévelas a otro espacio o elimínalas antes de borrarlo.',
      );
    }
    await _zonas(rid).doc(zonaId).delete();
  }

  // ---------------------------------------------------------------------------
  // Mesas (HU34-RF02)
  // ---------------------------------------------------------------------------

  /// Reservas activas a futuro que usan la mesa [mesaId].
  Future<List<ReservationModel>> reservasActivasDeMesa(String rid, String mesaId) async {
    final snap = await _db
        .collection('reservations')
        .where('restauranteId', isEqualTo: rid)
        .get();
    final ahora = _now();
    return [
      for (final d in snap.docs)
        if (ReservationModel.fromFirestore(d) case final r
            when r.bloqueaMesas &&
                r.mesaIds.contains(mesaId) &&
                (r.fin ?? r.effectiveStart.add(Duration(minutes: r.duracionMin)))
                    .isAfter(ahora))
          r,
    ];
  }

  /// Prefijo de los ids provisionales de las mesas nuevas que aún no se guardan.
  static const String prefijoTemporal = 'tmp_';

  /// Guarda el plano completo: crea las mesas nuevas (id vacío o provisional con
  /// [prefijoTemporal]), actualiza las que cambiaron y elimina las que ya no están en
  /// [mesas]. Es todo o nada.
  ///
  /// Lanza [LayoutException] si alguna mesa no es válida, o si se intenta borrar o reducir
  /// la capacidad de una mesa con reservas activas a futuro.
  Future<PlanSaveResult> guardarPlano({
    required String restauranteId,
    required List<MesaModel> mesas,

    /// Elementos decorativos del plano. Si es null no se tocan los guardados.
    List<ElementoPlano>? elementos,
  }) async {
    final zonas = await getZonas(restauranteId);
    final zonaIds = {for (final z in zonas) z.id};
    final actuales = await getMesas(restauranteId);
    final porIdActual = {for (final m in actuales) m.id: m};

    // Las nuevas reciben su id antes de validar para poder relacionarlas entre sí.
    final refs = <String, DocumentReference<Map<String, dynamic>>>{};
    final nuevosPorProvisional = <String, String>{};
    final conId = <MesaModel>[];
    for (final m in mesas) {
      if (m.id.isEmpty || m.id.startsWith(prefijoTemporal)) {
        final ref = _mesas(restauranteId).doc();
        refs[ref.id] = ref;
        if (m.id.isNotEmpty) nuevosPorProvisional[m.id] = ref.id;
        conId.add(m.copyWith(id: ref.id));
      } else {
        conId.add(m);
      }
    }
    // Las combinaciones que apuntaban a mesas provisionales pasan a los ids definitivos.
    if (nuevosPorProvisional.isNotEmpty) {
      for (var i = 0; i < conId.length; i++) {
        final m = conId[i];
        if (m.combinableCon.any(nuevosPorProvisional.containsKey)) {
          conId[i] = m.copyWith(
            combinableCon: [for (final c in m.combinableCon) nuevosPorProvisional[c] ?? c],
          );
        }
      }
    }

    final errores = <String>[];
    final camposPrimero = <String, String>{};
    for (final m in conId) {
      final e = TableLayoutValidator.validarMesa(
        m,
        otras: conId,
        zonaIds: zonaIds,
      );
      if (e.isNotEmpty) {
        final nombre = m.nombre.trim().isEmpty ? 'Una mesa' : m.nombre.trim();
        errores.add('$nombre: ${e.values.first}');
        if (camposPrimero.isEmpty) camposPrimero.addAll(e);
      }
    }
    if (errores.isNotEmpty) {
      throw LayoutException(errores.join('\n'), campos: camposPrimero);
    }

    final normalizadas = TableLayoutValidator.normalizarCombinaciones(conId);
    final nuevosIds = {for (final m in normalizadas) m.id};
    final eliminadas = [
      for (final m in actuales)
        if (!nuevosIds.contains(m.id)) m,
    ];

    // Mesas con reservas activas a futuro: no se borran ni se les quita capacidad.
    final protegidas = <String>[];
    for (final m in eliminadas) {
      final res = await reservasActivasDeMesa(restauranteId, m.id);
      if (res.isNotEmpty) {
        protegidas.add('${m.nombre} (${res.length} ${res.length == 1 ? 'reserva' : 'reservas'})');
      }
    }
    for (final m in normalizadas) {
      final antes = porIdActual[m.id];
      if (antes != null && m.capacidad < antes.capacidad) {
        final res = await reservasActivasDeMesa(restauranteId, m.id);
        if (res.isNotEmpty) {
          protegidas.add(
            '${m.nombre}: no puede bajar de ${antes.capacidad} sillas '
            '(${res.length} ${res.length == 1 ? 'reserva' : 'reservas'})',
          );
        }
      }
    }
    if (protegidas.isNotEmpty) {
      throw LayoutException(
        'Hay reservas activas que usan estas mesas: ${protegidas.join('; ')}. '
        'Cancela o reubica esas reservas antes de cambiarlas.',
      );
    }

    // Elementos decorativos: se validan y se reemplazan completos.
    final elementosConId = <ElementoPlano>[];
    final elementosAEliminar = <String>[];
    final refsElementos = <String, DocumentReference<Map<String, dynamic>>>{};
    if (elementos != null) {
      for (final e in elementos) {
        if (e.id.isEmpty || e.id.startsWith(prefijoTemporal)) {
          final ref = _elementos(restauranteId).doc();
          refsElementos[ref.id] = ref;
          elementosConId.add(e.copyWith(id: ref.id));
        } else {
          elementosConId.add(e);
        }
      }
      final erroresElem = <String>[];
      for (final e in elementosConId) {
        final err = e.validar(zonaIds: zonaIds);
        if (err.isNotEmpty) {
          erroresElem.add('${ElementoPlano.estilo(e.tipo).nombre}: ${err.values.first}');
        }
      }
      if (erroresElem.isNotEmpty) {
        throw LayoutException(erroresElem.join('\n'));
      }
      final actualesElem = await getElementos(restauranteId);
      final idsNuevos = {for (final e in elementosConId) e.id};
      for (final e in actualesElem) {
        if (!idsNuevos.contains(e.id)) elementosAEliminar.add(e.id);
      }
    }

    final batch = _db.batch();
    var creadas = 0;
    var actualizadas = 0;
    for (final m in normalizadas) {
      final ref = refs[m.id] ?? _mesas(restauranteId).doc(m.id);
      final existe = porIdActual.containsKey(m.id);
      batch.set(ref, m.toMap());
      if (existe) {
        actualizadas++;
      } else {
        creadas++;
      }
    }
    for (final m in eliminadas) {
      batch.delete(_mesas(restauranteId).doc(m.id));
    }
    for (final e in elementosConId) {
      batch.set(refsElementos[e.id] ?? _elementos(restauranteId).doc(e.id), e.toMap());
    }
    for (final id in elementosAEliminar) {
      batch.delete(_elementos(restauranteId).doc(id));
    }

    // Historial: una línea con lo que se hizo en este guardado.
    final partes = <String>[
      if (creadas > 0) '$creadas ${creadas == 1 ? 'mesa nueva' : 'mesas nuevas'}',
      if (actualizadas > 0) '$actualizadas ${actualizadas == 1 ? 'mesa actualizada' : 'mesas actualizadas'}',
      if (eliminadas.isNotEmpty) '${eliminadas.length} ${eliminadas.length == 1 ? 'mesa eliminada' : 'mesas eliminadas'}',
      if (elementos != null) '${elementosConId.length} ${elementosConId.length == 1 ? 'elemento' : 'elementos'} de decoración',
    ];
    batch.set(_historial(restauranteId).doc(), {
      'fecha': Timestamp.fromDate(_now()),
      'resumen': partes.isEmpty ? 'Plano guardado' : partes.join(', '),
      'mesas': normalizadas.length,
      'elementos': elementosConId.length,
    });
    await batch.commit();

    return PlanSaveResult(
      mesas: normalizadas,
      elementos: elementosConId,
      creadas: creadas,
      actualizadas: actualizadas,
      eliminadas: eliminadas.length,
    );
  }
}
