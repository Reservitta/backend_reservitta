import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/reservation_contact_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/user_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/visitor_account_service.dart';
import 'package:reservitta/viewmodels/reservation_confirmation_viewmodel.dart';

/// Fake de AuthService para pruebas de creación de cuenta de visitante (HU14-RF02)
class FakeAuthServiceForHU14 extends AuthService {
  final Map<String, UserModel> registeredUsers = {};
  bool simulateNetworkError = false;
  int registerCalls = 0;

  @override
  Future<UserModel> registerVisitor({
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    registerCalls++;

    if (simulateNetworkError) {
      throw const SocketExceptionProxy('Error de red: timeout al conectar con Firebase Auth.');
    }

    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres.');
    }

    final cleanEmail = correo.trim().toLowerCase();
    if (registeredUsers.containsKey(cleanEmail)) {
      throw Exception('El correo electrónico ya se encuentra registrado.');
    }

    final uid = 'uid_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    final user = UserModel(
      uid: uid,
      rol: 'visitante',
      nombre: nombre.trim(),
      correo: cleanEmail,
      telefono: telefono.trim(),
      fechaAlta: DateTime.now(),
    );

    registeredUsers[cleanEmail] = user;
    return user;
  }
}

class SocketExceptionProxy implements Exception {
  final String message;
  const SocketExceptionProxy(this.message);
  @override
  String toString() => message;
}

/// Fake de repositorio de reservaciones para simular la confirmación / persistencia
class FakeReservationRepositoryForHU14 implements ReservationRepository {
  final List<ReservationModel> persistedReservations = [];

  @override
  Future<ReservationModel> createReservation(ReservationModel reservation) async {
    final withId = reservation.copyWith(id: 'res_${persistedReservations.length + 1}');
    persistedReservations.add(withId);
    return withId;
  }

  @override
  Future<ReservationModel> createReservationVerified(
    ReservationModel reservation, {
    int margenLimpiezaMin = 0,
  }) async {
    return createReservation(reservation);
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
  group('HU14-RF02: Creación de cuenta de visitante', () {
    late FakeAuthServiceForHU14 fakeAuth;
    late VisitorAccountService accountService;
    late FakeReservationRepositoryForHU14 fakeRepo;

    final dummyRestaurant = const RestaurantModel(
      id: 'rest_bistro_cdmx',
      nombre: 'Bistró Condesa',
      estado: 'activo',
    );

    late ReservationDraftModel draftConSolicitudCuenta;
    late ReservationDraftModel draftSinSolicitudCuenta;

    setUp(() {
      fakeAuth = FakeAuthServiceForHU14();
      accountService = VisitorAccountService(authService: fakeAuth);
      fakeRepo = FakeReservationRepositoryForHU14();

      draftConSolicitudCuenta = ReservationDraftModel(
        restaurant: dummyRestaurant,
        branch: const BranchModel(
          id: 'branch_1',
          nombre: 'Condesa Roma',
          direccion: 'Av. Michoacán 120',
          telefono: '5512345678',
        ),
        fecha: DateTime(2026, 11, 20),
        duracionMin: 90,
        personas: 3,
        mesaIds: const ['mesa_3'],
        mesasNombres: const ['Mesa Terraza 3'],
        contactData: const ReservationContactModel(
          nombre: 'Alejandro Morales',
          correo: 'alejandro.morales@correo.com',
          telefono: '5587654321',
          notas: 'Celebración de cumpleaños',
          solicitaCrearCuenta: true,
          password: 'Password123!',
        ),
      );

      draftSinSolicitudCuenta = ReservationDraftModel(
        restaurant: dummyRestaurant,
        branch: const BranchModel(
          id: 'branch_1',
          nombre: 'Condesa Roma',
          direccion: 'Av. Michoacán 120',
          telefono: '5512345678',
        ),
        fecha: DateTime(2026, 11, 20),
        duracionMin: 90,
        personas: 2,
        mesaIds: const ['mesa_1'],
        contactData: const ReservationContactModel(
          nombre: 'Comensal Invitado',
          correo: 'invitado@correo.com',
          telefono: '5511223344',
          solicitaCrearCuenta: false,
        ),
      );
    });

    group('Criterio 1: Si se solicitó, se crea un usuario en el proveedor de autenticación', () {
      test('Crea exitosamente el usuario con correo y contraseña en el proveedor de autenticación', () async {
        final result = await accountService.processVisitorAccount(draft: draftConSolicitudCuenta);

        expect(fakeAuth.registerCalls, 1);
        expect(result.cuentaCreada, isTrue);
        expect(result.continueWithoutAccount, isFalse);
        expect(result.usuarioId, isNotEmpty);
        expect(result.usuario?.correo, 'alejandro.morales@correo.com');
        expect(result.usuario?.rol, 'visitante');
        expect(result.hasError, isFalse);
      });

      test('Si NO se solicitó crear cuenta, no invoca al proveedor de autenticación y continúa como invitado', () async {
        final result = await accountService.processVisitorAccount(draft: draftSinSolicitudCuenta);

        expect(fakeAuth.registerCalls, 0);
        expect(result.cuentaCreada, isFalse);
        expect(result.continueWithoutAccount, isTrue);
        expect(result.usuarioId, isEmpty);
        expect(result.isGuestReservation, isTrue);
      });
    });

    group('Criterio 2: La cuenta se asocia a la reserva en curso', () {
      test('El usuarioId generado se asocia al borrador y al modelo final de la reservación', () async {
        final result = await accountService.processVisitorAccount(draft: draftConSolicitudCuenta);
        expect(result.cuentaCreada, isTrue);

        final draftAsociado = accountService.associateAccountToDraft(
          draft: draftConSolicitudCuenta,
          result: result,
        );

        expect(draftAsociado.hasAccountAssociated, isTrue);
        expect(draftAsociado.usuarioId, result.usuarioId);

        // Conversión a ReservationModel
        final reservationModel = draftAsociado.toReservationModel();
        expect(reservationModel.usuarioId, result.usuarioId);
        expect(reservationModel.contactoNombre, 'Alejandro Morales');
        expect(reservationModel.contactoCorreo, 'alejandro.morales@correo.com');
        expect(reservationModel.restauranteId, 'rest_bistro_cdmx');
      });
    });

    group('Criterio 3: Si falla la creación, la reserva continúa sin cuenta y se informa el motivo', () {
      test('Fallo por correo duplicado: continúa como invitado e informa el motivo', () async {
        // Registrar previamente el correo para forzar la colisión
        await fakeAuth.registerVisitor(
          nombre: 'Usuario Previo',
          correo: 'alejandro.morales@correo.com',
          telefono: '5500000000',
          password: 'Password123!',
        );
        fakeAuth.registerCalls = 0;

        // Intentar procesar la reserva con el mismo correo
        final result = await accountService.processVisitorAccount(draft: draftConSolicitudCuenta);

        // Verificaciones Criterio 3:
        expect(result.cuentaCreada, isFalse);
        expect(result.continueWithoutAccount, isTrue);
        expect(result.usuarioId, isEmpty);
        expect(result.hasError, isTrue);
        expect(result.motivoFallo, contains('ya se encuentra registrado'));
        expect(result.mensajeInformativo, contains('Tu reserva continuará sin cuenta'));

        // El borrador continúa sin cuenta (como invitado)
        final draftSinCuenta = accountService.associateAccountToDraft(
          draft: draftConSolicitudCuenta,
          result: result,
        );
        expect(draftSinCuenta.hasAccountAssociated, isFalse);
        expect(draftSinCuenta.usuarioId, isEmpty);
        expect(draftSinCuenta.contactoCorreo, 'alejandro.morales@correo.com');
      });

      test('Fallo por error de red o timeout: continúa como invitado e informa el motivo', () async {
        fakeAuth.simulateNetworkError = true;

        final result = await accountService.processVisitorAccount(draft: draftConSolicitudCuenta);

        // Verificaciones Criterio 3:
        expect(result.cuentaCreada, isFalse);
        expect(result.continueWithoutAccount, isTrue);
        expect(result.usuarioId, isEmpty);
        expect(result.hasError, isTrue);
        expect(result.motivoFallo, contains('error de red'));
        expect(result.mensajeInformativo, contains('Tu reserva continuará sin cuenta'));
      });

      test('Fallo por contraseña no válida: continúa como invitado e informa el motivo', () async {
        final draftPassInvalida = draftConSolicitudCuenta.copyWith(
          contactData: () => const ReservationContactModel(
            nombre: 'Carlos',
            correo: 'carlos@correo.com',
            telefono: '5512345678',
            solicitaCrearCuenta: true,
            password: '123', // Menor a 6 caracteres
          ),
        );

        final result = await accountService.processVisitorAccount(draft: draftPassInvalida);

        expect(result.cuentaCreada, isFalse);
        expect(result.continueWithoutAccount, isTrue);
        expect(result.motivoFallo, contains('longitud'));
      });
    });

    group('MVVM: ReservationConfirmationViewModel gestiona el flujo de cuenta y confirmación', () {
      test('Flujo exitoso con creación de cuenta persiste reserva con usuarioId asociado', () async {
        final viewModel = ReservationConfirmationViewModel(
          initialDraft: draftConSolicitudCuenta,
          visitorAccountService: accountService,
          reservationRepository: fakeRepo,
        );

        expect(viewModel.isProcessing, isFalse);
        expect(viewModel.hasAccountCreated, isFalse);

        final confirmed = await viewModel.confirmarReserva();

        expect(confirmed, isNotNull);
        expect(viewModel.hasAccountCreated, isTrue);
        expect(viewModel.hasAccountFallback, isFalse);
        expect(confirmed!.usuarioId, isNotEmpty);
        expect(confirmed.usuarioId, viewModel.draft.usuarioId);
        expect(fakeRepo.persistedReservations.length, 1);
        expect(fakeRepo.persistedReservations.first.usuarioId, confirmed.usuarioId);
      });

      test('Flujo con fallback por duplicidad persiste la reserva sin cuenta e informa el motivo', () async {
        // Pre-registrar para forzar duplicado
        await fakeAuth.registerVisitor(
          nombre: 'Otro Usuario',
          correo: 'alejandro.morales@correo.com',
          telefono: '5599999999',
          password: 'Password123!',
        );

        final viewModel = ReservationConfirmationViewModel(
          initialDraft: draftConSolicitudCuenta,
          visitorAccountService: accountService,
          reservationRepository: fakeRepo,
        );

        final confirmed = await viewModel.confirmarReserva();

        // La reserva NO se cancela, se crea con éxito como invitado
        expect(confirmed, isNotNull);
        expect(viewModel.hasAccountCreated, isFalse);
        expect(viewModel.hasAccountFallback, isTrue);
        expect(viewModel.accountNoticeMessage, contains('ya se encuentra registrado'));
        expect(confirmed!.usuarioId, isEmpty);
        expect(fakeRepo.persistedReservations.length, 1);
        expect(fakeRepo.persistedReservations.first.usuarioId, isEmpty);
      });

      test('Flujo sin solicitud de cuenta confirma directamente como invitado', () async {
        final viewModel = ReservationConfirmationViewModel(
          initialDraft: draftSinSolicitudCuenta,
          visitorAccountService: accountService,
          reservationRepository: fakeRepo,
        );

        final confirmed = await viewModel.confirmarReserva();

        expect(confirmed, isNotNull);
        expect(viewModel.hasAccountCreated, isFalse);
        expect(viewModel.hasAccountFallback, isFalse);
        expect(confirmed!.usuarioId, isEmpty);
        expect(fakeAuth.registerCalls, 0);
      });
    });
  });
}

