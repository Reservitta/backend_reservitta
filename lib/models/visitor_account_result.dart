import 'user_model.dart';

/// Resultado del proceso de creación y asociación de cuenta de visitante (HU14-RF02)
///
/// Modela los tres posibles desenlaces del requerimiento:
/// 1. Creación exitosa: la cuenta se crea y se obtiene su `usuarioId`.
/// 2. No solicitada: el comensal no marcó crear cuenta y continúa como invitado.
/// 3. Fallback resiliente: ocurrió un error (correo duplicado, error de red), pero
///    la reserva puede continuar sin cuenta informando el motivo del fallo.
class VisitorAccountResult {
  final bool cuentaCreada;
  final String usuarioId;
  final bool continueWithoutAccount;
  final String? motivoFallo;
  final String? mensajeInformativo;
  final UserModel? usuario;

  const VisitorAccountResult._({
    required this.cuentaCreada,
    required this.usuarioId,
    required this.continueWithoutAccount,
    this.motivoFallo,
    this.mensajeInformativo,
    this.usuario,
  });

  /// Caso 1 (Criterios 1 y 2): Cuenta creada con éxito en el proveedor y asociada
  factory VisitorAccountResult.success({
    required UserModel usuario,
    String mensajeInformativo = 'Cuenta creada y asociada a tu reserva exitosamente.',
  }) {
    return VisitorAccountResult._(
      cuentaCreada: true,
      usuarioId: usuario.uid,
      continueWithoutAccount: false,
      motivoFallo: null,
      mensajeInformativo: mensajeInformativo,
      usuario: usuario,
    );
  }

  /// Caso 2: El usuario no solicitó crear cuenta; continúa directamente como invitado
  factory VisitorAccountResult.skipped({
    String? existingUsuarioId,
  }) {
    return VisitorAccountResult._(
      cuentaCreada: false,
      usuarioId: existingUsuarioId ?? '',
      continueWithoutAccount: true,
      motivoFallo: null,
      mensajeInformativo: null,
      usuario: null,
    );
  }

  /// Caso 3 (Criterio 3): Falló la creación (duplicado, error de red), la reserva continúa sin cuenta
  factory VisitorAccountResult.fallback({
    required String motivoFallo,
    String? mensajeInformativo,
  }) {
    final mensajeFinal = mensajeInformativo ??
        '$motivoFallo Tu reserva continuará como invitado sin interrupciones.';
    return VisitorAccountResult._(
      cuentaCreada: false,
      usuarioId: '',
      continueWithoutAccount: true,
      motivoFallo: motivoFallo,
      mensajeInformativo: mensajeFinal,
      usuario: null,
    );
  }

  bool get hasError => motivoFallo != null;
  bool get isSuccessWithAccount => cuentaCreada && usuarioId.isNotEmpty;
  bool get isGuestReservation => !cuentaCreada || usuarioId.isEmpty;
}

