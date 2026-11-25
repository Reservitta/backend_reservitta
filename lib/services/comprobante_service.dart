import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/image_data_uri.dart';

/// Un comprobante de transferencia ya guardado.
class Comprobante {
  final String imagen; // data URI
  final DateTime? enviadoEn;

  const Comprobante({required this.imagen, this.enviadoEn});

  /// Bytes de la imagen para mostrarla; null si el dato no es una imagen válida.
  Uint8List? get bytes {
    try {
      return UriData.parse(imagen).contentAsBytes();
    } catch (_) {
      return null;
    }
  }
}

/// Guarda los comprobantes de transferencia (de anticipos y de pedidos).
///
/// Sin Cloud Storage, la imagen se guarda en su propio documento de `comprobantes`
/// y no dentro de la reserva o el pedido, para no volver pesadas las listas del
/// restaurante. Cada reserva o pedido tiene un solo comprobante: subir otro lo reemplaza.
class ComprobanteService {
  final FirebaseFirestore? _firestoreInstance;

  ComprobanteService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  /// Máximo de caracteres del data URI: deja margen bajo el límite de 1 MiB.
  static const int maxCaracteres = 700000;

  static String docId(String tipo, String refId) => '${tipo}_$refId';

  /// Guarda el comprobante de la reserva (`reserva`) o del pedido (`pedido`).
  Future<void> guardar({
    required String tipo,
    required String refId,
    required String restauranteId,
    required String usuarioId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final imagen = ImageDataUri.crear(bytes, extension);
    if (imagen.length > maxCaracteres) {
      throw const ImageTooLargeException(
        'La imagen del comprobante pesa demasiado. Toma una captura más ligera '
        'o recórtala e inténtalo de nuevo.',
      );
    }
    await _firestore.collection('comprobantes').doc(docId(tipo, refId)).set({
      'tipo': tipo,
      'refId': refId,
      'restauranteId': restauranteId,
      'usuarioId': usuarioId,
      'imagen': imagen,
      'enviadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<Comprobante?> obtener(String tipo, String refId) async {
    final snap =
        await _firestore.collection('comprobantes').doc(docId(tipo, refId)).get();
    final data = snap.data();
    if (data == null) return null;
    final imagen = data['imagen'] as String? ?? '';
    if (imagen.isEmpty) return null;
    final ts = data['enviadoEn'];
    return Comprobante(imagen: imagen, enviadoEn: ts is Timestamp ? ts.toDate() : null);
  }
}
