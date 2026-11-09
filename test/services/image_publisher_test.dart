import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/services/image_publisher.dart';
import 'package:reservitta/services/storage_service.dart';
import 'package:reservitta/utils/image_data_uri.dart';

class _Storage implements StorageService {
  String? url = 'https://storage.test/foto.jpg';
  Object? falla;
  bool colgar = false;
  final subidas = <Map<String, Object?>>[];

  @override
  Future<String> uploadRestaurantImage({
    required String restaurantId,
    required String folder,
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    subidas.add({'rest': restaurantId, 'carpeta': folder, 'bytes': imageBytes.length, 'ext': fileExtension});
    if (colgar) return Completer<String>().future;
    if (falla != null) throw falla!;
    return url!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('StorageService: ayudas', () {
    test('el tipo de contenido es válido (jpg se vuelve image/jpeg)', () {
      expect(StorageService.contentTypePara('jpg'), 'image/jpeg');
      expect(StorageService.contentTypePara('JPEG'), 'image/jpeg');
      expect(StorageService.contentTypePara('png'), 'image/png');
      expect(StorageService.contentTypePara('webp'), 'image/webp');
      expect(StorageService.contentTypePara('gif'), 'image/gif');
      expect(StorageService.contentTypePara('xyz'), 'image/jpeg');
    });

    test('la extensión se limpia y por defecto es jpg', () {
      expect(StorageService.extensionSegura(' PNG '), 'png');
      expect(StorageService.extensionSegura('../../x'), 'x');
      expect(StorageService.extensionSegura(''), 'jpg');
      expect(StorageService.extensionSegura('***'), 'jpg');
    });

    test('el máximo es de 5 MB', () {
      expect(StorageService.maxBytes, 5 * 1024 * 1024);
    });
  });

  group('ImagePublisher', () {
    late _Storage storage;
    late ImagePublisher publicador;

    setUp(() {
      storage = _Storage();
      publicador = ImagePublisher(storage, timeout: const Duration(milliseconds: 200));
    });

    Future<PublishedImage> publicar(int bytes, {String folder = 'covers', String ext = 'jpg'}) =>
        publicador.publicar(
          restaurantId: 'r1',
          folder: folder,
          bytes: Uint8List(bytes),
          extension: ext,
        );

    test('sube a Cloud Storage y devuelve su dirección', () async {
      final r = await publicar(1000, folder: 'logos', ext: 'png');
      expect(r.enNube, isTrue);
      expect(r.url, 'https://storage.test/foto.jpg');
      expect(storage.subidas.single, {'rest': 'r1', 'carpeta': 'logos', 'bytes': 1000, 'ext': 'png'});
    });

    test('también acepta una lista de enteros', () async {
      final r = await publicador.publicar(
        restaurantId: 'r1',
        folder: 'covers',
        bytes: [1, 2, 3],
        extension: 'jpg',
      );
      expect(r.enNube, isTrue);
      expect(storage.subidas.single['bytes'], 3);
    });

    test('si Storage falla y la imagen es pequeña la guarda como respaldo', () async {
      storage.falla = Exception('storage/unauthorized');
      final r = await publicar(50 * 1024);
      expect(r.enNube, isFalse);
      expect(r.url, startsWith('data:image/jpg;base64,'));
    });

    test('si Storage se cuelga espera el tiempo límite y usa el respaldo', () async {
      storage.colgar = true;
      final r = await publicar(10 * 1024);
      expect(r.enNube, isFalse);
    });

    test('si Storage falla y la imagen es pesada explica qué pasó en vez de un error técnico', () async {
      storage.falla = Exception('storage/unauthorized');
      await expectLater(
        publicar(1024 * 1024),
        throwsA(isA<ImageUploadException>()
            .having((e) => e.message, 'mensaje', allOf(contains('Cloud Storage'), contains('más ligera')))),
      );
    });

    test('una imagen demasiado pesada para Storage no se guarda de otra forma', () async {
      storage.falla = const ImageTooLargeException('La imagen pesa 6.0 MB y el máximo es 5 MB.');
      await expectLater(publicar(100), throwsA(isA<ImageTooLargeException>()));
      expect(storage.subidas, hasLength(1));
    });

    test('el respaldo cabe junto a otra imagen en el documento', () {
      // Dos respaldos juntos no pasan el presupuesto de un documento de Firestore.
      expect(ImagePublisher.maxRespaldo * 2, lessThanOrEqualTo(ImageDataUri.maxCaracteresPorDocumento));
    });
  });
}
