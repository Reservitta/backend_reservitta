import 'package:flutter/material.dart';

import '../models/reservation_model.dart';
import '../viewmodels/admin_operations_viewmodel.dart';
import 'widgets/alert_settings_sheet.dart';
import 'widgets/arrival_alert_widgets.dart';
import '../theme/app_theme.dart';

/// Dashboard del administrador (HU25-RF02): métricas del día, alertas de llegada y
/// accesos directos. Se actualiza solo con los cambios de las reservas; el tirón hacia
/// abajo es un respaldo manual.
class DashboardView extends StatelessWidget {
  final AdminOperationsViewModel operaciones;
  final String restauranteNombre;
  final VoidCallback onIrAReservas;
  final VoidCallback onIrAMesas;
  final VoidCallback? onIrAPedidos;
  final void Function(ReservationModel reserva) onAbrirReserva;

  const DashboardView({
    super.key,
    required this.operaciones,
    required this.onIrAReservas,
    required this.onIrAMesas,
    required this.onAbrirReserva,
    this.onIrAPedidos,
    this.restauranteNombre = '',
  });

  static const Color _terracotta = AppColors.marca;
  static const Color _textDark = AppColors.texto;
  static const Color _textMuted = AppColors.textoSuave;
  static const Color _cardBorder = AppColors.divisor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: operaciones,
      builder: (context, _) {
        if (operaciones.cargando) {
          return const Center(
            child: CircularProgressIndicator(
              key: ValueKey('dashboard_cargando'),
              color: _terracotta,
            ),
          );
        }
        if (operaciones.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 44, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    operaciones.error!,
                    key: const ValueKey('dashboard_error'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('dashboard_reintentar'),
                    style: FilledButton.styleFrom(backgroundColor: _terracotta),
                    onPressed: operaciones.refrescar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          key: const ValueKey('dashboard_refresh'),
          color: _terracotta,
          onRefresh: operaciones.refrescar,
          child: ListView(
            key: const ValueKey('dashboard_contenido'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _encabezado(context),
                      const SizedBox(height: 20),
                      _metricas(),
                      const SizedBox(height: 24),
                      _alertas(),
                      const SizedBox(height: 24),
                      _accesos(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _encabezado(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontFamily: AppTheme.familiaTitulos,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                restauranteNombre.isEmpty
                    ? 'Resumen del día de hoy.'
                    : 'Resumen de hoy en $restauranteNombre.',
                style: const TextStyle(fontSize: 13.5, color: _textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('btn_ajustes_alertas'),
          tooltip: 'Alertas y recordatorios',
          icon: Icon(
            operaciones.config.alertasActivas
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: _textDark,
          ),
          onPressed: () => AlertSettingsSheet.mostrar(
            context,
            config: operaciones.config,
            onGuardar: operaciones.guardarConfig,
          ),
        ),
      ],
    );
  }

  Widget _metricas() {
    final m = operaciones.metricas;
    final tarjetas = <Widget>[
      _MetricCard(
        key: const ValueKey('metrica_reservas'),
        icono: Icons.event_available_outlined,
        etiqueta: 'Reservas de hoy',
        valor: '${m.totalReservas}',
      ),
      _MetricCard(
        key: const ValueKey('metrica_personas'),
        icono: Icons.groups_2_outlined,
        etiqueta: 'Personas esperadas',
        valor: '${m.personasEsperadas}',
      ),
      _MetricCard(
        key: const ValueKey('metrica_mesas'),
        icono: Icons.table_restaurant_outlined,
        etiqueta: 'Mesas ocupadas',
        valor: '${m.mesasOcupadas} / ${m.mesasActivas}',
      ),
      _MetricCard(
        key: const ValueKey('metrica_pedidos'),
        icono: Icons.receipt_long_outlined,
        etiqueta: 'Pedidos con preorden',
        valor: '${m.pedidosConPreorden}',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= 640 ? 4 : 2;
        const espacio = 12.0;
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
        );
      },
    );
  }

  Widget _alertas() {
    final alertas = operaciones.alertas;
    return Column(
      key: const ValueKey('dashboard_alertas'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próximas llegadas',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textDark),
        ),
        const SizedBox(height: 10),
        if (!operaciones.config.alertasActivas)
          const Text(
            'Las alertas de llegada están desactivadas.',
            key: ValueKey('alertas_desactivadas'),
            style: TextStyle(color: _textMuted),
          )
        else if (alertas.isEmpty)
          Text(
            'Nadie llega en los próximos ${operaciones.config.umbralAlertaMin} minutos.',
            key: const ValueKey('alertas_vacias'),
            style: const TextStyle(color: _textMuted),
          )
        else
          for (final a in alertas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ArrivalAlertTile(alerta: a, onTap: () => onAbrirReserva(a.reserva)),
            ),
      ],
    );
  }

  Widget _accesos() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Acceso(
          key: const ValueKey('acceso_reservas'),
          icono: Icons.calendar_today_outlined,
          texto: 'Reservas del día',
          onTap: onIrAReservas,
        ),
        _Acceso(
          key: const ValueKey('acceso_mesas'),
          icono: Icons.grid_4x4_outlined,
          texto: 'Estado de mesas',
          onTap: onIrAMesas,
        ),
        if (onIrAPedidos != null)
          _Acceso(
            key: const ValueKey('acceso_pedidos'),
            icono: Icons.receipt_long_outlined,
            texto: 'Pedidos',
            onTap: onIrAPedidos!,
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _MetricCard({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$etiqueta: $valor',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DashboardView._cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: DashboardView._terracotta, size: 22),
            const SizedBox(height: 10),
            Text(
              valor,
              key: const ValueKey('metrica_valor'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: DashboardView._textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              style: const TextStyle(fontSize: 12.5, color: DashboardView._textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Acceso extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  const _Acceso({super.key, required this.icono, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: DashboardView._textDark,
        side: const BorderSide(color: DashboardView._cardBorder),
        backgroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      onPressed: onTap,
      icon: Icon(icono, size: 20, color: DashboardView._terracotta),
      label: Text(texto),
    );
  }
}
