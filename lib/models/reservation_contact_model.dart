/// Modelo inmutable para los datos de contacto del comensal en el flujo de reserva (HU13-RF03)
/// Los datos se manipulan temporalmente en memoria durante la captura y validación previa a la confirmación.
class ReservationContactModel {
  final String nombre;
  final String correo;
  final String telefono;
  final String notas;
  final bool solicitaCrearCuenta;
  final String? password;
  final String canalPreferido; // 'email' o 'whatsapp' (HU13 / HU19-RF01)

  const ReservationContactModel({
    required this.nombre,
    required this.correo,
    required this.telefono,
    this.notas = '',
    this.solicitaCrearCuenta = false,
    this.password,
    this.canalPreferido = 'email',
  });

  /// Instancia vacía inicial
  static const empty = ReservationContactModel(
    nombre: '',
    correo: '',
    telefono: '',
    notas: '',
    solicitaCrearCuenta: false,
    password: null,
    canalPreferido: 'email',
  );

  bool get isEmpty =>
      nombre.trim().isEmpty && correo.trim().isEmpty && telefono.trim().isEmpty;

  bool get isNotEmpty => !isEmpty;

  ReservationContactModel copyWith({
    String? nombre,
    String? correo,
    String? telefono,
    String? notas,
    bool? solicitaCrearCuenta,
    String? Function()? password,
    String? canalPreferido,
  }) {
    return ReservationContactModel(
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      notas: notas ?? this.notas,
      solicitaCrearCuenta: solicitaCrearCuenta ?? this.solicitaCrearCuenta,
      password: password != null ? password() : this.password,
      canalPreferido: canalPreferido ?? this.canalPreferido,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre.trim(),
      'correo': correo.trim().toLowerCase(),
      'telefono': telefono.trim(),
      'notas': notas.trim(),
      'solicitaCrearCuenta': solicitaCrearCuenta,
      'canalPreferido': canalPreferido,
    };
  }

  factory ReservationContactModel.fromMap(Map<String, dynamic> map) {
    return ReservationContactModel(
      nombre: map['nombre'] as String? ?? '',
      correo: map['correo'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      notas: map['notas'] as String? ?? '',
      solicitaCrearCuenta: map['solicitaCrearCuenta'] as bool? ?? false,
      password: map['password'] as String?,
      canalPreferido: map['canalPreferido'] as String? ?? 'email',
    );
  }
}

