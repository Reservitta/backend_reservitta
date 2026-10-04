import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/restaurant_model.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Retorna el perfil de usuario almacenado en Firestore (users/{uid})
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Retorna la información del restaurante asociado
  Future<RestaurantModel?> getRestaurantByRef(
    DocumentReference? restRef,
  ) async {
    if (restRef == null) return null;
    final doc = await restRef.get() as DocumentSnapshot<Map<String, dynamic>>;
    if (!doc.exists) return null;
    return RestaurantModel.fromFirestore(doc);
  }

  Future<UserCredential> _createAuthAccount({
    required String correo,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('El correo electrónico ya se encuentra registrado.');
        case 'invalid-email':
          throw Exception('El correo electrónico no es válido.');
        case 'weak-password':
          throw Exception('La contraseña debe tener al menos 6 caracteres.');
        default:
          throw Exception('[FirebaseAuth] ${e.code}: ${e.message}');
      }
    }
  }

  Future<void> _removeIncompleteAuthAccount(
    User user,
    Object registrationError,
  ) async {
    try {
      await user.delete();
    } catch (cleanupError) {
      throw Exception(
        'Firestore rechazó el registro en Reservitta: $registrationError. '
        'No se pudo eliminar la cuenta de acceso temporal: $cleanupError. '
        'No intentes registrarte de nuevo con este correo; contacta al soporte.',
      );
    }
    throw Exception(
      'El registro en Reservitta no se completó y la cuenta de acceso '
      'temporal fue eliminada. Error de Firestore: $registrationError',
    );
  }

  /// Registro de cuenta de Administrador de Restaurante (HU22-RF01 / HU22-RF02)
  Future<UserModel> registerAdmin({
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
    String? nombreRestaurante,
  }) async {
    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres.');
    }

    final userCredential = await _createAuthAccount(
      correo: correo,
      password: password,
    );
    final user = userCredential.user;
    if (user == null) {
      throw Exception('Firebase Authentication no devolvió la cuenta creada.');
    }

    final uid = user.uid;
    late final UserModel userModel;
    try {
      await user.getIdToken(true);

      final userRef = _firestore.collection('users').doc(uid);
      final restaurantRef = _firestore.collection('restaurants').doc();
      final restName =
          (nombreRestaurante != null && nombreRestaurante.trim().isNotEmpty)
          ? nombreRestaurante.trim()
          : 'Restaurante de ${nombre.trim()}';

      userModel = UserModel(
        uid: uid,
        rol: 'admin',
        nombre: nombre.trim(),
        correo: correo.trim(),
        telefono: telefono.trim(),
        restauranteId: restaurantRef,
        canalPreferido: 'email',
        fechaAlta: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(userRef, userModel.toMap());
      batch.set(restaurantRef, {
        'adminId': userRef,
        'nombre': restName,
        'estado': 'inactivo',
        'perfilCompleto': false,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      await _removeIncompleteAuthAccount(user, e);
    }

    return userModel;
  }

  /// Registro de cuenta de Cliente / Visitante
  Future<UserModel> registerVisitor({
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres.');
    }

    final userCredential = await _createAuthAccount(
      correo: correo,
      password: password,
    );
    final user = userCredential.user;
    if (user == null) {
      throw Exception('Firebase Authentication no devolvió la cuenta creada.');
    }

    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);
    final userModel = UserModel(
      uid: uid,
      rol: 'visitante',
      nombre: nombre.trim(),
      correo: correo.trim(),
      telefono: telefono.trim(),
      restauranteId: null,
      canalPreferido: 'email',
      fechaAlta: DateTime.now(),
    );

    try {
      await userRef.set(userModel.toMap());
    } catch (e) {
      await _removeIncompleteAuthAccount(user, e);
    }

    return userModel;
  }

  /// Inicio de sesión con correo y contraseña (HU22-RF03)
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException {
      throw Exception('Correo o contraseña incorrectos.');
    } catch (e) {
      throw Exception('Correo o contraseña incorrectos.');
    }
  }

  Future<UserModel> signInWithReservittaProfile({
    required String email,
    required String password,
  }) async {
    final credential = await signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw Exception('No se pudo identificar la cuenta autenticada.');
    }

    UserModel? profile;
    try {
      profile = await getUserProfile(user.uid);
    } catch (error) {
      try {
        await signOut();
      } catch (signOutError) {
        throw Exception(
          'No se pudo verificar el perfil de Reservitta: $error. '
          'Tampoco se pudo cerrar la sesión: $signOutError',
        );
      }
      throw Exception(
        'No se pudo verificar el perfil de Reservitta: '
        '${error.toString().replaceAll('Exception: ', '')}',
      );
    }

    if (profile == null) {
      await signOut();
      throw Exception(
        'Esta cuenta no tiene un perfil de Reservitta. '
        'Regístrate desde la aplicación o contacta al soporte.',
      );
    }

    if (profile.rol != 'admin' && profile.rol != 'visitante') {
      await signOut();
      throw Exception(
        'El perfil de esta cuenta no tiene un rol válido en Reservitta.',
      );
    }

    return profile;
  }

  /// Envío de correo de restablecimiento de contraseña (HU22-RF03)
  Future<void> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('Por favor ingresa un correo electrónico válido.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        throw Exception('El formato del correo electrónico no es válido.');
      }
      throw Exception(
        'Si el correo está registrado, recibirás las instrucciones de restablecimiento.',
      );
    } catch (e) {
      throw Exception(
        'Ocurrió un error al enviar el correo de restablecimiento.',
      );
    }
  }

  /// Cierre de sesión (HU22-RF04): Invalida la sesión actual del administrador
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
