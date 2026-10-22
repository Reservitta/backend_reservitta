import 'package:flutter/material.dart';
import '../models/categoria_model.dart';
import '../models/platillo_model.dart';
import '../services/categoria_service.dart';
import '../services/platillo_service.dart';
import '../viewmodels/platillo_viewmodel.dart';
import 'widgets/platillo_card.dart';
import 'widgets/platillo_form_dialog.dart';

/// Pantalla de Gestión del Menú y Platillos (HU24-RF04 y HU32-RF01)
/// Permite:
/// - Alta y edición de platillos sin salir de la lista principal.
/// - Switch para marcar disponible/agotado con un solo toque.
/// - Reflejo en tiempo real para visitantes (HU06).
/// - Confirmación visual breve (SnackBar) al guardar cambios.
class PlatilloListView extends StatefulWidget {
  final String restaurantId;
  final PlatilloService? platilloService;
  final CategoriaService? categoriaService;
  final PlatilloViewModel? viewModel;
  final bool showAppBar;

  const PlatilloListView({
    super.key,
    required this.restaurantId,
    this.platilloService,
    this.categoriaService,
    this.viewModel,
    this.showAppBar = true,
  });

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _primary = Color(0xFFE4572E);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamAccent = Color(0xFFF3ECE1);
  static const Color _creamLight = Color(0xFFFAF5ED);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);
  static const Color _success = Color(0xFF2E7D32);
  static const Color _error = Color(0xFFD84A38);

  @override
  State<PlatilloListView> createState() => _PlatilloListViewState();
}

class _PlatilloListViewState extends State<PlatilloListView> {
  late final PlatilloViewModel _viewModel;
  late final CategoriaService _categoriaService;

  String? _categoriaFiltroId; // null = Todas las categorías
  String _busquedaTexto = '';

  @override
  void initState() {
    super.initState();
    _categoriaService = widget.categoriaService ?? CategoriaService();
    _viewModel = widget.viewModel ??
        PlatilloViewModel(
          restaurantId: widget.restaurantId,
          platilloService: widget.platilloService,
        );
    _viewModel.iniciarEscuchaEnTiempoReal(soloActivos: false);
  }

  @override
  void dispose() {
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  void _mostrarSnackBar({
    required String mensaje,
    bool esError = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            esError ? PlatilloListView._error : PlatilloListView._success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _abrirDialogoCrear() async {
    final resultado = await PlatilloFormDialog.show(
      context,
      restaurantId: widget.restaurantId,
      viewModel: _viewModel,
      categoriaService: _categoriaService,
    );

    if (resultado == true && mounted) {
      _mostrarSnackBar(mensaje: 'Platillo agregado al menú con éxito.');
    }
  }

  Future<void> _abrirDialogoEditar(PlatilloModel platillo) async {
    final resultado = await PlatilloFormDialog.show(
      context,
      restaurantId: widget.restaurantId,
      platillo: platillo,
      viewModel: _viewModel,
      categoriaService: _categoriaService,
    );

    if (resultado == true && mounted) {
      _mostrarSnackBar(
        mensaje: 'Platillo "${platillo.nombre}" actualizado exitosamente.',
      );
    }
  }

  Future<void> _conmutarDisponibilidad(
    PlatilloModel platillo,
    bool nuevoValor,
  ) async {
    final exito = await _viewModel.cambiarDisponibilidad(
      platillo,
      nuevoValor ? PlatilloModel.estadoActivo : PlatilloModel.estadoAgotado,
    );
    if (exito && mounted) {
      final estadoTexto = nuevoValor ? 'disponible' : 'agotado';
      _mostrarSnackBar(
        mensaje: 'Platillo "${platillo.nombre}" marcado como $estadoTexto.',
      );
    } else if (_viewModel.errorMessage != null && mounted) {
      _mostrarSnackBar(
        mensaje: _viewModel.errorMessage!,
        esError: true,
      );
    }
  }

  Future<void> _eliminarPlatillo(PlatilloModel platillo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar platillo?'),
        content: Text(
          'Estás a punto de eliminar "${platillo.nombre}". Esta acción no se puede deshacer.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PlatilloListView._error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final exito = await _viewModel.eliminarPlatillo(platillo.id);
      if (exito && mounted) {
        _mostrarSnackBar(mensaje: 'Platillo eliminado con éxito.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final todosLosPlatillos = _viewModel.platillosEnTiempoReal;

        // Filtrado por categoría y búsqueda
        final platillosFiltrados = todosLosPlatillos.where((p) {
          if (_categoriaFiltroId != null &&
              _categoriaFiltroId!.isNotEmpty &&
              p.categoriaId != _categoriaFiltroId) {
            return false;
          }
          if (_busquedaTexto.isNotEmpty) {
            final query = _busquedaTexto.toLowerCase();
            final coincideNombre = p.nombre.toLowerCase().contains(query);
            final coincideDesc = p.descripcion.toLowerCase().contains(query);
            return coincideNombre || coincideDesc;
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: PlatilloListView._lightBg,
          appBar: widget.showAppBar
              ? AppBar(
                  backgroundColor: Colors.white,
                  foregroundColor: PlatilloListView._textDark,
                  elevation: 0,
                  title: const Text(
                    'Gestión de Menú',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: PlatilloListView._textDark,
                    ),
                  ),
                )
              : null,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _abrirDialogoCrear,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo Platillo'),
            backgroundColor: PlatilloListView._primary,
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              if (_viewModel.isLoading)
                const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: PlatilloListView._creamLight,
                  color: PlatilloListView._primary,
                ),

              Expanded(
                child: StreamBuilder<List<CategoriaModel>>(
                  stream: _categoriaService
                      .getCategoriasStream(widget.restaurantId),
                  builder: (context, catSnap) {
                    final categorias = catSnap.data ?? [];
                    final Map<String, String> nombresCategorias = {
                      for (final c in categorias) c.id: c.nombre,
                    };

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: CustomScrollView(
                          slivers: [
                            // 1. Header con métricas y buscador
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (!widget.showAppBar) ...[
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Menú',
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: PlatilloListView._textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Administra los platillos de tu restaurante, precios y disponibilidad en tiempo real.',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: PlatilloListView._textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                    // Resumen contador
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 10,
                                      children: [
                                        Text(
                                          '${todosLosPlatillos.length} ${todosLosPlatillos.length == 1 ? 'platillo registrado' : 'platillos registrados'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: PlatilloListView._textMuted,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: PlatilloListView._creamAccent,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.sync_rounded,
                                                    size: 13,
                                                    color: PlatilloListView
                                                        ._primaryTerracotta,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Tiempo Real Activo',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: PlatilloListView
                                                          ._primaryTerracotta,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            ElevatedButton.icon(
                                              onPressed: _abrirDialogoCrear,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    PlatilloListView._primary,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 8,
                                                ),
                                              ),
                                              icon: const Icon(Icons.add_rounded,
                                                  size: 18),
                                              label: const Text(
                                                'Nuevo Platillo',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Buscador de texto
                                    TextField(
                                      onChanged: (val) {
                                        setState(() {
                                          _busquedaTexto = val.trim();
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText:
                                            'Buscar por nombre o ingredientes...',
                                        prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          color: PlatilloListView._textMuted,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color:
                                                PlatilloListView._cardBorder,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color:
                                                PlatilloListView._cardBorder,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: PlatilloListView._primary,
                                            width: 1.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // Filtro de categorías horizontal
                                    if (categorias.isNotEmpty) ...[
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            ChoiceChip(
                                              label: const Text('Todos'),
                                              selected:
                                                  _categoriaFiltroId == null,
                                              selectedColor: PlatilloListView
                                                  ._primaryTerracotta,
                                              backgroundColor:
                                                  PlatilloListView._creamLight,
                                              labelStyle: TextStyle(
                                                color: _categoriaFiltroId ==
                                                        null
                                                    ? Colors.white
                                                    : PlatilloListView
                                                        ._textDark,
                                                fontWeight:
                                                    _categoriaFiltroId == null
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                              ),
                                              onSelected: (_) {
                                                setState(() {
                                                  _categoriaFiltroId = null;
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            ...categorias.map((cat) {
                                              final isSel =
                                                  _categoriaFiltroId == cat.id;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 8),
                                                child: ChoiceChip(
                                                  label: Text(cat.nombre),
                                                  selected: isSel,
                                                  selectedColor: PlatilloListView
                                                      ._primaryTerracotta,
                                                  backgroundColor:
                                                      PlatilloListView
                                                          ._creamLight,
                                                  labelStyle: TextStyle(
                                                    color: isSel
                                                        ? Colors.white
                                                        : PlatilloListView
                                                            ._textDark,
                                                    fontWeight: isSel
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                  onSelected: (_) {
                                                    setState(() {
                                                      _categoriaFiltroId =
                                                          cat.id;
                                                    });
                                                  },
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // 2. Lista de platillos o estado vacío
                            if (platillosFiltrados.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: PlatilloListView._creamAccent
                                                .withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.restaurant_menu_rounded,
                                            size: 44,
                                            color: PlatilloListView
                                                ._primaryTerracotta,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'No se encontraron platillos',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: PlatilloListView._textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Agrega un platillo con el botón inferior o cambia los filtros de búsqueda.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: PlatilloListView._textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: _abrirDialogoCrear,
                                          icon: const Icon(Icons.add_rounded),
                                          label:
                                              const Text('Crear nuevo platillo'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                PlatilloListView._primary,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 80),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final platillo =
                                          platillosFiltrados[index];
                                      final nombreCat = nombresCategorias[
                                              platillo.categoriaId] ??
                                          'Sin categoría';

                                      return PlatilloCard(
                                        key: ValueKey(platillo.id),
                                        platillo: platillo,
                                        categoriaNombre: nombreCat,
                                        onToggleDisponibilidad: (nuevoEstado) =>
                                            _conmutarDisponibilidad(
                                                platillo, nuevoEstado),
                                        onEditar: () =>
                                            _abrirDialogoEditar(platillo),
                                        onEliminar: () =>
                                            _eliminarPlatillo(platillo),
                                      );
                                    },
                                    childCount: platillosFiltrados.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
