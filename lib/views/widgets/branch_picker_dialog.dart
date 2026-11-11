import 'package:flutter/material.dart';

import '../../models/branch_model.dart';
import '../../models/restaurant_model.dart';
import '../../services/restaurant_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/opening_status.dart';

/// Ventana que lista las sucursales del restaurante para elegir en cuál reservar.
/// Se abre al pulsar "Haz tu Reserva"; al continuar devuelve la sucursal elegida.
/// Sin sucursales registradas no deja continuar.
class BranchPickerDialog extends StatefulWidget {
  final RestaurantModel restaurant;
  final RestaurantService service;
  final DateTime Function() clock;

  const BranchPickerDialog({
    super.key,
    required this.restaurant,
    required this.service,
    this.clock = DateTime.now,
  });

  static Future<BranchModel?> show(
    BuildContext context, {
    required RestaurantModel restaurant,
    required RestaurantService service,
    DateTime Function()? clock,
  }) {
    return showDialog<BranchModel>(
      context: context,
      builder: (_) => BranchPickerDialog(
        restaurant: restaurant,
        service: service,
        clock: clock ?? DateTime.now,
      ),
    );
  }

  @override
  State<BranchPickerDialog> createState() => _BranchPickerDialogState();
}

class _BranchPickerDialogState extends State<BranchPickerDialog> {
  List<BranchModel> _sucursales = const [];
  bool _cargando = true;
  bool _fallo = false;
  BranchModel? _elegida;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await widget.service.getBranches(widget.restaurant.id);
      if (!mounted) return;
      setState(() {
        _sucursales = lista;
        _cargando = false;
        // Con una sola sucursal ya viene marcada.
        if (lista.length == 1) _elegida = lista.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _fallo = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = EstadoApertura.hoy(widget.restaurant, widget.clock());

    return Dialog(
      backgroundColor: AppColors.superficie,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Elige la sucursal',
                      style: TextStyle(
                        fontFamily: AppTheme.familiaTitulos,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                        fontSize: 24,
                        color: AppColors.texto,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Selecciona dónde quieres reservar en ${widget.restaurant.nombre}.',
                style: const TextStyle(fontSize: 14, color: AppColors.textoSuave),
              ),
              const SizedBox(height: 16),
              Flexible(child: _contenido(estado)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('btn_cancelar_sucursal'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('btn_continuar_sucursal'),
                    onPressed: _elegida == null
                        ? null
                        : () => Navigator.of(context).pop(_elegida),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido(EstadoApertura? estado) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(key: ValueKey('sucursales_cargando')),
        ),
      );
    }
    if (_fallo || _sucursales.isEmpty) {
      return Container(
        key: const ValueKey('sin_sucursales'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.fondo,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divisor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 34, color: AppColors.textoSuave),
            const SizedBox(height: 10),
            Text(
              _fallo
                  ? 'No pudimos cargar las sucursales'
                  : 'Este restaurante aún no tiene sucursales disponibles',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.texto,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fallo
                  ? 'Revisa tu conexión e inténtalo de nuevo.'
                  : 'Por ahora no se puede reservar aquí. Prueba con otro restaurante.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textoSuave),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _sucursales.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _tarjeta(_sucursales[i], estado),
    );
  }

  Widget _tarjeta(BranchModel b, EstadoApertura? estado) {
    final elegida = _elegida?.id == b.id;
    return InkWell(
      key: ValueKey('sucursal_${b.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _elegida = b),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: elegida ? AppColors.marcaSuave : AppColors.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: elegida ? AppColors.marca : AppColors.divisor,
            width: elegida ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: elegida ? AppColors.marca : AppColors.textoSuave,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.nombre.isNotEmpty ? b.nombre : widget.restaurant.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.texto,
                    ),
                  ),
                  if (b.direccion.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      b.direccion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textoSuave),
                    ),
                  ],
                ],
              ),
            ),
            if (estado != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: estado.fondo,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  estado.texto,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: estado.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
