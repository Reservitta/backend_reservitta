import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController resetEmailController = TextEditingController();

  bool _isLoading = false;
  bool _isResetLoading = false;
  String? _errorMessage;
  String? _resetMessage;
  String? _resetErrorMessage;

  LoginViewModel({AuthService? authService})
    : _authService = authService ?? AuthService();

  bool get isLoading => _isLoading;
  bool get isResetLoading => _isResetLoading;
  String? get errorMessage => _errorMessage;
  String? get resetMessage => _resetMessage;
  String? get resetErrorMessage => _resetErrorMessage;

  /// Inicio de Sesión (HU22-RF03)
  Future<bool> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    final errors = AppValidators.validateLogin(
      email: email,
      password: password,
    );
    final validationError = errors.values.firstWhere(
      (error) => error != null,
      orElse: () => null,
    );
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
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

  /// Restablecimiento de contraseña (HU22-RF03: Olvidé mi contraseña)
  Future<bool> sendPasswordReset() async {
    final email = resetEmailController.text.trim();

    final emailError = AppValidators.validateEmail(email);
    if (emailError != null) {
      _resetErrorMessage = emailError;
      notifyListeners();
      return false;
    }

    _isResetLoading = true;
    _resetErrorMessage = null;
    _resetMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _resetMessage = 'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.';
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

  void clearResetStatus() {
    _resetMessage = null;
    _resetErrorMessage = null;
    resetEmailController.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    resetEmailController.dispose();
    super.dispose();
  }
}
