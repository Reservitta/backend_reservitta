import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/user_model.dart';
import 'package:reservitta/services/auth_service.dart';

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  group('UserModel', () {
    test('toMap y fromFirestore van y vienen', () async {
      final ref = db.collection('restaurants').doc('r1');
      final u = UserModel(
        uid: 'u1',
        rol: 'admin',
        nombre: 'Ana',
        correo: 'ana@test.com',
        telefono: '4181234567',
        restauranteId: ref,
        fechaAlta: DateTime(2026, 10, 1),
      );
      await db.collection('users').doc('u1').set(u.toMap());
      final leido = UserModel.fromFirestore(await db.collection('users').doc('u1').get());
      expect(leido.uid, 'u1');
      expect(leido.rol, 'admin');
      expect(leido.restauranteId!.id, 'r1');
      expect(leido.fechaAlta, DateTime(2026, 10, 1));
      expect(leido.canalPreferido, 'email');
    });

    test('un perfil casi vacío se lee como visitante sin restaurante', () async {
      await db.collection('users').doc('x').set({});
      final u = UserModel.fromFirestore(await db.collection('users').doc('x').get());
      expect(u.rol, 'visitante');
      expect(u.nombre, '');
      expect(u.restauranteId, isNull);
      expect(u.fechaAlta, isNull);
    });
  });

  group('Registro de administrador (HU22)', () {
    late MockFirebaseAuth auth;
    late AuthService svc;

    setUp(() {
      auth = MockFirebaseAuth();
      svc = AuthService(auth: auth, firestore: db);
    });

    test('crea la cuenta, el perfil de admin y su restaurante inactivo', () async {
      final u = await svc.registerAdmin(
        nombre: 'Ana López',
        correo: ' ana@test.com ',
        telefono: '4181234567',
        password: 'secreto1',
        nombreRestaurante: 'Miel',
      );
      expect(u.rol, 'admin');
      expect(u.correo, 'ana@test.com');
      expect(auth.currentUser, isNotNull);

      final perfil = await db.collection('users').doc(u.uid).get();
      expect(perfil.data()!['rol'], 'admin');
      final rest = await u.restauranteId!.get();
      final d = rest.data() as Map<String, dynamic>;
      expect(d['nombre'], 'Miel');
      expect(d['estado'], 'inactivo');
      expect(d['perfilCompleto'], isFalse);
      expect(d['adminId'], isNotNull);
    });

    test('sin nombre de restaurante usa uno por defecto', () async {
      final u = await svc.registerAdmin(
          nombre: 'Ana', correo: 'a@test.com', telefono: '4181234567', password: 'secreto1');
      final rest = (await u.restauranteId!.get()).data() as Map<String, dynamic>;
      expect(rest['nombre'], 'Restaurante de Ana');
    });

    test('rechaza contraseñas cortas sin crear nada', () async {
      await expectLater(
        svc.registerAdmin(nombre: 'Ana', correo: 'a@test.com', telefono: '4181234567', password: '123'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('6 caracteres'))),
      );
      expect(auth.currentUser, isNull);
      expect((await db.collection('users').get()).docs, isEmpty);
    });

    test('si falla Firestore elimina la cuenta temporal y avisa', () async {
      final roto = AuthService(auth: auth, firestore: _FirestoreQueFalla(db));
      await expectLater(
        roto.registerAdmin(nombre: 'Ana', correo: 'a@test.com', telefono: '4181234567', password: 'secreto1'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('no se completó'))),
      );
    });
  });

  group('Registro de visitante', () {
    test('crea la cuenta y un perfil de visitante sin restaurante', () async {
      final auth = MockFirebaseAuth();
      final svc = AuthService(auth: auth, firestore: db);
      final u = await svc.registerVisitor(
          nombre: ' Luis ', correo: 'luis@test.com', telefono: '4181234567', password: 'secreto1');
      expect(u.rol, 'visitante');
      expect(u.nombre, 'Luis');
      expect(u.restauranteId, isNull);
      expect((await db.collection('users').doc(u.uid).get()).exists, isTrue);
    });

    test('rechaza contraseñas cortas', () async {
      final svc = AuthService(auth: MockFirebaseAuth(), firestore: db);
      await expectLater(
        svc.registerVisitor(nombre: 'Luis', correo: 'l@test.com', telefono: '4181234567', password: 'abc'),
        throwsException,
      );
    });

    test('desde una sesión anónima también crea el perfil de visitante', () async {
      final auth = MockFirebaseAuth();
      await auth.signInAnonymously();
      final svc = AuthService(auth: auth, firestore: db);
      final u = await svc.registerVisitor(
          nombre: 'Luis', correo: 'luis@test.com', telefono: '4181234567', password: 'secreto1');
      expect(u.rol, 'visitante');
      expect((await db.collection('users').doc(u.uid).get()).data()!['correo'], 'luis@test.com');
    });
  });

  group('Sesión anónima', () {
    test('crea un perfil "Invitado" de visitante en Firestore', () async {
      final auth = MockFirebaseAuth();
      final svc = AuthService(auth: auth, firestore: db);
      final a = await svc.signInAnonymously();
      expect(a.nombre, 'Invitado');
      expect(a.rol, 'visitante');
      expect(a.correo, '');
      expect((await db.collection('users').doc(a.uid).get()).exists, isTrue);
    });

    test('si el perfil ya existe lo reutiliza sin duplicarlo', () async {
      final auth = MockFirebaseAuth(signedIn: false, mockUser: MockUser(uid: 'anon1', isAnonymous: true));
      await db.collection('users').doc('anon1').set({'uid': 'anon1', 'rol': 'visitante', 'nombre': 'Marta'});
      final svc = AuthService(auth: auth, firestore: db);
      final p = await svc.signInAnonymously();
      expect(p.nombre, 'Marta');
      expect((await db.collection('users').get()).docs, hasLength(1));
    });

    test('si Firebase falla devuelve un perfil temporal para no bloquear al visitante', () async {
      final svc = AuthService(auth: _AuthConError(anonimo: true), firestore: db);
      final p = await svc.signInAnonymously();
      expect(p.uid, startsWith('anon_'));
      expect(p.rol, 'visitante');
    });
  });

  group('Inicio de sesión (HU22-RF03)', () {
    Future<AuthService> conCuenta({String? rol, bool conPerfil = true}) async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'ana@test.com'),
      );
      if (conPerfil) {
        await db.collection('users').doc('u1').set({
          'uid': 'u1',
          'rol': rol ?? 'visitante',
          'nombre': 'Ana',
          'correo': 'ana@test.com',
          'telefono': '4181234567',
        });
      }
      return AuthService(auth: auth, firestore: db);
    }

    test('devuelve el perfil de un visitante', () async {
      final svc = await conCuenta();
      final p = await svc.signInWithReservittaProfile(email: 'ana@test.com', password: 'secreto1');
      expect(p.uid, 'u1');
      expect(p.rol, 'visitante');
    });

    test('devuelve el perfil de un administrador', () async {
      final svc = await conCuenta(rol: 'admin');
      expect((await svc.signInWithReservittaProfile(email: 'ana@test.com', password: 'secreto1')).rol,
          'admin');
    });

    test('una cuenta sin perfil de Reservitta cierra la sesión y avisa', () async {
      final svc = await conCuenta(conPerfil: false);
      await expectLater(
        svc.signInWithReservittaProfile(email: 'ana@test.com', password: 'secreto1'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('perfil de Reservitta'))),
      );
      expect(svc.currentUser, isNull);
    });

    test('un rol inválido cierra la sesión y avisa', () async {
      final svc = await conCuenta(rol: 'superusuario');
      await expectLater(
        svc.signInWithReservittaProfile(email: 'ana@test.com', password: 'secreto1'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('rol válido'))),
      );
      expect(svc.currentUser, isNull);
    });

    test('credenciales incorrectas dan un mensaje claro', () async {
      final auth = _AuthConError(inicio: FirebaseAuthException(code: 'wrong-password'));
      final svc = AuthService(auth: auth, firestore: db);
      await expectLater(
        svc.signInWithEmailAndPassword(email: 'ana@test.com', password: 'mal'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('incorrectos'))),
      );
    });

    test('si falla la lectura del perfil cierra la sesión', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u1', email: 'ana@test.com'));
      final svc = AuthService(auth: auth, firestore: _FirestoreQueFalla(db));
      await expectLater(
        svc.signInWithReservittaProfile(email: 'ana@test.com', password: 'secreto1'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('No se pudo verificar'))),
      );
      expect(svc.currentUser, isNull);
    });
  });

  group('Restablecer contraseña y cerrar sesión', () {
    test('rechaza correos vacíos o sin arroba', () async {
      final svc = AuthService(auth: MockFirebaseAuth(), firestore: db);
      await expectLater(svc.sendPasswordResetEmail(''), throwsException);
      await expectLater(svc.sendPasswordResetEmail('sin-arroba'), throwsException);
    });

    test('un correo válido se envía sin errores', () async {
      final svc = AuthService(auth: MockFirebaseAuth(), firestore: db);
      await svc.sendPasswordResetEmail(' ana@test.com ');
    });

    test('un correo con formato inválido en Firebase da un mensaje específico', () async {
      final auth = _AuthConError(reset: FirebaseAuthException(code: 'invalid-email'));
      final svc = AuthService(auth: auth, firestore: db);
      await expectLater(
        svc.sendPasswordResetEmail('ana@test'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('formato'))),
      );
    });

    test('un correo no registrado no revela si existe', () async {
      final auth = _AuthConError(reset: FirebaseAuthException(code: 'user-not-found'));
      final svc = AuthService(auth: auth, firestore: db);
      await expectLater(
        svc.sendPasswordResetEmail('nadie@test.com'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'm', contains('Si el correo está registrado'))),
      );
    });

    test('cerrar sesión deja sin usuario', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
      final svc = AuthService(auth: auth, firestore: db);
      expect(svc.currentUser, isNotNull);
      await svc.signOut();
      expect(svc.currentUser, isNull);
    });
  });

  group('Consultas de perfil', () {
    test('getUserProfile devuelve null si no existe', () async {
      final svc = AuthService(auth: MockFirebaseAuth(), firestore: db);
      expect(await svc.getUserProfile('nadie'), isNull);
    });

    test('getRestaurantByRef sin referencia o inexistente devuelve null; con referencia, el restaurante', () async {
      final svc = AuthService(auth: MockFirebaseAuth(), firestore: db);
      expect(await svc.getRestaurantByRef(null), isNull);
      final ref = db.collection('restaurants').doc('r1');
      expect(await svc.getRestaurantByRef(ref), isNull);
      await ref.set({'nombre': 'Miel'});
      expect((await svc.getRestaurantByRef(ref))!.nombre, 'Miel');
    });
  });
}

/// Firestore que falla al escribir lotes y al leer perfiles de usuario.
class _FirestoreQueFalla extends FakeFirebaseFirestore {
  _FirestoreQueFalla(FakeFirebaseFirestore base);

  @override
  WriteBatch batch() => throw FirebaseException(plugin: 'firestore', code: 'permission-denied');

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (path == 'users') throw FirebaseException(plugin: 'firestore', code: 'unavailable');
    return super.collection(path);
  }
}

/// Auth de prueba que falla al iniciar sesión o al pedir el correo de restablecimiento.
class _AuthConError extends MockFirebaseAuth {
  final FirebaseAuthException? inicio;
  final FirebaseAuthException? reset;
  final bool anonimo;

  _AuthConError({this.inicio, this.reset, this.anonimo = false});

  @override
  Future<UserCredential> signInAnonymously() async {
    if (anonimo) throw FirebaseAuthException(code: 'network-request-failed');
    return super.signInAnonymously();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (inicio != null) throw inicio!;
    return super.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email, ActionCodeSettings? actionCodeSettings}) async {
    if (reset != null) throw reset!;
  }
}
