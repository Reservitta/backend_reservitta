import 'package:flutter/material.dart';
import '../models/categoria_model.dart';
import '../models/experiencia_model.dart';
import '../models/ocasion_model.dart';
import '../models/platillo_model.dart';
import '../models/reservation_draft_model.dart';
import '../models/restaurant_model.dart';
import '../services/categoria_service.dart';
import '../services/ocasion_service.dart';
import '../services/platillo_service.dart';
import 'widgets/platillo_menu_card.dart';
import 'widgets/preorden_item_dialog.dart';

/// Pantalla de Personalización de Visita (HU16, HU15-RF02, HU16-RF02)
///
/// Permite al comensal personalizar su visita antes de confirmar la reserva:
/// 1. Preorden de platillos: reutiliza el mismo catálogo, modelos y servicios de HU06 (HU16-RF02).
/// 2. Registro de alergias alimentarias y notas para cocina.
/// 3. Selección de ocasión especial y sus amenidades/experiencias (HU18/HU33).
///
/// Al confirmar, utiliza el mismo endpoint unificado de creación de reservas (HU15-RF02).
/// El usuario puede volver atrás en cualquier momento para cambiar de opción sin confirmar.
class PersonalizeVisitView extends StatefulWidget {
  final RestaurantModel restaurant;
  final ReservationDraftModel draft;
  final CategoriaService? categoriaService;
  final PlatilloService? platilloService;
  final OcasionService? ocasionService;
  final Future<void> Function(ReservationDraftModel updatedDraft)? onConfirm;

  const PersonalizeVisitView({
    super.key,
    required this.restaurant,
    required this.draft,
    this.categoriaService,
    this.platilloService,
    this.ocasionService,
    this.onConfirm,
  });

  @override
  State<PersonalizeVisitView> createState() => _PersonalizeVisitViewState();
}

class _PersonalizeVisitViewState extends State<PersonalizeVisitView> with SingleTickerProviderStateMixin {
  late final CategoriaService _categoriaService;
  late final PlatilloService _platilloService;
  late final OcasionService _ocasionService;

  late TabController _tabController;

  // Estado local de personalización
  final List<Map<String, dynamic>> _preordenItems = [];
  final Set<String> _alergiasSeleccionadas = {};
  final TextEditingController _notasAlergiasCtrl = TextEditingController();
  OcasionModel? _ocasionSeleccionada;
  final List<ExperienciaModel> _experienciasSeleccionadas = [];

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
    _categoriaService = widget.categoriaService ?? CategoriaService();
    _platilloService = widget.platilloService ?? PlatilloService();
    _ocasionService = widget.ocasionService ?? OcasionService();
    _tabController = TabController(length: 3, vsync: this);

    // Cargar personalización preexistente del borrador si la hubiera
    _preordenItems.addAll(widget.draft.preordenItems);
    _alergiasSeleccionadas.addAll(widget.draft.alergias);
    _notasAlergiasCtrl.text = widget.draft.notasAlergias;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notasAlergiasCtrl.dispose();
    super.dispose();
  }

  // Cálculos de subtotal
  double get _subtotalPreorden {
    return _preordenItems.fold<double>(0.0, (acc, item) {
      final total = (item['total'] as num?)?.toDouble();
      if (total != null) return acc + total;
      final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;
      return acc + (precio * cantidad);
    });
  }

  double get _totalExperiencias {
    return _experienciasSeleccionadas.fold<double>(0.0, (acc, exp) {
      return acc + (exp.esGratis ? 0.0 : exp.precio);
    });
  }

  double get _totalPersonalizacion => _subtotalPreorden + _totalExperiencias;

  int _cantidadDePlatillo(String platilloId) {
    int total = 0;
    for (final it in _preordenItems) {
      if (it['platilloId'] == platilloId) {
        total += (it['cantidad'] as num?)?.toInt() ?? 1;
      }
    }
    return total;
  }

  Future<void> _abrirDialogoPlatillo(PlatilloModel p) async {
    final item = await PreordenItemDialog.show(context, platillo: p);
    if (item != null && mounted) {
      setState(() {
        _preordenItems.add(item);
      });
    }
  }

  void _decrementarPlatillo(String platilloId) {
    final idx = _preordenItems.lastIndexWhere((it) => it['platilloId'] == platilloId);
    if (idx != -1) {
      setState(() {
        final actual = _preordenItems[idx];
        final cant = (actual['cantidad'] as num?)?.toInt() ?? 1;
        if (cant > 1) {
          final precio = (actual['precio'] as num?)?.toDouble() ?? 0.0;
          _preordenItems[idx] = {
            ...actual,
            'cantidad': cant - 1,
            'total': precio * (cant - 1),
          };
        } else {
          _preordenItems.removeAt(idx);
        }
      });
    }
  }

  Future<void> _confirmarPersonalizacion() async {
    final updatedDraft = widget.draft.copyWith(
      preordenItems: _preordenItems,
      alergias: _alergiasSeleccionadas.toList(),
      notasAlergias: _notasAlergiasCtrl.text.trim(),
      ocasionEspecial: () => _ocasionSeleccionada != null
          ? {
              'ocasionId': _ocasionSeleccionada!.id,
              'nombre': _ocasionSeleccionada!.nombre,
              'icono': _ocasionSeleccionada!.icono,
            }
          : null,
      experiencias: _experienciasSeleccionadas
          .map((e) => {
                'experienciaId': e.id,
                'nombre': e.nombre,
                'precio': e.precio,
                'esGratis': e.esGratis,
              })
          .toList(),
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
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: const Text('Personalizar mi visita'),
        backgroundColor: _lightBg,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryTerracotta,
          indicatorColor: _primaryTerracotta,
          unselectedLabelColor: _textMuted,
          tabs: [
            Tab(
              icon: const Icon(Icons.restaurant_menu),
              text: 'Preorden (${_preordenItems.length})',
            ),
            Tab(
              icon: const Icon(Icons.health_and_safety_outlined),
              text: 'Alergias (${_alergiasSeleccionadas.length})',
            ),
            Tab(
              icon: const Icon(Icons.celebration_outlined),
              text: _ocasionSeleccionada != null ? 'Ocasión (1)' : 'Ocasión',
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
  }

  // ---------------------------------------------------------------------------
  // TAB 1: PREORDEN (HU16-RF02: Reutilización del catálogo y tarjeta de platillos)
  // ---------------------------------------------------------------------------
  Widget _buildPreordenTab() {
    return StreamBuilder<List<PlatilloModel>>(
      stream: _platilloService.getPlatillosActivosStream(widget.restaurant.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryTerracotta));
        }

        final platillos = snapshot.data ?? [];
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

        return ListView.builder(
          key: const ValueKey('lista_preorden_platillos'),
          padding: const EdgeInsets.all(16),
          itemCount: platillos.length,
          itemBuilder: (context, index) {
            final p = platillos[index];
            final cantidad = _cantidadDePlatillo(p.id);

            return PlatilloMenuCard(
              platillo: p,
              mode: PlatilloCardMode.preorden,
              cantidad: cantidad,
              onAgregar: () => _abrirDialogoPlatillo(p),
              onIncrementar: () => _abrirDialogoPlatillo(p),
              onDecrementar: () => _decrementarPlatillo(p.id),
              onTap: () => _abrirDialogoPlatillo(p),
            );
          },
        );
      },
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark),
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('input_notas_alergias'),
            controller: _notasAlergiasCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ej. Uno de los invitados es celíaco estricto; evitar contaminación cruzada con mariscos.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    return FutureBuilder<List<OcasionModel>>(
      future: _ocasionService.getOcasiones(widget.restaurant.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryTerracotta));
        }

        final ocasiones = snapshot.data ?? [];
        if (ocasiones.isEmpty) {
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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '¿Celebras algo especial?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elige una ocasión para incluir amenidades de cortesía o experiencias personalizadas.',
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
            const SizedBox(height: 16),

            ...ocasiones.map((ocasion) {
              final esSeleccionada = _ocasionSeleccionada?.id == ocasion.id;

              return Card(
                key: ValueKey('card_ocasion_opcion_${ocasion.id}'),
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: esSeleccionada ? _primaryTerracotta : _cardBorder,
                    width: esSeleccionada ? 2.0 : 1.0,
                  ),
                ),
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.celebration, color: _primaryTerracotta, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ocasion.nombre,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Switch(
                            key: ValueKey('switch_ocasion_${ocasion.id}'),
                            activeColor: _primaryTerracotta,
                            value: esSeleccionada,
                            onChanged: (val) {
                              setState(() {
                                if (val) {
                                  _ocasionSeleccionada = ocasion;
                                  _experienciasSeleccionadas.clear();
                                  // Preseleccionar experiencias gratuitas por cortesía
                                  for (final exp in ocasion.experiencias) {
                                    if (exp.esGratis) {
                                      _experienciasSeleccionadas.add(exp);
                                    }
                                  }
                                } else {
                                  _ocasionSeleccionada = null;
                                  _experienciasSeleccionadas.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (ocasion.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ocasion.descripcion,
                          style: const TextStyle(fontSize: 13, color: _textMuted),
                        ),
                      ],

                      // Lista de experiencias
                      if (esSeleccionada && ocasion.experiencias.isNotEmpty) ...[
                        const Divider(height: 20),
                        const Text(
                          'Experiencias disponibles para esta ocasión:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        ...ocasion.experiencias.map((exp) {
                          final expMarcada = _experienciasSeleccionadas.any((e) => e.id == exp.id);

                          return CheckboxListTile(
                            key: ValueKey('check_exp_${exp.id}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: _primaryTerracotta,
                            title: Text(exp.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: exp.descripcionCorta.isNotEmpty ? Text(exp.descripcionCorta) : null,
                            secondary: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: exp.esGratis ? Colors.green.shade100 : Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                exp.precioFormateado,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: exp.esGratis ? Colors.green.shade900 : Colors.brown.shade900,
                                ),
                              ),
                            ),
                            value: expMarcada,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _experienciasSeleccionadas.add(exp);
                                } else {
                                  _experienciasSeleccionadas.removeWhere((e) => e.id == exp.id);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA INFERIOR DE ACCIÓN (HU15-RF02)
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _cardBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, -2)),
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
                    const Text('Total de personalización:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      '\$${_totalPersonalizacion.toStringAsFixed(2)} MXN',
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : _confirmarPersonalizacion,
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Confirmar reserva con personalización',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

