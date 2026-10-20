import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'geocoding_service.dart';

/// Representa el estado del permiso de ubicación (HU02-RF01 Criterios 1, 2, 3)
enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

/// Representa el resultado de una solicitud de obtención de coordenadas (HU02-RF01)
class LocationResult {
  final UserLocation? location;
  final LocationPermissionStatus status;
  final String? message;

  const LocationResult({
    this.location,
    required this.status,
    this.message,
  });

  const LocationResult.success(UserLocation loc)
      : location = loc,
        status = LocationPermissionStatus.granted,
        message = null;

  const LocationResult.denied([String? msg])
      : location = null,
        status = LocationPermissionStatus.denied,
        message = msg ?? 'Permiso de ubicación denegado por el usuario.';

  const LocationResult.permanentlyDenied([String? msg])
      : location = null,
        status = LocationPermissionStatus.permanentlyDenied,
        message = msg ?? 'Permiso de ubicación denegado permanentemente en la configuración del dispositivo.';

  const LocationResult.serviceDisabled([String? msg])
      : location = null,
        status = LocationPermissionStatus.serviceDisabled,
        message = msg ?? 'El servicio de ubicación o GPS está desactivado en el dispositivo.';

  bool get isSuccess => status == LocationPermissionStatus.granted && location != null;
  bool get isDenied => status == LocationPermissionStatus.denied || status == LocationPermissionStatus.permanentlyDenied;
  bool get isGpsDisabled => status == LocationPermissionStatus.serviceDisabled;
}

/// Contrato para el proveedor de geolocalización del dispositivo
abstract class LocationProvider {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermissionStatus> checkPermission();
  Future<LocationPermissionStatus> requestPermission();
  Future<UserLocation?> getCurrentPosition();
}

/// Proveedor por defecto de ubicación
class DefaultLocationProvider implements LocationProvider {
  bool isServiceEnabled;
  LocationPermissionStatus permissionStatus;
  UserLocation? mockPosition;

  DefaultLocationProvider({
    this.isServiceEnabled = true,
    this.permissionStatus = LocationPermissionStatus.granted,
    this.mockPosition,
  });

  void setServiceEnabled(bool enabled) => isServiceEnabled = enabled;
  void setPermissionStatus(LocationPermissionStatus status) => permissionStatus = status;
  void setMockPosition(UserLocation? position) => mockPosition = position;

  @override
  Future<bool> isLocationServiceEnabled() async => isServiceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => permissionStatus;

  @override
  Future<LocationPermissionStatus> requestPermission() async => permissionStatus;

  @override
  Future<UserLocation?> getCurrentPosition() async {
    if (mockPosition != null) return mockPosition;
    // Coordenadas predeterminadas de centro si está habilitado
    return const UserLocation(
      latitude: 19.432608,
      longitude: -99.133209,
      label: 'Mi ubicación actual',
      isGps: true,
    );
  }
}

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
  final LocationProvider _locationProvider;

  LocationService({
    GeocodingService? geocodingService,
    LocationProvider? locationProvider,
  })  : _geocodingService = geocodingService ?? GeocodingService(),
        _locationProvider = locationProvider ?? DefaultLocationProvider();

  LocationProvider get locationProvider => _locationProvider;

  /// Radios de búsqueda permitidos en kilómetros (HU02-RF02 Criterio 2)
  static const List<double> availableRadiiKm = [1.0, 3.0, 5.0, 10.0, 20.0];

  /// HU02-RF01 Criterios 1, 2 y 3:
  /// Solicita el permiso y obtiene las coordenadas actuales solo cuando el usuario lo activa.
  /// Si deniega el permiso o el GPS está apagado, retorna el estado correspondiente para ofrecer selección manual.
  Future<LocationResult> requestCurrentLocation() async {
    // 1. Verificar si el servicio de GPS está activo en el dispositivo
    final isGpsOn = await _locationProvider.isLocationServiceEnabled();
    if (!isGpsOn) {
      return const LocationResult.serviceDisabled(
        'El GPS o servicio de ubicación está desactivado en tu dispositivo.',
      );
    }

    // 2. Verificar y solicitar permiso de ubicación
    var permission = await _locationProvider.checkPermission();
    if (permission == LocationPermissionStatus.denied) {
      permission = await _locationProvider.requestPermission();
    }

    if (permission == LocationPermissionStatus.denied) {
      return const LocationResult.denied(
        'Has denegado el permiso de ubicación.',
      );
    }

    if (permission == LocationPermissionStatus.permanentlyDenied) {
      return const LocationResult.permanentlyDenied(
        'El permiso de ubicación está bloqueado permanentemente en la configuración del dispositivo.',
      );
    }

    // 3. Obtener coordenadas actuales si el permiso fue concedido (HU02-RF01 Criterio 2)
    final position = await _locationProvider.getCurrentPosition();
    if (position != null) {
      return LocationResult.success(position);
    }

    return const LocationResult.serviceDisabled(
      'No fue posible obtener tu posición GPS actual.',
    );
  }

  /// Método de conveniencia compatible hacia atrás
  Future<UserLocation> getCurrentLocation({
    double? fallbackLat,
    double? fallbackLon,
  }) async {
    final result = await requestCurrentLocation();
    if (result.isSuccess) {
      return result.location!;
    }

    return UserLocation(
      latitude: fallbackLat ?? 19.432608,
      longitude: fallbackLon ?? -99.133209,
      label: 'Mi ubicación actual',
      isGps: true,
    );
  }

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
}
