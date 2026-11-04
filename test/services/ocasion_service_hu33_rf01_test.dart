import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/experiencia_model.dart';
import 'package:reservitta/models/ocasion_model.dart';
import 'package:reservitta/services/ocasion_service.dart';
import 'package:reservitta/viewmodels/ocasion_viewmodel.dart';

class FakeOcasionService extends OcasionService {
  final Map<String, List<OcasionModel>> ocasionesPorRestaurante = {};
  final Map<String, StreamController<List<OcasionModel>>> _controllers = {};

  StreamController<List<OcasionModel>> _getController(String restaurantId) {
    return _controllers.putIfAbsent(
      restaurantId,
      () => StreamController<List<OcasionModel>>.broadcast(),
    );
  }

  void _emitir(String restaurantId) {
    final list = ocasionesPorRestaurante[restaurantId] ?? [];
    _getController(restaurantId).add(List.unmodifiable(list));
  }

  @override
  Future<String> crearOcasion({
    required String restaurantId,
    required String nombre,
    String? tipoPredefinido,
    String descripcion = '',
    String? icono,
    required List<ExperienciaModel> experiencias,
  }) async {
    OcasionService.validarOcasion(
      restaurantId: restaurantId,
      nombre: nombre,
      experiencias: experiencias,
    );

    final list = ocasionesPorRestaurante.putIfAbsent(restaurantId, () => []);
    final ocasionId = 'ocasion_${list.length + 1}';

    final expProcesadas = <ExperienciaModel>[];
    for (int i = 0; i < experiencias.length; i++) {
      final exp = experiencias[i];
      final expId = exp.id.isNotEmpty ? exp.id : '${ocasionId}_exp_${i + 1}';
      final procesada = exp.copyWith(
        id: expId,
        esGratis: exp.precio <= 0.0,
        orden: i + 1,
      );
      expProcesadas.add(procesada);
    }

    final nueva = OcasionModel(
      id: ocasionId,
      restaurantId: restaurantId,
      nombre: nombre.trim(),
      tipoPredefinido: tipoPredefinido ?? (OcasionModel.nombresPredefinidos.contains(nombre) ? nombre : 'Otro'),
      descripcion: descripcion.trim(),
      icono: icono ?? OcasionModel.iconoPorNombre(nombre),
      activo: true,
      experiencias: expProcesadas,
    );

    list.add(nueva);
    _emitir(restaurantId);
    return ocasionId;
  }

  @override
  Stream<List<OcasionModel>> getOcasionesStream(String restaurantId) {
    Future.microtask(() => _emitir(restaurantId));
    return _getController(restaurantId).stream;
  }

  @override
  Future<List<OcasionModel>> getOcasiones(String restaurantId) async {
    return List.unmodifiable(ocasionesPorRestaurante[restaurantId] ?? []);
  }

  @override
  Future<void> eliminarOcasion({
    required String restaurantId,
    required String ocasionId,
  }) async {
    final list = ocasionesPorRestaurante[restaurantId];
    if (list != null) {
      list.removeWhere((o) => o.id == ocasionId);
      _emitir(restaurantId);
    }
  }
}

void main() {
  group('72.- HU33-RF01: Crear ocasión especial y sus experiencias (Lógica de Negocio y Servicio)', () {
    late FakeOcasionService fakeService;
    const adminRestaurantId = 'rest_admin_123';

    setUp(() {
      fakeService = FakeOcasionService();
    });

    test('Criterio 1: Admite los nombres predefinidos de ocasión especial', () {
      expect(
        OcasionModel.nombresPredefinidos,
        containsAll([
          'Cumpleaños',
          'Aniversario',
          'Pedida',
          'Graduación',
          'Cena romántica',
          'Otro',
        ]),
      );
    });

    test('Criterio 2, 4: Validación estricta - Nombre y precio de experiencias obligatorios', () {
      // 1. Sin experiencias no se puede crear
      expect(
        () => OcasionService.validarOcasion(
          restaurantId: adminRestaurantId,
          nombre: 'Cumpleaños',
          experiencias: [],
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('al menos una experiencia'),
        )),
      );

      // 2. Nombre de ocasión vacío rechazado
      expect(
        () => OcasionService.validarOcasion(
          restaurantId: adminRestaurantId,
          nombre: '   ',
          experiencias: [
            const ExperienciaModel(id: '1', nombre: 'Pastel', precio: 50),
          ],
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('nombre de la ocasión especial es obligatorio'),
        )),
      );

      // 3. Experiencia con nombre vacío rechazada
      expect(
        () => OcasionService.validarOcasion(
          restaurantId: adminRestaurantId,
          nombre: 'Aniversario',
          experiencias: [
            const ExperienciaModel(id: '1', nombre: '   ', precio: 100),
          ],
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('nombre de la experiencia'),
        )),
      );

      // 4. Precio negativo rechazado
      expect(
        () => OcasionService.validarOcasion(
          restaurantId: adminRestaurantId,
          nombre: 'Graduación',
          experiencias: [
            const ExperienciaModel(id: '1', nombre: 'Brindis', precio: -20),
          ],
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('no puede ser negativo'),
        )),
      );
    });

    test('Criterio 3: Si el precio ingresado es \$0, la experiencia se marca automáticamente como "Gratis"', () async {
      // 1. En modelo ExperienciaModel
      const expGratis = ExperienciaModel(
        id: 'exp_0',
        nombre: 'Copa de cortesía',
        descripcionCorta: 'Brindis de la casa',
        precio: 0.0,
      );
      expect(expGratis.esGratis, isTrue);
      expect(expGratis.precioFormateado, equals('Gratis'));

      // 2. En ViewModel
      final vm = OcasionViewModel(restaurantId: adminRestaurantId, ocasionService: fakeService);
      vm.agregarExperienciaTemporal(
        nombre: 'Vela mágica',
        precio: 0,
      );
      expect(vm.experienciasTemporales.first.esGratis, isTrue);
      expect(vm.experienciasTemporales.first.precioFormateado, equals('Gratis'));

      // 3. En persistencia del servicio
      final id = await fakeService.crearOcasion(
        restaurantId: adminRestaurantId,
        nombre: 'Cumpleaños',
        experiencias: [
          const ExperienciaModel(id: 'e1', nombre: 'Pastel de Cortesía', precio: 0.0),
        ],
      );

      final guardadas = await fakeService.getOcasiones(adminRestaurantId);
      final guardada = guardadas.firstWhere((o) => o.id == id);
      expect(guardada.experiencias.first.esGratis, isTrue);
      expect(guardada.experiencias.first.precioFormateado, equals('Gratis'));
    });

    test('Criterio 6: El administrador puede agregar varias experiencias a la misma ocasión antes de guardar', () async {
      final vm = OcasionViewModel(restaurantId: adminRestaurantId, ocasionService: fakeService);

      vm.setNombrePredefinido('Pedida');
      vm.setDescripcion('Paquete para pedida de mano inolvidable');

      // Agregar múltiples experiencias antes de guardar
      vm.agregarExperienciaTemporal(nombre: 'Mesa con pétalos', descripcionCorta: 'Rosas rojas', precio: 300);
      vm.agregarExperienciaTemporal(nombre: 'Violinista en vivo (15 min)', descripcionCorta: 'Canción especial', precio: 500);
      vm.agregarExperienciaTemporal(nombre: 'Brindis con Champagne', precio: 0); // Gratis

      expect(vm.experienciasTemporales.length, equals(3));
      expect(vm.puedeGuardar, isTrue);

      final ok = await vm.guardarOcasion();
      expect(ok, isTrue);

      // Verificamos que se guardaron las 3 experiencias
      final ocasiones = await fakeService.getOcasiones(adminRestaurantId);
      expect(ocasiones.length, equals(1));
      expect(ocasiones.first.nombre, equals('Pedida'));
      expect(ocasiones.first.experiencias.length, equals(3));
      expect(ocasiones.first.experiencias[0].nombre, equals('Mesa con pétalos'));
      expect(ocasiones.first.experiencias[1].nombre, equals('Violinista en vivo (15 min)'));
      expect(ocasiones.first.experiencias[2].precioFormateado, equals('Gratis'));
    });

    test('Criterio 7: Las ocasiones y experiencias se guardan asociadas al restaurante del administrador autenticado (no globales)', () async {
      const restA = 'restaurante_la_trattoria';
      const restB = 'restaurante_el_asador';

      // Administrador del Restaurante A crea ocasión
      await fakeService.crearOcasion(
        restaurantId: restA,
        nombre: 'Cena romántica',
        experiencias: [
          const ExperienciaModel(id: 'e1', nombre: 'Vino Tinto Reserva', precio: 450),
        ],
      );

      // Administrador del Restaurante B crea ocasión
      await fakeService.crearOcasion(
        restaurantId: restB,
        nombre: 'Cumpleaños',
        experiencias: [
          const ExperienciaModel(id: 'e2', nombre: 'Rebanada de pastel', precio: 0),
        ],
      );

      // Consulta del Restaurante A: solo ve su ocasión
      final ocasionesA = await fakeService.getOcasiones(restA);
      expect(ocasionesA.length, equals(1));
      expect(ocasionesA.first.nombre, equals('Cena romántica'));
      expect(ocasionesA.first.restaurantId, equals(restA));

      // Consulta del Restaurante B: solo ve su ocasión
      final ocasionesB = await fakeService.getOcasiones(restB);
      expect(ocasionesB.length, equals(1));
      expect(ocasionesB.first.nombre, equals('Cumpleaños'));
      expect(ocasionesB.first.restaurantId, equals(restB));
    });

    test('Criterio 5: Al guardar, la ocasión y sus experiencias quedan disponibles de inmediato para consulta (HU18-RF01)', () async {
      // 1. Guardamos la ocasión
      final id = await fakeService.crearOcasion(
        restaurantId: adminRestaurantId,
        nombre: 'Graduación',
        experiencias: [
          const ExperienciaModel(id: 'e_grad', nombre: 'Postre con felicitación grabada', precio: 0.0),
        ],
      );

      // 2. Consulta inmediata (HU18-RF01)
      final consultadas = await fakeService.getOcasiones(adminRestaurantId);
      expect(consultadas, isNotEmpty);
      expect(consultadas.any((o) => o.id == id && o.nombre == 'Graduación'), isTrue);
      expect(consultadas.first.experiencias.first.nombre, equals('Postre con felicitación grabada'));

      // 3. Consulta en stream en tiempo real
      final listaStream = await fakeService.getOcasionesStream(adminRestaurantId).first;
      expect(listaStream, isNotEmpty);
      expect(listaStream.any((o) => o.id == id), isTrue);
    });
  });
}
