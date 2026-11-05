import 'package:flutter/material.dart';
import '../models/categoria_model.dart';
import '../services/categoria_service.dart';
import '../viewmodels/categoria_viewmodel.dart';
import 'widgets/categoria_card.dart';
import 'widgets/categoria_delete_dialog.dart';
import 'widgets/categoria_empty_state.dart';
import 'widgets/categoria_form_dialog.dart';

/// Pantalla principal para la Gestión de Categorías en backend_reservitta (HU24-RF02)
/// Criterios de aceptación:
/// 1. Lista las categorías existentes con opción de agregar, editar y reordenar (drag and drop o flechas).
/// 2. Confirmación antes de eliminar una categoría.
/// 3. Mensaje de estado vacío si aún no hay categorías creadas.
class CategoriaListView extends StatefulWidget {
  final String restaurantId;
  final CategoriaService? categoriaService;
  final CategoriaViewModel? viewModel;
  final bool showAppBar;

  const CategoriaListView({
    super.key,
    required this.restaurantId,
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
  static const Color _error = Color(0xFFD84A38);
  static const Color _success = Color(0xFF2E7D32);

  @override
  State<CategoriaListView> createState() => _CategoriaListViewState();
}

class _CategoriaListViewState extends State<CategoriaListView> {
  late final CategoriaViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ??
        CategoriaViewModel(
          restaurantId: widget.restaurantId,
          categoriaService: widget.categoriaService,
        );
    _viewModel.iniciarEscuchaEnTiempoReal();
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
        backgroundColor: esError
            ? CategoriaListView._error
            : CategoriaListView._success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _abrirDialogoAgregar() async {
    final resultado = await CategoriaFormDialog.show(
      context,
      onGuardar: (nombre, tipo) async {
        final ok = await _viewModel.crearCategoria(
          nombre: nombre,
          tipo: tipo,
        );
        return ok;
      },
    );

    if (resultado == true && mounted) {
      _mostrarSnackBar(mensaje: 'Categoría creada con éxito.');
    } else if (_viewModel.errorMessage != null && mounted) {
      _mostrarSnackBar(
        mensaje: _viewModel.errorMessage!,
        esError: true,
      );
    }
  }

  Future<void> _abrirDialogoEditar(CategoriaModel categoria) async {
    final resultado = await CategoriaFormDialog.show(
      context,
      categoria: categoria,
      onGuardar: (nombre, tipo) async {
        final ok = await _viewModel.actualizarCategoria(
          categoriaId: categoria.id,
          nuevoNombre: nombre,
          nuevoTipo: tipo,
        );
        return ok;
      },
    );

    if (resultado == true && mounted) {
      _mostrarSnackBar(mensaje: 'Categoría actualizada correctamente.');
    } else if (_viewModel.errorMessage != null && mounted) {
      _mostrarSnackBar(
        mensaje: _viewModel.errorMessage!,
        esError: true,
      );
    }
  }

  Future<void> _confirmarYEliminar(CategoriaModel categoria) async {
    // 1. Obtener la cantidad de platillos asociados para alertar adecuadamente
    final int platillosCount = await _viewModel.contarPlatillosAsociados(categoria.id);

    if (!mounted) return;

    // 2. Mostrar SIEMPRE el diálogo de confirmación antes de eliminar (HU24-RF02 Criterio 2)
    final confirmado = await CategoriaDeleteDialog.show(
      context,
      categoriaNombre: categoria.nombre,
      platillosAsociadosCount: platillosCount,
      onConfirmar: () async {
        return await _viewModel.eliminarCategoria(
          categoria.id,
          confirmadoExplicitamente: true,
        );
      },
    );

    if (confirmado == true && mounted) {
      _mostrarSnackBar(mensaje: 'Categoría eliminada con éxito.');
    } else {
      _viewModel.cancelarEliminacionPendiente();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final categorias = _viewModel.categoriasEnTiempoReal;
        final hayCategorias = categorias.isNotEmpty;

        return Scaffold(
          backgroundColor: CategoriaListView._lightBg,
          appBar: widget.showAppBar
              ? AppBar(
                  backgroundColor: Colors.white,
                  foregroundColor: CategoriaListView._textDark,
                  elevation: 0,
                  title: const Text(
                    'Gestión de Categorías',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: CategoriaListView._textDark,
                    ),
                  ),
                )
              : null,
          floatingActionButton: hayCategorias
              ? FloatingActionButton.extended(
                  onPressed: _viewModel.isLoading ? null : _abrirDialogoAgregar,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nueva Categoría'),
                  backgroundColor: CategoriaListView._primary,
                  foregroundColor: Colors.white,
                )
              : null,
          body: Column(
            children: [
              // Barra de progreso si está procesando
              if (_viewModel.isLoading)
                const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: CategoriaListView._creamLight,
                  color: CategoriaListView._primary,
                ),

              // Contenido principal
              Expanded(
                child: !hayCategorias
                    // Criterio 3: Mensaje de estado vacío
                    ? CategoriaEmptyState(
                        onCrearCategoria: _abrirDialogoAgregar,
                      )
                    // Criterio 1: Lista con agregar, editar y reordenar
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!widget.showAppBar) ...[
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Categorías',
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: CategoriaListView._textDark,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Organiza las secciones del menú, agrega, edita o reordena.',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: CategoriaListView._textMuted,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                              ],
                              // Encabezado descriptivo y contador
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${categorias.length} ${categorias.length == 1 ? 'categoría' : 'categorías'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: CategoriaListView._textMuted,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CategoriaListView._creamAccent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.sync_rounded,
                                            size: 13,
                                            color: CategoriaListView
                                                ._primaryTerracotta,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Sincronizado',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: CategoriaListView
                                                  ._primaryTerracotta,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Banner informativo para el usuario
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CategoriaListView._creamLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: CategoriaListView._cardBorder,
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: CategoriaListView._textMuted,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Arrastra las tarjetas o presiona las flechas para reordenar las categorías.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: CategoriaListView._textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Lista reordenable
                              Expanded(
                                child: ReorderableListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 4, 16, 80),
                                  buildDefaultDragHandles: false,
                                  itemCount: categorias.length,
                                  // ignore: deprecated_member_use
                                  onReorder: (oldIndex, newIndex) {
                                    _viewModel.reordenarCategorias(
                                      categorias,
                                      oldIndex,
                                      newIndex,
                                    );
                                  },
                                  itemBuilder: (context, index) {
                                    final cat = categorias[index];
                                    return CategoriaCard(
                                      key: ValueKey(cat.id),
                                      categoria: cat,
                                      index: index,
                                      isFirst: index == 0,
                                      isLast: index == categorias.length - 1,
                                      onEditar: () => _abrirDialogoEditar(cat),
                                      onEliminar: () =>
                                          _confirmarYEliminar(cat),
                                      onMoverArriba: () =>
                                          _viewModel.moverArriba(index),
                                      onMoverAbajo: () =>
                                          _viewModel.moverAbajo(index),
                                    );
                                  },
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
      },
    );
  }
}
