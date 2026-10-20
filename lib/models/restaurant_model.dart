import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/schedule_utils.dart';

class DaySchedule {
  final bool abierto;
  final String apertura;
  final String cierre;

  const DaySchedule({
    required this.abierto,
    required this.apertura,
    required this.cierre,
  });

  factory DaySchedule.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const DaySchedule(
        abierto: false,
        apertura: '09:00',
        cierre: '22:00',
      );
    }
    return DaySchedule(
      abierto: data['abierto'] as bool? ?? false,
      apertura: data['apertura'] as String? ?? '09:00',
      cierre: data['cierre'] as String? ?? '22:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'abierto': abierto,
      'apertura': apertura,
      'cierre': cierre,
    };
  }
}

class RestaurantModel {
  final String id;
  final String nombre;
  final DocumentReference? adminId;
  final String telefono;
  final String correo;
  final String direccion;
  final String descripcion;
  final GeoPoint? coordenadas;
  final String logoUrl;
  final String imagenPrincipalUrl;
  final String estado;
  final bool perfilCompleto;
  final List<String> diasAbiertos;
  final Map<String, DaySchedule> horarios;
  final List<String> cierresEspeciales;
  final List<String> serviciosIds;
  final List<String> serviciosPersonalizados;
  final double? distanciaKm;
  final int capacidadMaxima;

  const RestaurantModel({
    required this.id,
    required this.nombre,
    this.adminId,
    this.telefono = '',
    this.correo = '',
    this.direccion = '',
    this.descripcion = '',
    this.coordenadas,
    this.logoUrl = '',
    this.imagenPrincipalUrl = '',
    this.estado = 'inactivo',
    this.perfilCompleto = false,
    this.diasAbiertos = const [],
    this.horarios = const {},
    this.cierresEspeciales = const [],
    this.serviciosIds = const [],
    this.serviciosPersonalizados = const [],
    this.distanciaKm,
    this.capacidadMaxima = 50,
  });

  // Getters de compatibilidad y campos públicos (HU01-RF01 Criterios 1 y 2)
  String get name => nombre;
  String get logo => logoUrl;
  String get imagenPrincipal => imagenPrincipalUrl;
  bool get isActivo => estado.trim().toLowerCase() == 'activo';

  // Helpers de horarios y apertura (HU03-RF01 Criterios 1, 2 y 4)
  bool isOpenAt(DateTime dateTime) =>
      ScheduleUtils.isRestaurantOpenAt(restaurant: this, dateTime: dateTime);

  bool isSpecialClosure(DateTime dateTime) =>
      ScheduleUtils.isSpecialClosureDate(
        cierresEspeciales: cierresEspeciales,
        dateTime: dateTime,
      );

  // Helpers de coordenadas y distancia (HU02-RF02 Criterios 1 y 4)
  bool get hasValidCoordinates {
    if (coordenadas == null) return false;
    final lat = coordenadas!.latitude;
    final lng = coordenadas!.longitude;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  String get distanciaFormateada {
    if (distanciaKm == null) return '';
    if (distanciaKm! < 1.0) {
      final meters = (distanciaKm! * 1000).round();
      return '$meters m';
    }
    return '${distanciaKm!.toStringAsFixed(1)} km';
  }

  factory RestaurantModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return RestaurantModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory RestaurantModel.fromMap(String id, Map<String, dynamic> data) {
    // Mapeo seguro de horarios
    final rawHorarios = data['horarios'] as Map<String, dynamic>? ?? {};
    final mappedHorarios = <String, DaySchedule>{};
    rawHorarios.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        mappedHorarios[key] = DaySchedule.fromMap(val);
      }
    });

    // Mapeo seguro de servicios
    final rawServicios = data['servicios'] as List<dynamic>? ?? [];
    final serviciosList = <String>[];
    for (final item in rawServicios) {
      if (item is DocumentReference) {
        serviciosList.add(item.id);
      } else if (item is String) {
        serviciosList.add(item);
      }
    }

    // Coordenadas con soporte para GeoPoint o Map de lat/lng
    GeoPoint? coords;
    if (data['coordenadas'] is GeoPoint) {
      coords = data['coordenadas'] as GeoPoint;
    } else if (data['coordenadas'] is Map<String, dynamic>) {
      final mapCoords = data['coordenadas'] as Map<String, dynamic>;
      final lat = (mapCoords['latitude'] ?? mapCoords['lat'] ?? 0.0) as num;
      final lng = (mapCoords['longitude'] ?? mapCoords['lng'] ?? 0.0) as num;
      coords = GeoPoint(lat.toDouble(), lng.toDouble());
    }

    return RestaurantModel(
      id: id,
      nombre: (data['nombre'] ?? data['name']) as String? ?? 'Sin nombre',
      adminId: data['adminId'] as DocumentReference?,
      telefono: data['telefono'] as String? ?? '',
      correo: data['correo'] as String? ?? '',
      direccion: data['direccion'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      coordenadas: coords,
      logoUrl: (data['logoUrl'] ?? data['logo']) as String? ?? '',
      imagenPrincipalUrl:
          (data['imagenPrincipalUrl'] ?? data['imagenPrincipal']) as String? ??
          '',
      estado: data['estado'] as String? ?? 'inactivo',
      perfilCompleto: data['perfilCompleto'] as bool? ?? false,
      diasAbiertos: List<String>.from(data['diasAbiertos'] as List<dynamic>? ?? []),
      horarios: mappedHorarios,
      cierresEspeciales: List<String>.from(
        data['cierresEspeciales'] as List<dynamic>? ?? [],
      ),
      serviciosIds: serviciosList,
      serviciosPersonalizados: List<String>.from(
        data['serviciosPersonalizados'] as List<dynamic>? ?? [],
      ),
      distanciaKm: (data['distanciaKm'] as num?)?.toDouble(),
      capacidadMaxima: (data['capacidadMaxima'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toMap() {
    final horariosMap = <String, dynamic>{};
    horarios.forEach((key, value) {
      horariosMap[key] = value.toMap();
    });

    final map = <String, dynamic>{
      'nombre': nombre,
      'telefono': telefono,
      'correo': correo,
      'direccion': direccion,
      'descripcion': descripcion,
      'coordenadas': coordenadas,
      'logoUrl': logoUrl,
      'logo': logoUrl,
      'imagenPrincipalUrl': imagenPrincipalUrl,
      'imagenPrincipal': imagenPrincipalUrl,
      'estado': estado,
      'perfilCompleto': perfilCompleto,
      'diasAbiertos': diasAbiertos,
      'horarios': horariosMap,
      'cierresEspeciales': cierresEspeciales,
      'capacidadMaxima': capacidadMaxima,
      'servicios': serviciosIds.map((id) =>
        FirebaseFirestore.instance.collection('serviciosCatalogo').doc(id)
      ).toList(),
      'serviciosPersonalizados': serviciosPersonalizados,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    if (distanciaKm != null) {
      map['distanciaKm'] = distanciaKm;
    }

    if (adminId != null) {
      map['adminId'] = adminId;
    }

    return map;
  }

  RestaurantModel copyWith({
    String? id,
    String? nombre,
    DocumentReference? adminId,
    String? telefono,
    String? correo,
    String? direccion,
    String? descripcion,
    GeoPoint? coordenadas,
    String? logoUrl,
    String? imagenPrincipalUrl,
    String? estado,
    bool? perfilCompleto,
    List<String>? diasAbiertos,
    Map<String, DaySchedule>? horarios,
    List<String>? cierresEspeciales,
    List<String>? serviciosIds,
    List<String>? serviciosPersonalizados,
    double? distanciaKm,
    int? capacidadMaxima,
  }) {
    return RestaurantModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      adminId: adminId ?? this.adminId,
      telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo,
      direccion: direccion ?? this.direccion,
      descripcion: descripcion ?? this.descripcion,
      coordenadas: coordenadas ?? this.coordenadas,
      logoUrl: logoUrl ?? this.logoUrl,
      imagenPrincipalUrl: imagenPrincipalUrl ?? this.imagenPrincipalUrl,
      estado: estado ?? this.estado,
      perfilCompleto: perfilCompleto ?? this.perfilCompleto,
      diasAbiertos: diasAbiertos ?? this.diasAbiertos,
      horarios: horarios ?? this.horarios,
      cierresEspeciales: cierresEspeciales ?? this.cierresEspeciales,
      serviciosIds: serviciosIds ?? this.serviciosIds,
      serviciosPersonalizados:
          serviciosPersonalizados ?? this.serviciosPersonalizados,
      distanciaKm: distanciaKm ?? this.distanciaKm,
      capacidadMaxima: capacidadMaxima ?? this.capacidadMaxima,
    );
  }
}
