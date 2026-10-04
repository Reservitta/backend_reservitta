import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';

class RegisterAdminViewModel extends ChangeNotifier {
  final AuthService _authService;

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController nombreRestauranteController =
      TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  RegisterAdminViewModel({AuthService? authService})
    : _authService = authService ?? AuthService();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<bool> registerAdmin() async {
    final nombre = nombreController.text.trim();
    final correo = correoController.text.trim();
    final telefono = telefonoController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    final nombreRestaurante = nombreRestauranteController.text.trim();

    final validationErrors = AppValidators.validateRegistration(
      nombre: nombre,
      correo: correo,
      telefono: telefono,
      password: password,
      confirmPassword: confirmPassword,
      nombreRestaurante: nombreRestaurante,
    );
    final validationError = validationErrors.values.firstWhere(
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
    _successMessage = null;
    notifyListeners();

    try {
      await _authService.registerAdmin(
        nombre: nombre,
        correo: correo,
        telefono: telefono,
        password: password,
        nombreRestaurante: nombreRestaurante.isNotEmpty
            ? nombreRestaurante
            : null,
      );

      _successMessage =
          'Registro exitoso. Redirigiendo a configuración del restaurante...';
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

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    telefonoController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nombreRestauranteController.dispose();
    super.dispose();
  }
}
