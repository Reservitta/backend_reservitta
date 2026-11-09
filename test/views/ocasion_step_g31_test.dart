import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/experiencia_model.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/viewmodels/ocasion_selection_viewmodel.dart';
import 'package:reservitta/viewmodels/pedido_viewmodel.dart';
import 'package:reservitta/views/widgets/ocasion_step.dart';

const _postreExp = ExperienciaModel(
  id: 'e_postre',
  nombre: 'Postre con felicitación',
  descripcionCorta: 'Mensaje escrito en tu postre',
  precio: 0,
  orden: 1,
);
const _globos = ExperienciaModel(
  id: 'e_globos',
  nombre: 'Globos',
  descripcionCorta: 'Decoración de la mesa',
  precio: 150,
  orden: 2,
);

OcasionModel _ocasion(String id, String nombre, {List<ExperienciaModel> exps = const []}) =>
    OcasionModel(
      id: id,
      restaurantId: 'r1',
      nombre: nombre,
      tipoPredefinido: OcasionModel.nombresPredefinidos.contains(nombre) ? nombre : 'Otro',
      descripcion: 'Descripción de $nombre',
      icono: OcasionModel.iconoPorNombre(nombre),
      experiencias: exps,
    );

PlatilloModel _postre(String id, String nombre, double precio) => PlatilloModel(
    id: id, categoriaId: 'cat_postres', nombre: nombre, descripcion: '', precio: precio);

void main() {
  final cumple = _ocasion('o1', 'Cumpleaños', exps: [_postreExp, _globos]);
  final aniversario = _ocasion('o2', 'Aniversario');
  final otro = _ocasion('o3', 'Otro');
  final pastel = _postre('pos1', 'Pastel', 80);
  final flan = _postre('pos2', 'Flan', 60);

  late PedidoViewModel pedido;
  late OcasionSelectionViewModel vm;
  var continuado = 0;

  Future<void> montar(WidgetTester tester, {PedidoViewModel? pedidoInicial}) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    pedido = pedidoInicial ?? PedidoViewModel();
    vm = OcasionSelectionViewModel(
      ocasiones: [cumple, aniversario, otro],
      pedido: pedido,
      catalogoPostres: [pastel, flan],
      categoriasPostre: const {'cat_postres'},
    );
    continuado = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OcasionStep(vm: vm, onContinuar: () => continuado++)),
    ));
    await tester.pumpAndSettle();
  }

  Finder k(String key) => find.byKey(ValueKey(key));

  group('HU18-RF02 tipo de ocasión', () {
    testWidgets('muestra una cuadrícula con ícono y descripción de cada ocasión', (tester) async {
      await montar(tester);
      expect(k('cuadricula_ocasiones'), findsOneWidget);
      for (final id in ['o1', 'o2', 'o3']) {
        expect(k('card_ocasion_$id'), findsOneWidget);
      }
      expect(find.text('Cumpleaños'), findsOneWidget);
      expect(find.text('Descripción de Cumpleaños'), findsOneWidget);
      expect(find.byIcon(Icons.cake_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
    });

    testWidgets('sin seleccionar nada el botón dice "No celebro nada especial, continuar"',
        (tester) async {
      await montar(tester);
      expect(find.text('No celebro nada especial, continuar'), findsOneWidget);
      expect(k('seccion_experiencias'), findsNothing);
      await tester.tap(k('btn_continuar_ocasion'));
      expect(continuado, 1);
      expect(vm.experienciasMaps, isEmpty);
    });

    testWidgets('al seleccionar una ocasión se resalta y se despliegan las experiencias', (tester) async {
      await montar(tester);
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(k('seccion_experiencias'), findsOneWidget);
      expect(find.text('Experiencias disponibles'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('No celebro nada especial, continuar'), findsNothing);
    });

    testWidgets('solo una ocasión a la vez', (tester) async {
      await montar(tester);
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();
      await tester.tap(k('card_ocasion_o2'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(vm.esSeleccionada(aniversario), isTrue);
      expect(vm.esSeleccionada(cumple), isFalse);
    });

    testWidgets('tocar la ocasión elegida la quita y vuelve el botón sin ocasión', (tester) async {
      await montar(tester);
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();
      expect(find.text('No celebro nada especial, continuar'), findsOneWidget);
    });

    testWidgets('"Otro" muestra el campo "Cuéntanos qué celebras"', (tester) async {
      await montar(tester);
      expect(k('campo_otro_detalle'), findsNothing);
      await tester.tap(k('card_ocasion_o3'));
      await tester.pumpAndSettle();
      expect(k('campo_otro_detalle'), findsOneWidget);
      expect(find.text('Cuéntanos qué celebras'), findsOneWidget);

      await tester.enterText(k('campo_otro_detalle'), 'Ascenso de Luis');
      expect(vm.ocasionEspecialMap!['detalle'], 'Ascenso de Luis');
    });

    testWidgets('las ocasiones distintas de "Otro" no piden detalle', (tester) async {
      await montar(tester);
      await tester.tap(k('card_ocasion_o2'));
      await tester.pumpAndSettle();
      expect(k('campo_otro_detalle'), findsNothing);
      expect(k('sin_experiencias'), findsOneWidget);
    });
  });

  group('HU18-RF03 experiencias', () {
    testWidgets('lista nombre, descripción y precio o "Gratis"', (tester) async {
      await montar(tester);
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();

      expect(find.text('Postre con felicitación'), findsOneWidget);
      expect(find.text('Mensaje escrito en tu postre'), findsOneWidget);
      expect(find.text('Globos'), findsOneWidget);
      expect(find.text('Decoración de la mesa'), findsOneWidget);
      expect(tester.widget<Text>(k('precio_exp_e_postre')).data, 'Gratis');
      expect(tester.widget<Text>(k('precio_exp_e_globos')).data, '\$150.00 MXN');
    });

    testWidgets('se pueden seleccionar varias con casillas y las de costo se suman', (tester) async {
      await montar(tester);
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();
      await tester.tap(k('check_exp_e_globos'));
      await tester.pumpAndSettle();

      expect(tester.widget<CheckboxListTile>(k('check_exp_e_globos')).value, isTrue);
      expect(tester.widget<Text>(k('total_experiencias')).data,
          'Experiencias con costo: \$150.00 MXN');

      await tester.tap(k('check_exp_e_postre'));
      await tester.pumpAndSettle();
      expect(vm.experienciasSeleccionadas, hasLength(2));
      // La gratuita no cambia el total.
      expect(vm.totalExperiencias, 150.0);
    });

    testWidgets('con una experiencia que pide información Continuar queda deshabilitado con aviso',
        (tester) async {
      await montar(tester);
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();
      await tester.tap(k('check_exp_e_postre'));
      await tester.pumpAndSettle();

      expect(k('aviso_info_pendiente'), findsOneWidget);
      expect(find.text('Completa la información de las experiencias seleccionadas para continuar'),
          findsOneWidget);
      expect(tester.widget<FilledButton>(k('btn_continuar_ocasion')).onPressed, isNull);
    });

    testWidgets('una experiencia sin requisitos deja continuar', (tester) async {
      await montar(tester);
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();
      await tester.tap(k('check_exp_e_globos'));
      await tester.pumpAndSettle();
      expect(k('aviso_info_pendiente'), findsNothing);
      await tester.tap(k('btn_continuar_ocasion'));
      expect(continuado, 1);
    });
  });

  group('HU18-RF04 postre con felicitación', () {
    Future<void> abrirHoja(WidgetTester tester) async {
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();
      await tester.tap(k('check_exp_e_postre'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_configurar_felicitaciones'));
      await tester.pumpAndSettle();
    }

    testWidgets('sin postres en el pedido pregunta en cuál y muestra el catálogo', (tester) async {
      await montar(tester);
      await abrirHoja(tester);

      expect(k('sheet_felicitaciones'), findsOneWidget);
      expect(find.text('¿En qué postre deseas la felicitación?'), findsOneWidget);
      expect(k('postre_catalogo_pos1'), findsOneWidget);
      expect(k('postre_catalogo_pos2'), findsOneWidget);
      expect(find.text('Postres en tu pedido'), findsNothing);
      expect(tester.widget<FilledButton>(k('btn_guardar_felicitaciones')).onPressed, isNull);
    });

    testWidgets('al elegir un postre se agrega al pedido con costo normal y pide su mensaje',
        (tester) async {
      await montar(tester);
      await abrirHoja(tester);
      await tester.tap(find.descendant(of: k('postre_catalogo_pos1'), matching: find.text('Elegir')));
      await tester.pumpAndSettle();

      expect(pedido.estaAgregado('pos1'), isTrue);
      expect(pedido.subtotal, 80.0);
      expect(k('felicitacion_pos1'), findsOneWidget);
      expect(find.text('Mensaje de felicitación'), findsOneWidget);
      expect(find.text('Guardar 1 felicitación'), findsOneWidget);
      expect(k('btn_agregar_otro_postre'), findsOneWidget);
    });

    testWidgets('con postres en el pedido se muestran primero "Postres en tu pedido"', (tester) async {
      final conPostre = PedidoViewModel()..agregarPlatillo(pastel);
      await montar(tester, pedidoInicial: conPostre);
      await abrirHoja(tester);

      expect(find.text('Postres en tu pedido'), findsOneWidget);
      expect(k('postre_pedido_pos1'), findsOneWidget);
      expect(find.text('¿En qué postre deseas la felicitación?'), findsNothing);

      final antes = pedido.subtotal;
      await tester.tap(find.descendant(of: k('postre_pedido_pos1'), matching: find.text('Felicitar')));
      await tester.pumpAndSettle();
      expect(pedido.subtotal, antes); // el total no cambia
      expect(k('felicitacion_pos1'), findsOneWidget);
    });

    testWidgets('permite agregar otro postre y cada uno tiene su campo de mensaje', (tester) async {
      await montar(tester);
      await abrirHoja(tester);
      await tester.tap(find.descendant(of: k('postre_catalogo_pos1'), matching: find.text('Elegir')));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_agregar_otro_postre'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: k('postre_catalogo_pos2'), matching: find.text('Elegir')));
      await tester.pumpAndSettle();

      expect(k('mensaje_pos1'), findsOneWidget);
      expect(k('mensaje_pos2'), findsOneWidget);
      expect(find.text('Guardar 2 felicitaciones'), findsOneWidget);
    });

    testWidgets('Guardar queda deshabilitado hasta escribir todos los mensajes', (tester) async {
      await montar(tester);
      await abrirHoja(tester);
      await tester.tap(find.descendant(of: k('postre_catalogo_pos1'), matching: find.text('Elegir')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(k('btn_guardar_felicitaciones')).onPressed, isNull);

      await tester.enterText(k('mensaje_pos1'), 'Feliz cumple Ana');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(k('btn_guardar_felicitaciones')).onPressed, isNotNull);
    });

    testWidgets('guardar asocia los mensajes a las líneas y habilita Continuar', (tester) async {
      await montar(tester);
      await abrirHoja(tester);
      await tester.tap(find.descendant(of: k('postre_catalogo_pos1'), matching: find.text('Elegir')));
      await tester.pumpAndSettle();
      await tester.enterText(k('mensaje_pos1'), 'Feliz cumple Ana');
      await tester.pumpAndSettle();
      await tester.tap(k('btn_guardar_felicitaciones'));
      await tester.pumpAndSettle();

      expect(k('sheet_felicitaciones'), findsNothing);
      expect(pedido.obtenerItem('pos1')!.mensajeFelicitacion, 'Feliz cumple Ana');
      expect(pedido.subtotal, 80.0); // solo el postre, el mensaje no cuesta
      expect(tester.widget<Text>(k('estado_felicitaciones')).data, '1 felicitación guardada');
      expect(k('aviso_info_pendiente'), findsNothing);
      expect(tester.widget<FilledButton>(k('btn_continuar_ocasion')).onPressed, isNotNull);
    });

    testWidgets('quitar un postre elegido lo saca del pedido si solo se agregó por la felicitación',
        (tester) async {
      await montar(tester);
      await abrirHoja(tester);
      await tester.tap(find.descendant(of: k('postre_catalogo_pos1'), matching: find.text('Elegir')));
      await tester.pumpAndSettle();
      await tester.tap(k('quitar_postre_pos1'));
      await tester.pumpAndSettle();

      expect(pedido.estaAgregado('pos1'), isFalse);
      expect(k('felicitacion_pos1'), findsNothing);
      expect(find.text('¿En qué postre deseas la felicitación?'), findsOneWidget);
    });

    testWidgets('si el restaurante no tiene postres lo indica', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sinPostres = OcasionSelectionViewModel(
        ocasiones: [cumple],
        pedido: PedidoViewModel(),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: OcasionStep(vm: sinPostres, onContinuar: () {})),
      ));
      await tester.tap(k('card_ocasion_o1'));
      await tester.pumpAndSettle();
      await tester.tap(k('check_exp_e_postre'));
      await tester.pumpAndSettle();
      await tester.tap(k('btn_configurar_felicitaciones'));
      await tester.pumpAndSettle();
      expect(k('sin_postres'), findsOneWidget);
    });
  });
}
