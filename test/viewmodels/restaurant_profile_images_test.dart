import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/services/storage_service.dart';
import 'package:reservitta/viewmodels/restaurant_profile_viewmodel.dart';

class _NoStorage implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  RestaurantProfileViewModel crear() {
    final db = FakeFirebaseFirestore();
    final vm = RestaurantProfileViewModel(
      restaurantId: 'r1',
      restaurantService: RestaurantService(firestore: db),
      storageService: _NoStorage(),
      authService: AuthService(auth: MockFirebaseAuth(), firestore: db),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  test('sin imágenes no hay logo ni foto principal', () {
    final vm = crear();
    expect(vm.tieneLogo, isFalse);
    expect(vm.tieneFotoPrincipal, isFalse);
  });

  test('quitar el logo elimina la imagen nueva y la ya guardada', () {
    final vm = crear();
    vm.logoBytes = Uint8List.fromList([1, 2, 3]);
    vm.logoFileName = 'logo.png';
    vm.logoUrl = 'https://x.test/logo.png';
    expect(vm.tieneLogo, isTrue);

    var avisos = 0;
    vm.addListener(() => avisos++);
    vm.quitarLogo();

    expect(vm.logoBytes, isNull);
    expect(vm.logoFileName, isNull);
    expect(vm.logoUrl, '');
    expect(vm.tieneLogo, isFalse);
    expect(avisos, 1);
  });

  test('quitar la foto principal elimina la imagen nueva y la ya guardada', () {
    final vm = crear();
    vm.coverBytes = Uint8List.fromList([1, 2, 3]);
    vm.coverFileName = 'foto.jpg';
    vm.imagenPrincipalUrl = 'data:image/jpg;base64,AAAA';
    expect(vm.tieneFotoPrincipal, isTrue);

    vm.quitarFotoPrincipal();

    expect(vm.coverBytes, isNull);
    expect(vm.coverFileName, isNull);
    expect(vm.imagenPrincipalUrl, '');
    expect(vm.tieneFotoPrincipal, isFalse);
  });

  test('quitar una imagen no toca la otra', () {
    final vm = crear();
    vm.logoBytes = Uint8List.fromList([1]);
    vm.coverBytes = Uint8List.fromList([2]);
    vm.quitarFotoPrincipal();
    expect(vm.tieneLogo, isTrue);
    expect(vm.tieneFotoPrincipal, isFalse);
  });

  test('quitar la foto limpia el error de "imagen demasiado pesada" para poder continuar', () {
    final vm = crear();
    vm.coverBytes = Uint8List.fromList([1]);
    vm.errorMessage = 'Las imágenes pesan demasiado (1500 KB) para guardarse.';
    vm.quitarFotoPrincipal();
    expect(vm.errorMessage, isNull);
  });

  test('quitar algo que no existe no falla', () {
    final vm = crear();
    vm.quitarLogo();
    vm.quitarFotoPrincipal();
    expect(vm.tieneLogo, isFalse);
  });
}
