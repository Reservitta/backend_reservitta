import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/reminder_inbox_service.dart';
import '../../theme/app_theme.dart';

/// Recordatorio dentro de la app para el visitante con sesión (HU21-RF02): avisa de
/// las reservas que están por comenzar. Si no se puede consultar, no muestra nada.
class UpcomingReminderBanner extends StatefulWidget {
  /// Carga los recordatorios; por defecto, los del usuario con sesión.
  final Future<List<UpcomingReminder>> Function()? cargar;

  const UpcomingReminderBanner({super.key, this.cargar});

  @override
  State<UpcomingReminderBanner> createState() => _UpcomingReminderBannerState();
}

class _UpcomingReminderBannerState extends State<UpcomingReminderBanner> {
  late final Future<List<UpcomingReminder>> _futuro = _cargar();

  Future<List<UpcomingReminder>> _cargar() async {
    try {
      final cargar = widget.cargar;
      if (cargar != null) return await cargar();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      return await ReminderInboxService().proximos(uid);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UpcomingReminder>>(
      future: _futuro,
      builder: (context, snap) {
        final lista = snap.data ?? const <UpcomingReminder>[];
        if (lista.isEmpty) return const SizedBox.shrink();
        return Padding(
          key: const ValueKey('banner_recordatorio'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: [
              for (final r in lista)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0A100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined,
                          color: Color(0xFF7A5A00)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.texto,
                          key: ValueKey('recordatorio_${r.reserva.id}'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.texto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
