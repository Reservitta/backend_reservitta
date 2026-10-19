import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/utils/geo_utils.dart';

void main() {
  group('HU02-RF02 GeoUtils: Cálculo de distancia y validación geográfica', () {
    // Coordenadas de prueba en CDMX:
    // Zócalo CDMX
    const zocaloLat = 19.4326;
    const zocaloLng = -99.1332;

    // Ángel de la Independencia (~3.7 km del Zócalo)
    const angelLat = 19.4260;
    const angelLng = -99.1677;

    // Polanco / Museo Soumaya (~7.5 km del Zócalo)
    const polancoLat = 19.4406;
    const polancoLng = -99.2046;

    // Estadio Azteca (~14.8 km del Zócalo)
    const aztecaLat = 19.3029;
    const aztecaLng = -99.1505;

    test('Criterio 1: calculateDistanceKm calcula distancia precisa usando fórmula de Haversine', () {
      // Misma ubicación debe tener distancia cero
      final samePoint = GeoUtils.calculateDistanceKm(
        startLatitude: zocaloLat,
        startLongitude: zocaloLng,
        endLatitude: zocaloLat,
        endLongitude: zocaloLng,
      );
      expect(samePoint, 0.0);

      // Distancia Zócalo a Ángel (~3.7 km)
      final distanceZocaloAngel = GeoUtils.calculateDistanceKm(
        startLatitude: zocaloLat,
        startLongitude: zocaloLng,
        endLatitude: angelLat,
        endLongitude: angelLng,
      );
      expect(distanceZocaloAngel, closeTo(3.7, 0.2));

      // Distancia Zócalo a Polanco (~7.5 km)
      final distanceZocaloPolanco = GeoUtils.calculateDistanceKm(
        startLatitude: zocaloLat,
        startLongitude: zocaloLng,
        endLatitude: polancoLat,
        endLongitude: polancoLng,
      );
      expect(distanceZocaloPolanco, closeTo(7.5, 0.3));

      // calculateDistanceMeters devuelve metros
      final distanceMeters = GeoUtils.calculateDistanceMeters(
        startLatitude: zocaloLat,
        startLongitude: zocaloLng,
        endLatitude: angelLat,
        endLongitude: angelLng,
      );
      expect(distanceMeters, closeTo(3700.0, 200.0));
    });

    test('Criterio 4: isValidCoordinate y isValidGeoPoint validan rangos y excluyen nulos/0,0', () {
      // Coordenadas válidas
      expect(GeoUtils.isValidCoordinate(19.4326, -99.1332), isTrue);
      expect(GeoUtils.isValidGeoPoint(const GeoPoint(19.4326, -99.1332)), isTrue);

      // Nulos
      expect(GeoUtils.isValidCoordinate(null, -99.1332), isFalse);
      expect(GeoUtils.isValidCoordinate(19.4326, null), isFalse);
      expect(GeoUtils.isValidGeoPoint(null), isFalse);

      // Null island / sin asignar (0,0)
      expect(GeoUtils.isValidCoordinate(0.0, 0.0), isFalse);
      expect(GeoUtils.isValidGeoPoint(const GeoPoint(0.0, 0.0)), isFalse);

      // Fuera de rango
      expect(GeoUtils.isValidCoordinate(95.0, -99.1332), isFalse);
      expect(GeoUtils.isValidCoordinate(-95.0, -99.1332), isFalse);
      expect(GeoUtils.isValidCoordinate(19.4326, 185.0), isFalse);
      expect(GeoUtils.isValidCoordinate(19.4326, -185.0), isFalse);
      expect(GeoUtils.isValidCoordinate(double.nan, -99.1332), isFalse);
    });

    test('Criterio 1: calculateDistanceKm lanza ArgumentError ante coordenadas inválidas', () {
      expect(
        () => GeoUtils.calculateDistanceKm(
          startLatitude: 100.0,
          startLongitude: -99.0,
          endLatitude: 19.0,
          endLongitude: -99.0,
        ),
        throwsArgumentError,
      );
    });

    group('filterAndSortByDistance', () {
      late List<RestaurantModel> testRestaurants;

      setUp(() {
        testRestaurants = [
          // A ~3.7 km
          const RestaurantModel(
            id: 'rest_angel',
            nombre: 'Restaurante Ángel',
            coordenadas: GeoPoint(angelLat, angelLng),
            estado: 'activo',
          ),
          // A ~7.5 km
          const RestaurantModel(
            id: 'rest_polanco',
            nombre: 'Restaurante Polanco',
            coordenadas: GeoPoint(polancoLat, polancoLng),
            estado: 'activo',
          ),
          // A ~14.8 km
          const RestaurantModel(
            id: 'rest_azteca',
            nombre: 'Restaurante Azteca',
            coordenadas: GeoPoint(aztecaLat, aztecaLng),
            estado: 'activo',
          ),
          // Sin coordenadas (null)
          const RestaurantModel(
            id: 'rest_sin_coords',
            nombre: 'Restaurante Sin Coordenadas',
            coordenadas: null,
            estado: 'activo',
          ),
          // Coordenadas no asignadas (0,0)
          const RestaurantModel(
            id: 'rest_coords_cero',
            nombre: 'Restaurante Null Island',
            coordenadas: GeoPoint(0.0, 0.0),
            estado: 'activo',
          ),
        ];
      });

      test('Criterio 4: Excluye restaurantes sin coordenadas válidas', () {
        final filtered = GeoUtils.filterAndSortByDistance(
          restaurants: testRestaurants,
          userLatitude: zocaloLat,
          userLongitude: zocaloLng,
          radiusKm: 20.0, // Radio grande que cubriría a todos si tuvieran coords
        );

        // Solo deben quedar los 3 restaurantes con coordenadas válidas
        expect(filtered.length, 3);
        expect(filtered.any((r) => r.id == 'rest_sin_coords'), isFalse);
        expect(filtered.any((r) => r.id == 'rest_coords_cero'), isFalse);
      });

      test('Criterio 2: Filtra por radio de 5 km', () {
        final filtered5km = GeoUtils.filterAndSortByDistance(
          restaurants: testRestaurants,
          userLatitude: zocaloLat,
          userLongitude: zocaloLng,
          radiusKm: 5.0,
        );

        // A 5 km solo entra Ángel (~3.7 km), Polanco (~7.5 km) y Azteca (~14.8 km) quedan fuera
        expect(filtered5km.length, 1);
        expect(filtered5km.first.id, 'rest_angel');
        expect(filtered5km.first.distanciaKm, isNotNull);
        expect(filtered5km.first.distanciaKm!, lessThanOrEqualTo(5.0));
      });

      test('Criterio 2: Filtra por radio de 10 km', () {
        final filtered10km = GeoUtils.filterAndSortByDistance(
          restaurants: testRestaurants,
          userLatitude: zocaloLat,
          userLongitude: zocaloLng,
          radiusKm: 10.0,
        );

        // A 10 km entran Ángel (~3.7 km) y Polanco (~7.5 km)
        expect(filtered10km.length, 2);
        expect(filtered10km.any((r) => r.id == 'rest_angel'), isTrue);
        expect(filtered10km.any((r) => r.id == 'rest_polanco'), isTrue);
        expect(filtered10km.any((r) => r.id == 'rest_azteca'), isFalse);
      });

      test('Criterio 3: Ordena los resultados del más cercano al más lejano', () {
        final filteredAll = GeoUtils.filterAndSortByDistance(
          restaurants: testRestaurants,
          userLatitude: zocaloLat,
          userLongitude: zocaloLng,
          radiusKm: 20.0,
        );

        expect(filteredAll.length, 3);
        // Primer lugar: Ángel (~3.7 km)
        expect(filteredAll[0].id, 'rest_angel');
        // Segundo lugar: Polanco (~7.5 km)
        expect(filteredAll[1].id, 'rest_polanco');
        // Tercer lugar: Azteca (~14.8 km)
        expect(filteredAll[2].id, 'rest_azteca');

        // Distancias crecientes estrictas
        expect(filteredAll[0].distanciaKm!, lessThan(filteredAll[1].distanciaKm!));
        expect(filteredAll[1].distanciaKm!, lessThan(filteredAll[2].distanciaKm!));
      });

      test('filterAndSortByDistance valida radio positivo y coordenadas de usuario', () {
        expect(
          () => GeoUtils.filterAndSortByDistance(
            restaurants: testRestaurants,
            userLatitude: zocaloLat,
            userLongitude: zocaloLng,
            radiusKm: 0.0,
          ),
          throwsArgumentError,
        );

        expect(
          () => GeoUtils.filterAndSortByDistance(
            restaurants: testRestaurants,
            userLatitude: zocaloLat,
            userLongitude: zocaloLng,
            radiusKm: -5.0,
          ),
          throwsArgumentError,
        );

        expect(
          () => GeoUtils.filterAndSortByDistance(
            restaurants: testRestaurants,
            userLatitude: 100.0,
            userLongitude: zocaloLng,
            radiusKm: 5.0,
          ),
          throwsArgumentError,
        );
      });

      test('filterAndSortWithDistance devuelve objetos RestaurantWithDistance formateados', () {
        final list = GeoUtils.filterAndSortWithDistance(
          restaurants: testRestaurants,
          userLatitude: zocaloLat,
          userLongitude: zocaloLng,
          radiusKm: 5.0,
        );

        expect(list.length, 1);
        final item = list.first;
        expect(item.restaurant.id, 'rest_angel');
        expect(item.distanceKm, closeTo(3.7, 0.2));
        expect(item.formattedDistance, contains('km'));
      });
    });
  });
}
