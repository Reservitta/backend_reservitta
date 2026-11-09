import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/viewmodels/admin_reservations_viewmodel.dart';
import 'package:reservitta/views/admin_reservations_view.dart';
import 'package:reservitta/views/reservation_detail_view.dart';
import 'package:reservitta/views/widgets/reservation_state_control.dart';

const _restId = 'r1';
final _fecha = DateTime(2026, 11, 4);

Map<String, dynamic> _linea(String id, String nombre, String categoria,
        {String obs = '', int cant = 1, double precio = 100}) =>
    {
      'platilloId': id,
      'nombre': nombre,
      'categoria': categoria,
      'precio': precio,
      'cantidad': cant,
      'total': precio * cant,
      'observacion': obs,
    };

ReservationModel _reserva({
  String nombre = 'Fernando Herrera',
  List<Map<String, dynamic>> preorden = const [],
  List<String> alergias = const [],
  String notas = '',
  Map<String, dynamic>? ocasion,
  List<Map<String, dynamic>> experiencias = const [],
  String estado = ReservationModel.estadoConfirmada,
  int hora = 14,
}) {
  return ReservationModel.create(
    id: '',
    restauranteId: _restId,
    usuarioId: 'u1',
    contactoNombre: nombre,
    contactoCorreo: nombre.isEmpty ? '' : 'fernando@correo.com',
    contactoTelefono: nombre.isEmpty ? '' : '5599887766',
    fechaLocal: '2026-11-04',
    inicio: DateTime(2026, 11, 4, hora),
    duracionMin: 90,
    personas: 4,
    mesaIds: const ['m4'],
    mesasNombres: const ['Mesa 4'],
    estado: estado,
    preordenItems: preorden,
    alergias: alergias,
    notasAlergias: notas,
    ocasionEspecial: ocasion,
    experiencias: experiencias,
  );
}

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  late ReservationService repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ReservationService(firestore: db);
  });

  void pantallaGrande(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> abrirDetalle(
    WidgetTester tester,
    String id, {
    Future<String?> Function(String)? onChange,
  }) async {
    pantallaGrande(tester);
    await tester.pumpWidget(MaterialApp(
      home: ReservationDetailView(
        reservationId: id,
        repository: repo,
        onChangeState: onChange ??
            (nuevo) async {
              try {
                await repo.changeOperationalState(
                    reservationId: id, nuevoEstado: nuevo, usuarioId: 'admin');
                return null;
              } catch (e) {
                return e.toString();
              }
            },
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('HU28-RF02 pantalla de detalle', () {
    testWidgets('muestra los platillos agrupados con sus notas', (tester) async {
      final r = await repo.createReservationVerified(_reserva(preorden: [
        _linea('p1', 'Ensalada', 'Entrada'),
        _linea('p2', 'Filete', 'Plato fuerte', obs: 'término medio', cant: 2),
        _linea('p3', 'Pastel', 'Postre'),
      ]));
      await abrirDetalle(tester, r.id);

      expect(find.byKey(const ValueKey('detalle_pedido')), findsOneWidget);
      expect(find.byKey(const ValueKey('grupo_Entrada')), findsOneWidget);
      expect(find.byKey(const ValueKey('grupo_Plato fuerte')), findsOneWidget);
      expect(find.byKey(const ValueKey('grupo_Postre')), findsOneWidget);
      expect(find.text('2× Filete'), findsOneWidget);
      expect(find.text('Nota: término medio'), findsOneWidget);
      expect(find.text('1× Ensalada'), findsOneWidget);
      // Primero Entrada y luego Plato fuerte.
      final entrada = tester.getTopLeft(find.byKey(const ValueKey('grupo_Entrada'))).dy;
      final fuerte = tester.getTopLeft(find.byKey(const ValueKey('grupo_Plato fuerte'))).dy;
      expect(entrada, lessThan(fuerte));
    });

    testWidgets('destaca las alergias y restricciones', (tester) async {
      final r = await repo.createReservationVerified(_reserva(
        preorden: [_linea('p2', 'Filete', 'Plato fuerte', obs: 'sin sal')],
        alergias: ['Nueces', 'Gluten'],
        notas: 'Una persona celíaca',
      ));
      await abrirDetalle(tester, r.id);

      expect(find.byKey(const ValueKey('detalle_alergias')), findsOneWidget);
      expect(find.text('¡Alergias y restricciones!'), findsOneWidget);
      expect(find.text('Nueces'), findsOneWidget);
      expect(find.text('Gluten'), findsOneWidget);
      expect(find.text('Una persona celíaca'), findsOneWidget);
      expect(find.text('• Filete: sin sal'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      final caja = tester.widget<Container>(find.byKey(const ValueKey('detalle_alergias')));
      expect((caja.decoration as BoxDecoration).color, const Color(0xFFFFEBEE));
    });

    testWidgets('muestra de forma prominente el tipo de ocasión', (tester) async {
      final r = await repo.createReservationVerified(_reserva(
        ocasion: {'ocasionId': 'o1', 'nombre': 'Cumpleaños', 'icono': 'cake'},
        experiencias: [
          {'experienciaId': 'e1', 'nombre': 'Postre con felicitación', 'precio': 0.0, 'esGratis': true, 'mensajeFelicitacion': 'Feliz cumple Ana'},
        ],
      ));
      await abrirDetalle(tester, r.id);

      expect(find.byKey(const ValueKey('detalle_ocasion')), findsOneWidget);
      final tipo = tester.widget<Text>(find.byKey(const ValueKey('detalle_tipo_ocasion')));
      expect(tipo.data, 'Cumpleaños');
      expect(tipo.style!.fontSize, greaterThanOrEqualTo(20));
      expect(find.textContaining('Postre con felicitación'), findsOneWidget);
      expect(find.text('Mensaje: "Feliz cumple Ana"'), findsOneWidget);
    });

    testWidgets('lo que el cliente no indicó aparece como "No indicado"', (tester) async {
      final r = await repo.createReservationVerified(_reserva(nombre: ''));
      await abrirDetalle(tester, r.id);

      expect(find.byKey(const ValueKey('detalle_pedido_vacio')), findsOneWidget);
      expect(find.byKey(const ValueKey('detalle_alergias_vacias')), findsOneWidget);
      expect(find.byKey(const ValueKey('detalle_ocasion_vacia')), findsOneWidget);
      expect(find.byKey(const ValueKey('texto_no_indicado')), findsNWidgets(3));
      expect(find.text('No indicado'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('incluye los datos del cliente y de la visita', (tester) async {
      final r = await repo.createReservationVerified(_reserva());
      await abrirDetalle(tester, r.id);
      expect(find.text('Fernando Herrera'), findsWidgets);
      expect(find.text('5599887766'), findsOneWidget);
      expect(find.text('fernando@correo.com'), findsOneWidget);
      expect(find.text('14:00 – 15:30'), findsOneWidget);
      expect(find.text('Mesa 4'), findsOneWidget);
    });

    testWidgets('una reservación inexistente muestra un error con reintento', (tester) async {
      await abrirDetalle(tester, 'no_existe');
      expect(find.byKey(const ValueKey('detalle_error')), findsOneWidget);
      expect(find.byKey(const ValueKey('detalle_reintentar')), findsOneWidget);
    });

    testWidgets('desde el detalle se cambia el estado y se actualiza la pantalla', (tester) async {
      final r = await repo.createReservationVerified(_reserva());
      await abrirDetalle(tester, r.id);

      expect(find.text('Estado actual: Pendiente de llegada'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('boton_estado_cliente_llego')));
      await tester.pumpAndSettle();

      expect(find.text('Estado actual: Cliente llegó'), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_estado_en_servicio')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_estado_cliente_llego')), findsNothing);
    });

    testWidgets('el detalle muestra el estado del pedido', (tester) async {
      final r = await repo.createReservationVerified(_reserva(
        preorden: [_linea('p1', 'Ensalada', 'Entrada')],
      ));
      await abrirDetalle(tester, r.id);
      expect(find.byKey(const ValueKey('detalle_estado_pedido')), findsOneWidget);
      expect(find.text('Pedido: Pendiente'), findsOneWidget);
    });
  });

  group('HU27-RF02 control de cambio de estado', () {
    Future<void> montar(
      WidgetTester tester, {
      required String estado,
      required Future<String?> Function(String) onChange,
      bool compacto = false,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReservationStateControl(
              reservaId: 'r1',
              estadoActual: estado,
              onChange: onChange,
              compacto: compacto,
            ),
          ),
        ),
      ));
    }

    testWidgets('solo ofrece las transiciones válidas desde el estado actual', (tester) async {
      await montar(tester, estado: 'pendiente_llegada', onChange: (_) async => null);
      expect(find.byKey(const ValueKey('boton_estado_cliente_llego')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_estado_cancelada')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_estado_no_show')), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_estado_en_servicio')), findsNothing);
      expect(find.byKey(const ValueKey('boton_estado_finalizada')), findsNothing);
    });

    testWidgets('desde en servicio solo se puede finalizar', (tester) async {
      await montar(tester, estado: 'en_servicio', onChange: (_) async => null);
      expect(find.byKey(const ValueKey('boton_estado_finalizada')), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('un estado final no ofrece ningún cambio', (tester) async {
      for (final e in ['finalizada', 'cancelada', 'no_show']) {
        await montar(tester, estado: e, onChange: (_) async => null);
        expect(find.byKey(const ValueKey('control_estado')), findsNothing, reason: e);
      }
    });

    testWidgets('un cambio normal se aplica sin pedir confirmación', (tester) async {
      String? recibido;
      await montar(tester, estado: 'pendiente_llegada', onChange: (n) async {
        recibido = n;
        return null;
      });
      await tester.tap(find.byKey(const ValueKey('boton_estado_cliente_llego')));
      await tester.pumpAndSettle();
      expect(recibido, 'cliente_llego');
      expect(find.byKey(const ValueKey('dialogo_confirmar_estado_r1')), findsNothing);
    });

    testWidgets('cancelar pide confirmación y respeta "Volver"', (tester) async {
      var llamadas = 0;
      await montar(tester, estado: 'pendiente_llegada', onChange: (_) async {
        llamadas++;
        return null;
      });
      await tester.tap(find.byKey(const ValueKey('boton_estado_cancelada')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dialogo_confirmar_estado_r1')), findsOneWidget);
      expect(find.text('¿Cancelar esta reserva?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('boton_volver_estado')));
      await tester.pumpAndSettle();
      expect(llamadas, 0);

      await tester.tap(find.byKey(const ValueKey('boton_estado_cancelada')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('boton_confirmar_estado')));
      await tester.pumpAndSettle();
      expect(llamadas, 1);
    });

    testWidgets('marcar no-show también pide confirmación', (tester) async {
      String? recibido;
      await montar(tester, estado: 'pendiente_llegada', onChange: (n) async {
        recibido = n;
        return null;
      });
      await tester.tap(find.byKey(const ValueKey('boton_estado_no_show')));
      await tester.pumpAndSettle();
      expect(find.text('¿Marcar como no-show?'), findsOneWidget);
      expect(recibido, isNull);
      await tester.tap(find.byKey(const ValueKey('boton_confirmar_estado')));
      await tester.pumpAndSettle();
      expect(recibido, 'no_show');
    });

    testWidgets('si el cambio falla muestra el motivo', (tester) async {
      await montar(tester,
          estado: 'pendiente_llegada',
          onChange: (_) async => 'No se puede pasar de "A" a "B".');
      await tester.tap(find.byKey(const ValueKey('boton_estado_cliente_llego')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('snack_cambio_estado_error')), findsOneWidget);
      expect(find.text('No se puede pasar de "A" a "B".'), findsOneWidget);
    });

    testWidgets('la versión compacta usa un menú con las mismas opciones', (tester) async {
      await montar(tester,
          estado: 'cliente_llego', compacto: true, onChange: (_) async => null);
      await tester.tap(find.byKey(const ValueKey('menu_estado_r1')));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar servicio'), findsOneWidget);
      expect(find.text('Cancelar reserva'), findsOneWidget);
      expect(find.text('Marcar llegada'), findsNothing);
      expect(find.text('No se presentó'), findsNothing);
    });
  });

  group('HU27-RF02 desde el listado de reservas', () {
    Future<AdminReservationsViewModel> abrirListado(WidgetTester tester) async {
      pantallaGrande(tester);
      final vm = AdminReservationsViewModel(
        restaurantId: _restId,
        reservationRepository: repo,
        initialDate: _fecha,
        usuarioId: () => 'admin_7',
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(MaterialApp(
        home: AdminReservationsView(
          restaurantId: _restId,
          reservationRepository: repo,
          viewModel: vm,
          cargarCategorias: () async => {},
        ),
      ));
      await tester.pumpAndSettle();
      return vm;
    }

    testWidgets('cambia el estado desde el menú y el listado se actualiza solo', (tester) async {
      final r = await repo.createReservationVerified(_reserva());
      await abrirListado(tester);
      expect(find.text('Pendiente de llegada'), findsWidgets);

      await tester.tap(find.byKey(ValueKey('menu_estado_${r.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('opcion_estado_cliente_llego')));
      await tester.pumpAndSettle();

      expect(find.text('Cliente llegó'), findsWidgets);
      final guardada = (await repo.getReservationById(r.id))!;
      expect(guardada.estadoOperativo, 'cliente_llego');
      expect(guardada.estadoActualizadoPor, 'admin_7');
    });

    testWidgets('cancelar desde el listado pide confirmación y libera la mesa', (tester) async {
      final r = await repo.createReservationVerified(_reserva());
      await abrirListado(tester);

      await tester.tap(find.byKey(ValueKey('menu_estado_${r.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('opcion_estado_cancelada')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('dialogo_confirmar_estado_${r.id}')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('boton_confirmar_estado')));
      await tester.pumpAndSettle();

      expect((await repo.getReservationById(r.id))!.estadoOperativo, 'cancelada');
      await repo.createReservationVerified(_reserva()); // la mesa quedó libre
    });

    testWidgets('las reservas finalizadas y no-show tienen su filtro', (tester) async {
      final a = await repo.createReservationVerified(_reserva(hora: 12));
      final b = await repo.createReservationVerified(_reserva(hora: 16));
      await repo.changeOperationalState(reservationId: a.id, nuevoEstado: 'no_show', usuarioId: 'x');
      await repo.changeOperationalState(reservationId: b.id, nuevoEstado: 'cliente_llego', usuarioId: 'x');
      await repo.changeOperationalState(reservationId: b.id, nuevoEstado: 'en_servicio', usuarioId: 'x');
      await repo.changeOperationalState(reservationId: b.id, nuevoEstado: 'finalizada', usuarioId: 'x');
      final vm = await abrirListado(tester);

      expect(find.byKey(const ValueKey('filtro_estado_finalizada')), findsOneWidget);
      expect(find.byKey(const ValueKey('filtro_estado_no_show')), findsOneWidget);
      expect(vm.contarPorEstado('finalizada'), 1);
      expect(vm.contarPorEstado('no_show'), 1);

      await tester.ensureVisible(find.byKey(const ValueKey('filtro_estado_no_show')));
      await tester.tap(find.byKey(const ValueKey('filtro_estado_no_show')));
      await tester.pumpAndSettle();
      expect(vm.reservas.map((x) => x.id), [a.id]);
      // Una reserva en estado final no ofrece más cambios.
      expect(find.byKey(ValueKey('menu_estado_${a.id}')), findsNothing);
    });

    testWidgets('el viewmodel devuelve un mensaje si el cambio no es válido', (tester) async {
      final r = await repo.createReservationVerified(_reserva());
      final vm = await abrirListado(tester);
      final error = await vm.cambiarEstado(r.id, 'finalizada');
      expect(error, contains('No se puede pasar de'));
      expect(await vm.cambiarEstado(r.id, 'cliente_llego'), isNull);
    });
  });
}
