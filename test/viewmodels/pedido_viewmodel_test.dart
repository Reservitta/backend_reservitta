import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/platillo_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/viewmodels/pedido_viewmodel.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';

void main() {
  final platilloEntrada = PlatilloModel(
    id: 'plat_1',
    categoriaId: 'cat_entradas',
    nombre: 'Aguachile Verde',
    descripcion: 'Camarón fresco con pepino, cilantro y chile serrano',
    precio: 185.00,
    etiquetas: const ['Mariscos', 'Picante'],
  );

  final platilloFuerte = PlatilloModel(
    id: 'plat_2',
    categoriaId: 'cat_fuertes',
    nombre: 'Salmón a las Finas Hierbas',
    descripcion: 'Filete de salmón con espárragos al vapor',
    precio: 290.00,
    etiquetas: const ['Sin gluten', 'Saludable'],
  );

  group('G24 · PedidoViewModel (HU16-RF04, HU16-RF05, HU17-RF01)', () {
    test('HU16-RF04: Calcula precio total como precio unitario × cantidad y agrega al borrador', () {
      final restaurant = RestaurantModel(
        id: 'rest_1',
        nombre: 'Restaurante Demo',
        estado: 'activo',
      );
      final draftVm = ReservationDraftViewModel(restaurant: restaurant);
      final pedidoVm = PedidoViewModel(draftViewModel: draftVm);

      expect(pedidoVm.isEmpty, isTrue);
      expect(pedidoVm.totalCantidad, 0);
      expect(pedidoVm.badgePedidoTexto, 'Pedido (0)');

      pedidoVm.agregarPlatillo(
        platilloEntrada,
        cantidad: 3,
        observacion: 'Sin cebolla morada',
      );

      expect(pedidoVm.isNotEmpty, isTrue);
      expect(pedidoVm.estaAgregado('plat_1'), isTrue);
      expect(pedidoVm.cantidadDePlatillo('plat_1'), 3);
      expect(pedidoVm.observacionDePlatillo('plat_1'), 'Sin cebolla morada');
      expect(pedidoVm.subtotal, 555.00); // 185 * 3
      expect(pedidoVm.badgePedidoTexto, 'Pedido (3)');

      // Sincronizado con el borrador de reserva
      expect(draftVm.draft.preordenItems, hasLength(1));
      expect(draftVm.draft.preordenItems.first['platilloId'], 'plat_1');
      expect(draftVm.draft.preordenItems.first['cantidad'], 3);
      expect(draftVm.draft.preordenItems.first['total'], 555.00);
      expect(draftVm.draft.preordenItems.first['observacion'], 'Sin cebolla morada');
    });

    test('HU16-RF05: Editar un platillo actualiza cantidad, observación, subtotal y badge "Pedido (n)"', () {
      final pedidoVm = PedidoViewModel();
      pedidoVm.agregarPlatillo(platilloEntrada, cantidad: 2, observacion: 'Poca sal');
      pedidoVm.agregarPlatillo(platilloFuerte, cantidad: 1, observacion: 'Bien cocido');

      expect(pedidoVm.totalCantidad, 3);
      expect(pedidoVm.badgePedidoTexto, 'Pedido (3)');
      expect(pedidoVm.subtotal, 660.00); // 370 + 290

      // Editar el primer platillo cambiando cantidad a 4 y observación
      pedidoVm.editarPlatillo(
        'plat_1',
        cantidad: 4,
        observacion: 'Sin chile serrano, alérgico al picante',
      );

      expect(pedidoVm.cantidadDePlatillo('plat_1'), 4);
      expect(
        pedidoVm.observacionDePlatillo('plat_1'),
        'Sin chile serrano, alérgico al picante',
      );
      expect(pedidoVm.totalCantidad, 5); // 4 + 1
      expect(pedidoVm.badgePedidoTexto, 'Pedido (5)');
      expect(pedidoVm.subtotal, 1030.00); // (185 * 4) + 290

      // Si la cantidad llega a 0, el platillo se elimina del pedido
      pedidoVm.editarPlatillo('plat_1', cantidad: 0);
      expect(pedidoVm.estaAgregado('plat_1'), isFalse);
      expect(pedidoVm.cantidadDePlatillo('plat_1'), 0);
      expect(pedidoVm.totalCantidad, 1);
      expect(pedidoVm.badgePedidoTexto, 'Pedido (1)');
      expect(pedidoVm.subtotal, 290.00);
    });

    test('HU17-RF01: Campo de observación es opcional y valida límite de 200 caracteres', () {
      final pedidoVm = PedidoViewModel();

      // Vacío es válido (opcional)
      expect(pedidoVm.validarObservacion(null), isNull);
      expect(pedidoVm.validarObservacion(''), isNull);
      expect(pedidoVm.validarObservacion('   '), isNull);

      // Agrega platillo sin observación sin bloquear
      pedidoVm.agregarPlatillo(platilloFuerte, cantidad: 1);
      expect(pedidoVm.estaAgregado('plat_2'), isTrue);
      expect(pedidoVm.observacionDePlatillo('plat_2'), isEmpty);

      // Límite de 200 caracteres válido
      final obs200 = 'a' * 200;
      expect(pedidoVm.validarObservacion(obs200), isNull);

      // Exceder 200 caracteres devuelve error de validación y lanza ArgumentError al guardar
      final obs201 = 'a' * 201;
      expect(pedidoVm.validarObservacion(obs201), isNotNull);
      expect(
        () => pedidoVm.guardarPlatillo(
          platilloFuerte,
          cantidad: 1,
          observacion: obs201,
        ),
        throwsArgumentError,
      );
    });
  });
}
