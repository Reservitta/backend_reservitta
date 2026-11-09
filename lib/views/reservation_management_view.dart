import 'package:flutter/material.dart';

import '../models/branch_model.dart';
import '../models/mesa_model.dart';
import '../models/operations_config.dart';
import '../models/reservation_access.dart';
import '../models/restaurant_model.dart';
import '../services/availability_service.dart';
import '../services/reminder_service.dart';
import '../services/reservation_management_service.dart';
import '../services/reservation_service.dart';
import '../services/restaurant_service.dart';
import '../services/table_service.dart';
import '../viewmodels/reservation_draft_viewmodel.dart';
import 'reservation_flow_view.dart';
import 'widgets/reservation_state_control.dart';

/// Gestión de una reserva con su enlace o código, sin iniciar sesión (HU20-RF03).
///
/// Dentro del límite de tiempo permite modificar o cancelar; pasado el límite
/// muestra el resumen en solo lectura con los datos de contacto del restaurante.
class ReservationManagementView extends StatefulWidget {
  /// Código que viene en el enlace; si es null se pide escribirlo.
  final String? initialCode;
  final ReservationManagementService? service;
  final Future<RestaurantModel?> Function(String restaurantId)? cargarRestaurante;

  /// Disponibilidad que no cuenta la propia reserva, para elegir mesa y horario al modificar.
  final AvailabilityService Function(String reservaId)? disponibilidadParaEditar;

  /// Qué hacer al terminar (por defecto regresa a la pantalla anterior).
  final VoidCallback? onSalir;
  final DateTime Function()? now;

  const ReservationManagementView({
    super.key,
    this.initialCode,
    this.service,
    this.cargarRestaurante,
    this.disponibilidadParaEditar,
    this.onSalir,
    this.now,
  });

  static const Color terracotta = Color(0xFFB34A26);
  static const Color creamBg = Color(0xFFFAF6F0);
  static const Color darkText = Color(0xFF2E241E);
  static const Color mutedText = Color(0xFF7A6E65);
  static const Color cardBorder = Color(0xFFEDE4D8);

  @override
  State<ReservationManagementView> createState() => _ReservationManagementViewState();
}

class _ReservationManagementViewState extends State<ReservationManagementView> {
  late final ReservationManagementService _service;
  final TextEditingController _codigoCtrl = TextEditingController();

  ManagedReservation? _reserva;
  OperationsConfig _operaciones = const OperationsConfig();
  ({String nombre, String telefono, String direccion})? _contacto;
  bool _cargando = false;
  bool _procesando = false;
  String? _error;
  String? _aviso;

  DateTime get _ahora => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ReservationManagementService();
    final inicial = widget.initialCode;
    if (inicial != null && inicial.trim().isNotEmpty) {
      _codigoCtrl.text = ReservationAccess.formatear(inicial);
      WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _cargando = true;
      _error = null;
      _aviso = null;
    });
    try {
      final reserva = await _service.consultar(_codigoCtrl.text);
      ({String nombre, String telefono, String direccion})? contacto;
      if (!reserva.puedeGestionar(_ahora, politica: _service.politica)) {
        try {
          contacto = await _service.contactoRestaurante(reserva.restauranteId);
        } catch (_) {
          // El contacto es un extra: sin él igual se muestra el resumen.
        }
      }
      // HU21-RF02: con qué anticipación se avisa. Es un extra: sin él se usa el valor por defecto.
      var operaciones = const OperationsConfig();
      try {
        final cargar = widget.cargarRestaurante ??
            (String id) => RestaurantService().getRestaurantById(id);
        final restaurante = await cargar(reserva.restauranteId);
        if (restaurante != null) operaciones = restaurante.operaciones;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _reserva = reserva;
        _operaciones = operaciones;
        _contacto = contacto;
        _cargando = false;
      });
    } on ManagementException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo consultar la reserva. Revisa tu conexión e intenta de nuevo.';
        _cargando = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Cancelar (Criterio 3: pide confirmación explícita)
  // ---------------------------------------------------------------------------
  Future<void> _cancelar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('dialogo_cancelar_reserva'),
        title: const Text('¿Cancelar tu reserva?'),
        content: const Text(
          'Se liberará tu mesa y no podrás deshacerlo. Si quieres otro horario, mejor usa "Modificar".',
        ),
        actions: [
          TextButton(
            key: const ValueKey('btn_volver_cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const ValueKey('btn_confirmar_cancelar'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar mi reserva'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _procesando = true);
    try {
      final actualizada = await _service.cancelar(_codigoCtrl.text);
      if (!mounted) return;
      setState(() {
        _reserva = actualizada;
        _aviso = 'Tu reserva fue cancelada. ¡Esperamos verte pronto!';
        _procesando = false;
      });
    } on ManagementException catch (e) {
      _mostrarError(e.message);
    } catch (_) {
      _mostrarError('No se pudo cancelar. Revisa tu conexión e intenta de nuevo.');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    setState(() => _procesando = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(key: const ValueKey('snack_gestion_error'), content: Text(mensaje)));
  }

  // ---------------------------------------------------------------------------
  // Modificar (Criterio 4: reutiliza las pantallas del flujo de reserva, prellenadas)
  // ---------------------------------------------------------------------------
  Future<void> _modificar() async {
    final reserva = _reserva!;
    setState(() => _procesando = true);
    RestaurantModel? restaurante;
    try {
      final cargar = widget.cargarRestaurante ??
          (String id) => RestaurantService().getRestaurantById(id);
      restaurante = await cargar(reserva.restauranteId);
    } catch (_) {
      restaurante = null;
    }
    if (!mounted) return;
    setState(() => _procesando = false);
    if (restaurante == null) {
      _mostrarError('No se pudo abrir el restaurante para modificar la reserva.');
      return;
    }

    final disponibilidad = widget.disponibilidadParaEditar?.call(reserva.reservaId) ??
        AvailabilityService(
          ReservationService(),
          tables: TableService(),
          ignorarReservaId: reserva.reservaId,
        );
    final vm = _borradorPrellenado(restaurante, reserva);

    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReservationFlowView(
          restaurant: restaurante!,
          viewModel: vm,
          availabilityService: disponibilidad,
          isAuthenticated: true,
          confirmButtonText: 'Guardar cambios',
          onConfirmModification: (draft) async {
            try {
              await _service.modificar(
                _codigoCtrl.text,
                restaurant: restaurante!,
                fecha: draft.fecha!,
                inicio: draft.inicio!,
                duracionMin: draft.duracionMin,
                personas: draft.personas,
                mesaIds: draft.mesaIds,
                mesasNombres: draft.mesasNombres,
                margenLimpiezaMin: disponibilidad.margenLimpiezaMin,
              );
              return null;
            } on ManagementException catch (e) {
              return e.message;
            } catch (_) {
              return 'No se pudo guardar el cambio. Revisa tu conexión e intenta de nuevo.';
            }
          },
        ),
      ),
    );

    if (guardado == true && mounted) {
      await _buscar();
      if (!mounted) return;
      setState(() => _aviso = 'Tu reserva se actualizó correctamente.');
    }
  }

  /// Borrador con los datos actuales de la reserva, listo en el paso de fecha.
  ReservationDraftViewModel _borradorPrellenado(
    RestaurantModel restaurante,
    ManagedReservation r,
  ) {
    final vm = ReservationDraftViewModel(restaurant: restaurante, clock: widget.now);
    vm.selectBranch(BranchModel(
      id: restaurante.id,
      nombre: restaurante.nombre,
      direccion: restaurante.direccion,
      telefono: restaurante.telefono,
      esPrincipal: true,
    ));
    final dia = DateTime(r.inicio.year, r.inicio.month, r.inicio.day);
    vm.selectDate(dia);
    vm.selectDuration(r.duracionMin);
    vm.setPartySize(r.personas);
    vm.setSelectedTables([
      for (var i = 0; i < r.mesaIds.length; i++)
        MesaModel(
          id: r.mesaIds[i],
          nombre: i < r.mesasNombres.length ? r.mesasNombres[i] : r.mesaIds[i],
          capacidad: r.personas,
        ),
    ]);
    vm.selectTime(TimeSlot(inicio: r.inicio, fin: r.fin));
    vm.goToStep(1);
    return vm;
  }

  void _salir() {
    final salir = widget.onSalir;
    if (salir != null) {
      salir();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReservationManagementView.creamBg,
      appBar: AppBar(
        title: const Text('Gestionar mi reserva'),
        backgroundColor: ReservationManagementView.creamBg,
        foregroundColor: ReservationManagementView.darkText,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('btn_salir_gestion'),
          icon: const Icon(Icons.arrow_back),
          onPressed: _salir,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_reserva == null) _buscador() else _detalle(_reserva!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta({Key? key, required Widget child, Color? color, Color? borde}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde ?? ReservationManagementView.cardBorder),
      ),
      child: child,
    );
  }

  Widget _buscador() {
    return _tarjeta(
      key: const ValueKey('buscador_reserva'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ingresa tu código de reserva',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ReservationManagementView.darkText)),
          const SizedBox(height: 4),
          const Text(
            'Lo recibiste en el mensaje de confirmación, junto con el enlace.',
            style: TextStyle(fontSize: 13, color: ReservationManagementView.mutedText),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('campo_codigo_reserva'),
            controller: _codigoCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Código',
              hintText: 'ABCD-EFGH-JKMN-PQRS-TUVW',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _buscar(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                key: const ValueKey('error_codigo'),
                style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const ValueKey('btn_buscar_reserva'),
              style: FilledButton.styleFrom(backgroundColor: ReservationManagementView.terracotta),
              onPressed: _cargando ? null : _buscar,
              child: _cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Buscar mi reserva'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 19, color: ReservationManagementView.terracotta),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(etiqueta,
                style: const TextStyle(
                    fontSize: 13, color: ReservationManagementView.mutedText)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: ReservationManagementView.darkText)),
          ),
        ],
      ),
    );
  }

  static const _dias = ['L', 'M', 'Mi', 'J', 'V', 'S', 'D'];
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto',
    'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  String _fecha(DateTime d) => '${_dias[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _detalle(ManagedReservation r) {
    final estilo = ReservationStateStyle.of(r.estadoOperativo);
    final problema = r.motivoNoGestionable(_ahora, politica: _service.politica);
    final gestionable = problema == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_aviso != null) ...[
          _tarjeta(
            key: const ValueKey('aviso_exito'),
            color: const Color(0xFFE8F5E9),
            borde: const Color(0xFFA5D6A7),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                Expanded(child: Text(_aviso!, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        _tarjeta(
          key: const ValueKey('resumen_reserva'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.restauranteNombre,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: ReservationManagementView.darkText)),
                  ),
                  Container(
                    key: const ValueKey('estado_reserva'),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: estilo.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: estilo.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estilo.icon, size: 15, color: estilo.foreground),
                        const SizedBox(width: 5),
                        Text(ReservationModelEtiqueta.de(r.estadoOperativo),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: estilo.foreground)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _fila(Icons.calendar_today, 'Fecha', _fecha(r.inicio)),
              _fila(Icons.schedule, 'Horario', '${_hhmm(r.inicio)} – ${_hhmm(r.fin)}'),
              _fila(Icons.people_outline, 'Personas', '${r.personas}'),
              _fila(Icons.table_restaurant_outlined, 'Mesa', r.mesasTexto),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (gestionable)
          _acciones(r)
        else
          _soloLectura(problema),
        const SizedBox(height: 14),
        TextButton(
          key: const ValueKey('btn_buscar_otra'),
          onPressed: () => setState(() {
            _reserva = null;
            _contacto = null;
            _aviso = null;
            _codigoCtrl.clear();
          }),
          child: const Text('Consultar otra reserva'),
        ),
      ],
    );
  }

  Widget _acciones(ManagedReservation r) {
    final limite = _service.politica.limite(r.inicio);
    final recordatorio = ReminderPolicy.textoParaCliente(
      inicio: r.inicio,
      ahora: _ahora,
      config: _operaciones,
    );
    return _tarjeta(
      key: const ValueKey('acciones_reserva'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recordatorio != null) ...[
            Row(
              key: const ValueKey('aviso_recordatorio'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined,
                    size: 18, color: ReservationManagementView.mutedText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(recordatorio,
                      style: const TextStyle(
                          color: ReservationManagementView.mutedText, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'Puedes modificar o cancelar hasta el ${_fecha(limite)} a las ${_hhmm(limite)}.',
            key: const ValueKey('texto_limite'),
            style: const TextStyle(color: ReservationManagementView.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('btn_modificar_reserva'),
            style: FilledButton.styleFrom(
              backgroundColor: ReservationManagementView.terracotta,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _procesando ? null : _modificar,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Modificar reserva'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('btn_cancelar_reserva'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
              side: const BorderSide(color: Color(0xFFEF9A9A)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _procesando ? null : _cancelar,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
  }

  /// Pasado el límite (o reserva ya cerrada): resumen en solo lectura con aviso y contacto.
  Widget _soloLectura(ManagementException problema) {
    final c = _contacto;
    return _tarjeta(
      key: const ValueKey('aviso_solo_lectura'),
      color: const Color(0xFFFFF3D6),
      borde: const Color(0xFFE0A100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF7A5A00)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(problema.message,
                    key: const ValueKey('motivo_solo_lectura'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (c != null && (c.telefono.isNotEmpty || c.direccion.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Column(
              key: const ValueKey('contacto_restaurante'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.nombre.isNotEmpty)
                  Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (c.telefono.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.phone_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(c.telefono),
                  ]),
                ],
                if (c.direccion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.direccion)),
                  ]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Etiqueta legible de un estado operativo.
class ReservationModelEtiqueta {
  const ReservationModelEtiqueta._();

  static String de(String estado) {
    switch (estado) {
      case 'cliente_llego':
        return 'Cliente llegó';
      case 'en_servicio':
        return 'En servicio';
      case 'finalizada':
        return 'Finalizada';
      case 'cancelada':
        return 'Cancelada';
      case 'no_show':
        return 'No se presentó';
      default:
        return 'Confirmada';
    }
  }
}
