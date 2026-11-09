import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/reservation_contact_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/user_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/confirmation_notification_service.dart';
import 'package:reservitta/services/notification_clients.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/services/visitor_account_service.dart';
import 'package:reservitta/viewmodels/reservation_confirmation_viewmodel.dart';

/// Fake para TransactionalEmailClient con control de llamadas y fallos
class FakeTransactionalEmailClient implements TransactionalEmailClient {
  int sendCalls = 0;
  bool shouldFail = false;
  String? lastRecipient;
  String? lastSubject;
  String? lastBody;

  @override
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    sendCalls++;
    lastRecipient = to;
    lastSubject = subject;
    lastBody = body;
    if (shouldFail) {
      throw Exception('Simulated SMTP transport error.');
    }
    return true;
  }
}

/// Fake para WhatsAppBusinessApiClient con control de llamadas y fallos
class FakeWhatsAppBusinessApiClient implements WhatsAppBusinessApiClient {
  int sendCalls = 0;
  bool shouldFail = false;
  String? lastPhone;
  String? lastMessage;

  @override
  Future<bool> sendWhatsAppMessage({
    required String toPhone,
    required String message,
  }) async {
    sendCalls++;
    lastPhone = toPhone;
    lastMessage = message;
    if (shouldFail) {
      throw Exception('Simulated WhatsApp API 500 error.');
    }
    return true;
  }
}

/// Fake para AuthService en registro de visitantes
class FakeAuthServiceForHU19 extends AuthService {
  final Map<String, UserModel> users = {};
  int registerCalls = 0;

  @override
  Future<UserModel> registerVisitor({
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    registerCalls++;
    final uid = 'uid_${correo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    final user = UserModel(
      uid: uid,
      rol: 'visitante',
      nombre: nombre.trim(),
      correo: correo.trim().toLowerCase(),
      telefono: telefono.trim(),
      fechaAlta: DateTime.now(),
    );
    users[user.correo] = user;
    return user;
  }
}

/// Fake de repositorio de reservaciones
class FakeReservationRepositoryForHU19 implements ReservationRepository {
  // HU27/HU28: métodos del repositorio que esta prueba no usa.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
  Future<ReservationModel?> getReservationById(String reservationId) async =>
      persistedReservations.cast<ReservationModel?>().firstWhere(
            (r) => r?.id == reservationId,
            orElse: () => null,
          );

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

/// Fake AvailabilityService que siempre valida como válida la selección
class FakeAvailabilityServiceAlwaysValid extends AvailabilityService {
  FakeAvailabilityServiceAlwaysValid(super.reservations);

  @override
  Future<SelectionValidation> revalidateSelection({
    required RestaurantModel restaurant,
    required DateTime inicio,
    required int duracionMin,
    required List<String> mesaIds,
    int maxAlternativas = 5,
    String? ignorarReservaId,
  }) async {
    return const SelectionValidation.valid();
  }
}

void main() {
  group('HU19-RF01: Disparo de confirmación al crear la reserva', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeTransactionalEmailClient fakeEmailClient;
    late FakeWhatsAppBusinessApiClient fakeWhatsAppClient;
    late ConfirmationNotificationService notificationService;
    late FakeAuthServiceForHU19 fakeAuthService;
    late VisitorAccountService visitorAccountService;
    late FakeReservationRepositoryForHU19 reservationRepo;

    final restaurant = RestaurantModel(
      id: 'rest_italia',
      nombre: 'Trattoria Bella',
      estado: 'activo',
    );

    const branch = BranchModel(
      id: 'branch_roma',
      nombre: 'Roma Norte',
      direccion: 'Colima 123, Roma Norte',
      telefono: '5512345678',
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeEmailClient = FakeTransactionalEmailClient();
      fakeWhatsAppClient = FakeWhatsAppBusinessApiClient();
      notificationService = ConfirmationNotificationService(
        emailClient: fakeEmailClient,
        whatsAppClient: fakeWhatsAppClient,
        firestore: fakeFirestore,
      );
      fakeAuthService = FakeAuthServiceForHU19();
      visitorAccountService = VisitorAccountService(authService: fakeAuthService);
      reservationRepo = FakeReservationRepositoryForHU19();
    });

    // =========================================================================
    // CRITERIO 1: Disparo automático al confirmarse la reserva
    // =========================================================================
    test('Dispara automáticamente el envío de confirmación usando HU14-RF03 al confirmar', () async {
      final draft = ReservationDraftModel(
        restaurant: restaurant,
        branch: branch,
        fecha: DateTime(2026, 12, 15),
        duracionMin: 90,
        personas: 2,
        mesaIds: const ['mesa_1'],
        mesasNombres: const ['Mesa Ventana'],
        horario: const TimeOfDay(hour: 20, minute: 0),
        contactData: const ReservationContactModel(
          nombre: 'Andrés Morales',
          correo: 'andres@example.com',
          telefono: '3311223344',
          canalPreferido: 'email',
        ),
      );

      final viewModel = ReservationConfirmationViewModel(
        initialDraft: draft,
        visitorAccountService: visitorAccountService,
        notificationService: notificationService,
        reservationRepository: reservationRepo,
      );

      final confirmed = await viewModel.confirmarReserva();

      expect(confirmed, isNotNull);
      expect(confirmed!.estado, ReservationModel.estadoConfirmada);
      expect(viewModel.isReservationConfirmed, isTrue);

      // Criterio 1: Se disparó el envío automáticamente
      expect(fakeEmailClient.sendCalls, 1);
      expect(fakeEmailClient.lastRecipient, 'andres@example.com');
      expect(fakeEmailClient.lastSubject, contains('Reserva confirmada en Trattoria Bella'));
      expect(viewModel.notificationResult, isNotNull);
      expect(viewModel.notificationResult!.exitoso, isTrue);
      expect(viewModel.notificationNoticeMessage, contains('correo electrónico'));
    });

    // =========================================================================
    // CRITERIO 2: Canal (correo o WhatsApp) según preferencia de HU13 y disponibilidad
    // =========================================================================
    test('Envía por WhatsApp si el usuario lo indicó como preferencia en HU13 y tiene teléfono', () async {
      final draft = ReservationDraftModel(
        restaurant: restaurant,
        branch: branch,
        fecha: DateTime(2026, 12, 15),
        duracionMin: 120,
        personas: 4,
        mesaIds: const ['mesa_2'],
        mesasNombres: const ['Terraza 4'],
        horario: const TimeOfDay(hour: 15, minute: 30),
        contactData: const ReservationContactModel(
          nombre: 'Mariana Gómez',
          correo: 'mariana@example.com',
          telefono: '+52 (33) 9876-5432',
          canalPreferido: 'whatsapp',
        ),
      );

      final viewModel = ReservationConfirmationViewModel(
        initialDraft: draft,
        visitorAccountService: visitorAccountService,
        notificationService: notificationService,
        reservationRepository: reservationRepo,
      );

      await viewModel.confirmarReserva();

      // Criterio 2: Se disparó WhatsApp y no correo
      expect(fakeWhatsAppClient.sendCalls, 1);
      expect(fakeEmailClient.sendCalls, 0);
      expect(fakeWhatsAppClient.lastPhone, '523398765432');
      expect(fakeWhatsAppClient.lastMessage, contains('Trattoria Bella'));
      expect(viewModel.notificationNoticeMessage, contains('WhatsApp'));
    });

    test('Aplica fallback a correo si el usuario eligió WhatsApp pero no proporcionó teléfono válido', () async {
      final draft = ReservationDraftModel(
        restaurant: restaurant,
        branch: branch,
        fecha: DateTime(2026, 12, 15),
        duracionMin: 90,
        personas: 2,
        mesaIds: const ['mesa_3'],
        mesasNombres: const ['Mesa 3'],
        horario: const TimeOfDay(hour: 14, minute: 0),
        contactData: const ReservationContactModel(
          nombre: 'Héctor Tapia',
          correo: 'hector@example.com',
          telefono: '', // Sin teléfono
          canalPreferido: 'whatsapp',
        ),
      );

      final viewModel = ReservationConfirmationViewModel(
        initialDraft: draft,
        visitorAccountService: visitorAccountService,
        notificationService: notificationService,
        reservationRepository: reservationRepo,
      );

      await viewModel.confirmarReserva();

      // Criterio 2: Fallback automático a correo
      expect(fakeEmailClient.sendCalls, 1);
      expect(fakeWhatsAppClient.sendCalls, 0);
      expect(fakeEmailClient.lastRecipient, 'hector@example.com');
    });

    // =========================================================================
    // CRITERIO 3: Visitante creó cuenta -> reflejo en historial y notificación push
    // =========================================================================
    test('Si el visitante creó cuenta (HU14-RF02), se refleja en su historial de reservas y activa push', () async {
      final draft = ReservationDraftModel(
        restaurant: restaurant,
        branch: branch,
        fecha: DateTime(2026, 12, 20),
        duracionMin: 90,
        personas: 2,
        mesaIds: const ['mesa_vip'],
        mesasNombres: const ['Mesa VIP'],
        horario: const TimeOfDay(hour: 21, minute: 0),
        contactData: const ReservationContactModel(
          nombre: 'Lucía Méndez',
          correo: 'lucia@gmail.com',
          telefono: '3319998877',
          solicitaCrearCuenta: true,
          password: 'Password123!',
          canalPreferido: 'email',
        ),
      );

      final viewModel = ReservationConfirmationViewModel(
        initialDraft: draft,
        visitorAccountService: visitorAccountService,
        notificationService: notificationService,
        reservationRepository: reservationRepo,
      );

      final confirmed = await viewModel.confirmarReserva();

      // Criterio 3: Cuenta creada y asociada
      expect(viewModel.hasAccountCreated, isTrue);
      expect(fakeAuthService.registerCalls, 1);
      final registeredUser = fakeAuthService.users['lucia@gmail.com'];
      expect(registeredUser, isNotNull);

      // Verificación en la reserva
      expect(confirmed!.usuarioId, registeredUser!.uid);

      // Criterio 3: Reflejado en historial de reservas
      final userReservations = reservationRepo.persistedReservations
          .where((r) => r.usuarioId == registeredUser.uid)
          .toList();
      expect(userReservations.length, 1);
      expect(userReservations.first.id, confirmed.id);

      // Criterio 3: Push activada
      expect(viewModel.pushNotificationSent, isTrue);

      // Además, se disparó la confirmación automática
      expect(fakeEmailClient.sendCalls, 1);
      expect(fakeEmailClient.lastRecipient, 'lucia@gmail.com');
    });

    // =========================================================================
    // CRITERIO 4: Mensaje incluye restaurante, fecha, hora, duración, mesas, preorden y ocasión
    // =========================================================================
    test('El mensaje de confirmación incluye todos los detalles requeridos de la visita', () async {
      final draft = ReservationDraftModel(
        restaurant: restaurant,
        branch: branch,
        fecha: DateTime(2026, 12, 24),
        duracionMin: 120,
        personas: 6,
        mesaIds: const ['m1', 'm2'],
        mesasNombres: const ['Mesa Jardín 1', 'Mesa Jardín 2'],
        horario: const TimeOfDay(hour: 19, minute: 30),
        contactData: const ReservationContactModel(
          nombre: 'Fernando Ruiz',
          correo: 'fernando@example.com',
          telefono: '3314445566',
          canalPreferido: 'email',
        ),
        preordenItems: const [
          {'nombre': 'Lasaña Tradicional', 'cantidad': 3, 'precio': 210.0},
          {'nombre': 'Tiramisú della Casa', 'cantidad': 2, 'precio': 110.0},
        ],
        alergias: const ['Nueces', 'Mariscos'],
        notasAlergias: 'Muy alérgico a la nuez',
        ocasionEspecial: const {
          'tipo': 'Cena Navideña',
          'nota': 'Mesa decorada festiva',
        },
      );

      final viewModel = ReservationConfirmationViewModel(
        initialDraft: draft,
        visitorAccountService: visitorAccountService,
        notificationService: notificationService,
        reservationRepository: reservationRepo,
      );

      await viewModel.confirmarReserva();

      expect(fakeEmailClient.sendCalls, 1);
      final body = fakeEmailClient.lastBody!;

      // Criterio 4: Verificación exhaustiva del contenido
      expect(body, contains('Trattoria Bella'));
      expect(body, contains('2026-12-24'));
      expect(body, contains('19:30'));
      expect(body, contains('120 minutos'));
      expect(body, contains('Personas: 6'));
      expect(body, contains('Mesa Jardín 1, Mesa Jardín 2'));
      // Preorden
      expect(body, contains('Resumen de tu preorden:'));
      expect(body, contains('3x Lasaña Tradicional'));
      expect(body, contains('2x Tiramisú della Casa'));
      // Ocasión especial
      expect(body, contains('Celebración: Cena Navideña'));
      expect(body, contains('Mesa decorada festiva'));
      // Alergias
      expect(body, contains('Alergias reportadas: Nueces, Mariscos'));
    });

    // =========================================================================
    // CRITERIO 5: Tolerancia a fallos en la notificación
    // =========================================================================
    test('Si el servicio de envío falla, la reserva permanece confirmada y se registra para reintento manual', () async {
      fakeEmailClient.shouldFail = true; // Simular caída de transporte de correo

      final draft = ReservationDraftModel(
        restaurant: restaurant,
        branch: branch,
        fecha: DateTime(2026, 12, 10),
        duracionMin: 90,
        personas: 2,
        mesaIds: const ['m1'],
        mesasNombres: const ['Mesa 1'],
        horario: const TimeOfDay(hour: 13, minute: 0),
        contactData: const ReservationContactModel(
          nombre: 'Gaby Díaz',
          correo: 'gaby@example.com',
          telefono: '3310001122',
          canalPreferido: 'email',
        ),
      );

      final viewModel = ReservationConfirmationViewModel(
        initialDraft: draft,
        visitorAccountService: visitorAccountService,
        notificationService: notificationService,
        reservationRepository: reservationRepo,
      );

      final confirmed = await viewModel.confirmarReserva();

      // Criterio 5: La reserva NO se pierde ni se cancela
      expect(confirmed, isNotNull);
      expect(confirmed!.estado, ReservationModel.estadoConfirmada);
      expect(reservationRepo.persistedReservations.length, 1);

      // Notificación falló y fue registrada para reintento manual en Firestore
      expect(viewModel.notificationResult, isNotNull);
      expect(viewModel.notificationResult!.exitoso, isFalse);
      expect(viewModel.notificationResult!.requiereReintentoManual, isTrue);

      final notifDoc = await fakeFirestore
          .collection('notificaciones')
          .doc('notif_confirmacion_${confirmed.id}')
          .get();
      expect(notifDoc.exists, isTrue);
      expect(notifDoc.data()?['estado'], 'pendiente_reintento_manual');
      expect(notifDoc.data()?['requiereReintentoManual'], isTrue);
    });

    // =========================================================================
    // INTEGRACIÓN: ReservationBookingService también dispara la confirmación
    // =========================================================================
    test('ReservationBookingService.confirm dispara automáticamente la notificación', () async {
      final bookingService = ReservationBookingService(
        FakeAvailabilityServiceAlwaysValid(reservationRepo),
        reservationRepo,
        notificationService,
      );

      final draft = ReservationDraftModel(
        restaurant: restaurant,
        branch: branch,
        fecha: DateTime(2026, 12, 15),
        duracionMin: 90,
        personas: 2,
        mesaIds: const ['m_bs_1'],
        mesasNombres: const ['Mesa Interior'],
        horario: const TimeOfDay(hour: 18, minute: 0),
        contactData: const ReservationContactModel(
          nombre: 'Rodrigo Paz',
          correo: 'rodrigo@example.com',
          telefono: '3317776655',
          canalPreferido: 'email',
        ),
      );

      final result = await bookingService.confirm(
        restaurant: restaurant,
        draft: draft,
        usuarioId: 'uid_rodrigo',
      );

      expect(result, isA<BookingConfirmed>());
      final confirmed = result as BookingConfirmed;
      expect(confirmed.reservation.estado, ReservationModel.estadoConfirmada);
      expect(confirmed.notificationResult, isNotNull);
      expect(confirmed.notificationResult!.exitoso, isTrue);
      expect(fakeEmailClient.sendCalls, 1);
      expect(fakeEmailClient.lastRecipient, 'rodrigo@example.com');
    });
  });
}
