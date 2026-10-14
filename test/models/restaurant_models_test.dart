import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';

void main() {
  group('RestaurantModel Serialization and Defaults', () {
    test('DaySchedule correctly maps from and to Map', () {
      const schedule = DaySchedule(
        abierto: true,
        apertura: '13:00',
        cierre: '22:00',
      );

      final map = schedule.toMap();
      expect(map['abierto'], isTrue);
      expect(map['apertura'], '13:00');
      expect(map['cierre'], '22:00');

      final fromMap = DaySchedule.fromMap(map);
      expect(fromMap.abierto, isTrue);
      expect(fromMap.apertura, '13:00');
      expect(fromMap.cierre, '22:00');
    });

    test('BranchModel correctly serializes and deserializes', () {
      const branch = BranchModel(
        id: 'sucursal_1',
        nombre: 'Sucursal Centro',
        direccion: 'Av. Juárez 142, Centro',
        telefono: '+52 55 0000 0000',
        esPrincipal: true,
        logoUrl: 'https://example.com/logo.jpg',
        imagenPrincipalUrl: 'https://example.com/cover.jpg',
      );

      final map = branch.toMap();
      expect(map['nombre'], 'Sucursal Centro');
      expect(map['direccion'], 'Av. Juárez 142, Centro');
      expect(map['telefono'], '+52 55 0000 0000');
      expect(map['esPrincipal'], isTrue);
      expect(map['logoUrl'], 'https://example.com/logo.jpg');
      expect(map['imagenPrincipalUrl'], 'https://example.com/cover.jpg');

      final fromMap = BranchModel.fromMap('sucursal_1', map);
      expect(fromMap.id, 'sucursal_1');
      expect(fromMap.nombre, 'Sucursal Centro');
      expect(fromMap.esPrincipal, isTrue);
      expect(fromMap.logoUrl, 'https://example.com/logo.jpg');
      expect(fromMap.imagenPrincipalUrl, 'https://example.com/cover.jpg');
    });

    test('ServiceCatalogModel correctly maps properties', () {
      final service = ServiceCatalogModel.fromMap('wifi', {
        'nombre': 'Wi-Fi Gratis',
        'icono': 'wifi',
        'activo': true,
      });

      expect(service.id, 'wifi');
      expect(service.nombre, 'Wi-Fi Gratis');
      expect(service.icono, 'wifi');
      expect(service.activo, isTrue);
    });

    test('RestaurantModel correctly sets HU23 fields', () {
      const restaurant = RestaurantModel(
        id: 'rest_1',
        nombre: 'Casa Sabores',
        telefono: '+52 55 1234 5678',
        correo: 'hola@casasabores.com',
        direccion: 'Av. Reforma 123, Centro',
        descripcion: 'Comida tradicional mexicana gourmet',
        estado: 'activo',
        perfilCompleto: true,
        diasAbiertos: ['lunes', 'martes', 'miercoles'],
        serviciosIds: ['wifi', 'terraza'],
        serviciosPersonalizados: ['Área infantil'],
      );

      expect(restaurant.name, 'Casa Sabores');
      expect(restaurant.perfilCompleto, isTrue);
      expect(restaurant.diasAbiertos.length, 3);
      expect(restaurant.serviciosIds.contains('wifi'), isTrue);
      expect(restaurant.serviciosPersonalizados.contains('Área infantil'), isTrue);
    });
  });
}
