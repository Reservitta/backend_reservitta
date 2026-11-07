import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/experiencia_model.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/viewmodels/ocasion_selection_viewmodel.dart';
import 'package:reservitta/viewmodels/pedido_viewmodel.dart';

const _postre = ExperienciaModel(
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
const _musica = ExperienciaModel(
  id: 'e_musica',
  nombre: 'Canción',
  precio: 80,
  orden: 3,
);
const _apagada = ExperienciaModel(
  id: 'e_off',
  nombre: 'Apagada',
  precio: 0,
  activo: false,
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

PlatilloModel _platillo(String id, String nombre, double precio, {String cat = 'cat_postres'}) =>
    PlatilloModel(id: id, categoriaId: cat, nombre: nombre, descripcion: '', precio: precio);

void main() {
  final cumple = _ocasion('o1', 'Cumpleaños', exps: [_globos, _postre, _apagada]);
  final aniversario = _ocasion('o2', 'Aniversario', exps: [_musica]);
  final otro = _ocasion('o3', 'Otro');

  final pastel = _platillo('pos1', 'Pastel', 80);
  final flan = _platillo('pos2', 'Flan', 60);
  final filete = _platillo('fil1', 'Filete', 250, cat: 'cat_fuertes');

  OcasionSelectionViewModel crear({
    PedidoViewModel? pedido,
    Map<String, dynamic>? inicial,
    List<Map<String, dynamic>> experiencias = const [],
  }) {
    return OcasionSelectionViewModel(
      ocasiones: [cumple, aniversario, otro],
      pedido: pedido ?? PedidoViewModel(),
      catalogoPostres: [pastel, flan],
      categoriasPostre: const {'cat_postres'},
      ocasionInicial: inicial,
      experienciasIniciales: experiencias,
    );
  }

  group('HU18-RF02 tipo de ocasión', () {
    test('sin elegir ninguna el botón avisa que se continúa sin experiencias', () {
      final vm = crear();
      expect(vm.hayOcasion, isFalse);
      expect(vm.textoContinuar, 'No celebro nada especial, continuar');
      expect(vm.ocasionEspecialMap, isNull);
      expect(vm.experienciasMaps, isEmpty);
      expect(vm.puedeContinuar, isTrue);
    });

    test('al elegir una ocasión el botón pasa a "Continuar"', () {
      final vm = crear()..seleccionarOcasion(cumple);
      expect(vm.textoContinuar, 'Continuar');
      expect(vm.esSeleccionada(cumple), isTrue);
    });

    test('solo una ocasión a la vez: elegir otra reemplaza la anterior', () {
      final vm = crear()..seleccionarOcasion(cumple)..seleccionarOcasion(aniversario);
      expect(vm.esSeleccionada(cumple), isFalse);
      expect(vm.esSeleccionada(aniversario), isTrue);
    });

    test('al cambiar de ocasión se limpian las experiencias', () {
      final vm = crear()
        ..seleccionarOcasion(cumple)
        ..toggleExperiencia(_globos)
        ..seleccionarOcasion(aniversario);
      expect(vm.experienciasSeleccionadas, isEmpty);
    });

    test('tocar la ocasión elegida la quita', () {
      final vm = crear()..seleccionarOcasion(cumple)..seleccionarOcasion(cumple);
      expect(vm.hayOcasion, isFalse);
      expect(vm.textoContinuar, OcasionSelectionViewModel.textoSinOcasion);
    });

    test('"Otro" pide qué se celebra y lo guarda limpio', () {
      final vm = crear()..seleccionarOcasion(otro);
      expect(vm.esOtro, isTrue);
      vm.setDetalleOtro('  Ascenso de Luis  ');
      expect(vm.detalleOtro, 'Ascenso de Luis');
      expect(vm.ocasionEspecialMap!['detalle'], 'Ascenso de Luis');
      vm.setDetalleOtro('x' * 150);
      expect(vm.detalleOtro.length, 100);
    });

    test('las demás ocasiones no piden detalle', () {
      final vm = crear()..seleccionarOcasion(cumple);
      expect(vm.esOtro, isFalse);
      expect(vm.ocasionEspecialMap!.containsKey('detalle'), isFalse);
      expect(vm.ocasionEspecialMap!['nombre'], 'Cumpleaños');
      expect(vm.ocasionEspecialMap!['icono'], 'cake');
    });

    test('restaura la ocasión y experiencias que ya traía el borrador', () {
      final vm = crear(
        inicial: {'ocasionId': 'o1', 'nombre': 'Cumpleaños'},
        experiencias: [
          {'experienciaId': 'e_globos'},
        ],
      );
      expect(vm.esSeleccionada(cumple), isTrue);
      expect(vm.experienciasSeleccionadas.map((e) => e.id), ['e_globos']);
    });
  });

  group('HU18-RF03 experiencias', () {
    test('lista las experiencias activas de la ocasión en su orden', () {
      final vm = crear()..seleccionarOcasion(cumple);
      expect(vm.experienciasDeOcasion.map((e) => e.nombre), ['Postre con felicitación', 'Globos']);
    });

    test('se pueden seleccionar varias', () {
      final vm = crear()
        ..seleccionarOcasion(aniversario)
        ..toggleExperiencia(_musica);
      expect(vm.experienciaMarcada(_musica), isTrue);
      vm.toggleExperiencia(_musica);
      expect(vm.experienciaMarcada(_musica), isFalse);

      final v2 = crear()
        ..seleccionarOcasion(cumple)
        ..toggleExperiencia(_globos)
        ..toggleExperiencia(_postre);
      expect(v2.experienciasSeleccionadas, hasLength(2));
    });

    test('las experiencias con costo se suman y las gratuitas no', () {
      final vm = crear()
        ..seleccionarOcasion(cumple)
        ..toggleExperiencia(_globos)
        ..toggleExperiencia(_postre);
      expect(vm.totalExperiencias, 150.0);
      expect(vm.experienciasMaps.map((e) => e['esGratis']), [true, false]);
    });

    test('sin ocasión no se puede marcar una experiencia', () {
      final vm = crear()..toggleExperiencia(_globos);
      expect(vm.experienciasSeleccionadas, isEmpty);
    });

    test('Continuar se deshabilita si falta información de una experiencia', () {
      final vm = crear()
        ..seleccionarOcasion(cumple)
        ..toggleExperiencia(_postre);
      expect(vm.informacionPendiente, isTrue);
      expect(vm.puedeContinuar, isFalse);
      expect(OcasionSelectionViewModel.avisoInformacionPendiente,
          'Completa la información de las experiencias seleccionadas para continuar');
    });

    test('una experiencia sin requisitos no bloquea', () {
      final vm = crear()
        ..seleccionarOcasion(cumple)
        ..toggleExperiencia(_globos);
      expect(vm.puedeContinuar, isTrue);
    });

    test('desmarcar la experiencia que pedía información vuelve a habilitar Continuar', () {
      final vm = crear()
        ..seleccionarOcasion(cumple)
        ..toggleExperiencia(_postre)
        ..toggleExperiencia(_postre);
      expect(vm.puedeContinuar, isTrue);
    });
  });

  group('HU18-RF04 postre con felicitación', () {
    late PedidoViewModel pedido;
    late OcasionSelectionViewModel vm;

    setUp(() {
      pedido = PedidoViewModel();
      vm = crear(pedido: pedido)
        ..seleccionarOcasion(cumple)
        ..toggleExperiencia(_postre);
    });

    test('reconoce los postres que ya están en el pedido', () {
      pedido.agregarPlatillo(filete);
      pedido.agregarPlatillo(pastel);
      expect(vm.postresEnPedido.map((i) => i.nombre), ['Pastel']);
      expect(vm.tienePostresEnPedido, isTrue);
    });

    test('sin postres en el pedido se ofrece el catálogo completo', () {
      expect(vm.tienePostresEnPedido, isFalse);
      expect(vm.postresParaAgregar.map((p) => p.nombre), ['Pastel', 'Flan']);
    });

    test('elegir un postre del catálogo lo agrega al pedido con su costo normal', () {
      expect(pedido.subtotal, 0);
      vm.elegirPostre(pastel);
      expect(pedido.estaAgregado('pos1'), isTrue);
      expect(pedido.subtotal, 80.0);
      expect(vm.postresFelicitados, ['pos1']);
    });

    test('felicitar un postre que ya estaba en el pedido no cambia el total', () {
      pedido.agregarPlatillo(pastel);
      final antes = pedido.subtotal;
      vm.elegirPostreDelPedido(pedido.items.first);
      vm.setMensaje('pos1', 'Feliz cumple Ana');
      vm.guardarFelicitaciones();
      expect(pedido.subtotal, antes);
    });

    test('el mensaje nunca tiene costo', () {
      vm.elegirPostre(pastel);
      final antes = pedido.subtotal;
      vm.setMensaje('pos1', 'Feliz cumple Ana');
      vm.guardarFelicitaciones();
      expect(pedido.subtotal, antes);
    });

    test('cada postre tiene su propio mensaje', () {
      vm.elegirPostre(pastel);
      vm.elegirPostre(flan);
      vm.setMensaje('pos1', 'Feliz cumple Ana');
      vm.setMensaje('pos2', 'Felicidades Luis');
      expect(vm.mensajeDe('pos1'), 'Feliz cumple Ana');
      expect(vm.mensajeDe('pos2'), 'Felicidades Luis');
    });

    test('el botón dice cuántas felicitaciones guarda', () {
      vm.elegirPostre(pastel);
      expect(vm.textoGuardarFelicitaciones, 'Guardar 1 felicitación');
      vm.elegirPostre(flan);
      expect(vm.textoGuardarFelicitaciones, 'Guardar 2 felicitaciones');
    });

    test('no se puede guardar si algún postre no tiene mensaje', () {
      vm.elegirPostre(pastel);
      vm.elegirPostre(flan);
      vm.setMensaje('pos1', 'Feliz cumple Ana');
      expect(vm.puedeGuardarFelicitaciones, isFalse);
      expect(vm.guardarFelicitaciones(), isFalse);
      vm.setMensaje('pos2', 'Felicidades Luis');
      expect(vm.puedeGuardarFelicitaciones, isTrue);
    });

    test('guardar asocia el mensaje a cada línea de postre del pedido', () {
      vm.elegirPostre(pastel);
      vm.elegirPostre(flan);
      vm.setMensaje('pos1', '  Feliz cumple Ana ');
      vm.setMensaje('pos2', 'Felicidades Luis');
      expect(vm.guardarFelicitaciones(), isTrue);

      expect(pedido.obtenerItem('pos1')!.mensajeFelicitacion, 'Feliz cumple Ana');
      expect(pedido.obtenerItem('pos2')!.mensajeFelicitacion, 'Felicidades Luis');
      expect(pedido.preordenItems.map((m) => m['mensajeFelicitacion']),
          ['Feliz cumple Ana', 'Felicidades Luis']);
      expect(vm.felicitacionesGuardadas, 2);
    });

    test('con las felicitaciones guardadas se puede continuar', () {
      expect(vm.puedeContinuar, isFalse);
      vm.elegirPostre(pastel);
      vm.setMensaje('pos1', 'Feliz cumple Ana');
      vm.guardarFelicitaciones();
      expect(vm.puedeContinuar, isTrue);
      expect(vm.informacionPendiente, isFalse);
    });

    test('el mensaje se recorta a 100 caracteres', () {
      vm.elegirPostre(pastel);
      vm.setMensaje('pos1', 'x' * 150);
      expect(vm.mensajeDe('pos1').length, 100);
    });

    test('quitar un postre agregado solo para felicitar lo saca del pedido', () {
      vm.elegirPostre(pastel);
      vm.quitarPostre('pos1');
      expect(pedido.estaAgregado('pos1'), isFalse);
      expect(vm.postresFelicitados, isEmpty);
    });

    test('quitar un postre que ya estaba en el pedido no lo borra', () {
      pedido.agregarPlatillo(pastel);
      vm.elegirPostreDelPedido(pedido.items.first);
      vm.quitarPostre('pos1');
      expect(pedido.estaAgregado('pos1'), isTrue);
    });

    test('al desmarcar la experiencia se deshace lo agregado por la felicitación', () {
      vm.elegirPostre(pastel);
      vm.setMensaje('pos1', 'Feliz cumple Ana');
      vm.guardarFelicitaciones();
      vm.toggleExperiencia(_postre);
      expect(pedido.estaAgregado('pos1'), isFalse);
      expect(vm.felicitacionesGuardadas, 0);
    });

    test('cambiar de ocasión también deshace las felicitaciones', () {
      vm.elegirPostre(pastel);
      vm.seleccionarOcasion(aniversario);
      expect(pedido.estaAgregado('pos1'), isFalse);
    });

    test('editar la cantidad de un postre conserva su mensaje', () {
      vm.elegirPostre(pastel);
      vm.setMensaje('pos1', 'Feliz cumple Ana');
      vm.guardarFelicitaciones();
      pedido.editarPlatillo('pos1', cantidad: 2);
      pedido.guardarPlatillo(pastel, cantidad: 3);
      expect(pedido.obtenerItem('pos1')!.mensajeFelicitacion, 'Feliz cumple Ana');
      expect(pedido.obtenerItem('pos1')!.cantidad, 3);
    });

    test('restaura las felicitaciones que ya estaban en el pedido', () {
      final p2 = PedidoViewModel(initialItems: [
        {
          'platilloId': 'pos1',
          'nombre': 'Pastel',
          'precio': 80.0,
          'cantidad': 1,
          'categoriaId': 'cat_postres',
          'mensajeFelicitacion': 'Feliz cumple Ana',
        },
      ]);
      final restaurado = crear(
        pedido: p2,
        inicial: {'ocasionId': 'o1', 'nombre': 'Cumpleaños'},
        experiencias: [
          {'experienciaId': 'e_postre'},
        ],
      );
      expect(restaurado.felicitacionesGuardadas, 1);
      expect(restaurado.mensajeDe('pos1'), 'Feliz cumple Ana');
      expect(restaurado.puedeContinuar, isTrue);
    });
  });
}
