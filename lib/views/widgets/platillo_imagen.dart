import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Foto de un platillo: acepta una dirección `http(s)` (Cloud Storage) o una imagen
/// guardada dentro del propio documento como `data:image/...;base64,...` (respaldo
/// cuando Storage no está disponible). Si no hay imagen válida muestra [fallback].
class PlatilloImagen extends StatelessWidget {
  final String url;
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;

  const PlatilloImagen({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  /// Evita decodificar el mismo base64 en cada reconstrucción de una lista larga.
  static final Map<String, Uint8List> _cache = {};
  static const int _maxEntradas = 80;

  static Uint8List? _decodificar(String dataUri) {
    final guardada = _cache[dataUri];
    if (guardada != null) return guardada;
    final coma = dataUri.indexOf(',');
    if (coma < 0) return null;
    try {
      final bytes = base64Decode(dataUri.substring(coma + 1));
      if (_cache.length >= _maxEntradas) _cache.clear();
      _cache[dataUri] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:image')) {
      final bytes = _decodificar(url);
      if (bytes == null) return fallback;
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}
