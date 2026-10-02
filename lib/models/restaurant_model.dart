import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantModel {
  final String id;
  final String name;

  const RestaurantModel({
    required this.id,
    required this.name,
  });

  factory RestaurantModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RestaurantModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Sin nombre',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }
}
