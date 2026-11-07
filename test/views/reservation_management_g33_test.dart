import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_management_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/views/reservation_flow_view.dart';
import 'package:reservitta/views/reservation_management_view.dart';

const _token = 'ABCDEFGHJKMNPQRSTUVW';
const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

final _restaurante = RestaurantModel(
  id: 'r1',
  nombre: 'Miel Test',
  estado: 'activo',
  telefono: '418-555-0101',
  direccion: 'Calle Telesecundaria 1',
  capacidadMaxima: 30,
  mesas: const [
    MesaModel(id: 'm1', nombre: 'M1', capacidad: 4, x: 0, y: 0),
    MesaModel(id: 'm2', nombre: 'M2', capacidad: 4, x: 120, y: 0),
  ],
  horarios: {
    for (final d in [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo'
    ])
      d: _horario,
  },
);

ReservationModel _reserva({String token = _token, List<String> mesas = const ['m1'], int hora = 14}) {
  return ReservationModel.create(
    id: '',
    restauranteId: 'r1',
    usuarioId: 'u1',
    restauranteNombre: 'Miel Test',
    contactoNombre: 'Carlos',
    fechaLocal: '2026-10-30',
    inicio: DateTime(2026, 10, 30, hora),
    duracionMin: 90,
    personas: 4,
    mesaIds: mesas,
    mesasNombres: [for (final m in mesas) m.toUpperCase()],
    estado: ReservationModel.estadoConfirmada,
    tokenGestion: token,
  );
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  late ReservationService repo;
  var ahora = DateTime(2026, 10, 30, 9);

  setUp(() async {
    ahora = DateTime(2026, 10, 30, 9);
    db = FakeFirebaseFirestore();
    repo = ReservationService(firestore: db);
    await db.collection('restaurants').doc('r1').set({
      'nombre': 'Miel Test',
      'telefono': '418-555-0101',
      'direccion': 'Calle Telesecundaria 1',
    });
    await repo.createReservationVerified(_reserva());
  });

  AvailabilityService disponibilidad(String reservaId) =>
      AvailabilityService(repo, now: () => ahora, ignorarReservaId: reservaId);

  Future<void> abrir(WidgetTester tester, {String? codigo}) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final servicio = ReservationManagementService(
      firestore: db,
      availability: AvailabilityService(repo, now: () => ahora),
      now: () => ahora,
    );
    await tester.pumpWidget(MaterialApp(
      home: ReservationManagementView(
        initialCode: codigo,
        service: servicio,
        now: () => ahora,
        cargarRestaurante: (_) async => _restaurante,
        disponibilidadParaEditar: disponibilidad,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder k(String key) => find.byKey(ValueKey(key));

  group('HU20-RF03 abrir con el enlace o el código', () {
    testWidgets('con el enlace muestra el resumen de la reserva', (tester) async {
      await abrir(tester, codigo: _token);
      expect(k('resumen_reserva'), findsOneWidget);
      expect(find.text('Miel Test'), findsOneWidget);
      expect(find.text('V, 30 de Octubre'), findsOneWidget);
      expect(find.text('14:00 – 15:30'), findsOneWidget);
      expect(find.text('M1'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
    });

    testWidgets('sin enlace pide el código y lo acepta con guiones y minúsculas', (tester) async {
      await abrir(tester);
      expect(k('buscador_reserva'), findsOneWidget);
      expect(k('resumen_reserva'), findsNothing);

      await tester.enterText(k('campo_codigo_reserva'), 'abcd-efgh-jkmn-pqrs-tuvw');
      await tester.tap(k('btn_buscar_reserva'));
      await tester.pumpAndSettle();
      expect(k('resumen_reserva'), findsOneWidget);
    });

    testWidgets('un código inexistente muestra un error claro', (tester) async {
      await abrir(tester);
      await tester.enterText(k('campo_codigo_reserva'), 'ZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZ');
      await tester.tap(k('btn_buscar_reserva'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No encontramos una reserva'), findsOneWidget);
      expect(k('resumen_reserva'), findsNothing);
    });

    testWidgets('un código vencido avisa que ya no es válido', (tester) async {
      ahora = DateTime(2026, 11, 2);
      await abrir(tester, codigo: _token);
      expect(find.textContaining('ya no es válido'), findsOneWidget);
    });

    testWidgets('no muestra datos de contacto del cliente', (tester) async {
      await abrir(tester, codigo: _token);
      expect(find.textContaining('Carlos'), findsNothing);
    });
  });

  group('HU20-RF03 dentro del límite de 2 horas', () {
    testWidgets('muestra "Modificar" y "Cancelar" con la hora límite', (tester) async {
      await abrir(tester, codigo: _token);
      expect(k('btn_modificar_reserva'), findsOneWidget);
      expect(k('btn_cancelar_reserva'), findsOneWidget);
      expect(k('aviso_solo_lectura'), findsNothing);
      expect(tester.widget<Text>(k('texto_limite')).data, contains('12:00'));
    });

    testWidgets('justo en el límite todavía se puede gestionar', (tester) async {
      ahora = DateTime(2026, 10, 30, 12, 0);
      await abrir(tester, codigo: _token);
      expect(k('btn_modificar_reserva'), findsOneWidget);
    });
  });

  group('HU20-RF03 pasado el límite', () {
    testWidgets('queda en solo lectura con aviso y contacto del restaurante', (tester) async {
      ahora = DateTime(2026, 10, 30, 12, 30);
      await abrir(tester, codigo: _token);

      expect(k('resumen_reserva'), findsOneWidget);
      expect(k('btn_modificar_reserva'), findsNothing);
      expect(k('btn_cancelar_reserva'), findsNothing);
      expect(k('aviso_solo_lectura'), findsOneWidget);
      expect(tester.widget<Text>(k('motivo_solo_lectura')).data, contains('2 horas'));
      expect(k('contacto_restaurante'), findsOneWidget);
      expect(find.text('418-555-0101'), findsOneWidget);
      expect(find.text('Calle Telesecundaria 1'), findsOneWidget);
    });
  });

  group('HU20-RF03 cancelar', () {
    testWidgets('pide confirmación explícita y "Volver" no cancela', (tester) async {
      await abrir(tester, codigo: _token);
      await tester.tap(k('btn_cancelar_reserva'));
      await tester.pumpAndSettle();
      expect(k('dialogo_cancelar_reserva'), findsOneWidget);

      await tester.tap(k('btn_volver_cancelar'));
      await tester.pumpAndSettle();
      expect(k('dialogo_cancelar_reserva'), findsNothing);
      final doc = (await db.collection('reservations').get()).docs.single.data();
      expect(doc['estado'], 'confirmada');
    });

    testWidgets('al confirmar cancela, libera la mesa y avisa', (tester) async {
      await abrir(tester, codigo: _token);
      await tester.tap(k('btn_cancelar_reserva'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_confirmar_cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Tu reserva fue cancelada. ¡Esperamos verte pronto!'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(k('btn_cancelar_reserva'), findsNothing);
      expect((await db.collection('reservations').get()).docs.single.data()['estado'], 'cancelada');
      await repo.createReservationVerified(_reserva(token: 'BCDEFGHJKMNPQRSTUVWX')); // mesa libre
    });
  });

  group('HU20-RF03 modificar con las pantallas de la reserva', () {
    Future<void> recorrerHastaElResumen(WidgetTester tester, {String? horaNueva}) async {
      await tester.tap(k('btn_modificar_reserva'));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationFlowView), findsOneWidget);

      // Paso 1 (fecha) ya viene con la fecha actual de la reserva.
      expect(k('btn_continuar_step_1'), findsOneWidget);
      await tester.tap(k('btn_continuar_step_1'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_continuar_step_2'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_continuar_step_3'));
      await tester.pumpAndSettle();
      // Paso 4: la mesa actual sigue seleccionada porque la propia reserva no cuenta.
      expect(find.textContaining('M1 · capacidad 4'), findsOneWidget);
      await tester.tap(k('btn_continuar_step_4'));
      await tester.pumpAndSettle();
      // Paso 5: el horario actual está disponible y marcado.
      expect(k('slot_chip_1400'), findsOneWidget);
      if (horaNueva != null) {
        await tester.tap(k('slot_chip_$horaNueva'));
        await tester.pumpAndSettle();
      }
      await tester.tap(k('btn_continuar_step_5'));
      await tester.pumpAndSettle();
    }

    testWidgets('abre el flujo prellenado y guarda el nuevo horario', (tester) async {
      await abrir(tester, codigo: _token);
      await recorrerHastaElResumen(tester, horaNueva: '1800');

      expect(find.text('Guardar cambios'), findsWidgets);
      await tester.tap(k('btn_confirmar_reserva'));
      await tester.pumpAndSettle();

      // Regresa a la gestión con el cambio reflejado.
      expect(find.byType(ReservationFlowView), findsNothing);
      expect(find.text('Tu reserva se actualizó correctamente.'), findsOneWidget);
      expect(find.text('18:00 – 19:30'), findsOneWidget);
      final doc = (await db.collection('reservations').get()).docs.single.data();
      expect((doc['inicio'] as dynamic).toDate(), DateTime(2026, 10, 30, 18));
    });

    testWidgets('si el nuevo horario se ocupó avisa y no guarda', (tester) async {
      await abrir(tester, codigo: _token);
      await tester.tap(k('btn_modificar_reserva'));
      await tester.pumpAndSettle();
      for (final paso in ['1', '2', '3', '4']) {
        await tester.tap(k('btn_continuar_step_$paso'));
        await tester.pumpAndSettle();
      }
      await tester.tap(k('slot_chip_1800'));
      await tester.pumpAndSettle();
      // Otra persona toma M1 a las 18:00 antes de que se confirme.
      await repo.createReservationVerified(
          _reserva(token: 'BCDEFGHJKMNPQRSTUVWX', hora: 18));
      await tester.tap(k('btn_continuar_step_5'));
      await tester.pumpAndSettle();

      // La revalidación (HU12-RF02) la detecta y regresa al horario.
      expect(find.byType(ReservationFlowView), findsOneWidget);
      final doc = (await db
              .collection('reservations')
              .where('tokenGestion', isEqualTo: _token)
              .get())
          .docs
          .single
          .data();
      expect((doc['inicio'] as dynamic).toDate(), DateTime(2026, 10, 30, 14));
    });
  });
}
