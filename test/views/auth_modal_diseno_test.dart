import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/viewmodels/auth_modal_viewmodel.dart';
import 'package:reservitta/views/auth_modal_dialog.dart';

void main() {
  Future<void> abrir(
    WidgetTester tester, {
    double ancho = 1300,
    AuthMode modo = AuthMode.login,
  }) async {
    tester.view.physicalSize = Size(ancho, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AuthModalDialog(initialMode: modo))));
    await tester.pumpAndSettle();
  }

  group('Inicio de sesión y registro: panel de marca', () {
    testWidgets('en pantalla ancha muestra el panel de marca junto al formulario', (tester) async {
      await abrir(tester);

      expect(find.text('Qué bueno verte de nuevo'), findsOneWidget);
      expect(find.text('Reserva en segundos'), findsOneWidget);
      // El formulario sigue ahí.
      expect(find.text('Correo Electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);

      final panel = tester.getRect(find.text('Qué bueno verte de nuevo'));
      final campo = tester.getRect(find.text('Correo Electrónico'));
      expect(panel.right, lessThan(campo.left), reason: 'la marca queda a la izquierda');
    });

    testWidgets('en pantalla angosta solo se ve el formulario', (tester) async {
      await abrir(tester, ancho: 500);

      expect(find.text('Qué bueno verte de nuevo'), findsNothing);
      expect(find.text('Correo Electrónico'), findsOneWidget);
    });

    testWidgets('el panel cambia según el rol elegido al registrarse',
        (tester) async {
      await abrir(tester, modo: AuthMode.registerRoleSelection);
      expect(find.text('Tu mesa, sin complicaciones'), findsOneWidget);

      await tester.tap(find.text('Administrador de Restaurante'));
      await tester.pumpAndSettle();
      expect(find.text('Haz crecer tu restaurante'), findsOneWidget);
      expect(find.text('Tu mesa, sin complicaciones'), findsNothing);
    });

    testWidgets('al recuperar la contraseña el panel invita a revisar el correo', (tester) async {
      await abrir(tester, modo: AuthMode.forgotPassword);
      expect(find.text('Recupera tu acceso'), findsOneWidget);
    });
  });

  group('Contraseña visible u oculta', () {
    testWidgets('el ojo del inicio de sesión muestra y oculta la contraseña', (tester) async {
      await abrir(tester);

      bool oculta() => tester
          .widget<TextField>(find.widgetWithText(TextField, 'Contraseña'))
          .obscureText;

      expect(oculta(), isTrue);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pumpAndSettle();
      expect(oculta(), isFalse);
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);

      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pumpAndSettle();
      expect(oculta(), isTrue);
    });
  });
}
