import 'package:flutter/material.dart';

import '../models/categoria_model.dart';
import '../models/platillo_model.dart';
import '../models/restaurant_model.dart';
import '../services/auth_service.dart';
import '../services/categoria_service.dart';
import '../services/platillo_service.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import 'auth_modal_dialog.dart';
import 'widgets/preorden_item_dialog.dart';

/// Pantalla pública de detalle del restaurante (HU01-RF03, HU05)
/// Accesible libremente sin necesidad de iniciar sesión o registrarse.
class RestaurantDetailView extends StatefulWidget {
  final RestaurantModel restaurant;
  final AuthService? authService;
  final CategoriaService? categoriaService;
  final PlatilloService? platilloService;

  const RestaurantDetailView({
    super.key,
    required this.restaurant,
    this.authService,
    this.categoriaService,
    this.platilloService,
  });

  @override
  State<RestaurantDetailView> createState() => _RestaurantDetailViewState();
}

class _RestaurantDetailViewState extends State<RestaurantDetailView> {
  late final AuthService _authService;
  late final CategoriaService _categoriaService;
  late final PlatilloService _platilloService;

  late Stream<List<CategoriaModel>> _categoriasStream;
  late Stream<List<PlatilloModel>> _platillosStream;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _categoriaService = widget.categoriaService ?? CategoriaService();
    _platilloService = widget.platilloService ?? PlatilloService();

    _categoriasStream = _categoriaService.getCategoriasStream(widget.restaurant.id);
    _platillosStream = _platilloService.getPlatillosActivosStream(widget.restaurant.id);
  }

  /// HU01-RF03 Criterio 3: Las acciones que sí requieren cuenta (como reservar)
  /// redirigen a login o registro.
  void _onReservarPressed() {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Para reservar en ${widget.restaurant.nombre} necesitas una cuenta en Reservitta.',
          ),
          action: SnackBarAction(
            label: 'Iniciar sesión',
            onPressed: () {
              AuthModalDialog.show(context, initialMode: AuthMode.login);
            },
          ),
        ),
      );
      AuthModalDialog.show(context, initialMode: AuthMode.login);
      return;
    }

    // Si ya tiene sesión iniciada, muestra feedback del flujo de reserva
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reservar en ${widget.restaurant.nombre}'),
        content: Text(
          '¡Hola! Tu sesión está activa como ${user.email}. El módulo de selección de fecha y mesa (HU07) estará disponible a continuación.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.restaurant;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          r.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al listado',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      r.direccion.isNotEmpty ? r.direccion : 'Consulta disponibilidad',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                key: const ValueKey('boton_reservar_mesa'),
                icon: const Icon(Icons.table_restaurant),
                label: const Text('Reservar Mesa'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: _onReservarPressed,
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con imagen o portada
            Container(
              height: 220,
              width: double.infinity,
              color: theme.colorScheme.primaryContainer.withAlpha(80),
              child: r.imagenPrincipalUrl.isNotEmpty
                  ? Image.network(
                      r.imagenPrincipalUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildFallbackBanner(theme, r),
                    )
                  : _buildFallbackBanner(theme, r),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y Estado
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          r.nombre,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          r.estado.toUpperCase(),
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dirección
                  if (r.direccion.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.direccion,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Teléfono
                  if (r.telefono.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(r.telefono, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Correo
                  if (r.correo.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.email_outlined, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(r.correo, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Descripción
                  if (r.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      r.descripcion,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  // Horarios
                  if (r.horarios.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Horarios de Atención',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: r.horarios.entries.map((e) {
                          final s = e.value;
                          final dia = e.key[0].toUpperCase() + e.key.substring(1);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dia, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(
                                  s.abierto ? '${s.apertura} - ${s.cierre}' : 'Cerrado',
                                  style: TextStyle(
                                    color: s.abierto ? Colors.green.shade700 : Colors.red.shade400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Servicios disponibles
                  if (r.serviciosIds.isNotEmpty || r.serviciosPersonalizados.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Servicios e Instalaciones',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...r.serviciosIds.map((id) => Chip(
                              label: Text(_formatearServicio(id)),
                              avatar: const Icon(Icons.check, size: 16),
                            )),
                        ...r.serviciosPersonalizados.map((p) => Chip(
                              label: Text(p),
                              avatar: const Icon(Icons.star_outline, size: 16),
                            )),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Menú del restaurante
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Menú y Platillos',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildMenuSection(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBanner(ThemeData theme, RestaurantModel r) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            r.nombre,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(ThemeData theme) {
    return StreamBuilder<List<PlatilloModel>>(
      stream: _platillosStream,
      builder: (context, platillosSnap) {
        if (platillosSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final platillos = platillosSnap.data ?? [];
        if (platillos.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text(
              'Este restaurante aún no tiene platillos publicados en su menú.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          );
        }

        return StreamBuilder<List<CategoriaModel>>(
          stream: _categoriasStream,
          builder: (context, catSnap) {
            final categorias = catSnap.data ?? [];

            // Si hay categorías definidas, agrupar platillos por categoría
            if (categorias.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categorias.map((cat) {
                  final platillosCat = platillos.where((p) => p.categoriaId == cat.id).toList();
                  if (platillosCat.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          cat.nombre,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      ...platillosCat.map((p) => _buildDishTile(theme, p)),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              );
            }

            // Si no hay categorías, mostrar lista simple de platillos
            return Column(
              children: platillos.map((p) => _buildDishTile(theme, p)).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildDishTile(ThemeData theme, PlatilloModel p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final item = await PreordenItemDialog.show(context, platillo: p);
          if (item != null && mounted) {
            final obs = (item['observacion'] as String? ?? '').trim();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  obs.isNotEmpty
                      ? 'Agregado a preorden: ${item['nombre']} (${item['cantidad']}x) - "$obs"'
                      : 'Agregado a preorden: ${item['nombre']} (${item['cantidad']}x)',
                ),
                backgroundColor: const Color(0xFF2C5E94),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: p.imagenUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p.imagenUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.fastfood_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.fastfood_outlined,
                        color: theme.colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (p.permitePersonalizacion)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF3FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Personalizable',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E5288),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (p.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.descripcion,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${p.precio.toStringAsFixed(2)} MXN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                        OutlinedButton.icon(
                          key: ValueKey('btn_preordenar_${p.id}'),
                          icon: const Icon(Icons.add_shopping_cart, size: 14),
                          label: const Text('Preordenar', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final item = await PreordenItemDialog.show(context, platillo: p);
                            if (item != null && mounted) {
                              final obs = (item['observacion'] as String? ?? '').trim();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    obs.isNotEmpty
                                        ? 'Agregado a preorden: ${item['nombre']} (${item['cantidad']}x) - "$obs"'
                                        : 'Agregado a preorden: ${item['nombre']} (${item['cantidad']}x)',
                                  ),
                                  backgroundColor: const Color(0xFF2C5E94),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearServicio(String id) {
    switch (id) {
      case 'reservaciones':
        return 'Reservaciones';
      case 'preorden':
        return 'Preorden';
      case 'estacionamiento':
        return 'Estacionamiento';
      case 'acceso_discapacidad':
        return 'Acceso con silla de ruedas';
      case 'terraza':
        return 'Terraza';
      case 'wifi':
        return 'Wi-Fi Gratis';
      case 'musica_en_vivo':
        return 'Música en vivo';
      case 'pet_friendly':
        return 'Apto para mascotas';
      default:
        return id.replaceAll('_', ' ');
    }
  }
}
