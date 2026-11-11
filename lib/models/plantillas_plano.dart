import 'elemento_plano.dart';

/// Una mesa de una plantilla: qué modelo de la paleta es y dónde va.
class MesaDePlantilla {
  /// Id del modelo de mesa de la paleta (por ejemplo `redonda_4`).
  final String preset;
  final double x;
  final double y;
  final double rotacion;

  const MesaDePlantilla(this.preset, this.x, this.y, {this.rotacion = 0});
}

/// Un elemento de decoración de una plantilla.
class ElementoDePlantilla {
  final String tipo;
  final double x;
  final double y;
  final double? ancho;
  final double? alto;
  final double rotacion;
  final String? texto;

  const ElementoDePlantilla(
    this.tipo,
    this.x,
    this.y, {
    this.ancho,
    this.alto,
    this.rotacion = 0,
    this.texto,
  });
}

/// Plano de arranque: mesas y decoración ya acomodadas que el administrador puede
/// ajustar después a su gusto.
class PlantillaPlano {
  final String id;
  final String nombre;
  final String descripcion;
  final List<MesaDePlantilla> mesas;
  final List<ElementoDePlantilla> elementos;

  const PlantillaPlano({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.mesas,
    this.elementos = const [],
  });

  static const cafeteria = PlantillaPlano(
    id: 'cafeteria',
    nombre: 'Cafetería pequeña',
    descripcion: 'Mesas para dos, barra con banquetas y entrada.',
    mesas: [
      MesaDePlantilla('cuadrada_2', 100, 220),
      MesaDePlantilla('cuadrada_2', 240, 220),
      MesaDePlantilla('cuadrada_2', 380, 220),
      MesaDePlantilla('cuadrada_2', 520, 220),
      MesaDePlantilla('redonda_2', 100, 380),
      MesaDePlantilla('redonda_2', 240, 380),
      MesaDePlantilla('redonda_2', 380, 380),
      MesaDePlantilla('redonda_2', 520, 380),
      MesaDePlantilla('banqueta', 760, 220),
      MesaDePlantilla('banqueta', 840, 220),
      MesaDePlantilla('banqueta', 920, 220),
      MesaDePlantilla('banqueta', 1000, 220),
    ],
    elementos: [
      ElementoDePlantilla('barra', 740, 120, ancho: 300, alto: 60, texto: 'Barra'),
      ElementoDePlantilla('pared', 40, 60, ancho: 1120, alto: 14),
      ElementoDePlantilla('puerta', 120, 620),
      ElementoDePlantilla('ventana', 400, 50, ancho: 200, alto: 12),
      ElementoDePlantilla('planta', 60, 500),
      ElementoDePlantilla('planta', 640, 500),
    ],
  );

  static const familiar = PlantillaPlano(
    id: 'familiar',
    nombre: 'Restaurante familiar',
    descripcion: 'Mesas de cuatro, mesas largas para grupos, cocina y entrada.',
    mesas: [
      MesaDePlantilla('cuadrada_4', 120, 180),
      MesaDePlantilla('cuadrada_4', 300, 180),
      MesaDePlantilla('cuadrada_4', 480, 180),
      MesaDePlantilla('cuadrada_4', 120, 380),
      MesaDePlantilla('cuadrada_4', 300, 380),
      MesaDePlantilla('cuadrada_4', 480, 380),
      MesaDePlantilla('rectangular_6', 680, 180),
      MesaDePlantilla('rectangular_6', 680, 380),
      MesaDePlantilla('redonda_8', 900, 480),
    ],
    elementos: [
      ElementoDePlantilla('pared', 60, 60, ancho: 1080, alto: 14),
      ElementoDePlantilla('cocina', 900, 100, ancho: 220, alto: 130, texto: 'Cocina'),
      ElementoDePlantilla('bano', 120, 600, ancho: 110, alto: 100, texto: 'Baños'),
      ElementoDePlantilla('puerta', 560, 700),
      ElementoDePlantilla('planta', 60, 300),
      ElementoDePlantilla('planta', 640, 600),
    ],
  );

  static const bar = PlantillaPlano(
    id: 'bar',
    nombre: 'Bar con barra',
    descripcion: 'Barra larga con banquetas, mesas altas, sillones y escenario.',
    mesas: [
      MesaDePlantilla('banqueta', 240, 200),
      MesaDePlantilla('banqueta', 330, 200),
      MesaDePlantilla('banqueta', 420, 200),
      MesaDePlantilla('banqueta', 510, 200),
      MesaDePlantilla('banqueta', 600, 200),
      MesaDePlantilla('banqueta', 690, 200),
      MesaDePlantilla('alta_2', 240, 400),
      MesaDePlantilla('alta_2', 380, 400),
      MesaDePlantilla('alta_2', 520, 400),
      MesaDePlantilla('alta_2', 660, 400),
      MesaDePlantilla('sillon_3', 240, 580),
      MesaDePlantilla('sillon_3', 480, 580),
    ],
    elementos: [
      ElementoDePlantilla('barra', 200, 100, ancho: 560, alto: 60, texto: 'Barra'),
      ElementoDePlantilla('escenario', 880, 120, ancho: 240, alto: 110, texto: 'Escenario'),
      ElementoDePlantilla('bano', 940, 560, ancho: 110, alto: 100, texto: 'Baños'),
      ElementoDePlantilla('puerta', 100, 700),
    ],
  );

  static const terraza = PlantillaPlano(
    id: 'terraza',
    nombre: 'Terraza',
    descripcion: 'Mesas redondas al aire libre con plantas.',
    mesas: [
      MesaDePlantilla('redonda_6', 150, 180),
      MesaDePlantilla('redonda_6', 380, 180),
      MesaDePlantilla('redonda_6', 610, 180),
      MesaDePlantilla('redonda_6', 840, 180),
      MesaDePlantilla('redonda_4', 160, 440),
      MesaDePlantilla('redonda_4', 380, 440),
      MesaDePlantilla('redonda_4', 600, 440),
      MesaDePlantilla('redonda_4', 820, 440),
    ],
    elementos: [
      ElementoDePlantilla('planta', 80, 90),
      ElementoDePlantilla('planta', 1060, 90),
      ElementoDePlantilla('planta', 80, 640),
      ElementoDePlantilla('planta', 1060, 640),
      ElementoDePlantilla('pared', 60, 700, ancho: 1080, alto: 14),
      ElementoDePlantilla('puerta', 540, 690),
    ],
  );

  static const eventos = PlantillaPlano(
    id: 'eventos',
    nombre: 'Salón de eventos',
    descripcion: 'Mesas redondas de ocho, escenario y barra.',
    mesas: [
      MesaDePlantilla('redonda_8', 130, 180),
      MesaDePlantilla('redonda_8', 400, 180),
      MesaDePlantilla('redonda_8', 670, 180),
      MesaDePlantilla('redonda_8', 130, 470),
      MesaDePlantilla('redonda_8', 400, 470),
      MesaDePlantilla('redonda_8', 670, 470),
    ],
    elementos: [
      ElementoDePlantilla('escenario', 920, 160, ancho: 220, alto: 110, texto: 'Escenario'),
      ElementoDePlantilla('barra', 920, 470, ancho: 220, alto: 60, texto: 'Barra'),
      ElementoDePlantilla('puerta', 560, 740),
      ElementoDePlantilla('pared', 60, 60, ancho: 1080, alto: 14),
    ],
  );

  static const List<PlantillaPlano> todas = [cafeteria, familiar, bar, terraza, eventos];

  /// Cuántas piezas tiene la plantilla (para mostrarlo en la lista).
  int get piezas => mesas.length + elementos.length;

  /// Tipo de elemento y medidas por defecto, para armar la decoración.
  static ({double ancho, double alto, String texto}) medidasDe(ElementoDePlantilla e) {
    final estilo = ElementoPlano.estilo(e.tipo);
    return (
      ancho: e.ancho ?? estilo.ancho,
      alto: e.alto ?? estilo.alto,
      texto: e.texto ?? ElementoPlano.textoInicial(e.tipo),
    );
  }
}
