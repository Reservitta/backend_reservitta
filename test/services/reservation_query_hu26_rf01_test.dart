import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/user_model.dart';
import 'package:reservitta/services/auth_service.dart';
import 'package:reservitta/services/reservation_service.dart';

class _FakeUser implements User {
  @override
  final String uid;

  _FakeUser(this.uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService extends AuthService {
  final User? _user;
  final UserModel? _profile;

  _FakeAuthService({User? user, UserModel? profile})
      : _user = user,
        _profile = profile;

  @override
  User? get currentUser => _user;

  @override
  Future<UserModel?> getUserProfile(String uid) async => _profile;
}

void main() {
  group('62.- HU26-RF01: Consulta de reservas por restaurante y fecha', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ReservationService reservationService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      reservationService = ReservationService(firestore: fakeFirestore);
    });

    test(
      'Criterio 1: Dada la fecha (por defecto el día actual), devuelve las reservas del restaurante ordenadas por hora de inicio',
      () async {
        final hoy = DateTime.now();
        final fechaHoy = ReservationService.formatDateLocal(hoy);

        // Insertamos en desorden horario para hoy y una de otro restaurante / otra fecha
        await reservationService.createReservation(
          ReservationModel(
            id: 'res_tarde',
            restauranteId: 'rest_sabores',
            contactoNombre: 'Sofía Ramírez',
            fechaLocal: fechaHoy,
            inicio: DateTime(hoy.year, hoy.month, hoy.day, 20, 30),
            personas: 4,
            mesaIds: ['m4'],
            mesasNombres: ['Mesa 4'],
            estado: ReservationModel.estadoPendienteLlegada,
          ),
        );

        await reservationService.createReservation(
          ReservationModel(
            id: 'res_temprano',
            restauranteId: 'rest_sabores',
            contactoNombre: 'Alejandro Gómez',
            fechaLocal: fechaHoy,
            inicio: DateTime(hoy.year, hoy.month, hoy.day, 13, 0),
            personas: 2,
            mesaIds: ['m1'],
            mesasNombres: ['Mesa 1'],
            estado: ReservationModel.estadoConfirmada,
          ),
        );

        await reservationService.createReservation(
          ReservationModel(
            id: 'res_medio',
            restauranteId: 'rest_sabores',
            contactoNombre: 'Valeria Torres',
            fechaLocal: fechaHoy,
            inicio: DateTime(hoy.year, hoy.month, hoy.day, 16, 15),
            personas: 6,
            mesaIds: ['m2', 'm3'],
            mesasNombres: ['Mesa 2', 'Mesa 3'],
            estado: ReservationModel.estadoEnServicio,
          ),
        );

        // Reserva de otro día
        await reservationService.createReservation(
          ReservationModel(
            id: 'res_otro_dia',
            restauranteId: 'rest_sabores',
            contactoNombre: 'Cliente Mañana',
            fechaLocal: '2099-12-31',
            inicio: DateTime(2099, 12, 31, 14, 0),
            personas: 2,
            mesaIds: ['m1'],
            mesasNombres: ['Mesa 1'],
            estado: ReservationModel.estadoConfirmada,
          ),
        );

        // Reserva de otro restaurante hoy
        await reservationService.createReservation(
          ReservationModel(
            id: 'res_otro_rest',
            restauranteId: 'rest_ajeno',
            contactoNombre: 'Cliente Ajeno',
            fechaLocal: fechaHoy,
            inicio: DateTime(hoy.year, hoy.month, hoy.day, 12, 0),
            personas: 2,
            mesaIds: ['m9'],
            mesasNombres: ['Mesa 9'],
            estado: ReservationModel.estadoConfirmada,
          ),
        );

        // Sin especificar fechaLocal -> usa por defecto el día actual
        final reservasHoy =
            await reservationService.getReservationsByRestaurantAndDate(
          restauranteId: 'rest_sabores',
        );

        expect(reservasHoy.length, 3);
        expect(
          reservasHoy.map((r) => r.id).toList(),
          ['res_temprano', 'res_medio', 'res_tarde'],
        );
        expect(
          reservasHoy.map((r) => r.horaInicioFormateada).toList(),
          ['13:00', '16:15', '20:30'],
        );
      },
    );

    test(
      'Criterio 2: Cada reserva incluye hora, nombre del cliente, cantidad de personas, mesa(s) asignada(s) y estado',
      () async {
        const fecha = '2026-11-05';
        await reservationService.createReservation(
          ReservationModel(
            id: 'res_completa',
            restauranteId: 'rest_sabores',
            contactoNombre: 'Mariana Mendoza',
            contactoCorreo: 'mariana@correo.com',
            contactoTelefono: '5512345678',
            fechaLocal: fecha,
            inicio: DateTime(2026, 11, 5, 19, 30),
            duracionMin: 90,
            personas: 5,
            mesaIds: ['mesa_a1', 'mesa_a2'],
            mesasNombres: ['Mesa A1', 'Mesa A2'],
            estado: ReservationModel.estadoClienteLlego,
          ),
        );

        final resultado =
            await reservationService.getReservationsByRestaurantAndDate(
          restauranteId: 'rest_sabores',
          fechaLocal: fecha,
        );

        expect(resultado, hasLength(1));
        final reserva = resultado.first;
        expect(reserva.horaInicioFormateada, '19:30');
        expect(reserva.horarioFormateado, '19:30 - 21:00');
        expect(reserva.nombreCliente, 'Mariana Mendoza');
        expect(reserva.cantidadPersonas, 5);
        expect(reserva.mesasAsignadas, ['Mesa A1', 'Mesa A2']);
        expect(reserva.mesasAsignadasTexto, 'Mesa A1, Mesa A2');
        expect(reserva.estadoOperativo, ReservationModel.estadoClienteLlego);
        expect(reserva.etiquetaEstado, 'Cliente llegó');
      },
    );

    test(
      'Criterio 3: Se pueden filtrar por estado (pendiente de llegada, cliente llegó, en servicio, cancelada)',
      () async {
        const fecha = '2026-11-06';

        final estados = [
          ('res_pend', ReservationModel.estadoPendienteLlegada, 13),
          ('res_conf', ReservationModel.estadoConfirmada, 14),
          ('res_llego', ReservationModel.estadoClienteLlego, 15),
          ('res_serv', ReservationModel.estadoEnServicio, 16),
          ('res_canc', ReservationModel.estadoCancelada, 17),
        ];

        for (final item in estados) {
          await reservationService.createReservation(
            ReservationModel(
              id: item.$1,
              restauranteId: 'rest_sabores',
              contactoNombre: 'Cliente ${item.$1}',
              fechaLocal: fecha,
              inicio: DateTime(2026, 11, 6, item.$3, 0),
              personas: 2,
              mesaIds: ['m1'],
              mesasNombres: ['Mesa 1'],
              estado: item.$2,
            ),
          );
        }

        // 1. Filtrar por "pendiente de llegada" (incluye pendiente_llegada y confirmada)
        final pendientes =
            await reservationService.getReservationsByRestaurantAndDate(
          restauranteId: 'rest_sabores',
          fechaLocal: fecha,
          estado: 'pendiente de llegada',
        );
        expect(pendientes.map((r) => r.id).toList(), ['res_pend', 'res_conf']);

        // 2. Filtrar por "cliente llegó"
        final llegaron =
            await reservationService.getReservationsByRestaurantAndDate(
          restauranteId: 'rest_sabores',
          fechaLocal: fecha,
          estado: 'cliente llegó',
        );
        expect(llegaron.map((r) => r.id).toList(), ['res_llego']);

        // 3. Filtrar por "en servicio"
        final enServicio =
            await reservationService.getReservationsByRestaurantAndDate(
          restauranteId: 'rest_sabores',
          fechaLocal: fecha,
          estado: 'en servicio',
        );
        expect(enServicio.map((r) => r.id).toList(), ['res_serv']);

        // 4. Filtrar por "cancelada"
        final canceladas =
            await reservationService.getReservationsByRestaurantAndDate(
          restauranteId: 'rest_sabores',
          fechaLocal: fecha,
          estado: 'cancelada',
        );
        expect(canceladas.map((r) => r.id).toList(), ['res_canc']);
      },
    );

    test(
      'Criterio 1 y 4: getAuthenticatedRestaurantReservations devuelve únicamente las reservas del restaurante del admin autenticado',
      () async {
        final hoy = ReservationService.formatDateLocal(DateTime.now());
        final restPropiaRef =
            fakeFirestore.collection('restaurants').doc('rest_propio');

        final fakeAuth = _FakeAuthService(
          user: _FakeUser('admin_uid_1'),
          profile: UserModel(
            uid: 'admin_uid_1',
            rol: 'admin',
            nombre: 'Admin Propio',
            correo: 'admin@propio.com',
            telefono: '5500000000',
            restauranteId: restPropiaRef,
          ),
        );

        final serviceConAuth = ReservationService(
          firestore: fakeFirestore,
          authService: fakeAuth,
        );

        await serviceConAuth.createReservation(
          ReservationModel(
            id: 'res_propia',
            restauranteId: 'rest_propio',
            contactoNombre: 'Cliente Propio',
            fechaLocal: hoy,
            inicio: DateTime.now(),
            personas: 3,
            mesaIds: ['m1'],
            mesasNombres: ['Mesa 1'],
          ),
        );

        await serviceConAuth.createReservation(
          ReservationModel(
            id: 'res_ajena',
            restauranteId: 'rest_competencia',
            contactoNombre: 'Cliente Competencia',
            fechaLocal: hoy,
            inicio: DateTime.now(),
            personas: 4,
            mesaIds: ['m2'],
            mesasNombres: ['Mesa 2'],
          ),
        );

        final misReservas =
            await serviceConAuth.getAuthenticatedRestaurantReservations();
        expect(misReservas, hasLength(1));
        expect(misReservas.first.id, 'res_propia');
        expect(misReservas.first.restauranteId, 'rest_propio');
      },
    );

    test(
      'Criterio 4: Reglas de Firestore garantizan que un administrador solo vea las reservas de su propio restaurante',
      () {
        final rulesFile = File('firestore.rules');
        expect(rulesFile.existsSync(), isTrue);
        final content = rulesFile.readAsStringSync();

        expect(content, contains('function isAdminOfReservationRestaurant'));
        expect(content, contains('userData.rol == \'admin\''));
        expect(content, contains('userData.restauranteId == restId'));
        expect(
          content,
          contains(
            'allow read: if isAdminOfReservationRestaurant(resource.data)',
          ),
        );
      },
    );
  });
}
