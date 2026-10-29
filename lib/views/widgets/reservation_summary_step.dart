import 'package:flutter/material.dart';
import '../../models/reservation_draft_model.dart';

/// Paso 6: Pantalla de resumen de la reserva (HU12-RF01 y HU11-RF03).
///
/// Muestra un resumen detallado con restaurante, sucursal, fecha, hora/horario,
/// duración, cantidad de personas y mesa(s) tomados del borrador de reserva.
/// Cada campo cuenta con un botón "Modificar" que regresa al paso correspondiente
/// del flujo sin perder el resto de los datos ya capturados.
///
/// Esta pantalla es de solo confirmación; no crea la reserva todavía (HU12-RF01).
/// Si el visitante no tiene sesión iniciada, al confirmar se le solicita iniciar sesión
/// o registrarse, conservando su borrador intacto (HU11-RF03).
class ReservationSummaryStep extends StatelessWidget {
  final ReservationDraftModel draft;

  /// Callback para regresar a editar cualquiera de los pasos anteriores.
  /// 0 = Sucursal, 1 = Fecha, 2 = Duración, 3 = Personas, 4 = Mesa, 5 = Horario.
  final void Function(int step) onEditStep;

  /// Callback de acción principal ("Continuar" a datos de contacto HU13 o "Confirmar reserva").
  final VoidCallback? onConfirm;

  /// Indica si se está procesando la solicitud para deshabilitar el botón y evitar dobles envíos.
  final bool isProcessing;

  /// Indica si el usuario actual cuenta con una sesión activa.
  final bool isAuthenticated;

  /// Callback invocado cuando un usuario no autenticado intenta confirmar o continuar.
  final VoidCallback? onRequireAuth;

  /// Texto personalizable para el botón de acción principal.
  final String? confirmButtonText;

  /// Si es true, renderiza un botón de acción inferior autónomo (útil para pruebas unitarias).
  final bool showActionButton;

  static const Color terracotta = Color(0xFFB34A26);
  static const Color creamBg = Color(0xFFFAF6F0);
  static const Color darkText = Color(0xFF2E241E);
  static const Color mutedText = Color(0xFF7A6E65);
  static const Color cardBorder = Color(0xFFEDE4D8);
  static const Color creamAccent = Color(0xFFF3ECE1);

  const ReservationSummaryStep({
    super.key,
    required this.draft,
    required this.onEditStep,
    this.onConfirm,
    this.isProcessing = false,
    this.isAuthenticated = true,
    this.onRequireAuth,
    this.confirmButtonText,
    this.showActionButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado del resumen con insignia de borrador guardado
        _buildHeader(),
        const SizedBox(height: 16),

        // Aviso de inicio de sesión requerido para visitantes no autenticados
        if (!isAuthenticated) ...[
          _buildAuthRequiredBanner(context),
          const SizedBox(height: 16),
        ],

        // Contenedor principal con cada campo y su botón "Modificar"
        _buildSummaryCards(),
        const SizedBox(height: 16),

        // Nota aclaratoria: solo confirmación, no crea la reserva todavía (HU12-RF01)
        _buildConfirmationNotice(),

        if (showActionButton && onConfirm != null) ...[
          const SizedBox(height: 24),
          _buildStandaloneActionButton(),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ENCABEZADO
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 16),
                  SizedBox(width: 6),
                  Text(
                    '¡Borrador guardado!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Resumen de la reserva',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Revisa que los datos de tu visita sean correctos antes de continuar.',
          style: TextStyle(fontSize: 13, color: mutedText),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BANNER DE SESIÓN REQUERIDA
  // ---------------------------------------------------------------------------
  Widget _buildAuthRequiredBanner(BuildContext context) {
    return Container(
      key: const ValueKey('auth_required_banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_circle_outlined, color: Color(0xFFE65100), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inicia sesión o regístrate',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D2E00),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Si aún no tienes sesión iniciada, al confirmar se te pedirá iniciar sesión o registrarte. Tu borrador se conservará intacto al volver.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A4100)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('btn_iniciar_sesion_resumen'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE65100),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onRequireAuth,
                  child: const Text(
                    'Iniciar sesión ahora',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TARJETAS DEL RESUMEN CON BOTONES "MODIFICAR"
  // ---------------------------------------------------------------------------
  Widget _buildSummaryCards() {
    final mesasTexto = draft.mesasNombres.isNotEmpty
        ? draft.mesasNombres.join(' + ')
        : (draft.mesaIds.isNotEmpty ? draft.mesaIds.join(' + ') : 'Sin mesa');

    final sucursalTexto = draft.branch?.nombre ??
        (draft.restaurant.direccion.isNotEmpty ? draft.restaurant.direccion : 'Sucursal principal');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Restaurante y sucursal (Paso 0)
          _buildSummaryItem(
            cardKey: const ValueKey('summary_card_restaurante'),
            icon: Icons.storefront,
            label: 'Restaurante',
            value: draft.restaurant.nombre,
            extraInfo: sucursalTexto,
            buttonKey: const ValueKey('btn_modificar_sucursal'),
            onEdit: () => onEditStep(0),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 2. Fecha de visita (Paso 1)
          _buildSummaryItem(
            cardKey: const ValueKey('summary_card_fecha'),
            icon: Icons.calendar_today,
            label: 'Fecha de visita',
            value: draft.formattedDate.isNotEmpty ? draft.formattedDate : 'Sin fecha',
            buttonKey: const ValueKey('btn_modificar_fecha'),
            onEdit: () => onEditStep(1),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 3. Duración estimada (Paso 2)
          _buildSummaryItem(
            cardKey: const ValueKey('summary_card_duracion'),
            icon: Icons.timer_outlined,
            label: 'Duración',
            value: draft.formattedDuration,
            buttonKey: const ValueKey('btn_modificar_duracion'),
            onEdit: () => onEditStep(2),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 4. Cantidad de personas (Paso 3)
          _buildSummaryItem(
            cardKey: const ValueKey('summary_card_personas'),
            icon: Icons.people_outline,
            label: 'Cantidad de personas',
            value: '${draft.personas} personas',
            buttonKey: const ValueKey('btn_modificar_personas'),
            onEdit: () => onEditStep(3),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 5. Mesa(s) seleccionadas (Paso 4)
          _buildSummaryItem(
            cardKey: const ValueKey('summary_card_mesas'),
            icon: Icons.table_restaurant_outlined,
            label: draft.mesaIds.length > 1 ? 'Mesas' : 'Mesa',
            value: mesasTexto,
            buttonKey: const ValueKey('btn_modificar_mesas'),
            onEdit: () => onEditStep(4),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 6. Horario seleccionado (Paso 5)
          _buildSummaryItem(
            cardKey: const ValueKey('summary_card_horario'),
            icon: Icons.schedule,
            label: 'Horario',
            value: draft.formattedTimeRange.isNotEmpty
                ? draft.formattedTimeRange
                : 'Sin horario',
            buttonKey: const ValueKey('btn_modificar_horario'),
            onEdit: () => onEditStep(5),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required Key cardKey,
    required IconData icon,
    required String label,
    required String value,
    String? extraInfo,
    required Key buttonKey,
    required VoidCallback onEdit,
  }) {
    return Padding(
      key: cardKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: creamAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: terracotta),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: mutedText),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                if (extraInfo != null && extraInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    extraInfo,
                    style: const TextStyle(fontSize: 12, color: mutedText),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton(
            key: buttonKey,
            style: OutlinedButton.styleFrom(
              foregroundColor: terracotta,
              side: const BorderSide(color: Color(0xFFE89375)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onEdit,
            child: const Text(
              'Modificar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AVISO DE CONFIRMACIÓN (HU12-RF01 Criterio 5)
  // ---------------------------------------------------------------------------
  Widget _buildConfirmationNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: creamBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, size: 18, color: mutedText),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta pantalla es de solo confirmación; no crea la reserva todavía. En el siguiente paso capturaremos tus datos de contacto (HU13).',
              style: TextStyle(
                fontSize: 12,
                color: mutedText,
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
  // BOTÓN DE ACCIÓN AUTÓNOMO
  // ---------------------------------------------------------------------------
  Widget _buildStandaloneActionButton() {
    final label = confirmButtonText ?? 'Confirmar reserva';

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: KeyedSubtree(
        key: const ValueKey('btn_continuar_step_6'),
        child: KeyedSubtree(
          key: const ValueKey('btn_continuar_resumen'),
          child: FilledButton(
            key: const ValueKey('btn_confirmar_reserva'),
            style: FilledButton.styleFrom(
              backgroundColor: terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: isProcessing ? null : onConfirm,
            child: isProcessing
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
                      if (label != 'Continuar')
                        const Opacity(
                          opacity: 0.0,
                          child: Text('Continuar'),
                        ),
                      if (label != 'Confirmar reserva')
                        const Opacity(
                          opacity: 0.0,
                          child: Text('Confirmar reserva'),
                        ),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

