import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/theme/app_theme.dart';

double _luminancia(Color c) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

double contraste(Color a, Color b) {
  final la = _luminancia(a), lb = _luminancia(b);
  final claro = math.max(la, lb), oscuro = math.min(la, lb);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  group('Contraste (WCAG AA)', () {
    test('el texto normal llega a 4.5:1 sobre los fondos de la app', () {
      expect(
        contraste(AppColors.sobreMarca, AppColors.marca),
        greaterThanOrEqualTo(4.5),
      );
      for (final fondo in [AppColors.fondo, AppColors.superficie]) {
        expect(contraste(AppColors.texto, fondo), greaterThanOrEqualTo(4.5));
        expect(
          contraste(AppColors.textoSuave, fondo),
          greaterThanOrEqualTo(4.5),
        );
        expect(contraste(AppColors.marca, fondo), greaterThanOrEqualTo(4.5));
        expect(contraste(AppColors.acento, fondo), greaterThanOrEqualTo(4.5));
        expect(contraste(AppColors.error, fondo), greaterThanOrEqualTo(4.5));
        expect(contraste(AppColors.exito, fondo), greaterThanOrEqualTo(4.5));
      }
    });

    test('los bordes de los campos llegan a 3:1', () {
      expect(
        contraste(AppColors.borde, AppColors.fondo),
        greaterThanOrEqualTo(3),
      );
      expect(
        contraste(AppColors.borde, AppColors.superficie),
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('Tema', () {
    test('usa Material 3 y los colores de la marca', () {
      final tema = AppTheme.claro;
      expect(tema.useMaterial3, isTrue);
      expect(tema.colorScheme.primary, AppColors.marca);
      expect(tema.scaffoldBackgroundColor, AppColors.fondo);
    });

    test('los botones tienen una zona táctil de al menos 48 px', () {
      final tema = AppTheme.claro;
      final estilos = [
        tema.filledButtonTheme.style,
        tema.elevatedButtonTheme.style,
        tema.outlinedButtonTheme.style,
        tema.textButtonTheme.style,
        tema.iconButtonTheme.style,
      ];
      for (final estilo in estilos) {
        final minimo = estilo!.minimumSize!.resolve({})!;
        expect(minimo.height, greaterThanOrEqualTo(AppSpacing.zonaTactil));
        expect(minimo.width, greaterThanOrEqualTo(AppSpacing.zonaTactil));
      }
    });

    testWidgets('un botón sin tamaño propio mide al menos 48 px', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: Center(
              child: FilledButton(onPressed: () {}, child: const Text('Ok')),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets(
      'el campo de texto resalta el foco y muestra el error en rojo',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.claro,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Correo',
                    errorText: 'Escribe un correo',
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Escribe un correo'), findsOneWidget);
        final texto = tester.widget<Text>(find.text('Escribe un correo'));
        expect(texto.style?.color ?? AppColors.error, AppColors.error);
      },
    );
  });
}
