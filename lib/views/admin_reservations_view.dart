import 'package:flutter/material.dart';
import '../models/reservation_model.dart';
import '../repositories/reservation_repository.dart';
import '../services/categoria_service.dart';
import '../viewmodels/admin_operations_viewmodel.dart';
import '../viewmodels/admin_reservations_viewmodel.dart';
import 'reservation_detail_view.dart';
import 'widgets/alert_settings_sheet.dart';
import 'widgets/arrival_alert_widgets.dart';
import 'widgets/reservation_state_control.dart';

/// Pantalla de listado de reservas para administradores de restaurante (HU26-RF02)
///
/// Criterios de aceptación:
/// 1. Lista o tabla con hora, cliente, personas, mesa y estado, ordenada cronológicamente.
/// 2. Se puede seleccionar una fecha distinta a la de hoy mediante un selector de fecha.
/// 3. Al tocar una reserva se abre su detalle completo (HU28-RF02) y se puede cambiar su estado (HU27-RF02).
/// 4. Se muestra un estado vacío ("No hay reservas para este día") y manejo de errores con "Reintentar".
/// 5. La lista se actualiza en tiempo real si llega una nueva reserva o cambia su estado.
class AdminReservationsView extends StatefulWidget {
  final String restaurantId;
  final ReservationRepository? reservationRepository;
  final AdminReservationsViewModel? viewModel;
  final bool showAppBar;
  final void Function(ReservationModel reservation)? onReservationTap;

  /// Nombres de categoría por id (para el detalle); por defecto se leen del restaurante.
  final Future<Map<String, String>> Function()? cargarCategorias;

  /// Estado operativo del día: con él el listado destaca las reservas por llegar
  /// (HU30-RF03) y permite ajustar las alertas.
  final AdminOperationsViewModel? operaciones;

  const AdminReservationsView({
    super.key,
    required this.restaurantId,
    this.reservationRepository,
    this.viewModel,
    this.showAppBar = true,
    this.onReservationTap,
    this.cargarCategorias,
    this.operaciones,
  });

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamAccent = Color(0xFFF3ECE1);
  static const Color _creamLight = Color(0xFFFAF5ED);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);

  @override
  State<AdminReservationsView> createState() => _AdminReservationsViewState();
}

class _AdminReservationsViewState extends State<AdminReservationsView> {
  late final AdminReservationsViewModel _viewModel;

  static const List<String> _mesesCortos = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static const List<String> _diasSemana = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ??
        AdminReservationsViewModel(
          restaurantId: widget.restaurantId,
          reservationRepository: widget.reservationRepository,
        );
    _viewModel.iniciarEscuchaEnTiempoReal();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  String _formatearFechaLegible(DateTime fecha) {
    final diaSemana = _diasSemana[(fecha.weekday - 1).clamp(0, 6)];
    final mes = _mesesCortos[(fecha.month - 1).clamp(0, 11)];
    final dia = fecha.day.toString().padLeft(2, '0');
    return '$diaSemana, $dia $mes ${fecha.year}';
  }

  Future<void> _abrirSelectorDeFecha() async {
    final hoy = DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _viewModel.fechaSeleccionada,
      firstDate: DateTime(hoy.year - 2, 1, 1),
      lastDate: DateTime(hoy.year + 2, 12, 31),
      helpText: 'Seleccionar fecha de reservas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (seleccionada != null && mounted) {
      _viewModel.seleccionarFecha(seleccionada);
    }
  }

  /// Nombres de categoría por id para agrupar los platillos del detalle (HU28-RF02).
  Future<Map<String, String>> _cargarCategorias() async {
    final cargar = widget.cargarCategorias;
    if (cargar != null) return cargar();
    final categorias =
        await CategoriaService().getCategoriasStream(widget.restaurantId).first;
    return {
      for (final c in categorias)
        c.id: c.tipo != 'general' && c.tipo.isNotEmpty ? c.tipo : c.nombre,
    };
  }

  /// Al tocar una reserva abre su detalle completo (HU28-RF02).
  void _alTocarReserva(ReservationModel reserva) {
    if (widget.onReservationTap != null) {
      widget.onReservationTap!(reserva);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReservationDetailView(
          reservationId: reserva.id,
          repository: _viewModel.repositorio,
          onChangeState: (nuevo) => _viewModel.cambiarEstado(reserva.id, nuevo),
          onChangeOrderState: (nuevo, {motivo}) =>
              _viewModel.cambiarEstadoPedido(reserva.id, nuevo, motivo: motivo),
          cargarCategorias: _cargarCategorias,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final operaciones = widget.operaciones;
    return ListenableBuilder(
      listenable: operaciones == null
          ? _viewModel
          : Listenable.merge([_viewModel, operaciones]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AdminReservationsView._lightBg,
          appBar: widget.showAppBar
              ? AppBar(
                  backgroundColor: Colors.white,
                  foregroundColor: AdminReservationsView._textDark,
                  elevation: 0,
                  title: const Text(
                    'Reservas del Restaurante',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AdminReservationsView._textDark,
                    ),
                  ),
                )
              : null,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEncabezadoYSelectorFecha(),
                    if (operaciones != null) ...[
                      const SizedBox(height: 12),
                      _buildAlertasDeLlegada(operaciones),
                    ],
                    const SizedBox(height: 16),
                    _buildBarraFiltrosEstado(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildContenidoPrincipal(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEncabezadoYSelectorFecha() {
    final fechaLegible = _formatearFechaLegible(_viewModel.fechaSeleccionada);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Reservas',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AdminReservationsView._textDark,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AdminReservationsView._creamAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        size: 13,
                        color: AdminReservationsView._primaryTerracotta,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tiempo real',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AdminReservationsView._primaryTerracotta,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Consulta y monitorea las reservaciones programadas ordenadas por hora de inicio.',
              style: TextStyle(
                fontSize: 13.5,
                color: AdminReservationsView._textMuted,
              ),
            ),
          ],
        ),

        // Criterio 2: Selector de fecha con controles de navegación por día
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_viewModel.esHoy) ...[
              TextButton.icon(
                key: const ValueKey('boton_ir_a_hoy_reservas'),
                onPressed: _viewModel.irAHoy,
                icon: const Icon(Icons.today_rounded, size: 16),
                label: const Text('Hoy'),
                style: TextButton.styleFrom(
                  foregroundColor: AdminReservationsView._primaryTerracotta,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminReservationsView._cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('boton_dia_anterior_reservas'),
                    tooltip: 'Día anterior',
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    color: AdminReservationsView._textDark,
                    onPressed: () => _viewModel.cambiarDia(-1),
                  ),
                  InkWell(
                    key: const ValueKey('boton_selector_fecha_reservas'),
                    onTap: _abrirSelectorDeFecha,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: AdminReservationsView._primaryTerracotta,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fechaLegible,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AdminReservationsView._textDark,
                            ),
                          ),
                          if (_viewModel.esHoy) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AdminReservationsView._primaryTerracotta
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Hoy',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      AdminReservationsView._primaryTerracotta,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('boton_dia_siguiente_reservas'),
                    tooltip: 'Día siguiente',
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    color: AdminReservationsView._textDark,
                    onPressed: () => _viewModel.cambiarDia(1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Barra de filtros por estado (HU26-RF01 Criterio 3)
  Widget _buildBarraFiltrosEstado() {
    final filtros = <({String? valor, String etiqueta, String keyId})>[
      (
        valor: null,
        etiqueta: 'Todas (${_viewModel.contarPorEstado(null)})',
        keyId: 'filtro_estado_todos',
      ),
      (
        valor: ReservationModel.estadoPendienteLlegada,
        etiqueta:
            'Pendiente de llegada (${_viewModel.contarPorEstado(ReservationModel.estadoPendienteLlegada)})',
        keyId: 'filtro_estado_pendiente_llegada',
      ),
      (
        valor: ReservationModel.estadoClienteLlego,
        etiqueta:
            'Cliente llegó (${_viewModel.contarPorEstado(ReservationModel.estadoClienteLlego)})',
        keyId: 'filtro_estado_cliente_llego',
      ),
      (
        valor: ReservationModel.estadoEnServicio,
        etiqueta:
            'En servicio (${_viewModel.contarPorEstado(ReservationModel.estadoEnServicio)})',
        keyId: 'filtro_estado_en_servicio',
      ),
      (
        valor: ReservationModel.estadoFinalizada,
        etiqueta:
            'Finalizada (${_viewModel.contarPorEstado(ReservationModel.estadoFinalizada)})',
        keyId: 'filtro_estado_finalizada',
      ),
      (
        valor: ReservationModel.estadoCancelada,
        etiqueta:
            'Cancelada (${_viewModel.contarPorEstado(ReservationModel.estadoCancelada)})',
        keyId: 'filtro_estado_cancelada',
      ),
      (
        valor: ReservationModel.estadoNoShow,
        etiqueta:
            'No se presentó (${_viewModel.contarPorEstado(ReservationModel.estadoNoShow)})',
        keyId: 'filtro_estado_no_show',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filtros.map((f) {
          final bool seleccionado = _viewModel.estadoFiltro == f.valor;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey(f.keyId),
              label: Text(f.etiqueta),
              selected: seleccionado,
              selectedColor: AdminReservationsView._primaryTerracotta,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: seleccionado
                    ? AdminReservationsView._primaryTerracotta
                    : AdminReservationsView._cardBorder,
              ),
              labelStyle: TextStyle(
                color: seleccionado
                    ? Colors.white
                    : AdminReservationsView._textDark,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12.5,
              ),
              onSelected: (_) => _viewModel.seleccionarFiltroEstado(f.valor),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContenidoPrincipal() {
    if (_viewModel.isLoading) {
      return const Center(
        key: ValueKey('indicador_carga_reservas'),
        child: CircularProgressIndicator(
          color: AdminReservationsView._primaryTerracotta,
        ),
      );
    }

    // Criterio 4: Manejo de errores con botón "Reintentar"
    if (_viewModel.hasError) {
      return Center(
        key: const ValueKey('vista_error_reservas'),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 14),
              const Text(
                'Error al cargar las reservas',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AdminReservationsView._textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _viewModel.errorMessage ?? 'Ocurrió un problema inesperado.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AdminReservationsView._textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('boton_reintentar_reservas'),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminReservationsView._primaryTerracotta,
                ),
                onPressed: _viewModel.reintentar,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final reservas = _viewModel.reservas;

    // Criterio 4: Estado vacío ("No hay reservas para este día")
    if (reservas.isEmpty) {
      return Center(
        key: const ValueKey('vista_vacia_reservas'),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 42),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AdminReservationsView._cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AdminReservationsView._creamLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_outlined,
                  size: 42,
                  color: AdminReservationsView._primaryTerracotta,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No hay reservas para este día',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AdminReservationsView._textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _viewModel.estadoFiltro != null
                    ? 'No se encontraron reservas con el filtro seleccionado para esta fecha.'
                    : 'Cuando los clientes realicen una reservación para esta fecha aparecerá aquí automáticamente.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminReservationsView._textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              if (_viewModel.estadoFiltro != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const ValueKey('boton_limpiar_filtro_estado'),
                  onPressed: () => _viewModel.seleccionarFiltroEstado(null),
                  child: const Text('Ver todas las reservas del día'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Criterio 1: Lista o tabla con hora, cliente, personas, mesa y estado, ordenada cronológicamente
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminReservationsView._cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEncabezadoTabla(),
          const Divider(height: 1, color: AdminReservationsView._cardBorder),
          Expanded(
            child: ListView.separated(
              key: const ValueKey('lista_reservas_restaurante'),
              itemCount: reservas.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                color: AdminReservationsView._cardBorder,
              ),
              itemBuilder: (context, index) {
                final reserva = reservas[index];
                return _buildFilaReserva(reserva);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncabezadoTabla() {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AdminReservationsView._textMuted,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: AdminReservationsView._creamLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 96, child: Text('HORA', style: headerStyle)),
          Expanded(flex: 3, child: Text('CLIENTE', style: headerStyle)),
          Expanded(flex: 2, child: Text('PERSONAS', style: headerStyle)),
          Expanded(flex: 2, child: Text('MESA', style: headerStyle)),
          SizedBox(width: 155, child: Text('ESTADO', style: headerStyle)),
          SizedBox(width: 28),
        ],
      ),
    );
  }

  /// Alertas de reservas por llegar con acceso a los ajustes (HU30-RF03).
  Widget _buildAlertasDeLlegada(AdminOperationsViewModel operaciones) {
    final alertas = operaciones.alertas;
    return Column(
      key: const ValueKey('alertas_llegada'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                !operaciones.config.alertasActivas
                    ? 'Alertas de llegada desactivadas'
                    : alertas.isEmpty
                        ? 'Sin llegadas próximas'
                        : '${alertas.length} ${alertas.length == 1 ? 'llegada próxima' : 'llegadas próximas'}',
                key: const ValueKey('alertas_resumen'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AdminReservationsView._textDark,
                ),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('btn_ajustes_alertas_reservas'),
              onPressed: () => AlertSettingsSheet.mostrar(
                context,
                config: operaciones.config,
                onGuardar: operaciones.guardarConfig,
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Ajustes'),
            ),
          ],
        ),
        for (final a in alertas.take(3))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ArrivalAlertTile(alerta: a, onTap: () => _alTocarReserva(a.reserva)),
          ),
      ],
    );
  }

  Widget _buildFilaReserva(ReservationModel reserva) {
    final badgeStyle = _obtenerEstiloEstado(reserva.estadoOperativo);
    final alerta = widget.operaciones?.alertaDe(reserva.id);

    return InkWell(
      key: ValueKey('item_reserva_${reserva.id}'),
      onTap: () => _alTocarReserva(reserva),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // 1. Hora
            SizedBox(
              width: 96,
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AdminReservationsView._primaryTerracotta,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reserva.horaInicioFormateada,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AdminReservationsView._textDark,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Cliente
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reserva.nombreCliente,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AdminReservationsView._textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (reserva.contactoTelefono.trim().isNotEmpty)
                      Text(
                        reserva.contactoTelefono,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminReservationsView._textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (alerta != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ArrivalAlertChip(alerta: alerta),
                      ),
                  ],
                ),
              ),
            ),

            // 3. Personas
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(
                    Icons.people_outline_rounded,
                    size: 16,
                    color: AdminReservationsView._textMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${reserva.cantidadPersonas} ${reserva.cantidadPersonas == 1 ? 'persona' : 'personas'}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AdminReservationsView._textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 4. Mesa(s) asignada(s)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.table_restaurant_outlined,
                      size: 16,
                      color: AdminReservationsView._textMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        reserva.mesasAsignadasTexto,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AdminReservationsView._textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Estado
            SizedBox(
              width: 155,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeStyle.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeStyle.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badgeStyle.icon,
                        size: 13,
                        color: badgeStyle.foreground,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          reserva.etiquetaEstado,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: badgeStyle.foreground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(
              width: 40,
              child: ReservationStateControl(
                reservaId: reserva.id,
                estadoActual: reserva.estadoOperativo,
                compacto: true,
                onChange: (nuevo) => _viewModel.cambiarEstado(reserva.id, nuevo),
              ),
            ),

            const SizedBox(
              width: 28,
              child: Icon(
                Icons.chevron_right_rounded,
                color: AdminReservationsView._textMuted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({
    Color background,
    Color border,
    Color foreground,
    IconData icon,
  }) _obtenerEstiloEstado(String estadoOperativo) {
    final e = ReservationStateStyle.of(estadoOperativo);
    return (
      background: e.background,
      border: e.border,
      foreground: e.foreground,
      icon: e.icon,
    );
  }
}
