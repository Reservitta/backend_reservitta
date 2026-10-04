import 'dart:ui';
import 'package:flutter/material.dart';
import '../viewmodels/auth_modal_viewmodel.dart';

class AuthModalDialog extends StatefulWidget {
  final AuthMode initialMode;

  const AuthModalDialog({
    super.key,
    this.initialMode = AuthMode.login,
  });

  /// Abre el modal flotante con animación fluida de escala/opacidad y desenfoque de fondo
  static Future<void> show(BuildContext context, {AuthMode initialMode = AuthMode.login}) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar modal',
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.38),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AuthModalDialog(initialMode: initialMode),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.08),
                blurRadius: 32,
                spreadRadius: 0,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 12,
                spreadRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
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
                          Text(
                            _getTitle(_viewModel.currentMode),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Cerrar',
                            hoverColor: const Color.fromRGBO(0, 0, 0, 0.05),
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
                },
              ),
            ),
          ),
        ),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: _viewModel.fieldErrors['loginEmail'],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _viewModel.loginPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: _viewModel.fieldErrors['loginPassword'],
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _viewModel.setMode(AuthMode.forgotPassword),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _viewModel.isLoading
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final success = await _viewModel.login();
                  if (success && mounted) {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¿No tienes cuenta? ',
              style: TextStyle(color: Colors.grey),
            ),
            TextButton(
              onPressed: () => _viewModel.setMode(AuthMode.registerRoleSelection),
              child: const Text('Registrarse', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Opción 1: Cliente / Comensal
        InkWell(
          onTap: () => _viewModel.setSelectedRole('visitante'),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isClient ? theme.colorScheme.primary : Colors.grey.shade200,
                width: isClient ? 2 : 1,
              ),
              color: isClient ? theme.colorScheme.primaryContainer.withAlpha(60) : theme.colorScheme.surface,
              boxShadow: isClient
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(20),
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
                  color: isClient ? theme.colorScheme.primary : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.person_pin_outlined,
                  size: 32,
                  color: isClient ? theme.colorScheme.primary : Colors.grey.shade600,
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
                          color: isClient ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quiero hacer reservas, ver mi historial y enterarme de promociones en restaurantes.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
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
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAdmin ? theme.colorScheme.primary : Colors.grey.shade200,
                width: isAdmin ? 2 : 1,
              ),
              color: isAdmin ? theme.colorScheme.primaryContainer.withAlpha(60) : theme.colorScheme.surface,
              boxShadow: isAdmin
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(20),
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
                  color: isAdmin ? theme.colorScheme.primary : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.storefront_outlined,
                  size: 32,
                  color: isAdmin ? theme.colorScheme.primary : Colors.grey.shade600,
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
                          color: isAdmin ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Busco inscribir mi restaurante a la plataforma para gestionar mesas y reservas.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: fe['correo'],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _viewModel.telefonoController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Teléfono *',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: fe['telefono'],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _viewModel.registerPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Contraseña (mínimo 6 caracteres) *',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: fe['password'],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _viewModel.confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirmar Contraseña *',
            prefixIcon: const Icon(Icons.lock_reset_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: fe['confirmPassword'],
          ),
        ),

        if (isAdmin) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _viewModel.nombreRestauranteController,
            decoration: InputDecoration(
              labelText: 'Nombre de tu Restaurante (Opcional)',
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              helperText: 'Se creará en borrador para configurar después',
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _viewModel.isLoading
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final success = await _viewModel.register();
                  if (success && mounted) {
                    navigator.pop();
                  }
                },
          child: _viewModel.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Completar Registro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _viewModel.resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo Electrónico',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
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
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.green, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
