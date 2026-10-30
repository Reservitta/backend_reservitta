import 'package:flutter/material.dart';
import '../models/booking_models.dart';
import '../models/branch_model.dart';
import '../models/restaurant_model.dart';
import '../services/availability_service.dart';
import '../services/reservation_booking_service.dart';
import '../services/reservation_service.dart';
import '../services/restaurant_service.dart';
import '../services/table_service.dart';
import '../viewmodels/reservation_draft_viewmodel.dart';
import '../models/reservation_draft_model.dart';
import '../services/auth_service.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import 'auth_modal_dialog.dart';
import 'reservation_confirmation_view.dart';
import 'widgets/contact_form_step.dart';
import 'widgets/reservation_summary_step.dart';
import 'widgets/table_selection_step.dart';
import 'widgets/time_slot_step.dart';

/// Flujo interactivo de reserva (HU07-RF01, HU07-RF02, HU08-RF01, HU09-RF01, HU13, HU14).
/// Implementa los pasos: Sucursal, Fecha, Duración, Personas, Mesa, Horario,
/// Resumen y Datos de contacto.
class ReservationFlowView extends StatefulWidget {
  final RestaurantModel restaurant;
  final RestaurantService? restaurantService;
  final ReservationDraftViewModel? viewModel;

  /// Motor de disponibilidad para los pasos de mesa y horario (HU09 a HU11).
  final AvailabilityService? availabilityService;

  /// Servicio de autenticación para comprobar si el visitante tiene sesión iniciada (HU11-RF03).
  final AuthService? authService;

  /// Permite sobrescribir el estado de autenticación (útil para pruebas).
  final bool? isAuthenticated;

  /// Callback opcional para avanzar al paso de captura de datos de contacto (HU13).
  final void Function(ReservationDraftModel draft)? onProceedToContact;

  /// Callback opcional invocado cuando el usuario sin sesión confirma la reserva.
  final VoidCallback? onRequireAuth;

  /// Texto personalizable para el botón de confirmación/avance del resumen.
  final String? confirmButtonText;

  /// Si es true y no hay paso de contacto, al confirmar el resumen se guarda la
  /// reserva en una transacción y se muestra la pantalla de confirmación (HU11-RF04).
  final bool createReservationOnConfirm;

  /// Servicio que confirma la reserva (se puede sustituir en pruebas).
  final ReservationBookingService? bookingService;

  /// Permite sobrescribir el id del usuario autenticado (útil para pruebas).
  final String? currentUserId;

  /// Activa el paso 7 (Datos de contacto, HU13/HU14). Por defecto desactivado
  /// para no alterar el flujo existente de HU11/HU12.
  final bool enableContactStep;

  /// Se invoca al terminar el paso de datos, con el borrador y la contraseña
  /// (solo si el visitante pidió crear cuenta; si no, es null).
  final void Function(ReservationDraftModel draft, String? password)?
      onContactSubmitted;

  const ReservationFlowView({
    super.key,
    required this.restaurant,
    this.restaurantService,
    this.viewModel,
    this.availabilityService,
    this.authService,
    this.isAuthenticated,
    this.onProceedToContact,
    this.onRequireAuth,
    this.confirmButtonText,
    this.createReservationOnConfirm = false,
    this.bookingService,
    this.currentUserId,
    this.enableContactStep = false,
    this.onContactSubmitted,
  });

  @override
  State<ReservationFlowView> createState() => _ReservationFlowViewState();
}

class _ReservationFlowViewState extends State<ReservationFlowView> {
  late final ReservationDraftViewModel _viewModel;
  late final bool _isExternalViewModel;
  late final AuthService _authService;
  bool _isProcessing = false;

  bool get _isAuthenticated =>
      widget.isAuthenticated ?? (_authService.currentUser != null);

  AvailabilityService? _availability;

  AvailabilityService get _availabilityService => _availability ??=
      widget.availabilityService ??
      AvailabilityService(ReservationService(), tables: TableService());

  ReservationBookingService? _booking;

  ReservationBookingService get _bookingService => _booking ??=
      widget.bookingService ??
      ReservationBookingService(_availabilityService, ReservationService());

  /// Cambia cuando la selección se invalida para recargar los pasos de mesa y horario.
  int _stepReload = 0;

  // Mes visible en el selector de calendario
  late DateTime _visibleMonth;

  // Paleta de colores institucional
  static const Color terracotta = Color(0xFFB34A26);
  static const Color creamBg = Color(0xFFFAF6F0);
  static const Color darkText = Color(0xFF2E241E);
  static const Color mutedText = Color(0xFF7A6E65);
  static const Color cardBorder = Color(0xFFEDE4D8);
  static const Color creamAccent = Color(0xFFF3ECE1);

  @override
  void initState() {
    super.initState();
    _isExternalViewModel = widget.viewModel != null;
    _authService = widget.authService ?? AuthService();
    _viewModel = widget.viewModel ??
        ReservationDraftViewModel(
          restaurant: widget.restaurant,
          restaurantService: widget.restaurantService ?? RestaurantService(),
          tableRepository: TableService(),
        );

    final now = _viewModel.clockNow;
    _visibleMonth = DateTime(now.year, now.month, 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
  }

  @override
  void dispose() {
    if (!_isExternalViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  void _handleBack() {
    if (_viewModel.currentStep > 0) {
      // Retrocede en el flujo conservando los datos ya elegidos (HU07-RF01)
      _viewModel.previousStep();
    } else {
      // Salir del flujo descarta el borrador (HU07-RF01)
      _viewModel.discardDraft();
      Navigator.of(context).pop();
    }
  }

  void _confirmCancelFlow() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar reserva?'),
        content: const Text(
          'Si sales ahora se perderán los datos elegidos para este borrador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continuar reserva'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: terracotta),
            onPressed: () {
              Navigator.of(ctx).pop();
              _viewModel.discardDraft();
              Navigator.of(context).pop();
            },
            child: const Text('Descartar y salir'),
          ),
        ],
      ),
    );
  }

  void _mostrarResumenBorradorFinal() {
    final draft = _viewModel.draft;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Color(0xFF2E7D32), size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Borrador guardado!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      Text(
                        'Pasos 1 al 5 completados con éxito',
                        style: TextStyle(fontSize: 13, color: mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: creamBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    icon: Icons.storefront,
                    label: 'Restaurante',
                    value: draft.restaurant.nombre,
                  ),
                  const Divider(height: 18),
                  _buildSummaryRow(
                    icon: Icons.location_on_outlined,
                    label: 'Sucursal',
                    value: draft.branch?.nombre ?? 'Sin especificar',
                  ),
                  const Divider(height: 18),
                  _buildSummaryRow(
                    icon: Icons.calendar_today,
                    label: 'Fecha de visita',
                    value: draft.formattedDate,
                  ),
                  const Divider(height: 18),
                  _buildSummaryRow(
                    icon: Icons.timer_outlined,
                    label: 'Duración',
                    value: draft.formattedDuration,
                  ),
                  const Divider(height: 18),
                  _buildSummaryRow(
                    icon: Icons.people_outline,
                    label: 'Cantidad',
                    value: '${draft.personas} personas',
                  ),
                  const Divider(height: 18),
                  _buildSummaryRow(
                    icon: Icons.table_restaurant_outlined,
                    label: draft.mesaIds.length > 1 ? 'Mesas' : 'Mesa',
                    value: draft.mesasNombres.join(' + '),
                  ),
                  const Divider(height: 18),
                  _buildSummaryRow(
                    icon: Icons.schedule,
                    label: 'Horario',
                    value: draft.formattedTimeRange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nota: El paso 6 (Datos) se integrará en la siguiente etapa del flujo.',
              style: TextStyle(fontSize: 12, color: mutedText, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Modificar datos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('btn_cerrar_resumen_borrador'),
                    style: FilledButton.styleFrom(
                      backgroundColor: terracotta,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Entendido'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: terracotta),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: mutedText),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          final step = _viewModel.currentStep;

          return Scaffold(
            backgroundColor: creamBg,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      // Encabezado
                      if (step == 0)
                        _buildStep0Header()
                      else
                        _buildStepperBar(step),

                      // Contenido según el paso
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: _buildCurrentStepContent(step),
                        ),
                      ),

                      // Barra inferior de acción
                      _buildBottomActionBar(step),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ENCABEZADOS Y STEPPER BAR
  // ---------------------------------------------------------------------------
  Widget _buildStep0Header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          InkWell(
            key: const ValueKey('btn_back_step0'),
            onTap: _handleBack,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: creamAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: darkText, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Haz tu reserva',
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'serif',
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Cancelar reserva',
            icon: const Icon(Icons.close, color: mutedText),
            onPressed: _confirmCancelFlow,
          ),
        ],
      ),
    );
  }

  Widget _buildStepperBar(int currentStep) {
    // HU13-RF01: el stepper incluye el paso "Datos" al final.
    final steps = [
      'Fecha',
      'Duración',
      'Personas',
      'Mesa',
      'Horario',
      'Resumen',
      'Datos',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                key: const ValueKey('btn_stepper_back'),
                onTap: _handleBack,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: creamAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: darkText, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(steps.length, (idx) {
                    final stepNumber = idx + 1;
                    final isCompleted = currentStep > stepNumber;
                    final isActive = currentStep == stepNumber;
                    final hasNextLine = idx < steps.length - 1;

                    return Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: isCompleted ? () => _viewModel.goToStep(stepNumber) : null,
                                borderRadius: BorderRadius.circular(13),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: (isActive || isCompleted)
                                        ? terracotta
                                        : creamAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: isCompleted
                                      ? const Icon(Icons.check,
                                          size: 15, color: Colors.white)
                                      : Text(
                                          '$stepNumber',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? Colors.white
                                                : mutedText,
                                          ),
                                        ),
                                ),
                              ),
                              if (hasNextLine)
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    color: currentStep > stepNumber
                                        ? terracotta
                                        : Colors.grey.shade300,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 32,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                steps[idx],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: (isActive || isCompleted)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: (isActive || isCompleted)
                                      ? terracotta
                                      : mutedText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENIDO DE CADA PASO
  // ---------------------------------------------------------------------------
  Widget _buildCurrentStepContent(int step) {
    switch (step) {
      case 0:
        return _buildStep0BranchSelection();
      case 1:
        return _buildStep1FechaSelection();
      case 2:
        return _buildStep2DuracionSelection();
      case 3:
        return _buildStep3PersonasSelection();
      case 4:
        return _buildStep4MesaSelection();
      case 5:
        return _buildStep5HorarioSelection();
      case 6:
        return _buildStep6ResumenSelection();
      case 7:
        return _buildStep7Contacto();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep6ResumenSelection() {
    final draft = _viewModel.draft;
    return ReservationSummaryStep(
      key: ValueKey(
        'step_resumen_${draft.fecha}_${draft.duracionMin}_${draft.personas}_${draft.mesaIds.join(',')}_${draft.horario?.hour}_${draft.horario?.minute}',
      ),
      draft: draft,
      onEditStep: _viewModel.goToStep,
      onConfirm: _handleConfirmOrContinue,
      isProcessing: _isProcessing,
      // Con el paso de contacto activo, el visitante sin sesión también avanza a Datos (HU13).
      isAuthenticated: _isAuthenticated || widget.enableContactStep,
      onRequireAuth: _handleRequireAuth,
      confirmButtonText: widget.confirmButtonText,
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 7: DATOS DE CONTACTO (HU13-RF01, HU13-RF02, HU14-RF01)
  // ---------------------------------------------------------------------------
  Widget _buildStep7Contacto() {
    final draft = _viewModel.draft;
    return ContactFormStep(
      key: const ValueKey('step_contacto'),
      draft: draft,
      isAuthenticated: _isAuthenticated,
      initialPassword: _viewModel.password,
      initialConfirmPassword: _viewModel.confirmPassword,
      onNameChanged: _viewModel.setContactName,
      onEmailChanged: _viewModel.setContactEmail,
      onPhoneChanged: _viewModel.setContactPhone,
      onCreateAccountChanged: _viewModel.setCreateAccount,
      onPasswordChanged: _viewModel.setPassword,
      onConfirmPasswordChanged: _viewModel.setConfirmPassword,
      phoneDigits: _viewModel.phoneDigits,
    );
  }

  /// HU13-RF01: si hay sesión, prellena los campos (siguen siendo editables)
  /// y abre el paso de datos.
  void _goToContactStep() {
    final user = _authService.currentUser;
    if (_isAuthenticated) {
      _viewModel.setCreateAccount(false);
      _viewModel.prefillContact(
        nombre: user?.displayName,
        correo: user?.email,
        telefono: user?.phoneNumber, // ajusta si tu UserModel guarda el teléfono en Firestore
      );
    }
    _viewModel.goToStep(7);
  }

  /// Entrega el borrador (y la contraseña solo si pidió cuenta) al llamador.
  void _submitContact() {
    if (!_viewModel.canContinueFromContact) return;
    final draft = _viewModel.draft;
    final password = draft.crearCuenta ? _viewModel.password : null;
    if (widget.onContactSubmitted != null) {
      widget.onContactSubmitted!(draft, password);
    } else {
      _showFlowMessage('Datos de contacto guardados.');
    }
  }

  void _handleRequireAuth() {
    if (widget.onRequireAuth != null) {
      widget.onRequireAuth!();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Para confirmar tu reserva necesitas iniciar sesión o registrarte. Tu borrador se conservará intacto.',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Iniciar sesión',
          onPressed: () {
            AuthModalDialog.show(context, initialMode: AuthMode.login);
          },
        ),
      ),
    );
    AuthModalDialog.show(context, initialMode: AuthMode.login);
  }

  // ---------------------------------------------------------------------------
  // HU12-RF02: revalidación antes del resumen · HU11-RF04: confirmación
  // ---------------------------------------------------------------------------
  void _showFlowMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('snack_flow_message'),
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: action,
        ),
      );
  }

  /// Antes de mostrar el resumen se comprueba que la mesa siga libre (HU12-RF02).
  Future<void> _revalidateThenAdvance() async {
    final draft = _viewModel.draft;
    final inicio = draft.inicio;
    if (inicio == null) return;

    setState(() => _isProcessing = true);
    try {
      final result = await _availabilityService.revalidateSelection(
        restaurant: widget.restaurant,
        inicio: inicio,
        duracionMin: draft.duracionMin,
        mesaIds: draft.mesaIds,
      );
      if (!mounted) return;
      if (result.isValid) {
        _viewModel.nextStep();
      } else {
        _redirectInvalidSelection(result);
      }
    } catch (_) {
      if (!mounted) return;
      _showFlowMessage(
        'No se pudo verificar la disponibilidad. Revisa tu conexión e intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Informa que la selección ya no es válida y vuelve al paso para elegir de nuevo.
  void _redirectInvalidSelection(SelectionValidation validation) {
    if (validation.redirectStep <= 4) {
      _viewModel.setSelectedTables(const []);
    } else {
      _viewModel.clearTime();
    }
    setState(() => _stepReload++);
    _viewModel.goToStep(validation.redirectStep);
    _showFlowMessage(validation.message ?? 'Elige de nuevo tu selección.');
  }

  /// Guarda la reserva y muestra la confirmación (HU11-RF04).
  Future<void> _bookReservation() async {
    setState(() => _isProcessing = true);
    try {
      final user = _authService.currentUser;
      final result = await _bookingService.confirm(
        restaurant: widget.restaurant,
        draft: _viewModel.draft,
        usuarioId: widget.currentUserId ?? user?.uid ?? '',
        contactoNombre: user?.displayName ?? '',
        contactoCorreo: user?.email ?? '',
      );
      if (!mounted) return;

      switch (result) {
        case BookingConfirmed(:final reservation):
          _viewModel.discardDraft();
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReservationConfirmationView(reservation: reservation),
            ),
          );
        case BookingConflict():
          // Se libera el botón antes de abrir el diálogo para no dejar el spinner activo.
          setState(() => _isProcessing = false);
          await _showConflictDialog(result);
        case BookingRejected(:final validation):
          _redirectInvalidSelection(validation);
        case BookingFailed(:final message, :final retryable):
          _showFlowMessage(
            message,
            action: retryable
                ? SnackBarAction(label: 'Reintentar', onPressed: _bookReservation)
                : null,
          );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Otra persona reservó la mesa: se ofrecen horarios alternativos (HU11-RF04).
  Future<void> _showConflictDialog(BookingConflict conflict) async {
    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final slot = await showDialog<TimeSlot>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('booking_conflict_dialog'),
        title: const Text('Esa mesa ya fue reservada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conflict.message),
            if (conflict.alternativas.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Horarios disponibles para tu mesa:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in conflict.alternativas)
                    ActionChip(
                      key: ValueKey('alt_slot_${hhmm(s.inicio).replaceAll(':', '')}'),
                      label: Text('${hhmm(s.inicio)} – ${hhmm(s.fin)}'),
                      onPressed: () => Navigator.of(ctx).pop(s),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('btn_conflict_other_table'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Elegir otra mesa'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (slot != null) {
      _viewModel.selectTime(slot);
      setState(() => _stepReload++);
      _viewModel.goToStep(6);
    } else {
      _viewModel.setSelectedTables(const []);
      setState(() => _stepReload++);
      _viewModel.goToStep(4);
    }
  }

  Future<void> _handleConfirmOrContinue() async {
    // HU13: con el paso de contacto activo (y sin callback propio), el resumen
    // lleva al formulario de datos, con o sin sesión iniciada.
    if (widget.enableContactStep && widget.onProceedToContact == null) {
      _goToContactStep();
      return;
    }

    if (!_isAuthenticated) {
      _handleRequireAuth();
      return;
    }

    if (widget.onProceedToContact == null && widget.createReservationOnConfirm) {
      await _bookReservation();
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // HU12-RF01 Criterio 5: La pantalla es de solo confirmación; no crea la reserva todavía.
      // HU11-RF03 Criterio 4: Se deshabilita mientras se procesa para evitar dobles envíos.
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      if (widget.onProceedToContact != null) {
        widget.onProceedToContact!(_viewModel.draft);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: ValueKey('snack_continuar_contacto'),
            content: Text('Avanzando al paso de datos de contacto (HU13)...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PASO 4: MESA (HU09-RF03, HU10-RF02/03/04) Y PASO 5: HORARIO (HU11-RF02)
  // ---------------------------------------------------------------------------
  Widget _buildStep4MesaSelection() {
    final draft = _viewModel.draft;
    return TableSelectionStep(
      key: ValueKey(
        'step_mesas_${draft.fecha}_${draft.duracionMin}_${draft.personas}_$_stepReload',
      ),
      restaurant: widget.restaurant,
      availability: _availabilityService,
      fecha: draft.fecha!,
      personas: draft.personas,
      duracionMin: draft.duracionMin,
      initialSelectedIds: draft.mesaIds,
      onSelectionChanged: _viewModel.setSelectedTables,
      onChangeStep: _viewModel.goToStep,
    );
  }

  Widget _buildStep5HorarioSelection() {
    final draft = _viewModel.draft;
    return TimeSlotStep(
      key: ValueKey(
        'step_horario_${draft.fecha}_${draft.duracionMin}_${draft.mesaIds.join(',')}_$_stepReload',
      ),
      restaurant: widget.restaurant,
      availability: _availabilityService,
      fecha: draft.fecha!,
      duracionMin: draft.duracionMin,
      mesaIds: draft.mesaIds,
      mesasNombres: draft.mesasNombres,
      initialInicio: draft.inicio,
      onSelected: _viewModel.selectTime,
      onChangeStep: _viewModel.goToStep,
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 0: SELECCIÓN DE SUCURSAL
  // ---------------------------------------------------------------------------
  Widget _buildStep0BranchSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner con imagen y texto
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF332219),
            image: widget.restaurant.imagenPrincipalUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(widget.restaurant.imagenPrincipalUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withAlpha(120),
                      BlendMode.darken,
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.all(20),
          alignment: Alignment.centerLeft,
          child: const Text(
            'Elige cuándo quieres visitarnos y nosotros nos encargamos del resto.',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'serif',
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Título de la sección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'SELECCIONA UNA SUCURSAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF8C6E53),
              ),
            ),
            Text(
              'Requerido',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC64E24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Listado de sucursales
        if (_viewModel.isLoadingBranches)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: terracotta),
            ),
          )
        else
          ..._viewModel.branches.map((b) => _buildBranchCard(b)),

        const SizedBox(height: 20),

        // 3 Tarjetas informativas del flujo
        _buildInfoCard(
          icon: Icons.calendar_month_outlined,
          iconColor: Colors.blue.shade400,
          title: 'Selecciona fecha y duración',
          subtitle: 'Elige el día y cuánto tiempo planeas quedarte.',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.chair_outlined,
          iconColor: terracotta,
          title: 'Elige tu mesa',
          subtitle: 'Visualiza el restaurante y selecciona la mesa ideal para tu grupo.',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.check_box_outlined,
          iconColor: const Color(0xFF2E7D32),
          title: 'Confirmación inmediata',
          subtitle: 'Recibirás la confirmación por correo en segundos.',
        ),
      ],
    );
  }

  Widget _buildBranchCard(BranchModel branch) {
    final isSelected = _viewModel.draft.branch?.id == branch.id;
    final initials = branch.nombre.length >= 2
        ? branch.nombre.substring(0, 2)
        : 'Su';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: ValueKey('branch_card_${branch.id}'),
        onTap: () => _viewModel.selectBranch(branch),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? darkText : cardBorder,
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar con iniciales
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? terracotta : creamAccent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : terracotta,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Datos de la sucursal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.nombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      branch.direccion,
                      style: const TextStyle(fontSize: 12, color: mutedText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Tag Abierto / Cerrado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Abierto',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),

              if (isSelected) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: terracotta,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 1: SELECTOR DE FECHA (HU07-RF02)
  // ---------------------------------------------------------------------------
  Widget _buildStep1FechaSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          '¿Qué día quieres visitarnos?',
          style: TextStyle(
            fontSize: 22,
            fontFamily: 'serif',
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
        const SizedBox(height: 20),

        // Calendario personalizado en tarjeta blanca
        _buildCalendarCard(),

        const SizedBox(height: 24),

        // Acceso rápido
        const Text(
          'ACCESO RÁPIDO',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF8C6E53),
          ),
        ),
        const SizedBox(height: 10),
        _buildQuickAccessChips(),

        const SizedBox(height: 20),

        // Contenedor de fecha elegida
        if (_viewModel.draft.fecha != null) ...[
          Container(
            key: const ValueKey('caja_fecha_elegida'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF7F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _viewModel.isDateSelectable(_viewModel.draft.fecha!)
                    ? const Color(0xFFE89375)
                    : Colors.red.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: _viewModel.isDateSelectable(_viewModel.draft.fecha!)
                      ? terracotta
                      : Colors.red.shade700,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _viewModel.draft.formattedDate,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _viewModel.isDateSelectable(_viewModel.draft.fecha!)
                          ? terracotta
                          : Colors.red.shade700,
                    ),
                  ),
                ),
                if (!_viewModel.isDateSelectable(_viewModel.draft.fecha!))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Cerrado',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Abierto',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCalendarCard() {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final mesNombre = meses[_visibleMonth.month - 1];
    final year = _visibleMonth.year;

    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // En Dart weekday 1=Lunes, 7=Domingo
    final startWeekday = firstDayOfMonth.weekday; // 1 to 7

    final now = _viewModel.clockNow;
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Navegador de Mes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const ValueKey('btn_mes_anterior'),
                icon: const Icon(Icons.chevron_left, color: terracotta),
                onPressed: () {
                  setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              Text(
                '$mesNombre $year',
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              IconButton(
                key: const ValueKey('btn_mes_siguiente'),
                icon: const Icon(Icons.chevron_right, color: terracotta),
                onPressed: () {
                  setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                      1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Días de la semana (L, M, X, J, V, S, D)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _WeekdayHeader('L'),
              _WeekdayHeader('M'),
              _WeekdayHeader('X'),
              _WeekdayHeader('J'),
              _WeekdayHeader('V'),
              _WeekdayHeader('S'),
              _WeekdayHeader('D'),
            ],
          ),
          const SizedBox(height: 12),

          // Rejilla de días
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (startWeekday - 1) + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (index < startWeekday - 1) {
                return const SizedBox.shrink();
              }

              final dayNum = index - (startWeekday - 1) + 1;
              final dayDate = DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
              final isSelectable = _viewModel.isDateSelectable(dayDate);

              final isToday = dayDate.year == today.year &&
                  dayDate.month == today.month &&
                  dayDate.day == today.day;

              final isSelected = _viewModel.draft.fecha != null &&
                  _viewModel.draft.fecha!.year == dayDate.year &&
                  _viewModel.draft.fecha!.month == dayDate.month &&
                  _viewModel.draft.fecha!.day == dayDate.day;

              final isPast = dayDate.isBefore(today);
              final isWithinMax = !dayDate.isAfter(today.add(const Duration(days: 60)));

              return InkWell(
                key: ValueKey('cal_day_${dayDate.year}_${dayDate.month}_$dayNum'),
                onTap: (isPast || !isWithinMax)
                    ? null
                    : () {
                        setState(() {
                          _visibleMonth = DateTime(dayDate.year, dayDate.month, 1);
                        });
                        _viewModel.selectDate(dayDate);
                        if (!isSelectable) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'El restaurante no tiene servicio programado para esta fecha. Elige un día abierto para continuar.',
                              ),
                              duration: Duration(seconds: 3),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? terracotta
                        : (isToday ? creamAccent : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: (isSelected || isToday)
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isSelectable
                              ? (isToday ? terracotta : darkText)
                              : Colors.grey.shade300),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessChips() {
    final now = _viewModel.clockNow;
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final quickOptions = <Map<String, dynamic>>[];

    // 1. Opciones inmediatas: Hoy y Mañana
    quickOptions.add({'label': 'Hoy', 'date': today});
    quickOptions.add({'label': 'Mañana', 'date': tomorrow});

    // 2. Próximos días abiertos del restaurante (hasta 4 días adicionales)
    final existingDates = {
      '${today.year}-${today.month}-${today.day}',
      '${tomorrow.year}-${tomorrow.month}-${tomorrow.day}',
    };
    for (int i = 2; i < 30; i++) {
      if (quickOptions.length >= 6) break;
      final cand = today.add(Duration(days: i));
      final key = '${cand.year}-${cand.month}-${cand.day}';
      if (!existingDates.contains(key) && _viewModel.isDateSelectable(cand)) {
        existingDates.add(key);
        final diaSemana = _diaAbrev(cand.weekday);
        final mesStr = _mesAbrev(cand.month);
        quickOptions.add({
          'label': '$diaSemana ${cand.day} $mesStr',
          'date': cand,
        });
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: quickOptions.map((opt) {
          final date = opt['date'] as DateTime;
          final isSelectable = _viewModel.isDateSelectable(date);
          final isSelected = _viewModel.draft.fecha != null &&
              _viewModel.draft.fecha!.year == date.year &&
              _viewModel.draft.fecha!.month == date.month &&
              _viewModel.draft.fecha!.day == date.day;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              key: ValueKey('chip_rapido_${opt['label']}'),
              onTap: () {
                setState(() {
                  _visibleMonth = DateTime(date.year, date.month, 1);
                });
                _viewModel.selectDate(date);
                if (!isSelectable) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'El restaurante no tiene servicio programado para esta fecha. Elige un día abierto para continuar.',
                      ),
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? terracotta
                      : creamAccent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? darkText : cardBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : darkText,
                      ),
                    ),
                    if (!isSelectable) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• Cerrado',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white70 : Colors.red.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _diaAbrev(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lun';
      case DateTime.tuesday:
        return 'Mar';
      case DateTime.wednesday:
        return 'Mié';
      case DateTime.thursday:
        return 'Jue';
      case DateTime.friday:
        return 'Vie';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
        return 'Dom';
      default:
        return '';
    }
  }

  String _mesAbrev(int mes) {
    const abrevs = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return abrevs[mes - 1];
  }

  // ---------------------------------------------------------------------------
  // PASO 2: SELECTOR DE DURACIÓN (HU08-RF01)
  // ---------------------------------------------------------------------------
  Widget _buildStep2DuracionSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          '¿Cuánto tiempo planeas quedarte?',
          style: TextStyle(
            fontSize: 22,
            fontFamily: 'serif',
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
        const SizedBox(height: 16),

        // Banner informativo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: creamAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'La duración nos ayuda a calcular la disponibilidad de las mesas. No tiene ningún costo adicional.',
            style: TextStyle(
              fontSize: 13,
              color: mutedText,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Opciones de duración
        ...ReservationDraftViewModel.duracionesDisponibles.map((minutos) {
          final isSelected = _viewModel.draft.duracionMin == minutos;
          final isSugerida = minutos == ReservationDraftViewModel.duracionPorDefectoMin;

          final label = _formatearDuracionTexto(minutos);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              key: ValueKey('duracion_opcion_$minutos'),
              onTap: () => _viewModel.selectDuration(minutos),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? terracotta : cardBorder,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: darkText, size: 22),
                    const SizedBox(width: 14),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    if (isSugerida) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: terracotta.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sugerido',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: terracotta,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: terracotta,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatearDuracionTexto(int minutos) {
    final horas = minutos ~/ 60;
    final mins = minutos % 60;
    if (horas > 0 && mins > 0) {
      return '$horas ${horas == 1 ? "hora" : "horas"} $mins min';
    } else {
      return '$horas ${horas == 1 ? "hora" : "horas"}';
    }
  }

  // ---------------------------------------------------------------------------
  // PASO 3: SELECTOR DE PERSONAS (HU09-RF01)
  // ---------------------------------------------------------------------------
  Widget _buildStep3PersonasSelection() {
    final personas = _viewModel.draft.personas;
    final maxPeople = _viewModel.maxPartySize;
    final minPeople = _viewModel.minPartySize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          '¿Para cuántas personas?',
          style: TextStyle(
            fontSize: 22,
            fontFamily: 'serif',
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
        const SizedBox(height: 20),

        // Tarjeta central del Stepper Numérico
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón Menos
              InkWell(
                key: const ValueKey('stepper_btn_minus'),
                onTap: personas > minPeople
                    ? () => _viewModel.decrementPartySize()
                    : null,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: personas > minPeople ? creamAccent : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.remove,
                    color: personas > minPeople ? terracotta : Colors.grey.shade400,
                    size: 26,
                  ),
                ),
              ),

              // Número central destacado
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$personas',
                    key: const ValueKey('texto_contador_personas'),
                    style: const TextStyle(
                      fontSize: 54,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.bold,
                      color: darkText,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'personas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: mutedText,
                    ),
                  ),
                ],
              ),

              // Botón Más
              InkWell(
                key: const ValueKey('stepper_btn_plus'),
                onTap: personas < maxPeople
                    ? () => _viewModel.incrementPartySize()
                    : null,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: personas < maxPeople ? terracotta : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Rangos sugeridos
        const Text(
          'RANGOS SUGERIDOS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF8C6E53),
          ),
        ),
        const SizedBox(height: 12),

        _buildSuggestedRangeCard(label: '1–2 personas', minR: 1, maxR: 2, targetVal: 2),
        const SizedBox(height: 8),
        _buildSuggestedRangeCard(label: '3–4 personas', minR: 3, maxR: 4, targetVal: 4),
        const SizedBox(height: 8),
        _buildSuggestedRangeCard(label: '5–6 personas', minR: 5, maxR: 6, targetVal: 6),
        const SizedBox(height: 8),
        _buildSuggestedRangeCard(label: '7–8 personas', minR: 7, maxR: 8, targetVal: 8),
        const SizedBox(height: 8),
        _buildSuggestedRangeCard(label: '9+ personas', minR: 9, maxR: 99, targetVal: 10),
      ],
    );
  }

  Widget _buildSuggestedRangeCard({
    required String label,
    required int minR,
    required int maxR,
    required int targetVal,
  }) {
    final personas = _viewModel.draft.personas;
    final isSelected = personas >= minR && personas <= maxR;

    return InkWell(
      key: ValueKey('rango_sugerido_${minR}_$maxR'),
      onTap: () => _viewModel.setPartySize(targetVal),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : creamAccent.withAlpha(140),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? terracotta : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? terracotta : darkText,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 18, color: terracotta),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA INFERIOR DE ACCIÓN (CONTINUAR / COMENZAR)
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionBar(int step) {
    final canAdvance = _viewModel.canAdvanceCurrentStep;

    if (step == 0) {
      // Paso 0: Botón Comenzar
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        decoration: BoxDecoration(
          color: creamBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canAdvance) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE89375)),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Selecciona una sucursal para continuar',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB34A26),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('btn_comenzar_reserva'),
                style: FilledButton.styleFrom(
                  backgroundColor: canAdvance ? terracotta : const Color(0xFFE6DACB),
                  foregroundColor: canAdvance ? Colors.white : const Color(0xFF8A7B6D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: canAdvance ? 2 : 0,
                ),
                onPressed: canAdvance ? () => _viewModel.nextStep() : null,
                child: const Text(
                  'Comenzar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Pasos 1 a 7: Botón Continuar / Ver mesas disponibles / Confirmar reserva
    final isSummaryStep = step == 6;
    final buttonText = step == 3
        ? 'Ver mesas disponibles'
        : (isSummaryStep
            ? (widget.confirmButtonText ?? 'Confirmar reserva')
            : 'Continuar');

    final filledButton = FilledButton(
      key: isSummaryStep
          ? const ValueKey('btn_confirmar_reserva')
          : ValueKey('btn_continuar_step_$step'),
      style: FilledButton.styleFrom(
        backgroundColor: (canAdvance && !_isProcessing)
            ? terracotta
            : const Color(0xFFE6DACB),
        foregroundColor: (canAdvance && !_isProcessing)
            ? Colors.white
            : const Color(0xFF8A7B6D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: (canAdvance && !_isProcessing) ? 2 : 0,
      ),
      onPressed: (canAdvance && !_isProcessing)
          ? () {
              if (step == 5) {
                _revalidateThenAdvance();
              } else if (step == 7) {
                _submitContact();
              } else if (step < 6) {
                _viewModel.nextStep();
              } else {
                _handleConfirmOrContinue();
              }
            }
          : null,
      child: _isProcessing
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                if (buttonText != 'Continuar')
                  const Opacity(
                    opacity: 0.0,
                    child: Text('Continuar'),
                  ),
                if (buttonText != 'Confirmar reserva')
                  const Opacity(
                    opacity: 0.0,
                    child: Text('Confirmar reserva'),
                  ),
                Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: creamBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: isSummaryStep
            ? KeyedSubtree(
                key: const ValueKey('btn_continuar_step_6'),
                child: KeyedSubtree(
                  key: const ValueKey('btn_continuar_resumen'),
                  child: filledButton,
                ),
              )
            : filledButton,
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8C6E53),
        ),
      ),
    );
  }
}