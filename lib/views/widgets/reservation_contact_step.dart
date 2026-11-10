import 'package:flutter/material.dart';
import '../../models/reservation_draft_model.dart';
import '../../services/contact_validation_service.dart';
import '../../viewmodels/reservation_contact_viewmodel.dart';
import '../../theme/app_theme.dart';

/// Paso / Modal para captura y validación temporal de datos de contacto (HU13-RF03)
///
/// Valida formato de correo y teléfono, verifica duplicados si solicita crear cuenta,
/// y guarda temporalmente en memoria en el borrador sin persistir en Firestore (HU11-RF04).
class ReservationContactStep extends StatefulWidget {
  final ReservationDraftModel draft;
  final void Function(ReservationDraftModel updatedDraft) onContactConfirmed;
  final VoidCallback? onBack;
  final ContactValidationService? validationService;

  static const Color terracotta = AppColors.marca;
  static const Color darkText = AppColors.texto;
  static const Color mutedText = AppColors.textoSuave;
  static const Color cardBorder = AppColors.divisor;
  static const Color creamBg = AppColors.fondo;

  const ReservationContactStep({
    super.key,
    required this.draft,
    required this.onContactConfirmed,
    this.onBack,
    this.validationService,
  });

  @override
  State<ReservationContactStep> createState() => _ReservationContactStepState();
}

class _ReservationContactStepState extends State<ReservationContactStep> {
  late final ReservationContactViewModel _viewModel;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _viewModel = ReservationContactViewModel(
      service: widget.validationService,
      initialDraft: widget.draft,
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final updatedDraft = await _viewModel.procesarYGuardarTemporal(widget.draft);
    if (updatedDraft != null && mounted) {
      widget.onContactConfirmed(updatedDraft);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              _buildHeader(),
              const SizedBox(height: 20),

              // Alerta de error general
              if (_viewModel.errorMessage != null) ...[
                _buildGeneralErrorBanner(_viewModel.errorMessage!),
                const SizedBox(height: 16),
              ],

              // Tarjeta contenedora de formulario
              _buildFormCard(),
              const SizedBox(height: 24),

              // Botones de acción
              _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ReservationContactStep.terracotta.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: ReservationContactStep.terracotta),
                  SizedBox(width: 4),
                  Text(
                    'Paso temporal (Sin persistencia)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ReservationContactStep.terracotta,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Datos de contacto',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: ReservationContactStep.darkText,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ingresa tus datos para recibir la confirmación de tu reserva.',
          style: TextStyle(fontSize: 13, color: ReservationContactStep.mutedText),
        ),
      ],
    );
  }

  Widget _buildGeneralErrorBanner(String message) {
    return Container(
      key: const ValueKey('banner_error_contacto'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ReservationContactStep.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo Nombre
          _buildTextField(
            key: const ValueKey('input_contacto_nombre'),
            controller: _viewModel.nombreController,
            label: 'Nombre completo *',
            hint: 'Ej. Juan Pérez',
            icon: Icons.person_outline,
            errorText: _viewModel.errorNombre,
          ),
          const SizedBox(height: 16),

          // Campo Correo
          _buildTextField(
            key: const ValueKey('input_contacto_correo'),
            controller: _viewModel.correoController,
            label: 'Correo electrónico *',
            hint: 'ejemplo@correo.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            errorText: _viewModel.errorCorreo,
          ),
          const SizedBox(height: 16),

          // Campo Teléfono
          _buildTextField(
            key: const ValueKey('input_contacto_telefono'),
            controller: _viewModel.telefonoController,
            label: 'Número de teléfono (10 dígitos) *',
            hint: '5512345678',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            errorText: _viewModel.errorTelefono,
          ),
          const SizedBox(height: 16),

          // Campo Notas / Alergias
          _buildTextField(
            key: const ValueKey('input_contacto_notas'),
            controller: _viewModel.notasController,
            label: 'Notas u observaciones (opcional)',
            hint: 'Alergias, motivo de celebración o requerimientos especiales',
            icon: Icons.edit_note_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Opción Crear Cuenta (Criterio 3)
          CheckboxListTile(
            key: const ValueKey('checkbox_crear_cuenta'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Quiero crear una cuenta con estos datos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ReservationContactStep.darkText,
              ),
            ),
            subtitle: const Text(
              'Podrás consultar tu historial y agilizar futuras reservas.',
              style: TextStyle(fontSize: 12, color: ReservationContactStep.mutedText),
            ),
            value: _viewModel.solicitaCrearCuenta,
            activeColor: ReservationContactStep.terracotta,
            onChanged: (val) {
              _viewModel.setSolicitaCrearCuenta(val ?? false);
            },
          ),

          // Campo Contraseña si solicita crear cuenta
          if (_viewModel.solicitaCrearCuenta) ...[
            const SizedBox(height: 12),
            _buildTextField(
              key: const ValueKey('input_contacto_password'),
              controller: _viewModel.passwordController,
              label: 'Contraseña para tu nueva cuenta *',
              hint: 'Mínimo 6 caracteres',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              errorText: _viewModel.errorPassword,
              suffixIcon: IconButton(
        tooltip: 'Mostrar u ocultar contraseña',
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? errorText,
    int? maxLength,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ReservationContactStep.darkText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: key,
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            prefixIcon: Icon(icon, size: 20, color: ReservationContactStep.mutedText),
            suffixIcon: suffixIcon,
            counterText: '',
            errorText: errorText,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ReservationContactStep.terracotta, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.onBack != null) ...[
          OutlinedButton(
            key: const ValueKey('btn_contacto_volver'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: Colors.grey.shade400),
            ),
            onPressed: _viewModel.isLoading ? null : widget.onBack,
            child: const Text('Volver', style: TextStyle(color: ReservationContactStep.darkText)),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: FilledButton(
            key: const ValueKey('btn_contacto_continuar'),
            style: FilledButton.styleFrom(
              backgroundColor: ReservationContactStep.terracotta,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _viewModel.isLoading ? null : _handleConfirm,
            child: _viewModel.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Guardar y continuar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}

