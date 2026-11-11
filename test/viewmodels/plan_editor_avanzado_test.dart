import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/elemento_plano.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/table_layout_validator.dart';
import 'package:reservitta/services/table_layout_service.dart';
import 'package:reservitta/viewmodels/plan_editor_viewmodel.dart';

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  late FakeFirebaseFirestore db;
  late TableLayoutService svc;

  setUp(() {
    db = FakeFirebaseFirestore();
    svc = TableLayoutService(firestore: db, now: () => DateTime(2026, 11, 8, 12));
  });

  Future<PlanEditorViewModel> crear() async {
    final vm = PlanEditorViewModel(restaurantId: 'r1', service: svc);
    addTearDown(vm.dispose);
    await vm.cargar();
    return vm;
  }

  group('Paleta de mesas', () {
    test('hay mesas de 1 a 10 sillas, redondas, cuadradas, rectangulares, altas y sillones', () {
      final formas = PlanEditorViewModel.presetsMesa.map((p) => p.forma).toSet();
      expect(formas, {MesaModel.formaRedonda, MesaModel.formaCuadrada, MesaModel.formaRectangular});
      final tipos = PlanEditorViewModel.presetsMesa.map((p) => p.tipo).toSet();
      expect(tipos, containsAll([MesaModel.tipoRegular, MesaModel.tipoBarra, MesaModel.tipoAlta, MesaModel.tipoSillon]));
      expect(PlanEditorViewModel.presetsMesa.map((p) => p.capacidad), containsAll([1, 2, 4, 6, 8, 10]));
    });

    test('cada mesa de la paleta cumple las reglas de tamaño y sillas', () {
      for (final p in PlanEditorViewModel.presetsMesa) {
        expect(p.ancho, inInclusiveRange(TableLayoutValidator.tamanoMinimo, TableLayoutValidator.tamanoMaximo), reason: p.id);
        expect(p.alto, inInclusiveRange(TableLayoutValidator.tamanoMinimo, TableLayoutValidator.tamanoMaximo), reason: p.id);
        expect(p.capacidad, inInclusiveRange(1, TableLayoutValidator.capacidadMaxima), reason: p.id);
      }
    });

    test('agregar una mesa de la paleta usa su forma, sillas, tamaño y tipo', () async {
      final vm = await crear();
      final banqueta = PlanEditorViewModel.presetsMesa.firstWhere((p) => p.id == 'banqueta');
      final m = vm.agregarPreset(banqueta);
      expect(m.capacidad, 1);
      expect(m.tipo, MesaModel.tipoBarra);
      expect(m.forma, MesaModel.formaRedonda);
      expect(vm.seleccionadaId, m.id);
      expect(vm.erroresDe(m.id), isEmpty);
    });
  });

  group('Rotación', () {
    test('girar suma grados y da la vuelta a 360', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.rotarMesa(m.id, 90);
      expect(vm.mesas.single.rotacion, 90);
      vm.rotarMesa(m.id, 300);
      expect(vm.mesas.single.rotacion, 30);
      vm.rotarMesa(m.id, -45);
      expect(vm.mesas.single.rotacion, 345);
    });

    test('la caja de una mesa rectangular girada 90° intercambia ancho y alto', () {
      const m = MesaModel(id: 'a', nombre: 'A', capacidad: 6, forma: 'rectangular', ancho: 200, alto: 100, x: 100, y: 100, rotacion: 90);
      expect(m.cajaRotada.width, closeTo(100, 0.001));
      expect(m.cajaRotada.height, closeTo(200, 0.001));
      expect(m.cajaRotada.center.dx, closeTo(200, 0.001));
    });

    test('un giro fuera de rango no se acepta al validar', () {
      const m = MesaModel(id: 'a', nombre: 'A', capacidad: 4, x: 0, y: 0, rotacion: 400);
      expect(TableLayoutValidator.validarMesa(m, otras: const [], zonaIds: const {}).keys, contains('rotacion'));
    });

    test('el giro se guarda y se recupera', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.fijarRotacionMesa(m.id, 45);
      expect(await vm.guardar(), isTrue);
      final otra = await crear();
      expect(otra.mesas.single.rotacion, 45);
    });
  });

  group('Tipo y mínimo / máximo de personas', () {
    test('por defecto acepta de 1 persona al número de sillas', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      expect(m.minPersonas, 1);
      expect(m.maxEfectivo, m.capacidad);
      expect(m.admite(1), isTrue);
      expect(m.admite(m.capacidad), isTrue);
      expect(m.admite(m.capacidad + 1), isFalse);
    });

    test('con mínimo 2 y máximo 3 una mesa de 4 sillas no acepta 1 ni 4', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.cambiarMinimo(m.id, 2);
      vm.cambiarMaximo(m.id, 3);
      final c = vm.mesas.single;
      expect([c.admite(1), c.admite(2), c.admite(3), c.admite(4)], [false, true, true, false]);
    });

    test('quitar sillas ajusta el mínimo y el máximo para que no pasen de las sillas', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.cambiarMinimo(m.id, 3);
      vm.cambiarMaximo(m.id, 4);
      vm.cambiarCapacidad(m.id, 2);
      final c = vm.mesas.single;
      expect(c.minPersonas, lessThanOrEqualTo(2));
      expect(c.maxEfectivo, lessThanOrEqualTo(2));
      expect(vm.erroresDe(c.id), isEmpty);
    });

    test('cambiar el tipo se refleja y un tipo inválido se ignora', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.cambiarTipo(m.id, MesaModel.tipoAlta);
      expect(vm.mesas.single.tipo, MesaModel.tipoAlta);
      vm.cambiarTipo(m.id, 'volador');
      expect(vm.mesas.single.tipo, MesaModel.tipoAlta);
    });

    test('tipo, mínimo y máximo se guardan y se recuperan', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.cambiarTipo(m.id, MesaModel.tipoSillon);
      vm.cambiarMinimo(m.id, 2);
      vm.cambiarMaximo(m.id, 3);
      expect(await vm.guardar(), isTrue);
      final c = (await crear()).mesas.single;
      expect([c.tipo, c.minPersonas, c.maxPersonas], [MesaModel.tipoSillon, 2, 3]);
    });
  });

  group('Elementos decorativos', () {
    test('se agregan con el tamaño y texto de su tipo y quedan seleccionados', () async {
      final vm = await crear();
      final barra = vm.agregarElemento(ElementoPlano.barra);
      expect(barra.etiqueta, 'Barra');
      expect(barra.ancho, ElementoPlano.estilo(ElementoPlano.barra).ancho);
      expect(vm.elementoSeleccionadoId, barra.id);
      expect(vm.seleccionadaId, isNull);
      expect(vm.hayCambios, isTrue);
    });

    test('un tipo desconocido se vuelve texto', () async {
      final vm = await crear();
      expect(vm.agregarElemento('dragon').tipo, ElementoPlano.texto);
    });

    test('se pueden mover, girar, cambiar de tamaño, escribir y borrar', () async {
      final vm = await crear();
      final e = vm.agregarElemento(ElementoPlano.texto);
      vm.arrastrarElemento(e.id, 100, 50);
      vm.soltarElemento(e.id);
      vm.rotarElemento(e.id, 90);
      vm.cambiarTamanoElemento(e.id, ancho: 300);
      vm.cambiarTextoElemento(e.id, 'Terraza');
      final c = vm.elementos.single;
      expect(c.rotacion, 90);
      expect(c.ancho, 300);
      expect(c.etiqueta, 'Terraza');
      expect(c.x % PlanEditorViewModel.paso, 0);
      vm.eliminarElemento(e.id);
      expect(vm.elementos, isEmpty);
    });

    test('una planta o columna conserva lados iguales', () async {
      final vm = await crear();
      final e = vm.agregarElemento(ElementoPlano.planta);
      vm.cambiarTamanoElemento(e.id, ancho: 90);
      expect(vm.elementos.single.alto, 90);
    });

    test('se guardan, se recuperan y quedan en el historial', () async {
      final vm = await crear();
      vm.agregarMesa();
      final e = vm.agregarElemento(ElementoPlano.cocina);
      vm.cambiarTextoElemento(e.id, 'Cocina abierta');
      expect(await vm.guardar(), isTrue);

      final otra = await crear();
      expect(otra.elementos, hasLength(1));
      expect(otra.elementos.single.etiqueta, 'Cocina abierta');
      expect(otra.hayCambios, isFalse);

      final historial = await otra.historial();
      expect(historial, hasLength(1));
      expect(historial.single.resumen, contains('1 mesa nueva'));
      expect(historial.single.resumen, contains('1 elemento de decoración'));
    });

    test('quitar un elemento y guardar lo borra', () async {
      final vm = await crear();
      final e = vm.agregarElemento(ElementoPlano.barra);
      expect(await vm.guardar(), isTrue);
      final otra = await crear();
      otra.eliminarElemento(otra.elementos.single.id);
      expect(await otra.guardar(), isTrue);
      expect((await crear()).elementos, isEmpty);
      expect(e, isNotNull);
    });

    test('un elemento fuera de medida no se guarda', () async {
      await expectLater(
        svc.guardarPlano(
          restauranteId: 'r1',
          mesas: const [],
          elementos: const [
            ElementoPlano(id: 'x', tipo: 'barra', x: 0, y: 0, ancho: 5000, alto: 60),
          ],
        ),
        throwsA(isA<LayoutException>()),
      );
    });

    test('guardar sin pasar elementos no borra los que ya hay', () async {
      await svc.guardarPlano(
        restauranteId: 'r1',
        mesas: const [],
        elementos: const [ElementoPlano(id: '', tipo: 'barra', x: 10, y: 10, ancho: 200, alto: 60)],
      );
      await svc.guardarPlano(restauranteId: 'r1', mesas: const []);
      expect(await svc.getElementos('r1'), hasLength(1));
    });

    test('un espacio con decoración no se puede eliminar', () async {
      final vm = await crear();
      await vm.agregarZona('Patio');
      vm.agregarElemento(ElementoPlano.planta);
      final zona = vm.zonas.single;
      final error = await vm.eliminarZona(zona.id);
      expect(error, contains('elemento'));
    });
  });

  group('Deshacer y rehacer', () {
    test('deshacer quita lo último y rehacer lo devuelve', () async {
      final vm = await crear();
      vm.agregarMesa();
      vm.agregarMesa(forma: MesaModel.formaRedonda);
      expect(vm.mesas, hasLength(2));
      expect(vm.puedeDeshacer, isTrue);

      vm.deshacer();
      expect(vm.mesas, hasLength(1));
      expect(vm.puedeRehacer, isTrue);
      vm.rehacer();
      expect(vm.mesas, hasLength(2));
      expect(vm.puedeRehacer, isFalse);
    });

    test('deshacer todo deja el plano como estaba y sin cambios', () async {
      final vm = await crear();
      vm.agregarMesa();
      vm.agregarElemento(ElementoPlano.barra);
      vm.deshacer();
      vm.deshacer();
      expect(vm.mesas, isEmpty);
      expect(vm.elementos, isEmpty);
      expect(vm.hayCambios, isFalse);
      expect(vm.puedeDeshacer, isFalse);
    });

    test('un cambio nuevo borra lo que se podía rehacer', () async {
      final vm = await crear();
      vm.agregarMesa();
      vm.deshacer();
      expect(vm.puedeRehacer, isTrue);
      vm.agregarMesa();
      expect(vm.puedeRehacer, isFalse);
    });

    test('un arrastre seguido cuenta como un solo paso', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      final antes = vm.mesas.single;
      for (var i = 0; i < 20; i++) {
        vm.arrastrarMesa(m.id, 5, 3);
      }
      vm.soltarMesa(m.id);
      expect(vm.mesas.single.x, isNot(antes.x));
      vm.deshacer();
      expect(vm.mesas.single.x, antes.x);
      expect(vm.mesas.single.y, antes.y);
    });

    test('deshacer también devuelve una mesa eliminada con su selección vacía', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.eliminarMesa(m.id);
      expect(vm.mesas, isEmpty);
      vm.deshacer();
      expect(vm.mesas.single.id, m.id);
    });

    test('descartar y recargar limpian el historial', () async {
      final vm = await crear();
      vm.agregarMesa();
      vm.descartar();
      expect(vm.puedeDeshacer, isFalse);
      vm.agregarMesa();
      expect(await vm.guardar(), isTrue);
      expect(vm.puedeDeshacer, isFalse, reason: 'tras guardar se recarga');
    });

    test('el historial tiene un máximo', () async {
      final vm = await crear();
      for (var i = 0; i < PlanEditorViewModel.maxHistorial + 20; i++) {
        vm.agregarElemento(ElementoPlano.columna);
      }
      var pasos = 0;
      while (vm.puedeDeshacer) {
        vm.deshacer();
        pasos++;
      }
      expect(pasos, PlanEditorViewModel.maxHistorial);
    });
  });

  group('Selección múltiple, alinear y distribuir', () {
    Future<(PlanEditorViewModel, List<String>)> conTres() async {
      final vm = await crear();
      final a = vm.agregarMesa();
      final b = vm.agregarMesa();
      final c = vm.agregarMesa();
      vm.moverMesa(a.id, 100, 100);
      vm.moverMesa(b.id, 300, 200);
      vm.moverMesa(c.id, 700, 400);
      vm.limpiarSeleccion();
      vm.alternarModoMultiple();
      vm.alternarEnSeleccion(a.id);
      vm.alternarEnSeleccion(b.id);
      vm.alternarEnSeleccion(c.id);
      return (vm, [a.id, b.id, c.id]);
    }

    test('el modo múltiple junta varias piezas y se puede limpiar', () async {
      final (vm, ids) = await conTres();
      expect(vm.cantidadSeleccionada, 3);
      expect(vm.estaSeleccionada(ids.first), isTrue);
      vm.alternarEnSeleccion(ids.first);
      expect(vm.cantidadSeleccionada, 2);
      vm.limpiarSeleccion();
      expect(vm.cantidadSeleccionada, 0);
    });

    test('seleccionar todo toma las mesas y los elementos del espacio', () async {
      final vm = await crear();
      vm.agregarMesa();
      vm.agregarElemento(ElementoPlano.planta);
      vm.seleccionarTodo();
      expect(vm.cantidadSeleccionada, 2);
      expect(vm.modoMultiple, isTrue);
    });

    test('alinear a la izquierda deja el mismo borde izquierdo', () async {
      final (vm, ids) = await conTres();
      vm.alinear(Alineacion.izquierda);
      final izq = vm.mesas.where((m) => ids.contains(m.id)).map((m) => m.cajaRotada.left).toSet();
      expect(izq, hasLength(1));
      expect(izq.single, closeTo(100, 0.001));
    });

    test('alinear arriba y al centro vertical', () async {
      final (vm, ids) = await conTres();
      vm.alinear(Alineacion.arriba);
      expect(vm.mesas.where((m) => ids.contains(m.id)).map((m) => m.cajaRotada.top).toSet(), hasLength(1));
      vm.alinear(Alineacion.centroVertical);
      expect(vm.mesas.where((m) => ids.contains(m.id)).map((m) => m.cajaRotada.center.dy.round()).toSet(), hasLength(1));
    });

    test('distribuir deja separaciones iguales entre los centros', () async {
      final (vm, ids) = await conTres();
      vm.distribuir(horizontal: true);
      final centros = [
        for (final m in vm.mesas)
          if (ids.contains(m.id)) m.cajaRotada.center.dx,
      ]..sort();
      expect(centros[1] - centros[0], closeTo(centros[2] - centros[1], 0.001));
    });

    test('alinear con menos de dos piezas no hace nada', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      final antes = vm.mesas.single.x;
      vm.alinear(Alineacion.derecha);
      expect(vm.mesas.single.x, antes);
      expect(m, isNotNull);
    });

    test('arrastrar una pieza del grupo mueve a todas juntas y dentro del plano', () async {
      final (vm, ids) = await conTres();
      final antes = {for (final m in vm.mesas) m.id: m.x!};
      vm.arrastrarMesa(ids.first, 40, 0);
      for (final m in vm.mesas) {
        expect(m.x, closeTo(antes[m.id]! + 40, 0.001));
      }
      vm.arrastrarMesa(ids.first, -5000, 0);
      expect(vm.mesas.map((m) => m.cajaRotada.left).reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(0));
    });

    test('girar, duplicar y eliminar la selección afectan a todas', () async {
      final (vm, ids) = await conTres();
      vm.girarSeleccion(90);
      expect(vm.mesas.where((m) => ids.contains(m.id)).every((m) => m.rotacion == 90), isTrue);

      vm.duplicarSeleccion();
      expect(vm.mesas, hasLength(6));
      expect(vm.cantidadSeleccionada, 3, reason: 'quedan seleccionadas las copias');

      vm.eliminarSeleccion();
      expect(vm.mesas, hasLength(3));
      expect(vm.cantidadSeleccionada, 0);
    });

    test('las flechas empujan la selección sin sacarla del plano', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.moverMesa(m.id, 0, 0);
      vm.empujarSeleccion(-10, -10);
      expect(vm.mesas.single.x, 0);
      vm.empujarSeleccion(10, 10);
      expect(vm.mesas.single.x, 10);
    });
  });

  group('Disponibilidad con mínimo y máximo', () {
    test('una mesa con mínimo 2 no se ofrece a un grupo de 1', () {
      const m = MesaModel(id: 'a', nombre: 'A', capacidad: 4, minPersonas: 2);
      expect(m.admite(1), isFalse);
      expect(m.admite(2), isTrue);
    });
  });
}
