import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Sube los bytes de una imagen a Cloud Storage en la ruta indicada y retorna la URL pública
  Future<String> uploadRestaurantImage({
    required String restaurantId,
    required String folder, // 'logos' o 'covers'
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final path = 'restaurants/$restaurantId/$folder/$fileName';
      final ref = _storage.ref().child(path);

      final metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
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
