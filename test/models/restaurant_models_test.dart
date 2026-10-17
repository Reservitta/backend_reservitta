import 'package:cloud_firestore/cloud_firestore.dart';
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

    test('HU01-RF01 Criterio 1: RestaurantModel contains all public fields (nombre, logo, imagenPrincipal, direccion, coordenadas, estado)', () {
      final rawData = {
        'nombre': 'Restaurante El Gourmet',
        'logo': 'https://firebasestorage.com/v0/b/reservitta/logo.png',
        'imagenPrincipal': 'https://firebasestorage.com/v0/b/reservitta/portada.jpg',
        'direccion': 'Calle Principal 100, CDMX',
        'coordenadas': const GeoPoint(19.4326, -99.1332),
        'estado': 'activo',
      };

      final restaurant = RestaurantModel.fromMap('rest_pub_1', rawData);

      // Criterio 1: Verificación de campos públicos
      expect(restaurant.nombre, 'Restaurante El Gourmet');
      expect(restaurant.logo, 'https://firebasestorage.com/v0/b/reservitta/logo.png');
      expect(restaurant.logoUrl, 'https://firebasestorage.com/v0/b/reservitta/logo.png');
      expect(restaurant.imagenPrincipal, 'https://firebasestorage.com/v0/b/reservitta/portada.jpg');
      expect(restaurant.imagenPrincipalUrl, 'https://firebasestorage.com/v0/b/reservitta/portada.jpg');
      expect(restaurant.direccion, 'Calle Principal 100, CDMX');
      expect(restaurant.coordenadas, isNotNull);
      expect(restaurant.coordenadas!.latitude, 19.4326);
      expect(restaurant.coordenadas!.longitude, -99.1332);
      expect(restaurant.estado, 'activo');
      expect(restaurant.isActivo, isTrue);

      // Verificación de toMap incluye logo e imagenPrincipal
      final map = restaurant.toMap();
      expect(map['logo'], 'https://firebasestorage.com/v0/b/reservitta/logo.png');
      expect(map['logoUrl'], 'https://firebasestorage.com/v0/b/reservitta/logo.png');
      expect(map['imagenPrincipal'], 'https://firebasestorage.com/v0/b/reservitta/portada.jpg');
      expect(map['imagenPrincipalUrl'], 'https://firebasestorage.com/v0/b/reservitta/portada.jpg');
      expect(map['estado'], 'activo');
    });

    test('HU01-RF01 Criterio 1: coordinates parses from both GeoPoint and Map representation', () {
      final mapCoords = {
        'nombre': 'Restaurante Mapa',
        'coordenadas': {'latitude': 20.6736, 'longitude': -103.344},
        'estado': 'inactivo',
      };

      final rest = RestaurantModel.fromMap('rest_map_1', mapCoords);
      expect(rest.coordenadas, isNotNull);
      expect(rest.coordenadas!.latitude, 20.6736);
      expect(rest.coordenadas!.longitude, -103.344);
      expect(rest.isActivo, isFalse);
    });
  });
}
