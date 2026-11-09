import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mesa_model.dart';
import '../models/reservation_model.dart';
import '../models/table_layout_validator.dart';
import '../models/zona_model.dart';

/// Resultado de guardar el plano.
class PlanSaveResult {
  /// Mesas guardadas, ya con su id (las nuevas lo reciben al guardarse).
  final List<MesaModel> mesas;
  final int creadas;
  final int actualizadas;
  final int eliminadas;

  const PlanSaveResult({
    required this.mesas,
    required this.creadas,
    required this.actualizadas,
    required this.eliminadas,
  });
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
    await batch.commit();

    return PlanSaveResult(
      mesas: normalizadas,
      creadas: creadas,
      actualizadas: actualizadas,
      eliminadas: eliminadas.length,
    );
  }
}
