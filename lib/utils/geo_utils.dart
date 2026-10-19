import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant_model.dart';
import '../models/restaurant_with_distance.dart';

/// Utilidades geográficas y de cálculo de distancias (HU02-RF02)
class GeoUtils {
  /// Radio medio de la Tierra en kilómetros (WGS84 aproximado)
  static const double earthRadiusKm = 6371.0;

  /// Opciones de radio estándar en kilómetros sugeridas por el requerimiento
  static const List<double> defaultRadiusOptionsKm = [1.0, 3.0, 5.0, 10.0];

  /// Calcula la distancia geodésica en kilómetros entre dos pares de coordenadas (fórmula de Haversine).
  /// Retorna la distancia en kilómetros con alta precisión.
  static double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    if (!isValidCoordinate(startLatitude, startLongitude) ||
        !isValidCoordinate(endLatitude, endLongitude)) {
      throw ArgumentError(
        'Coordenadas geográficas fuera de rango o inválidas: '
        'origen ($startLatitude, $startLongitude), destino ($endLatitude, $endLongitude)',
      );
    }

    final dLat = _degreesToRadians(endLatitude - startLatitude);
    final dLon = _degreesToRadians(endLongitude - startLongitude);

    final lat1Rad = _degreesToRadians(startLatitude);
    final lat2Rad = _degreesToRadians(endLatitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Calcula la distancia en metros entre dos puntos geográficos
  static double calculateDistanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return calculateDistanceKm(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    ) * 1000.0;
  }

  /// Valida si un par de latitud y longitud corresponde a coordenadas geográficas válidas.
  /// Rango: latitud [-90, 90], longitud [-180, 180]. Excluye (0,0) / nulo / NaN.
  static bool isValidCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude < -90.0 || latitude > 90.0) return false;
    if (longitude < -180.0 || longitude > 180.0) return false;
    // Excluir 0,0 si se considera ubicación no asignada o nula
    if (latitude == 0.0 && longitude == 0.0) return false;
    return true;
  }

  /// Valida si un GeoPoint contiene coordenadas geográficas utilizables
  static bool isValidGeoPoint(GeoPoint? point) {
    if (point == null) return false;
    return isValidCoordinate(point.latitude, point.longitude);
  }

  /// Filtra y ordena restaurantes activos según un radio máximo en km desde la ubicación del usuario.
  /// - Excluye restaurantes sin coordenadas válidas (Criterio 4).
  /// - Filtra por el radio especificado en kilómetros (Criterio 2).
  /// - Ordena los resultados del más cercano al más lejano (Criterio 3).
  /// - Asigna la distancia calculada en el modelo resultante (Criterio 1).
  static List<RestaurantModel> filterAndSortByDistance({
    required List<RestaurantModel> restaurants,
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) {
    if (radiusKm <= 0) {
      throw ArgumentError('El radio de búsqueda debe ser mayor a 0 km.');
    }
    if (!isValidCoordinate(userLatitude, userLongitude)) {
      throw ArgumentError('Las coordenadas del usuario no son válidas.');
    }

    final results = <RestaurantModel>[];

    for (final restaurant in restaurants) {
      // Criterio 4: Excluir restaurantes sin coordenadas válidas
      final coords = restaurant.coordenadas;
      if (!isValidGeoPoint(coords)) {
        continue;
      }

      // Criterio 1: Calcular distancia entre ubicación del usuario y restaurante
      final distance = calculateDistanceKm(
        startLatitude: userLatitude,
        startLongitude: userLongitude,
        endLatitude: coords!.latitude,
        endLongitude: coords.longitude,
      );

      // Criterio 2: Filtrar por radio máximo
      if (distance <= radiusKm) {
        results.add(restaurant.copyWith(distanciaKm: distance));
      }
    }

    // Criterio 3: Ordenar del más cercano al más lejano (ascendente)
    results.sort((a, b) {
      final distA = a.distanciaKm ?? double.infinity;
      final distB = b.distanciaKm ?? double.infinity;
      final comp = distA.compareTo(distB);
      if (comp != 0) return comp;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });

    return results;
  }

  /// Filtra y retorna pares RestaurantWithDistance
  static List<RestaurantWithDistance> filterAndSortWithDistance({
    required List<RestaurantModel> restaurants,
    required double userLatitude,
    required double userLongitude,
    required double radiusKm,
  }) {
    final list = filterAndSortByDistance(
      restaurants: restaurants,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      radiusKm: radiusKm,
    );

    return list
        .map((r) => RestaurantWithDistance(
              restaurant: r,
              distanceKm: r.distanciaKm!,
            ))
        .toList();
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
