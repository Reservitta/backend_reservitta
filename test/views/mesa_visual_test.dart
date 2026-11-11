import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/views/widgets/mesa_visual.dart';

double _lum(Color c) {
  double canal(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

double _contraste(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const paletas = {
    'libre': MesaPaleta.libre,
    'ocupada': MesaPaleta.ocupada,
    'combinada': MesaPaleta.combinada,
    'fuera de servicio': MesaPaleta.fueraDeServicio,
    'no adecuada': MesaPaleta.noAdecuada,
    'seleccionada': MesaPaleta.seleccionada,
    'editor': MesaPaleta.editor,
    'editor seleccionada': MesaPaleta.editorSeleccionada,
    'editor con error': MesaPaleta.editorConError,
  };
  const piso = Color(0xFFF6F1E9);

  group('Paleta de las mesas', () {
    paletas.forEach((nombre, p) {
      test('$nombre: el texto se lee sobre la mesa (4.5:1)', () {
        expect(_contraste(p.texto, p.superficie), greaterThanOrEqualTo(4.5));
      });
      test('$nombre: el borde se distingue del piso (3:1)', () {
        expect(_contraste(p.borde, piso), greaterThanOrEqualTo(3));
      });
    });

    test('los estados principales se distinguen entre sí por su borde', () {
      final bordes = {
        MesaPaleta.libre.borde,
        MesaPaleta.ocupada.borde,
        MesaPaleta.combinada.borde,
        MesaPaleta.fueraDeServicio.borde,
        MesaPaleta.noAdecuada.borde,
      };
      expect(bordes, hasLength(5));
    });
  });

  group('MesaVisual', () {
    Future<void> pintar(WidgetTester tester, MesaModel mesa, {bool seleccionada = false}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: mesa.ancho,
              height: mesa.alto,
              child: MesaVisual(
                mesa: mesa,
                paleta: MesaPaleta.libre,
                icono: Icons.check_circle_outline,
                seleccionada: seleccionada,
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('muestra nombre, capacidad e ícono', (tester) async {
      await pintar(tester, const MesaModel(id: 'a', nombre: 'M1', capacidad: 4, x: 0, y: 0));
      expect(find.text('M1'), findsOneWidget);
      expect(find.text('4 pers.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('dibuja tantas sillas como capacidad', (tester) async {
      const mesa = MesaModel(id: 'a', nombre: 'M1', capacidad: 6, x: 0, y: 0);
      await pintar(tester, mesa);
      final pintor = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<SillasPainter>()
          .single;
      expect(pintor.capacidad, 6);
      expect(SillasPainter.posiciones(6, mesa.forma, Size(mesa.ancho, mesa.alto)), hasLength(6));
    });

    testWidgets('una mesa redonda es un círculo y una cuadrada un rectángulo', (tester) async {
      await pintar(tester, const MesaModel(id: 'a', nombre: 'R', capacidad: 4, forma: 'redonda', x: 0, y: 0));
      var caja = tester.widget<Container>(find.descendant(of: find.byType(MesaVisual), matching: find.byType(Container)).first);
      expect((caja.decoration as BoxDecoration).shape, BoxShape.circle);

      await pintar(tester, const MesaModel(id: 'b', nombre: 'C', capacidad: 4, forma: 'cuadrada', x: 0, y: 0));
      caja = tester.widget<Container>(find.descendant(of: find.byType(MesaVisual), matching: find.byType(Container)).first);
      expect((caja.decoration as BoxDecoration).shape, BoxShape.rectangle);
    });

    testWidgets('la mesa seleccionada tiene el borde más grueso', (tester) async {
      const mesa = MesaModel(id: 'a', nombre: 'M1', capacidad: 4, x: 0, y: 0);
      await pintar(tester, mesa);
      var caja = tester.widget<Container>(find.descendant(of: find.byType(MesaVisual), matching: find.byType(Container)).first);
      final normal = ((caja.decoration as BoxDecoration).border as Border).top.width;

      await pintar(tester, mesa, seleccionada: true);
      caja = tester.widget<Container>(find.descendant(of: find.byType(MesaVisual), matching: find.byType(Container)).first);
      final marcada = ((caja.decoration as BoxDecoration).border as Border).top.width;
      expect(marcada, greaterThan(normal));
    });
  });
}
