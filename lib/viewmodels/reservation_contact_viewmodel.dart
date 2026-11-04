import 'package:flutter/material.dart';
import '../models/reservation_contact_model.dart';
import '../models/reservation_draft_model.dart';
import '../services/contact_validation_service.dart';

/// ViewModel para la captura, validación y manejo temporal de datos de contacto (HU13-RF03)
///
/// Gestiona el formulario, estados reactivos de error y validaciones sin persistir en Firestore
/// hasta que el usuario confirme la reserva (HU11-RF04).
class ReservationContactViewModel extends ChangeNotifier {
  final ContactValidationService _service;

  // Controladores de texto para el formulario
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController notasController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _solicitaCrearCuenta = false;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String?> _fieldErrors = {};
  ReservationContactModel? _validatedContact;

  ReservationContactViewModel({
    ContactValidationService? service,
    ReservationDraftModel? initialDraft,
  }) : _service = service ?? ContactValidationService() {
    if (initialDraft != null) {
      prepopulateFromDraft(initialDraft);
    }
  }

  // Getters
  bool get solicitaCrearCuenta => _solicitaCrearCuenta;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, String?> get fieldErrors => Map.unmodifiable(_fieldErrors);
  ReservationContactModel? get validatedContact => _validatedContact;
  bool get hasErrors => _fieldErrors.values.any((e) => e != null) || _errorMessage != null;

  String? get errorNombre => _fieldErrors['nombre'];
  String? get errorCorreo => _fieldErrors['correo'];
  String? get errorTelefono => _fieldErrors['telefono'];
  String? get errorPassword => _fieldErrors['password'];

  /// Alterna la solicitud de creación de cuenta
  void setSolicitaCrearCuenta(bool value) {
    if (_solicitaCrearCuenta == value) return;
    _solicitaCrearCuenta = value;
    if (!value) {
      passwordController.clear();
      _fieldErrors.remove('password');
    }
    notifyListeners();
  }

  /// Precarga datos en los campos si ya existían en el borrador en memoria
  void prepopulateFromDraft(ReservationDraftModel draft) {
    final contact = draft.contactData;
    if (contact != null) {
      nombreController.text = contact.nombre;
      correoController.text = contact.correo;
      telefonoController.text = contact.telefono;
      notasController.text = contact.notas;
      _solicitaCrearCuenta = contact.solicitaCrearCuenta;
      if (contact.password != null) {
        passwordController.text = contact.password!;
      }
      _validatedContact = contact;
    }
  }

  /// Limpia los errores de validación
  void clearErrors() {
    _fieldErrors = {};
    _errorMessage = null;
    notifyListeners();
  }

  /// Valida en tiempo real y guarda temporalmente en memoria en el borrador (Criterios 1, 2 y 3).
  ///
  /// Retorna el [ReservationDraftModel] actualizado en memoria si la validación es exitosa,
  /// o `null` si hay errores de formato o correo duplicado.
  Future<ReservationDraftModel?> procesarYGuardarTemporal(
    ReservationDraftModel draft,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      final result = await _service.validateAndPrepareContact(
        nombre: nombreController.text,
        correo: correoController.text,
        telefono: telefonoController.text,
        notas: notasController.text,
        solicitaCrearCuenta: _solicitaCrearCuenta,
        password: passwordController.text,
      );

      if (result.isValid && result.validatedContact != null) {
        _validatedContact = result.validatedContact;
        _fieldErrors = {};
        _errorMessage = null;

        // Criterio 2: Se adjunta al borrador en memoria sin interactuar con Firestore
        final updatedDraft = _service.attachContactToDraft(
          draft: draft,
          contact: result.validatedContact!,
        );

        return updatedDraft;
      } else {
        _fieldErrors = Map.from(result.fieldErrors);
        _errorMessage = result.generalError ??
            'Por favor corrige los campos señalados antes de continuar.';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error inesperado al validar datos de contacto: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    telefonoController.dispose();
    notasController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

