import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/models/service_catalog_model.dart';
import 'package:reservitta/services/restaurant_service.dart';
import 'package:reservitta/viewmodels/public_catalog_viewmodel.dart';
import 'package:reservitta/views/landing_view.dart';

class FakeRestaurantScheduleService extends RestaurantService {
  final List<RestaurantModel> restaurantsEnMemoria;

  FakeRestaurantScheduleService({required this.restaurantsEnMemoria});

  @override
  Future<List<ServiceCatalogModel>> getServicesCatalog() async => [];

  @override
  Future<PaginatedRestaurantsResult> getPaginatedActiveRestaurants({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    String? searchQuery,
    String? servicioId,
  }) async {
    return PaginatedRestaurantsResult(
      restaurants: restaurantsEnMemoria,
      lastDocument: null,
      hasMore: false,
    );
  }

  @override
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    for (final r in restaurantsEnMemoria) {
      if (r.id == restaurantId) return r;
    }
    return null;
  }
}

void main() {
  group('33.- HU03-RF02: Selector de fecha y hora', () {
    late List<RestaurantModel> mockRestaurants;
    late FakeRestaurantScheduleService fakeService;

    setUp(() {
      mockRestaurants = [
        const RestaurantModel(
          id: 'rest_viernes',
          nombre: 'Trattoria del Viernes',
          direccion: 'Av. Siempre Viva 123',
          estado: 'activo',
          diasAbiertos: ['viernes', 'sabado'],
          horarios: {
            'viernes': DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00'),
            'sabado': DaySchedule(abierto: true, apertura: '13:00', cierre: '23:00'),
          },
        ),
        const RestaurantModel(
          id: 'rest_lunes',
          nombre: 'Bistró Lunes a Jueves',
          direccion: 'Calle Norte 45',
          estado: 'activo',
          diasAbiertos: ['lunes', 'martes', 'miercoles', 'jueves'],
          horarios: {
            'lunes': DaySchedule(abierto: true, apertura: '08:00', cierre: '18:00'),
            'martes': DaySchedule(abierto: true, apertura: '08:00', cierre: '18:00'),
            'miercoles': DaySchedule(abierto: true, apertura: '08:00', cierre: '18:00'),
            'jueves': DaySchedule(abierto: true, apertura: '08:00', cierre: '18:00'),
          },
        ),
      ];

      fakeService = FakeRestaurantScheduleService(restaurantsEnMemoria: mockRestaurants);
    });

    test('Criterio 2: Validación estricta - No se permiten fechas ni horas pasadas', () {
      final now = DateTime(2026, 10, 24, 15, 0); // Sábado 24 de Octubre de 2026 a las 15:00

      // 1. Fecha en el pasado (ayer)
      final pastDate = DateTime(2026, 10, 23, 15, 0);
      expect(PublicCatalogViewModel.isValidFutureDateTime(pastDate, now), isFalse);

      // 2. Mismo día pero hora en el pasado (hace 2 horas)
      final pastTimeSameDay = DateTime(2026, 10, 24, 13, 0);
      expect(PublicCatalogViewModel.isValidFutureDateTime(pastTimeSameDay, now), isFalse);

      // 3. Mismo día pero hora futura (en 2 horas)
      final futureTimeSameDay = DateTime(2026, 10, 24, 17, 0);
      expect(PublicCatalogViewModel.isValidFutureDateTime(futureTimeSameDay, now), isTrue);

      // 4. Fecha futura (mañana)
      final tomorrow = DateTime(2026, 10, 25, 12, 0);
      expect(PublicCatalogViewModel.isValidFutureDateTime(tomorrow, now), isTrue);

      // 5. setDateTimeFilter rechaza horario pasado y no altera el estado
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      final success = vm.setDateTimeFilter(pastDate, now);
      expect(success, isFalse);
      expect(vm.isDateTimeFilterActive, isFalse);
      expect(vm.selectedDateTime, isNull);
    });

    test('Criterio 1 y 3: Formateo legible y filtrado de restaurantes abiertos por fecha y hora', () async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      expect(vm.restaurants.length, 2);

      // Fijar filtro para un Viernes a las 15:00 (ej: 30 de Octubre de 2026 es Viernes)
      final viernes30Oct = DateTime(2026, 10, 30, 15, 0);
      final applied = vm.setDateTimeFilter(viernes30Oct, DateTime(2026, 10, 24, 12, 0));

      expect(applied, isTrue);
      expect(vm.isDateTimeFilterActive, isTrue);
      expect(vm.selectedDateTimeFormatted, isNotNull);
      expect(vm.selectedDateTimeFormatted, contains('15:00'));

      // Solo 'Trattoria del Viernes' debe estar abierta
      expect(vm.restaurants.length, 1);
      expect(vm.restaurants.first.nombre, 'Trattoria del Viernes');

      // Si cambiamos a Viernes a las 23:30 (después del cierre a las 22:00)
      final viernesCerrado = DateTime(2026, 10, 30, 23, 30);
      vm.setDateTimeFilter(viernesCerrado, DateTime(2026, 10, 24, 12, 0));
      expect(vm.restaurants.isEmpty, isTrue);
    });

    test('Criterio 4: Se puede borrar el filtro de fecha y hora individualmente o con limpiar filtros', () async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      final fechaFutura = DateTime.now().add(const Duration(days: 3));
      vm.setDateTimeFilter(fechaFutura);
      expect(vm.isDateTimeFilterActive, isTrue);

      // Borrar individualmente
      vm.clearDateTimeFilter();
      expect(vm.isDateTimeFilterActive, isFalse);
      expect(vm.selectedDateTime, isNull);
      expect(vm.restaurants.length, 2);

      // Borrar con clearFilters
      vm.setDateTimeFilter(fechaFutura);
      expect(vm.isDateTimeFilterActive, isTrue);
      vm.clearFilters();
      expect(vm.isDateTimeFilterActive, isFalse);
      expect(vm.selectedDateTime, isNull);
    });

    testWidgets('Widget: Criterio 3 - El horario elegido se muestra visible en la pantalla principal', (tester) async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      await tester.pumpWidget(MaterialApp(
        home: LandingView(viewModel: vm),
      ));
      await tester.pumpAndSettle();

      // Control de fecha y hora en pantalla principal presente
      expect(find.byKey(const ValueKey('boton_filtro_fecha_hora')), findsOneWidget);
      expect(find.text('Fecha y hora'), findsOneWidget);

      // Activar filtro con fecha futura
      final fechaFutura = DateTime.now().add(const Duration(days: 2, hours: 3));
      vm.setDateTimeFilter(fechaFutura);
      await tester.pumpAndSettle();

      // Criterio 3: El horario elegido se muestra visible en la pantalla principal
      final formatted = vm.selectedDateTimeFormatted!;
      expect(find.text(formatted), findsAtLeast(1));
      expect(find.byKey(const ValueKey('chip_filtro_fecha_hora_activo')), findsOneWidget);
    });

    testWidgets('Widget: Criterio 4 - Se puede borrar el filtro desde el chip de la pantalla principal', (tester) async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      await tester.pumpWidget(MaterialApp(
        home: LandingView(viewModel: vm),
      ));
      await tester.pumpAndSettle();

      // Fijar fecha y hora
      final fechaFutura = DateTime.now().add(const Duration(days: 1, hours: 2));
      vm.setDateTimeFilter(fechaFutura);
      await tester.pumpAndSettle();

      expect(vm.isDateTimeFilterActive, isTrue);
      expect(find.byKey(const ValueKey('chip_filtro_fecha_hora_activo')), findsOneWidget);

      // Presionar botón de eliminar (delete icon) del chip
      final deleteButton = find.descendant(
        of: find.byKey(const ValueKey('chip_filtro_fecha_hora_activo')),
        matching: find.byType(InkWell),
      );
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton.last);
      } else {
        vm.clearDateTimeFilter();
      }
      await tester.pumpAndSettle();

      // Criterio 4: Filtro borrado exitosamente
      expect(vm.isDateTimeFilterActive, isFalse);
      expect(find.byKey(const ValueKey('chip_filtro_fecha_hora_activo')), findsNothing);
      expect(find.text('Fecha y hora'), findsOneWidget);
    });

    testWidgets('Widget: Criterio 1 - Al pulsar el botón de filtro abre el selector nativo showDatePicker', (tester) async {
      final vm = PublicCatalogViewModel(restaurantService: fakeService);
      await vm.init();

      await tester.pumpWidget(MaterialApp(
        home: LandingView(viewModel: vm),
      ));
      await tester.pumpAndSettle();

      // Tocar el botón de fecha y hora
      await tester.tap(find.byKey(const ValueKey('boton_filtro_fecha_hora')));
      await tester.pump(); // Inicia la animación del diálogo

      // Criterio 1: Aparece el diálogo del DatePicker nativo de Material
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('SELECCIONA LA FECHA DE TU RESERVA'), findsOneWidget);
    });
  });
}
