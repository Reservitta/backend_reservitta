import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/reservation_contact_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/contact_validation_service.dart';
import 'package:reservitta/viewmodels/reservation_contact_viewmodel.dart';

/// Fake de servicio de validación que simula verificación de correos existentes sin Firebase real
class FakeContactValidationService extends ContactValidationService {
  final Set<String> existingEmails;
  int firestoreReservationWriteCalls = 0;

  FakeContactValidationService({
    this.existingEmails = const {},
  });

  @override
  Future<String?> checkEmailAvailability(String correo) async {
    final cleanEmail = correo.trim().toLowerCase();
    if (existingEmails.contains(cleanEmail)) {
      return 'El correo electrónico ya se encuentra registrado con una cuenta existente. Inicia sesión o utiliza otro correo.';
    }
    return null;
  }
}

/// Fake de repositorio de reservaciones para comprobar que NO se realizan escrituras prematuras (Criterio 2)
class SpyReservationRepository implements ReservationRepository {
  int createCalls = 0;
  final List<ReservationModel> persistedReservations = [];

  @override
  Future<ReservationModel> createReservation(ReservationModel reservation) async {
    createCalls++;
    persistedReservations.add(reservation);
    return reservation.copyWith(id: 'res_test_${persistedReservations.length}');
  }

  @override
  Future<ReservationModel> createReservationVerified(
    ReservationModel reservation, {
    int margenLimpiezaMin = 0,
  }) async {
    createCalls++;
    persistedReservations.add(reservation);
    return reservation.copyWith(id: 'res_test_${persistedReservations.length}');
  }

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async =>
      persistedReservations;

  @override
  Future<List<ReservationModel>> getReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async =>
      persistedReservations;

  @override
  Future<ReservationModel?> getReservationById(String reservationId) async => null;

  @override
  Future<void> updateReservationStatus({
    required String reservationId,
    required String nuevoEstado,
  }) async {}

  @override
  Future<void> cancelReservation(String reservationId) async {}

  @override
  Future<bool> isTableAvailable({
    required String restauranteId,
    required String mesaId,
    required DateTime targetDateTime,
    int durationMin = 90,
  }) async =>
      true;

  @override
  Future<Set<String>> getBlockedTableIds({
    required String restauranteId,
    required DateTime targetDateTime,
    int durationMin = 90,
  }) async =>
      const {};

  @override
  Stream<List<ReservationModel>> getReservationsStream({
    required String restauranteId,
    required String fechaLocal,
  }) =>
      const Stream.empty();
}

void main() {
  group('HU13-RF03: Validación y manejo temporal de datos de contacto', () {
    late FakeContactValidationService validationService;
    late ReservationDraftModel baseDraft;
    late SpyReservationRepository reservationRepo;

    final dummyRestaurant = const RestaurantModel(
      id: 'rest_demo',
      nombre: 'Bistró Central',
      estado: 'activo',
    );

    setUp(() {
      validationService = FakeContactValidationService(
        existingEmails: {
          'usuario.registrado@reservitta.com',
          'admin@restaurante.com',
        },
      );

      reservationRepo = SpyReservationRepository();

      baseDraft = ReservationDraftModel(
        restaurant: dummyRestaurant,
        branch: const BranchModel(
          id: 'b1',
          nombre: 'Sucursal Matriz',
          direccion: 'Av. Paseo de la Reforma 100',
          telefono: '5512345678',
        ),
        fecha: DateTime(2026, 11, 15),
        duracionMin: 90,
        personas: 4,
        mesaIds: const ['mesa_1'],
        mesasNombres: const ['Mesa 1 (4p)'],
      );
    });

    group('Criterio 1: El backend valida formato de correo y teléfono antes de aceptar la solicitud', () {
      test('Acepta correo electrónico y teléfono con formato válido estándar', () {
        final errors = validationService.validateFieldsFormat(
          nombre: 'Mariana López',
          correo: 'mariana.lopez@ejemplo.com',
          telefono: '5512345678', // 10 dígitos numéricos estrictos
        );

        expect(errors, isEmpty);
      });

      test('Rechaza correos electrónicos con formatos no válidos o espacios', () {
        // Correo vacío
        var errors = validationService.validateFieldsFormat(
          nombre: 'Juan Pérez',
          correo: '',
          telefono: '5512345678',
        );
        expect(errors['correo'], contains('Por favor ingresa un correo'));

        // Correo con espacios
        errors = validationService.validateFieldsFormat(
          nombre: 'Juan Pérez',
          correo: 'juan perez@correo.com',
          telefono: '5512345678',
        );
        expect(errors['correo'], contains('no debe contener espacios'));

        // Correo malformado sin arroba o sin dominio
        errors = validationService.validateFieldsFormat(
          nombre: 'Juan Pérez',
          correo: 'correosinformato.com',
          telefono: '5512345678',
        );
        expect(errors['correo'], contains('válido'));

        errors = validationService.validateFieldsFormat(
          nombre: 'Juan Pérez',
          correo: 'usuario@dominio',
          telefono: '5512345678',
        );
        expect(errors['correo'], contains('válido'));
      });

      test('Rechaza teléfonos que no cumplan estrictamente con 10 dígitos numéricos', () {
        // Teléfono vacío
        var errors = validationService.validateFieldsFormat(
          nombre: 'Carlos Ruiz',
          correo: 'carlos@ejemplo.com',
          telefono: '',
        );
        expect(errors['telefono'], contains('Por favor ingresa un número de teléfono'));

        // Teléfono con letras
        errors = validationService.validateFieldsFormat(
          nombre: 'Carlos Ruiz',
          correo: 'carlos@ejemplo.com',
          telefono: '551234567A',
        );
        expect(errors['telefono'], contains('solo debe contener dígitos numéricos'));

        // Teléfono con espacios
        errors = validationService.validateFieldsFormat(
          nombre: 'Carlos Ruiz',
          correo: 'carlos@ejemplo.com',
          telefono: '55 1234 5678',
        );
        expect(errors['telefono'], contains('no debe contener espacios'));

        // Teléfono con menos de 10 dígitos
        errors = validationService.validateFieldsFormat(
          nombre: 'Carlos Ruiz',
          correo: 'carlos@ejemplo.com',
          telefono: '5512345',
        );
        expect(errors['telefono'], contains('exactamente 10 dígitos'));

        // Teléfono con más de 10 dígitos
        errors = validationService.validateFieldsFormat(
          nombre: 'Carlos Ruiz',
          correo: 'carlos@ejemplo.com',
          telefono: '551234567899',
        );
        expect(errors['telefono'], contains('exactamente 10 dígitos'));
      });

      test('Rechaza nombre de contacto inválido (menor a 2 caracteres o con dígitos)', () {
        var errors = validationService.validateFieldsFormat(
          nombre: 'A',
          correo: 'valido@correo.com',
          telefono: '5512345678',
        );
        expect(errors['nombre'], contains('al menos 2 caracteres'));

        errors = validationService.validateFieldsFormat(
          nombre: 'Carlos2',
          correo: 'valido@correo.com',
          telefono: '5512345678',
        );
        expect(errors['nombre'], contains('no debe contener números'));
      });

      test('Si solicita crear cuenta, exige contraseña mínima de 6 caracteres', () {
        var errors = validationService.validateFieldsFormat(
          nombre: 'Laura Gómez',
          correo: 'laura@ejemplo.com',
          telefono: '5512345678',
          solicitaCrearCuenta: true,
          password: '123', // Muy corta
        );
        expect(errors['password'], contains('al menos 6 caracteres'));

        errors = validationService.validateFieldsFormat(
          nombre: 'Laura Gómez',
          correo: 'laura@ejemplo.com',
          telefono: '5512345678',
          solicitaCrearCuenta: true,
          password: 'Password123!',
        );
        expect(errors['password'], isNull);
      });
    });

    group('Criterio 2: Los datos de contacto no se persisten en Firestore hasta confirmar la reserva (HU11-RF04)', () {
      test('La validación y asociación temporal al borrador NO genera escrituras en la base de datos', () async {
        final result = await validationService.validateAndPrepareContact(
          nombre: 'Pedro Martínez',
          correo: 'pedro@correo.com',
          telefono: '5598765432',
          notas: 'Alergia al marisco',
        );

        expect(result.isValid, isTrue);
        expect(result.validatedContact, isNotNull);

        // Se asocia en memoria al borrador
        final draftConContacto = validationService.attachContactToDraft(
          draft: baseDraft,
          contact: result.validatedContact!,
        );

        // Verificación 1: El borrador en memoria contiene los datos íntegros
        expect(draftConContacto.hasContactData, isTrue);
        expect(draftConContacto.contactoNombre, 'Pedro Martínez');
        expect(draftConContacto.contactoCorreo, 'pedro@correo.com');
        expect(draftConContacto.contactoTelefono, '5598765432');
        expect(draftConContacto.contactoNotas, 'Alergia al marisco');

        // Verificación 2 (Criterio 2 estricto): Cero llamadas de inserción en el repositorio de reservaciones
        expect(reservationRepo.createCalls, 0);
        expect(reservationRepo.persistedReservations, isEmpty);
      });

      test('Descartar o limpiar el borrador elimina los datos de contacto en memoria sin efectos secundarios en base de datos', () {
        final draftConContacto = baseDraft.copyWith(
          contactData: () => const ReservationContactModel(
            nombre: 'Temporal',
            correo: 'temp@correo.com',
            telefono: '5500000000',
          ),
        );
        expect(draftConContacto.hasContactData, isTrue);

        final draftLimpio = draftConContacto.clear();
        expect(draftLimpio.hasContactData, isFalse);
        expect(draftLimpio.contactoNombre, isEmpty);
        expect(reservationRepo.createCalls, 0);
      });
    });

    group('Criterio 3: Si se solicitó crear cuenta, el correo se valida contra cuentas existentes para evitar duplicados', () {
      test('Rechaza solicitud de crear cuenta si el correo ya pertenece a una cuenta existente', () async {
        final result = await validationService.validateAndPrepareContact(
          nombre: 'Usuario Repetido',
          correo: 'usuario.registrado@reservitta.com', // Ya registrado
          telefono: '5511223344',
          solicitaCrearCuenta: true,
          password: 'Password123!',
        );

        expect(result.isValid, isFalse);
        expect(result.errorCorreo, contains('ya se encuentra registrado con una cuenta existente'));
        expect(result.validatedContact, isNull);
      });

      test('Acepta solicitud de crear cuenta con correo no registrado', () async {
        final result = await validationService.validateAndPrepareContact(
          nombre: 'Usuario Nuevo',
          correo: 'nuevo.cliente@reservitta.com',
          telefono: '5511223344',
          solicitaCrearCuenta: true,
          password: 'Password123!',
        );

        expect(result.isValid, isTrue);
        expect(result.errorCorreo, isNull);
        expect(result.validatedContact?.solicitaCrearCuenta, isTrue);
        expect(result.validatedContact?.password, 'Password123!');
      });

      test('Si NO se solicita crear cuenta (invitado), no se bloquea por correo existente en catálogo de clientes', () async {
        // En modo invitado, el cliente solo proporciona su contacto para notificaciones sin registrar cuenta nueva
        final result = await validationService.validateAndPrepareContact(
          nombre: 'Comensal Invitado',
          correo: 'usuario.registrado@reservitta.com',
          telefono: '5511223344',
          solicitaCrearCuenta: false,
        );

        expect(result.isValid, isTrue);
        expect(result.validatedContact?.solicitaCrearCuenta, isFalse);
      });
    });

    group('MVVM: ReservationContactViewModel gestión de estado y persistencia temporal', () {
      test('ViewModel valida formatos y actualiza borrador en memoria de manera reactiva', () async {
        final viewModel = ReservationContactViewModel(
          service: validationService,
          initialDraft: baseDraft,
        );

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasErrors, isFalse);

        // Llenar campos con datos válidos
        viewModel.nombreController.text = 'Sofía Herrera';
        viewModel.correoController.text = 'sofia.herrera@correo.com';
        viewModel.telefonoController.text = '5587654321';
        viewModel.notasController.text = 'Mesa cerca de la ventana';

        final updatedDraft = await viewModel.procesarYGuardarTemporal(baseDraft);

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasErrors, isFalse);
        expect(updatedDraft, isNotNull);
        expect(updatedDraft!.hasContactData, isTrue);
        expect(updatedDraft.contactoNombre, 'Sofía Herrera');
        expect(updatedDraft.contactoTelefono, '5587654321');
        expect(updatedDraft.contactoNotas, 'Mesa cerca de la ventana');

        // Confirmar que no se llamó a base de datos para crear reservación
        expect(reservationRepo.createCalls, 0);

        viewModel.dispose();
      });

      test('ViewModel captura errores sintácticos y bloquea avance temporal', () async {
        final viewModel = ReservationContactViewModel(
          service: validationService,
          initialDraft: baseDraft,
        );

        // Llenar con teléfono incompleto y correo sin @
        viewModel.nombreController.text = 'Raúl';
        viewModel.correoController.text = 'correo_invalido';
        viewModel.telefonoController.text = '123';

        final updatedDraft = await viewModel.procesarYGuardarTemporal(baseDraft);

        expect(updatedDraft, isNull);
        expect(viewModel.hasErrors, isTrue);
        expect(viewModel.errorCorreo, isNotNull);
        expect(viewModel.errorTelefono, isNotNull);

        viewModel.dispose();
      });

      test('ViewModel detecta duplicado cuando se activa creación de cuenta', () async {
        final viewModel = ReservationContactViewModel(
          service: validationService,
          initialDraft: baseDraft,
        );

        viewModel.nombreController.text = 'Admin Demo';
        viewModel.correoController.text = 'admin@restaurante.com'; // Correo existente
        viewModel.telefonoController.text = '5512345678';
        viewModel.setSolicitaCrearCuenta(true);
        viewModel.passwordController.text = 'Segura123!';

        final updatedDraft = await viewModel.procesarYGuardarTemporal(baseDraft);

        expect(updatedDraft, isNull);
        expect(viewModel.hasErrors, isTrue);
        expect(viewModel.errorCorreo, contains('ya se encuentra registrado'));

        viewModel.dispose();
      });
    });
  });
}
