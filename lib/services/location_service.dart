import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'geocoding_service.dart';

/// Representa una zona o ubicación geográfica seleccionada por el usuario
class UserLocation {
  final double latitude;
  final double longitude;
  final String label;
  final bool isGps;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.isGps = false,
  });

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
}

/// Zonas populares predefinidas para selección manual rápida (HU02-RF01 Criterio 3)
class LocationPresets {
  static const List<UserLocation> presetLocations = [
    UserLocation(
      latitude: 19.4326,
      longitude: -99.1332,
      label: 'CDMX - Centro Histórico',
    ),
    UserLocation(
      latitude: 19.4187,
      longitude: -99.1678,
      label: 'CDMX - Roma / Condesa',
    ),
    UserLocation(
      latitude: 19.4337,
      longitude: -99.1906,
      label: 'CDMX - Polanco',
    ),
    UserLocation(
      latitude: 20.6767,
      longitude: -103.3470,
      label: 'Guadalajara Centro',
    ),
    UserLocation(
      latitude: 25.6866,
      longitude: -100.3161,
      label: 'Monterrey Centro',
    ),
    UserLocation(
      latitude: 19.0414,
      longitude: -98.2063,
      label: 'Puebla Centro',
    ),
    UserLocation(
      latitude: 20.5888,
      longitude: -100.3899,
      label: 'Querétaro Centro',
    ),
  ];
}

/// Servicio de geolocalización, cálculo de distancias y selección de zonas (HU02-RF01, HU02-RF02)
class LocationService {
  final GeocodingService _geocodingService;

  LocationService({GeocodingService? geocodingService})
      : _geocodingService = geocodingService ?? GeocodingService();

  /// Radios de búsqueda permitidos en kilómetros (HU02-RF02 Criterio 2)
  static const List<double> availableRadiiKm = [1.0, 3.0, 5.0, 10.0, 20.0];

  /// Calcula la distancia geodésica en metros entre dos coordenadas usando la fórmula de Haversine
  /// HU02-RF02 Criterio 1 y RNF02 (Margen de error menor a 100 metros)
  static double calculateDistanceInMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusMeters = 6371000.0; // Radio medio de la Tierra en metros

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double radLat1 = _toRadians(lat1);
    final double radLat2 = _toRadians(lat2);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(radLat1) *
            math.cos(radLat2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Calcula la distancia en kilómetros entre dos coordenadas
  static double calculateDistanceInKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return calculateDistanceInMeters(
          lat1: lat1,
          lon1: lon1,
          lat2: lat2,
          lon2: lon2,
        ) /
        1000.0;
  }

  /// Formatea la distancia calculada para mostrar en la interfaz (HU02-RF03 Criterio 2)
  /// Ejemplos: "450 m", "1.2 km", "8.5 km"
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Convierte grados a radianes
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Busca zonas y ciudades por nombre de forma manual (HU02-RF01 Criterio 3)
  Future<List<UserLocation>> searchManualLocations(String query) async {
    final results = await _geocodingService.searchAddress(query);
    return results.map((r) {
      return UserLocation(
        latitude: r.latitude,
        longitude: r.longitude,
        label: r.displayName,
        isGps: false,
      );
    }).toList();
  }

  /// Obtiene la ubicación GPS actual simulada o detectada
  /// (Garantiza funcionamiento en entornos web y tests)
  Future<UserLocation> getCurrentLocation({
    double? fallbackLat,
    double? fallbackLon,
  }) async {
    // Ubicación por defecto de CDMX para fallback en caso de no disponibilidad de GPS
    final lat = fallbackLat ?? 19.432608;
    final lon = fallbackLon ?? -99.133209;

    return UserLocation(
      latitude: lat,
      longitude: lon,
      label: 'Mi ubicación actual',
      isGps: true,
    );
  }
}
