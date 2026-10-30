import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservitta/models/booking_models.dart';
import 'package:reservitta/models/branch_model.dart';
import 'package:reservitta/models/mesa_model.dart';
import 'package:reservitta/models/reservation_draft_model.dart';
import 'package:reservitta/models/reservation_model.dart';
import 'package:reservitta/models/restaurant_model.dart';
import 'package:reservitta/repositories/reservation_repository.dart';
import 'package:reservitta/services/availability_service.dart';
import 'package:reservitta/services/reservation_booking_service.dart';
import 'package:reservitta/viewmodels/reservation_draft_viewmodel.dart';
import 'package:reservitta/views/reservation_confirmation_view.dart';
import 'package:reservitta/views/reservation_flow_view.dart';
import 'package:reservitta/views/widgets/contact_form_step.dart';
import 'package:reservitta/views/widgets/reservation_summary_step.dart';

class _MockReservationRepo implements ReservationRepository {
  final List<ReservationModel> created = [];

  @override
  Future<List<ReservationModel>> getActiveReservationsByRestaurantAndDate({
    required String restauranteId,
    required String fechaLocal,
  }) async =>
      const [];

  @override
  Future<ReservationModel> createReservationVerified(
    ReservationModel res, {
    int margenLimpiezaMin = 0,
  }) async {
    final saved = res.copyWith(id: 'res_test_123');
    created.add(saved);
    return saved;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RestaurantModel _buildRestaurant() {
  const h = DaySchedule(abierto: true, apertura: '12:00', cierre: '22:00');
  return RestaurantModel(
    id: 'rest_aurum',
    nombre: 'Miel Aurum',
    direccion: 'Av. Hidalgo 100, Centro',
    telefono: '418-123-4567',
    estado: 'activo',
    mesas: [
      MesaModel(id: 'M1', nombre: 'Mesa 1', capacidad: 4, forma: MesaModel.formaCuadrada),
    ],
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sucursal = const BranchModel(
    id: 'br_centro',
    nombre: 'Miel Aurum — Centro',
    direccion: 'Av. Hidalgo 100, Centro',
    telefono: '418-123-4567',
    esPrincipal: true,
  );

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  ReservationDraftViewModel createReadyViewModel({
    bool isAuthenticated = false,
    int phoneDigits = 10,
  }) {
    final r = _buildRestaurant();
    final vm = ReservationDraftViewModel(
      restaurant: r,
      phoneDigits: phoneDigits,
      clock: () => DateTime(2026, 10, 24, 10),
    );
    vm.selectBranch(sucursal);
    vm.selectDate(DateTime(2026, 10, 30));
    vm.selectDuration(90);
    vm.setPartySize(2);
    vm.setSelectedTables([r.mesas.first]);
    vm.selectTime(TimeSlot(
      inicio: DateTime(2026, 10, 30, 14, 0),
      fin: DateTime(2026, 10, 30, 15, 30),
    ));
    vm.goToStep(7);
    return vm;
  }

  group('HU13-RF01: Formulario de datos de contacto', () {
    testWidgets('Campos requeridos muestran placeholders de ejemplo', (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContactFormStep(
                draft: vm.draft,
                isAuthenticated: false,
                onNameChanged: vm.setContactName,
                onEmailChanged: vm.setContactEmail,
                onPhoneChanged: vm.setContactPhone,
                onCreateAccountChanged: vm.setCreateAccount,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Placeholders de ejemplo
      expect(find.text('Ej. María López García'), findsOneWidget);
      expect(find.text('Ej. maria@correo.com'), findsOneWidget);
      expect(find.text('Ej. 4181234567'), findsOneWidget);
    });

    testWidgets('Muestra stepper de progreso con Fecha, Duración, Personas, Mesa, Horario, Datos',
        (tester) async {
      setLargeScreen(tester);
      final r = _buildRestaurant();
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationFlowView(
            restaurant: r,
            viewModel: vm,
            enableContactStep: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Stepper contiene todos los pasos del flujo hasta Datos
      expect(find.text('Fecha'), findsOneWidget);
      expect(find.text('Duración'), findsOneWidget);
      expect(find.text('Personas'), findsOneWidget);
      expect(find.text('Mesa'), findsOneWidget);
      expect(find.text('Horario'), findsOneWidget);
      expect(find.text('Datos'), findsOneWidget);
    });

    testWidgets('Botón Continuar permanece deshabilitado hasta que los 3 campos sean válidos',
        (tester) async {
      setLargeScreen(tester);
      final r = _buildRestaurant();
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationFlowView(
            restaurant: r,
            viewModel: vm,
            enableContactStep: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      FilledButton getContinuarButton() =>
          tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_step_7')));

      // Inicialmente vacío: deshabilitado
      expect(getContinuarButton().onPressed, isNull);

      // Solo nombre: aún deshabilitado
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_nombre')),
        'Juan Pérez',
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNull);

      // Nombre y correo inválido: aún deshabilitado
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_correo')),
        'correo_invalido',
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNull);

      // Correo válido, sin teléfono: aún deshabilitado
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_correo')),
        'juan@test.com',
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNull);

      // Teléfono incompleto (menos de 10 dígitos): aún deshabilitado
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_telefono')),
        '418123',
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNull);

      // Teléfono válido de 10 dígitos: se habilita
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_telefono')),
        '4181234567',
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNotNull);
    });

    testWidgets('Validación de teléfono configurable (ej. 8 dígitos)', (tester) async {
      setLargeScreen(tester);
      final r = _buildRestaurant();
      final vm = createReadyViewModel(phoneDigits: 8);

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationFlowView(
            restaurant: r,
            viewModel: vm,
            enableContactStep: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      FilledButton getContinuarButton() =>
          tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_step_7')));

      await tester.enterText(
        find.byKey(const ValueKey('input_contact_nombre')),
        'Ana Gómez',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_correo')),
        'ana@test.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_telefono')),
        '1234567', // 7 dígitos -> no válido
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('input_contact_telefono')),
        '12345678', // exactamente 8 dígitos -> válido
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNotNull);
    });

    testWidgets('Si el visitante tiene sesión iniciada, los campos se prellenan y son editables',
        (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();
      vm.prefillContact(
        nombre: 'Carlos Santana',
        correo: 'carlos@test.com',
        telefono: '4187654321',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContactFormStep(
                draft: vm.draft,
                isAuthenticated: true,
                onNameChanged: vm.setContactName,
                onEmailChanged: vm.setContactEmail,
                onPhoneChanged: vm.setContactPhone,
                onCreateAccountChanged: vm.setCreateAccount,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Campos prellenados
      expect(find.text('Carlos Santana'), findsOneWidget);
      expect(find.text('carlos@test.com'), findsOneWidget);
      expect(find.text('4187654321'), findsOneWidget);

      // Son editables
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_nombre')),
        'Carlos Santana Editado',
      );
      await tester.pumpAndSettle();
      expect(vm.draft.contactoNombre, equals('Carlos Santana Editado'));
    });

    testWidgets('Los datos se guardan en el borrador de reserva', (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContactFormStep(
                draft: vm.draft,
                isAuthenticated: false,
                onNameChanged: vm.setContactName,
                onEmailChanged: vm.setContactEmail,
                onPhoneChanged: vm.setContactPhone,
                onCreateAccountChanged: vm.setCreateAccount,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('input_contact_nombre')),
        'Laura Méndez',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_correo')),
        'laura@correo.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_telefono')),
        '4189998877',
      );
      await tester.pumpAndSettle();

      expect(vm.draft.contactoNombre, equals('Laura Méndez'));
      expect(vm.draft.contactoCorreo, equals('laura@correo.com'));
      expect(vm.draft.contactoTelefono, equals('4189998877'));
      expect(vm.draft.hasValidContactData, isTrue);
    });

    testWidgets('En los datos del flujo (resumen y confirmación) aparecen el teléfono y correo',
        (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();
      vm.setContactName('Pedro Infante');
      vm.setContactEmail('pedro@test.com');
      vm.setContactPhone('4181112233');

      // 1. En el resumen de reserva (ReservationSummaryStep)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReservationSummaryStep(
                draft: vm.draft,
                onEditStep: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('summary_card_contacto_correo')), findsOneWidget);
      expect(find.byKey(const ValueKey('summary_card_contacto_telefono')), findsOneWidget);
      expect(find.text('pedro@test.com'), findsOneWidget);
      expect(find.text('4181112233'), findsOneWidget);

      // 2. En la pantalla de confirmación (ReservationConfirmationView)
      final reserva = ReservationModel.create(
        id: 'res_001',
        restauranteId: 'r1',
        usuarioId: 'u1',
        restauranteNombre: 'Miel Aurum',
        contactoNombre: 'Pedro Infante',
        contactoCorreo: 'pedro@test.com',
        contactoTelefono: '4181112233',
        fechaLocal: '2026-10-30',
        inicio: DateTime(2026, 10, 30, 14, 0),
        duracionMin: 90,
        personas: 2,
        mesaIds: ['M1'],
        mesasNombres: ['Mesa 1'],
        estado: ReservationModel.estadoConfirmada,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationConfirmationView(reservation: reserva),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('pedro@test.com'), findsOneWidget);
      expect(find.text('4181112233'), findsOneWidget);
    });
  });

  group('HU13-RF02: Checkbox para crear cuenta', () {
    testWidgets('Checkbox "Quiero crear una cuenta para guardar mis reservas", no marcado por defecto',
        (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContactFormStep(
                draft: vm.draft,
                isAuthenticated: false,
                onNameChanged: vm.setContactName,
                onEmailChanged: vm.setContactEmail,
                onPhoneChanged: vm.setContactPhone,
                onCreateAccountChanged: vm.setCreateAccount,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxTile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('checkbox_crear_cuenta')),
      );
      expect(checkboxTile.value, isFalse);
      expect(find.text('Quiero crear una cuenta para guardar mis reservas'), findsOneWidget);
      expect(vm.draft.crearCuenta, isFalse);
    });

    testWidgets('No se muestra si el visitante ya tiene sesión iniciada', (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContactFormStep(
                draft: vm.draft,
                isAuthenticated: true, // Con sesión activa
                onNameChanged: vm.setContactName,
                onEmailChanged: vm.setContactEmail,
                onPhoneChanged: vm.setContactPhone,
                onCreateAccountChanged: vm.setCreateAccount,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('container_crear_cuenta')), findsNothing);
      expect(find.byKey(const ValueKey('checkbox_crear_cuenta')), findsNothing);
    });

    testWidgets('Marcarlo no agrega campos si showPasswordFields es false (HU13 aislado)',
        (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ContactFormStep(
                    draft: vm.draft,
                    isAuthenticated: false,
                    showPasswordFields: false, // HU13 estricto
                    onNameChanged: vm.setContactName,
                    onEmailChanged: vm.setContactEmail,
                    onPhoneChanged: vm.setContactPhone,
                    onCreateAccountChanged: (val) {
                      setState(() {
                        vm.setCreateAccount(val);
                      });
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('checkbox_crear_cuenta')));
      await tester.pumpAndSettle();

      expect(vm.draft.crearCuenta, isTrue);
      expect(find.byKey(const ValueKey('container_password')), findsNothing);
    });

    testWidgets('El estado se guarda en el borrador de reserva', (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ContactFormStep(
                    draft: vm.draft,
                    isAuthenticated: false,
                    onNameChanged: vm.setContactName,
                    onEmailChanged: vm.setContactEmail,
                    onPhoneChanged: vm.setContactPhone,
                    onCreateAccountChanged: (v) {
                      setState(() => vm.setCreateAccount(v));
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Inicial: false
      expect(vm.draft.crearCuenta, isFalse);

      // Marcar
      await tester.tap(find.byKey(const ValueKey('checkbox_crear_cuenta')));
      await tester.pumpAndSettle();
      expect(vm.draft.crearCuenta, isTrue);

      // Desmarcar
      await tester.tap(find.byKey(const ValueKey('checkbox_crear_cuenta')));
      await tester.pumpAndSettle();
      expect(vm.draft.crearCuenta, isFalse);
    });
  });

  group('HU14-RF01: Captura de contraseña condicionada a la creación de cuenta', () {
    testWidgets('Si el checkbox de HU13 está marcado, se muestran Contraseña y Confirmar contraseña',
        (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ContactFormStep(
                    draft: vm.draft,
                    isAuthenticated: false,
                    showPasswordFields: true,
                    onNameChanged: vm.setContactName,
                    onEmailChanged: vm.setContactEmail,
                    onPhoneChanged: vm.setContactPhone,
                    onCreateAccountChanged: (v) {
                      setState(() => vm.setCreateAccount(v));
                    },
                    onPasswordChanged: vm.setPassword,
                    onConfirmPasswordChanged: vm.setConfirmPassword,
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Sin marcar: no se muestran
      expect(find.byKey(const ValueKey('container_password')), findsNothing);
      expect(find.byKey(const ValueKey('input_password')), findsNothing);
      expect(find.byKey(const ValueKey('input_confirm_password')), findsNothing);

      // Marcar checkbox
      await tester.tap(find.byKey(const ValueKey('checkbox_crear_cuenta')));
      await tester.pumpAndSettle();

      // Marcado: se muestran ambos campos
      expect(find.byKey(const ValueKey('container_password')), findsOneWidget);
      expect(find.byKey(const ValueKey('input_password')), findsOneWidget);
      expect(find.byKey(const ValueKey('input_confirm_password')), findsOneWidget);
    });

    testWidgets('Checks interactivos de requisitos de contraseña (8 caracteres, letra, número)',
        (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();
      vm.setCreateAccount(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContactFormStep(
                draft: vm.draft,
                isAuthenticated: false,
                showPasswordFields: true,
                onNameChanged: vm.setContactName,
                onEmailChanged: vm.setContactEmail,
                onPhoneChanged: vm.setContactPhone,
                onCreateAccountChanged: vm.setCreateAccount,
                onPasswordChanged: vm.setPassword,
                onConfirmPasswordChanged: vm.setConfirmPassword,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('password_constraints')), findsOneWidget);

      Row getConstraintRow(String key) =>
          tester.widget<Row>(find.byKey(ValueKey(key)));

      bool isIconChecked(String key) {
        final row = getConstraintRow(key);
        final iconWidget = row.children.first as Icon;
        return iconWidget.icon == Icons.check_circle;
      }

      // Vacío: ninguno cumplido
      expect(isIconChecked('constraint_min_length'), isFalse);
      expect(isIconChecked('constraint_has_letter'), isFalse);
      expect(isIconChecked('constraint_has_number'), isFalse);

      // Solo números cortos "1234"
      await tester.enterText(find.byKey(const ValueKey('input_password')), '1234');
      await tester.pumpAndSettle();
      expect(isIconChecked('constraint_min_length'), isFalse);
      expect(isIconChecked('constraint_has_letter'), isFalse);
      expect(isIconChecked('constraint_has_number'), isTrue);

      // Letras y números pero menos de 8 "Abc1"
      await tester.enterText(find.byKey(const ValueKey('input_password')), 'Abc1');
      await tester.pumpAndSettle();
      expect(isIconChecked('constraint_min_length'), isFalse);
      expect(isIconChecked('constraint_has_letter'), isTrue);
      expect(isIconChecked('constraint_has_number'), isTrue);

      // Cumple los 3 requisitos: 8 caracteres con letra y número "Clave123"
      await tester.enterText(find.byKey(const ValueKey('input_password')), 'Clave123');
      await tester.pumpAndSettle();
      expect(isIconChecked('constraint_min_length'), isTrue);
      expect(isIconChecked('constraint_has_letter'), isTrue);
      expect(isIconChecked('constraint_has_number'), isTrue);
    });

    testWidgets('Al desmarcar el checkbox, los campos se ocultan y su valor se descarta',
        (tester) async {
      setLargeScreen(tester);
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ContactFormStep(
                    draft: vm.draft,
                    isAuthenticated: false,
                    showPasswordFields: true,
                    onNameChanged: vm.setContactName,
                    onEmailChanged: vm.setContactEmail,
                    onPhoneChanged: vm.setContactPhone,
                    onCreateAccountChanged: (v) {
                      setState(() => vm.setCreateAccount(v));
                    },
                    onPasswordChanged: vm.setPassword,
                    onConfirmPasswordChanged: vm.setConfirmPassword,
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Marcar checkbox y escribir contraseña
      await tester.tap(find.byKey(const ValueKey('checkbox_crear_cuenta')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('input_password')), 'Secreta1');
      await tester.enterText(
        find.byKey(const ValueKey('input_confirm_password')),
        'Secreta1',
      );
      await tester.pumpAndSettle();

      expect(vm.password, equals('Secreta1'));
      expect(vm.confirmPassword, equals('Secreta1'));

      // Desmarcar checkbox
      await tester.tap(find.byKey(const ValueKey('checkbox_crear_cuenta')));
      await tester.pumpAndSettle();

      // Campos ocultos
      expect(find.byKey(const ValueKey('container_password')), findsNothing);

      // Valores descartados tanto en ViewModel como en borradores
      expect(vm.password, isEmpty);
      expect(vm.confirmPassword, isEmpty);
    });

    testWidgets('Continuar valida contraseña y confirmación cuando se solicita crear cuenta',
        (tester) async {
      setLargeScreen(tester);
      final r = _buildRestaurant();
      final vm = createReadyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationFlowView(
            restaurant: r,
            viewModel: vm,
            enableContactStep: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      FilledButton getContinuarButton() =>
          tester.widget<FilledButton>(find.byKey(const ValueKey('btn_continuar_step_7')));

      // Llenar datos de contacto válidos
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_nombre')),
        'Roberto Gómez',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_correo')),
        'roberto@test.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_telefono')),
        '4181234567',
      );
      await tester.pumpAndSettle();

      // Sin pedir cuenta, el botón está habilitado
      expect(getContinuarButton().onPressed, isNotNull);

      // Marcar crear cuenta: ahora exige contraseñas válidas, botón se deshabilita
      await tester.tap(find.byKey(const ValueKey('checkbox_crear_cuenta')));
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNull);

      // Contraseña inválida (< 8 caracteres): sigue deshabilitado
      await tester.enterText(find.byKey(const ValueKey('input_password')), 'Pass1');
      await tester.enterText(
        find.byKey(const ValueKey('input_confirm_password')),
        'Pass1',
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNull);

      // Contraseña válida pero confirmación no coincide: sigue deshabilitado
      await tester.enterText(find.byKey(const ValueKey('input_password')), 'Password123');
      await tester.enterText(
        find.byKey(const ValueKey('input_confirm_password')),
        'Password999',
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNull);

      // Contraseña y confirmación coincidentes y válidas: se habilita Continuar
      await tester.enterText(
        find.byKey(const ValueKey('input_confirm_password')),
        'Password123',
      );
      await tester.pumpAndSettle();
      expect(getContinuarButton().onPressed, isNotNull);
    });
  });

  group('Integración del flujo con confirmación de reserva (HU13/HU14 + confirmación)', () {
    testWidgets('Tapping Continuar en paso 7 entrega draft y contraseña via onContactSubmitted',
        (tester) async {
      setLargeScreen(tester);
      final r = _buildRestaurant();
      final vm = createReadyViewModel();

      ReservationDraftModel? submittedDraft;
      String? submittedPassword;

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationFlowView(
            restaurant: r,
            viewModel: vm,
            enableContactStep: true,
            onContactSubmitted: (d, pass) {
              submittedDraft = d;
              submittedPassword = pass;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('input_contact_nombre')),
        'Mariana Ríos',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_correo')),
        'mariana@test.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_contact_telefono')),
        '4185556677',
      );
      await tester.tap(find.byKey(const ValueKey('checkbox_crear_cuenta')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('input_password')), 'Mariana2026');
      await tester.enterText(
        find.byKey(const ValueKey('input_confirm_password')),
        'Mariana2026',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('btn_continuar_step_7')));
      await tester.pumpAndSettle();

      expect(submittedDraft, isNotNull);
      expect(submittedDraft!.contactoNombre, equals('Mariana Ríos'));
      expect(submittedDraft!.contactoCorreo, equals('mariana@test.com'));
      expect(submittedDraft!.contactoTelefono, equals('4185556677'));
      expect(submittedDraft!.crearCuenta, isTrue);
      expect(submittedPassword, equals('Mariana2026'));
    });
  });
}
