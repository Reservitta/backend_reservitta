import 'package:flutter/material.dart';
import '../models/categoria_model.dart';
import '../models/occasion_booking.dart';
import '../models/platillo_model.dart';
import '../models/reservation_draft_model.dart';
import '../models/restaurant_model.dart';
import '../services/categoria_service.dart';
import '../services/ocasion_service.dart';
import '../viewmodels/ocasion_selection_viewmodel.dart';
import 'widgets/ocasion_step.dart';
import '../services/platillo_service.dart';
import '../services/auth_service.dart';
import '../viewmodels/pedido_viewmodel.dart';
import 'mi_pedido_view.dart';
import 'widgets/platillo_detalle_sheet.dart';
import 'widgets/platillo_menu_card.dart';

/// Pantalla de Personalización de Visita (HU16, HU15-RF02, HU16-RF02, HU16-RF04, HU16-RF05, HU17-RF01)
///
/// Permite al comensal personalizar su visita antes de confirmar la reserva:
/// 1. Preorden de platillos con detalle de cantidad y observaciones en texto libre (HU16-RF04, HU17-RF01),
///    edición de platillos agregados, badge `"Pedido (n)"` y resumen `"Mi pedido"` (HU16-RF05),
///    administrados por [PedidoViewModel].
/// 2. Registro de alergias alimentarias y notas para cocina.
/// 3. Selección de ocasión especial y sus amenidades/experiencias (HU18/HU33).
///
/// Al confirmar, utiliza el mismo endpoint unificado de creación de reservas (HU15-RF02).
class PersonalizeVisitView extends StatefulWidget {
  final RestaurantModel restaurant;
  final ReservationDraftModel draft;
  final PedidoViewModel? pedidoViewModel;
  final CategoriaService? categoriaService;
  final PlatilloService? platilloService;
  final OcasionService? ocasionService;
  final AuthService? authService;
  final bool? isAuthenticated;
  final Future<void> Function(ReservationDraftModel updatedDraft)? onConfirm;

  const PersonalizeVisitView({
    super.key,
    required this.restaurant,
    required this.draft,
    this.pedidoViewModel,
    this.categoriaService,
    this.platilloService,
    this.ocasionService,
    this.authService,
    this.isAuthenticated,
    this.onConfirm,
  });

  @override
  State<PersonalizeVisitView> createState() => _PersonalizeVisitViewState();
}

class _PersonalizeVisitViewState extends State<PersonalizeVisitView>
    with SingleTickerProviderStateMixin {
  late final CategoriaService _categoriaService;
  late final PlatilloService _platilloService;
  late final OcasionService _ocasionService;
  late final PedidoViewModel _pedidoViewModel;
  late final bool _isExternalPedidoViewModel;
  late final AuthService _authService;

  String _categoriaSeleccionadaId = 'todas';

  bool get _hasSession =>
      widget.isAuthenticated ??
      (_authService.currentUser != null && !_authService.currentUser!.isAnonymous);

  late TabController _tabController;

  // Catálogo cacheado para abrir edición desde "Mi pedido"
  final Map<String, PlatilloModel> _catalogoPorId = {};

  // Estado local de alergias y ocasión
  final Set<String> _alergiasSeleccionadas = {};
  final TextEditingController _notasAlergiasCtrl = TextEditingController();
  OcasionSelectionViewModel? _ocasionVm;
  Future<OcasionSelectionViewModel>? _ocasionVmFuture;

  bool _isProcessing = false;

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);

  static const List<String> _alergiasComunes = [
    'Gluten',
    'Lácteos',
    'Mariscos',
    'Frutos secos',
    'Cacahuates',
    'Huevo',
    'Soya',
    'Pescado',
  ];

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _categoriaService = widget.categoriaService ?? CategoriaService();
    _platilloService = widget.platilloService ?? PlatilloService();
    _ocasionService = widget.ocasionService ?? OcasionService();
    _isExternalPedidoViewModel = widget.pedidoViewModel != null;
    _pedidoViewModel = widget.pedidoViewModel ??
        PedidoViewModel(initialItems: widget.draft.preordenItems);

    _tabController = TabController(length: 3, vsync: this);

    _alergiasSeleccionadas.addAll(widget.draft.alergias);
    _notasAlergiasCtrl.text = widget.draft.notasAlergias;
  }

  Stream<List<CategoriaModel>> _getCategoriasStream() {
    if (widget.categoriaService != null) {
      return widget.categoriaService!.getCategoriasStream(widget.restaurant.id);
    }
    try {
      return _categoriaService.getCategoriasStream(widget.restaurant.id);
    } catch (_) {
      return Stream.value(const []);
    }
  }

  @override
  void dispose() {
    if (!_isExternalPedidoViewModel) {
      _pedidoViewModel.dispose();
    }
    _tabController.dispose();
    _notasAlergiasCtrl.dispose();
    super.dispose();
  }

  // Cálculos de subtotal
  double get _subtotalPreorden => _pedidoViewModel.subtotal;

  double get _totalExperiencias {
    final vm = _ocasionVm;
    if (vm != null) return vm.totalExperiencias;
    return OccasionBooking.totalExperiencias(widget.draft.experiencias);
  }

  /// Carga las ocasiones disponibles y los postres del menú para el paso de ocasión
  /// (HU18-RF02, RF03 y RF04).
  Future<OcasionSelectionViewModel> _cargarOcasionVm() async {
    final ocasiones = await _ocasionService.getOcasionesDisponibles(widget.restaurant.id);

    Future<List<T>> primero<T>(Stream<List<T>> Function() abrir) async {
      try {
        return await abrir().first.timeout(const Duration(seconds: 8));
      } catch (_) {
        return <T>[];
      }
    }

    final categorias = await primero<CategoriaModel>(_getCategoriasStream);
    final platillos = await primero<PlatilloModel>(
      () => _platilloService.getPlatillosActivosStream(widget.restaurant.id),
    );
    final idsPostre = {
      for (final c in categorias)
        if (c.tipo.toLowerCase() == 'postre' || c.nombre.toLowerCase().contains('postre'))
          c.id,
    };

    final vm = OcasionSelectionViewModel(
      ocasiones: ocasiones,
      pedido: _pedidoViewModel,
      catalogoPostres: [for (final p in platillos) if (idsPostre.contains(p.categoriaId)) p],
      categoriasPostre: idsPostre,
      ocasionInicial: widget.draft.ocasionEspecial,
      experienciasIniciales: widget.draft.experiencias,
    );
    vm.addListener(() {
      if (mounted) setState(() {});
    });
    _ocasionVm = vm;
    return vm;
  }

  double get _totalPersonalizacion => _subtotalPreorden + _totalExperiencias;

  /// Abre el detalle del platillo (HU16-RF04 / HU16-RF05 / HU17-RF01).
  /// Si ya está agregado en [_pedidoViewModel], se abre prellenado con su cantidad y observación guardadas.
  Future<void> _abrirDetallePlatillo(PlatilloModel p) async {
    _catalogoPorId[p.id] = p;
    await PlatilloDetalleSheet.show(
      context,
      platillo: p,
      pedidoViewModel: _pedidoViewModel,
    );
  }

  Future<void> _navegarAMiPedidoView() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MiPedidoView(
          restaurant: widget.restaurant,
          draft: widget.draft,
          pedidoViewModel: _pedidoViewModel,
          catalogoPorId: _catalogoPorId,
          onAgregarMasPlatillos: () => Navigator.of(context).pop(),
          onContinuarOcasion: () {
            Navigator.of(context).pop('ir_a_ocasion');
          },
        ),
      ),
    );
    if (result == 'ir_a_ocasion' && mounted) {
      _tabController.animateTo(2); // Avanza a Ocasión Especial (HU18)
    }
  }

  Future<void> _editarItemDesdeMiPedido(PedidoItem item) async {
    final platillo = _catalogoPorId[item.platilloId] ??
        PlatilloModel(
          id: item.platilloId,
          categoriaId: item.categoriaId,
          nombre: item.nombre,
          descripcion: item.descripcion,
          precio: item.precio,
          imagenUrl: item.imagenUrl,
          etiquetas: item.etiquetas,
        );
    await _abrirDetallePlatillo(platillo);
  }

  void _mostrarMiPedidoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AnimatedBuilder(
          animation: _pedidoViewModel,
          builder: (context, _) {
            return Container(
              key: const ValueKey('sheet_mi_pedido'),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.80,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mi pedido',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      IconButton(
        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_pedidoViewModel.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Tu pedido está vacío.',
                          style: TextStyle(color: _textMuted),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _pedidoViewModel.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) {
                          final item = _pedidoViewModel.items[idx];
                          return _buildMiPedidoItemTile(
                            item,
                            onTapEditar: () {
                              Navigator.of(ctx).pop();
                              _editarItemDesdeMiPedido(item);
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
      },
    );
  }

  Future<void> _confirmarPersonalizacion() async {
    final updatedDraft = widget.draft.copyWith(
      preordenItems: _pedidoViewModel.preordenItems,
      alergias: _alergiasSeleccionadas.toList(),
      notasAlergias: _notasAlergiasCtrl.text.trim(),
      // Si nunca se abrió la pestaña de ocasión se conserva lo que ya traía el borrador.
      ocasionEspecial: () => _ocasionVm != null
          ? _ocasionVm!.ocasionEspecialMap
          : widget.draft.ocasionEspecial,
      experiencias: _ocasionVm != null
          ? _ocasionVm!.experienciasMaps
          : widget.draft.experiencias,
    );

    if (widget.onConfirm != null) {
      setState(() => _isProcessing = true);
      try {
        await widget.onConfirm!(updatedDraft);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else {
      Navigator.pop(context, updatedDraft);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pedidoViewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _lightBg,
          appBar: AppBar(
            title: const Text('Personalizar mi visita'),
            backgroundColor: _lightBg,
            elevation: 0,
            actions: [
              // Badge "Pedido (n)" actualizado en tiempo real (HU16-RF05 Criterio 4)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ActionChip(
                  key: const ValueKey('badge_pedido_count'),
                  avatar: const Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: _primaryTerracotta,
                  ),
                  label: Text(
                    _pedidoViewModel.badgePedidoTexto,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: _primaryTerracotta,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _primaryTerracotta),
                  onPressed: _hasSession ? _navegarAMiPedidoView : _mostrarMiPedidoSheet,
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: _primaryTerracotta,
              indicatorColor: _primaryTerracotta,
              unselectedLabelColor: _textMuted,
              tabs: [
                Tab(
                  icon: const Icon(Icons.restaurant_menu),
                  text: 'Preorden (${_pedidoViewModel.totalCantidad})',
                ),
                Tab(
                  icon: const Icon(Icons.health_and_safety_outlined),
                  text: 'Alergias (${_alergiasSeleccionadas.length})',
                ),
                Tab(
                  icon: const Icon(Icons.celebration_outlined),
                  text: (_ocasionVm?.hayOcasion ?? widget.draft.ocasionEspecial != null)
                      ? 'Ocasión (1)'
                      : 'Ocasión',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPreordenTab(),
              _buildAlergiasTab(),
              _buildOcasionesTab(),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: PREORDEN (HU16-RF02, HU16-RF03, HU16-RF04, HU16-RF05, HU17-RF01)
  // ---------------------------------------------------------------------------
  Widget _buildPreordenTab() {
    return StreamBuilder<List<CategoriaModel>>(
      stream: _getCategoriasStream(),
      builder: (context, catSnap) {
        final categorias = catSnap.data ?? [];

        return StreamBuilder<List<PlatilloModel>>(
          stream: _platilloService.getPlatillosActivosStream(widget.restaurant.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _primaryTerracotta),
              );
            }

            final platillos = snapshot.data ?? [];
            for (final p in platillos) {
              _catalogoPorId[p.id] = p;
            }

            if (platillos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.menu_book, size: 48, color: _textMuted),
                      SizedBox(height: 12),
                      Text(
                        'No hay platillos disponibles para preordenar.',
                        style: TextStyle(color: _textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Construir lista de categorías para las pestañas (HU16-RF03 Criterio 1)
            final categoriasTabs = <CategoriaModel>[];
            if (categorias.isNotEmpty) {
              categoriasTabs.addAll(categorias);
            } else {
              final uniqueCatIds = platillos
                  .map((p) => p.categoriaId)
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .toList();
              for (var i = 0; i < uniqueCatIds.length; i++) {
                final id = uniqueCatIds[i];
                final nombre = id.replaceAll('cat_', '').replaceAll('_', ' ');
                final nombreCapitalizado = nombre.isNotEmpty
                    ? '${nombre[0].toUpperCase()}${nombre.substring(1)}'
                    : id;
                categoriasTabs.add(CategoriaModel(
                  id: id,
                  nombre: nombreCapitalizado,
                  nombreNormalizado: CategoriaModel.normalizarNombre(nombreCapitalizado),
                  orden: i + 1,
                ));
              }
            }

            final todasLasTabs = [
              const CategoriaModel(
                id: 'todas',
                nombre: 'Todas',
                nombreNormalizado: 'todas',
                orden: 0,
              ),
              ...categoriasTabs,
            ];

            // Filtrar platillos según la pestaña seleccionada
            final platillosFiltrados = _categoriaSeleccionadaId == 'todas'
                ? platillos
                : platillos.where((p) => p.categoriaId == _categoriaSeleccionadaId).toList();

            final initialIndex = todasLasTabs.indexWhere((c) => c.id == _categoriaSeleccionadaId);
            final activeIndex = initialIndex >= 0 ? initialIndex : 0;

            final content = ListView(
              key: const ValueKey('lista_preorden_platillos'),
              padding: const EdgeInsets.all(16),
              children: [
                // Botón "Ver mi pedido (n platillos)" (HU16-RF06 Criterio 1 - solo con sesión)
                if (_hasSession && _pedidoViewModel.isNotEmpty) ...[
                  Container(
                    key: const ValueKey('container_btn_ver_mi_pedido'),
                    margin: const EdgeInsets.only(bottom: 12),
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('btn_ver_mi_pedido'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryTerracotta,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: Text(
                        'Ver mi pedido (${_pedidoViewModel.totalCantidad} ${_pedidoViewModel.totalCantidad == 1 ? "platillo" : "platillos"})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _navegarAMiPedidoView,
                    ),
                  ),
                ],
                // Sección "Mi pedido" reflejada de inmediato (HU16-RF05 Criterio 4 / HU17-RF01 Criterio 3)
                if (_pedidoViewModel.isNotEmpty) ...[
                  _buildMiPedidoSection(),
                  const SizedBox(height: 16),
                ],
                // Pestañas por categoría (HU16-RF03 Criterio 1)
                if (categoriasTabs.isNotEmpty) ...[
                  Container(
                    key: const ValueKey('container_categorias_preorden'),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: TabBar(
                      key: const ValueKey('tabbar_categorias_preorden'),
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: _primaryTerracotta,
                      unselectedLabelColor: _textMuted,
                      indicatorColor: _primaryTerracotta,
                      indicatorWeight: 3.0,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13.5),
                      tabs: todasLasTabs.map((cat) {
                        return Tab(
                          key: ValueKey('tab_categoria_${cat.id}'),
                          text: cat.nombre,
                        );
                      }).toList(),
                      onTap: (index) {
                        setState(() {
                          _categoriaSeleccionadaId = todasLasTabs[index].id;
                        });
                      },
                    ),
                  ),
                ],
                if (platillosFiltrados.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.restaurant_outlined, size: 40, color: _textMuted),
                          SizedBox(height: 10),
                          Text(
                            'No hay platillos disponibles en esta categoría.',
                            style: TextStyle(color: _textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...platillosFiltrados.map((p) {
                    final cantidad = _pedidoViewModel.cantidadDePlatillo(p.id);
                    final observacion = _pedidoViewModel.observacionDePlatillo(p.id);

                    return PlatilloMenuCard(
                      platillo: p,
                      mode: PlatilloCardMode.preorden,
                      cantidad: cantidad,
                      observacion: observacion,
                      onAgregar: () => _abrirDetallePlatillo(p),
                      onEditar: () => _abrirDetallePlatillo(p),
                      onTap: () => _abrirDetallePlatillo(p),
                    );
                  }),
              ],
            );

            if (categoriasTabs.isNotEmpty) {
              return DefaultTabController(
                key: ValueKey('cat_tab_ctrl_${todasLasTabs.map((e) => e.id).join("_")}_$activeIndex'),
                length: todasLasTabs.length,
                initialIndex: activeIndex,
                child: content,
              );
            }

            return content;
          },
        );
      },
    );
  }

  Widget _buildMiPedidoSection() {
    return Container(
      key: const ValueKey('seccion_mi_pedido'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryTerracotta.withAlpha(90), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: _primaryTerracotta,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Mi pedido',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${_pedidoViewModel.subtotal.toStringAsFixed(2)} MXN',
                key: const ValueKey('mi_pedido_subtotal'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _primaryTerracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._pedidoViewModel.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildMiPedidoItemTile(
                item,
                onTapEditar: () => _editarItemDesdeMiPedido(item),
              ),
            ),
          ),
          if (_hasSession) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('btn_abrir_pantalla_mi_pedido'),
                icon: const Icon(Icons.fullscreen, size: 18),
                label: const Text('Ver pantalla completa de mi pedido'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryTerracotta,
                  side: const BorderSide(color: _primaryTerracotta),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _navegarAMiPedidoView,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiPedidoItemTile(
    PedidoItem item, {
    required VoidCallback onTapEditar,
  }) {
    return Container(
      key: ValueKey('mi_pedido_item_${item.platilloId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.cantidad}x ${item.nombre}',
                  key: ValueKey('mi_pedido_nombre_${item.platilloId}'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${item.total.toStringAsFixed(2)} MXN',
                  key: ValueKey('mi_pedido_total_${item.platilloId}'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryTerracotta,
                  ),
                ),
                if (item.observacion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Observación: "${item.observacion}"',
                    key: ValueKey('mi_pedido_obs_${item.platilloId}'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: _textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            key: ValueKey('btn_mi_pedido_editar_${item.platilloId}'),
            onPressed: onTapEditar,
            child: const Text(
              'Editar',
              style: TextStyle(
                color: _primaryTerracotta,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: ALERGIAS ALIMENTARIAS
  // ---------------------------------------------------------------------------
  Widget _buildAlergiasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alergias e intolerancias alimentarias',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecciona si alguien en tu mesa presenta alguna de estas alergias. La cocina tomará las precauciones de preparación correspondientes.',
            style: TextStyle(fontSize: 13, color: _textMuted),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _alergiasComunes.map((alergia) {
              final seleccionada = _alergiasSeleccionadas.contains(alergia);
              return FilterChip(
                key: ValueKey('chip_alergia_$alergia'),
                label: Text(alergia),
                selected: seleccionada,
                selectedColor: _primaryTerracotta.withAlpha(40),
                checkmarkColor: _primaryTerracotta,
                labelStyle: TextStyle(
                  color: seleccionada ? _primaryTerracotta : _textDark,
                  fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _alergiasSeleccionadas.add(alergia);
                    } else {
                      _alergiasSeleccionadas.remove(alergia);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          const Text(
            'Notas o especificaciones para cocina (Opcional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('input_notas_alergias'),
            controller: _notasAlergiasCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Ej. Uno de los invitados es celíaco estricto; evitar contaminación cruzada con mariscos.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: OCASIÓN ESPECIAL (HU18 / HU33)
  // ---------------------------------------------------------------------------
  Widget _buildOcasionesTab() {
    _ocasionVmFuture ??= _cargarOcasionVm();
    return FutureBuilder<OcasionSelectionViewModel>(
      future: _ocasionVmFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryTerracotta),
          );
        }

        final vm = snapshot.data;
        if (vm == null || vm.ocasiones.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.celebration_outlined, size: 48, color: _textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Este restaurante no tiene paquetes de ocasión especial disponibles en este momento.',
                    style: TextStyle(color: _textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return OcasionStep(vm: vm, onContinuar: _confirmarPersonalizacion);
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_totalPersonalizacion > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total de personalización:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '\$${_totalPersonalizacion.toStringAsFixed(2)} MXN',
                      key: const ValueKey('texto_total_personalizacion'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _primaryTerracotta,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const ValueKey('btn_confirmar_reserva_personalizada'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryTerracotta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_isProcessing || !(_ocasionVm?.puedeContinuar ?? true))
                    ? null
                    : _confirmarPersonalizacion,
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirmar reserva con personalización',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
