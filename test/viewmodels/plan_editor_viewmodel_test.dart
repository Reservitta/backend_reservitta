import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
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

  group('Carga', () {
    test('un restaurante sin plano empieza vacío y sin cambios', () async {
      final vm = await crear();
      expect(vm.cargando, isFalse);
      expect(vm.mesas, isEmpty);
      expect(vm.zonas, isEmpty);
      expect(vm.hayCambios, isFalse);
      expect(vm.pestanas, isEmpty);
    });

    test('trae las mesas y los espacios guardados', () async {
      final z = await svc.crearZona('r1', 'Patio');
      await svc.guardarPlano(restauranteId: 'r1', mesas: [
        const MesaModel(id: '', nombre: 'P1', capacidad: 2, x: 20, y: 20, zonaId: null),
      ]);
      final vm = await crear();
      expect(vm.zonas.single.id, z.id);
      expect(vm.mesas, hasLength(1));
      // La mesa no tiene espacio: aparece en "Sin espacio".
      expect(vm.hayMesasSinEspacio, isTrue);
      expect(vm.pestanas.map((p) => p.nombre), ['Patio', 'Sin espacio']);
    });
  });

  group('Agregar mesas', () {
    test('cada forma trae medidas y sillas por defecto', () async {
      final vm = await crear();
      final cuadrada = vm.agregarMesa();
      final redonda = vm.agregarMesa(forma: MesaModel.formaRedonda);
      final rect = vm.agregarMesa(forma: MesaModel.formaRectangular);
      expect((cuadrada.forma, cuadrada.ancho, cuadrada.alto, cuadrada.capacidad),
          ('cuadrada', 100.0, 100.0, 4));
      expect((redonda.forma, redonda.ancho, redonda.alto), ('redonda', 100.0, 100.0));
      expect((rect.forma, rect.ancho, rect.alto, rect.capacidad), ('rectangular', 180.0, 90.0, 6));
    });

    test('los nombres automáticos no se repiten y la mesa queda seleccionada', () async {
      final vm = await crear();
      final a = vm.agregarMesa();
      final b = vm.agregarMesa();
      expect(a.nombre, 'Mesa 1');
      expect(b.nombre, 'Mesa 2');
      expect(vm.seleccionadaId, b.id);
      vm.eliminarMesa(a.id);
      expect(vm.agregarMesa().nombre, isNot('Mesa 2'));
    });

    test('las mesas nuevas no se empalman', () async {
      final vm = await crear();
      final a = vm.agregarMesa();
      final b = vm.agregarMesa();
      final chocan = a.x! < b.x! + b.ancho && a.x! + a.ancho > b.x! && a.y! < b.y! + b.alto && a.y! + a.alto > b.y!;
      expect(chocan, isFalse);
    });

    test('marca que hay cambios sin guardar', () async {
      final vm = await crear();
      vm.agregarMesa();
      expect(vm.hayCambios, isTrue);
    });
  });

  group('Mover y editar', () {
    test('arrastrar y soltar alinea a la cuadrícula y no se sale del lienzo', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.arrastrarMesa(m.id, 33, 47);
      vm.soltarMesa(m.id);
      final movida = vm.mesas.single;
      expect(movida.x! % PlanEditorViewModel.paso, 0);
      expect(movida.y! % PlanEditorViewModel.paso, 0);

      vm.arrastrarMesa(m.id, -5000, -5000);
      expect((vm.mesas.single.x, vm.mesas.single.y), (0.0, 0.0));
      vm.arrastrarMesa(m.id, 99999, 99999);
      expect(vm.mesas.single.x, PlanEditorViewModel.anchoLienzo - m.ancho);
      expect(vm.mesas.single.y, PlanEditorViewModel.altoLienzo - m.alto);
    });

    test('la capacidad se mantiene entre 1 y 50', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.cambiarCapacidad(m.id, 0);
      expect(vm.mesas.single.capacidad, 1);
      vm.cambiarCapacidad(m.id, 999);
      expect(vm.mesas.single.capacidad, 50);
      vm.cambiarCapacidad(m.id, 8);
      expect(vm.mesas.single.capacidad, 8);
    });

    test('cambiar a cuadrada o redonda iguala los lados y a rectangular los separa', () async {
      final vm = await crear();
      final m = vm.agregarMesa(forma: MesaModel.formaRectangular);
      vm.cambiarForma(m.id, MesaModel.formaRedonda);
      expect(vm.mesas.single.ancho, vm.mesas.single.alto);
      vm.cambiarForma(m.id, MesaModel.formaRectangular);
      expect(vm.mesas.single.ancho, greaterThan(vm.mesas.single.alto));
      vm.cambiarForma(m.id, 'triangular');
      expect(vm.mesas.single.forma, MesaModel.formaRectangular);
    });

    test('el tamaño respeta límites y las no rectangulares conservan lados iguales', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.cambiarTamano(m.id, ancho: 500);
      expect(vm.mesas.single.ancho, 300);
      expect(vm.mesas.single.alto, 300);
      vm.cambiarTamano(m.id, ancho: 1);
      expect(vm.mesas.single.ancho, 40);
      final r = vm.agregarMesa(forma: MesaModel.formaRectangular);
      vm.cambiarTamano(r.id, ancho: 250);
      expect(vm.mesas.last.ancho, 250);
      expect(vm.mesas.last.alto, 90);
    });

    test('duplicar copia forma y sillas con otro nombre', () async {
      final vm = await crear();
      final m = vm.agregarMesa(forma: MesaModel.formaRedonda);
      vm.cambiarCapacidad(m.id, 7);
      final copia = vm.duplicarMesa(m.id)!;
      expect((copia.forma, copia.capacidad), ('redonda', 7));
      expect(copia.nombre, isNot(m.nombre));
      expect(vm.mesas, hasLength(2));
    });

    test('eliminar quita la mesa y la deselecciona', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      vm.eliminarMesa(m.id);
      expect(vm.mesas, isEmpty);
      expect(vm.seleccionadaId, isNull);
    });
  });

  group('Combinaciones', () {
    test('solo se unen mesas combinables y la unión es en ambos sentidos', () async {
      final vm = await crear();
      final a = vm.agregarMesa();
      final b = vm.agregarMesa();
      vm.alternarCombinacion(a.id, b.id);
      expect(vm.mesas.first.combinableCon, isEmpty);
      vm.cambiarCombinable(a.id, true);
      vm.cambiarCombinable(b.id, true);
      vm.alternarCombinacion(a.id, b.id);
      expect(vm.mesas.first.combinableCon, [b.id]);
      expect(vm.mesas.last.combinableCon, [a.id]);
      vm.alternarCombinacion(a.id, b.id);
      expect(vm.mesas.first.combinableCon, isEmpty);
      expect(vm.mesas.last.combinableCon, isEmpty);
    });

    test('dejar de ser combinable separa a la mesa de las demás', () async {
      final vm = await crear();
      final a = vm.agregarMesa();
      final b = vm.agregarMesa();
      vm.cambiarCombinable(a.id, true);
      vm.cambiarCombinable(b.id, true);
      vm.alternarCombinacion(a.id, b.id);
      vm.cambiarCombinable(a.id, false);
      expect(vm.mesas.last.combinableCon, isEmpty);
    });

    test('al eliminar una mesa se quita de las combinaciones', () async {
      final vm = await crear();
      final a = vm.agregarMesa();
      final b = vm.agregarMesa();
      vm.cambiarCombinable(a.id, true);
      vm.cambiarCombinable(b.id, true);
      vm.alternarCombinacion(a.id, b.id);
      vm.eliminarMesa(a.id);
      expect(vm.mesas.single.combinableCon, isEmpty);
    });
  });

  group('Espacios', () {
    test('crear un espacio lo deja activo y las mesas nuevas van a él', () async {
      final vm = await crear();
      expect(await vm.agregarZona('Segundo piso'), isNull);
      expect(vm.zonas.single.nombre, 'Segundo piso');
      expect(vm.zonaActivaId, vm.zonas.single.id);
      final m = vm.agregarMesa();
      expect(m.zonaId, vm.zonas.single.id);
    });

    test('devuelve el error si el nombre es inválido o repetido', () async {
      final vm = await crear();
      await vm.agregarZona('Patio');
      expect(await vm.agregarZona('patio'), contains('Ya existe'));
      expect(await vm.agregarZona(''), isNotNull);
      expect(vm.zonas, hasLength(1));
    });

    test('cada espacio muestra solo sus mesas', () async {
      final vm = await crear();
      await vm.agregarZona('Piso 1');
      vm.agregarMesa();
      await vm.agregarZona('Patio');
      vm.agregarMesa();
      vm.agregarMesa();
      expect(vm.mesasVisibles, hasLength(2));
      vm.seleccionarZona(vm.zonas.first.id);
      expect(vm.mesasVisibles, hasLength(1));
      expect(vm.mesas, hasLength(3));
    });

    test('renombrar un espacio', () async {
      final vm = await crear();
      await vm.agregarZona('Patio');
      expect(await vm.renombrarZona(vm.zonas.single.id, 'Jardín'), isNull);
      expect(vm.zonas.single.nombre, 'Jardín');
      await vm.agregarZona('Interior');
      expect(await vm.renombrarZona(vm.zonas.first.id, 'interior'), isNotNull);
    });

    test('no elimina un espacio que tiene mesas en el borrador', () async {
      final vm = await crear();
      await vm.agregarZona('Patio');
      vm.agregarMesa();
      final error = await vm.eliminarZona(vm.zonas.single.id);
      expect(error, contains('1 mesa'));
      expect(vm.zonas, hasLength(1));
    });

    test('elimina un espacio vacío y pasa al siguiente', () async {
      final vm = await crear();
      await vm.agregarZona('Piso 1');
      await vm.agregarZona('Patio');
      expect(await vm.eliminarZona(vm.zonas.last.id), isNull);
      expect(vm.zonas.single.nombre, 'Piso 1');
      expect(vm.zonaActivaId, vm.zonas.single.id);
    });

    test('mover una mesa a otro espacio cambia su espacio y la deja en lugar libre', () async {
      final vm = await crear();
      await vm.agregarZona('Piso 1');
      final m = vm.agregarMesa();
      await vm.agregarZona('Patio');
      vm.agregarMesa();
      vm.moverAEspacio(m.id, vm.zonas.last.id);
      expect(vm.mesas.firstWhere((x) => x.id == m.id).zonaId, vm.zonas.last.id);
      expect(vm.mesasVisibles, hasLength(2));
      final a = vm.mesasVisibles.first;
      final b = vm.mesasVisibles.last;
      final chocan = a.x! < b.x! + b.ancho && a.x! + a.ancho > b.x! && a.y! < b.y! + b.alto && a.y! + a.alto > b.y!;
      expect(chocan, isFalse);
    });
  });

  group('Validación y guardado', () {
    test('un nombre repetido o vacío se detecta al momento', () async {
      final vm = await crear();
      final a = vm.agregarMesa();
      final b = vm.agregarMesa();
      vm.cambiarNombre(b.id, a.nombre.toLowerCase());
      expect(vm.erroresDe(b.id)['nombre'], contains('Ya hay'));
      vm.cambiarNombre(b.id, '');
      expect(vm.erroresDe(b.id)['nombre'], isNotNull);
      vm.cambiarNombre(b.id, 'Barra');
      expect(vm.erroresDe(b.id), isEmpty);
    });

    test('no guarda con errores: selecciona la mesa con problema y explica', () async {
      final vm = await crear();
      vm.agregarMesa();
      final b = vm.agregarMesa();
      vm.cambiarNombre(b.id, '');
      expect(await vm.guardar(), isFalse);
      expect(vm.seleccionadaId, b.id);
      expect(vm.error, contains('Una mesa'));
      expect(vm.camposConError.keys, contains('nombre'));
      expect(await svc.getMesas('r1'), isEmpty);
    });

    test('guarda, recarga con ids definitivos y deja de tener cambios', () async {
      final vm = await crear();
      await vm.agregarZona('Patio');
      vm.agregarMesa(forma: MesaModel.formaRedonda);
      vm.agregarMesa();
      expect(await vm.guardar(), isTrue);
      expect(vm.hayCambios, isFalse);
      expect(vm.error, isNull);
      expect(vm.mesas.every((m) => !m.id.startsWith('tmp_')), isTrue);
      expect(await svc.getMesas('r1'), hasLength(2));
    });

    test('guarda las combinaciones entre mesas nuevas', () async {
      final vm = await crear();
      final a = vm.agregarMesa();
      final b = vm.agregarMesa();
      vm.cambiarCombinable(a.id, true);
      vm.cambiarCombinable(b.id, true);
      vm.alternarCombinacion(a.id, b.id);
      expect(await vm.guardar(), isTrue);
      expect(vm.mesas.every((m) => m.combinableCon.length == 1), isTrue);
    });

    test('descartar vuelve al último plano guardado', () async {
      final vm = await crear();
      vm.agregarMesa();
      await vm.guardar();
      vm.agregarMesa();
      vm.eliminarMesa(vm.mesas.first.id);
      vm.descartar();
      expect(vm.mesas, hasLength(1));
      expect(vm.hayCambios, isFalse);
      expect(vm.seleccionadaId, isNull);
    });

    test('si el servicio rechaza (reservas activas) muestra el motivo y conserva el borrador', () async {
      final vm = await crear();
      final m = vm.agregarMesa();
      await vm.guardar();
      final guardada = vm.mesas.single;
      await db.collection('reservations').add({
        'restauranteId': 'r1',
        'fechaLocal': '2026-11-10',
        'inicio': DateTime(2026, 11, 10, 14),
        'duracionMin': 90,
        'personas': 2,
        'mesaIds': [guardada.id],
        'estado': 'confirmada',
      });
      vm.eliminarMesa(guardada.id);
      expect(m.id, isNotEmpty);
      expect(await vm.guardar(), isFalse);
      expect(vm.error, contains('reservas activas'));
      expect(vm.hayCambios, isTrue);
    });

    test('guardar marca el estado de guardando y lo libera', () async {
      final vm = await crear();
      vm.agregarMesa();
      final estados = <bool>[];
      vm.addListener(() => estados.add(vm.guardando));
      await vm.guardar();
      expect(estados, contains(true));
      expect(vm.guardando, isFalse);
    });
  });
}
