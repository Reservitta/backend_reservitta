import 'package:flutter/material.dart';

import '../models/restaurant_model.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _viewModel;

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
        final currentRest = _viewModel.currentRestaurant;
        final isConfigFlowNeeded =
            currentRest != null && !currentRest.perfilCompleto;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isConfigFlowNeeded
                  ? 'Configuración de Restaurante (HU23)'
                  : 'Dashboard Administrador (HU25)',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Cerrar Sesión',
                onPressed: () => _viewModel.signOut(),
              ),
            ],
          ),
          body: _viewModel.isLoadingProfile
              ? const Center(child: CircularProgressIndicator())
              : _viewModel.loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No se pudo cargar tu perfil: ${_viewModel.loadError}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _viewModel.loadAdminSessionData,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (isConfigFlowNeeded)
                      Container(
                        width: double.infinity,
                        color: Colors.amber.shade100,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Flujo HU23: El perfil de tu restaurante "${currentRest.name}" está en borrador. Completa la configuración.',
                                style: TextStyle(color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: StreamBuilder<List<RestaurantModel>>(
                        stream: _viewModel.restaurantsStream,
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(child: Text('Error: ${snap.error}'));
                          }
                          if (!snap.hasData || _viewModel.isInitializing) {
                            return const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Inicializando las 14 colecciones en Firebase...',
                                  ),
                                ],
                              ),
                            );
                          }
                          final restaurants = snap.data!;
                          if (restaurants.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Base de datos vacía',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Haz clic en el botón de abajo para subir y crear las 14 colecciones en Firebase',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.storage),
                                    label: const Text(
                                      'Inicializar 14 Colecciones en Firebase',
                                    ),
                                    onPressed: () async {
                                      await _viewModel.initDatabase();
                                    },
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: restaurants.length,
                            itemBuilder: (context, index) {
                              final restaurant = restaurants[index];
                              return ListTile(
                                leading: const Icon(Icons.restaurant),
                                title: Text(restaurant.name),
                                subtitle: Text(
                                  'Estado: ${restaurant.estado} | Perfil Completo: ${restaurant.perfilCompleto}',
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
