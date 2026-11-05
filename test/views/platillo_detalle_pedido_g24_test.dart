import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/ocasion_service.dart';
import 'package:reservitta/services/platillo_service.dart';
import 'package:reservitta/viewmodels/pedido_viewmodel.dart';
import 'package:reservitta/views/personalize_visit_view.dart';
import 'package:reservitta/views/widgets/platillo_detalle_sheet.dart';
import 'package:reservitta/views/widgets/platillo_menu_card.dart';

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
  final platillo = PlatilloModel(
    id: 'plat_ceviche',
    categoriaId: 'cat_entradas',
    nombre: 'Ceviche Peruano',
    descripcion: 'Pescado fresco marinado en leche de tigre con maíz cancha',
    precio: 195.00,
    etiquetas: const ['Entrada', 'Sin gluten', 'Fresco'],
  );

  final restaurant = RestaurantModel(
    id: 'rest_g24',
    nombre: 'Mar & Tierra',
    estado: 'activo',
  );

  group('G24 · HU16-RF04 y HU17-RF01: Detalle de platillo con cantidad y observaciones', () {
    testWidgets(
      'Muestra imagen, nombre, precio unitario, descripción, etiquetas, stepper mínimo 1 y campo de texto libre con límite 200',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pedidoVm = PedidoViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatilloDetalleSheet(
                platillo: platillo,
                pedidoViewModel: pedidoVm,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // HU16-RF04 Criterio 1: Imagen, nombre, precio unitario, descripción y etiquetas
        expect(find.byKey(const ValueKey('detalle_platillo_imagen')), findsOneWidget);
        expect(find.byKey(const ValueKey('detalle_platillo_nombre')), findsOneWidget);
        expect(find.text('Ceviche Peruano'), findsOneWidget);
        expect(find.byKey(const ValueKey('detalle_platillo_precio_unitario')), findsOneWidget);
        expect(find.text('\$195.00 MXN'), findsOneWidget);
        expect(find.byKey(const ValueKey('detalle_platillo_descripcion')), findsOneWidget);
        expect(find.byKey(const ValueKey('detalle_platillo_etiquetas')), findsOneWidget);
        expect(find.text('Entrada'), findsOneWidget);
        expect(find.text('Sin gluten'), findsOneWidget);
        expect(find.text('Fresco'), findsOneWidget);

        // HU17-RF01 Criterio 1 y 2: Solo campo de texto libre con título y subtítulo; sin checkboxes
        expect(find.text('Agregar una observación'), findsOneWidget);
        expect(find.text('¿Algo más que debamos saber sobre este platillo?'), findsOneWidget);
        expect(find.byKey(const ValueKey('input_observacion_platillo')), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.byType(CheckboxListTile), findsNothing);

        // HU17-RF01 Criterio 5: Límite de caracteres razonable (200) visible para el usuario
        expect(find.text('0/200 caracteres'), findsOneWidget);

        // HU16-RF04 Criterio 2: Stepper de Cantidad con mínimo 1
        expect(find.text('1'), findsOneWidget);
        final btnDec = tester.widget<IconButton>(
          find.byKey(const ValueKey('btn_decrementar_cantidad')),
        );
        expect(btnDec.onPressed, isNull);

        // HU16-RF04 Criterio 3: Precio en botón "Agregar al pedido" se recalcula como precio unitario × cantidad
        expect(find.text('Agregar al pedido · \$195.00 MXN'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('btn_incrementar_cantidad')));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Agregar al pedido · \$390.00 MXN'), findsOneWidget);

        // HU17-RF01 Criterio 3 y 4: Escribir observación y confirmar agrega al pedido
        await tester.enterText(
          find.byKey(const ValueKey('input_observacion_platillo')),
          'Sin cilantro por alergia',
        );
        await tester.pumpAndSettle();
        expect(find.text('24/200 caracteres'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('btn_agregar_al_pedido')));
        await tester.pumpAndSettle();

        expect(pedidoVm.cantidadDePlatillo(platillo.id), 2);
        expect(pedidoVm.observacionDePlatillo(platillo.id), 'Sin cilantro por alergia');
        expect(pedidoVm.subtotal, 390.00);
      },
    );
  });

  group('G24 · HU16-RF05: Edición de un platillo ya agregado', () {
    testWidgets(
      'Muestra badge de cantidad sobre imagen, botón "Editar", prellena datos, ofrece eliminar al llegar a 0 y actualiza "Pedido (n)" y "Mi pedido"',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final draft = ReservationDraftModel(restaurant: restaurant);
        final pedidoVm = PedidoViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: PersonalizeVisitView(
              restaurant: restaurant,
              draft: draft,
              pedidoViewModel: pedidoVm,
              platilloService: _FakePlatilloService([platillo]),
              ocasionService: _FakeOcasionService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inicialmente el badge dice "Pedido (0)" y el botón de la tarjeta es "Agregar"
        expect(find.text('Pedido (0)'), findsOneWidget);
        expect(find.byKey(ValueKey('btn_agregar_platillo_${platillo.id}')), findsOneWidget);
        expect(find.byKey(ValueKey('badge_cantidad_platillo_${platillo.id}')), findsNothing);

        // Abrir detalle y agregar 2 unidades con observación
        await tester.tap(find.byKey(ValueKey('btn_agregar_platillo_${platillo.id}')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('btn_incrementar_cantidad')));
        await tester.enterText(
          find.byKey(const ValueKey('input_observacion_platillo')),
          'Poco picante',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('btn_agregar_al_pedido')));
        await tester.pumpAndSettle();

        // HU16-RF05 Criterio 1 y 4: Badge con cantidad sobre imagen, botón "Editar", "Pedido (2)" y "Mi pedido"
        expect(find.byKey(ValueKey('badge_cantidad_platillo_${platillo.id}')), findsOneWidget);
        expect(find.byKey(ValueKey('btn_editar_platillo_${platillo.id}')), findsOneWidget);
        expect(find.text('Pedido (2)'), findsOneWidget);
        expect(find.byKey(const ValueKey('seccion_mi_pedido')), findsOneWidget);
        expect(find.text('Mi pedido'), findsOneWidget);
        expect(find.text('Observación: "Poco picante"'), findsOneWidget);

        // HU16-RF05 Criterio 2: "Editar" abre el mismo detalle prellenado con cantidad y observación guardadas
        await tester.tap(find.byKey(ValueKey('btn_editar_platillo_${platillo.id}')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('texto_cantidad_detalle')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('texto_cantidad_detalle'))).data,
          '2',
        );
        expect(find.text('Poco picante'), findsOneWidget);

        // HU16-RF05 Criterio 3: Si la cantidad llega a 0, se ofrece eliminar el platillo del pedido
        await tester.tap(find.byKey(const ValueKey('btn_decrementar_cantidad')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('btn_decrementar_cantidad')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('aviso_eliminar_platillo')), findsOneWidget);
        expect(find.text('Eliminar del pedido'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('btn_eliminar_del_pedido')));
        await tester.pumpAndSettle();

        // Se refleja de inmediato en "Pedido (0)" y desaparece de "Mi pedido"
        expect(find.text('Pedido (0)'), findsOneWidget);
        expect(find.byKey(const ValueKey('seccion_mi_pedido')), findsNothing);
        expect(find.byKey(ValueKey('btn_agregar_platillo_${platillo.id}')), findsOneWidget);
      },
    );

    testWidgets(
      'PlatilloMenuCard muestra badge de cantidad sobre imagen y botón "Editar" cuando cantidad > 0',
      (tester) async {
        bool editarPulsado = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatilloMenuCard(
                platillo: platillo,
                mode: PlatilloCardMode.preorden,
                cantidad: 3,
                observacion: 'Sin sal',
                onEditar: () => editarPulsado = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(ValueKey('badge_cantidad_platillo_${platillo.id}')), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.byKey(ValueKey('btn_editar_platillo_${platillo.id}')), findsOneWidget);
        expect(find.text('Editar'), findsOneWidget);

        await tester.tap(find.byKey(ValueKey('btn_editar_platillo_${platillo.id}')));
        await tester.pump();
        expect(editarPulsado, isTrue);
      },
    );
  });
}

