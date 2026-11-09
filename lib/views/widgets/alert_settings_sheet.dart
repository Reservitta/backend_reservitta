import 'package:flutter/material.dart';

import '../../models/operations_config.dart';

/// Ajustes de las alertas de llegada y del recordatorio (HU30-RF03, HU21-RF01): el
/// administrador elige con cuánta anticipación se avisa, o desactiva las alertas.
class AlertSettingsSheet extends StatefulWidget {
  final OperationsConfig config;

  /// Guarda los ajustes; devuelve un mensaje de error o null si se guardaron.
  final Future<String?> Function(OperationsConfig nueva) onGuardar;

  const AlertSettingsSheet({
    super.key,
    required this.config,
    required this.onGuardar,
  });

  /// Abre la hoja como diálogo inferior.
  static Future<void> mostrar(
    BuildContext context, {
    required OperationsConfig config,
    required Future<String?> Function(OperationsConfig nueva) onGuardar,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AlertSettingsSheet(config: config, onGuardar: onGuardar),
    );
  }

  @override
  State<AlertSettingsSheet> createState() => _AlertSettingsSheetState();
}

class _AlertSettingsSheetState extends State<AlertSettingsSheet> {
  static const List<int> _recordatorios = [60, 120, 180, 240];

  late bool _activas = widget.config.alertasActivas;
  late int _umbral = widget.config.umbralAlertaMin;
  late int _recordatorio = widget.config.recordatorioMin;
  bool _guardando = false;
  String? _error;

  List<int> get _umbrales {
    final lista = {...OperationsConfig.umbralesPermitidos, widget.config.umbralAlertaMin}
        .toList()
      ..sort();
    return lista;
  }

  List<int> get _opcionesRecordatorio {
    final lista = {..._recordatorios, widget.config.recordatorioMin}.toList()..sort();
    return lista;
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await widget.onGuardar(widget.config.copyWith(
      alertasActivas: _activas,
      umbralAlertaMin: _umbral,
      recordatorioMin: _recordatorio,
    ));
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        child: Column(
          key: const ValueKey('hoja_ajustes_alertas'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alertas y recordatorios',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('switch_alertas'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Alertas de llegada'),
              subtitle: const Text(
                'Avisa cuando una reserva está por llegar o se retrasa.',
              ),
              value: _activas,
              onChanged: (v) => setState(() => _activas = v),
            ),
            const SizedBox(height: 8),
            Text(
              'Avisar con anticipación',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _activas ? null : Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _umbrales)
                  ChoiceChip(
                    key: ValueKey('chip_umbral_$m'),
                    label: Text('$m min'),
                    selected: _umbral == m,
                    onSelected: _activas ? (_) => setState(() => _umbral = m) : null,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Recordatorio al cliente',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _opcionesRecordatorio)
                  ChoiceChip(
                    key: ValueKey('chip_recordatorio_$m'),
                    label: Text(OperationsConfig.textoAnticipacion(m)),
                    selected: _recordatorio == m,
                    onSelected: (_) => setState(() => _recordatorio = m),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const ValueKey('error_ajustes_alertas'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('btn_guardar_ajustes_alertas'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB34A26),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
