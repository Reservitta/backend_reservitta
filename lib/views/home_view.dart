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
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservitta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _viewModel.signOut(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return StreamBuilder<List<RestaurantModel>>(
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
                      Text('Inicializando las 14 colecciones en Firebase...'),
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
                      const Icon(Icons.cloud_upload_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Base de datos vacía',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        label: const Text('Inicializar 14 Colecciones en Firebase'),
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
                    subtitle: Text('ID: ${restaurant.id}'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
