import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';

enum AuthMode {
  login,
  registerRoleSelection, // Paso 0: ¿Cómo quieres asociarte a nosotros?
  registerForm, // Paso 1: Formulario según el rol seleccionado
  forgotPassword,
}

class AuthModalViewModel extends ChangeNotifier {
  final AuthService _authService;

  AuthMode _currentMode;
  String _selectedRole =
      'visitante'; // 'visitante' (Cliente) o 'admin' (Restaurante)

  // Controladores de Login y Reset
  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();
  final TextEditingController resetEmailController = TextEditingController();

  // Controladores de Registro
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController nombreRestauranteController =
      TextEditingController();

  /// Mapa de errores por campo — se actualizan en tiempo real tras el primer intento de envío
  final Map<String, String?> fieldErrors = {};

  /// Flags que indican si el usuario ya intentó enviar el formulario
  bool _registerSubmitted = false;
  bool _loginSubmitted = false;

  bool _isLoading = false;
  bool _isResetLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _resetMessage;
  String? _resetErrorMessage;

  AuthModalViewModel({
    AuthService? authService,
    AuthMode initialMode = AuthMode.login,
  }) : _authService = authService ?? AuthService(),
       _currentMode = initialMode {
    _attachListeners();
  }

  AuthMode get currentMode => _currentMode;
  String get selectedRole => _selectedRole;
  bool get isLoading => _isLoading;
  bool get isResetLoading => _isResetLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get resetMessage => _resetMessage;
  String? get resetErrorMessage => _resetErrorMessage;

  // ──────────────────────────────────────────────
  // Listeners de validación en tiempo real
  // ──────────────────────────────────────────────

  void _attachListeners() {
    // Login — solo valida después del primer intento
    loginEmailController.addListener(() {
      if (_loginSubmitted) {
        fieldErrors['loginEmail'] = AppValidators.validateEmail(
          loginEmailController.text.trim(),
        );
        notifyListeners();
      }
    });
    loginPasswordController.addListener(() {
      if (_loginSubmitted) {
        fieldErrors['loginPassword'] = AppValidators.validatePassword(
          loginPasswordController.text,
        );
        notifyListeners();
      }
    });

    // Registro — solo valida después del primer intento
    nombreController.addListener(() {
      if (_registerSubmitted) {
        fieldErrors['nombre'] = AppValidators.validateName(
          nombreController.text.trim(),
        );
        notifyListeners();
      }
    });
    correoController.addListener(() {
      if (_registerSubmitted) {
        fieldErrors['correo'] = AppValidators.validateEmail(
          correoController.text.trim(),
        );
        notifyListeners();
      }
    });
    telefonoController.addListener(() {
      if (_registerSubmitted) {
        fieldErrors['telefono'] = AppValidators.validatePhone(
          telefonoController.text.trim(),
        );
        notifyListeners();
      }
    });
    registerPasswordController.addListener(() {
      if (_registerSubmitted) {
        fieldErrors['password'] = AppValidators.validatePassword(
          registerPasswordController.text,
        );
        // Re-validar confirmación cuando la contraseña cambia
        fieldErrors['confirmPassword'] = AppValidators.validateConfirmPassword(
          registerPasswordController.text,
          confirmPasswordController.text,
        );
        notifyListeners();
      }
    });
    confirmPasswordController.addListener(() {
      if (_registerSubmitted) {
        fieldErrors['confirmPassword'] = AppValidators.validateConfirmPassword(
          registerPasswordController.text,
          confirmPasswordController.text,
        );
        notifyListeners();
      }
    });
    nombreRestauranteController.addListener(() {
      if (_registerSubmitted && _selectedRole == 'admin') {
        fieldErrors['restaurante'] = AppValidators.validateRestaurantName(
          nombreRestauranteController.text.trim(),
        );
        notifyListeners();
      }
    });

    // Reset
    resetEmailController.addListener(() {
      if (_resetErrorMessage != null) {
        _resetErrorMessage = AppValidators.validateEmail(
          resetEmailController.text.trim(),
        );
        notifyListeners();
      }
    });
  }

  // ──────────────────────────────────────────────
  // Navegación entre modos
  // ──────────────────────────────────────────────

  void setMode(AuthMode mode) {
    _currentMode = mode;
    _errorMessage = null;
    _successMessage = null;
    _resetMessage = null;
    _resetErrorMessage = null;
    _loginSubmitted = false;
    _registerSubmitted = false;
    fieldErrors.clear();
    notifyListeners();
  }

  void setSelectedRole(String role) {
    _selectedRole = role;
    if (role == 'admin' && _registerSubmitted) {
      fieldErrors['restaurante'] = AppValidators.validateRestaurantName(
        nombreRestauranteController.text.trim(),
      );
    } else {
      fieldErrors.remove('restaurante');
    }
    notifyListeners();
  }

  void goToRegisterForm() {
    _currentMode = AuthMode.registerForm;
    _errorMessage = null;
    _registerSubmitted = false;
    fieldErrors.clear();
    notifyListeners();
  }

  void backToRoleSelection() {
    _currentMode = AuthMode.registerRoleSelection;
    _errorMessage = null;
    _registerSubmitted = false;
    fieldErrors.clear();
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // Acción de Inicio de Sesión
  // ──────────────────────────────────────────────

  Future<bool> login() async {
    _loginSubmitted = true;
    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text;

    fieldErrors.addAll(
      AppValidators.validateLogin(email: email, password: password),
    );
    notifyListeners();

    if (fieldErrors['loginEmail'] != null ||
        fieldErrors['loginPassword'] != null) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithReservittaProfile(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // Acción de Registro
  // ──────────────────────────────────────────────

  Future<bool> register() async {
    _registerSubmitted = true;
    final nombre = nombreController.text.trim();
    final correo = correoController.text.trim();
    final telefono = telefonoController.text.trim();
    final password = registerPasswordController.text;
    final confirmPassword = confirmPasswordController.text;
    final nombreRestaurante = nombreRestauranteController.text.trim();

    fieldErrors.clear();
    fieldErrors.addAll(
      AppValidators.validateRegistration(
        nombre: nombre,
        correo: correo,
        telefono: telefono,
        password: password,
        confirmPassword: confirmPassword,
        nombreRestaurante: _selectedRole == 'admin' ? nombreRestaurante : null,
      ),
    );
    notifyListeners();

    if (fieldErrors.values.any((e) => e != null)) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (_selectedRole == 'admin') {
        await _authService.registerAdmin(
          nombre: nombre,
          correo: correo,
          telefono: telefono,
          password: password,
          nombreRestaurante: nombreRestaurante.isNotEmpty
              ? nombreRestaurante
              : null,
        );
      } else {
        await _authService.registerVisitor(
          nombre: nombre,
          correo: correo,
          telefono: telefono,
          password: password,
        );
      }

      _successMessage = 'Registro exitoso.';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // Acción de Olvidé mi contraseña
  // ──────────────────────────────────────────────

  Future<bool> sendPasswordReset() async {
    final email = resetEmailController.text.trim();

    final emailErr = AppValidators.validateEmail(email);
    if (emailErr != null) {
      _resetErrorMessage = emailErr;
      notifyListeners();
      return false;
    }

    _isResetLoading = true;
    _resetErrorMessage = null;
    _resetMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _resetMessage = 'Si el correo está registrado, recibirás un enlace de restablecimiento.';
      _isResetLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _resetErrorMessage = e.toString().replaceAll('Exception: ', '');
      _isResetLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    resetEmailController.dispose();
    nombreController.dispose();
    correoController.dispose();
    telefonoController.dispose();
    registerPasswordController.dispose();
    confirmPasswordController.dispose();
    nombreRestauranteController.dispose();
    super.dispose();
  }
}
