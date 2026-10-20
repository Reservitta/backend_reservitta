import 'restaurant_model.dart';

/// Modelo compuesto que asocia un restaurante con su distancia calculada respecto al usuario (HU02-RF02)
class RestaurantWithDistance {
  final RestaurantModel restaurant;
  final double distanceKm;

  const RestaurantWithDistance({
    required this.restaurant,
    required this.distanceKm,
  });

  /// Distancia formateada para presentación amigable (ej: "850 m" o "2.4 km")
  String get formattedDistance {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  @override
  String toString() =>
      'RestaurantWithDistance(${restaurant.nombre}, distance: $formattedDistance)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantWithDistance &&
          runtimeType == other.runtimeType &&
          restaurant.id == other.restaurant.id &&
          distanceKm == other.distanceKm;

  @override
  int get hashCode => restaurant.id.hashCode ^ distanceKm.hashCode;
}
