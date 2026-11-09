import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/arrival_alert.dart';
import '../models/operations_config.dart';
import '../models/reservation_model.dart';

/// Mensaje push para el administrador (HU30-RF02).
class AdminPushMessage {
  final String clave;
  final String restauranteId;
  final String reservaId;
  final String titulo;
  final String cuerpo;
  final Map<String, dynamic> datos;

  const AdminPushMessage({
    required this.clave,
    required this.restauranteId,
    required this.reservaId,
    required this.titulo,
    required this.cuerpo,
    required this.datos,
  });

  /// Arma el mensaje con cliente, hora, mesa y si hay preorden o alergias por preparar.
  factory AdminPushMessage.deAlerta(ArrivalAlert alerta) {
    final r = alerta.reserva;
    final hora = _hhmm(r.effectiveStart);
    final cliente = r.contactoNombre.trim().isEmpty ? 'Cliente' : r.contactoNombre.trim();
    final mesa = r.mesasNombres.isEmpty ? 'sin mesa' : r.mesasNombres.join(' + ');
    final partes = <String>[
      '$cliente · $hora · $mesa',
      if (r.tienePreorden)
        alerta.pedidoListo ? 'Preorden lista' : 'Preorden por preparar',
      if (r.tieneRestriccionesOAlergias) 'Alergias o restricciones',
    ];
    return AdminPushMessage(
      clave: alerta.clave,
      restauranteId: r.restauranteId,
      reservaId: r.id,
      titulo: alerta.esRetraso
          ? 'Cliente sin llegar: $cliente'
          : 'Llega pronto: $cliente',
      cuerpo: partes.join('\n'),
      datos: {
        'tipo': alerta.tipo.name,
        'cliente': cliente,
        'hora': hora,
        'mesas': r.mesasNombres,
        'tienePreorden': r.tienePreorden,
        'pedidoListo': alerta.pedidoListo,
        'tieneAlergias': r.tieneRestriccionesOAlergias,
        'minutos': alerta.minutos,
      },
    );
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Envía el push al dispositivo del administrador (HU30-RF02).
///
/// La implementación por defecto, [FirestorePushQueue], deja el mensaje en una cola
/// de Firestore; un proceso de servidor con acceso a Firebase Cloud Messaging (por
/// ejemplo una Cloud Function) lo toma y lo envía a los dispositivos registrados.
abstract class AdminPushGateway {
  Future<void> enviar(AdminPushMessage mensaje);
}

class FirestorePushQueue implements AdminPushGateway {
  final FirebaseFirestore? _firestoreInstance;

  FirestorePushQueue({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  @override
  Future<void> enviar(AdminPushMessage m) {
    // El id es la clave: reenviar el mismo aviso no crea otro documento.
    return _db
        .collection('restaurants')
        .doc(m.restauranteId)
        .collection('colaPush')
        .doc(m.clave)
        .set({
      'canal': 'fcm',
      'destino': 'admin',
      'titulo': m.titulo,
      'cuerpo': m.cuerpo,
      'datos': m.datos,
      'reservaId': m.reservaId,
      'estado': 'pendiente',
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }
}

/// Resultado de [AdminAlertService.sincronizar].
class AlertSyncResult {
  final List<ArrivalAlert> alertas;
  final List<String> nuevas;
  final List<String> desactivadas;

  const AlertSyncResult({
    required this.alertas,
    required this.nuevas,
    required this.desactivadas,
  });
}

/// Registra y envía las alertas de llegada sin duplicarlas (HU30-RF02, HU30-RNF02).
///
/// Cada alerta se guarda en `restaurants/{id}/alertasAdmin/{reserva_tipo_umbral}`: ese
/// id garantiza que para la misma reserva y el mismo umbral se avise una sola vez,
/// aunque varios dispositivos del restaurante estén abiertos.
class AdminAlertService {
  final FirebaseFirestore? _firestoreInstance;
  final AdminPushGateway? _gatewayInstance;

  AdminAlertService({FirebaseFirestore? firestore, AdminPushGateway? gateway})
      : _firestoreInstance = firestore,
        _gatewayInstance = gateway;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  AdminPushGateway get _gateway =>
      _gatewayInstance ?? FirestorePushQueue(firestore: _firestoreInstance);

  CollectionReference<Map<String, dynamic>> _alertas(String restauranteId) =>
      _db.collection('restaurants').doc(restauranteId).collection('alertasAdmin');

  /// Calcula las alertas, avisa de las nuevas y desactiva las que ya no aplican.
  Future<AlertSyncResult> sincronizar({
    required String restauranteId,
    required Iterable<ReservationModel> reservas,
    required DateTime ahora,
    OperationsConfig config = const OperationsConfig(),
  }) async {
    final alertas = ArrivalAlertCalculator.calcular(
      reservas: reservas,
      ahora: ahora,
      config: config,
    );
    final vigentes = {for (final a in alertas) a.clave};
    final nuevas = <String>[];

    for (final alerta in alertas) {
      final ref = _alertas(restauranteId).doc(alerta.clave);
      final mensaje = AdminPushMessage.deAlerta(alerta);
      final creada = await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) return false;
        tx.set(ref, {
          'reservaId': alerta.reserva.id,
          'tipo': alerta.tipo.name,
          'umbralMin': alerta.umbralMin,
          'titulo': mensaje.titulo,
          'cuerpo': mensaje.cuerpo,
          'datos': mensaje.datos,
          'activa': true,
          'leida': false,
          'pushEnviado': false,
          'creadaEn': Timestamp.fromDate(ahora),
        });
        return true;
      });
      if (!creada) continue;
      nuevas.add(alerta.clave);
      try {
        await _gateway.enviar(mensaje);
        await ref.update({'pushEnviado': true});
      } catch (_) {
        // El aviso dentro de la app no depende del push; queda pushEnviado=false
        // para que se pueda reintentar.
      }
    }

    final desactivadas = <String>[];
    final activas = await _alertas(restauranteId)
        .where('activa', isEqualTo: true)
        .get();
    for (final doc in activas.docs) {
      if (vigentes.contains(doc.id)) continue;
      await doc.reference.update({'activa': false});
      desactivadas.add(doc.id);
    }

    return AlertSyncResult(
      alertas: alertas,
      nuevas: nuevas,
      desactivadas: desactivadas,
    );
  }

  /// Marca como leída una alerta (el administrador la abrió).
  Future<void> marcarLeida(String restauranteId, String clave) =>
      _alertas(restauranteId).doc(clave).update({'leida': true});

  /// Alertas vigentes registradas, de la más reciente a la más antigua.
  Stream<List<Map<String, dynamic>>> alertasActivas(String restauranteId) {
    return _alertas(restauranteId)
        .where('activa', isEqualTo: true)
        .snapshots()
        .map((s) {
      final lista = [
        for (final d in s.docs) {...d.data(), 'clave': d.id},
      ];
      lista.sort((a, b) {
        final ta = a['creadaEn'];
        final tb = b['creadaEn'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        return 0;
      });
      return lista;
    });
  }
}
