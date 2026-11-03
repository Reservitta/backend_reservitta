import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/utils/validators.dart';

void main() {
  group('AppValidators.validateEmail', () {
    test('accepts valid email with standard domain', () {
      expect(AppValidators.validateEmail('contacto@casasabores.com'), isNull);
    });

    test('rejects malformed email and spaces', () {
      expect(AppValidators.validateEmail('person@example'), isNotNull);
      expect(AppValidators.validateEmail('person @example.com'), isNotNull);
    });
  });

  group('AppValidators.validatePhone (10 digits strictly)', () {
    test('accepts 10 digits clean phone', () {
      expect(AppValidators.validatePhone('5512345678'), isNull);
    });

    test('rejects letters, spaces and non-10 digit numbers', () {
      expect(AppValidators.validatePhone('55 1234 5678'), isNotNull);
      expect(AppValidators.validatePhone('5512345abc'), isNotNull);
      expect(AppValidators.validatePhone('1234567'), isNotNull);
      expect(AppValidators.validatePhone('551234567890'), isNotNull);
    });
  });

  test('validateConfirmPassword requires matching values', () {
    expect(
      AppValidators.validateConfirmPassword('secret1', 'secret2'),
      'Las contraseñas no coinciden.',
    );
    expect(AppValidators.validateConfirmPassword('secret1', 'secret1'), isNull);
  });

  test('registration validation keeps restaurant name optional', () {
    final errors = AppValidators.validateRegistration(
      nombre: 'Ana Pérez',
      correo: 'ana@example.com',
      telefono: '5512345678',
      password: 'secret1',
      confirmPassword: 'secret1',
      nombreRestaurante: '',
    );

    expect(errors.values.every((error) => error == null), isTrue);
  });

  group('HU23 Validators', () {
    test('validateRestaurantProfile validates mandatory fields (nombre, telefono, direccion)', () {
      final invalidErrors = AppValidators.validateRestaurantProfile(
        nombre: '',
        telefono: '',
        direccion: '',
      );
      expect(invalidErrors['nombre'], isNotNull);
      expect(invalidErrors['telefono'], isNotNull);
      expect(invalidErrors['direccion'], isNotNull);

      final validErrors = AppValidators.validateRestaurantProfile(
        nombre: 'Casa Sabores',
        telefono: '5512345678',
        direccion: 'Av. Reforma 123, Centro',
        correo: 'contacto@casasabores.com',
      );
      expect(validErrors.values.every((e) => e == null), isTrue);
    });

    test('validateScheduleHours checks that closing time is strictly after opening time', () {
      const opening = TimeOfDay(hour: 13, minute: 0);
      const earlierClosing = TimeOfDay(hour: 11, minute: 0);
      const equalClosing = TimeOfDay(hour: 13, minute: 0);
      const validClosing = TimeOfDay(hour: 22, minute: 0);

      expect(
        AppValidators.validateScheduleHours(
          apertura: opening,
          cierre: earlierClosing,
        ),
        'La hora de cierre debe ser posterior a la hora de apertura.',
      );

      expect(
        AppValidators.validateScheduleHours(
          apertura: opening,
          cierre: equalClosing,
        ),
        'La hora de cierre debe ser posterior a la hora de apertura.',
      );

      expect(
        AppValidators.validateScheduleHours(
          apertura: opening,
          cierre: validClosing,
        ),
        isNull,
      );
    });
  });

  group('HU13/HU14 validators', () {
    test('validatePhone respects configurable digits', () {
      expect(AppValidators.validatePhone('5512345678', digits: 10), isNull);
      expect(AppValidators.validatePhone('55123456', digits: 8), isNull);
      expect(AppValidators.validatePhone('5512345678', digits: 8), isNotNull);
    });

    test('validateNewPassword requires 8 chars, a letter and a number', () {
      expect(AppValidators.validateNewPassword(''), isNotNull);
      expect(AppValidators.validateNewPassword('abc123'), isNotNull); // < 8
      expect(AppValidators.validateNewPassword('12345678'), isNotNull); // sin letra
      expect(AppValidators.validateNewPassword('abcdefgh'), isNotNull); // sin número
      expect(AppValidators.validateNewPassword('abcd1234'), isNull);
    });

    test('validateNewPassword does not affect the login password rule', () {
      // El login conserva el mínimo de 6 caracteres.
      expect(AppValidators.validatePassword('abc123'), isNull);
    });
  });
}