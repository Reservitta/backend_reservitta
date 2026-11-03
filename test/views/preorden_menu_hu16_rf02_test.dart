import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/categoria_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/views/widgets/platillo_menu_card.dart';

void main() {
  group('HU16-RF02: Reutilización del menú existente para el preorden', () {
    final platillo = PlatilloModel(
      id: 'platillo_10',
      categoriaId: 'cat_entradas',
      nombre: 'Ceviche Mixto',
      descripcion: 'Pescado blanco, camarón, cebolla morada y cilantro',
      precio: 185.00,
      permitePersonalizacion: true,
      placeholderObservacion: 'Sin picante',
      limiteCaracteresObs: 120,
    );

    testWidgets('PlatilloMenuCard en modo readOnly (HU06-RF03) no muestra controles de cantidad ni botón Agregar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatilloMenuCard(
              platillo: platillo,
              mode: PlatilloCardMode.readOnly,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ceviche Mixto'), findsOneWidget);
      expect(find.text('\$185.00 MXN'), findsOneWidget);
      expect(find.text('Personalizable'), findsOneWidget);

      // En modo solo consulta NO existe botón agregar ni controles de cantidad
      expect(find.byKey(ValueKey('btn_agregar_platillo_${platillo.id}')), findsNothing);
      expect(find.byKey(ValueKey('btn_incrementar_platillo_${platillo.id}')), findsNothing);
      expect(find.byKey(ValueKey('btn_decrementar_platillo_${platillo.id}')), findsNothing);
    });

    testWidgets('PlatilloMenuCard en modo preorden (HU16-RF02) muestra botón "Agregar" y controles de cantidad', (tester) async {
      bool agregarPulsado = false;
      bool incrementarPulsado = false;
      bool decrementarPulsado = false;

      // Estado 1: Cantidad 0 -> Muestra botón Agregar
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatilloMenuCard(
              platillo: platillo,
              mode: PlatilloCardMode.preorden,
              cantidad: 0,
              onAgregar: () => agregarPulsado = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnAgregar = find.byKey(ValueKey('btn_agregar_platillo_${platillo.id}'));
      expect(btnAgregar, findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);

      await tester.tap(btnAgregar);
      await tester.pump();
      expect(agregarPulsado, isTrue);

      // Estado 2: Cantidad > 0 -> Muestra stepper [-] [2] [+]
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatilloMenuCard(
              platillo: platillo,
              mode: PlatilloCardMode.preorden,
              cantidad: 2,
              onIncrementar: () => incrementarPulsado = true,
              onDecrementar: () => decrementarPulsado = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('btn_agregar_platillo_${platillo.id}')), findsNothing);
      expect(find.byKey(ValueKey('txt_cantidad_platillo_${platillo.id}')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('btn_incrementar_platillo_${platillo.id}')));
      await tester.pump();
      expect(incrementarPulsado, isTrue);

      await tester.tap(find.byKey(ValueKey('btn_decrementar_platillo_${platillo.id}')));
      await tester.pump();
      expect(decrementarPulsado, isTrue);
    });

    test('Consistencia de modelo: PlatilloModel genera snapshot de preorden sin duplicar estructuras', () {
      final snapshot = platillo.toPreordenItemSnapshot(
        cantidad: 3,
        observacion: 'Cebolla aparte',
      );

      expect(snapshot['platilloId'], equals('platillo_10'));
      expect(snapshot['nombre'], equals('Ceviche Mixto'));
      expect(snapshot['precio'], equals(185.00));
      expect(snapshot['cantidad'], equals(3));
      expect(snapshot['total'], equals(555.00));
      expect(snapshot['observacion'], equals('Cebolla aparte'));
    });
  });
}

