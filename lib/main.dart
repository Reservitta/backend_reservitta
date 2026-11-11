import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'models/reservation_access.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'views/authenticated_user_gate.dart';
import 'views/landing_view.dart';
import 'views/reservation_management_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Nota: Archivo .env no cargado dinámicamente ($e), usando clave por defecto/dart-define.');
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // HU20-RF03: el enlace de la reserva (?reserva=CODIGO) abre su gestión sin sesión.
    final codigoEnlace = ReservationAccess.tokenDeEnlace(Uri.base);

    return MaterialApp(
      title: 'Reservitta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      home: codigoEnlace != null
          ? Builder(
              builder: (context) => ReservationManagementView(
                initialCode: codigoEnlace,
                onSalir: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const _Inicio()),
                ),
              ),
            )
          : const _Inicio(),
    );
  }
}

/// Pantalla de inicio: la landing pública o el panel según la sesión.
class _Inicio extends StatelessWidget {
  const _Inicio();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.hasData
            ? AuthenticatedUserGate(
                key: ValueKey(snap.data!.uid),
                user: snap.data!,
              )
            : const LandingView();
      },
    );
  }
}
