import 'package:flutter/material.dart';

import '../models/categoria_model.dart';
import '../models/platillo_model.dart';
import '../models/restaurant_model.dart';
import '../services/auth_service.dart';
import '../services/categoria_service.dart';
import '../services/pedido_service.dart';
import '../services/platillo_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/carrito_viewmodel.dart';
import 'pedido_checkout_view.dart';
import 'widgets/platillo_menu_card.dart';
import 'widgets/transferencia_widgets.dart';

/// Menú para pedir a domicilio o para recoger: el cliente agrega platillos a su
/// carrito (sin personalización) y continúa al pago y la entrega.
class PedidoOnlineView extends StatefulWidget {
  final RestaurantModel restaurant;
  final CategoriaService? categoriaService;
  final PlatilloService? platilloService;
  final PedidoService? pedidoService;
  final AuthService? authService;
  final CarritoViewModel? carrito;

  const PedidoOnlineView({
    super.key,
    required this.restaurant,
    this.categoriaService,
    this.platilloService,
    this.pedidoService,
    this.authService,
    this.carrito,
  });

  @override
  State<PedidoOnlineView> createState() => _PedidoOnlineViewState();
}

class _PedidoOnlineViewState extends State<PedidoOnlineView> {
  late final CarritoViewModel _carrito = widget.carrito ?? CarritoViewModel();
  late final Stream<List<PlatilloModel>> _platillos =
      (widget.platilloService ?? PlatilloService())
          .getPlatillosActivosStream(widget.restaurant.id);
  late final Stream<List<CategoriaModel>> _categorias =
      (widget.categoriaService ?? CategoriaService())
          .getCategoriasStream(widget.restaurant.id);

  @override
  void dispose() {
    if (widget.carrito == null) _carrito.dispose();
    super.dispose();
  }

  void _irAlPago() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PedidoCheckoutView(
          restaurant: widget.restaurant,
          carrito: _carrito,
          pedidoService: widget.pedidoService,
          authService: widget.authService,
        ),
      ),
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          texto,
          style: const TextStyle(
            fontFamily: AppTheme.familiaTitulos,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            color: AppColors.marca,
          ),
        ),
      );

  Widget _tarjeta(PlatilloModel p) {
    return AnimatedBuilder(
      animation: _carrito,
      builder: (context, _) => PlatilloMenuCard(
        // En pedidos a domicilio no hay personalización: se oculta esa etiqueta.
        platillo: p.copyWith(permitePersonalizacion: false),
        mode: PlatilloCardMode.preorden,
        cantidad: _carrito.cantidadDe(p.id),
        onAgregar: () => _carrito.agregar(p),
        onIncrementar: () => _carrito.agregar(p),
        onDecrementar: () => _carrito.quitar(p.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: Text(
          'Pedir en ${widget.restaurant.nombre}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _carrito,
        builder: (context, _) {
          if (_carrito.vacio) return const SizedBox.shrink();
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divisor)),
              ),
              child: FilledButton(
                key: const ValueKey('btn_ver_carrito'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _irAlPago,
                child: Text(
                  'Ver mi pedido (${_carrito.totalPlatillos}) · ${formatoDinero(_carrito.total)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<List<PlatilloModel>>(
        stream: _platillos,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('No se pudo cargar el menú.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final platillos = snap.data!;
          if (platillos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Este restaurante aún no tiene platillos disponibles para pedir.',
                  key: ValueKey('menu_pedido_vacio'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return StreamBuilder<List<CategoriaModel>>(
            stream: _categorias,
            builder: (context, catSnap) {
              final categorias = catSnap.data ?? const <CategoriaModel>[];
              final secciones = <Widget>[];
              if (categorias.isEmpty) {
                secciones.addAll(platillos.map(_tarjeta));
              } else {
                final usados = <String>{};
                for (final c in categorias) {
                  final delGrupo = platillos.where((p) => p.categoriaId == c.id).toList();
                  if (delGrupo.isEmpty) continue;
                  usados.addAll(delGrupo.map((p) => p.id));
                  secciones
                    ..add(_titulo(c.nombre))
                    ..addAll(delGrupo.map(_tarjeta));
                }
                // Platillos cuya categoría ya no existe: no se pierden del menú.
                final sueltos = platillos.where((p) => !usados.contains(p.id)).toList();
                if (sueltos.isNotEmpty) {
                  secciones
                    ..add(_titulo('Otros'))
                    ..addAll(sueltos.map(_tarjeta));
                }
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: secciones,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
