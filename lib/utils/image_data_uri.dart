import 'dart:convert';
import 'dart:typed_data';

/// La imagen es demasiado pesada para guardarse dentro del documento de Firestore.
class ImageTooLargeException implements Exception {
  final String message;

  const ImageTooLargeException(this.message);

  @override
  String toString() => message;
}

/// Imágenes como "data URI" (base64) dentro de Firestore.
///
/// En web las imágenes del restaurante se guardan en el propio documento, y Firestore
/// limita cada documento a 1 MiB (1,048,576 bytes). Se valida antes de escribir para
/// avisar con un mensaje claro en lugar del error crudo de Firestore.
class ImageDataUri {
  ImageDataUri._();

  /// Presupuesto en caracteres para todas las imágenes de un mismo documento; deja margen
  /// para el resto de los campos del restaurante.
  static const int maxCaracteresPorDocumento = 900000;

  /// 'data:image/jpg;base64,...' con los [bytes] dados.
  static String crear(Uint8List bytes, String extension) {
    final ext = extension.trim().isEmpty ? 'jpg' : extension.trim().toLowerCase();
    return 'data:image/$ext;base64,${base64Encode(bytes)}';
  }

  /// Aproximación del tamaño en KB de una imagen ya codificada.
  static int kilobytes(int caracteres) => (caracteres / 1024).ceil();

  /// Lanza [ImageTooLargeException] si las imágenes [codificadas] juntas no caben en
  /// un documento de Firestore.
  static void validarPresupuesto(Iterable<String> codificadas) {
    final total = codificadas.fold<int>(0, (suma, s) => suma + s.length);
    if (total > maxCaracteresPorDocumento) {
      throw ImageTooLargeException(
        'Las imágenes pesan demasiado (${kilobytes(total)} KB) para guardarse. '
        'Usa imágenes más ligeras: entre el logo y la foto principal deben pesar '
        'menos de ${kilobytes(maxCaracteresPorDocumento) * 3 ~/ 4} KB.',
      );
    }
  }
}
