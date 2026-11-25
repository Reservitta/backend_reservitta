/// Datos de la cuenta donde el restaurante recibe transferencias (anticipos y pedidos).
class DatosBancarios {
  final String banco;
  final String beneficiario;

  /// CLABE interbancaria, número de cuenta o de tarjeta (solo dígitos).
  final String cuenta;

  const DatosBancarios({
    this.banco = '',
    this.beneficiario = '',
    this.cuenta = '',
  });

  bool get completos =>
      banco.trim().isNotEmpty &&
      beneficiario.trim().isNotEmpty &&
      cuenta.trim().isNotEmpty;

  factory DatosBancarios.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const DatosBancarios();
    return DatosBancarios(
      banco: (data['banco'] as String?)?.trim() ?? '',
      beneficiario: (data['beneficiario'] as String?)?.trim() ?? '',
      cuenta: (data['cuenta'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'banco': banco.trim(),
        'beneficiario': beneficiario.trim(),
        'cuenta': cuenta.trim(),
      };

  /// Mensaje del primer problema de los datos, o null si son válidos.
  static String? validar({
    required String banco,
    required String beneficiario,
    required String cuenta,
  }) {
    if (banco.trim().isEmpty) return 'Escribe el nombre del banco.';
    if (beneficiario.trim().isEmpty) return 'Escribe el nombre del beneficiario.';
    final digitos = cuenta.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{10,18}$').hasMatch(digitos)) {
      return 'La cuenta debe tener entre 10 y 18 dígitos (CLABE, cuenta o tarjeta).';
    }
    return null;
  }

  /// Quita espacios y guiones de la cuenta para guardarla solo con dígitos.
  static String limpiarCuenta(String cuenta) =>
      cuenta.replaceAll(RegExp(r'[\s-]'), '');
}

/// Anticipo que el restaurante pide para confirmar una reservación.
class AnticipoConfig {
  final bool activo;

  /// Monto fijo en MXN por reservación.
  final double monto;

  /// Horas que tiene el cliente para mandar su comprobante.
  final int horasLimite;

  /// Política de cancelación y reembolso que ve el cliente antes de pagar.
  final String politicaCancelacion;

  static const int horasLimitePorDefecto = 24;

  const AnticipoConfig({
    this.activo = false,
    this.monto = 0,
    this.horasLimite = horasLimitePorDefecto,
    this.politicaCancelacion = '',
  });

  factory AnticipoConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AnticipoConfig();
    final horas = (data['horasLimite'] as num?)?.toInt() ?? horasLimitePorDefecto;
    return AnticipoConfig(
      activo: data['activo'] as bool? ?? false,
      monto: (data['monto'] as num?)?.toDouble() ?? 0,
      horasLimite: horas > 0 ? horas : horasLimitePorDefecto,
      politicaCancelacion: (data['politicaCancelacion'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'activo': activo,
        'monto': monto,
        'horasLimite': horasLimite,
        'politicaCancelacion': politicaCancelacion.trim(),
      };
}
