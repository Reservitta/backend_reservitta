import 'package:flutter/material.dart';
import '../models/reservation_model.dart';
import '../repositories/reservation_repository.dart';
import '../viewmodels/admin_reservations_viewmodel.dart';

/// Pantalla de listado de reservas para administradores de restaurante (HU26-RF02)
///
/// Criterios de aceptación:
/// 1. Lista o tabla con hora, cliente, personas, mesa y estado, ordenada cronológicamente.
/// 2. Se puede seleccionar una fecha distinta a la de hoy mediante un selector de fecha.
/// 3. Al tocar una reserva se despliega la descripción de la reserva (placeholder previo a HU28).
/// 4. Se muestra un estado vacío ("No hay reservas para este día") y manejo de errores con "Reintentar".
/// 5. La lista se actualiza en tiempo real si llega una nueva reserva o cambia su estado.
class AdminReservationsView extends StatefulWidget {
  final String restaurantId;
  final ReservationRepository? reservationRepository;
  final AdminReservationsViewModel? viewModel;
  final bool showAppBar;
  final void Function(ReservationModel reservation)? onReservationTap;

  const AdminReservationsView({
    super.key,
    required this.restaurantId,
    this.reservationRepository,
    this.viewModel,
    this.showAppBar = true,
    this.onReservationTap,
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

  /// Al tocar una reserva despliega únicamente su descripción general (previo a HU28)
  void _alTocarReserva(ReservationModel reserva) {
    if (widget.onReservationTap != null) {
      widget.onReservationTap!(reserva);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          key: ValueKey('dialogo_descripcion_reserva_${reserva.id}'),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AdminReservationsView._cardBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminReservationsView._primaryTerracotta
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AdminReservationsView._primaryTerracotta,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Descripción de la reserva',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AdminReservationsView._textDark,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilaDescripcion(
                    icono: Icons.person_outline_rounded,
                    etiqueta: 'Cliente',
                    valor: reserva.nombreCliente,
                  ),
                  if (reserva.contactoTelefono.trim().isNotEmpty)
                    _buildFilaDescripcion(
                      icono: Icons.phone_outlined,
                      etiqueta: 'Teléfono',
                      valor: reserva.contactoTelefono,
                    ),
                  if (reserva.contactoCorreo.trim().isNotEmpty)
                    _buildFilaDescripcion(
                      icono: Icons.email_outlined,
                      etiqueta: 'Correo',
                      valor: reserva.contactoCorreo,
                    ),
                  _buildFilaDescripcion(
                    icono: Icons.calendar_today_outlined,
                    etiqueta: 'Fecha',
                    valor: reserva.fechaLocal,
                  ),
                  _buildFilaDescripcion(
                    icono: Icons.access_time_rounded,
                    etiqueta: 'Horario',
                    valor: reserva.horarioFormateado,
                  ),
                  _buildFilaDescripcion(
                    icono: Icons.groups_outlined,
                    etiqueta: 'Personas',
                    valor:
                        '${reserva.cantidadPersonas} ${reserva.cantidadPersonas == 1 ? 'persona' : 'personas'}',
                  ),
                  _buildFilaDescripcion(
                    icono: Icons.table_restaurant_outlined,
                    etiqueta: 'Mesa(s)',
                    valor: reserva.mesasAsignadasTexto,
                  ),
                  _buildFilaDescripcion(
                    icono: Icons.info_outline_rounded,
                    etiqueta: 'Estado',
                    valor: reserva.etiquetaEstado,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminReservationsView._creamLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AdminReservationsView._cardBorder,
                      ),
                    ),
                    child: Text(
                      'Reserva registrada para ${reserva.nombreCliente} '
                      '(${reserva.cantidadPersonas} ${reserva.cantidadPersonas == 1 ? 'comensal' : 'comensales'}) '
                      'a las ${reserva.horaInicioFormateada} en ${reserva.mesasAsignadasTexto}.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminReservationsView._textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              key: const ValueKey('boton_cerrar_descripcion_reserva'),
              style: FilledButton.styleFrom(
                backgroundColor: AdminReservationsView._primaryTerracotta,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilaDescripcion({
    required IconData icono,
    required String etiqueta,
    required String valor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: AdminReservationsView._textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(
              '$etiqueta:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminReservationsView._textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AdminReservationsView._textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
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
                          fontSize: 11.5,
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
                                  fontSize: 10.5,
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
        valor: ReservationModel.estadoCancelada,
        etiqueta:
            'Cancelada (${_viewModel.contarPorEstado(ReservationModel.estadoCancelada)})',
        keyId: 'filtro_estado_cancelada',
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
      fontSize: 11.5,
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

  Widget _buildFilaReserva(ReservationModel reserva) {
    final badgeStyle = _obtenerEstiloEstado(reserva.estadoOperativo);

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
                            fontSize: 11.5,
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
    switch (estadoOperativo) {
      case ReservationModel.estadoClienteLlego:
        return (
          background: const Color(0xFFE3F2FD),
          border: const Color(0xFF90CAF9),
          foreground: const Color(0xFF1565C0),
          icon: Icons.how_to_reg_rounded,
        );
      case ReservationModel.estadoEnServicio:
        return (
          background: const Color(0xFFE8F5E9),
          border: const Color(0xFFA5D6A7),
          foreground: const Color(0xFF2E7D32),
          icon: Icons.restaurant_rounded,
        );
      case ReservationModel.estadoCancelada:
        return (
          background: const Color(0xFFFFEBEE),
          border: const Color(0xFFEF9A9A),
          foreground: const Color(0xFFC62828),
          icon: Icons.cancel_outlined,
        );
      case ReservationModel.estadoPendienteLlegada:
      default:
        return (
          background: const Color(0xFFFFF8E1),
          border: const Color(0xFFFFE082),
          foreground: const Color(0xFFB26A00),
          icon: Icons.schedule_rounded,
        );
    }
  }
}
