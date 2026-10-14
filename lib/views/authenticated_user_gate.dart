import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'home_view.dart';

class AuthenticatedUserGate extends StatefulWidget {
  final User user;

  const AuthenticatedUserGate({super.key, required this.user});

  @override
  State<AuthenticatedUserGate> createState() => _AuthenticatedUserGateState();
}

class _AuthenticatedUserGateState extends State<AuthenticatedUserGate> {
  final AuthService _authService = AuthService();
  late Future<UserModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<UserModel?> _loadProfile() =>
      _authService.getUserProfile(widget.user.uid);

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ProfileAccessMessage(
            message:
                'No se pudo verificar tu perfil de Reservitta: ${snapshot.error}',
            onRetry: () {
              setState(() {
                _profileFuture = _loadProfile();
              });
            },
            onSignOut: _signOut,
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return _ProfileAccessMessage(
            message: 'Esta cuenta de Firebase no tiene un perfil en Reservitta. Regístrate desde la aplicación o cierra sesión.',
            onRetry: () {
              setState(() {
                _profileFuture = _loadProfile();
              });
            },
            onSignOut: _signOut,
          );
        }

        if (profile.rol == 'admin') {
          return const HomeView();
        }

        if (profile.rol == 'visitante') {
          return _VisitorHomeView(nombre: profile.nombre);
        }

        return _ProfileAccessMessage(
          message: 'El perfil de esta cuenta no tiene un rol válido en Reservitta. Cierra sesión y contacta al soporte.',
          onSignOut: _signOut,
        );
      },
    );
  }
}

class _ProfileAccessMessage extends StatefulWidget {
  final String message;
  final VoidCallback? onRetry;
  final Future<void> Function() onSignOut;

  const _ProfileAccessMessage({
    required this.message,
    required this.onSignOut,
    this.onRetry,
  });

  @override
  State<_ProfileAccessMessage> createState() => _ProfileAccessMessageState();
}

class _ProfileAccessMessageState extends State<_ProfileAccessMessage> {
  String? _signOutError;
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _signOutError = null;
    });
    try {
      await widget.onSignOut();
    } catch (error) {
      setState(() {
        _signOutError = 'No se pudo cerrar la sesión: $error';
        _isSigningOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle_outlined, size: 48),
                const SizedBox(height: 16),
                Text(widget.message, textAlign: TextAlign.center),
                if (_signOutError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _signOutError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (widget.onRetry != null)
                  OutlinedButton(
                    onPressed: widget.onRetry,
                    child: const Text('Reintentar'),
                  ),
                FilledButton(
                  onPressed: _isSigningOut ? null : _signOut,
                  child: _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitorHomeView extends StatelessWidget {
  final String nombre;

  const _VisitorHomeView({required this.nombre});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservitta'),
        actions: [
          IconButton(
            onPressed: () => authService.signOut(),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Text('Bienvenido${nombre.isEmpty ? '' : ', $nombre'}'),
      ),
    );
  }
}
