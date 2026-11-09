import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/utils/image_data_uri.dart';

void main() {
  test('crea un data URI con la extensión en minúsculas', () {
    final uri = ImageDataUri.crear(Uint8List.fromList([1, 2, 3]), 'PNG');
    expect(uri, startsWith('data:image/png;base64,'));
  });

  test('sin extensión usa jpg', () {
    expect(ImageDataUri.crear(Uint8List.fromList([1]), ' '), startsWith('data:image/jpg;base64,'));
  });

  test('una imagen pequeña cabe en el documento', () {
    ImageDataUri.validarPresupuesto([ImageDataUri.crear(Uint8List(100 * 1024), 'jpg')]);
  });

  test('una imagen que pasa el límite de Firestore se rechaza con un mensaje claro', () {
    // ~1 MB de bytes -> ~1.4 M caracteres en base64, más que el límite de 1 MiB del documento.
    final grande = ImageDataUri.crear(Uint8List(1024 * 1024), 'jpg');
    expect(
      () => ImageDataUri.validarPresupuesto([grande]),
      throwsA(isA<ImageTooLargeException>()
          .having((e) => e.message, 'mensaje', contains('más ligeras'))),
    );
  });

  test('el límite cuenta todas las imágenes del documento juntas', () {
    final media = ImageDataUri.crear(Uint8List(400 * 1024), 'jpg'); // ~547 mil caracteres
    ImageDataUri.validarPresupuesto([media]);
    expect(() => ImageDataUri.validarPresupuesto([media, media]),
        throwsA(isA<ImageTooLargeException>()));
  });

  test('sin imágenes no hay nada que validar', () {
    ImageDataUri.validarPresupuesto(const []);
  });
}
