import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import '../viewmodels/public_catalog_viewmodel.dart';
import 'auth_modal_dialog.dart';
import 'restaurant_detail_view.dart';

/// Pantalla Principal Pública de Reservitta (HU01-RF03)
/// Permite navegación libre del catálogo, listado de restaurantes, filtros
/// y vistas de detalle sin necesidad de registrarse ni iniciar sesión.
class LandingView extends StatefulWidget {
  final PublicCatalogViewModel? viewModel;

  const LandingView({super.key, this.viewModel});

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
            title: Row(
              children: [
                Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Reservitta',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              if (!_viewModel.isUserAuthenticated) ...[
                TextButton(
                  key: const ValueKey('boton_header_registrarse'),
                  onPressed: () {
                    AuthModalDialog.show(
                      context,
                      initialMode: AuthMode.registerRoleSelection,
                    );
                  },
                  child: const Text('Crear Cuenta'),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: FilledButton.icon(
                    key: const ValueKey('boton_header_iniciar_sesion'),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Iniciar Sesión'),
                    onPressed: () {
                      AuthModalDialog.show(
                        context,
                        initialMode: AuthMode.login,
                      );
                    },
                  ),
                ),
              ] else ...[
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
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // 1. Hero Banner y Buscador
                SliverToBoxAdapter(
                  child: _buildHeroSection(theme),
                ),

                // 2. Chips de Filtros de Servicios
                if (_viewModel.availableServices.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildServiceFilters(theme),
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
        );
      },
    );
  }

  Widget _buildHeroSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      color: theme.colorScheme.primaryContainer.withAlpha(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Bienvenido a Reservitta',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Explora y descubre restaurantes asociados, consulta sus menús y reserva tu mesa.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Buscador de texto
              TextField(
                key: const ValueKey('campo_buscar_restaurantes'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar restaurantes por nombre o dirección...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _viewModel.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onChanged: (val) {
                  _viewModel.setSearchQuery(val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceFilters(ThemeData theme) {
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _viewModel.availableServices.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = _viewModel.availableServices[index];
          final isSelected = _viewModel.selectedServiceId == s.id;

          return FilterChip(
            key: ValueKey('filtro_servicio_${s.id}'),
            selected: isSelected,
            label: Text(s.nombre),
            onSelected: (_) => _viewModel.toggleServiceFilter(s.id),
          );
        },
      ),
    );
  }

  Widget _buildActiveFiltersBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          const Text(
            'Filtros aplicados:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 8),
          if (_viewModel.searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                label: Text('"${_viewModel.searchQuery}"'),
                onDeleted: () {
                  _searchController.clear();
                  _viewModel.setSearchQuery('');
                },
              ),
            ),
          if (_viewModel.selectedServiceId != null)
            Chip(
              label: Text(_obtenerNombreServicio(_viewModel.selectedServiceId!)),
              onDeleted: () => _viewModel.toggleServiceFilter(_viewModel.selectedServiceId!),
            ),
          const Spacer(),
          TextButton(
            key: const ValueKey('boton_limpiar_filtros'),
            onPressed: () {
              _searchController.clear();
              _viewModel.clearFilters();
            },
            child: const Text('Limpiar filtros'),
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

    if (_viewModel.restaurants.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                const Text(
                  'No se encontraron restaurantes asociados.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _viewModel.hasActiveFilters
                      ? 'Prueba modificando tus términos de búsqueda o filtros.'
                      : 'Próximamente habrá opciones disponibles en tu zona.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (_viewModel.hasActiveFilters) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      _searchController.clear();
                      _viewModel.clearFilters();
                    },
                    child: const Text('Limpiar filtros'),
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
          final isWide = constraints.crossAxisExtent > 700;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 2 : 1,
              mainAxisExtent: 310,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final restaurant = _viewModel.restaurants[index];
                return _RestaurantCard(
                  restaurant: restaurant,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailView(restaurant: restaurant),
                      ),
                    );
                  },
                  onReservar: () {
                    // Criterio 3: Redirige a login si no tiene cuenta
                    final canProceed = _viewModel.requireAuthForAction(
                      context,
                      actionName: 'reservar mesa',
                      restaurantName: restaurant.nombre,
                    );
                    if (canProceed) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantDetailView(restaurant: restaurant),
                        ),
                      );
                    }
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
}

/// Tarjeta visual del restaurante según HU01-RF02
class _RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;
  final VoidCallback onReservar;

  const _RestaurantCard({
    required this.restaurant,
    required this.onTap,
    required this.onReservar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen o Portada
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: theme.colorScheme.primaryContainer.withAlpha(80),
                    child: restaurant.imagenPrincipalUrl.isNotEmpty
                        ? Image.network(
                            restaurant.imagenPrincipalUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackCover(theme),
                          )
                        : _buildFallbackCover(theme),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'DISPONIBLE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: ValueKey('boton_ver_detalle_${restaurant.id}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: onTap,
                          child: const Text('Ver Detalle'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: ValueKey('boton_reservar_${restaurant.id}'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: onReservar,
                          child: const Text('Reservar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.restaurant,
        size: 48,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
