class AppValidators {
  /// RegEx estándar para validación estricta de correo electrónico
  static final RegExp _emailRegExp = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,}$');

  /// RegEx para números de teléfono (admite formato internacional con +, espacios, guiones)
  static final RegExp _phoneRegExp = RegExp(r'^\+?[0-9\s\-]{8,18}$');

  /// Valida campo obligatorio genérico
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa $fieldName.';
    }
    return null;
  }

  static Map<String, String?> validateLogin({
    required String email,
    required String password,
  }) {
    return {
      'loginEmail': validateEmail(email),
      'loginPassword': validatePassword(password),
    };
  }

  static Map<String, String?> validateRegistration({
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
    required String confirmPassword,
    String? nombreRestaurante,
  }) {
    final errors = <String, String?>{
      'nombre': validateName(nombre),
      'correo': validateEmail(correo),
      'telefono': validatePhone(telefono),
      'password': validatePassword(password),
      'confirmPassword': validateConfirmPassword(password, confirmPassword),
    };

    if (nombreRestaurante != null) {
      errors['restaurante'] = validateRestaurantName(nombreRestaurante);
    }

    return errors;
  }

  /// Valida Nombre Completo
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa tu nombre completo.';
    }
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }
    return null;
  }

  /// Valida Correo Electrónico
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa un correo electrónico.';
    }
    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Por favor ingresa un correo electrónico válido (ej. usuario@dominio.com).';
    }
    return null;
  }

  /// Valida Número de Teléfono
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa un número de teléfono.';
    }
    final cleanPhone = value.trim();
    final digitCount = cleanPhone.replaceAll(RegExp(r'\D'), '').length;
    if (!_phoneRegExp.hasMatch(cleanPhone) || digitCount < 8) {
      return 'Por favor ingresa un número de teléfono válido (mínimo 8 dígitos).';
    }
    return null;
  }

  /// Valida Contraseña según política mínima (mínimo 6 caracteres)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña.';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return null;
  }

  /// Valida coincidencia de confirmación de contraseña
  static String? validateConfirmPassword(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Por favor confirma tu contraseña.';
    }
    if (password != confirmPassword) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  /// Valida Nombre de Restaurante
  static String? validateRestaurantName(
    String? value, {
    bool isRequired = false,
  }) {
    if (isRequired && (value == null || value.trim().isEmpty)) {
      return 'Por favor ingresa el nombre de tu restaurante.';
    }
    if (value != null && value.trim().isNotEmpty && value.trim().length < 3) {
      return 'El nombre del restaurante debe tener al menos 3 caracteres.';
    }
    return null;
  }
}
