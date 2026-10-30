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
///  - Contraseña + Confirmar contraseña con restricciones visibles (HU14-RF01)
class ContactFormStep extends StatefulWidget {
  final ReservationDraftModel draft;

  /// Si el visitante ya tiene sesión iniciada se oculta el checkbox de crear
  /// cuenta y los campos de contraseña (HU13-RF02).
  final bool isAuthenticated;

  /// Dígitos exigidos al teléfono (HU13-RF01, configurable).
  final int phoneDigits;

  /// Controla si se muestran los campos de contraseña al marcar crear cuenta (HU14-RF01).
  final bool showPasswordFields;

  /// Valores en memoria de las contraseñas (no viven en el borrador).
  final String initialPassword;
  final String initialConfirmPassword;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<bool> onCreateAccountChanged;
  final ValueChanged<String>? onPasswordChanged;
  final ValueChanged<String>? onConfirmPasswordChanged;

  const ContactFormStep({
    super.key,
    required this.draft,
    required this.isAuthenticated,
    required this.onNameChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onCreateAccountChanged,
    this.onPasswordChanged,
    this.onConfirmPasswordChanged,
    this.showPasswordFields = true,
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
    _sync(_nombreCtrl, widget.draft.contactoNombre);
    _sync(_correoCtrl, widget.draft.contactoCorreo);
    _sync(_telefonoCtrl, widget.draft.contactoTelefono);

    // HU14-RF01: al desmarcar el checkbox, se descartan las contraseñas.
    if (!widget.draft.crearCuenta) {
      _sync(_passwordCtrl, '');
      _sync(_confirmPasswordCtrl, '');
    } else {
      if (widget.initialPassword != oldWidget.initialPassword) {
        _sync(_passwordCtrl, widget.initialPassword);
      }
      if (widget.initialConfirmPassword != oldWidget.initialConfirmPassword) {
        _sync(_confirmPasswordCtrl, widget.initialConfirmPassword);
      }
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
    final showPasswords = widget.showPasswordFields &&
        showAccountOption &&
        widget.draft.crearCuenta; // HU14-RF01
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
                // Nombre completo
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

                // Correo electrónico
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

                // Teléfono
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

          // Checkbox: Crear cuenta (HU13-RF02)
          if (showAccountOption) ...[
            _buildCreateAccountCheckbox(),
            const SizedBox(height: 12),
          ],

          // Campos de contraseña condicionados (HU14-RF01)
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: CheckboxListTile(
          key: const ValueKey('checkbox_crear_cuenta'),
          value: widget.draft.crearCuenta,
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECCIÓN DE CONTRASEÑA CONDICIONADA (HU14-RF01)
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
                      'Define tu contraseña para acceder a tus reservas.',
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

          // Campo Contraseña
          _buildSectionLabel('Contraseña'),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('input_password'),
            controller: _passwordCtrl,
            obscureText: !_mostrarPassword,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: 'Ingresa tu contraseña',
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
              setState(() {});
              widget.onPasswordChanged?.call(v);
              if (_confirmPasswordCtrl.text.isNotEmpty) {
                _confirmFieldKey.currentState?.validate();
              }
            },
          ),
          const SizedBox(height: 10),

          // Indicador visual de restricciones de contraseña (HU14-RF01)
          _buildPasswordConstraints(),

          const SizedBox(height: 18),

          // Campo Confirmar contraseña
          _buildSectionLabel('Confirmar contraseña'),
          const SizedBox(height: 6),
          KeyedSubtree(
            key: const ValueKey('input_confirm_password'),
            child: KeyedSubtree(
              key: const ValueKey('input_confirmar_password'),
              child: TextFormField(
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
                onChanged: (v) {
                  setState(() {});
                  widget.onConfirmPasswordChanged?.call(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lista interactiva de requisitos de seguridad para la contraseña (HU14-RF01).
  /// Muestra en verde con check cada criterio conforme el usuario escribe.
  Widget _buildPasswordConstraints() {
    final text = _passwordCtrl.text;
    final confirmText = _confirmPasswordCtrl.text;
    final hasLength = text.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
    final hasNumber = RegExp(r'[0-9]').hasMatch(text);
    final passwordsMatch = confirmText.isNotEmpty && (text == confirmText);

    return Container(
      key: const ValueKey('password_constraints'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ContactFormStep.creamBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ContactFormStep.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Requisitos de la contraseña:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ContactFormStep.darkText,
            ),
          ),
          const SizedBox(height: 8),
          _buildConstraintRow(
            'Mínimo 8 caracteres',
            hasLength,
            'constraint_min_length',
          ),
          const SizedBox(height: 6),
          _buildConstraintRow(
            'Al menos una letra',
            hasLetter,
            'constraint_has_letter',
          ),
          const SizedBox(height: 6),
          _buildConstraintRow(
            'Al menos un número',
            hasNumber,
            'constraint_has_number',
          ),
          if (confirmText.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildConstraintRow(
              'Las contraseñas coinciden',
              passwordsMatch,
              'constraint_passwords_match',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConstraintRow(String label, bool isMet, String keySuffix) {
    final color = isMet ? const Color(0xFF2E7D32) : ContactFormStep.mutedText;
    return Row(
      key: ValueKey(keySuffix),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
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
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ContactFormStep.darkText,
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
        color: Color(0xFFB0A59A),
      ),
      prefixIcon: Icon(prefixIcon, color: ContactFormStep.mutedText, size: 20),
      suffixIcon: suffixIcon,
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
        borderSide: const BorderSide(color: ContactFormStep.terracotta, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
      errorMaxLines: 2,
    );
  }
}
