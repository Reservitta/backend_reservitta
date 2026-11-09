import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/operations_config.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/services/admin_alert_service.dart';
import 'package:reservitta/services/admin_push_token_service.dart';
import 'package:reservitta/services/operations_config_service.dart';
import 'package:reservitta/services/reminder_service.dart';
import 'package:reservitta/services/reservation_service.dart';
import 'package:reservitta/services/table_status_service.dart';
import 'package:reservitta/viewmodels/admin_operations_viewmodel.dart';
import 'package:reservitta/views/widgets/alert_settings_sheet.dart';

class _FakeProvider implements PushTokenProvider {
  bool permiso = true;
  String? token = 'token-1';
  bool falla = false;
  final renovaciones = StreamController<String>.broadcast();

  @override
  Future<bool> pedirPermiso() async {
    if (falla) throw Exception('sin FCM');
    return permiso;
  }

  @override
  Future<String?> obtenerToken() async => token;

  @override
  Stream<String> get tokenRenovado => renovaciones.stream;
}

class _CuentaPush implements AdminPushGateway {
  int enviados = 0;
  @override
  Future<void> enviar(AdminPushMessage mensaje) async => enviados++;
}

DateTime mx(int d, int h, [int mi = 0]) => DateTime.utc(2026, 10, d, h + 6, mi);

void main() {
  setUpAll(() => FakeFirebaseFirestore());

  group('Registro del dispositivo para recibir push (HU30-RF02)', () {
    late FakeFirebaseFirestore db;
    late _FakeProvider provider;
    late AdminPushTokenService servicio;

    setUp(() {
      db = FakeFirebaseFirestore();
      provider = _FakeProvider();
      servicio = AdminPushTokenService(
        firestore: db,
        provider: provider,
        plataforma: () => 'android',
      );
    });

    tearDown(() => servicio.dispose());

    Future<List<Map<String, dynamic>>> dispositivos() async {
      final snap =
          await db.collection('restaurants').doc('r1').collection('dispositivosAdmin').get();
      return [for (final d in snap.docs) {...d.data(), 'id': d.id}];
    }

    test('guarda el token del dispositivo en el restaurante', () async {
      final ok = await servicio.registrar(restauranteId: 'r1', usuarioId: 'admin1');
      expect(ok, isTrue);
      final lista = await dispositivos();
      expect(lista, hasLength(1));
      expect(lista.single['id'], 'token-1');
      expect(lista.single['usuarioId'], 'admin1');
      expect(lista.single['plataforma'], 'android');
    });

    test('registrar dos veces no duplica el dispositivo', () async {
      await servicio.registrar(restauranteId: 'r1', usuarioId: 'admin1');
      await servicio.registrar(restauranteId: 'r1', usuarioId: 'admin1');
      expect(await dispositivos(), hasLength(1));
    });

    test('si el usuario niega el permiso no guarda nada', () async {
      provider.permiso = false;
      expect(await servicio.registrar(restauranteId: 'r1', usuarioId: 'admin1'), isFalse);
      expect(await dispositivos(), isEmpty);
    });

    test('si no hay token no guarda nada', () async {
      provider.token = null;
      expect(await servicio.registrar(restauranteId: 'r1', usuarioId: 'admin1'), isFalse);
      expect(await dispositivos(), isEmpty);
    });

    test('un fallo de FCM no lanza: devuelve false', () async {
      provider.falla = true;
      expect(await servicio.registrar(restauranteId: 'r1', usuarioId: 'admin1'), isFalse);
    });

    test('cuando FCM renueva el token se guarda el nuevo', () async {
      await servicio.registrar(restauranteId: 'r1', usuarioId: 'admin1');
      provider.renovaciones.add('token-2');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final ids = (await dispositivos()).map((d) => d['id']).toSet();
      expect(ids, {'token-1', 'token-2'});
    });

    test('al quitar el dispositivo deja de recibir avisos', () async {
      await servicio.registrar(restauranteId: 'r1', usuarioId: 'admin1');
      await servicio.quitar('r1');
      expect(await dispositivos(), isEmpty);
    });
  });

  group('Procesamiento en el servidor', () {
    test('el ajuste se lee y se guarda', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('restaurants').doc('r1').set({'nombre': 'Miel'});
      final svc = OperationsConfigService(firestore: db);
      expect((await svc.cargar('r1')).procesamientoServidor, isFalse);
      await svc.guardar('r1', const OperationsConfig(procesamientoServidor: true));
      expect((await svc.cargar('r1')).procesamientoServidor, isTrue);
    });

    Future<int> alertasEnviadas({required bool servidor}) async {
      final db = FakeFirebaseFirestore();
      await db.collection('restaurants').doc('r1').set({
        'nombre': 'Miel',
        'zonaHoraria': 'America/Mexico_City',
        'configuracion': {'umbralAlertaMin': 30, 'procesamientoServidor': servidor},
      });
      final r = ReservationModel.create(
        id: 'a1',
        restauranteId: 'r1',
        usuarioId: 'u1',
        restauranteNombre: 'Miel',
        contactoNombre: 'Carlos',
        fechaLocal: '2026-10-30',
        inicio: mx(30, 14),
        duracionMin: 90,
        personas: 2,
        mesaIds: const ['m1'],
        mesasNombres: const ['M1'],
        estado: ReservationModel.estadoConfirmada,
      );
      await db.collection('reservations').doc('a1').set(r.toMap());
      final push = _CuentaPush();
      final vm = AdminOperationsViewModel(
        restaurantId: 'r1',
        reservas: ReservationService(firestore: db),
        mesasService: TableStatusService(firestore: db),
        configService: OperationsConfigService(firestore: db),
        alertService: AdminAlertService(firestore: db, gateway: push),
        reminderService: ReminderService(firestore: db),
        now: () => mx(30, 13, 45),
        tick: Duration.zero,
      );
      await vm.iniciar();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      vm.dispose();
      return push.enviados;
    }

    test('si lo procesa el servidor la app no registra ni envía alertas', () async {
      expect(await alertasEnviadas(servidor: true), 0);
    });

    test('si no, la app sigue enviándolas', () async {
      expect(await alertasEnviadas(servidor: false), 1);
    });

    test('al abrir el panel la app registra el dispositivo para recibir push', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('restaurants').doc('r1').set({'nombre': 'Miel'});
      final tokens = AdminPushTokenService(
        firestore: db,
        provider: _FakeProvider(),
        plataforma: () => 'web',
      );
      final vm = AdminOperationsViewModel(
        restaurantId: 'r1',
        reservas: ReservationService(firestore: db),
        mesasService: TableStatusService(firestore: db),
        configService: OperationsConfigService(firestore: db),
        alertService: AdminAlertService(firestore: db, gateway: _CuentaPush()),
        reminderService: ReminderService(firestore: db),
        tick: Duration.zero,
        sincronizar: false,
        usuarioId: () => 'admin1',
        tokens: tokens,
      );
      await vm.iniciar();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final snap = await db
          .collection('restaurants')
          .doc('r1')
          .collection('dispositivosAdmin')
          .get();
      expect(snap.docs.single.id, 'token-1');
      expect(snap.docs.single.data()['usuarioId'], 'admin1');
      vm.dispose();
    });
  });

  testWidgets('la hoja de ajustes permite activar el procesamiento en el servidor', (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final guardados = <OperationsConfig>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AlertSettingsSheet.mostrar(
              context,
              config: const OperationsConfig(),
              onGuardar: (n) async {
                guardados.add(n);
                return null;
              },
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('switch_procesamiento_servidor')));
    await tester.tap(find.byKey(const ValueKey('switch_procesamiento_servidor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('btn_guardar_ajustes_alertas')));
    await tester.pumpAndSettle();
    expect(guardados.single.procesamientoServidor, isTrue);
  });
}
