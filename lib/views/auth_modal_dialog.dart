import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import '../theme/app_theme.dart';

class AuthModalDialog extends StatefulWidget {
  final AuthMode initialMode;
  final bool showGuestOption;

  const AuthModalDialog({
    super.key,
    this.initialMode = AuthMode.login,
    this.showGuestOption = false,
  });

  /// Abre el modal flotante con animación fluida de escala/opacidad y desenfoque de fondo
  static Future<T?> show<T>(
    BuildContext context, {
    AuthMode initialMode = AuthMode.login,
    bool showGuestOption = false,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar modal',
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.38),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AuthModalDialog(
            initialMode: initialMode,
            showGuestOption: showGuestOption,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = Curves.easeOutCubic.transform(animation.value);
        return Transform.scale(
          scale: 0.94 + (0.06 * curve),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AuthModalDialog> createState() => _AuthModalDialogState();
}

class _AuthModalDialogState extends State<AuthModalDialog> {
  late final AuthModalViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthModalViewModel(initialMode: widget.initialMode);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  bool _verClaveLogin = false;
  bool _verClaveRegistro = false;
  bool _verClaveConfirmar = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tamano = MediaQuery.sizeOf(context);
    final dosPaneles = tamano.width >= 820;
    final alto = tamano.height * 0.90;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dosPaneles ? 920 : 480,
          maxHeight: alto,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.12),
                blurRadius: 32,
                spreadRadius: 0,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                final formulario = SingleChildScrollView(
                  padding: EdgeInsets.all(dosPaneles ? 36 : 28),
                  child: _buildContenido(theme),
                );
                if (!dosPaneles) return formulario;
                final altoPanel = alto < 660 ? alto : 660.0;
                return SizedBox(
                  height: altoPanel,
                  child: Row(
                    children: [
                      SizedBox(width: 340, child: _buildPanelMarca()),
                      Expanded(child: Center(child: formulario)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContenido(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: Título principal y botón de cierre minimalista
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_viewModel.currentMode == AuthMode.registerForm)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => _viewModel.backToRoleSelection(),
                tooltip: 'Regresar',
              )
            else if (_viewModel.currentMode == AuthMode.forgotPassword)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => _viewModel.setMode(AuthMode.login),
                tooltip: 'Volver',
              )
            else
              const SizedBox(width: 40),
            Flexible(
              child: Text(
                _getTitle(_viewModel.currentMode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.familiaTitulos,
                  fontWeight: FontWeight.w700,
                  fontVariations: [FontVariation('wght', 700)],
                  fontSize: 26,
                  letterSpacing: -0.4,
                  color: AppColors.texto,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textoSuave),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Cerrar',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Cuerpo dinámico del modal
        if (_viewModel.currentMode == AuthMode.login)
          _buildLoginForm(theme)
        else if (_viewModel.currentMode == AuthMode.registerRoleSelection)
          _buildRoleSelectionStep(theme)
        else if (_viewModel.currentMode == AuthMode.registerForm)
          _buildRegisterForm(theme)
        else if (_viewModel.currentMode == AuthMode.forgotPassword)
          _buildForgotPasswordForm(theme),
      ],
    );
  }

  /// Panel de marca de la izquierda (solo en pantallas anchas).
  Widget _buildPanelMarca() {
    final modo = _viewModel.currentMode;
    final esAdmin = _viewModel.selectedRole == 'admin' &&
        (modo == AuthMode.registerForm || modo == AuthMode.registerRoleSelection);

    final String titular;
    final String detalle;
    final List<String> puntos;
    switch (modo) {
      case AuthMode.login:
        titular = 'Qué bueno verte de nuevo';
        detalle = 'Entra para ver y gestionar tus reservas.';
        puntos = const [
          'Reserva en segundos',
          'Elige tu mesa en el mapa',
          'Recibe tu confirmación al instante',
        ];
      case AuthMode.forgotPassword:
        titular = 'Recupera tu acceso';
        detalle = 'Te enviaremos un enlace para que elijas una nueva contraseña.';
        puntos = const [
          'Revisa también tu bandeja de spam',
          'El enlace funciona por tiempo limitado',
        ];
      case AuthMode.registerRoleSelection:
      case AuthMode.registerForm:
        if (esAdmin) {
          titular = 'Haz crecer tu restaurante';
          detalle = 'Recibe reservas y organiza tu salón desde un solo lugar.';
          puntos = const [
            'Arma el plano de tus mesas',
            'Controla tus reservas del día',
            'Publica tu menú y tus horarios',
          ];
        } else {
          titular = 'Tu mesa, sin complicaciones';
          detalle = 'Descubre restaurantes, elige tu mesa y reserva en minutos.';
          puntos = const [
            'Reserva en segundos',
            'Guarda tu historial de visitas',
            'Personaliza tu visita con anticipación',
          ];
        }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.marca, Color(0xFF4A2B17)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
          ),
          const Spacer(),
          Text(
            titular,
            style: const TextStyle(
              fontFamily: AppTheme.familiaTitulos,
              fontWeight: FontWeight.w700,
              fontVariations: [FontVariation('wght', 700)],
              fontSize: 32,
              height: 1.12,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            detalle,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 26),
          for (final punto in puntos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      punto,
                      style: const TextStyle(fontSize: 14, height: 1.3, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  String _getTitle(AuthMode mode) {
    switch (mode) {
      case AuthMode.login:
        return 'Iniciar Sesión';
      case AuthMode.registerRoleSelection:
        return 'Crear Cuenta';
      case AuthMode.registerForm:
        return _viewModel.selectedRole == 'admin'
            ? 'Registro Restaurante'
            : 'Registro Cliente';
      case AuthMode.forgotPassword:
        return 'Restablecer Contraseña';
    }
  }

  /// 1. Formulario de Inicio de Sesión
  Widget _buildLoginForm(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _viewModel.loginEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo Electrónico',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            errorText: _viewModel.fieldErrors['loginEmail'],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _viewModel.loginPasswordController,
          obscureText: !_verClaveLogin,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _verClaveLogin ? 'Ocultar contraseña' : 'Mostrar contraseña',
              icon: Icon(_verClaveLogin ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _verClaveLogin = !_verClaveLogin),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            errorText: _viewModel.fieldErrors['loginPassword'],
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _viewModel.setMode(AuthMode.forgotPassword),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textoSuave,
            ),
            child: const Text('¿Olvidaste tu contraseña?'),
          ),
        ),
        if (_viewModel.errorMessage != null) ...[
          const SizedBox(height: 8),
          _buildErrorContainer(_viewModel.errorMessage!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _viewModel.isLoading
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final success = await _viewModel.login();
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    navigator.pop();
                  }
                },
          child: _viewModel.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Iniciar Sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              '¿No tienes cuenta? ',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            TextButton(
              onPressed: () => _viewModel.setMode(AuthMode.registerRoleSelection),
              child: const Text('Registrarse', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (widget.showGuestOption) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              key: const ValueKey('btn_continuar_como_invitado'),
              icon: const Icon(Icons.arrow_forward_outlined, size: 16, color: AppColors.marca),
              label: const Text(
                'Continuar reserva sin cuenta',
                style: TextStyle(
                  color: AppColors.marca,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: () async {
                await _viewModel.signInAnonymously();
                if (context.mounted) {
                  Navigator.of(context).pop('guest');
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  /// 2. Paso 0 de Registro: ¿Cómo quieres asociarte a nosotros?
  Widget _buildRoleSelectionStep(ThemeData theme) {
    final isClient = _viewModel.selectedRole == 'visitante';
    final isAdmin = _viewModel.selectedRole == 'admin';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Cómo quieres asociarte a nosotros?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecciona la opción que mejor se acomode a tu perfil.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSuave, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Opción 1: Cliente / Comensal
        InkWell(
          onTap: () => _viewModel.setSelectedRole('visitante'),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isClient ? AppColors.marca : AppColors.divisor,
                width: isClient ? 2 : 1,
              ),
              color: isClient ? AppColors.marcaSuave : theme.colorScheme.surface,
              boxShadow: isClient
                  ? [
                      BoxShadow(
                        color: AppColors.marca.withAlpha(20),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isClient ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isClient ? AppColors.marca : AppColors.borde,
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.person_pin_outlined,
                  size: 32,
                  color: isClient ? AppColors.marca : AppColors.textoSuave,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente / Comensal',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isClient ? AppColors.marca : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quiero hacer reservas, ver mi historial y enterarme de promociones en restaurantes.',
                        style: TextStyle(fontSize: 12, color: AppColors.textoSuave, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Opción 2: Administrador de Restaurante
        InkWell(
          onTap: () => _viewModel.setSelectedRole('admin'),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isAdmin ? AppColors.marca : AppColors.divisor,
                width: isAdmin ? 2 : 1,
              ),
              color: isAdmin ? AppColors.marcaSuave : theme.colorScheme.surface,
              boxShadow: isAdmin
                  ? [
                      BoxShadow(
                        color: AppColors.marca.withAlpha(20),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isAdmin ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isAdmin ? AppColors.marca : AppColors.borde,
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.storefront_outlined,
                  size: 32,
                  color: isAdmin ? AppColors.marca : AppColors.textoSuave,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrador de Restaurante',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isAdmin ? AppColors.marca : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Busco inscribir mi restaurante a la plataforma para gestionar mesas y reservas.',
                        style: TextStyle(fontSize: 12, color: AppColors.textoSuave, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Siguiente', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          onPressed: () => _viewModel.goToRegisterForm(),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _viewModel.setMode(AuthMode.login),
          child: const Text('¿Ya tienes una cuenta? Iniciar Sesión'),
        ),
      ],
    );
  }

  /// 3. Paso 1 de Registro: Formulario según el rol seleccionado
  Widget _buildRegisterForm(ThemeData theme) {
    final isAdmin = _viewModel.selectedRole == 'admin';
    final fe = _viewModel.fieldErrors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _viewModel.nombreController,
          decoration: InputDecoration(
            labelText: 'Nombre Completo *',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            errorText: fe['nombre'],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _viewModel.correoController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo Electrónico *',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            errorText: fe['correo'],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _viewModel.telefonoController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            labelText: 'Teléfono (10 dígitos numéricos) *',
            hintText: '5512345678',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            errorText: fe['telefono'],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _viewModel.registerPasswordController,
          obscureText: !_verClaveRegistro,
          decoration: InputDecoration(
            labelText: 'Contraseña (mínimo 8 caracteres) *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _verClaveRegistro ? 'Ocultar contraseña' : 'Mostrar contraseña',
              icon: Icon(_verClaveRegistro ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _verClaveRegistro = !_verClaveRegistro),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            errorText: fe['password'],
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        _buildPasswordConstraints(
          _viewModel.registerPasswordController.text,
          _viewModel.confirmPasswordController.text,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _viewModel.confirmPasswordController,
          obscureText: !_verClaveConfirmar,
          decoration: InputDecoration(
            labelText: 'Confirmar Contraseña *',
            prefixIcon: const Icon(Icons.lock_reset_outlined),
            suffixIcon: IconButton(
              tooltip: _verClaveConfirmar ? 'Ocultar contraseña' : 'Mostrar contraseña',
              icon: Icon(_verClaveConfirmar ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _verClaveConfirmar = !_verClaveConfirmar),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            errorText: fe['confirmPassword'],
          ),
          onChanged: (_) => setState(() {}),
        ),

        if (isAdmin) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _viewModel.nombreRestauranteController,
            decoration: InputDecoration(
              labelText: 'Nombre de tu Restaurante (Opcional)',
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              helperText: 'Completarás los datos y horarios en el siguiente paso',
              errorText: fe['restaurante'],
            ),
          ),
        ],

        // Error global (e.g. correo ya registrado en Firebase)
        if (_viewModel.errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildErrorContainer(_viewModel.errorMessage!),
        ],

        if (_viewModel.successMessage != null) ...[
          const SizedBox(height: 14),
          _buildSuccessContainer(_viewModel.successMessage!),
        ],

        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _viewModel.isLoading
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final success = await _viewModel.register();
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    navigator.pop();
                  }
                },
          child: _viewModel.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isAdmin ? 'Continuar: Configurar Restaurante' : 'Crear Cuenta',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  /// 4. Formulario de Olvidé mi Contraseña
  Widget _buildForgotPasswordForm(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ingresa tu correo electrónico y te enviaremos el enlace para restablecer tu contraseña.',
          style: TextStyle(fontSize: 13, color: AppColors.textoSuave, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _viewModel.resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo Electrónico',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        if (_viewModel.resetErrorMessage != null) ...[
          const SizedBox(height: 10),
          _buildErrorContainer(_viewModel.resetErrorMessage!),
        ],
        if (_viewModel.resetMessage != null) ...[
          const SizedBox(height: 10),
          _buildSuccessContainer(_viewModel.resetMessage!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _viewModel.isResetLoading
              ? null
              : () async {
                  await _viewModel.sendPasswordReset();
                },
          child: _viewModel.isResetLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar Correo de Restablecimiento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildErrorContainer(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContainer(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.exito.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: AppColors.exito, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.exito, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordConstraints(String password, String confirmPassword) {
    final hasLength = password.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final passwordsMatch = confirmPassword.isNotEmpty && (password == confirmPassword);

    return Container(
      key: const ValueKey('modal_password_constraints'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divisor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Requisitos de la contraseña:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.texto,
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
          if (confirmPassword.isNotEmpty) ...[
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
    final color = isMet ? AppColors.exito : AppColors.textoSuave;
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
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
