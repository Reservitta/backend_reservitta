import 'package:flutter/material.dart';

import '../models/platillo_model.dart';
import '../models/reservation_draft_model.dart';
import '../models/restaurant_model.dart';
import '../services/reminder_inbox_service.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import '../viewmodels/pedido_viewmodel.dart';
import '../viewmodels/public_catalog_viewmodel.dart';
import 'auth_modal_dialog.dart';
import 'location_filter_sheet.dart';
import 'mi_pedido_view.dart';
import 'reservation_management_view.dart';
import 'restaurant_detail_view.dart';
import 'widgets/upcoming_reminder_banner.dart';
import '../theme/app_theme.dart';

/// Pantalla Principal Pública de Reservitta (HU01-RF03, HU02-RF03)
/// Permite navegación libre del catálogo, filtros de ubicación por radio (HU02),
/// servicios y vistas de detalle sin necesidad de registrarse ni iniciar sesión.
class LandingView extends StatefulWidget {
  final PublicCatalogViewModel? viewModel;

  /// Recordatorios de reservas próximas del visitante con sesión (HU21-RF02); por
  /// defecto se consultan en Firestore.
  final Future<List<UpcomingReminder>> Function()? cargarRecordatorios;

  const LandingView({super.key, this.viewModel, this.cargarRecordatorios});

  @override
  State<LandingView> createState() => _LandingViewState();
}

class _LandingViewState extends State<LandingView> {
  late final PublicCatalogViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? PublicCatalogViewModel();
    if (widget.viewModel == null) {
      _viewModel.init();
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            elevation: 1,
            titleSpacing: 12,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_menu, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 5),
                const Text(
                  'Reservitta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            actions: [
              // Con o sin sesión se puede gestionar una reserva con su código.
              IconButton(
                key: const ValueKey('boton_header_gestionar_reserva'),
                tooltip: 'Gestionar mi reserva',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.event_note_outlined, size: 20),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReservationManagementView(),
                    ),
                  );
                },
              ),
              if (!_viewModel.isUserAuthenticated) ...[
                TextButton(
                  key: const ValueKey('boton_header_registrarse'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    AuthModalDialog.show(
                      context,
                      initialMode: AuthMode.registerRoleSelection,
                    );
                  },
                  child: const Text(
                    'Crear Cuenta',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 10),
                  child: FilledButton(
                    key: const ValueKey('boton_header_iniciar_sesion'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      AuthModalDialog.show(
                        context,
                        initialMode: AuthMode.login,
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login, size: 15),
                        SizedBox(width: 4),
                        Text(
                          'Iniciar Sesión',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: ActionChip(
                      key: const ValueKey('btn_header_mi_pedido'),
                      avatar: const Icon(Icons.receipt_long, size: 16, color: Colors.white),
                      label: const Text(
                        'Mi pedido',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: AppColors.marca,
                      onPressed: () => _abrirMiPedidoRapido(context),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Chip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: Text(
                        _viewModel.currentUserName ?? 'Mi Cuenta',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Cerrar sesión',
                  onPressed: () => _viewModel.signOut(),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _viewModel.refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // 1. Hero Banner y Buscador
                    SliverToBoxAdapter(
                      child: _buildHeroSection(theme),
                    ),

                    // 1.5. Menú especial de acceso rápido a "Mi pedido" (solo con sesión iniciada)
                    if (_viewModel.isUserAuthenticated)
                      SliverToBoxAdapter(
                        child: _buildAccesoRapidoMiPedido(theme),
                      ),

                    // 1.6. Recordatorio de reservas próximas (HU21-RF02)
                    if (_viewModel.isUserAuthenticated)
                      SliverToBoxAdapter(
                        child: UpcomingReminderBanner(
                          cargar: widget.cargarRecordatorios,
                        ),
                      ),

                    // 2. Filtros de Ubicación y Servicios
                    SliverToBoxAdapter(
                      child: _buildFiltersBar(theme),
                    ),

                    // 3. Barra de Filtros Activos
                    if (_viewModel.hasActiveFilters)
                      SliverToBoxAdapter(
                        child: _buildActiveFiltersBar(theme),
                      ),

                    // 4. Lista o Grid de Restaurantes
                    _buildRestaurantsContent(theme),

                    // 5. Indicador de carga de más elementos al final
                    if (_viewModel.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1E6DA), AppColors.fondo],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Bienvenido a Reservitta',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: AppColors.texto,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Explora y descubre restaurantes asociados, consulta sus menús y reserva tu mesa.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textoSuave,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),

              // Buscador de texto
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.marca.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  key: const ValueKey('campo_buscar_restaurantes'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar restaurantes por nombre o dirección...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.marca),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Borrar búsqueda',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _viewModel.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.superficie,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: const BorderSide(color: AppColors.marca, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  ),
                  onChanged: (val) {
                    _viewModel.setSearchQuery(val);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra de búsqueda con tres campos (ubicación, fecha y hora, personas) y los
  /// filtros por servicios debajo. HU02-RF03, HU03-RF02 y HU04-RF02.
  Widget _buildFiltersBar(ThemeData theme) {
    final segmentos = [
      _SegmentoFiltro(
        key: const ValueKey('boton_filtro_ubicacion'),
        icono: _viewModel.isLocationFilterActive
            ? Icons.my_location
            : Icons.location_on_outlined,
        titulo: 'Dónde',
        valor: _viewModel.isLocationFilterActive
            ? '${_viewModel.selectedLocation!.label} (${_viewModel.selectedRadiusKm!.toInt()} km)'
            : 'Cerca de mí / Ubicación',
        activo: _viewModel.isLocationFilterActive,
        onTap: () => LocationFilterSheet.show(context, _viewModel),
      ),
      _SegmentoFiltro(
        key: const ValueKey('boton_filtro_fecha_hora'),
        icono: _viewModel.isDateTimeFilterActive
            ? Icons.event_available
            : Icons.calendar_today_outlined,
        titulo: 'Cuándo',
        valor: _viewModel.isDateTimeFilterActive
            ? _viewModel.selectedDateTimeFormatted!
            : 'Fecha y hora',
        activo: _viewModel.isDateTimeFilterActive,
        onTap: _openNativeDateTimePicker,
      ),
      _SegmentoFiltro(
        key: const ValueKey('boton_filtro_cantidad_personas'),
        icono: _viewModel.isGuestCountFilterActive
            ? Icons.group
            : Icons.group_outlined,
        titulo: 'Cuántos',
        valor: _viewModel.isGuestCountFilterActive
            ? _viewModel.selectedGuestCountFormatted!
            : 'Personas',
        activo: _viewModel.isGuestCountFilterActive,
        onTap: _openGuestCountPicker,
      ),
    ];

    final servicios = _viewModel.availableServices;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.superficie,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divisor),
              boxShadow: [
                BoxShadow(
                  color: AppColors.marca.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ancho = constraints.maxWidth >= 640;
                  if (ancho) {
                    return IntrinsicHeight(
                      child: Row(
                        children: [
                          for (var i = 0; i < segmentos.length; i++) ...[
                            if (i > 0)
                              const VerticalDivider(width: 1, color: AppColors.divisor),
                            Expanded(child: segmentos[i]),
                          ],
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < segmentos.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.divisor),
                        segmentos[i],
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          if (_viewModel.hasActiveFilters || servicios.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Botón directo para limpiar todos los filtros con un solo toque
                if (_viewModel.hasActiveFilters)
                  ActionChip(
                    key: const ValueKey('boton_limpiar_filtros_barra'),
                    avatar: const Icon(
                      Icons.filter_alt_off,
                      size: 16,
                      color: AppColors.marca,
                    ),
                    label: const Text(
                      'Limpiar filtros',
                      style: TextStyle(
                        color: AppColors.marca,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: AppColors.marcaSuave,
                    side: BorderSide.none,
                    onPressed: () {
                      _searchController.clear();
                      _viewModel.clearFilters();
                    },
                  ),

                // Chips de servicios disponibles
                for (final s in servicios)
                  FilterChip(
                    key: ValueKey('filtro_servicio_${s.id}'),
                    selected: _viewModel.selectedServiceId == s.id,
                    label: Text(s.nombre),
                    showCheckmark: true,
                    checkmarkColor: AppColors.sobreMarca,
                    selectedColor: AppColors.marca,
                    backgroundColor: AppColors.superficie,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _viewModel.selectedServiceId == s.id
                          ? AppColors.sobreMarca
                          : AppColors.texto,
                    ),
                    onSelected: (_) => _viewModel.toggleServiceFilter(s.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Filtros activos:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),

          // Chip de Ubicación activa con opción para quitar (HU02-RF03 Criterio 3)
          if (_viewModel.isLocationFilterActive)
            Chip(
              key: const ValueKey('chip_filtro_ubicacion_activo'),
              avatar: const Icon(Icons.near_me, size: 16),
              deleteButtonTooltipMessage: 'Quitar filtro de ubicación',
              label: Text(
                '${_viewModel.selectedLocation!.label} (≤ ${_viewModel.selectedRadiusKm!.toInt()} km)',
              ),
              onDeleted: () => _viewModel.clearLocationFilter(),
            ),

          if (_viewModel.searchQuery.isNotEmpty)
            Chip(
              label: Text('"${_viewModel.searchQuery}"'),
              onDeleted: () {
                _searchController.clear();
                _viewModel.setSearchQuery('');
              },
            ),

          // Chip de Fecha y hora activa con opción para quitar (HU03-RF02 Criterio 3 y 4)
          if (_viewModel.isDateTimeFilterActive)
            Chip(
              key: const ValueKey('chip_filtro_fecha_hora_activo'),
              avatar: const Icon(Icons.event, size: 16),
              deleteButtonTooltipMessage: 'Quitar filtro de fecha y hora',
              label: Text(_viewModel.selectedDateTimeFormatted!),
              onDeleted: () => _viewModel.clearDateTimeFilter(),
            ),

          // Chip de Cantidad de personas activa con opción para quitar (HU04-RF02 Criterios 3 y 4)
          if (_viewModel.isGuestCountFilterActive)
            Chip(
              key: const ValueKey('chip_filtro_cantidad_personas_activo'),
              avatar: const Icon(Icons.group, size: 16),
              deleteButtonTooltipMessage: 'Quitar filtro de cantidad de personas',
              label: Text(_viewModel.selectedGuestCountFormatted!),
              onDeleted: () => _viewModel.clearGuestCountFilter(),
            ),

          if (_viewModel.selectedServiceId != null)
            Chip(
              label: Text(_obtenerNombreServicio(_viewModel.selectedServiceId!)),
              onDeleted: () => _viewModel.toggleServiceFilter(_viewModel.selectedServiceId!),
            ),

          OutlinedButton.icon(
            key: const ValueKey('boton_limpiar_filtros'),
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('Limpiar todos'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            onPressed: () {
              _searchController.clear();
              _viewModel.clearFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantsContent(ThemeData theme) {
    if (_viewModel.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando restaurantes disponibles...'),
            ],
          ),
        ),
      );
    }

    if (_viewModel.errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  _viewModel.errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('boton_reintentar_carga'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  onPressed: _viewModel.retry,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Estado vacío (HU02-RF03 Criterio 4: Si no hay resultados en el radio elegido, se muestra mensaje y opción de ampliar radio)
    if (_viewModel.restaurants.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _viewModel.isLocationFilterActive
                      ? Icons.location_off_outlined
                      : Icons.storefront_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  _viewModel.isLocationFilterActive
                      ? 'Sin restaurantes en el radio elegido'
                      : 'No se encontraron restaurantes asociados.',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _viewModel.isLocationFilterActive
                      ? 'No hay restaurantes activos en un radio de ${_viewModel.selectedRadiusKm!.toInt()} km alrededor de ${_viewModel.selectedLocation!.label}.'
                      : _viewModel.hasActiveFilters
                          ? 'Prueba modificando tus términos de búsqueda o filtros.'
                          : 'Próximamente habrá opciones disponibles en tu zona.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),

                // HU02-RF03 Criterio 4: Opción directa de ampliar el radio
                if (_viewModel.isLocationFilterActive) ...[
                  FilledButton.icon(
                    key: const ValueKey('boton_ampliar_radio'),
                    icon: const Icon(Icons.zoom_out_map),
                    label: const Text('Ampliar radio de búsqueda'),
                    onPressed: () => _viewModel.expandRadius(),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const ValueKey('boton_quitar_filtro_ubicacion_vacio'),
                    onPressed: () => _viewModel.clearLocationFilter(),
                    child: const Text('Quitar filtro de ubicación'),
                  ),
                ],

                // Botón único para restablecer todos los filtros con un solo clic cuando no hay resultados
                if (_viewModel.hasActiveFilters) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    key: const ValueKey('boton_limpiar_filtros_vacio'),
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Limpiar todos los filtros'),
                    onPressed: () {
                      _searchController.clear();
                      _viewModel.clearFilters();
                    },
                  ),
                ],
                // HU03-RF02 Criterio 4: Opción directa de quitar filtro de fecha y hora
                if (_viewModel.isDateTimeFilterActive) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('boton_quitar_filtro_fecha_hora_vacio'),
                    icon: const Icon(Icons.event_busy),
                    label: const Text('Quitar filtro de fecha y hora'),
                    onPressed: () => _viewModel.clearDateTimeFilter(),
                  ),
                ],

                // HU04-RF02 Criterio 4: Opción directa de quitar filtro de personas
                if (_viewModel.isGuestCountFilterActive) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('boton_quitar_filtro_personas_vacio'),
                    icon: const Icon(Icons.group_remove),
                    label: const Text('Quitar filtro de personas'),
                    onPressed: () => _viewModel.clearGuestCountFilter(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Grid adaptativo para pantallas amplias o móviles
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final int crossAxisCount;
          if (width > 800) {
            crossAxisCount = 3;
          } else if (width > 500) {
            crossAxisCount = 2;
          } else {
            crossAxisCount = 1;
          }

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              // Crece con el tamaño de letra del sistema para que el texto no se corte.
              mainAxisExtent: 312 +
                  (MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0) - 1) * 110,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final restaurant = _viewModel.restaurants[index];
                // Distancia aproximada calculada si el filtro está activo (HU02-RF03 Criterio 2)
                final distanceFormatted = _viewModel.getFormattedDistance(restaurant);

                return _RestaurantCard(
                  restaurant: restaurant,
                  distanceFormatted: distanceFormatted,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailView(restaurant: restaurant),
                      ),
                    );
                  },
                );
              },
              childCount: _viewModel.restaurants.length,
            ),
          );
        },
      ),
    );
  }

  String _obtenerNombreServicio(String id) {
    for (final s in _viewModel.availableServices) {
      if (s.id == id) return s.nombre;
    }
    return id;
  }

  /// HU03-RF02: Selector nativo de fecha y hora (Criterios 1, 2, 3 y 4)
  Future<void> _openNativeDateTimePicker() async {
    final now = DateTime.now();

    // 1. Selector nativo de Fecha (showDatePicker)
    // Criterio 2: firstDate es la fecha actual (hoy), impidiendo seleccionar fechas pasadas.
    final initialDate = _viewModel.selectedDateTime != null &&
            !_viewModel.selectedDateTime!.isBefore(now)
        ? _viewModel.selectedDateTime!
        : now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'SELECCIONA LA FECHA DE TU RESERVA',
      cancelText: 'CANCELAR',
      confirmText: 'SIGUIENTE (HORA)',
    );

    if (pickedDate == null || !mounted) return;

    // 2. Selector nativo de Hora (showTimePicker)
    final initialTime = _viewModel.selectedDateTime != null
        ? TimeOfDay.fromDateTime(_viewModel.selectedDateTime!)
        : TimeOfDay.now();

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'SELECCIONA LA HORA DE TU RESERVA',
      cancelText: 'CANCELAR',
      confirmText: 'ACEPTAR',
    );

    if (pickedTime == null || !mounted) return;

    // 3. Combinar fecha y hora seleccionada
    final combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Criterio 2: No se permiten fechas ni horas pasadas
    final isSuccess = _viewModel.setDateTimeFilter(combinedDateTime, now);
    if (!isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: ValueKey('aviso_fecha_hora_pasada'),
          content: Text('No se permiten fechas ni horas pasadas. Elige un horario futuro.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Horario seleccionado: ${_viewModel.selectedDateTimeFormatted}'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _viewModel.clearDateTimeFilter(),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// HU04-RF02: Selector numérico (stepper) de cantidad de personas (Criterios 1, 2, 3 y 4)
  Future<void> _openGuestCountPicker() async {
    int tempCount = _viewModel.selectedGuestCount ?? 2;
    const minGuests = PublicCatalogViewModel.minGuestCount;
    const maxGuests = PublicCatalogViewModel.maxGuestCount;

    final selected = await showDialog<int?>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return AlertDialog(
              key: const ValueKey('dialogo_selector_cantidad_personas'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.people_alt_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Cantidad de personas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Selecciona el número de personas para filtrar restaurantes con capacidad disponible:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton.filledTonal(
                          key: const ValueKey('boton_decrementar_personas'),
                          icon: const Icon(Icons.remove),
                          onPressed: tempCount > minGuests
                              ? () => setModalState(() => tempCount--)
                              : null,
                          tooltip: 'Disminuir personas',
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$tempCount',
                              key: const ValueKey('texto_conteo_personas'),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              tempCount == 1 ? 'persona' : 'personas',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          key: const ValueKey('boton_incrementar_personas'),
                          icon: const Icon(Icons.add),
                          onPressed: tempCount < maxGuests
                              ? () => setModalState(() => tempCount++)
                              : null,
                          tooltip: 'Aumentar personas',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mínimo $minGuests y máximo $maxGuests personas.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                  ),
                ],
              ),
              actions: [
                if (_viewModel.isGuestCountFilterActive)
                  TextButton(
                    key: const ValueKey('boton_quitar_filtro_personas_dialogo'),
                    onPressed: () {
                      Navigator.pop(dialogCtx, 0); // 0 indica quitar filtro
                    },
                    child: const Text('Quitar filtro', style: TextStyle(color: Colors.redAccent)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const ValueKey('boton_aplicar_filtro_personas'),
                  onPressed: () => Navigator.pop(dialogCtx, tempCount),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;

    if (selected == 0) {
      _viewModel.clearGuestCountFilter();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Filtro de cantidad de personas eliminado'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      final success = _viewModel.setGuestCountFilter(selected);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Filtro aplicado: $selected ${selected == 1 ? 'persona' : 'personas'}',
            ),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () => _viewModel.clearGuestCountFilter(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // HU16-RF06: ACCESO RÁPIDO A "MI PEDIDO" (SOLO CON SESIÓN INICIADA)
  // ---------------------------------------------------------------------------
  Widget _buildAccesoRapidoMiPedido(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Container(
        key: const ValueKey('card_acceso_rapido_mi_pedido'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divisor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.restaurant, size: 18, color: AppColors.marca),
                    SizedBox(width: 8),
                    Text(
                      'Acceso Rápido: Mi Pedido',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.texto,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Consulta el resumen de tu visita, gestiona los platillos preordenados y personaliza tu experiencia.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
              ],
            );

            final button = FilledButton.icon(
              key: const ValueKey('btn_acceso_rapido_mi_pedido'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.marca,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text(
                'Ver mi pedido',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => _abrirMiPedidoRapido(context),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  const SizedBox(height: 12),
                  button,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 16),
                button,
              ],
            );
          },
        ),
      ),
    );
  }

  void _abrirMiPedidoRapido(BuildContext context) {
    final restaurant = _viewModel.restaurants.isNotEmpty
        ? _viewModel.restaurants.first
        : const RestaurantModel(
            id: 'rest_demo',
            nombre: 'Miel Aurum',
            estado: 'activo',
          );

    final draft = ReservationDraftModel(
      restaurant: restaurant,
      fecha: DateTime.now().add(const Duration(days: 3)),
      duracionMin: 90,
      personas: 2,
      mesaIds: const ['mesa_1'],
      mesasNombres: const ['Mesa Terraza 1'],
      horario: const TimeOfDay(hour: 14, minute: 0),
    );

    final platillo1 = PlatilloModel(
      id: 'plat_1',
      categoriaId: 'cat_cortes',
      nombre: 'Ribeye a la Leña',
      descripcion: 'Corte jugoso de 400g a la parrilla con guarnición.',
      precio: 350.0,
      imagenUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=500',
      etiquetas: const ['Especialidad', 'Carne'],
    );

    final platillo2 = PlatilloModel(
      id: 'plat_2',
      categoriaId: 'cat_entradas',
      nombre: 'Ceviche Mixto',
      descripcion: 'Pescado blanco, camarón, cebolla morada y aguacate fresco.',
      precio: 180.0,
      imagenUrl: 'https://images.unsplash.com/photo-1535400255456-984241443b29?w=500',
      etiquetas: const ['Mariscos', 'Fresco'],
    );

    final platillo3 = PlatilloModel(
      id: 'plat_3',
      categoriaId: 'cat_bebidas',
      nombre: 'Vino Tinto Reserva',
      descripcion: 'Copa de vino tinto crianza de la casa.',
      precio: 120.0,
      imagenUrl: 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=500',
      etiquetas: const ['Bebidas'],
    );

    final pedidoVm = PedidoViewModel();
    pedidoVm.agregarPlatillo(
      platillo1,
      cantidad: 1,
      observacion: 'Término medio, sal de grano',
    );
    pedidoVm.agregarPlatillo(
      platillo2,
      cantidad: 1,
      observacion: 'Sin cebolla morada',
    );
    pedidoVm.agregarPlatillo(
      platillo3,
      cantidad: 1,
    );

    final catalogo = {
      platillo1.id: platillo1,
      platillo2.id: platillo2,
      platillo3.id: platillo3,
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MiPedidoView(
          restaurant: restaurant,
          draft: draft,
          pedidoViewModel: pedidoVm,
          catalogoPorId: catalogo,
          onAgregarMasPlatillos: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regresando al catálogo de platillos...'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          onContinuarOcasion: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Ocasión Especial (HU18)'),
                content: const Text(
                  'Avanzando a la personalización de tu experiencia y amenidades.',
                ),
                actions: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.marca,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tarjeta visual del restaurante según HU01-RF02 y HU02-RF03
class _RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final String? distanceFormatted;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.restaurant,
    this.distanceFormatted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divisor),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen o Portada
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildRestaurantCoverImage(
                    restaurant.imagenPrincipalUrl,
                    theme,
                    nombre: restaurant.nombre,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: AppColors.exito),
                          SizedBox(width: 6),
                          Text(
                            'Disponible',
                            style: TextStyle(
                              color: AppColors.exito,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Distancia destacada sobre la imagen si el filtro está activo (HU02-RF03 Criterio 2)
                  if (distanceFormatted != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              distanceFormatted!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.nombre,
                    style: const TextStyle(
                      fontFamily: AppTheme.familiaTitulos,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation('wght', 700)],
                      fontSize: 19,
                      color: AppColors.texto,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Dirección y distancia
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.direccion.isNotEmpty
                              ? restaurant.direccion
                              : 'Ubicación céntrica',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (distanceFormatted != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '($distanceFormatted)',
                          key: ValueKey('distancia_${restaurant.id}'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Botón de acción: sólo Ver Detalle
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      key: ValueKey('boton_ver_detalle_${restaurant.id}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.marcaSuave,
                        foregroundColor: AppColors.marca,
                      ),
                      onPressed: onTap,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text(
                        'Ver Detalle',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRestaurantCoverImage(
    String rawUrl,
    ThemeData theme, {
    String nombre = '',
  }) {
    final trimmedUrl = rawUrl.trim();
    if (trimmedUrl.isEmpty) {
      return _buildFallbackCover(theme, nombre);
    }

    String finalUrl = trimmedUrl;
    try {
      finalUrl = Uri.encodeFull(trimmedUrl);
    } catch (_) {}

    return Image.network(
      finalUrl,
      fit: BoxFit.cover,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[Reservitta Image Error] $error - URL: $finalUrl');
        return _buildFallbackCover(theme, nombre);
      },
    );
  }

  /// Portada sin foto: degradado cálido con la inicial del restaurante.
  Widget _buildFallbackCover(ThemeData theme, [String nombre = '']) {
    final limpio = nombre.trim();
    final inicial = limpio.isEmpty ? null : limpio.characters.first.toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.marcaSuave, AppColors.marcaMedia],
        ),
      ),
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
          child: inicial == null
              ? const Icon(Icons.restaurant, size: 30, color: AppColors.marca)
              : Text(
                  inicial,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.marca,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Un campo de la barra de búsqueda: título pequeño arriba y el valor abajo.
class _SegmentoFiltro extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final bool activo;
  final VoidCallback onTap;

  const _SegmentoFiltro({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      label: '$titulo: $valor',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          color: activo ? AppColors.marcaSuave : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icono, size: 22, color: AppColors.marca),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textoSuave,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                        color: activo ? AppColors.marca : AppColors.texto,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more, size: 20, color: AppColors.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}
