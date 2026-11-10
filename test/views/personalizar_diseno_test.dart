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

class _Platillos extends PlatilloService {
  @override
  Stream<List<PlatilloModel>> getPlatillosActivosStream(String restaurantId) => Stream.value(const []);
}

class _Ocasiones extends OcasionService {
  @override
  Future<List<OcasionModel>> getOcasiones(String restaurantId) async => const [];
}

void main() {
  const restaurante = RestaurantModel(id: 'r1', nombre: 'Miel', estado: 'activo');

  Future<void> abrir(WidgetTester tester, {double ancho = 1300, String? texto}) async {
    tester.view.physicalSize = Size(ancho, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: PersonalizeVisitView(
        restaurant: restaurante,
        draft: const ReservationDraftModel(restaurant: restaurante),
        pedidoViewModel: PedidoViewModel(),
        platilloService: _Platillos(),
        ocasionService: _Ocasiones(),
        isAuthenticated: true,
        textoConfirmar: texto ?? 'Confirmar reserva con personalización',

      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('el botón principal usa el texto indicado por quien abre la pantalla', (tester) async {
    await abrir(tester, texto: 'Guardar y volver al resumen');
    expect(find.text('Guardar y volver al resumen'), findsOneWidget);
    expect(find.text('Confirmar reserva con personalización'), findsNothing);
  });

  testWidgets('por defecto conserva el texto de confirmar la reserva', (tester) async {
    await abrir(tester);
    expect(find.text('Confirmar reserva con personalización'), findsOneWidget);
  });

  testWidgets('en pantalla ancha el botón queda a la derecha de la barra inferior', (tester) async {
    await abrir(tester);
    final boton = tester.getRect(find.byKey(const ValueKey('btn_confirmar_reserva_personalizada')));
    expect(boton.right, greaterThan(1200));
    expect(boton.width, lessThanOrEqualTo(380));
  });

  testWidgets('en pantalla angosta el botón ocupa el ancho', (tester) async {
    await abrir(tester, ancho: 500);
    final boton = tester.getRect(find.byKey(const ValueKey('btn_confirmar_reserva_personalizada')));
    expect(boton.width, greaterThan(400));
  });

  testWidgets('la pestaña de alergias muestra sus chips y las notas', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Alergias (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Alergias e intolerancias alimentarias'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chip_alergia_Gluten')));
    await tester.pumpAndSettle();
    expect(find.text('Alergias (1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('input_notas_alergias')), findsOneWidget);
  });
}
