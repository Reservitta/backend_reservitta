import 'package:flutter/material.dart';

import '../../models/ocasion_model.dart';
import '../../models/platillo_model.dart';
import '../../viewmodels/ocasion_selection_viewmodel.dart';

const Color _terracotta = Color(0xFFB34A26);
const Color _cardBorder = Color(0xFFEDE4D8);
const Color _textDark = Color(0xFF2E241E);
const Color _textMuted = Color(0xFF7A6E65);

String _dinero(double v) => '\$${v.toStringAsFixed(2)} MXN';

IconData iconoDeOcasion(String nombre) {
  switch (nombre) {
    case 'cake':
      return Icons.cake_outlined;
    case 'favorite':
      return Icons.favorite_outline;
    case 'diamond':
      return Icons.diamond_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'wine_bar':
      return Icons.wine_bar_outlined;
    default:
      return Icons.celebration_outlined;
  }
}

/// Paso "¿Celebras algo especial?": tipo de ocasión (HU18-RF02), experiencias
/// disponibles (HU18-RF03) y el postre con felicitación (HU18-RF04).
class OcasionStep extends StatelessWidget {
  final OcasionSelectionViewModel vm;

  /// Se llama al pulsar el botón principal ("Continuar" o "No celebro nada especial...").
  final VoidCallback onContinuar;

  const OcasionStep({super.key, required this.vm, required this.onContinuar});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        return ListView(
          key: const ValueKey('paso_ocasion'),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '¿Celebras algo especial?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elige una ocasión y suma experiencias para tu visita.',
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
            const SizedBox(height: 14),
            _cuadricula(),
            if (vm.esOtro) ...[
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('campo_otro_detalle'),
                initialValue: vm.detalleOtro,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Cuéntanos qué celebras',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: vm.setDetalleOtro,
              ),
            ],
            if (vm.hayOcasion) ...[
              const SizedBox(height: 16),
              _experiencias(context),
            ],
            const SizedBox(height: 20),
            if (vm.informacionPendiente)
              Container(
                key: const ValueKey('aviso_info_pendiente'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF7A5A00),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        OcasionSelectionViewModel.avisoInformacionPendiente,
                        style: TextStyle(fontSize: 13, color: _textDark),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const ValueKey('btn_continuar_ocasion'),
                style: FilledButton.styleFrom(
                  backgroundColor: _terracotta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: vm.puedeContinuar ? onContinuar : null,
                child: Text(
                  vm.textoContinuar,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HU18-RF02
  // ---------------------------------------------------------------------------
  Widget _cuadricula() {
    return Wrap(
      key: const ValueKey('cuadricula_ocasiones'),
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final o in vm.ocasiones)
          _TarjetaOcasion(
            ocasion: o,
            seleccionada: vm.esSeleccionada(o),
            onTap: () => vm.seleccionarOcasion(o),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HU18-RF03
  // ---------------------------------------------------------------------------
  Widget _experiencias(BuildContext context) {
    final lista = vm.experienciasDeOcasion;
    return Container(
      key: const ValueKey('seccion_experiencias'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Experiencias disponibles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          if (lista.isEmpty)
            const Text(
              'Esta ocasión no tiene experiencias disponibles.',
              key: ValueKey('sin_experiencias'),
              style: TextStyle(color: _textMuted),
            ),
          for (final e in lista) ...[
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                key: ValueKey('check_exp_${e.id}'),
                contentPadding: EdgeInsets.zero,
                activeColor: _terracotta,
                controlAffinity: ListTileControlAffinity.leading,
                value: vm.experienciaMarcada(e),
                onChanged: (_) => vm.toggleExperiencia(e),
                title: Text(
                  e.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: e.descripcionCorta.isEmpty
                    ? null
                    : Text(e.descripcionCorta),
                secondary: Text(
                  e.esGratis ? 'Gratis' : _dinero(e.precio),
                  key: ValueKey('precio_exp_${e.id}'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: e.esGratis ? const Color(0xFF2E7D32) : _terracotta,
                  ),
                ),
              ),
            ),
            if (e.requiereInformacion && vm.experienciaMarcada(e))
              _configurarFelicitaciones(context),
          ],
          if (vm.totalExperiencias > 0) ...[
            const Divider(height: 20),
            Text(
              'Experiencias con costo: ${_dinero(vm.totalExperiencias)}',
              key: const ValueKey('total_experiencias'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _terracotta,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HU18-RF04
  // ---------------------------------------------------------------------------
  Widget _configurarFelicitaciones(BuildContext context) {
    final guardadas = vm.felicitacionesGuardadas;
    return Container(
      key: const ValueKey('configurar_felicitaciones'),
      margin: const EdgeInsets.only(left: 12, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              guardadas == 0
                  ? 'Elige el postre y escribe tu mensaje (el mensaje no tiene costo).'
                  : '$guardadas ${guardadas == 1 ? 'felicitación guardada' : 'felicitaciones guardadas'}',
              key: const ValueKey('estado_felicitaciones'),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const ValueKey('btn_configurar_felicitaciones'),
            onPressed: () => PostreFelicitacionSheet.mostrar(context, vm),
            child: Text(guardadas == 0 ? 'Elegir postres' : 'Editar'),
          ),
        ],
      ),
    );
  }
}

class _TarjetaOcasion extends StatelessWidget {
  final OcasionModel ocasion;
  final bool seleccionada;
  final VoidCallback onTap;

  const _TarjetaOcasion({
    required this.ocasion,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionada,
      label: ocasion.nombre,
      child: InkWell(
        key: ValueKey('card_ocasion_${ocasion.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: seleccionada ? const Color(0xFFFFF3E8) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seleccionada ? _terracotta : _cardBorder,
              width: seleccionada ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    iconoDeOcasion(ocasion.icono),
                    color: _terracotta,
                    size: 26,
                  ),
                  const Spacer(),
                  if (seleccionada)
                    const Icon(
                      Icons.check_circle,
                      color: _terracotta,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ocasion.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              if (ocasion.descripcion.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  ocasion.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja para elegir los postres a felicitar y escribir el mensaje de cada uno
/// (HU18-RF04).
class PostreFelicitacionSheet extends StatefulWidget {
  final OcasionSelectionViewModel vm;

  const PostreFelicitacionSheet({super.key, required this.vm});

  static Future<void> mostrar(
    BuildContext context,
    OcasionSelectionViewModel vm,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PostreFelicitacionSheet(vm: vm),
    );
  }

  @override
  State<PostreFelicitacionSheet> createState() =>
      _PostreFelicitacionSheetState();
}

class _PostreFelicitacionSheetState extends State<PostreFelicitacionSheet> {
  final Map<String, TextEditingController> _controladores = {};
  bool _mostrarOtros = false;

  OcasionSelectionViewModel get vm => widget.vm;

  TextEditingController _controlador(String id) {
    return _controladores.putIfAbsent(
      id,
      () => TextEditingController(text: vm.mensajeDe(id)),
    );
  }

  @override
  void dispose() {
    for (final c in _controladores.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedBuilder(
        animation: vm,
        builder: (context, _) {
          final elegidos = vm.postresFelicitados;
          return SingleChildScrollView(
            key: const ValueKey('sheet_felicitaciones'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Postre con felicitación',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'El mensaje en el postre no tiene costo; el postre sí.',
                  style: TextStyle(fontSize: 13, color: _textMuted),
                ),
                const SizedBox(height: 14),
                if (elegidos.isEmpty) _selector(primero: true),
                for (final id in elegidos) _campoMensaje(id),
                if (elegidos.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    key: const ValueKey('btn_agregar_otro_postre'),
                    onPressed: () =>
                        setState(() => _mostrarOtros = !_mostrarOtros),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Agregar otro postre con felicitación'),
                  ),
                  if (_mostrarOtros) _selector(primero: false),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('btn_guardar_felicitaciones'),
                    style: FilledButton.styleFrom(backgroundColor: _terracotta),
                    onPressed: vm.puedeGuardarFelicitaciones
                        ? () {
                            if (vm.guardarFelicitaciones())
                              Navigator.of(context).pop();
                          }
                        : null,
                    child: Text(vm.textoGuardarFelicitaciones),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Si ya hay postres en el pedido se ofrecen primero; si no, todo el catálogo.
  Widget _selector({required bool primero}) {
    final delPedido = [
      for (final i in vm.postresEnPedido)
        if (!vm.postresFelicitados.contains(i.platilloId)) i,
    ];
    final catalogo = vm.postresParaAgregar
        .where((p) => !delPedido.any((i) => i.platilloId == p.id))
        .toList();
    final mostrarPedidoPrimero = vm.tienePostresEnPedido;

    return Column(
      key: ValueKey(primero ? 'selector_postres' : 'selector_otros_postres'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostrarPedidoPrimero && delPedido.isNotEmpty) ...[
          const Text(
            'Postres en tu pedido',
            key: ValueKey('titulo_postres_pedido'),
            style: TextStyle(fontWeight: FontWeight.bold, color: _textDark),
          ),
          for (final item in delPedido)
            ListTile(
              key: ValueKey('postre_pedido_${item.platilloId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(item.nombre),
              subtitle: Text('${item.cantidad}× · ${_dinero(item.precio)}'),
              trailing: OutlinedButton(
                onPressed: () => vm.elegirPostreDelPedido(item),
                child: const Text('Felicitar'),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (!mostrarPedidoPrimero || primero == false || delPedido.isEmpty) ...[
          Text(
            mostrarPedidoPrimero
                ? 'Otros postres del menú'
                : '¿En qué postre deseas la felicitación?',
            key: const ValueKey('titulo_catalogo_postres'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          if (catalogo.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No hay más postres disponibles.',
                key: ValueKey('sin_postres'),
                style: TextStyle(color: _textMuted),
              ),
            ),
          for (final p in catalogo) _filaCatalogo(p),
        ],
      ],
    );
  }

  Widget _filaCatalogo(PlatilloModel p) {
    return ListTile(
      key: ValueKey('postre_catalogo_${p.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(p.nombre),
      subtitle: Text(_dinero(p.precio)),
      trailing: OutlinedButton(
        onPressed: () => vm.elegirPostre(p),
        child: const Text('Elegir'),
      ),
    );
  }

  Widget _campoMensaje(String id) {
    final agregado = vm.pedido.obtenerItem(id);
    return Container(
      key: ValueKey('felicitacion_$id'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vm.nombreDePostre(id),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (agregado != null)
                Text(
                  _dinero(agregado.precio),
                  style: const TextStyle(fontSize: 12, color: _textMuted),
                ),
              IconButton(
                key: ValueKey('quitar_postre_$id'),
                tooltip: 'Quitar',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _controladores.remove(id)?.dispose();
                  vm.quitarPostre(id);
                },
              ),
            ],
          ),
          TextField(
            key: ValueKey('mensaje_$id'),
            controller: _controlador(id),
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Mensaje de felicitación',
              border: OutlineInputBorder(),
            ),
            onChanged: (t) => vm.setMensaje(id, t),
          ),
        ],
      ),
    );
  }
}
