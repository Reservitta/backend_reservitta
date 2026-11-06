import 'package:firebase_auth/firebase_auth.dart';
import '../models/reservation_draft_model.dart';
import '../models/visitor_account_result.dart';
import 'auth_service.dart';

/// Servicio para la creación y asociación de cuenta de visitante a la reserva en curso (HU14-RF02)
///
/// Criterios de aceptación:
/// 1. Si se solicitó, se crea un usuario en el proveedor de autenticación con el correo y contraseña capturados.
/// 2. La cuenta se asocia a la reserva en curso.
/// 3. Si falla la creación (correo duplicado, error de red), la reserva puede continuar sin cuenta y se informa el motivo.
class VisitorAccountService {
  final AuthService _authService;

  VisitorAccountService({AuthService? authService})
      : _authService = authService ?? AuthService();

  /// Procesa la solicitud opcional de cuenta de visitante durante la reserva.
  ///
  /// - Si `solicitaCrearCuenta` es false: no crea cuenta y continúa como invitado.
  /// - Si `solicitaCrearCuenta` es true: intenta registrar la cuenta en el proveedor.
  /// - Si ocurre un error (duplicado, red, etc.): no aborta la reserva, retorna un
  ///   resultado de fallback con `continueWithoutAccount: true` y el motivo detallado (Criterio 3).
  Future<VisitorAccountResult> processVisitorAccount({
    required ReservationDraftModel draft,
  }) async {
    final contact = draft.contactData;

    // Si no se capturaron datos o no se solicitó crear cuenta, avanza directamente
    if (contact == null || !contact.solicitaCrearCuenta) {
      return VisitorAccountResult.skipped(existingUsuarioId: draft.usuarioId);
    }

    final correo = contact.correo.trim();
    final password = contact.password?.trim() ?? '';
    final nombre = contact.nombre.trim();
    final telefono = contact.telefono.trim();

    // Validación previa de campos mínimos
    if (correo.isEmpty || password.isEmpty) {
      return VisitorAccountResult.fallback(
        motivoFallo: 'No se proporcionaron correo y contraseña válidos para la cuenta.',
        mensajeInformativo:
            'Faltan datos de acceso. Tu reserva continuará como invitado sin cuenta asociada.',
      );
    }

    try {
      // Criterio 1: Crear usuario en el proveedor de autenticación
      final userModel = await _authService.registerVisitor(
        nombre: nombre,
        correo: correo,
        telefono: telefono,
        password: password,
      );

      // Criterio 2: La cuenta se asocia a la reserva en curso
      return VisitorAccountResult.success(
        usuario: userModel,
        mensajeInformativo: 'Cuenta creada y vinculada exitosamente a tu reservación.',
      );
    } catch (e) {
      // Criterio 3: Manejo resiliente ante fallas de autenticación
      final errorStr = e.toString().toLowerCase();
      String motivo;

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            motivo = 'El correo electrónico ya se encuentra registrado con otra cuenta.';
            break;
          case 'network-request-failed':
            motivo = 'No se pudo conectar con el servidor de autenticación por un error de red.';
            break;
          case 'weak-password':
            motivo = 'La contraseña no cumple con la longitud mínima requerida.';
            break;
          default:
            motivo = 'Error en el proveedor de autenticación (${e.code}).';
        }
      } else if (errorStr.contains('ya se encuentra registrado') ||
          errorStr.contains('email-already-in-use')) {
        motivo = 'El correo electrónico ya se encuentra registrado con otra cuenta.';
      } else if (errorStr.contains('network') ||
          errorStr.contains('conexión') ||
          errorStr.contains('red') ||
          errorStr.contains('timeout')) {
        motivo = 'No se pudo conectar con el servidor de autenticación por un error de red.';
      } else if (errorStr.contains('contraseña') || errorStr.contains('password')) {
        motivo = 'La contraseña no cumple con la longitud requerida.';
      } else {
        motivo = 'No se pudo completar la creación de la cuenta: ${e.toString().replaceAll("Exception: ", "")}';
      }

      return VisitorAccountResult.fallback(
        motivoFallo: motivo,
        mensajeInformativo:
            '$motivo Tu reserva continuará sin cuenta para no interrumpir tu solicitud.',
      );
    }
  }

  /// Criterio 2: Asocia el ID de la cuenta creada (o vacía si continúa como invitado) a la reserva en curso.
  ReservationDraftModel associateAccountToDraft({
    required ReservationDraftModel draft,
    required VisitorAccountResult result,
  }) {
    if (result.cuentaCreada && result.usuarioId.isNotEmpty) {
      return draft.copyWith(usuarioId: result.usuarioId);
    } else {
      // Si falló o fue omitida, se conserva sin cuenta (modo invitado)
      return draft.copyWith(usuarioId: '');
    }
  }
}

