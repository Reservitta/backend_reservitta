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
      body: StreamBuilder<List<RestaurantModel>>(
        stream: _viewModel.restaurantsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final restaurants = snap.data!;
          if (restaurants.isEmpty) {
            return const Center(child: Text('Conectado. No hay restaurantes aún.'));
          }
          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              return ListTile(
                title: Text(restaurant.name),
              );
            },
          );
        },
      ),
    );
  }
}
