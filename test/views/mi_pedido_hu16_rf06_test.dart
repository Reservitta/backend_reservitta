import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/ocasion_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/viewmodels/pedido_viewmodel.dart';
import 'package:reservitta/views/mi_pedido_view.dart';
import 'package:reservitta/views/personalize_visit_view.dart';

class _FakePlatilloService extends PlatilloService {
  final List<PlatilloModel> platillos;
  _FakePlatilloService(this.platillos);

  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) {
    return Stream.value(platillos);
  }
}

class _FakeOcasionService extends OcasionService {
  @override
  Future<List<OcasionModel>> getOcasiones(String restaurantId) async {
    return const [];
  }
}

void main() {
  final restaurant = const RestaurantModel(
    id: 'rest_demo',
    nombre: 'Miel Aurum',
    estado: 'activo',
  );

  final platillo1 = PlatilloModel(
    id: 'plat_1',
    categoriaId: 'cat_entradas',
    nombre: 'Ceviche Mixto',
    descripcion: 'Pescado fresco y mariscos',
    precio: 150.0,
    imagenUrl: 'https://example.com/ceviche.jpg',
    etiquetas: const ['Fresco'],
  );

  final platillo2 = PlatilloModel(
    id: 'plat_2',
    categoriaId: 'cat_fuertes',
    nombre: 'Ribeye a la Leña',
    descripcion: 'Corte jugoso de 400g',
    precio: 350.0,
    imagenUrl: 'https://example.com/ribeye.jpg',
    etiquetas: const ['Carne'],
  );

  final draft = ReservationDraftModel(
    restaurant: restaurant,
    fecha: DateTime(2026, 11, 9),
    duracionMin: 90,
    personas: 2,
    mesaIds: const ['mesa_1'],
    mesasNombres: const ['Mesa Terraza 1'],
    horario: const TimeOfDay(hour: 13, minute: 0),
  );

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('HU16-RF06 Criterio 1: Acceso a "Mi pedido" solo con sesión iniciada', () {
    testWidgets(
      'Si el usuario NO tiene sesión, el botón "Ver mi pedido" NO aparece en el preorden',
      (tester) async {
        setScreenSize(tester);
        final pedidoVm = PedidoViewModel();
        pedidoVm.agregarPlatillo(platillo1, cantidad: 2);

        await tester.pumpWidget(
          MaterialApp(
            home: PersonalizeVisitView(
              restaurant: restaurant,
              draft: draft,
              pedidoViewModel: pedidoVm,
              platilloService: _FakePlatilloService([platillo1, platillo2]),
              ocasionService: _FakeOcasionService(),
              isAuthenticated: false, // Sin sesión iniciada
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('btn_ver_mi_pedido')), findsNothing);
      },
    );

    testWidgets(
      'Si el usuario SÍ tiene sesión iniciada, muestra "Ver mi pedido (n platillos)" y al pulsar abre MiPedidoView',
      (tester) async {
        setScreenSize(tester);
        final pedidoVm = PedidoViewModel();
        pedidoVm.agregarPlatillo(platillo1, cantidad: 2);

        await tester.pumpWidget(
          MaterialApp(
            home: PersonalizeVisitView(
              restaurant: restaurant,
              draft: draft,
              pedidoViewModel: pedidoVm,
              platilloService: _FakePlatilloService([platillo1, platillo2]),
              ocasionService: _FakeOcasionService(),
              isAuthenticated: true, // Con sesión iniciada
            ),
          ),
        );
        await tester.pumpAndSettle();

        // El botón "Ver mi pedido (2 platillos)" es visible
        final btn = find.byKey(const ValueKey('btn_ver_mi_pedido'));
        expect(btn, findsOneWidget);
        expect(find.text('Ver mi pedido (2 platillos)'), findsOneWidget);

        // Al pulsar el botón, navega a la pantalla MiPedidoView
        await tester.tap(btn);
        await tester.pumpAndSettle();

        expect(find.byType(MiPedidoView), findsOneWidget);
        expect(find.text('Mi pedido'), findsWidgets);
      },
    );
  });

  group('HU16-RF06 Criterio 2: Resumen de la reserva de solo lectura', () {
    testWidgets('Muestra los datos de la reserva en modo de solo lectura', (tester) async {
      setScreenSize(tester);
      final pedidoVm = PedidoViewModel();
      pedidoVm.agregarPlatillo(platillo1, cantidad: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: MiPedidoView(
            restaurant: restaurant,
            draft: draft,
            pedidoViewModel: pedidoVm,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('resumen_reserva_mi_pedido')), findsOneWidget);
      expect(find.byKey(const ValueKey('resumen_nombre_restaurante')), findsOneWidget);
      expect(find.text('Miel Aurum'), findsOneWidget);
      expect(find.text('Solo lectura'), findsOneWidget);
      expect(find.text('2 personas'), findsOneWidget);
      expect(find.text('Mesa Terraza 1'), findsOneWidget);
    });
  });

  group('HU16-RF06 Criterio 3: Detalle de cada platillo en la lista', () {
    testWidgets(
      'Lista imagen, nombre, cantidad × precio unitario, precio total de línea y observación',
      (tester) async {
        setScreenSize(tester);
        final pedidoVm = PedidoViewModel();
        pedidoVm.agregarPlatillo(
          platillo1,
          cantidad: 2,
          observacion: 'Sin cebolla y poco picante',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MiPedidoView(
              restaurant: restaurant,
              draft: draft,
              pedidoViewModel: pedidoVm,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nombre
        expect(find.byKey(const ValueKey('mi_pedido_item_nombre_plat_1')), findsOneWidget);
        expect(find.text('Ceviche Mixto'), findsOneWidget);

        // Cantidad × precio unitario: 2 × $150.00 MXN
        expect(find.byKey(const ValueKey('mi_pedido_item_desglose_plat_1')), findsOneWidget);
        expect(find.text('2 × \$150.00 MXN'), findsOneWidget);

        // Total de línea: Total: $300.00 MXN
        expect(find.byKey(const ValueKey('mi_pedido_item_total_plat_1')), findsOneWidget);
        expect(find.text('Total: \$300.00 MXN'), findsOneWidget);

        // Observación existente
        expect(find.byKey(const ValueKey('mi_pedido_item_observacion_plat_1')), findsOneWidget);
        expect(find.text('Observación: Sin cebolla y poco picante'), findsOneWidget);
      },
    );
  });

  group('HU16-RF06 Criterio 4: Acciones Editar y Eliminar (con confirmación)', () {
    testWidgets('Botón Editar abre el detalle del platillo', (tester) async {
      setScreenSize(tester);
      final pedidoVm = PedidoViewModel();
      pedidoVm.agregarPlatillo(platillo1, cantidad: 1, observacion: 'Con limón extra');

      await tester.pumpWidget(
        MaterialApp(
          home: MiPedidoView(
            restaurant: restaurant,
            draft: draft,
            pedidoViewModel: pedidoVm,
            catalogoPorId: {platillo1.id: platillo1},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnEditar = find.byKey(const ValueKey('btn_editar_plat_1'));
      expect(btnEditar, findsOneWidget);

      await tester.tap(btnEditar);
      await tester.pumpAndSettle();

      // Abre el detalle de platillo con el contenido prellenado
      expect(find.byKey(const ValueKey('platillo_detalle_sheet')), findsOneWidget);
      expect(find.text('Con limón extra'), findsOneWidget);
    });

    testWidgets('Botón Eliminar muestra diálogo de confirmación y al cancelar no lo borra', (tester) async {
      setScreenSize(tester);
      final pedidoVm = PedidoViewModel();
      pedidoVm.agregarPlatillo(platillo1, cantidad: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: MiPedidoView(
            restaurant: restaurant,
            draft: draft,
            pedidoViewModel: pedidoVm,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnEliminar = find.byKey(const ValueKey('btn_eliminar_plat_1'));
      await tester.tap(btnEliminar);
      await tester.pumpAndSettle();

      // Muestra diálogo de confirmación
      expect(find.byKey(const ValueKey('dialog_confirmar_eliminar')), findsOneWidget);
      expect(find.text('¿Eliminar platillo?'), findsOneWidget);
      expect(find.text('¿Seguro que deseas eliminar "Ceviche Mixto" de tu pedido?'), findsOneWidget);

      // Al pulsar cancelar, se cierra el diálogo y el platillo sigue en el pedido
      await tester.tap(find.byKey(const ValueKey('btn_cancelar_eliminar')));
      await tester.pumpAndSettle();

      expect(pedidoVm.estaAgregado('plat_1'), isTrue);
      expect(find.byKey(const ValueKey('mi_pedido_item_plat_1')), findsOneWidget);
    });

    testWidgets('Botón Eliminar confirma y remueve el platillo del pedido', (tester) async {
      setScreenSize(tester);
      final pedidoVm = PedidoViewModel();
      pedidoVm.agregarPlatillo(platillo1, cantidad: 2);
      pedidoVm.agregarPlatillo(platillo2, cantidad: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: MiPedidoView(
            restaurant: restaurant,
            draft: draft,
            pedidoViewModel: pedidoVm,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pedidoVm.items.length, equals(2));

      // Tap eliminar platillo 1
      await tester.tap(find.byKey(const ValueKey('btn_eliminar_plat_1')));
      await tester.pumpAndSettle();

      // Confirmar eliminar
      await tester.tap(find.byKey(const ValueKey('btn_confirmar_eliminar')));
      await tester.pumpAndSettle();

      expect(pedidoVm.estaAgregado('plat_1'), isFalse);
      expect(find.byKey(const ValueKey('mi_pedido_item_plat_1')), findsNothing);
      expect(pedidoVm.estaAgregado('plat_2'), isTrue);
    });
  });

  group('HU16-RF06 Criterio 5: Muestra el Subtotal general del pedido', () {
    testWidgets('Calcula y muestra el subtotal general correctamente', (tester) async {
      setScreenSize(tester);
      final pedidoVm = PedidoViewModel();
      // 2 * 150 = 300
      pedidoVm.agregarPlatillo(platillo1, cantidad: 2);
      // 1 * 350 = 350 -> Total = 650.00
      pedidoVm.agregarPlatillo(platillo2, cantidad: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: MiPedidoView(
            restaurant: restaurant,
            draft: draft,
            pedidoViewModel: pedidoVm,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('card_subtotal_mi_pedido')), findsOneWidget);
      expect(find.byKey(const ValueKey('texto_subtotal_general')), findsOneWidget);
      expect(find.text('\$650.00 MXN'), findsOneWidget);
    });
  });

  group('HU16-RF06 Criterio 6: Botón "Agregar más platillos"', () {
    testWidgets('Regresa conservando lo ya agregado', (tester) async {
      setScreenSize(tester);
      final pedidoVm = PedidoViewModel();
      pedidoVm.agregarPlatillo(platillo1, cantidad: 1);

      bool regresoInvocado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MiPedidoView(
            restaurant: restaurant,
            draft: draft,
            pedidoViewModel: pedidoVm,
            onAgregarMasPlatillos: () {
              regresoInvocado = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnAgregarMas = find.byKey(const ValueKey('btn_agregar_mas_platillos'));
      expect(btnAgregarMas, findsOneWidget);
      expect(find.text('Agregar más platillos'), findsOneWidget);

      await tester.tap(btnAgregarMas);
      await tester.pumpAndSettle();

      expect(regresoInvocado, isTrue);
      expect(pedidoVm.estaAgregado('plat_1'), isTrue);
    });
  });

  group('HU16-RF06 Criterio 7: Botón "Continuar" que avanza a la pantalla de ocasión especial', () {
    testWidgets('Pulsar Continuar avanza a ocasión especial', (tester) async {
      setScreenSize(tester);
      final pedidoVm = PedidoViewModel();
      pedidoVm.agregarPlatillo(platillo1, cantidad: 1);

      bool continuoAOvision = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MiPedidoView(
            restaurant: restaurant,
            draft: draft,
            pedidoViewModel: pedidoVm,
            onContinuarOcasion: () {
              continuoAOvision = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnContinuar = find.byKey(const ValueKey('btn_continuar_ocasion'));
      expect(btnContinuar, findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);

      await tester.tap(btnContinuar);
      await tester.pumpAndSettle();

      expect(continuoAOvision, isTrue);
    });
  });
}
