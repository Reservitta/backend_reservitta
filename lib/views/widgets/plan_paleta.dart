import 'package:flutter/material.dart';

import '../../models/elemento_plano.dart';
import '../../models/mesa_model.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/plan_editor_viewmodel.dart';
import 'mesa_visual.dart';

/// Paleta del editor del plano: mesas de todas las formas y tamaños, y elementos de
/// decoración (barra, paredes, puertas, plantas, cocina…) que se agregan con un toque.
class PaletaPlano extends StatelessWidget {
  final PlanEditorViewModel vm;

  /// En pantallas angostas la paleta es una tira horizontal; en anchas, una columna.
  final bool horizontal;

  const PaletaPlano({super.key, required this.vm, this.horizontal = false});

  /// Llaves históricas de los tres botones básicos.
  static Key _llaveMesa(PresetMesa p) {
    switch (p.id) {
      case 'cuadrada_4':
        return const ValueKey('btn_agregar_mesa_cuadrada');
      case 'redonda_4':
        return const ValueKey('btn_agregar_mesa_redonda');
      case 'rectangular_6':
        return const ValueKey('btn_agregar_mesa_rectangular');
      default:
        return ValueKey('pal_mesa_${p.id}');
    }
  }

  Widget _fichaMesa(PresetMesa p) {
    final mesa = MesaModel(
      id: 'p_${p.id}',
      nombre: '',
      capacidad: p.capacidad,
      forma: p.forma,
      ancho: p.ancho,
      alto: p.alto,
      x: 0,
      y: 0,
    );
    return _Ficha(
      key: _llaveMesa(p),
      etiqueta: p.etiqueta,
      onTap: () => vm.agregarPreset(p),
      vista: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SizedBox(
            width: p.ancho,
            height: p.alto,
            child: MesaVisual(
              mesa: mesa,
              paleta: MesaPaleta.editor,
              mostrarTexto: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fichaElemento(String tipo) {
    final estilo = ElementoPlano.estilo(tipo);
    final e = ElementoPlano(
      id: 'p_$tipo',
      tipo: tipo,
      x: 0,
      y: 0,
      ancho: estilo.ancho,
      alto: estilo.alto,
      etiqueta: ElementoPlano.textoInicial(tipo),
    );
    return _Ficha(
      key: ValueKey('pal_elemento_$tipo'),
      etiqueta: estilo.nombre,
      onTap: () => vm.agregarElemento(tipo),
      vista: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            width: estilo.ancho,
            height: estilo.alto < 30 ? 30 : estilo.alto,
            child: ElementoVisual(elemento: e),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesas = [for (final p in PlanEditorViewModel.presetsMesa) _fichaMesa(p)];
    final decoracion = [for (final t in ElementoPlano.tiposValidos) _fichaElemento(t)];

    if (horizontal) {
      return Container(
        key: const ValueKey('paleta_plano'),
        height: 112,
        color: Colors.white,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            const _TituloLateral('Mesas'),
            ...mesas,
            const SizedBox(width: 8),
            const _TituloLateral('Decoración'),
            ...decoracion,
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('paleta_plano'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divisor),
      ),
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Titulo('Mesas'),
            const SizedBox(height: 4),
            const Text(
              'Toca una para agregarla al plano.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: mesas),
            const SizedBox(height: 20),
            const _Titulo('Decoración'),
            const SizedBox(height: 4),
            const Text(
              'Para que el plano se parezca a tu salón.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: decoracion),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontFamily: AppTheme.familiaTitulos,
        fontWeight: FontWeight.w700,
        fontVariations: [FontVariation('wght', 700)],
        fontSize: 18,
        color: AppColors.texto,
      ),
    );
  }
}

class _TituloLateral extends StatelessWidget {
  final String texto;

  const _TituloLateral(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, left: 4),
      child: RotatedBox(
        quarterTurns: 3,
        child: Center(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textoSuave,
            ),
          ),
        ),
      ),
    );
  }
}

/// Una pieza de la paleta: vista previa y nombre.
class _Ficha extends StatelessWidget {
  final String etiqueta;
  final Widget vista;
  final VoidCallback onTap;

  const _Ficha({super.key, required this.etiqueta, required this.vista, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Agregar: $etiqueta',
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 78,
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            decoration: BoxDecoration(
              color: AppColors.fondo,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divisor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 50, width: 66, child: vista),
                const SizedBox(height: 4),
                Text(
                  etiqueta,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, height: 1.15, color: AppColors.texto),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
