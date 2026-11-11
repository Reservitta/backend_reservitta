import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/views/widgets/branch_picker_dialog.dart';

const _horario = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');

RestaurantModel _restaurante() => RestaurantModel(
      id: 'r1',
      nombre: 'Miel Test',
      estado: 'activo',
      horarios: {
        for (final d in [
          'lunes',
          'martes',
          'miercoles',
          'jueves',
          'viernes',
          'sabado',
          'domingo',
        ])
          d: _horario,
      },
    );

void main() {
  late FakeFirebaseFirestore db;
  BranchModel? elegida;
  var cerro = false;

  setUp(() {
    db = FakeFirebaseFirestore();
    elegida = null;
    cerro = false;
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                elegida = await BranchPickerDialog.show(
                  context,
                  restaurant: _restaurante(),
                  service: RestaurantService(firestore: db),
                  clock: () => DateTime(2026, 10, 30, 14),
                );
                cerro = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> sucursales(List<Map<String, dynamic>> lista) async {
    for (var i = 0; i < lista.length; i++) {
      await db
          .collection('restaurants')
          .doc('r1')
          .collection('sucursales')
          .doc('s$i')
          .set(lista[i]);
    }
  }

  testWidgets('lista las sucursales y no deja continuar hasta elegir una', (tester) async {
    await sucursales([
      {'nombre': 'Centro', 'direccion': 'Calle 1'},
      {'nombre': 'Norte', 'direccion': 'Calle 2'},
    ]);
    await abrir(tester);

    expect(find.text('Elige la sucursal'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('Norte'), findsOneWidget);
    expect(find.text('Abierto hasta 22:00'), findsNWidgets(2));

    var continuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_sucursal')));
    expect(continuar.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('sucursal_s1')));
    await tester.pumpAndSettle();
    continuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_sucursal')));
    expect(continuar.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('btn_continuar_sucursal')));
    await tester.pumpAndSettle();
    expect(cerro, isTrue);
    expect(elegida?.nombre, 'Norte');
  });

  testWidgets('con una sola sucursal ya viene elegida', (tester) async {
    await sucursales([
      {'nombre': 'Centro', 'direccion': 'Calle 1'},
    ]);
    await abrir(tester);

    final continuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_sucursal')));
    expect(continuar.onPressed, isNotNull);
  });

  testWidgets('sin sucursales avisa y no permite continuar', (tester) async {
    await abrir(tester);

    expect(find.byKey(const ValueKey('sin_sucursales')), findsOneWidget);
    expect(find.text('Este restaurante aún no tiene sucursales disponibles'), findsOneWidget);
    final continuar = tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_sucursal')));
    expect(continuar.onPressed, isNull);
  });

  testWidgets('cancelar cierra la ventana sin elegir sucursal', (tester) async {
    await sucursales([
      {'nombre': 'Centro', 'direccion': 'Calle 1'},
    ]);
    await abrir(tester);

    await tester.tap(find.byKey(const ValueKey('btn_cancelar_sucursal')));
    await tester.pumpAndSettle();
    expect(find.text('Elige la sucursal'), findsNothing);
    expect(cerro, isTrue);
    expect(elegida, isNull);
  });
}
