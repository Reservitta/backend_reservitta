import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/views/landing_view.dart';

void main() {
  testWidgets('landing page presents sign-in and registration actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LandingView()));

    expect(find.text('Bienvenido a Reservitta'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsNWidgets(2));
  });
}
