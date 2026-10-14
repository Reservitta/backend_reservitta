import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../viewmodels/home_viewmodel.dart';
import 'restaurant_profile_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _viewModel;
  bool _isEditingProfile = false;

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);

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

        // Si el restaurante aún no tiene el perfil completo o el usuario eligió editarlo
        if (currentRest != null && (needsConfig || _isEditingProfile)) {
          return RestaurantProfileView(
            restaurantId: currentRest.id,
            onCompleted: () {
              setState(() {
                _isEditingProfile = false;
              });
              _viewModel.loadAdminSessionData();
            },
            onCancel: needsConfig
                ? () => _viewModel.signOut()
                : () {
                    setState(() {
                      _isEditingProfile = false;
                    });
                  },
          );
        }

        // Vista de Dashboard Administrador con perfil completado
        return Scaffold(
          backgroundColor: _lightBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              currentRest?.nombre ?? 'Dashboard Administrador',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: 'Editar Perfil del Restaurante (HU23)',
                onPressed: () {
                  setState(() {
                    _isEditingProfile = true;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Cerrar Sesión',
                onPressed: () => _viewModel.signOut(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                              'Tu restaurante "${currentRest?.nombre}" está visible y listo para recibir reservaciones.',
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
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar'),
                        onPressed: () {
                          setState(() {
                            _isEditingProfile = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Resumen del Restaurante
                if (currentRest != null) ...[
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
                  const SizedBox(height: 24),
                ],

                // Listado de restaurantes en la base de datos
                const Text(
                  'Restaurantes registrados en la plataforma',
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
                        child: Text('No hay restaurantes registrados en el sistema.'),
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
                              CircleAvatar(
                                backgroundColor: const Color(0xFFF3ECE1),
                                child: const Icon(Icons.restaurant, color: _primaryTerracotta),
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
        );
      },
    );
  }
}
