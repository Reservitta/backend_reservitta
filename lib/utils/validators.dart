import 'package:flutter/material.dart';

class AppValidators {
  /// RegEx estándar para validación estricta de correo electrónico
  static final RegExp _emailRegExp = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,}$');

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

  /// Validación de formulario de perfil de restaurante (HU23)
  static Map<String, String?> validateRestaurantProfile({
    required String nombre,
    required String telefono,
    required String direccion,
    String? correo,
  }) {
    final errors = <String, String?>{
      'nombre': validateRestaurantName(nombre, isRequired: true),
      'telefono': validatePhone(telefono),
      'direccion': validateAddress(direccion),
    };

    if (correo != null && correo.trim().isNotEmpty) {
      errors['correo'] = validateEmail(correo);
    }

    return errors;
  }

  /// Valida Dirección del Restaurante
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa la dirección del restaurante.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 5) {
      return 'La dirección debe tener al menos 5 caracteres.';
    }
    return null;
  }

  /// Valida Coordenadas Geográficas (Latitud y Longitud)
  static String? validateCoordinates({
    required double latitude,
    required double longitude,
  }) {
    if (latitude < -90.0 || latitude > 90.0) {
      return 'La latitud debe estar entre -90.0 y 90.0 grados.';
    }
    if (longitude < -180.0 || longitude > 180.0) {
      return 'La longitud debe estar entre -180.0 y 180.0 grados.';
    }
    return null;
  }

  /// Valida que la hora de cierre sea posterior a la de apertura (HU23-RF03 / RF04)
  static String? validateScheduleHours({
    required TimeOfDay apertura,
    required TimeOfDay cierre,
  }) {
    final aperturaMinutes = apertura.hour * 60 + apertura.minute;
    final cierreMinutes = cierre.hour * 60 + cierre.minute;

    if (cierreMinutes <= aperturaMinutes) {
      return 'La hora de cierre debe ser posterior a la hora de apertura.';
    }
    return null;
  }

  /// Valida Nombre Completo
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa tu nombre completo.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }
    if (RegExp(r'[0-9]').hasMatch(trimmed)) {
      return 'El nombre no debe contener números.';
    }
    return null;
  }

  /// Valida Correo Electrónico
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa un correo electrónico.';
    }
    final trimmed = value.trim();
    if (trimmed.contains(' ')) {
      return 'El correo no debe contener espacios.';
    }
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Ingresa un correo electrónico válido (ej. contacto@restaurante.com).';
    }
    return null;
  }

  /// Valida teléfono: solo dígitos, sin espacios, exactamente [digits]
  /// (10 por defecto, configurable, HU13-RF01).
  static String? validatePhone(String? value, {int digits = 10}) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa un número de teléfono.';
    }
    final cleanPhone = value.trim();
    if (cleanPhone.contains(' ')) {
      return 'El teléfono no debe contener espacios.';
    }
    if (RegExp(r'[^\d]').hasMatch(cleanPhone)) {
      return 'El teléfono solo debe contener dígitos numéricos, sin letras ni símbolos.';
    }
    if (cleanPhone.length != digits) {
      return 'El teléfono debe tener exactamente $digits dígitos (tienes ${cleanPhone.length}).';
    }
    return null;
  }

  /// Valida Contraseña según política mínima de inicio de sesión (mínimo 6 caracteres)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña.';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return null;
  }

  /// Contraseña para cuentas nuevas: mínimo 8 caracteres, al menos una letra
  /// y un número (HU14-RF01).
  static String? validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa una contraseña.';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'La contraseña debe incluir al menos una letra.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'La contraseña debe incluir al menos un número.';
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
    if (value != null && value.trim().isNotEmpty) {
      final trimmed = value.trim();
      if (trimmed.length < 2) {
        return 'El nombre del restaurante debe tener al menos 2 caracteres.';
      }
    }
    return null;
  }

  /// Valida Nombre de Categoría
  static String? validateCategoryName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa el nombre de la categoría.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'El nombre de la categoría debe tener al menos 2 caracteres.';
    }
    return null;
  }

  /// Valida Nombre de Platillo
  static String? validateDishName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa el nombre del platillo.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'El nombre del platillo debe tener al menos 2 caracteres.';
    }
    return null;
  }

  /// Valida que el precio sea numérico y mayor a cero
  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa el precio del platillo.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Ingresa un precio numérico válido (ej. 120.50).';
    }
    if (parsed <= 0) {
      return 'El precio debe ser mayor a cero.';
    }
    return null;
  }

  /// Valida campo opcional de personalización del cliente (HU24-RF05 Criterio 4)
  static String? validateCustomization(String? value, {int maxCharacters = 150}) {
    if (value == null || value.trim().isEmpty) {
      return null; // Es opcional
    }
    if (value.trim().length > maxCharacters) {
      return 'Las modificaciones no pueden exceder los $maxCharacters caracteres.';
    }
    return null;
  }

  /// Valida el texto de ejemplo / ayuda (placeholder) definido por el admin (HU24-RF05 Criterio 2)
  static String? validatePlaceholder(String? value, {int maxCharacters = 80}) {
    if (value == null || value.trim().isEmpty) {
      return null; // Es opcional
    }
    if (value.trim().length > maxCharacters) {
      return 'El texto de ejemplo no puede exceder los $maxCharacters caracteres.';
    }
    return null;
  }
}