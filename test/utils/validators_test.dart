import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/utils/validators.dart';

void main() {
  group('AppValidators.validateEmail', () {
    test('accepts valid email with a long top-level domain', () {
      expect(AppValidators.validateEmail('person@example.restaurant'), isNull);
    });

    test('rejects malformed email', () {
      expect(AppValidators.validateEmail('person@example'), isNotNull);
    });
  });

  group('AppValidators.validatePhone', () {
    test('accepts international phone format', () {
      expect(AppValidators.validatePhone('+52 55-1234-5678'), isNull);
    });

    test('rejects values with fewer than eight digits', () {
      expect(AppValidators.validatePhone('--------'), isNotNull);
      expect(AppValidators.validatePhone('123-4567'), isNotNull);
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
      telefono: '+52 55-1234-5678',
      password: 'secret1',
      confirmPassword: 'secret1',
      nombreRestaurante: '',
    );

    expect(errors.values.every((error) => error == null), isTrue);
  });
}
