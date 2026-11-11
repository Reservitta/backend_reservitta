import 'package:flutter/material.dart';

import '../../models/elemento_plano.dart';
import '../../models/mesa_model.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/plan_editor_viewmodel.dart';

const _tiposMesa = [
  (MesaModel.tipoRegular, 'Regular', Icons.table_restaurant_outlined),
  (MesaModel.tipoBarra, 'Barra', Icons.local_bar_outlined),
  (MesaModel.tipoAlta, 'Alta', Icons.height),
  (MesaModel.tipoSillon, 'Sillón', Icons.weekend_outlined),
];

/// Control para girar con botones de 90° y un deslizador de 15 en 15 grados.
class ControlRotacion extends StatelessWidget {
  final double grados;
  final ValueChanged<double> onFijar;
  final ValueChanged<double> onGirar;
  final String sufijoLlave;

  const ControlRotacion({
    super.key,
    required this.grados,
    required this.onFijar,
    required this.onGirar,
    this.sufijoLlave = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Giro', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(
              '${grados.round()}°',
              key: ValueKey('texto_rotacion$sufijoLlave'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            IconButton(
              key: ValueKey('btn_girar_90_izq$sufijoLlave'),
              tooltip: 'Girar 90° a la izquierda',
              visualDensity: VisualDensity.compact,
              onPressed: () => onGirar(-90),
              icon: const Icon(Icons.rotate_90_degrees_ccw),
            ),
            IconButton(
              key: ValueKey('btn_girar_90_der$sufijoLlave'),
              tooltip: 'Girar 90° a la derecha',
              visualDensity: VisualDensity.compact,
              onPressed: () => onGirar(90),
              icon: const Icon(Icons.rotate_90_degrees_cw),
            ),
          ],
        ),
        Slider(
          key: ValueKey('slider_rotacion$sufijoLlave'),
          min: 0,
          max: 345,
          divisions: 23,
          value: ((grados / 15).round() * 15).clamp(0, 345).toDouble(),
          label: '${grados.round()}°',
          onChanged: onFijar,
        ),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  final String titulo;
  final String valor;
  final String llave;
  final VoidCallback? onMenos;
  final VoidCallback? onMas;

  const _Paso({
    required this.titulo,
    required this.valor,
    required this.llave,
    required this.onMenos,
    required this.onMas,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 12.5, color: AppColors.textoSuave)),
        Row(
          children: [
            IconButton.outlined(
              key: ValueKey('btn_${llave}_menos'),
              tooltip: 'Menos',
              visualDensity: VisualDensity.compact,
              onPressed: onMenos,
              icon: const Icon(Icons.remove, size: 18),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                valor,
                key: ValueKey('texto_$llave'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton.outlined(
              key: ValueKey('btn_${llave}_mas'),
              tooltip: 'Más',
              visualDensity: VisualDensity.compact,
              onPressed: onMas,
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tipo de mesa, grupo que acepta y giro (se agrega al panel de la mesa).
class ControlesAvanzadosMesa extends StatelessWidget {
  final PlanEditorViewModel vm;
  final MesaModel mesa;
  final Map<String, String> errores;

  const ControlesAvanzadosMesa({
    super.key,
    required this.vm,
    required this.mesa,
    this.errores = const {},
  });

  @override
  Widget build(BuildContext context) {
    final max = mesa.maxEfectivo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text('Tipo de mesa', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in _tiposMesa)
              ChoiceChip(
                key: ValueKey('chip_tipo_${t.$1}'),
                avatar: Icon(t.$3, size: 16),
                label: Text(t.$2),
                selected: mesa.tipo == t.$1,
                onSelected: (_) => vm.cambiarTipo(mesa.id, t.$1),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Grupo que acepta', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        const Text(
          'La mesa solo se ofrece a grupos dentro de este rango.',
          style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _Paso(
              titulo: 'Mínimo',
              valor: '${mesa.minPersonas}',
              llave: 'min',
              onMenos: mesa.minPersonas > 1 ? () => vm.cambiarMinimo(mesa.id, mesa.minPersonas - 1) : null,
              onMas: mesa.minPersonas < mesa.capacidad
                  ? () => vm.cambiarMinimo(mesa.id, mesa.minPersonas + 1)
                  : null,
            ),
            _Paso(
              titulo: 'Máximo',
              valor: '$max',
              llave: 'max',
              onMenos: max > mesa.minPersonas ? () => vm.cambiarMaximo(mesa.id, max - 1) : null,
              onMas: max < mesa.capacidad ? () => vm.cambiarMaximo(mesa.id, max + 1) : null,
            ),
          ],
        ),
        for (final campo in const ['minPersonas', 'maxPersonas'])
          if (errores[campo] != null)
            Text(errores[campo]!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        const SizedBox(height: 14),
        ControlRotacion(
          grados: mesa.rotacion,
          onFijar: (g) => vm.fijarRotacionMesa(mesa.id, g),
          onGirar: (d) => vm.rotarMesa(mesa.id, d),
        ),
      ],
    );
  }
}

/// Contenedor común de los paneles laterales del editor.
class _MarcoPanel extends StatelessWidget {
  final Key llave;
  final Widget child;

  const _MarcoPanel({required this.llave, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: llave,
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divisor),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// Panel del elemento decorativo seleccionado.
class PanelElementoPlano extends StatefulWidget {
  final PlanEditorViewModel vm;
  final Future<void> Function(ElementoPlano elemento) onEliminar;

  const PanelElementoPlano({super.key, required this.vm, required this.onEliminar});

  @override
  State<PanelElementoPlano> createState() => _PanelElementoPlanoState();
}

class _PanelElementoPlanoState extends State<PanelElementoPlano> {
  final _texto = TextEditingController();
  String? _idTexto;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _sincronizar(ElementoPlano e) {
    if (e.id != _idTexto) {
      _idTexto = e.id;
      _texto.text = e.etiqueta;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final e = vm.elementoSeleccionado;
    if (e == null) return const SizedBox.shrink();
    _sincronizar(e);
    final estilo = ElementoPlano.estilo(e.tipo);

    return _MarcoPanel(
      llave: const ValueKey('panel_elemento'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(estilo.icono, color: AppColors.marca),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  estilo.nombre,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                key: const ValueKey('btn_cerrar_panel_elemento'),
                tooltip: 'Cerrar',
                onPressed: vm.limpiarSeleccion,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (estilo.llevaTexto) ...[
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('campo_elemento_texto'),
              controller: _texto,
              maxLength: ElementoPlano.textoMax,
              onChanged: (v) => vm.cambiarTextoElemento(e.id, v),
              decoration: const InputDecoration(labelText: 'Texto', counterText: ''),
            ),
          ],
          const SizedBox(height: 10),
          Text(e.esCircular ? 'Tamaño: ${e.ancho.round()}' : 'Ancho: ${e.ancho.round()}'),
          Slider(
            key: const ValueKey('slider_elemento_ancho'),
            min: ElementoPlano.tamanoMinimo,
            max: 1200,
            value: e.ancho.clamp(ElementoPlano.tamanoMinimo, 1200).toDouble(),
            onChanged: (v) => vm.cambiarTamanoElemento(e.id, ancho: v),
          ),
          if (!e.esCircular) ...[
            Text('Alto: ${e.alto.round()}'),
            Slider(
              key: const ValueKey('slider_elemento_alto'),
              min: ElementoPlano.tamanoMinimo,
              max: 300,
              value: e.alto.clamp(ElementoPlano.tamanoMinimo, 300).toDouble(),
              onChanged: (v) => vm.cambiarTamanoElemento(e.id, alto: v),
            ),
          ],
          ControlRotacion(
            sufijoLlave: '_elemento',
            grados: e.rotacion,
            onFijar: (g) => vm.fijarRotacionElemento(e.id, g),
            onGirar: (d) => vm.rotarElemento(e.id, d),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('btn_duplicar_elemento'),
                  onPressed: () => vm.duplicarElemento(e.id),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Duplicar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('btn_eliminar_elemento'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: () => widget.onEliminar(e),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Panel cuando hay varias piezas seleccionadas: alinear, distribuir, girar y borrar.
class PanelSeleccionPlano extends StatelessWidget {
  final PlanEditorViewModel vm;
  final Future<void> Function(int cantidad) onEliminar;

  const PanelSeleccionPlano({super.key, required this.vm, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final n = vm.cantidadSeleccionada;
    Widget alinear(Alineacion a, IconData icono, String texto) => IconButton.outlined(
          key: ValueKey('btn_alinear_${a.name}'),
          tooltip: texto,
          onPressed: n >= 2 ? () => vm.alinear(a) : null,
          icon: Icon(icono, size: 20),
        );

    return _MarcoPanel(
      llave: const ValueKey('panel_seleccion'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  n == 0
                      ? 'Selección múltiple'
                      : '$n ${n == 1 ? 'pieza seleccionada' : 'piezas seleccionadas'}',
                  key: const ValueKey('texto_cantidad_seleccion'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                key: const ValueKey('btn_seleccionar_todo'),
                onPressed: vm.seleccionarTodo,
                child: const Text('Todo'),
              ),
            ],
          ),
          if (n == 0)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Toca las mesas y los elementos que quieras juntar. Después podrás moverlos, alinearlos o borrarlos a la vez.',
                key: ValueKey('texto_ayuda_multiple'),
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textoSuave),
              ),
            ),
          if (n >= 1) ...[
            const SizedBox(height: 14),
            const Text('Alinear', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                alinear(Alineacion.izquierda, Icons.align_horizontal_left, 'A la izquierda'),
                alinear(Alineacion.centroHorizontal, Icons.align_horizontal_center, 'Centrar horizontalmente'),
                alinear(Alineacion.derecha, Icons.align_horizontal_right, 'A la derecha'),
                alinear(Alineacion.arriba, Icons.align_vertical_top, 'Arriba'),
                alinear(Alineacion.centroVertical, Icons.align_vertical_center, 'Centrar verticalmente'),
                alinear(Alineacion.abajo, Icons.align_vertical_bottom, 'Abajo'),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Repartir con el mismo espacio', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn_distribuir_horizontal'),
                    onPressed: n >= 3 ? () => vm.distribuir(horizontal: true) : null,
                    icon: const Icon(Icons.align_horizontal_center, size: 18),
                    label: const Text('Horizontal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn_distribuir_vertical'),
                    onPressed: n >= 3 ? () => vm.distribuir(horizontal: false) : null,
                    icon: const Icon(Icons.align_vertical_center, size: 18),
                    label: const Text('Vertical'),
                  ),
                ),
              ],
            ),
            if (n < 3)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Para repartir hacen falta al menos 3 piezas.',
                  style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Text('Girar todo', style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  key: const ValueKey('btn_girar_seleccion_izq'),
                  tooltip: 'Girar 90° a la izquierda',
                  onPressed: () => vm.girarSeleccion(-90),
                  icon: const Icon(Icons.rotate_90_degrees_ccw),
                ),
                IconButton(
                  key: const ValueKey('btn_girar_seleccion_der'),
                  tooltip: 'Girar 90° a la derecha',
                  onPressed: () => vm.girarSeleccion(90),
                  icon: const Icon(Icons.rotate_90_degrees_cw),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn_duplicar_seleccion'),
                    onPressed: vm.duplicarSeleccion,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Duplicar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn_eliminar_seleccion'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: () => onEliminar(n),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
