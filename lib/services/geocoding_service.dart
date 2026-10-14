import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final double latitude;
  final double longitude;
  final String displayName;

  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

class GeocodingService {
  final http.Client _client;

  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  /// Busca coordenadas usando la API gratuita de Nominatim (OpenStreetMap)
  /// Retorna una lista de sugerencias o resultados coincidentes.
  Future<List<GeocodingResult>> searchAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || cleanQuery.length < 3) {
      return [];
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': cleanQuery,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
      });

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'ReservittaApp/1.0 (contacto@reservitta.com)',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.map((item) {
          final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
          final name = item['display_name'] as String? ?? cleanQuery;
          return GeocodingResult(
            latitude: lat,
            longitude: lon,
            displayName: name,
          );
        }).where((r) => r.latitude != 0.0 && r.longitude != 0.0).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Geocodificación inversa: a partir de lat/lng obtiene la dirección legible
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'format': 'json',
      });

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'ReservittaApp/1.0 (contacto@reservitta.com)',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
