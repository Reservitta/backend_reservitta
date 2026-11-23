import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pedido_model.dart';

/// Datos del pedido que el cliente confirma.
class PedidoInvalidoException implements Exception {
  final String message;
  const PedidoInvalidoException(this.message);
  @override
  String toString() => message;
}

/// Pedidos a domicilio y para recoger, guardados en la colección `pedidos`.
class PedidoService {
  final FirebaseFirestore? _firestoreInstance;

  PedidoService({FirebaseFirestore? firestore}) : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('pedidos');

  /// Id del pedido antes de guardarlo: sirve para armar el concepto de la transferencia.
  String nuevoId() => _ref.doc().id;

  /// Valida el pedido y mensaje del primer problema, o null si todo está bien.
  static String? validar(PedidoModel p) {
    if (p.lineas.isEmpty || p.totalPlatillos <= 0) {
      return 'Agrega al menos un platillo a tu pedido.';
    }
    if (p.contactoNombre.trim().length < 2) return 'Escribe tu nombre.';
    final tel = p.contactoTelefono.replaceAll(RegExp(r'\D'), '');
    if (tel.length < 10) return 'Escribe un teléfono de 10 dígitos para avisarte de tu pedido.';
    if (p.esDomicilio && p.direccion.trim().length < 8) {
      return 'Escribe tu dirección completa para llevarte el pedido.';
    }
    return null;
  }

  /// Guarda el pedido como "recibido". El total siempre se recalcula de las líneas.
  Future<PedidoModel> crear(PedidoModel pedido, {String? id}) async {
    final problema = validar(pedido);
    if (problema != null) throw PedidoInvalidoException(problema);
    final ref = id != null ? _ref.doc(id) : _ref.doc();
    final guardado = PedidoModel(
      id: ref.id,
      restauranteId: pedido.restauranteId,
      restauranteNombre: pedido.restauranteNombre,
      usuarioId: pedido.usuarioId,
      contactoNombre: pedido.contactoNombre.trim(),
      contactoTelefono: pedido.contactoTelefono.trim(),
      lineas: pedido.lineas,
      total: PedidoModel.sumar(pedido.lineas),
      tipoEntrega: pedido.tipoEntrega,
      direccion: pedido.direccion.trim(),
      referencias: pedido.referencias.trim(),
      metodoPago: pedido.metodoPago,
      estadoPago: PedidoModel.pagoPendiente,
      estado: PedidoModel.estadoRecibido,
    );
    await ref.set(guardado.toMap());
    return guardado;
  }

  /// Seguimiento en tiempo real de un pedido (para el cliente).
  Stream<PedidoModel?> seguir(String pedidoId) => _ref.doc(pedidoId).snapshots().map(
        (s) => s.exists ? PedidoModel.fromFirestore(s) : null,
      );

  /// Pedidos del restaurante, los más recientes primero.
  Stream<List<PedidoModel>> pedidosDelRestaurante(String restauranteId) {
    return _ref.where('restauranteId', isEqualTo: restauranteId).snapshots().map((q) {
      final lista = q.docs.map(PedidoModel.fromFirestore).toList();
      lista.sort((a, b) {
        final fa = a.creadoEn ?? DateTime.fromMillisecondsSinceEpoch(0);
        final fb = b.creadoEn ?? DateTime.fromMillisecondsSinceEpoch(0);
        return fb.compareTo(fa);
      });
      return lista;
    });
  }

  /// Avanza o cancela el pedido. Valida que el cambio tenga sentido.
  Future<void> cambiarEstado(String pedidoId, String nuevoEstado) async {
    final snap = await _ref.doc(pedidoId).get();
    if (!snap.exists) throw StateError('El pedido $pedidoId no existe.');
    final pedido = PedidoModel.fromFirestore(snap);
    if (pedido.estaCerrado) {
      throw StateError('Un pedido ${pedido.etiquetaEstadoActual.toLowerCase()} ya no cambia.');
    }
    final valido = nuevoEstado == PedidoModel.estadoCancelado
        ? pedido.sePuedeCancelar
        : nuevoEstado == pedido.siguienteEstado;
    if (!valido) {
      throw StateError(
        'No se puede pasar de "${pedido.etiquetaEstadoActual}" a "${PedidoModel.etiquetaEstado(nuevoEstado, tipoEntrega: pedido.tipoEntrega)}".',
      );
    }
    await _ref.doc(pedidoId).update({
      'estado': nuevoEstado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// El cliente avisa que ya subió su comprobante.
  Future<void> marcarComprobanteEnviado(String pedidoId) => _ref.doc(pedidoId).update({
        'pago.estado': PedidoModel.pagoComprobanteEnviado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

  /// El restaurante confirma que recibió el pago (transferencia o efectivo).
  Future<void> confirmarPago(String pedidoId) => _ref.doc(pedidoId).update({
        'pago.estado': PedidoModel.pagoConfirmado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

  /// El comprobante no es válido: el cliente puede subir otro.
  Future<void> rechazarPago(String pedidoId) => _ref.doc(pedidoId).update({
        'pago.estado': PedidoModel.pagoRechazado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
}
