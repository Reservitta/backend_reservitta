import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation_contact_model.dart';
import '../models/reservation_draft_model.dart';
import '../utils/validators.dart';

/// Resultado detallado de la validación de datos de contacto (HU13-RF03)
class ContactValidationResult {
  final bool isValid;
  final Map<String, String?> fieldErrors;
  final String? generalError;
  final ReservationContactModel? validatedContact;

  const ContactValidationResult._({
    required this.isValid,
    this.fieldErrors = const {},
    this.generalError,
    this.validatedContact,
  });

  factory ContactValidationResult.success(ReservationContactModel contact) {
    return ContactValidationResult._(
      isValid: true,
      fieldErrors: const {},
      generalError: null,
      validatedContact: contact,
    );
  }

  factory ContactValidationResult.failure({
    required Map<String, String?> fieldErrors,
    String? generalError,
  }) {
    return ContactValidationResult._(
      isValid: false,
      fieldErrors: fieldErrors,
      generalError: generalError,
      validatedContact: null,
    );
  }

  bool get hasErrors => !isValid;
  String? get errorNombre => fieldErrors['nombre'];
  String? get errorCorreo => fieldErrors['correo'];
  String? get errorTelefono => fieldErrors['telefono'];
  String? get errorPassword => fieldErrors['password'];
}

/// Servicio para validación y gestión temporal en memoria de datos de contacto (HU13-RF03)
///
/// Criterios de aceptación:
/// 1. El backend valida formato de correo y teléfono antes de aceptar la solicitud.
/// 2. Los datos de contacto no se persisten en Firestore hasta confirmar la reserva (HU11-RF04).
/// 3. Si se solicitó crear cuenta, el correo se valida contra cuentas existentes para evitar duplicados.
class ContactValidationService {
  final FirebaseFirestore? _firestoreInstance;

  ContactValidationService({
    FirebaseFirestore? firestore,
  }) : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  /// Valida sintaxis y formato de datos de contacto (Criterio 1)
  Map<String, String?> validateFieldsFormat({
    required String nombre,
    required String correo,
    required String telefono,
    bool solicitaCrearCuenta = false,
    String? password,
  }) {
    final errors = <String, String?>{};

    final errorNombre = AppValidators.validateName(nombre);
    if (errorNombre != null) errors['nombre'] = errorNombre;

    final errorCorreo = AppValidators.validateEmail(correo);
    if (errorCorreo != null) errors['correo'] = errorCorreo;

    final errorTelefono = AppValidators.validatePhone(telefono);
    if (errorTelefono != null) errors['telefono'] = errorTelefono;

    if (solicitaCrearCuenta) {
      final errorPass = AppValidators.validatePassword(password ?? '');
      if (errorPass != null) {
        errors['password'] = errorPass;
      }
    }

    return errors;
  }

  /// Criterio 3: Si se solicitó crear cuenta, valida el correo contra cuentas existentes para evitar duplicados
  Future<String?> checkEmailAvailability(String correo) async {
    final cleanEmail = correo.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    try {
      // Verificar en Firestore colección 'users' por campo 'correo'
      final userSnap = await _firestore
          .collection('users')
          .where('correo', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        return 'El correo electrónico ya se encuentra registrado con una cuenta existente. Inicia sesión o utiliza otro correo.';
      }

      return null;
    } catch (e) {
      return 'Error al verificar disponibilidad del correo: $e';
    }
  }

  /// Valida de forma integral los datos de contacto y la unicidad si se solicita crear cuenta (Criterios 1 y 3)
  /// Nota: NO guarda nada en Firestore (Criterio 2).
  Future<ContactValidationResult> validateAndPrepareContact({
    required String nombre,
    required String correo,
    required String telefono,
    String notas = '',
    bool solicitaCrearCuenta = false,
    String? password,
  }) async {
    // 1. Validación de formato de campos (Criterio 1)
    final fieldErrors = validateFieldsFormat(
      nombre: nombre,
      correo: correo,
      telefono: telefono,
      solicitaCrearCuenta: solicitaCrearCuenta,
      password: password,
    );

    if (fieldErrors.isNotEmpty) {
      return ContactValidationResult.failure(fieldErrors: fieldErrors);
    }

    // 2. Validación de correo duplicado si se solicitó crear cuenta (Criterio 3)
    if (solicitaCrearCuenta) {
      final duplicateError = await checkEmailAvailability(correo);
      if (duplicateError != null) {
        fieldErrors['correo'] = duplicateError;
        return ContactValidationResult.failure(
          fieldErrors: fieldErrors,
          generalError: duplicateError,
        );
      }
    }

    // 3. Creación del modelo validado temporal en memoria (Criterio 2)
    final contact = ReservationContactModel(
      nombre: nombre.trim(),
      correo: correo.trim().toLowerCase(),
      telefono: telefono.trim(),
      notas: notas.trim(),
      solicitaCrearCuenta: solicitaCrearCuenta,
      password: solicitaCrearCuenta ? password : null,
    );

    return ContactValidationResult.success(contact);
  }

  /// Criterio 2: Asocia los datos de contacto al borrador de reservación en memoria sin tocar Firestore
  ReservationDraftModel attachContactToDraft({
    required ReservationDraftModel draft,
    required ReservationContactModel contact,
  }) {
    return draft.copyWith(
      contactData: () => contact,
    );
  }
}
