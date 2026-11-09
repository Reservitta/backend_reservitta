import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Acceso al token de notificaciones push del dispositivo (FCM).
abstract class PushTokenProvider {
  /// Pide permiso para mostrar notificaciones; false si el usuario lo negó.
  Future<bool> pedirPermiso();

  /// Token FCM del dispositivo, o null si no se pudo obtener.
  Future<String?> obtenerToken();

  /// Nuevos tokens cuando FCM renueva el del dispositivo.
  Stream<String> get tokenRenovado;
}

/// Implementación con `firebase_messaging`. En web FCM necesita la clave VAPID del
/// proyecto (`--dart-define=FCM_VAPID_KEY=...`).
class FirebasePushTokenProvider implements PushTokenProvider {
  static const String _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> pedirPermiso() async {
    final ajustes = await _messaging.requestPermission();
    return ajustes.authorizationStatus == AuthorizationStatus.authorized ||
        ajustes.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> obtenerToken() => _messaging.getToken(
        vapidKey: kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null,
      );

  @override
  Stream<String> get tokenRenovado => _messaging.onTokenRefresh;
}

/// Registra el dispositivo del administrador para recibir las alertas de llegada por
/// push (HU30-RF02). El token queda en `restaurants/{id}/dispositivosAdmin/{token}`, de
/// donde la Cloud Function `enviarPushAdmin` toma los destinatarios.
class AdminPushTokenService {
  final FirebaseFirestore? _firestoreInstance;
  final PushTokenProvider? _providerInstance;
  final String Function()? _plataforma;
  StreamSubscription<String>? _renovacion;

  AdminPushTokenService({
    FirebaseFirestore? firestore,
    PushTokenProvider? provider,
    String Function()? plataforma,
  })  : _firestoreInstance = firestore,
        _providerInstance = provider,
        // ignore: prefer_initializing_formals
        _plataforma = plataforma;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  PushTokenProvider get _provider => _providerInstance ?? FirebasePushTokenProvider();

  String get _plataformaActual =>
      _plataforma?.call() ?? (kIsWeb ? 'web' : defaultTargetPlatform.name);

  CollectionReference<Map<String, dynamic>> _dispositivos(String restauranteId) =>
      _db.collection('restaurants').doc(restauranteId).collection('dispositivosAdmin');

  Future<void> _guardar(String restauranteId, String usuarioId, String token) {
    return _dispositivos(restauranteId).doc(token).set({
      'usuarioId': usuarioId,
      'plataforma': _plataformaActual,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Pide permiso, obtiene el token y lo guarda. Devuelve true si el dispositivo quedó
  /// registrado; nunca lanza: un fallo aquí no debe impedir usar la app.
  Future<bool> registrar({
    required String restauranteId,
    required String usuarioId,
  }) async {
    try {
      final provider = _provider;
      if (!await provider.pedirPermiso()) return false;
      final token = await provider.obtenerToken();
      if (token == null || token.isEmpty) return false;
      await _guardar(restauranteId, usuarioId, token);
      await _renovacion?.cancel();
      _renovacion = provider.tokenRenovado.listen((nuevo) {
        _guardar(restauranteId, usuarioId, nuevo).catchError((_) {});
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quita el dispositivo (por ejemplo al cerrar sesión) para que deje de recibir avisos.
  Future<void> quitar(String restauranteId) async {
    try {
      final token = await _provider.obtenerToken();
      if (token != null && token.isNotEmpty) {
        await _dispositivos(restauranteId).doc(token).delete();
      }
    } catch (_) {}
  }

  void dispose() {
    _renovacion?.cancel();
  }
}
