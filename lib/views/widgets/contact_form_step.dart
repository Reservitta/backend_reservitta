import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/reservation_draft_model.dart';
import '../../utils/validators.dart';

/// Paso 7: Formulario de datos de contacto y creación de cuenta (HU13-RF01,
/// HU13-RF02, HU14-RF01).
///
/// Campos:
///  - Nombre completo, correo electrónico y teléfono (HU13-RF01)
///  - Checkbox "Quiero crear una cuenta" (HU13-RF02), oculto con sesión iniciada
///  - Contraseña + Confirmar contraseña, solo si el checkbox está marcado (HU14-RF01)
///
/// La validez del formulario la calcula el ViewModel (`canContinueFromContact`),
/// y el botón "Continuar" de la barra inferior lo maneja [ReservationFlowView].
/// Este widget solo muestra el estado y reporta cambios mediante callbacks.
class ContactFormStep extends StatefulWidget {
  final ReservationDraftModel draft;

  /// Si el visitante ya tiene sesión iniciada se oculta el checkbox de crear
  /// cuenta y los campos de contraseña (HU13-RF02).
  final bool isAuthenticated;

  /// Dígitos exigidos al teléfono (HU13-RF01, configurable).
  final int phoneDigits;

  /// Valores en memoria de las contraseñas (no viven en el borrador).
  final String initialPassword;
  final String initialConfirmPassword;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<bool> onCreateAccountChanged;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onConfirmPasswordChanged;

  const ContactFormStep({
    super.key,
    required this.draft,
    required this.isAuthenticated,
    required this.onNameChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onCreateAccountChanged,
    required this.onPasswordChanged,
    required this.onConfirmPasswordChanged,
    this.phoneDigits = 10,
    this.initialPassword = '',
    this.initialConfirmPassword = '',
  });

  static const Color terracotta = Color(0xFFB34A26);
  static const Color creamBg = Color(0xFFFAF6F0);
  static const Color darkText = Color(0xFF2E241E);
  static const Color mutedText = Color(0xFF7A6E65);
  static const Color cardBorder = Color(0xFFEDE4D8);
  static const Color creamAccent = Color(0xFFF3ECE1);

  @override
  State<ContactFormStep> createState() => _ContactFormStepState();
}

class _ContactFormStepState extends State<ContactFormStep> {
  final _formKey = GlobalKey<FormState>();
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _correoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  bool _mostrarPassword = false;
  bool _mostrarConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _nombreCtrl = TextEditingController(text: d.contactoNombre);
    _correoCtrl = TextEditingController(text: d.contactoCorreo);
    _telefonoCtrl = TextEditingController(text: d.contactoTelefono);
    _passwordCtrl = TextEditingController(text: widget.initialPassword);
    _confirmPasswordCtrl =
        TextEditingController(text: widget.initialConfirmPassword);
  }

  @override
  void didUpdateWidget(covariant ContactFormStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el ViewModel cambia un valor (prellenado de sesión o descarte),
    // se refleja en el campo sin pisar lo que el usuario está escribiendo.
    _sync(_nombreCtrl, widget.draft.contactoNombre);
    _sync(_correoCtrl, widget.draft.contactoCorreo);
    _sync(_telefonoCtrl, widget.draft.contactoTelefono);

    // HU14-RF01: al desmarcar el checkbox, se descartan las contraseñas.
    if (!widget.draft.crearCuenta) {
      _sync(_passwordCtrl, '');
      _sync(_confirmPasswordCtrl, '');
    }
  }

  void _sync(TextEditingController c, String value) {
    if (c.text != value) c.text = value;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final showAccountOption = !widget.isAuthenticated; // HU13-RF02 criterio 2
    final showPasswords = widget.showPasswordFields && showAccountOption && widget.draft.crearCuenta;
    final phoneExample = '4181234567'
        .padRight(widget.phoneDigits, '0')
        .substring(0, widget.phoneDigits);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Encabezado
          const Text(
            '¿Cómo te contactamos?',
            style: TextStyle(
              fontSize: 22,
              fontFamily: 'serif',
              fontWeight: FontWeight.bold,
              color: ContactFormStep.darkText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Completa tus datos de contacto para confirmar la reserva.',
            style: TextStyle(fontSize: 13, color: ContactFormStep.mutedText),
          ),
          const SizedBox(height: 24),

          // Tarjeta de campos
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ContactFormStep.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Nombre completo ──────────────────────────────────────────
                _buildSectionLabel('Nombre completo'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('input_contact_nombre'),
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Ej. María López García',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: AppValidators.validateName,
                  onChanged: widget.onNameChanged,
                ),
                const SizedBox(height: 18),

                // ── Correo electrónico ───────────────────────────────────────
                _buildSectionLabel('Correo electrónico'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('input_contact_correo'),
                  controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Ej. maria@correo.com',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: AppValidators.validateEmail,
                  onChanged: widget.onEmailChanged,
                ),
                const SizedBox(height: 18),

                // ── Teléfono ─────────────────────────────────────────────────
                _buildSectionLabel('Teléfono (${widget.phoneDigits} dígitos)'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('input_contact_telefono'),
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: widget.phoneDigits,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration(
                    hint: 'Ej. $phoneExample',
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: (v) => AppValidators.validatePhone(
                    v,
                    digits: widget.phoneDigits,
                  ),
                  onChanged: widget.onPhoneChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Checkbox: Crear cuenta (HU13-RF02) ──────────────────────────────
          if (showAccountOption) ...[
            _buildCreateAccountCheckbox(),
            const SizedBox(height: 12),
          ],

          // ── Campos de contraseña (HU14-RF01) ────────────────────────────────
          if (showPasswords) ...[
            _buildPasswordSection(),
            const SizedBox(height: 12),
          ],

          // Aviso de privacidad
          _buildPrivacyNotice(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHECKBOX — Crear cuenta (HU13-RF02)
  // ---------------------------------------------------------------------------
  void _handleCheckboxChanged(bool? value) {
    final checked = value ?? false;
    if (!checked) {
      _passwordCtrl.clear();
      _confirmPasswordCtrl.clear();
      widget.onPasswordChanged?.call('');
      widget.onConfirmPasswordChanged?.call('');
    }
    widget.onCreateAccountChanged(checked);
  }

  Widget _buildCreateAccountCheckbox() {
    return Container(
      key: const ValueKey('container_crear_cuenta'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ContactFormStep.cardBorder),
      ),
      child: CheckboxListTile(
        key: const ValueKey('checkbox_crear_cuenta'),
        value: widget.draft.crearCuenta,
        // Marcarlo no agrega campos aquí; las contraseñas aparecen abajo (HU14).
        // Al desmarcar, el ViewModel descarta las contraseñas y didUpdateWidget
        // vacía los campos.
        onChanged: _handleCheckboxChanged,
        activeColor: ContactFormStep.terracotta,
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        title: const Text(
          'Quiero crear una cuenta para guardar mis reservas',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ContactFormStep.darkText,
          ),
        ),
        subtitle: const Text(
          'Podrás ver el historial de tus reservas en cualquier momento.',
          style: TextStyle(fontSize: 12, color: ContactFormStep.mutedText),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECCIÓN DE CONTRASEÑA (HU14-RF01)
  // ---------------------------------------------------------------------------
  Widget _buildPasswordSection() {
    return Container(
      key: const ValueKey('container_password'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ContactFormStep.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ContactFormStep.terracotta.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: ContactFormStep.terracotta,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crea tu contraseña',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ContactFormStep.darkText,
                      ),
                    ),
                    Text(
                      'Mínimo 8 caracteres, una letra y un número.',
                      style: TextStyle(
                        fontSize: 12,
                        color: ContactFormStep.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Contraseña
          _buildSectionLabel('Contraseña'),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('input_password'),
            controller: _passwordCtrl,
            obscureText: !_mostrarPassword,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: 'Mínimo 8 caracteres',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarPassword ? Icons.visibility_off : Icons.visibility,
                  color: ContactFormStep.mutedText,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _mostrarPassword = !_mostrarPassword),
              ),
            ),
            validator: AppValidators.validateNewPassword,
            onChanged: (v) {
              widget.onPasswordChanged(v);
              // Revalida la confirmación cuando cambia la contraseña.
              if (_confirmPasswordCtrl.text.isNotEmpty) {
                _confirmFieldKey.currentState?.validate();
              }
            },
          ),
          const SizedBox(height: 18),

          // Confirmar contraseña
          _buildSectionLabel('Confirmar contraseña'),
          const SizedBox(height: 6),
          TextFormField(
            key: _confirmFieldKey,
            controller: _confirmPasswordCtrl,
            obscureText: !_mostrarConfirmPassword,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              hint: 'Repite tu contraseña',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: ContactFormStep.mutedText,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _mostrarConfirmPassword = !_mostrarConfirmPassword,
                ),
              ),
            ),
            validator: (v) =>
                AppValidators.validateConfirmPassword(_passwordCtrl.text, v),
            onChanged: widget.onConfirmPasswordChanged,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AVISO DE PRIVACIDAD
  // ---------------------------------------------------------------------------
  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ContactFormStep.creamBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ContactFormStep.cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: ContactFormStep.mutedText),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tus datos solo se usan para gestionar tu reserva y enviarte la confirmación. No los compartimos con terceros.',
              style: TextStyle(
                fontSize: 12,
                color: ContactFormStep.mutedText,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
        color: ContactFormStep.mutedText,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFFBBAAA0),
      ),
      prefixIcon: Icon(prefixIcon, color: ContactFormStep.mutedText, size: 20),
      suffixIcon: suffixIcon,
      counterText: '',
      filled: true,
      fillColor: ContactFormStep.creamBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ContactFormStep.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ContactFormStep.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: ContactFormStep.terracotta,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.8),
      ),
    );
  }
}