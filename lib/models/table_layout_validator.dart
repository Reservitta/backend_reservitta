import 'mesa_model.dart';
import 'zona_model.dart';

/// Se rechazó un cambio del plano de mesas (HU34). [campos] indica qué campo falló.
class LayoutException implements Exception {
  final String message;

  /// Errores por campo (nombre, capacidad, ancho, alto, x, y, forma, zona), si aplica.
  final Map<String, String> campos;

  const LayoutException(this.message, {this.campos = const {}});

  @override
  String toString() => message;
}

/// Reglas del plano de mesas y de los espacios (HU34-RF01, HU34-RF02).
class TableLayoutValidator {
  TableLayoutValidator._();

  static const int capacidadMinima = 1;
  static const int capacidadMaxima = 50;
  static const double tamanoMinimo = 40;
  static const double tamanoMaximo = 300;
  static const int zonaNombreMin = 2;
  static const int zonaNombreMax = 40;
  static const int mesaNombreMax = 30;

  /// Compara nombres sin importar mayúsculas, acentos ni espacios repetidos.
  static String normalizarNombre(String texto) {
    var t = texto.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
    acentos.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  /// Error del nombre de un espacio, o null si es válido.
  static String? validarNombreZona(
    String nombre,
    Iterable<ZonaModel> existentes, {
    String? ignorarId,
  }) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return 'Escribe el nombre del espacio.';
    if (limpio.length < zonaNombreMin) {
      return 'El nombre del espacio debe tener al menos $zonaNombreMin caracteres.';
    }
    if (limpio.length > zonaNombreMax) {
      return 'El nombre del espacio no puede pasar de $zonaNombreMax caracteres.';
    }
    final clave = normalizarNombre(limpio);
    for (final z in existentes) {
      if (z.id != ignorarId && normalizarNombre(z.nombre) == clave) {
        return 'Ya existe un espacio llamado "${z.nombre}".';
      }
    }
    return null;
  }

  /// Errores de una mesa por campo; vacío si es válida. [otras] son las demás mesas del
  /// restaurante (para el nombre único) y [zonaIds] los espacios que existen.
  static Map<String, String> validarMesa(
    MesaModel mesa, {
    required Iterable<MesaModel> otras,
    required Set<String> zonaIds,
  }) {
    final errores = <String, String>{};

    final nombre = mesa.nombre.trim();
    if (nombre.isEmpty) {
      errores['nombre'] = 'Escribe el nombre o número de la mesa.';
    } else if (nombre.length > mesaNombreMax) {
      errores['nombre'] = 'El nombre no puede pasar de $mesaNombreMax caracteres.';
    } else {
      final clave = normalizarNombre(nombre);
      final repetida = otras.any(
        (o) => o.id != mesa.id && normalizarNombre(o.nombre) == clave,
      );
      if (repetida) errores['nombre'] = 'Ya hay una mesa llamada "$nombre".';
    }

    if (mesa.capacidad < capacidadMinima || mesa.capacidad > capacidadMaxima) {
      errores['capacidad'] =
          'La capacidad debe estar entre $capacidadMinima y $capacidadMaxima sillas.';
    }

    if (!MesaModel.formasValidas.contains(mesa.forma)) {
      errores['forma'] = 'Elige redonda, cuadrada o rectangular.';
    }

    if (mesa.ancho < tamanoMinimo || mesa.ancho > tamanoMaximo) {
      errores['ancho'] =
          'El ancho debe estar entre ${tamanoMinimo.round()} y ${tamanoMaximo.round()}.';
    }
    if (mesa.alto < tamanoMinimo || mesa.alto > tamanoMaximo) {
      errores['alto'] =
          'El alto debe estar entre ${tamanoMinimo.round()} y ${tamanoMaximo.round()}.';
    }

    if (mesa.x == null || mesa.x! < 0) errores['x'] = 'La mesa debe estar dentro del plano.';
    if (mesa.y == null || mesa.y! < 0) errores['y'] = 'La mesa debe estar dentro del plano.';

    final zona = mesa.zonaId;
    if (zona != null && zona.isNotEmpty && !zonaIds.contains(zona)) {
      errores['zona'] = 'El espacio de esta mesa ya no existe.';
    }
    return errores;
  }

  /// Hace simétrica la combinación entre mesas y quita referencias a mesas que no
  /// existen o a la misma mesa: si A se combina con B, B también con A. Una mesa que
  /// no es combinable no se une a ninguna.
  static List<MesaModel> normalizarCombinaciones(List<MesaModel> mesas) {
    final ids = {for (final m in mesas) m.id};
    final porId = {for (final m in mesas) m.id: m};
    final pares = <String, Set<String>>{for (final m in mesas) m.id: <String>{}};

    for (final m in mesas) {
      if (!m.combinable) continue;
      for (final otro in m.combinableCon) {
        final destino = porId[otro];
        if (otro == m.id || !ids.contains(otro) || destino == null || !destino.combinable) {
          continue;
        }
        pares[m.id]!.add(otro);
        pares[otro]!.add(m.id);
      }
    }
    return [
      for (final m in mesas)
        m.copyWith(
          combinableCon: m.combinable ? (pares[m.id]!.toList()..sort()) : const <String>[],
        ),
    ];
  }

  /// Primer lugar libre (cuadrícula de [paso]) donde cabe una mesa de [ancho] x [alto]
  /// sin empalmarse con las [existentes] del mismo espacio.
  static ({double x, double y}) primerLugarLibre({
    required Iterable<MesaModel> existentes,
    required double ancho,
    required double alto,
    double paso = 20,
    double anchoPlano = 800,
    double separacion = 20,
  }) {
    bool choca(double x, double y) {
      for (final m in existentes) {
        if (!m.tienePosicion) continue;
        final izq = m.x! - separacion;
        final der = m.x! + m.ancho + separacion;
        final arriba = m.y! - separacion;
        final abajo = m.y! + m.alto + separacion;
        if (x < der && x + ancho > izq && y < abajo && y + alto > arriba) return true;
      }
      return false;
    }

    for (var y = paso; y < 4000; y += paso) {
      for (var x = paso; x + ancho <= anchoPlano; x += paso) {
        if (!choca(x, y)) return (x: x, y: y);
      }
    }
    return (x: paso, y: paso);
  }

  /// Ajusta [valor] a la cuadrícula más cercana.
  static double alinear(double valor, {double paso = 10}) =>
      (valor / paso).round() * paso;
}
