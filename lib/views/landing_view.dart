import 'package:flutter/material.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import 'auth_modal_dialog.dart';

class LandingView extends StatelessWidget {
  const LandingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Row(
          children: [
            Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Reservitta',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AuthModalDialog.show(
                context,
                initialMode: AuthMode.registerRoleSelection,
              );
            },
            child: const Text('Registrarse'),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Iniciar Sesión'),
              onPressed: () {
                AuthModalDialog.show(
                  context,
                  initialMode: AuthMode.login,
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withAlpha(50),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_outlined,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Bienvenido a Reservitta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: const Text(
                      'La plataforma inteligente de gestión de reservas y experiencias para restaurantes. Administra tus mesas, menús y horarios en tiempo real.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Iniciar Sesión'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () {
                          AuthModalDialog.show(
                            context,
                            initialMode: AuthMode.login,
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.app_registration),
                        label: const Text('Crear Cuenta'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () {
                          AuthModalDialog.show(
                            context,
                            initialMode: AuthMode.registerRoleSelection,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
