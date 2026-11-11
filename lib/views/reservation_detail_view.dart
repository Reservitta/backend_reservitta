import 'package:flutter/material.dart';

import '../models/reservation_detail.dart';
import '../models/reservation_model.dart';
import '../repositories/reservation_repository.dart';
import 'widgets/order_state_control.dart';
import 'widgets/reservation_state_control.dart';
import '../theme/app_theme.dart';

/// Pantalla de detalle de una reservación para el administrador (HU28-RF02).
///
/// Muestra los platillos preseleccionados agrupados con sus notas, destaca las
/// alergias y restricciones, pone al frente la ocasión especial y permite cambiar
/// el estado de la reserva (HU27-RF02) y ver el del pedido (HU29).
class ReservationDetailView extends StatefulWidget {
  final String reservationId;
  final ReservationRepository repository;

  /// Cambia el estado de la reserva; devuelve un mensaje de error o null si se aplicó.
  final Future<String?> Function(String nuevoEstado) onChangeState;

  /// Nombres de categoría por id, para agrupar los platillos (entrada, plato fuerte...).
  final Future<Map<String, String>> Function()? cargarCategorias;

  /// Cambia el estado del pedido (HU29-RF02); devuelve un mensaje de error o null.
  /// Si es null no se muestra el control del pedido.
  final Future<String?> Function(String nuevoEstado, {String? motivo})? onChangeOrderState;

  const ReservationDetailView({
    super.key,
    required this.reservationId,
    required this.repository,
    required this.onChangeState,
    this.cargarCategorias,
    this.onChangeOrderState,
  });

  static const Color terracotta = AppColors.marca;
  static const Color creamBg = AppColors.fondo;
  static const Color cardBorder = AppColors.divisor;
  static const Color darkText = AppColors.texto;
  static const Color mutedText = AppColors.textoSuave;
  static const Color alertRed = Color(0xFFC62828);

  @override
  State<ReservationDetailView> createState() => _ReservationDetailViewState();
}

class _ReservationDetailViewState extends State<ReservationDetailView> {
  ReservationDetail? _detalle;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      Map<String, String> categorias = const {};
      try {
        categorias = await widget.cargarCategorias?.call() ?? const {};
      } catch (_) {
        // Sin categorías los platillos se agrupan con la etiqueta general.
      }
      final detalle = await widget.repository.getReservationDetail(
        widget.reservationId,
        categoriasPorId: categorias,
      );
      if (!mounted) return;
      setState(() {
        _detalle = detalle;
        _error = detalle == null ? 'No se encontró la reservación.' : null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el detalle de la reserva.';
        _cargando = false;
      });
    }
  }

  Future<String?> _cambiarEstado(String nuevo) async {
    final error = await widget.onChangeState(nuevo);
    if (error == null) await _cargar();
    return error;
  }

  Future<String?> _cambiarEstadoPedido(String nuevo, {String? motivo}) async {
    final error = await widget.onChangeOrderState!(nuevo, motivo: motivo);
    if (error == null) await _cargar();
    return error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReservationDetailView.creamBg,
      appBar: AppBar(
        title: const Text('Detalle de la reservación'),
        backgroundColor: ReservationDetailView.creamBg,
        foregroundColor: ReservationDetailView.darkText,
        elevation: 0,
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _detalle == null) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('detalle_cargando')),
      );
    }
    final d = _detalle;
    if (d == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'No se encontró la reservación.',
                  key: const ValueKey('detalle_error'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey('detalle_reintentar'),
                onPressed: _cargar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        key: const ValueKey('detalle_contenido'),
        padding: const EdgeInsets.all(16),
        children: [
          _encabezado(d),
          const SizedBox(height: 14),
          _ocasion(d),
          const SizedBox(height: 14),
          _alergias(d),
          const SizedBox(height: 14),
          _pedido(d),
          const SizedBox(height: 14),
          _cliente(d),
          const SizedBox(height: 14),
          _estado(d),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secciones
  // ---------------------------------------------------------------------------

  Widget _tarjeta({Key? key, required Widget child, Color? color, Color? borde}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borde ?? ReservationDetailView.cardBorder),
      ),
      child: child,
    );
  }

  Widget _titulo(String texto, {IconData? icono, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icono != null) ...[
            Icon(icono, size: 20, color: color ?? ReservationDetailView.terracotta),
            const SizedBox(width: 8),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? ReservationDetailView.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noIndicado() => const Text(
        ReservationDetail.noIndicado,
        key: ValueKey('texto_no_indicado'),
        style: TextStyle(color: ReservationDetailView.mutedText, fontStyle: FontStyle.italic),
      );

  Widget _fila(IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: ReservationDetailView.mutedText),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(etiqueta,
                style: const TextStyle(color: ReservationDetailView.mutedText, fontSize: 13)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: ReservationDetailView.darkText)),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(ReservationDetail d) {
    final estilo = ReservationStateStyle.of(d.estadoOperativo);
    return _tarjeta(
      key: const ValueKey('detalle_encabezado'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(d.clienteNombre,
                    key: const ValueKey('detalle_cliente'),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ReservationDetailView.darkText)),
              ),
              Container(
                key: const ValueKey('detalle_estado_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: estilo.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: estilo.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(estilo.icon, size: 15, color: estilo.foreground),
                    const SizedBox(width: 6),
                    Text(d.etiquetaEstado,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: estilo.foreground)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fila(Icons.calendar_today_outlined, 'Fecha', d.fechaLocal),
          _fila(Icons.schedule_rounded, 'Horario', d.horario),
          _fila(Icons.groups_outlined, 'Personas', '${d.personas}'),
          _fila(Icons.table_restaurant_outlined, d.mesas.length > 1 ? 'Mesas' : 'Mesa', d.mesasTexto),
        ],
      ),
    );
  }

  Widget _ocasion(ReservationDetail d) {
    if (!d.esOcasionEspecial) {
      return _tarjeta(
        key: const ValueKey('detalle_ocasion_vacia'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Ocasión especial', icono: Icons.celebration_outlined),
            _noIndicado(),
          ],
        ),
      );
    }
    return _tarjeta(
      key: const ValueKey('detalle_ocasion'),
      color: const Color(0xFFFFF3E8),
      borde: ReservationDetailView.terracotta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo('Ocasión especial', icono: Icons.celebration_rounded),
          Text(d.resumenOcasion,
              key: const ValueKey('detalle_tipo_ocasion'),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ReservationDetailView.terracotta)),
          for (final e in d.experiencias) ...[
            const SizedBox(height: 10),
            Text('• ${e.nombre} (${e.precioFormateado})',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (e.mensajeFelicitacion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Text('Mensaje: "${e.mensajeFelicitacion}"',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _alergias(ReservationDetail d) {
    if (!d.tieneAlergias && !d.tieneObservaciones) {
      return _tarjeta(
        key: const ValueKey('detalle_alergias_vacias'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Alergias y restricciones', icono: Icons.health_and_safety_outlined),
            _noIndicado(),
          ],
        ),
      );
    }
    return _tarjeta(
      key: const ValueKey('detalle_alergias'),
      color: const Color(0xFFFFEBEE),
      borde: ReservationDetailView.alertRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo('¡Alergias y restricciones!',
              icono: Icons.warning_amber_rounded, color: ReservationDetailView.alertRed),
          if (d.alergias.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final a in d.alergias)
                  Chip(
                    avatar: const Icon(Icons.warning_amber_rounded,
                        size: 16, color: ReservationDetailView.alertRed),
                    label: Text(a, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: ReservationDetailView.alertRed),
                  ),
              ],
            ),
          if (d.notasAlergias.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.notasAlergias,
                key: const ValueKey('detalle_notas_alergias'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          for (final o in d.observacionesPorPlatillo) ...[
            const SizedBox(height: 6),
            Text('• $o', style: const TextStyle(fontSize: 13.5)),
          ],
        ],
      ),
    );
  }

  Widget _pedido(ReservationDetail d) {
    if (!d.tienePreorden) {
      return _tarjeta(
        key: const ValueKey('detalle_pedido_vacio'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Platillos preseleccionados', icono: Icons.restaurant_menu),
            _noIndicado(),
          ],
        ),
      );
    }
    final estilo = ReservationStateStyle.of(ReservationModel.estadoPendienteLlegada);
    return _tarjeta(
      key: const ValueKey('detalle_pedido'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Platillos preseleccionados',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ReservationDetailView.darkText)),
              ),
              Container(
                key: const ValueKey('detalle_estado_pedido'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estilo.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: estilo.border),
                ),
                child: Text('Pedido: ${d.etiquetaEstadoPreorden}',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: estilo.foreground)),
              ),
            ],
          ),
          if (widget.onChangeOrderState != null) ...[
            const SizedBox(height: 12),
            OrderStateControl(
              reservaId: d.id,
              estadoActual: d.estadoPreorden,
              onChange: _cambiarEstadoPedido,
            ),
          ],
          for (final grupo in d.platillosPorGrupo.entries) ...[
            const SizedBox(height: 12),
            Text(grupo.key.toUpperCase(),
                key: ValueKey('grupo_${grupo.key}'),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: ReservationDetailView.terracotta)),
            for (final p in grupo.value)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.cantidad}× ${p.nombre}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (p.tieneNota)
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.edit_note_rounded,
                                size: 16, color: ReservationDetailView.mutedText),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text('Nota: ${p.nota}',
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: ReservationDetailView.mutedText)),
                            ),
                          ],
                        ),
                      ),
                    if (p.mensajeFelicitacion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 2),
                        child: Text('Felicitación: "${p.mensajeFelicitacion}"',
                            style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
          ],
          const Divider(height: 24),
          Text('Subtotal del pedido: \$${d.subtotalPreorden.toStringAsFixed(2)} MXN',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _cliente(ReservationDetail d) {
    return _tarjeta(
      key: const ValueKey('detalle_contacto'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo('Datos del cliente', icono: Icons.person_outline_rounded),
          _fila(Icons.person_outline_rounded, 'Nombre', d.clienteNombre),
          _fila(Icons.phone_outlined, 'Teléfono', d.clienteTelefono),
          _fila(Icons.email_outlined, 'Correo', d.clienteCorreo),
        ],
      ),
    );
  }

  Widget _estado(ReservationDetail d) {
    final siguientes = d.estadoOperativo;
    return _tarjeta(
      key: const ValueKey('detalle_cambio_estado'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo('Estado de la reserva', icono: Icons.swap_horiz_rounded),
          Text('Estado actual: ${d.etiquetaEstado}',
              style: const TextStyle(color: ReservationDetailView.mutedText)),
          const SizedBox(height: 12),
          ReservationStateControl(
            reservaId: d.id,
            estadoActual: siguientes,
            onChange: _cambiarEstado,
          ),
        ],
      ),
    );
  }
}
