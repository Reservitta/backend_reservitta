import 'package:flutter/material.dart';

import '../models/categoria_model.dart';
import '../models/platillo_model.dart';
import '../models/restaurant_model.dart';
import '../services/auth_service.dart';
import '../services/categoria_service.dart';
import '../services/platillo_service.dart';
import '../services/preorden_cache_service.dart';
import '../services/restaurant_service.dart';
import '../viewmodels/auth_modal_viewmodel.dart';
import 'auth_modal_dialog.dart';
import 'reservation_flow_view.dart';
// import 'widgets/preorden_item_dialog.dart';
import 'widgets/branch_picker_dialog.dart';
import 'widgets/platillo_menu_card.dart';
import 'widgets/preorden_resumen_sheet.dart';
import '../theme/app_theme.dart';

/// Pantalla pública de detalle del restaurante (HU01-RF03, HU05)
/// Accesible libremente sin necesidad de iniciar sesión o registrarse.
class RestaurantDetailView extends StatefulWidget {
  final RestaurantModel restaurant;
  final AuthService? authService;
  final CategoriaService? categoriaService;
  final PlatilloService? platilloService;
  final PreordenCacheService? preordenCacheService;
  final RestaurantService? restaurantService;
  final bool bypassAuthForTesting;

  const RestaurantDetailView({
    super.key,
    required this.restaurant,
    this.authService,
    this.categoriaService,
    this.platilloService,
    this.preordenCacheService,
    this.restaurantService,
    this.bypassAuthForTesting = false,
  });

  @override
  State<RestaurantDetailView> createState() => _RestaurantDetailViewState();
}

class _RestaurantDetailViewState extends State<RestaurantDetailView> {
  late final AuthService _authService;
  late final CategoriaService _categoriaService;
  late final PlatilloService _platilloService;
  late final PreordenCacheService _preordenCacheService;

  late Stream<List<CategoriaModel>> _categoriasStream;
  late Stream<List<PlatilloModel>> _platillosStream;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _categoriaService = widget.categoriaService ?? CategoriaService();
    _platilloService = widget.platilloService ?? PlatilloService();
    _preordenCacheService =
        widget.preordenCacheService ?? PreordenCacheService();

    _categoriasStream = _categoriaService.getCategoriasStream(widget.restaurant.id);
    _platillosStream = _platilloService.getPlatillosActivosStream(widget.restaurant.id);
  }

  void _abrirResumenPreorden() {
    PreordenResumenSheet.show(
      context,
      restaurantId: widget.restaurant.id,
      restaurantNombre: widget.restaurant.nombre,
      cacheService: _preordenCacheService,
    );
  }

  /*
  void _procesarPreordenItem(Map<String, dynamic> item) {
    _preordenCacheService.agregarItem(widget.restaurant.id, item);
    final obs = (item['observacion'] as String? ?? '').trim();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          obs.isNotEmpty
              ? 'Agregado a preorden: ${item['nombre']} (${item['cantidad']}x) - "$obs"'
              : 'Agregado a preorden: ${item['nombre']} (${item['cantidad']}x)',
        ),
        backgroundColor: const Color(0xFF2C5E94),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver Preorden',
          textColor: Colors.amber,
          onPressed: _abrirResumenPreorden,
        ),
      ),
    );
  }
  */

  /// HU01-RF03 Criterio 3: Las acciones que sí requieren cuenta (como reservar)
  /// redirigen a login o registro.
  void _onReservarPressed() {
    final user = _authService.currentUser;
    if (!widget.bypassAuthForTesting && user == null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Para reservar en ${widget.restaurant.nombre} necesitas una cuenta en Reservitta.',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Iniciar sesión',
            onPressed: () {
              messenger.clearSnackBars();
              AuthModalDialog.show<String>(
                context,
                initialMode: AuthMode.login,
                showGuestOption: true,
              ).then((res) async {
                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  if (_authService.currentUser != null || res == 'guest') {
                    if (res == 'guest' && _authService.currentUser == null) {
                      try {
                        await _authService.signInAnonymously();
                      } catch (_) {}
                    }
                    if (mounted) _iniciarFlujoReserva();
                  }
                }
              });
            },
          ),
        ),
      );
      AuthModalDialog.show<String>(
        context,
        initialMode: AuthMode.login,
        showGuestOption: true,
      ).then((res) async {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          if (_authService.currentUser != null || res == 'guest') {
            if (res == 'guest' && _authService.currentUser == null) {
              try {
                await _authService.signInAnonymously();
              } catch (_) {}
            }
            if (mounted) _iniciarFlujoReserva();
          }
        }
      });
      return;
    }

    _iniciarFlujoReserva();
  }

  /// Abre la ventana de sucursales; al continuar entra al flujo de reserva con la
  /// sucursal elegida.
  Future<void> _iniciarFlujoReserva() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    final sucursal = await BranchPickerDialog.show(
      context,
      restaurant: widget.restaurant,
      service: widget.restaurantService ?? RestaurantService(),
    );
    if (sucursal == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationFlowView(
          restaurant: widget.restaurant,
          initialBranch: sucursal,
          restaurantService: widget.restaurantService,
          createReservationOnConfirm: true,
          enableContactStep: true,
          categoriaService: _categoriaService,
          platilloService: _platilloService,
        ),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.familiaTitulos,
            fontWeight: FontWeight.w700,
            fontVariations: [FontVariation('wght', 700)],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al listado',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Acceso directo a la preorden en caché desde la barra superior
          AnimatedBuilder(
            animation: _preordenCacheService,
            builder: (context, _) {
              final count = _preordenCacheService.contarItems(r.id);
              if (count == 0) return const SizedBox.shrink();

              return IconButton(
                key: const ValueKey('btn_appbar_preorden_cache'),
                icon: Badge(
                  label: Text('$count'),
                  backgroundColor: AppColors.acento,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                tooltip: 'Ver preorden en caché',
                onPressed: _abrirResumenPreorden,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPortada(theme, r),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final dosColumnas = constraints.maxWidth >= 860;
                      final principal = _buildColumnaPrincipal(theme, r);
                      final lateral = _buildColumnaReserva(theme, r);
                      if (dosColumnas) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: principal),
                            const SizedBox(width: 32),
                            SizedBox(width: 360, child: lateral),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          lateral,
                          const SizedBox(height: 28),
                          principal,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Portada a todo el ancho con el nombre y la dirección sobre la foto.
  Widget _buildPortada(ThemeData theme, RestaurantModel r) {
    final Widget fondo = r.imagenPrincipalUrl.isNotEmpty
        ? Image.network(
            r.imagenPrincipalUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackBanner(theme, r),
          )
        : _buildFallbackBanner(theme, r);
    final conFoto = r.imagenPrincipalUrl.isNotEmpty;

    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          fondo,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (conFoto ? Colors.black : AppColors.marca).withValues(alpha: 0.72),
                ],
                stops: const [0.35, 1],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 8, color: AppColors.exito),
                          const SizedBox(width: 6),
                          Text(
                            r.estado.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.exito,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      r.nombre,
                      style: const TextStyle(
                        fontFamily: AppTheme.familiaTitulos,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation('wght', 700)],
                        fontSize: 38,
                        height: 1.1,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                    if (r.direccion.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              r.direccion,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titulo(String texto, {IconData? icono}) {
    return Row(
      children: [
        if (icono != null) ...[
          Icon(icono, color: AppColors.marca, size: 24),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            texto,
            style: const TextStyle(
              fontFamily: AppTheme.familiaTitulos,
              fontWeight: FontWeight.w700,
              fontVariations: [FontVariation('wght', 700)],
              fontSize: 24,
              color: AppColors.texto,
            ),
          ),
        ),
      ],
    );
  }

  /// Descripción, servicios y menú.
  Widget _buildColumnaPrincipal(ThemeData theme, RestaurantModel r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.descripcion.isNotEmpty) ...[
          Text(
            r.descripcion,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textoSuave,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Servicios disponibles
        if (r.serviciosIds.isNotEmpty || r.serviciosPersonalizados.isNotEmpty) ...[
          _titulo('Servicios e Instalaciones'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...r.serviciosIds.map((id) => Chip(
                    label: Text(_formatearServicio(id)),
                    avatar: const Icon(Icons.check, size: 16, color: AppColors.exito),
                    backgroundColor: AppColors.superficie,
                  )),
              ...r.serviciosPersonalizados.map((p) => Chip(
                    label: Text(p),
                    avatar: const Icon(Icons.star_outline, size: 16, color: AppColors.acento),
                    backgroundColor: AppColors.superficie,
                  )),
            ],
          ),
          const SizedBox(height: 32),
        ],

        // Menú del restaurante
        _titulo('Menú y Platillos', icono: Icons.restaurant_menu),
        const SizedBox(height: 16),
        _buildMenuSection(theme),
      ],
    );
  }

  /// Tarjeta lateral: reservar, contacto y horarios.
  Widget _buildColumnaReserva(ThemeData theme, RestaurantModel r) {
    return Card(
      elevation: 0,
      color: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divisor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reserva tu mesa',
              style: TextStyle(
                fontFamily: AppTheme.familiaTitulos,
                fontWeight: FontWeight.w700,
                fontVariations: [FontVariation('wght', 700)],
                fontSize: 22,
                color: AppColors.texto,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Elige fecha, hora y la mesa que prefieras.',
              style: TextStyle(color: AppColors.textoSuave, fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('boton_reservar_mesa'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 22),
              label: const Text(
                'Haz tu Reserva',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: _onReservarPressed,
            ),

            // Contacto
            if (r.telefono.isNotEmpty || r.correo.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              if (r.telefono.isNotEmpty)
                _filaContacto(Icons.phone_outlined, r.telefono),
              if (r.correo.isNotEmpty)
                _filaContacto(Icons.email_outlined, r.correo),
            ],

            // Horarios
            if (r.horarios.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 14),
              const Text(
                'Horarios de Atención',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.texto,
                ),
              ),
              const SizedBox(height: 10),
              ...r.horarios.entries.map((e) {
                final h = e.value;
                final dia = e.key[0].toUpperCase() + e.key.substring(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dia, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        h.abierto ? '${h.apertura} - ${h.cierre}' : 'Cerrado',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: h.abierto ? AppColors.exito : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filaContacto(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icono, size: 20, color: AppColors.marca),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  /// Portada sin foto: degradado café con la inicial del restaurante.
  Widget _buildFallbackBanner(ThemeData theme, RestaurantModel r) {
    final nombre = r.nombre.trim();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.marcaSuave, AppColors.marcaMedia],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
          child: nombre.isEmpty
              ? const Icon(Icons.restaurant, size: 40, color: AppColors.marca)
              : Text(
                  nombre.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppTheme.familiaTitulos,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppColors.marca,
                  ),
                ),
        ),
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
                          style: const TextStyle(
                            fontFamily: AppTheme.familiaTitulos,
                            fontWeight: FontWeight.w700,
                            fontVariations: [FontVariation('wght', 700)],
                            fontSize: 19,
                            color: AppColors.marca,
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
    return PlatilloMenuCard(
      platillo: p,
      mode: PlatilloCardMode.readOnly,
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
