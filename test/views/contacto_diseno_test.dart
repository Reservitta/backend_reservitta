import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/views/widgets/contact_form_step.dart';

void main() {
  Future<void> abrir(WidgetTester tester, double ancho) async {
    tester.view.physicalSize = Size(ancho, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ContactFormStep(
            draft: const ReservationDraftModel(
              restaurant: RestaurantModel(id: 'r1', nombre: 'Miel', estado: 'activo'),
            ),
            isAuthenticated: false,
            onNameChanged: (_) {},
            onEmailChanged: (_) {},
            onPhoneChanged: (_) {},
            onCreateAccountChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('en pantalla ancha el nombre y el correo van lado a lado', (tester) async {
    await abrir(tester, 1000);
    final nombre = tester.getRect(find.byKey(const ValueKey('input_contact_nombre')));
    final correo = tester.getRect(find.byKey(const ValueKey('input_contact_correo')));
    expect(correo.left, greaterThan(nombre.right));
    expect((correo.top - nombre.top).abs(), lessThan(2));
  });

  testWidgets('en pantalla angosta los campos van uno debajo del otro', (tester) async {
    await abrir(tester, 480);
    final nombre = tester.getRect(find.byKey(const ValueKey('input_contact_nombre')));
    final correo = tester.getRect(find.byKey(const ValueKey('input_contact_correo')));
    final telefono = tester.getRect(find.byKey(const ValueKey('input_contact_telefono')));
    expect(correo.top, greaterThan(nombre.bottom));
    expect(telefono.top, greaterThan(correo.bottom));
  });
}
