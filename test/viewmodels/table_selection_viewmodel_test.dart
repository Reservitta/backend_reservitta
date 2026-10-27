import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/zona_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/repositories/table_repository.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/viewmodels/table_selection_viewmodel.dart';
import 'package:reservitta/viewmodels/time_slot_viewmodel.dart';

class _FakeReservations implements ReservationRepository {
  final List<ReservationModel> data;
  _FakeReservations([this.data = const []]);

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async => data
      .where(
        (r) =>
            r.restauranteId == restauranteId &&
            r.fechaLocal == fechaLocal &&
            r.bloqueaMesas,
      )
      .toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTables implements TableRepository {
  final List<MesaModel> mesas;
  _FakeTables(this.mesas);

  @override
  Future<List<MesaModel>> getMesas(String restaurantId) async => mesas;

  @override
  Future<List<ZonaModel>> getZonas(String restaurantId) async => const [];
}

MesaModel _mesa(
  String id,
  int cap, {
  bool combinable = false,
  List<String> con = const [],
  String? zona,
}) => MesaModel(
  id: id,
  nombre: id,
  capacidad: cap,
  combinable: combinable,
  combinableCon: con,
  x: 0,
  y: 0,
  zonaId: zona,
);

// a - b - c combinables en cadena; x y big no combinan.
final _mesas = [
  _mesa('a', 2, combinable: true, con: ['b']),
  _mesa('b', 2, combinable: true, con: ['a', 'c']),
  _mesa('c', 2, combinable: true, con: ['b']),
  _mesa('x', 4),
  _mesa('big', 6),
];

RestaurantModel _restaurant({List<MesaModel>? mesas, bool abierto = true}) {
  final h = DaySchedule(abierto: abierto, apertura: '12:00', cierre: '16:00');
  return RestaurantModel(
    id: 'r1',
    nombre: 'Test',
    estado: 'activo',
    mesas: mesas ?? _mesas,
    horarios: {
      for (final d in [
        'lunes',
        'martes',
        'miercoles',
        'jueves',
        'viernes',
        'sabado',
        'domingo',
      ])
        d: h,
    },
  );
}

ReservationModel _res(DateTime inicio, List<String> mesas, int duracion) {
  return ReservationModel.create(
    id: 'res_${mesas.join()}_${inicio.hour}',
    restauranteId: 'r1',
    fechaLocal: '2026-10-30',
    inicio: inicio,
    duracionMin: duracion,
    mesaIds: mesas,
    estado: ReservationModel.estadoConfirmada,
  );
}

void main() {
  final now = DateTime(2026, 10, 25, 10);
  final fecha = DateTime(2026, 10, 30);

  Future<(TableSelectionViewModel, List<List<String>>)> build({
    int personas = 4,
    int duracion = 90,
    List<MesaModel>? mesas,
    List<ReservationModel> reservations = const [],
    List<String> initial = const [],
    DateTime? fechaElegida,
  }) async {
    final commits = <List<String>>[];
    final vm = TableSelectionViewModel(
      restaurant: _restaurant(mesas: mesas),
      availability: AvailabilityService(
        _FakeReservations(reservations),
        now: () => now,
      ),
      fecha: fechaElegida ?? fecha,
      personas: personas,
      duracionMin: duracion,
      initialSelectedIds: initial,
      onSelectionChanged: (m) => commits.add(m.map((e) => e.id).toList()),
    );
    await vm.load();
    return (vm, commits);
  }

  MesaModel m(TableSelectionViewModel vm, String id) =>
      vm.plan.mesas.firstWhere((p) => p.mesa.id == id).mesa;

  group('HU10-RF02 estados visuales', () {
    test('mesas libres y que cubren al grupo están disponibles', () async {
      final (vm, _) = await build();
      expect(vm.stateOf(m(vm, 'x')), TableVisualState.disponible);
      expect(vm.stateOf(m(vm, 'big')), TableVisualState.disponible);
    });

    test('mesas con capacidad menor al grupo son no adecuadas', () async {
      final (vm, _) = await build();
      expect(vm.stateOf(m(vm, 'a')), TableVisualState.noAdecuada);
    });

    test('mesas sin horarios libres están ocupadas', () async {
      final (vm, _) = await build(
        reservations: [
          _res(DateTime(2026, 10, 30, 12), ['x'], 240),
        ],
      );
      expect(vm.stateOf(m(vm, 'x')), TableVisualState.ocupada);
    });

    test('una fecha cerrada deja todas como no disponibles', () async {
      final (vm, _) = await build(fechaElegida: DateTime(2026, 10, 1));
      expect(vm.stateOf(m(vm, 'x')), TableVisualState.noDisponible);
    });

    test('la mesa elegida se ve seleccionada', () async {
      final (vm, _) = await build();
      await vm.onTapMesa(m(vm, 'x'));
      expect(vm.stateOf(m(vm, 'x')), TableVisualState.seleccionada);
    });
  });

  group('HU10-RF03 selección de una mesa', () {
    test('tocar una mesa disponible la selecciona y la guarda', () async {
      final (vm, commits) = await build();
      await vm.onTapMesa(m(vm, 'x'));
      expect(vm.selected.map((e) => e.id), ['x']);
      expect(vm.isValidSelection, isTrue);
      expect(commits.last, ['x']);
    });

    test('tocar otra mesa cambia la selección', () async {
      final (vm, commits) = await build();
      await vm.onTapMesa(m(vm, 'x'));
      await vm.onTapMesa(m(vm, 'big'));
      expect(vm.selected.map((e) => e.id), ['big']);
      expect(commits.last, ['big']);
    });

    test('tocar de nuevo la deselecciona y vacía el borrador', () async {
      final (vm, commits) = await build();
      await vm.onTapMesa(m(vm, 'x'));
      await vm.onTapMesa(m(vm, 'x'));
      expect(vm.selected, isEmpty);
      expect(commits.last, isEmpty);
    });

    test('una mesa no adecuada no se selecciona e informa el motivo', () async {
      final (vm, _) = await build();
      await vm.onTapMesa(m(vm, 'a'));
      expect(vm.selected, isEmpty);
      expect(vm.message, contains('capacidad para 2'));
      expect(vm.message, contains('Combinar mesas'));
    });

    test('una mesa ocupada no se selecciona e informa el motivo', () async {
      final (vm, _) = await build(
        reservations: [
          _res(DateTime(2026, 10, 30, 12), ['x'], 240),
        ],
      );
      await vm.onTapMesa(m(vm, 'x'));
      expect(vm.selected, isEmpty);
      expect(vm.message, contains('no tiene horarios libres'));
    });

    test('restaura la selección previa al volver al paso', () async {
      final (vm, _) = await build(initial: ['x']);
      expect(vm.selected.map((e) => e.id), ['x']);
    });

    test('no restaura una mesa que ya no está disponible', () async {
      final (vm, _) = await build(
        initial: ['x'],
        reservations: [
          _res(DateTime(2026, 10, 30, 12), ['x'], 240),
        ],
      );
      expect(vm.selected, isEmpty);
    });
  });

  group('HU10-RF04 combinación de mesas', () {
    test(
      'en modo combinar solo las mesas combinables quedan disponibles',
      () async {
        final (vm, _) = await build();
        vm.setCombineMode(true);
        expect(vm.stateOf(m(vm, 'a')), TableVisualState.disponible);
        expect(vm.stateOf(m(vm, 'x')), TableVisualState.noAdecuada);
        await vm.onTapMesa(m(vm, 'x'));
        expect(vm.message, contains('no se puede combinar'));
      },
    );

    test('muestra la capacidad total mientras se selecciona', () async {
      final (vm, _) = await build();
      vm.setCombineMode(true);
      await vm.onTapMesa(m(vm, 'a'));
      expect(vm.capacidadSeleccionada, 2);
      await vm.onTapMesa(m(vm, 'b'));
      expect(vm.capacidadSeleccionada, 4);
    });

    test('solo es válida si la capacidad cubre al grupo', () async {
      final (vm, commits) = await build();
      vm.setCombineMode(true);
      await vm.onTapMesa(m(vm, 'a'));
      expect(vm.isValidSelection, isFalse);
      expect(commits.last, isEmpty);
      await vm.onTapMesa(m(vm, 'b'));
      expect(vm.isValidSelection, isTrue);
      expect(commits.last, ['a', 'b']);
    });

    test(
      'rechaza una mesa que no se puede combinar con las elegidas',
      () async {
        final (vm, _) = await build();
        vm.setCombineMode(true);
        await vm.onTapMesa(m(vm, 'a'));
        await vm.onTapMesa(m(vm, 'c'));
        expect(vm.selected.map((e) => e.id), ['a']);
        expect(vm.message, contains('no se puede combinar con a'));
      },
    );

    test('un segundo toque durante la verificación no se pierde', () async {
      final (vm, _) = await build();
      vm.setCombineMode(true);
      final primero = vm.onTapMesa(m(vm, 'a'));
      final segundo = vm.onTapMesa(m(vm, 'b')); // llega mientras verifica 'a'
      await Future.wait([primero, segundo]);
      expect(vm.selected.map((e) => e.id), ['a', 'b']);
    });

    test('se puede quitar una mesa de la combinación', () async {
      final (vm, commits) = await build();
      vm.setCombineMode(true);
      await vm.onTapMesa(m(vm, 'a'));
      await vm.onTapMesa(m(vm, 'b'));
      vm.removeMesa('b');
      expect(vm.selected.map((e) => e.id), ['a']);
      expect(commits.last, isEmpty);
    });

    test('exige que las mesas estén libres a la vez', () async {
      // a libre solo de 14:00 a 16:00; b libre solo de 12:00 a 14:00.
      final (vm, _) = await build(
        duracion: 120,
        reservations: [
          _res(DateTime(2026, 10, 30, 12), ['a'], 120),
          _res(DateTime(2026, 10, 30, 14), ['b'], 120),
        ],
      );
      vm.setCombineMode(true);
      await vm.onTapMesa(m(vm, 'a'));
      await vm.onTapMesa(m(vm, 'b'));
      expect(vm.selected.map((e) => e.id), ['a']);
      expect(vm.message, contains('horario libre en común'));
    });

    test('cambiar de modo limpia la selección', () async {
      final (vm, commits) = await build();
      await vm.onTapMesa(m(vm, 'x'));
      vm.setCombineMode(true);
      expect(vm.selected, isEmpty);
      expect(commits.last, isEmpty);
    });

    test(
      'si solo hay combinaciones, el modo combinar se activa solo',
      () async {
        final (vm, _) = await build(mesas: _mesas.take(3).toList());
        expect(vm.needsCombination, isTrue);
        expect(vm.combineMode, isTrue);
        expect(vm.hasIndividualOptions, isFalse);
      },
    );
  });

  group('HU09-RF03 mensajes sin mesas adecuadas', () {
    test(
      'sin mesas libres sugiere cambiar fecha, duración o personas',
      () async {
        final (vm, _) = await build(
          personas: 3,
          reservations: [
            for (final id in ['a', 'b', 'c', 'x', 'big'])
              _res(DateTime(2026, 10, 30, 12), [id], 240),
          ],
        );
        final msg = vm.emptyMessage!;
        expect(msg.title, 'No hay mesas adecuadas');
        expect(msg.suggestions.join(' '), contains('fecha'));
        expect(msg.suggestions.join(' '), contains('duración'));
        expect(msg.suggestions.join(' '), contains('personas'));
      },
    );

    test(
      'si el grupo excede la capacidad informa el máximo permitido',
      () async {
        final (vm, _) = await build(personas: 40);
        final msg = vm.emptyMessage!;
        expect(msg.title, contains('excede la capacidad'));
        expect(msg.maxPersonas, 6);
        expect(msg.detail, contains('6 personas'));
      },
    );

    test('con capacidadMaxima registrada se usa ese máximo', () {
      final msg = TableEmptyMessage.noTables(personas: 50, capacidadMaxima: 30);
      expect(msg.maxPersonas, 30);
    });

    test('una fecha no reservable explica el motivo', () async {
      final (vm, _) = await build(fechaElegida: DateTime(2026, 10, 1));
      final msg = vm.emptyMessage!;
      expect(msg.detail, contains('fecha de hoy'));
      expect(msg.suggestions, ['Cambiar la fecha de la visita']);
    });

    test('un restaurante sin mesas lo indica', () async {
      final (vm, _) = await build(mesas: const []);
      expect(vm.emptyMessage!.title, contains('Aún no hay mesas'));
    });

    test('hay mesas adecuadas: no hay mensaje', () async {
      final (vm, _) = await build();
      expect(vm.emptyMessage, isNull);
    });
  });

  group('HU10-RF02 lista alternativa sin plano', () {
    test('mesas sin posición se devuelven para mostrarlas en lista', () async {
      final sinPosicion = [
        const MesaModel(id: 'p', nombre: 'p', capacidad: 4),
        const MesaModel(id: 'q', nombre: 'q', capacidad: 6),
      ];
      final (vm, _) = await build(mesas: sinPosicion);
      expect(vm.hasPlan, isFalse);
      expect(vm.plan.mesas.map((p) => p.mesa.id), ['p', 'q']);
      await vm.onTapMesa(vm.plan.mesas.first.mesa);
      expect(vm.selected.map((e) => e.id), ['p']);
    });
  });

  group('HU11-RF02 TimeSlotViewModel', () {
    TimeSlotViewModel slots({
      List<ReservationModel> reservations = const [],
      DateTime? initial,
      void Function(TimeSlot)? onSelected,
    }) {
      return TimeSlotViewModel(
        restaurant: _restaurant(),
        availability: AvailabilityService(
          _FakeReservations(reservations),
          now: () => now,
        ),
        fecha: fecha,
        duracionMin: 90,
        mesaIds: ['x'],
        initialInicio: initial,
        onSelected: onSelected ?? (_) {},
      );
    }

    test('carga los horarios ordenados de menor a mayor', () async {
      final vm = slots();
      await vm.load();
      final inicios = vm.slots.map((s) => s.inicio).toList();
      expect([...inicios]..sort(), inicios);
      expect(vm.slots.first.inicio, DateTime(2026, 10, 30, 12));
    });

    test('elegir un horario lo marca y lo guarda en el borrador', () async {
      TimeSlot? guardado;
      final vm = slots(onSelected: (s) => guardado = s);
      await vm.load();
      vm.select(vm.slots[2]);
      expect(vm.selected, vm.slots[2]);
      expect(guardado, vm.slots[2]);
    });

    test('conserva el horario ya elegido al volver al paso', () async {
      final vm = slots(initial: DateTime(2026, 10, 30, 13));
      await vm.load();
      expect(vm.selected!.inicio, DateTime(2026, 10, 30, 13));
    });

    test('sin horarios libres lo indica', () async {
      final vm = slots(
        reservations: [
          _res(DateTime(2026, 10, 30, 12), ['x'], 240),
        ],
      );
      await vm.load();
      expect(vm.hasNoSlots, isTrue);
    });
  });

  group('Máximo de personas según las mesas reales', () {
    test('maxGroupSize usa la mesa más grande o el mayor grupo combinable', () {
      expect(AvailabilityService.maxGroupSize(_mesas), 6);
      expect(AvailabilityService.maxGroupSize(const []), 0);
      expect(
        AvailabilityService.maxGroupSize([
          _mesa('p', 4, combinable: true, con: ['q']),
          _mesa('q', 4, combinable: true, con: ['p']),
          _mesa('r', 6),
        ]),
        8,
      );
    });

    test('las mesas no enlazadas no suman entre sí', () {
      expect(
        AvailabilityService.maxGroupSize([
          _mesa('p', 4, combinable: true),
          _mesa('q', 4, combinable: true),
        ]),
        4,
      );
    });

    test('el borrador limita las personas a lo que sientan las mesas', () async {
      final vm = ReservationDraftViewModel(
        restaurant: _restaurant(mesas: const []),
        tableRepository: _FakeTables(_mesas),
        clock: () => now,
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.maxPartySize, 6);
      vm.setPartySize(7);
      expect(vm.draft.personas, 2);
      vm.setPartySize(6);
      expect(vm.draft.personas, 6);
    });

    test('sin mesas registradas se conserva el máximo por defecto', () async {
      final vm = ReservationDraftViewModel(
        restaurant: _restaurant(mesas: const []),
        tableRepository: _FakeTables(const []),
        clock: () => now,
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.maxPartySize, 20);
    });
  });

  group('Borrador de reserva: pasos 4 y 5', () {
    ReservationDraftViewModel draft() =>
        ReservationDraftViewModel(restaurant: _restaurant(), clock: () => now);

    test('guardar la mesa elegida habilita Continuar en el paso de mesa', () {
      final vm = draft()..goToStep(4);
      expect(vm.canAdvanceCurrentStep, isFalse);
      vm.setSelectedTables([_mesas[3]]);
      expect(vm.draft.mesaIds, ['x']);
      expect(vm.draft.mesasNombres, ['x']);
      expect(vm.canAdvanceCurrentStep, isTrue);
    });

    test('Continuar en el paso de horario exige elegir uno', () {
      final vm = draft()..goToStep(5);
      expect(vm.canAdvanceCurrentStep, isFalse);
      vm.selectTime(
        TimeSlot(
          inicio: DateTime(2026, 10, 30, 14),
          fin: DateTime(2026, 10, 30, 15, 30),
        ),
      );
      expect(vm.draft.horario, const TimeOfDay(hour: 14, minute: 0));
      expect(vm.canAdvanceCurrentStep, isTrue);
    });

    test('cambiar de mesa invalida el horario elegido', () {
      final vm = draft();
      vm.setSelectedTables([_mesas[3]]);
      vm.selectTime(
        TimeSlot(
          inicio: DateTime(2026, 10, 30, 14),
          fin: DateTime(2026, 10, 30, 15, 30),
        ),
      );
      vm.setSelectedTables([_mesas[4]]);
      expect(vm.draft.horario, isNull);
    });

    test('cambiar personas, duración o fecha invalida mesa y horario', () {
      for (final cambio in <void Function(ReservationDraftViewModel)>[
        (v) => v.incrementPartySize(),
        (v) => v.selectDuration(120),
        (v) => v.selectDate(DateTime(2026, 11, 2)),
      ]) {
        final vm = draft()..selectDate(fecha);
        vm.setSelectedTables([_mesas[3]]);
        vm.selectTime(
          TimeSlot(
            inicio: DateTime(2026, 10, 30, 14),
            fin: DateTime(2026, 10, 30, 15, 30),
          ),
        );
        cambio(vm);
        expect(vm.draft.mesaIds, isEmpty);
        expect(vm.draft.horario, isNull);
      }
    });

    test('el rango del horario suma la duración al inicio', () {
      final vm = draft()..selectDate(fecha);
      vm.selectTime(
        TimeSlot(
          inicio: DateTime(2026, 10, 30, 14),
          fin: DateTime(2026, 10, 30, 15, 30),
        ),
      );
      expect(vm.draft.formattedTimeRange, '14:00 – 15:30');
    });

    test('se puede avanzar hasta el paso 5 y no más', () {
      final vm = draft()..goToStep(4);
      vm.setSelectedTables([_mesas[3]]);
      vm.nextStep();
      expect(vm.currentStep, 5);
      vm.selectTime(
        TimeSlot(
          inicio: DateTime(2026, 10, 30, 14),
          fin: DateTime(2026, 10, 30, 15, 30),
        ),
      );
      vm.nextStep();
      expect(vm.currentStep, 5);
    });
  });
}
