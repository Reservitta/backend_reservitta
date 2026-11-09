import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/utils/validators.dart';
import 'package:reservitta/viewmodels/auth_modal_viewmodel.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/views/landing_view.dart';
import 'package:reservitta/views/reservation_management_view.dart';

class _Restaurantes extends RestaurantService {
  @override
  Future<List<ServiceCatalogModel>> getServicesCatalog() async => [];

  @override
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    dynamic startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async =>
      const PaginatedRestaurantsResult(
        restaurants: [RestaurantModel(id: 'r1', nombre: 'Miel', estado: 'activo')],
        lastDocument: null,
        hasMore: false,
      );
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  group('Contraseña de cuentas nuevas: 8 caracteres, una letra y un número', () {
    String? clave(String password) => AppValidators.validateRegistration(
          nombre: 'Ana Pérez',
          correo: 'ana@test.com',
          telefono: '5512345678',
          password: password,
          confirmPassword: password,
        )['password'];

    test('rechaza menos de 8 caracteres', () {
      expect(clave('abc123'), contains('8 caracteres'));
      expect(clave('secret1'), contains('8 caracteres'));
    });

    test('exige una letra y un número', () {
      expect(clave('12345678'), contains('letra'));
      expect(clave('abcdefgh'), contains('número'));
    });

    test('acepta una contraseña válida', () {
      expect(clave('secreto1'), isNull);
      expect(clave('Contraseña2026'), isNull);
    });

    test('el inicio de sesión sigue aceptando 6 caracteres para las cuentas ya creadas', () {
      expect(AppValidators.validateLogin(email: 'ana@test.com', password: 'abc123')['loginPassword'], isNull);
      expect(AppValidators.validateLogin(email: 'ana@test.com', password: 'abc12')['loginPassword'], isNotNull);
    });
  });

  group('Formulario de registro', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    AuthModalViewModel crear() {
      final vm = AuthModalViewModel(authService: AuthService(auth: MockFirebaseAuth(), firestore: db));
      addTearDown(vm.dispose);
      return vm;
    }

    void llenar(AuthModalViewModel vm, String password) {
      vm.nombreController.text = 'Ana López';
      vm.correoController.text = 'ana@test.com';
      vm.telefonoController.text = '4181234567';
      vm.registerPasswordController.text = password;
      vm.confirmPasswordController.text = password;
    }

    test('no registra con 7 caracteres y explica el motivo', () async {
      final vm = crear();
      llenar(vm, 'secret1');
      expect(await vm.register(), isFalse);
      expect(vm.fieldErrors['password'], contains('8 caracteres'));
      expect((await db.collection('users').get()).docs, isEmpty);
    });

    test('no registra sin número ni sin letra', () async {
      final vm = crear();
      llenar(vm, 'abcdefgh');
      expect(await vm.register(), isFalse);
      expect(vm.fieldErrors['password'], contains('número'));
      llenar(vm, '12345678');
      expect(await vm.register(), isFalse);
      expect(vm.fieldErrors['password'], contains('letra'));
    });

    test('al corregir la contraseña el error se quita al escribir', () async {
      final vm = crear();
      llenar(vm, 'secret1');
      await vm.register();
      vm.registerPasswordController.text = 'secreto1';
      expect(vm.fieldErrors['password'], isNull);
    });

    test('registra con 8 caracteres, una letra y un número', () async {
      final vm = crear();
      llenar(vm, 'secreto1');
      expect(await vm.register(), isTrue);
      expect((await db.collection('users').get()).docs, hasLength(1));
    });

    test('registrar administrador exige lo mismo', () async {
      final vm = crear();
      vm.setSelectedRole('admin');
      llenar(vm, 'secret1');
      expect(await vm.register(), isFalse);
      llenar(vm, 'secreto1');
      expect(await vm.register(), isTrue);
    });
  });

  group('El servicio también exige 8 caracteres', () {
    test('rechaza contraseñas cortas para administrador y visitante', () async {
      final svc = AuthService(auth: MockFirebaseAuth(), firestore: FakeFirebaseFirestore());
      await expectLater(
        svc.registerAdmin(nombre: 'Ana', correo: 'a@test.com', telefono: '4181234567', password: 'secret1'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('8 caracteres'))),
      );
      await expectLater(
        svc.registerVisitor(nombre: 'Ana', correo: 'a@test.com', telefono: '4181234567', password: 'secret1'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('8 caracteres'))),
      );
    });
  });

  group('"Gestionar mi reserva" en la portada', () {
    Future<void> abrir(WidgetTester tester, {required bool conSesion}) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = PublicCatalogViewModel(
        restaurantService: _Restaurantes(),
        isAuthenticated: conSesion,
        currentUserName: conSesion ? 'ana@test.com' : null,
      );
      await tester.pumpWidget(MaterialApp(home: LandingView(viewModel: vm)));
      await tester.pumpAndSettle();
    }

    testWidgets('sin sesión aparece y abre la gestión', (tester) async {
      await abrir(tester, conSesion: false);
      await tester.tap(find.byKey(const ValueKey('boton_header_gestionar_reserva')));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationManagementView), findsOneWidget);
    });

    testWidgets('con sesión también aparece y abre la gestión', (tester) async {
      await abrir(tester, conSesion: true);
      expect(find.byKey(const ValueKey('btn_header_mi_pedido')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_header_gestionar_reserva')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('boton_header_gestionar_reserva')));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationManagementView), findsOneWidget);
    });

    testWidgets('con sesión no aparecen los botones de crear cuenta ni iniciar sesión', (tester) async {
      await abrir(tester, conSesion: true);
      expect(find.byKey(const ValueKey('boton_header_registrarse')), findsNothing);
      expect(find.byKey(const ValueKey('boton_header_iniciar_sesion')), findsNothing);
    });
  });
}
