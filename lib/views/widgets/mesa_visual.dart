import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/elemento_plano.dart';
import '../../models/mesa_model.dart';
import '../../models/table_layout_validator.dart';
import '../../theme/app_theme.dart';

/// Colores de una mesa en el plano: la superficie lleva un tinte suave del estado, el
/// borde el color pleno y las sillas un tono apagado. El estado nunca depende solo del
/// color: cada mesa lleva además un ícono y, en las listas y leyendas, su nombre.
///
/// Las combinaciones siguen la convención de los sistemas de reservas y de punto de
/// venta: verde libre, rojo ocupada, azul combinada, gris fuera de servicio y ámbar
/// para las que no sirven al grupo.
class MesaPaleta {
  final Color superficie;
  final Color borde;
  final Color silla;
  final Color texto;

  const MesaPaleta({
    required this.superficie,
    required this.borde,
    required this.silla,
    required this.texto,
  });

  static const libre = MesaPaleta(
    superficie: Color(0xFFF2F9F4),
    borde: Color(0xFF3F8A5F),
    silla: Color(0xFFB7D6C2),
    texto: Color(0xFF1D5438),
  );

  static const ocupada = MesaPaleta(
    superficie: Color(0xFFFBEFED),
    borde: Color(0xFFB5473A),
    silla: Color(0xFFE2B5AE),
    texto: Color(0xFF7A2A21),
  );

  static const combinada = MesaPaleta(
    superficie: Color(0xFFEFF4FA),
    borde: Color(0xFF3F6C9E),
    silla: Color(0xFFB5C9DE),
    texto: Color(0xFF244A73),
  );

  static const fueraDeServicio = MesaPaleta(
    superficie: Color(0xFFF1F2F3),
    borde: Color(0xFF858B90),
    silla: Color(0xFFD2D5D8),
    texto: Color(0xFF51565B),
  );

  static const noAdecuada = MesaPaleta(
    superficie: Color(0xFFFFF7E3),
    borde: Color(0xFFA87408),
    silla: Color(0xFFEAD7A4),
    texto: Color(0xFF6E4B00),
  );

  static const seleccionada = MesaPaleta(
    superficie: AppColors.marca,
    borde: Color(0xFF4A2B17),
    silla: Color(0xFFD7B898),
    texto: Colors.white,
  );

  /// Editor del plano: mesa sin estado, blanca con borde café suave.
  static const editor = MesaPaleta(
    superficie: Colors.white,
    borde: AppColors.borde,
    silla: Color(0xFFD9CCBC),
    texto: AppColors.texto,
  );

  static const editorSeleccionada = MesaPaleta(
    superficie: AppColors.marcaSuave,
    borde: AppColors.marca,
    silla: AppColors.marcaMedia,
    texto: AppColors.texto,
  );

  static const editorConError = MesaPaleta(
    superficie: Color(0xFFFDECEA),
    borde: AppColors.error,
    silla: Color(0xFFEFB9B4),
    texto: AppColors.texto,
  );
}

/// Dibuja una silla por cada lugar de la mesa, repartidas alrededor.
class SillasPainter extends CustomPainter {
  final int capacidad;
  final String forma;
  final Color color;

  /// Color de relleno de las sillas; si no se indica, es [color] suavizado.
  final Color? relleno;

  const SillasPainter({
    required this.capacidad,
    required this.forma,
    required this.color,
    this.relleno,
  });

  static const double radio = 7;
  static const double separacion = 9;

  /// Centros de las sillas respecto de la esquina de la mesa.
  static List<Offset> posiciones(int capacidad, String forma, Size size) {
    final n = capacidad.clamp(0, TableLayoutValidator.capacidadMaxima);
    final w = size.width;
    final h = size.height;
    final lista = <Offset>[];
    if (forma == MesaModel.formaRedonda) {
      final rx = w / 2 + separacion + radio;
      final ry = h / 2 + separacion + radio;
      for (var i = 0; i < n; i++) {
        final a = -math.pi / 2 + 2 * math.pi * i / math.max(n, 1);
        lista.add(Offset(w / 2 + rx * math.cos(a), h / 2 + ry * math.sin(a)));
      }
      return lista;
    }
    final d = separacion + radio;
    final perimetro = 2 * (w + h);
    for (var i = 0; i < n; i++) {
      var t = (i + 0.5) * perimetro / n;
      if (t < w) {
        lista.add(Offset(t, -d));
      } else if ((t -= w) < h) {
        lista.add(Offset(w + d, t));
      } else if ((t -= h) < w) {
        lista.add(Offset(w - t, h + d));
      } else {
        t -= w;
        lista.add(Offset(-d, h - t));
      }
    }
    return lista;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Paint()..color = relleno ?? color.withAlpha(60);
    final borde = Paint()
      ..color = color.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final p in posiciones(capacidad, forma, size)) {
      canvas.drawCircle(p, radio, fondo);
      canvas.drawCircle(p, radio, borde);
    }
  }

  @override
  bool shouldRepaint(covariant SillasPainter old) =>
      old.capacidad != capacidad ||
      old.forma != forma ||
      old.color != color ||
      old.relleno != relleno;
}

/// Una mesa del plano: superficie con sombra suave, sillas alrededor, nombre,
/// capacidad y un ícono de estado.
class MesaVisual extends StatelessWidget {
  final MesaModel mesa;
  final MesaPaleta paleta;
  final IconData? icono;

  /// Texto bajo el nombre; por defecto "N pers.".
  final String? detalle;
  final bool seleccionada;
  final bool mostrarSillas;
  final double grosorBorde;

  /// Falso para vistas previas pequeñas (paleta): solo la forma y las sillas.
  final bool mostrarTexto;

  const MesaVisual({
    super.key,
    required this.mesa,
    required this.paleta,
    this.icono,
    this.detalle,
    this.seleccionada = false,
    this.mostrarSillas = true,
    this.grosorBorde = 1.8,
    this.mostrarTexto = true,
  });

  @override
  Widget build(BuildContext context) {
    final redonda = mesa.forma == MesaModel.formaRedonda;
    final angulo = mesa.rotacion * math.pi / 180;

    // La mesa y sus sillas giran; el texto se queda derecho para que se lea.
    final cuerpo = CustomPaint(
      painter: mostrarSillas
          ? SillasPainter(
              capacidad: mesa.capacidad,
              forma: mesa.forma,
              color: paleta.borde,
              relleno: paleta.silla,
            )
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: paleta.superficie,
          shape: redonda ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: redonda ? null : BorderRadius.circular(8),
          border: Border.all(
            color: paleta.borde,
            width: seleccionada ? grosorBorde + 1.4 : grosorBorde,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: seleccionada ? 0.22 : 0.10),
              blurRadius: seleccionada ? 10 : 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );

    final etiqueta = FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) Icon(icono, color: paleta.texto, size: 18),
            Text(
              mesa.nombre.isEmpty ? '¿Nombre?' : mesa.nombre,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: paleta.texto,
              ),
            ),
            Text(
              detalle ?? '${mesa.capacidad} pers.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: paleta.texto.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Transform.rotate(angle: angulo, child: cuerpo),
        if (mostrarTexto) Center(child: etiqueta),
      ],
    );
  }
}

/// Ubica una mesa en un [Stack]: la caja ocupa el rectángulo de la mesa ya girada (así
/// se puede tocar y arrastrar por cualquier parte) y la mesa va centrada dentro.
/// [dx] y [dy] se restan a la posición (para planos que empiezan en la primera mesa).
class MesaUbicada extends StatelessWidget {
  final MesaModel mesa;
  final double dx;
  final double dy;
  final Widget child;

  /// Envuelve la mesa ubicada (por ejemplo, con un detector de toques).
  final Widget Function(BuildContext context, Widget ubicada)? envoltura;

  const MesaUbicada({
    super.key,
    required this.mesa,
    required this.child,
    this.dx = 0,
    this.dy = 0,
    this.envoltura,
  });

  @override
  Widget build(BuildContext context) {
    final caja = mesa.cajaRotada;
    final centrada = Center(
      child: SizedBox(width: mesa.ancho, height: mesa.alto, child: child),
    );
    return Positioned(
      left: caja.left - dx,
      top: caja.top - dy,
      width: caja.width,
      height: caja.height,
      child: envoltura == null ? centrada : envoltura!(context, centrada),
    );
  }
}

/// Un elemento decorativo del salón (barra, pared, puerta, planta…).
class ElementoVisual extends StatelessWidget {
  final ElementoPlano elemento;
  final bool seleccionado;

  const ElementoVisual({super.key, required this.elemento, this.seleccionado = false});

  @override
  Widget build(BuildContext context) {
    final e = elemento;
    final estilo = ElementoPlano.estilo(e.tipo);
    final circular = e.esCircular;
    final delgado = e.tipo == ElementoPlano.pared ||
        e.tipo == ElementoPlano.ventana ||
        e.tipo == ElementoPlano.puerta;
    final esTexto = e.tipo == ElementoPlano.texto;
    final borde = seleccionado ? AppColors.marca : estilo.borde;

    Widget contenido;
    if (delgado) {
      contenido = e.tipo == ElementoPlano.puerta
          ? CustomPaint(painter: _PuertaPainter(color: estilo.borde, relleno: estilo.relleno))
          : const SizedBox.expand();
    } else if (circular) {
      contenido = Center(child: Icon(estilo.icono, color: estilo.tinta, size: math.min(e.ancho, e.alto) * 0.55));
    } else {
      final texto = e.etiqueta.isEmpty ? estilo.nombre : e.etiqueta;
      contenido = Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!esTexto) ...[
                  Icon(estilo.icono, color: estilo.tinta, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(
                  texto,
                  style: TextStyle(
                    fontWeight: esTexto ? FontWeight.w700 : FontWeight.w600,
                    fontSize: esTexto ? 18 : 14,
                    color: estilo.tinta,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final caja = Container(
      decoration: BoxDecoration(
        color: esTexto ? Colors.transparent : estilo.relleno,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(delgado ? 2 : 6),
        border: delgado && e.tipo == ElementoPlano.puerta
            ? null
            : Border.all(
                color: esTexto && !seleccionado ? Colors.transparent : borde,
                width: seleccionado ? 2.4 : 1.4,
              ),
      ),
      child: contenido,
    );

    return Transform.rotate(angle: e.rotacion * math.pi / 180, child: caja);
  }
}

class _PuertaPainter extends CustomPainter {
  final Color color;
  final Color relleno;

  const _PuertaPainter({required this.color, required this.relleno});

  @override
  void paint(Canvas canvas, Size size) {
    // Hoja de la puerta y arco por donde abre.
    final linea = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = relleno);
    canvas.drawRect(Offset.zero & size, linea);
    final radio = size.width * 0.5;
    final arco = Rect.fromCircle(center: Offset(0, size.height), radius: radio);
    canvas.drawArc(arco, -math.pi / 2, math.pi / 2, false, linea..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant _PuertaPainter old) => old.color != color || old.relleno != relleno;
}

/// Ubica un elemento decorativo en un [Stack] (ver [MesaUbicada]).
class ElementoUbicado extends StatelessWidget {
  final ElementoPlano elemento;
  final double dx;
  final double dy;
  final Widget child;
  final Widget Function(BuildContext context, Widget ubicado)? envoltura;

  const ElementoUbicado({
    super.key,
    required this.elemento,
    required this.child,
    this.dx = 0,
    this.dy = 0,
    this.envoltura,
  });

  @override
  Widget build(BuildContext context) {
    final caja = elemento.cajaRotada;
    final centrado = Center(
      child: SizedBox(width: elemento.ancho, height: elemento.alto, child: child),
    );
    return Positioned(
      left: caja.left - dx,
      top: caja.top - dy,
      width: caja.width,
      height: caja.height,
      child: envoltura == null ? centrado : envoltura!(context, centrado),
    );
  }
}

/// Piso del salón: fondo cálido con una cuadrícula de puntos muy suave.
class PisoPainter extends CustomPainter {
  final double paso;

  const PisoPainter({this.paso = 28});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF6F1E9));
    final punto = Paint()..color = const Color(0xFFD9CFC0);
    for (var x = paso; x < size.width; x += paso) {
      for (var y = paso; y < size.height; y += paso) {
        canvas.drawCircle(Offset(x, y), 1.1, punto);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PisoPainter old) => old.paso != paso;
}

/// Contenedor del plano (visitante y administrador): piso, borde fino y esquinas suaves.
class PisoDelSalon extends StatelessWidget {
  final double? alto;
  final Widget child;

  const PisoDelSalon({super.key, this.alto, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: alto,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divisor),
      ),
      child: CustomPaint(painter: const PisoPainter(), child: child),
    );
  }
}
