import 'dart:typed_data';

import '../utils/image_data_uri.dart';
import 'storage_service.dart';

/// Imagen ya publicada: su dirección y dónde quedó guardada.
class PublishedImage {
  final String url;

  /// true si está en Cloud Storage; false si quedó dentro del documento (respaldo).
  final bool enNube;

  const PublishedImage({required this.url, required this.enNube});
}

/// No se pudo publicar la imagen ni siquiera con el respaldo.
class ImageUploadException implements Exception {
  final String message;

  const ImageUploadException(this.message);

  @override
  String toString() => message;
}

/// Publica las imágenes del restaurante (logo, foto principal, sucursales).
///
/// Las sube a Cloud Storage y guarda solo su dirección en Firestore. Si Storage no está
/// disponible (sin configurar, sin red o sin permiso) y la imagen es pequeña, la guarda
/// dentro del documento como respaldo para no bloquear al administrador; si es pesada,
/// explica qué pasó en lugar de fallar con un error técnico.
class ImagePublisher {
  final StorageService _storage;
  final Duration timeout;

  /// Tamaño máximo (en caracteres) de una imagen guardada como respaldo dentro del
  /// documento; deja lugar a la otra imagen y al resto de los campos.
  static const int maxRespaldo = ImageDataUri.maxCaracteresPorDocumento ~/ 2;

  ImagePublisher(this._storage, {this.timeout = const Duration(seconds: 30)});

  Future<PublishedImage> publicar({
    required String restaurantId,
    required String folder,
    required List<int> bytes,
    required String extension,
  }) async {
    final datos = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    try {
      final url = await _storage
          .uploadRestaurantImage(
            restaurantId: restaurantId,
            folder: folder,
            imageBytes: datos,
            fileExtension: extension,
          )
          .timeout(timeout);
      return PublishedImage(url: url, enNube: true);
    } on ImageTooLargeException {
      // Una imagen demasiado pesada para Storage tampoco se guarda de otra forma.
      rethrow;
    } catch (_) {
      final respaldo = ImageDataUri.crear(datos, extension);
      if (respaldo.length <= maxRespaldo) {
        return PublishedImage(url: respaldo, enNube: false);
      }
      throw const ImageUploadException(
        'No se pudo subir la imagen a Cloud Storage y pesa demasiado para guardarla de otra forma. '
        'Usa una imagen más ligera o pide que revisen la configuración de Storage.',
      );
    }
  }
}
