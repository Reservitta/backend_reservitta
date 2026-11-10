import 'package:flutter/material.dart';

import '../../models/restaurant_model.dart';
import '../../services/availability_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/reservation_draft_viewmodel.dart';
import 'table_selection_step.dart';

/// Pasos que muestra la barra de estado de la reserva en la versión web.
const List<String> etapasReserva = [
  'Fecha',
  'Duración',
  'Personas',
  'Horario',
  'Mesa',
  'Resumen',
  'Datos',
];

/// Ancho a partir del cual la reserva se muestra en una sola pantalla.
const double anchoPantallaUnica = 1000;

/// Encabezado de la reserva en web: volver y título a la izquierda y la barra de
/// estado (pasos) siempre en la esquina superior derecha.
class EncabezadoReservaWeb extends StatelessWidget {
  /// Índice (0 a 6) de la etapa en curso dentro de [etapasReserva].
  final int etapaActual;
  final VoidCallback onVolver;
  final VoidCallback onCancelar;
  final void Function(int etapa)? onIrAEtapa;

  const EncabezadoReservaWeb({
    super.key,
    required this.etapaActual,
    required this.onVolver,
    required this.onCancelar,
    this.onIrAEtapa,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            key: const ValueKey('btn_stepper_back'),
            tooltip: 'Volver',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.marcaSuave,
              foregroundColor: AppColors.texto,
            ),
            onPressed: onVolver,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 14),
          const Text(
            'Haz tu reserva',
            style: TextStyle(
              fontFamily: AppTheme.familiaTitulos,
              fontWeight: FontWeight.w700,
              fontVariations: [FontVariation('wght', 700)],
              fontSize: 28,
              color: AppColors.texto,
            ),
          ),
          const Spacer(),
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: BarraEstadoReserva(
                  etapaActual: etapaActual,
                  onIrAEtapa: onIrAEtapa,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cancelar reserva',
            icon: const Icon(Icons.close, color: AppColors.textoSuave),
            onPressed: onCancelar,
          ),
        ],
      ),
    );
  }
}

/// Barra de estado: círculos numerados unidos por una línea; las etapas ya
/// completadas llevan una palomita y la actual va resaltada.
class BarraEstadoReserva extends StatelessWidget {
  final int etapaActual;
  final void Function(int etapa)? onIrAEtapa;

  const BarraEstadoReserva({
    super.key,
    required this.etapaActual,
    this.onIrAEtapa,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(etapasReserva.length, (i) {
        final completada = i < etapaActual;
        final activa = i == etapaActual;
        final hayLinea = i < etapasReserva.length - 1;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: completada && onIrAEtapa != null ? () => onIrAEtapa!(i) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (completada || activa) ? AppColors.marca : AppColors.marcaSuave,
                        shape: BoxShape.circle,
                      ),
                      child: completada
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: activa ? Colors.white : AppColors.textoSuave,
                              ),
                            ),
                    ),
                  ),
                  if (hayLinea)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        color: completada ? AppColors.marca : AppColors.divisor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                etapasReserva[i],
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: (completada || activa) ? FontWeight.w700 : FontWeight.w500,
                  color: (completada || activa) ? AppColors.marca : AppColors.textoSuave,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Reserva en una sola pantalla (web): fecha, duración, personas y horario como
/// campos que se habilitan uno tras otro y, debajo, el mapa de mesas en grande.
class FormularioReservaWeb extends StatefulWidget {
  final ReservationDraftViewModel viewModel;
  final RestaurantModel restaurant;
  final AvailabilityService availability;

  /// Cambia cada vez que hay que volver a cargar el mapa (p. ej. tras un aviso).
  final int recarga;

  /// Se avisa de la etapa en curso (0 a 4) para la barra de estado.
  final ValueChanged<int> onEtapaCambia;
  final VoidCallback onContinuar;
  final bool procesando;

  const FormularioReservaWeb({
    super.key,
    required this.viewModel,
    required this.restaurant,
    required this.availability,
    required this.onEtapaCambia,
    required this.onContinuar,
    this.recarga = 0,
    this.procesando = false,
  });

  @override
  State<FormularioReservaWeb> createState() => _FormularioReservaWebState();
}

class _FormularioReservaWebState extends State<FormularioReservaWeb> {
  late bool _duracionElegida;
  late bool _personasElegidas;
  List<TimeSlot> _horarios = const [];
  bool _cargandoHorarios = false;
  String _claveHorarios = '';
  int _peticion = 0;

  ReservationDraftViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    final d = _vm.draft;
    final yaAvanzo = d.horario != null || d.mesaIds.isNotEmpty;
    _duracionElegida = yaAvanzo;
    _personasElegidas = yaAvanzo;
    _vm.addListener(_alCambiarBorrador);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarHorarios();
      _avisarEtapa();
    });
  }

  @override
  void dispose() {
    _vm.removeListener(_alCambiarBorrador);
    super.dispose();
  }

  void _alCambiarBorrador() {
    if (mounted) setState(() {});
  }

  bool get _hayFecha => _vm.draft.fecha != null && _vm.canContinueFromDate;
  bool get _hayHorario => _vm.draft.horario != null;
  bool get _hayMesa => _vm.draft.mesaIds.isNotEmpty;

  int get _etapa {
    if (!_hayFecha) return 0;
    if (!_duracionElegida) return 1;
    if (!_personasElegidas) return 2;
    if (!_hayHorario) return 3;
    if (!_hayMesa) return 4;
    return 5;
  }

  void _avisarEtapa() {
    widget.onEtapaCambia(_etapa);
  }

  Future<void> _cargarHorarios() async {
    final fecha = _vm.draft.fecha;
    if (fecha == null || !_duracionElegida) return;
    final clave = '${fecha.year}-${fecha.month}-${fecha.day}_${_vm.draft.duracionMin}';
    if (clave == _claveHorarios) return;
    _claveHorarios = clave;
    final mia = ++_peticion;
    setState(() => _cargandoHorarios = true);
    List<TimeSlot> lista;
    try {
      lista = await widget.availability.getAvailableTimeSlots(
        restaurant: widget.restaurant,
        fecha: fecha,
        duracionMin: _vm.draft.duracionMin,
        mesaIds: const [],
      );
    } catch (_) {
      lista = const [];
    }
    if (!mounted || mia != _peticion) return;
    setState(() {
      _horarios = lista;
      _cargandoHorarios = false;
    });
  }

  Future<void> _elegirFecha() async {
    final ahora = _vm.clockNow;
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final ultima = hoy.add(Duration(days: _vm.maxAnticipacionDias));
    var inicial = _vm.draft.fecha ?? hoy;
    if (!_vm.isDateSelectable(inicial)) {
      var d = hoy;
      while (d.isBefore(ultima) && !_vm.isDateSelectable(d)) {
        d = d.add(const Duration(days: 1));
      }
      inicial = d;
    }
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: hoy,
      lastDate: ultima,
      helpText: '¿Qué día quieres visitarnos?',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      selectableDayPredicate: _vm.isDateSelectable,
    );
    if (elegida == null) return;
    _vm.selectDate(elegida);
    _claveHorarios = '';
    _cargarHorarios();
    _avisarEtapa();
  }

  static const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  String _textoFecha(DateTime f) =>
      '${_dias[f.weekday - 1]} ${f.day} ${_meses[f.month - 1]} ${f.year}';

  String _textoDuracion(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    final horas = h == 1 ? '1 hora' : '$h horas';
    return m == 0 ? horas : '$horas $m min';
  }

  String _textoHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void didUpdateWidget(covariant FormularioReservaWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _avisarEtapa();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _vm.draft;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _avisarEtapa();
    });

    final campos = <Widget>[
      _Campo(
        numero: 1,
        etiqueta: 'Fecha',
        habilitado: true,
        completo: _hayFecha,
        child: _CajaCampo(
          key: const ValueKey('campo_fecha'),
          icono: Icons.calendar_today_outlined,
          texto: _hayFecha ? _textoFecha(d.fecha!) : 'Elige el día',
          lleno: _hayFecha,
          onTap: _elegirFecha,
        ),
      ),
      _Campo(
        numero: 2,
        etiqueta: 'Duración',
        habilitado: _hayFecha,
        completo: _duracionElegida,
        ayuda: 'Primero elige la fecha',
        child: _Seleccion<int>(
          key: const ValueKey('campo_duracion'),
          icono: Icons.timer_outlined,
          pista: 'Cuánto tiempo',
          valor: _duracionElegida ? d.duracionMin : null,
          opciones: [
            for (final m in ReservationDraftViewModel.duracionesDisponibles)
              DropdownMenuItem(
                value: m,
                child: Text(
                  m == ReservationDraftViewModel.duracionPorDefectoMin
                      ? '${_textoDuracion(m)} (sugerido)'
                      : _textoDuracion(m),
                ),
              ),
          ],
          habilitado: _hayFecha,
          onChanged: (m) {
            if (m == null) return;
            _vm.selectDuration(m);
            setState(() => _duracionElegida = true);
            _cargarHorarios();
            _avisarEtapa();
          },
        ),
      ),
      _Campo(
        numero: 3,
        etiqueta: 'Personas',
        habilitado: _duracionElegida,
        completo: _personasElegidas,
        ayuda: 'Primero elige la duración',
        child: _Seleccion<int>(
          key: const ValueKey('campo_personas'),
          icono: Icons.group_outlined,
          pista: 'Cuántos van',
          valor: _personasElegidas ? d.personas : null,
          opciones: [
            for (var n = _vm.minPartySize; n <= _vm.maxPartySize; n++)
              DropdownMenuItem(
                value: n,
                child: Text(n == 1 ? '1 persona' : '$n personas'),
              ),
          ],
          habilitado: _duracionElegida,
          onChanged: (n) {
            if (n == null) return;
            _vm.setPartySize(n);
            setState(() => _personasElegidas = true);
            _avisarEtapa();
          },
        ),
      ),
      _Campo(
        numero: 4,
        etiqueta: 'Horario',
        habilitado: _personasElegidas,
        completo: _hayHorario,
        ayuda: 'Primero elige las personas',
        child: _Seleccion<String>(
          key: const ValueKey('campo_horario'),
          icono: Icons.schedule,
          pista: _cargandoHorarios
              ? 'Buscando horarios…'
              : (_horarios.isEmpty && _personasElegidas ? 'Sin horarios libres' : 'A qué hora'),
          valor: d.horario == null ? null : _textoHora(d.horario!),
          opciones: [
            for (final s in _horarios)
              DropdownMenuItem(
                value: _textoHora(TimeOfDay(hour: s.inicio.hour, minute: s.inicio.minute)),
                child: Text(_textoHora(TimeOfDay(hour: s.inicio.hour, minute: s.inicio.minute))),
              ),
          ],
          habilitado: _personasElegidas && !_cargandoHorarios && _horarios.isNotEmpty,
          onChanged: (txt) {
            if (txt == null) return;
            final partes = txt.split(':');
            _vm.selectHorario(
              TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1])),
            );
            _avisarEtapa();
          },
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divisor),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final cuatro = c.maxWidth >= 760;
              if (cuatro) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < campos.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(child: campos[i]),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final campo in campos)
                    SizedBox(width: (c.maxWidth - 16) / 2, child: campo),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        _buildMapa(d),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 280,
            height: 52,
            child: FilledButton(
              key: const ValueKey('btn_continuar_web'),
              onPressed: (_hayHorario && _hayMesa && !widget.procesando) ? widget.onContinuar : null,
              child: widget.procesando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Continuar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildMapa(dynamic d) {
    if (!_hayHorario) {
      return Container(
        key: const ValueKey('mapa_pendiente'),
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.marcaSuave.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divisor),
        ),
        child: const Column(
          children: [
            Icon(Icons.table_restaurant_outlined, size: 44, color: AppColors.textoSuave),
            SizedBox(height: 12),
            Text(
              'Aquí aparecerá el mapa de mesas',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.texto,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Completa la fecha, la duración, las personas y el horario para elegir tu mesa.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textoSuave),
            ),
          ],
        ),
      );
    }

    final inicio = _vm.draft.inicio!;
    return TableSelectionStep(
      key: ValueKey(
        'mapa_${inicio.toIso8601String()}_${_vm.draft.duracionMin}_${_vm.draft.personas}_${widget.recarga}',
      ),
      restaurant: widget.restaurant,
      availability: widget.availability,
      fecha: _vm.draft.fecha!,
      personas: _vm.draft.personas,
      duracionMin: _vm.draft.duracionMin,
      inicio: inicio,
      initialSelectedIds: _vm.draft.mesaIds,
      onSelectionChanged: (mesas) {
        _vm.setSelectedTables(mesas, conservarHorario: true);
        _avisarEtapa();
      },
      onEspaciosChanged: _vm.setSelectedSpaces,
      onChangeStep: (_) {},
    );
  }
}

/// Campo numerado con su etiqueta; se ve atenuado mientras no está habilitado.
class _Campo extends StatelessWidget {
  final int numero;
  final String etiqueta;
  final bool habilitado;
  final bool completo;
  final String? ayuda;
  final Widget child;

  const _Campo({
    required this.numero,
    required this.etiqueta,
    required this.habilitado,
    required this.completo,
    required this.child,
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: habilitado ? 1 : 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completo ? AppColors.exito : AppColors.marcaSuave,
                  shape: BoxShape.circle,
                ),
                child: completo
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : Text(
                        '$numero',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoSuave,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                etiqueta,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.texto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
          if (!habilitado && ayuda != null) ...[
            const SizedBox(height: 6),
            Text(
              ayuda!,
              style: const TextStyle(fontSize: 12, color: AppColors.textoSuave),
            ),
          ],
        ],
      ),
    );
  }
}

/// Caja con aspecto de campo que abre un selector (se usa para la fecha).
class _CajaCampo extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool lleno;
  final VoidCallback onTap;

  const _CajaCampo({
    super.key,
    required this.icono,
    required this.texto,
    required this.lleno,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: lleno ? AppColors.marca : AppColors.borde, width: lleno ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: AppColors.marca),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: lleno ? FontWeight.w700 : FontWeight.w500,
                  color: lleno ? AppColors.texto : AppColors.textoSuave,
                ),
              ),
            ),
            const Icon(Icons.expand_more, size: 20, color: AppColors.textoSuave),
          ],
        ),
      ),
    );
  }
}

/// Lista desplegable con el mismo aspecto que [_CajaCampo].
class _Seleccion<T> extends StatelessWidget {
  final IconData icono;
  final String pista;
  final T? valor;
  final List<DropdownMenuItem<T>> opciones;
  final bool habilitado;
  final ValueChanged<T?> onChanged;

  const _Seleccion({
    super.key,
    required this.icono,
    required this.pista,
    required this.valor,
    required this.opciones,
    required this.habilitado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lleno = valor != null;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lleno ? AppColors.marca : AppColors.borde, width: lleno ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Icon(icono, size: 20, color: AppColors.marca),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: valor,
                hint: Text(
                  pista,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: AppColors.textoSuave),
                ),
                items: opciones,
                onChanged: habilitado ? onChanged : null,
                borderRadius: BorderRadius.circular(12),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.texto,
                ),
                icon: const Icon(Icons.expand_more, color: AppColors.textoSuave),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
