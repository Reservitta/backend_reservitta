import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/image_data_uri.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Peso máximo de una imagen del restaurante (5 MB).
  static const int maxBytes = 5 * 1024 * 1024;

  /// Extensión en minúsculas y sin caracteres raros; 'jpg' si viene vacía.
  static String extensionSegura(String extension) {
    final limpia = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return limpia.isEmpty ? 'jpg' : limpia;
  }

  /// Tipo de contenido correcto para la extensión ("jpg" no es un tipo válido: es image/jpeg).
  static String contentTypePara(String extension) {
    switch (extensionSegura(extension)) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  /// Sube los bytes de una imagen a Cloud Storage en la ruta indicada y retorna la URL pública.
  /// Lanza [ImageTooLargeException] si pesa más de [maxBytes].
  Future<String> uploadRestaurantImage({
    required String restaurantId,
    required String folder, // 'logos', 'covers' o 'sucursales'
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    if (imageBytes.length > maxBytes) {
      final mb = (imageBytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw ImageTooLargeException(
        'La imagen pesa $mb MB y el máximo es ${maxBytes ~/ (1024 * 1024)} MB. Usa una más ligera.',
      );
    }
    try {
      final ext = extensionSegura(fileExtension);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'restaurants/$restaurantId/$folder/$fileName';
      final ref = _storage.ref().child(path);

      final metadata = SettableMetadata(
        contentType: contentTypePara(ext),
        customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
      );

      final uploadTask = await ref.putData(imageBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir imagen a Cloud Storage: $e');
    }
  }
}
