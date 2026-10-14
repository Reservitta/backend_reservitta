import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseInitService {
  final FirebaseFirestore _db;

  DatabaseInitService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> initFullDatabaseSchema() async {
    // 1. serviciosCatalogo (Colección Raíz)
    final servicioRef = _db.collection('serviciosCatalogo').doc('wifi');
    await servicioRef.set({
      'nombre': 'Wi-Fi Gratis',
      'icono': 'wifi',
      'activo': true,
    });

    // 2. users (Colección Raíz - sin subcolección dispositivos ya que fue descartada)
    final userRef = _db.collection('users').doc('user_demo');
    await userRef.set({
      'uid': 'user_demo',
      'rol': 'admin',
      'nombre': 'Administrador Demo',
      'correo': 'admin@reservitta.com',
      'telefono': '555-0100',
      'restauranteId': _db.collection('restaurants').doc('restaurante_demo'),
      'canalPreferido': 'email',
      'fechaAlta': FieldValue.serverTimestamp(),
    });

    // 3. restaurants (Colección Raíz)
    final restaurantRef = _db.collection('restaurants').doc('restaurante_demo');
    await restaurantRef.set({
      'adminId': userRef,
      'nombre': 'Restaurante Reservitta Demo',
      'telefono': '555-0199',
      'correo': 'contacto@reservittademo.com',
      'direccion': 'Av. Principal 123, Ciudad',
      'coordenadas': const GeoPoint(19.432608, -99.133209),
      'geohash': '9g3w',
      'logoUrl': '',
      'imagenPrincipalUrl': '',
      'estado': 'activo',
      'perfilCompleto': true,
      'zonaHoraria': 'America/Mexico_City',
      'capacidadMaxima': 100,
      'diasAbiertos': [
        'lunes',
        'martes',
        'miercoles',
        'jueves',
        'viernes',
        'sabado',
        'domingo'
      ],
      'horarios': {
        'lunes': {'abierto': true, 'apertura': '12:00', 'cierre': '22:00'}
      },
      'cierresEspeciales': [],
      'servicios': [servicioRef],
      'serviciosPersonalizados': ['Música en vivo'],
      'configuracion': {
        'diasMaxAnticipacion': 60,
        'margenLimpiezaMin': 15,
        'intervaloHorariosMin': 30,
        'limiteCambioMin': 120,
        'recordatorioMin': 120,
        'umbralAlertaMin': null,
      },
      'creadoEn': FieldValue.serverTimestamp(),
    });

    // 4. Subcolección: sucursales
    final sucursalRef = restaurantRef.collection('sucursales').doc('sucursal_1');
    await sucursalRef.set({
      'nombre': 'Sucursal Centro',
      'direccion': 'Calle 5 de Mayo #45',
      'telefono': '555-0198',
    });

    // 5. Subcolección: zonas
    final zonaRef = restaurantRef.collection('zonas').doc('zona_1');
    await zonaRef.set({
      'nombre': 'Terraza Principal',
      'orden': 1,
    });

    // 6. Subcolección: mesas
    final mesaRef = restaurantRef.collection('mesas').doc('mesa_1');
    await mesaRef.set({
      'nombre': 'Mesa 1',
      'capacidad': 4,
      'combinable': true,
      'combinableCon': [],
      'zonaId': zonaRef,
      'x': 10.0,
      'y': 20.0,
      'forma': 'cuadrada',
      'ancho': 100.0,
      'alto': 100.0,
      'estadoManual': null,
    });

    // 7. Subcolección: ocupacionMesas
    final ocupacionRef =
        restaurantRef.collection('ocupacionMesas').doc('mesa_1_2026-10-10');
    await ocupacionRef.set({
      'mesaId': mesaRef,
      'fechaLocal': '2026-10-10',
      'intervalos': [
        {'reservaId': 'reserva_demo', 'inicioMin': 840, 'finMin': 945}
      ],
    });

    // 8. Subcolección: categorias
    final categoriaRef = restaurantRef.collection('categorias').doc('categoria_1');
    await categoriaRef.set({
      'nombre': 'Entradas',
      'nombreNormalizado': 'entradas',
      'orden': 1,
      'tipo': 'entrada',
    });

    // 9. Subcolección: platillos
    final platilloRef = restaurantRef.collection('platillos').doc('platillo_1');
    await platilloRef.set({
      'categoriaId': categoriaRef,
      'nombre': 'Guacamole Tradicional',
      'descripcion': 'Aguacate fresco con totopos y pico de gallo',
      'precio': 120.0,
      'imagenUrl': '',
      'estado': 'activo',
      'orden': 1,
      'etiquetas': ['para compartir', 'vegano'],
      'placeholderObservacion': 'Ej. Sin cebolla',
      'limiteCaracteresObs': 150,
    });

    // 10. Subcolección: ocasiones
    final ocasionRef = restaurantRef.collection('ocasiones').doc('ocasion_1');
    await ocasionRef.set({
      'nombre': 'Cumpleaños',
      'icono': 'cake',
      'descripcionCorta': 'Celebra tu cumpleaños con nosotros',
    });

    // 11. Sub-subcolección: experiencias (dentro de ocasiones)
    final experienciaRef =
        ocasionRef.collection('experiencias').doc('experiencia_1');
    await experienciaRef.set({
      'nombre': 'Pastel de Cumpleaños con Vela',
      'descripcionCorta': 'Pastel individual personalizado',
      'precio': 150.0,
      'tipo': 'postre_con_felicitacion',
      'requiereInformacion': true,
      'grupoExclusion': null,
      'orden': 1,
    });

    // 12. reservations (Colección Raíz)
    final reservaRef = _db.collection('reservations').doc('reserva_demo');
    await reservaRef.set({
      'restauranteId': restaurantRef,
      'usuarioId': userRef,
      'restauranteNombre': 'Restaurante Reservitta Demo',
      'contacto': {
        'nombre': 'Juan Pérez',
        'correo': 'juan@example.com',
        'telefono': '555-1234'
      },
      'fechaLocal': '2026-10-10',
      'inicio': FieldValue.serverTimestamp(),
      'fin': FieldValue.serverTimestamp(),
      'duracionMin': 90,
      'personas': 4,
      'mesaIds': [mesaRef],
      'mesasNombres': ['Mesa 1'],
      'estado': 'confirmada',
      'tienePreorden': true,
      'tieneObservaciones': false,
      'preorden': {
        'items': [
          {
            'platilloId': 'platillo_1',
            'nombre': 'Guacamole Tradicional',
            'precio': 120.0,
            'cantidad': 2,
            'total': 240.0,
            'observacion': '',
            'mensajeFelicitacion': '',
          }
        ],
        'estado': 'pendiente',
        'estadoActualizadoEn': FieldValue.serverTimestamp(),
      },
      'ocasion': {
        'ocasionId': 'ocasion_1',
        'nombre': 'Cumpleaños',
        'experiencias': [
          {'experienciaId': 'experiencia_1', 'nombre': 'Pastel de Cumpleaños'}
        ]
      },
      'totales': {
        'subtotalPreorden': 240.0,
        'totalExperiencias': 150.0,
        'total': 390.0,
      },
      'tokenGestionHash': 'hash_demo_123',
      'tokenExpiraEn': FieldValue.serverTimestamp(),
      'creadaEn': FieldValue.serverTimestamp(),
    });

    // 13. Subcolección: historialEstados (dentro de reservations)
    final historialRef =
        reservaRef.collection('historialEstados').doc('cambio_1');
    await historialRef.set({
      'entidad': 'reserva',
      'estadoAnterior': 'pendiente',
      'estadoNuevo': 'confirmada',
      'cambiadoPor': userRef,
      'cambiadoEn': FieldValue.serverTimestamp(),
      'motivo': 'Creación inicial',
    });

    // 14. notificaciones (Colección Raíz)
    final notificacionRef =
        _db.collection('notificaciones').doc('reserva_confirmacion_demo');
    await notificacionRef.set({
      'reservaId': reservaRef,
      'restauranteId': restaurantRef,
      'destinatarioUid': userRef,
      'tipo': 'confirmacion',
      'canal': 'email',
      'destino': 'admin@reservitta.com',
      'payload': {'mensaje': 'Reserva confirmada con éxito'},
      'umbralMin': 30,
      'programadaPara': FieldValue.serverTimestamp(),
      'estado': 'pendiente',
      'intentos': 0,
      'ultimoError': null,
      'enviadaEn': null,
    });
  }
}
