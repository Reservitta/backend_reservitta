import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../models/reservation_model.dart';
import '../viewmodels/admin_operations_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import 'admin_reservations_view.dart';
import 'categoria_list_view.dart';
import 'dashboard_view.dart';
import 'ocasion_list_view.dart';
import 'orders_view.dart';
import 'platillo_list_view.dart';
import 'reservation_detail_view.dart';
import 'restaurant_profile_view.dart';
import 'table_management_view.dart';
import '../theme/app_theme.dart';

/// Secciones del panel de administración
enum AdminSection {
  dashboard,
  reservas,
  pedidos,
  mesas,
  menu,
  categorias,
  ocasiones,
  configuracion,
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _viewModel;

  /// Estado operativo del día (reservas, mesas, alertas y métricas), compartido por el
  /// dashboard, las reservas, los pedidos y las mesas.
  AdminOperationsViewModel? _operaciones;
  AdminSection _seccionActual = AdminSection.menu;

  static const Color _sidebarBg = Color(0xFF1B110B);
  static const Color _primaryTerracotta = AppColors.marca;
  static const Color _lightBg = AppColors.fondo;
  static const Color _textDark = AppColors.texto;
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
    _operaciones?.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  AdminOperationsViewModel _operacionesDe(RestaurantModel restaurante) {
    final actual = _operaciones;
    if (actual != null && actual.restaurantId == restaurante.id) return actual;
    actual?.dispose();
    final nuevo = AdminOperationsViewModel(restaurantId: restaurante.id);
    nuevo.iniciar();
    return _operaciones = nuevo;
  }

  /// Abre el detalle de una reserva desde el dashboard, los pedidos o las mesas.
  void _abrirReserva(AdminOperationsViewModel operaciones, ReservationModel reserva) {
    final repo = operaciones.reservasRepositorio;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReservationDetailView(
          reservationId: reserva.id,
          repository: repo,
          onChangeState: (nuevo) async {
            try {
              await repo.changeOperationalState(
                reservationId: reserva.id,
                nuevoEstado: nuevo,
                usuarioId: operaciones.usuarioActual,
              );
              return null;
            } catch (e) {
              return e.toString();
            }
          },
          onChangeOrderState: (nuevo, {motivo}) =>
              operaciones.cambiarEstadoPedido(reserva.id, nuevo, motivo: motivo),
        ),
      ),
    );
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
        tooltip: 'Cerrar sesión',
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
      case AdminSection.ocasiones:
        return 'Ocasiones Especiales';
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
                _buildSidebarItem(
                  seccion: AdminSection.ocasiones,
                  icono: Icons.celebration_outlined,
                  titulo: 'Ocasiones',
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
          fontSize: 12,
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

      case AdminSection.ocasiones:
        // HU33-RF01: Crear ocasión especial y sus experiencias
        return OcasionListView(
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
                backgroundColor: AppColors.exito,
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
        // HU25-RF02: métricas del día, alertas de llegada y accesos directos
        final ops = _operacionesDe(currentRest);
        return DashboardView(
          operaciones: ops,
          restauranteNombre: currentRest.nombre,
          onIrAReservas: () => setState(() => _seccionActual = AdminSection.reservas),
          onIrAMesas: () => setState(() => _seccionActual = AdminSection.mesas),
          onIrAPedidos: () => setState(() => _seccionActual = AdminSection.pedidos),
          onAbrirReserva: (r) => _abrirReserva(ops, r),
        );

      case AdminSection.reservas:
        // HU26-RF02: Pantalla de listado de reservas del restaurante
        return AdminReservationsView(
          restaurantId: currentRest.id,
          showAppBar: false,
          operaciones: _operacionesDe(currentRest),
        );

      case AdminSection.pedidos:
        // HU29-RF02: gestión del estado de los pedidos preordenados
        final ops = _operacionesDe(currentRest);
        return OrdersView(
          operaciones: ops,
          onAbrirReserva: (r) => _abrirReserva(ops, r),
        );

      case AdminSection.mesas:
        // HU31-RF02: estado de las mesas y fuera de servicio
        final ops = _operacionesDe(currentRest);
        return TableManagementView(
          operaciones: ops,
          onAbrirReserva: (r) => _abrirReserva(ops, r),
        );
    }
  }
}
