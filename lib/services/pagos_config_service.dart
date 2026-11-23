import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_config.dart';

/// Guarda la configuración de cobros del restaurante: cuenta para transferencias,
/// anticipo de reservaciones y si recibe pedidos a domicilio y para recoger.
class PagosConfigService {
  final FirebaseFirestore? _firestoreInstance;

  PagosConfigService({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  /// Mensaje del primer problema de la configuración, o null si se puede guardar.
  static String? validar({
    required DatosBancarios cuenta,
    required AnticipoConfig anticipo,
  }) {
    // La cuenta es obligatoria con anticipo; sin él es opcional, pero si se empieza a
    // llenar debe quedar completa para que el cliente pueda transferir.
    final algunDato = cuenta.banco.trim().isNotEmpty ||
        cuenta.cuenta.trim().isNotEmpty ||
        cuenta.beneficiario.trim().isNotEmpty;
    if (anticipo.activo || algunDato) {
      final problema = DatosBancarios.validar(
        banco: cuenta.banco,
        beneficiario: cuenta.beneficiario,
        cuenta: cuenta.cuenta,
      );
      if (problema != null) return problema;
    }
    if (anticipo.activo && anticipo.monto <= 0) {
      return 'Escribe el monto del anticipo (mayor a cero).';
    }
    if (anticipo.activo && (anticipo.horasLimite < 1 || anticipo.horasLimite > 168)) {
      return 'El plazo para enviar el comprobante debe estar entre 1 y 168 horas.';
    }
    return null;
  }

  Future<void> guardar({
    required String restaurantId,
    required bool ofreceDelivery,
    required DatosBancarios cuenta,
    required AnticipoConfig anticipo,
  }) async {
    final limpia = DatosBancarios(
      banco: cuenta.banco.trim(),
      beneficiario: cuenta.beneficiario.trim(),
      cuenta: DatosBancarios.limpiarCuenta(cuenta.cuenta),
    );
    await _firestore.collection('restaurants').doc(restaurantId).set({
      'ofreceDelivery': ofreceDelivery,
      'datosBancarios': limpia.toMap(),
      'anticipo': anticipo.toMap(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
