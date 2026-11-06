import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/services/notification_clients.dart';

void main() {
  group('Firebase Trigger Email Client (Colección mail)', () {
    test('Escribe documento en colección mail con to, subject, text y html', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final client = DefaultTransactionalEmailClient(
        firestore: fakeFirestore,
      );

      final success = await client.sendEmail(
        to: 'gaelq1074@gmail.com',
        subject: '¡Reserva confirmada en Miel Aurum!',
        body: 'Hola Gael, tu reserva para el 20 de Noviembre a las 14:00 ha sido confirmada.',
      );

      expect(success, isTrue);

      final snapshot = await fakeFirestore.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final docData = snapshot.docs.first.data();
      expect(docData['to'], equals(['gaelq1074@gmail.com']));

      final message = docData['message'] as Map<String, dynamic>;
      expect(message['subject'], equals('¡Reserva confirmada en Miel Aurum!'));
      expect(
        message['text'],
        contains('Hola Gael, tu reserva para el 20 de Noviembre a las 14:00 ha sido confirmada.'),
      );
      expect(message['html'], contains('Reservitta'));
      expect(message['html'], contains('Confirmación de Reserva'));
      expect(docData.containsKey('createdAt'), isTrue);
    });

    test('Lanza FormatException si el correo destinatario es inválido', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final client = DefaultTransactionalEmailClient(
        firestore: fakeFirestore,
      );

      expect(
        () => client.sendEmail(
          to: 'correo-sin-arroba',
          subject: 'Test',
          body: 'Test body',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

