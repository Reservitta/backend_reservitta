import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/utils/validators.dart';
import 'package:reservitta/viewmodels/auth_modal_viewmodel.dart';

class _AuthQueFalla extends MockFirebaseAuth {
  final bool registro;
  final bool reset;
  _AuthQueFalla({this.registro = false, this.reset = false});

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (registro) throw FirebaseAuthException(code: 'email-already-in-use');
    return super.createUserWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email, ActionCodeSettings? actionCodeSettings}) async {
    if (reset) throw FirebaseAuthException(code: 'invalid-email');
  }
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  AuthModalViewModel crear({FirebaseAuth? auth, AuthMode modo = AuthMode.login}) {
    final vm = AuthModalViewModel(
      authService: AuthService(auth: auth ?? MockFirebaseAuth(), firestore: db),
      initialMode: modo,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  void llenarRegistro(AuthModalViewModel vm, {String pass = 'secreto1', String confirm = 'secreto1'}) {
    vm.nombreController.text = 'Ana López';
    vm.correoController.text = 'ana@test.com';
    vm.telefonoController.text = '4181234567';
    vm.registerPasswordController.text = pass;
    vm.confirmPasswordController.text = confirm;
  }

  group('Navegación entre modos', () {
    test('empieza en el modo indicado y cambia de modo limpiando mensajes y errores', () {
      final vm = crear(modo: AuthMode.registerRoleSelection);
      expect(vm.currentMode, AuthMode.registerRoleSelection);
      vm.fieldErrors['x'] = 'error';
      vm.setMode(AuthMode.forgotPassword);
      expect(vm.currentMode, AuthMode.forgotPassword);
      expect(vm.fieldErrors, isEmpty);
      expect(vm.errorMessage, isNull);
    });

    test('el rol por defecto es visitante y se puede cambiar', () {
      final vm = crear();
      expect(vm.selectedRole, 'visitante');
      vm.setSelectedRole('admin');
      expect(vm.selectedRole, 'admin');
    });

    test('pasar al formulario y volver a elegir el rol', () {
      final vm = crear();
      vm.goToRegisterForm();
      expect(vm.currentMode, AuthMode.registerForm);
      vm.backToRoleSelection();
      expect(vm.currentMode, AuthMode.registerRoleSelection);
    });
  });

  group('Inicio de sesión', () {
    test('con campos vacíos muestra los errores y no llama a Firebase', () async {
      final vm = crear();
      expect(await vm.login(), isFalse);
      expect(vm.fieldErrors['loginEmail'], isNotNull);
      expect(vm.fieldErrors['loginPassword'], isNotNull);
      expect(vm.isLoading, isFalse);
    });

    test('un correo mal escrito se valida en tiempo real después del primer intento', () async {
      final vm = crear();
      await vm.login();
      vm.loginEmailController.text = 'mal correo';
      expect(vm.fieldErrors['loginEmail'], isNotNull);
      vm.loginEmailController.text = 'ana@test.com';
      expect(vm.fieldErrors['loginEmail'], isNull);
    });

    test('antes del primer intento no regaña mientras se escribe', () {
      final vm = crear();
      vm.loginEmailController.text = 'mal';
      expect(vm.fieldErrors['loginEmail'], isNull);
    });

    test('con cuenta y perfil válidos devuelve true', () async {
      await db.collection('users').doc('u1').set({'uid': 'u1', 'rol': 'visitante', 'nombre': 'Ana'});
      final vm = crear(auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u1', email: 'ana@test.com')));
      vm.loginEmailController.text = 'ana@test.com';
      vm.loginPasswordController.text = 'secreto1';
      expect(await vm.login(), isTrue);
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('una cuenta sin perfil de Reservitta muestra el error', () async {
      final vm = crear(auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u1', email: 'ana@test.com')));
      vm.loginEmailController.text = 'ana@test.com';
      vm.loginPasswordController.text = 'secreto1';
      expect(await vm.login(), isFalse);
      expect(vm.errorMessage, contains('perfil de Reservitta'));
      expect(vm.errorMessage, isNot(contains('Exception')));
      expect(vm.isLoading, isFalse);
    });

    test('notifica a los oyentes al empezar y al terminar', () async {
      final vm = crear();
      var llamadas = 0;
      vm.addListener(() => llamadas++);
      vm.loginEmailController.text = 'ana@test.com';
      vm.loginPasswordController.text = 'secreto1';
      await vm.login();
      expect(llamadas, greaterThanOrEqualTo(2));
    });

    test('la sesión anónima funciona', () async {
      final vm = crear();
      expect(await vm.signInAnonymously(), isTrue);
      expect(vm.isLoading, isFalse);
    });
  });

  group('Registro', () {
    test('con todo vacío marca todos los campos', () async {
      final vm = crear(modo: AuthMode.registerForm);
      expect(await vm.register(), isFalse);
      for (final c in ['nombre', 'correo', 'telefono', 'password', 'confirmPassword']) {
        expect(vm.fieldErrors[c], isNotNull, reason: c);
      }
    });

    test('contraseñas distintas no registran', () async {
      final vm = crear();
      llenarRegistro(vm, confirm: 'otra-cosa1');
      expect(await vm.register(), isFalse);
      expect(vm.fieldErrors['confirmPassword'], contains('no coinciden'));
    });

    test('cambiar la contraseña revalida la confirmación', () async {
      final vm = crear();
      llenarRegistro(vm, confirm: 'otra-cosa1');
      await vm.register();
      vm.registerPasswordController.text = 'otra-cosa1';
      expect(vm.fieldErrors['confirmPassword'], isNull);
    });

    test('un teléfono con letras o de longitud incorrecta se rechaza', () async {
      final vm = crear();
      llenarRegistro(vm);
      vm.telefonoController.text = '12345';
      expect(await vm.register(), isFalse);
      expect(vm.fieldErrors['telefono'], isNotNull);
      vm.telefonoController.text = '41812abcde';
      expect(vm.fieldErrors['telefono'], isNotNull);
    });

    test('registra a un visitante y avisa el éxito', () async {
      final vm = crear();
      llenarRegistro(vm);
      expect(await vm.register(), isTrue);
      expect(vm.successMessage, 'Registro exitoso.');
      final usuarios = await db.collection('users').get();
      expect(usuarios.docs.single.data()['rol'], 'visitante');
    });

    test('el nombre del restaurante es opcional pero no puede ser de un solo carácter', () async {
      final vm = crear();
      vm.setSelectedRole('admin');
      llenarRegistro(vm);
      vm.nombreRestauranteController.text = 'M';
      expect(await vm.register(), isFalse);
      expect(vm.fieldErrors['restaurante'], isNotNull);
      vm.nombreRestauranteController.text = '';
      expect(await vm.register(), isTrue);
      final rest = await db.collection('restaurants').get();
      expect(rest.docs.single.data()['nombre'], 'Restaurante de Ana López');
    });

    test('registra a un administrador con su restaurante', () async {
      final vm = crear();
      vm.setSelectedRole('admin');
      llenarRegistro(vm);
      vm.nombreRestauranteController.text = 'Miel';
      expect(await vm.register(), isTrue);
      expect((await db.collection('users').get()).docs.single.data()['rol'], 'admin');
      final rest = await db.collection('restaurants').get();
      expect(rest.docs.single.data()['nombre'], 'Miel');
    });

    test('un correo ya registrado muestra el mensaje sin la palabra Exception', () async {
      final vm = crear(auth: _AuthQueFalla(registro: true));
      llenarRegistro(vm);
      expect(await vm.register(), isFalse);
      expect(vm.errorMessage, contains('ya se encuentra registrado'));
      expect(vm.errorMessage, isNot(contains('Exception')));
      expect(vm.isLoading, isFalse);
      expect(vm.successMessage, isNull);
    });
  });

  group('Olvidé mi contraseña', () {
    test('un correo inválido no envía nada', () async {
      final vm = crear(modo: AuthMode.forgotPassword);
      vm.resetEmailController.text = 'mal';
      expect(await vm.sendPasswordReset(), isFalse);
      expect(vm.resetErrorMessage, isNotNull);
      expect(vm.isResetLoading, isFalse);
    });

    test('el error se corrige al escribir un correo válido', () async {
      final vm = crear();
      vm.resetEmailController.text = 'mal';
      await vm.sendPasswordReset();
      vm.resetEmailController.text = 'ana@test.com';
      expect(vm.resetErrorMessage, isNull);
    });

    test('con un correo válido avisa sin revelar si existe', () async {
      final vm = crear();
      vm.resetEmailController.text = 'ana@test.com';
      expect(await vm.sendPasswordReset(), isTrue);
      expect(vm.resetMessage, contains('Si el correo está registrado'));
      expect(vm.resetErrorMessage, isNull);
    });

    test('si Firebase rechaza el formato muestra su mensaje', () async {
      final vm = crear(auth: _AuthQueFalla(reset: true));
      vm.resetEmailController.text = 'ana@test.com';
      expect(await vm.sendPasswordReset(), isFalse);
      expect(vm.resetErrorMessage, contains('formato'));
    });
  });

  group('Validadores', () {
    test('nombre', () {
      expect(AppValidators.validateName(''), isNotNull);
      expect(AppValidators.validateName('A'), isNotNull);
      expect(AppValidators.validateName('Ana 2'), isNotNull);
      expect(AppValidators.validateName('Ana López'), isNull);
    });

    test('correo', () {
      for (final mal in ['', 'sin-arroba', 'a@b', 'con espacio@x.com', 'a@@b.com']) {
        expect(AppValidators.validateEmail(mal), isNotNull, reason: mal);
      }
      expect(AppValidators.validateEmail('ana@test.com'), isNull);
    });

    test('teléfono de 10 dígitos', () {
      expect(AppValidators.validatePhone(''), isNotNull);
      expect(AppValidators.validatePhone('123 456 7890'), isNotNull);
      expect(AppValidators.validatePhone('12345abcde'), isNotNull);
      expect(AppValidators.validatePhone('123456789'), isNotNull);
      expect(AppValidators.validatePhone('1234567890'), isNull);
      expect(AppValidators.validatePhone('12345678', digits: 8), isNull);
    });

    test('contraseñas', () {
      expect(AppValidators.validatePassword(''), isNotNull);
      expect(AppValidators.validatePassword('12345'), isNotNull);
      expect(AppValidators.validatePassword('123456'), isNull);
      expect(AppValidators.validateNewPassword('corta1'), contains('8 caracteres'));
      expect(AppValidators.validateNewPassword('12345678'), contains('letra'));
      expect(AppValidators.validateNewPassword('abcdefgh'), contains('número'));
      expect(AppValidators.validateNewPassword('abcdefg1'), isNull);
      expect(AppValidators.validateConfirmPassword('a', ''), isNotNull);
      expect(AppValidators.validateConfirmPassword('a', 'b'), isNotNull);
      expect(AppValidators.validateConfirmPassword('a', 'a'), isNull);
    });

    test('dirección y coordenadas', () {
      expect(AppValidators.validateAddress(''), isNotNull);
      expect(AppValidators.validateAddress('abc'), isNotNull);
      expect(AppValidators.validateAddress('Calle 5 de Mayo'), isNull);
      expect(AppValidators.validateCoordinates(latitude: 91, longitude: 0), isNotNull);
      expect(AppValidators.validateCoordinates(latitude: 0, longitude: 181), isNotNull);
      expect(AppValidators.validateCoordinates(latitude: 19.4, longitude: -99.1), isNull);
    });

    test('perfil del restaurante y campos requeridos', () {
      final e = AppValidators.validateRestaurantProfile(
          nombre: '', telefono: '123', direccion: 'x', correo: 'mal');
      expect(e.values.every((v) => v != null), isTrue);
      final ok = AppValidators.validateRestaurantProfile(
          nombre: 'Miel', telefono: '4181234567', direccion: 'Calle 5 de Mayo');
      expect(ok.values.every((v) => v == null), isTrue);
      expect(AppValidators.validateRequired(' ', 'el nombre'), contains('el nombre'));
      expect(AppValidators.validateRequired('x', 'el nombre'), isNull);
    });
  });
}
