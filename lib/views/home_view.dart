import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../viewmodels/home_viewmodel.dart';
import 'categoria_list_view.dart';
import 'platillo_list_view.dart';
import 'restaurant_profile_view.dart';

/// Secciones del panel de administración
enum AdminSection {
  dashboard,
  reservas,
  pedidos,
  mesas,
  menu,
  categorias,
  configuracion,
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _viewModel;
  AdminSection _seccionActual = AdminSection.menu;

  static const Color _sidebarBg = Color(0xFF1B110B);
  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _sidebarMuted = Color(0xFF9E8E83);
  static const Color _sidebarHeader = Color(0xFF7D6B5E);

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel();
    _viewModel.loadAdminSessionData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _obtenerIniciales(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return 'CS';
    final palabras = nombre.trim().split(RegExp(r'\s+'));
    if (palabras.length == 1) {
      return palabras[0].substring(0, palabras[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${palabras[0][0]}${palabras[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.isLoadingProfile) {
          return const Scaffold(
            backgroundColor: _lightBg,
            body: Center(
              child: CircularProgressIndicator(color: _primaryTerracotta),
            ),
          );
        }

        if (_viewModel.loadError != null) {
          return Scaffold(
            backgroundColor: _lightBg,
            appBar: AppBar(
              title: const Text('Reservitta Admin'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _viewModel.signOut(),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudo cargar tu perfil: ${_viewModel.loadError}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _primaryTerracotta),
                      onPressed: _viewModel.loadAdminSessionData,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final currentRest = _viewModel.currentRestaurant;
        final needsConfig = currentRest != null && !currentRest.perfilCompleto;

        // Si el restaurante aún no tiene el perfil completo obligatorio
        if (currentRest != null && needsConfig) {
          return RestaurantProfileView(
            restaurantId: currentRest.id,
            onCompleted: () {
              _viewModel.loadAdminSessionData();
            },
            onCancel: () => _viewModel.signOut(),
          );
        }

        // Layout Principal: Sidebar a la izquierda y Contenido a la derecha
        final screenWidth = MediaQuery.of(context).size.width;
        final bool esPantallaAmplia = screenWidth >= 800;

        return Scaffold(
          backgroundColor: _lightBg,
          drawer: esPantallaAmplia
              ? null
              : Drawer(
                  backgroundColor: _sidebarBg,
                  child: _buildSidebarContent(currentRest, isDrawer: true),
                ),
          appBar: esPantallaAmplia
              ? null
              : AppBar(
                  backgroundColor: Colors.white,
                  foregroundColor: _textDark,
                  elevation: 0,
                  title: Text(
                    _obtenerTituloSeccion(_seccionActual),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
          body: Row(
            children: [
              if (esPantallaAmplia)
                SizedBox(
                  width: 250,
                  child: Material(
                    color: _sidebarBg,
                    child: _buildSidebarContent(currentRest, isDrawer: false),
                  ),
                ),
              Expanded(
                child: _buildMainContent(currentRest),
              ),
            ],
          ),
        );
      },
    );
  }

  String _obtenerTituloSeccion(AdminSection seccion) {
    switch (seccion) {
      case AdminSection.dashboard:
        return 'Dashboard';
      case AdminSection.reservas:
        return 'Reservas';
      case AdminSection.pedidos:
        return 'Pedidos';
      case AdminSection.mesas:
        return 'Mesas';
      case AdminSection.menu:
        return 'Menú';
      case AdminSection.categorias:
        return 'Categorías';
      case AdminSection.configuracion:
        return 'Configuración';
    }
  }

  Widget _buildSidebarContent(RestaurantModel? currentRest, {required bool isDrawer}) {
    final nombre = currentRest?.nombre ?? 'Casa Sabores';
    final iniciales = _obtenerIniciales(nombre);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header con avatar e iniciales
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _primaryTerracotta,
                  child: Text(
                    iniciales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Admin',
                        style: TextStyle(
                          color: _sidebarMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0x1AFFFFFF), height: 1),
          const SizedBox(height: 10),

          // 2. Lista de secciones con scroll si se requiere
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildSidebarSectionHeader('OPERACIÓN'),
                _buildSidebarItem(
                  seccion: AdminSection.dashboard,
                  icono: Icons.grid_view_rounded,
                  titulo: 'Dashboard',
                  isDrawer: isDrawer,
                ),
                _buildSidebarItem(
                  seccion: AdminSection.reservas,
                  icono: Icons.calendar_today_outlined,
                  titulo: 'Reservas',
                  isDrawer: isDrawer,
                ),
                _buildSidebarItem(
                  seccion: AdminSection.pedidos,
                  icono: Icons.receipt_long_outlined,
                  titulo: 'Pedidos',
                  isDrawer: isDrawer,
                ),
                _buildSidebarItem(
                  seccion: AdminSection.mesas,
                  icono: Icons.grid_4x4_outlined,
                  titulo: 'Mesas',
                  isDrawer: isDrawer,
                ),

                const SizedBox(height: 18),
                _buildSidebarSectionHeader('MENÚ'),
                _buildSidebarItem(
                  seccion: AdminSection.menu,
                  icono: Icons.restaurant_menu_outlined,
                  titulo: 'Menú',
                  isDrawer: isDrawer,
                ),
                _buildSidebarItem(
                  seccion: AdminSection.categorias,
                  icono: Icons.category_outlined,
                  titulo: 'Categorías',
                  isDrawer: isDrawer,
                ),

                const SizedBox(height: 18),
                _buildSidebarSectionHeader('CONFIGURACIÓN'),
                _buildSidebarItem(
                  seccion: AdminSection.configuracion,
                  icono: Icons.settings_outlined,
                  titulo: 'Configuración',
                  isDrawer: isDrawer,
                ),
              ],
            ),
          ),

          // 3. Footer de sesión
          const Divider(color: Color(0x1AFFFFFF), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: InkWell(
              onTap: () => _viewModel.signOut(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: const Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: _sidebarMuted,
                      size: 20,
                    ),
                    SizedBox(width: 14),
                    Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        color: _sidebarMuted,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSectionHeader(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Text(
        titulo,
        style: const TextStyle(
          color: _sidebarHeader,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required AdminSection seccion,
    required IconData icono,
    required String titulo,
    required bool isDrawer,
  }) {
    final bool isSelected = _seccionActual == seccion;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _seccionActual = seccion;
            });
            if (isDrawer) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color.fromRGBO(255, 255, 255, 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icono,
                  size: 20,
                  color: isSelected ? Colors.white : _sidebarMuted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _sidebarMuted,
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(RestaurantModel? currentRest) {
    if (currentRest == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_seccionActual) {
      case AdminSection.menu:
        // HU24-RF04: Formulario de alta/edición de platillos y switch de disponibilidad
        return PlatilloListView(
          restaurantId: currentRest.id,
          showAppBar: false,
        );

      case AdminSection.categorias:
        // HU24-RF02: Gestión de categorías
        return CategoriaListView(
          restaurantId: currentRest.id,
          showAppBar: false,
        );

      case AdminSection.configuracion:
        // Edición de perfil de restaurante
        return RestaurantProfileView(
          restaurantId: currentRest.id,
          onCompleted: () {
            _viewModel.loadAdminSessionData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil del restaurante actualizado con éxito.'),
                backgroundColor: Color(0xFF2E7D32),
              ),
            );
          },
          onCancel: () {
            setState(() {
              _seccionActual = AdminSection.dashboard;
            });
          },
        );

      case AdminSection.dashboard:
        return _buildDashboardView(currentRest);

      case AdminSection.reservas:
      case AdminSection.pedidos:
      case AdminSection.mesas:
        return _buildProximamenteView(_obtenerTituloSeccion(_seccionActual));
    }
  }

  /// Vista "Próximamente" fiel a la imagen de referencia del usuario
  Widget _buildProximamenteView(String seccionTitulo) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            seccionTitulo,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Esta sección está preparada para futuras implementaciones.',
            style: TextStyle(
              fontSize: 14,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 48),

          // Tarjeta central estilo placeholder con icono de cubiertos
          Center(
            child: Container(
              width: 640,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE2D6C7),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.restaurant_rounded,
                    size: 42,
                    color: _textDark,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Próximamente',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta sección de administración estará disponible en la\nsiguiente iteración del sistema.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Vista de Dashboard Administrador
  Widget _buildDashboardView(RestaurantModel currentRest) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Resumen operativo y estado general de tu restaurante.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 24),

              // Banner de perfil completado con éxito
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perfil de Restaurante Activo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tu restaurante "${currentRest.nombre}" está visible y listo para recibir reservaciones.',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade900,
                        side: BorderSide(color: Colors.green.shade400),
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      label: const Text('Configurar'),
                      onPressed: () {
                        setState(() {
                          _seccionActual = AdminSection.configuracion;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Resumen del Restaurante
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentRest.nombre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            currentRest.direccion.isNotEmpty
                                ? currentRest.direccion
                                : 'Sin dirección registrada',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          currentRest.telefono.isNotEmpty
                              ? currentRest.telefono
                              : 'Sin teléfono registrado',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3ECE1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${currentRest.diasAbiertos.length} días de atención',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3ECE1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${currentRest.serviciosIds.length + currentRest.serviciosPersonalizados.length} servicios activos',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Accesos rápidos a Menú y Categorías
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF1EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu_rounded,
                              color: _primaryTerracotta,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Menú y Platillos',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: Color(0xFF2E241E),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Alta, edición y disponibilidad',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF7A6E65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryTerracotta,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              setState(() {
                                _seccionActual = AdminSection.menu;
                              });
                            },
                            child: const Text('Ir al Menú', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF1EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.category_rounded,
                              color: _primaryTerracotta,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Categorías',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: Color(0xFF2E241E),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Secciones y orden del menú',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF7A6E65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryTerracotta,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              setState(() {
                                _seccionActual = AdminSection.categorias;
                              });
                            },
                            child: const Text('Gestionar', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Listado con título PROVISIONAL solicitado por el usuario:
              // "LO DE RESTAURANTES REGISTRADOS EN LA PLATAFORMA PONLE CON UN NOMBRE PROVISIONAL"
              const Text(
                'Restaurantes Asociados (Provisional)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E241E),
                ),
              ),
              const SizedBox(height: 10),

              StreamBuilder<List<RestaurantModel>>(
                stream: _viewModel.restaurantsStream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final list = snap.data!;
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No hay restaurantes asociados en el sistema.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final r = list[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFF3ECE1),
                              child: Icon(Icons.restaurant, color: _primaryTerracotta),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.direccion.isNotEmpty ? r.direccion : 'Sin dirección',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: r.perfilCompleto
                                    ? Colors.green.shade50
                                    : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: r.perfilCompleto
                                      ? Colors.green.shade300
                                      : Colors.amber.shade300,
                                ),
                              ),
                              child: Text(
                                r.perfilCompleto ? 'Completo' : 'Borrador',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: r.perfilCompleto
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
