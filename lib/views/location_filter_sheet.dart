import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../viewmodels/public_catalog_viewmodel.dart';

/// Modal / BottomSheet para configurar el filtro de ubicación y radio (HU02-RF01, HU02-RF03)
class LocationFilterSheet extends StatefulWidget {
  final PublicCatalogViewModel viewModel;

  const LocationFilterSheet({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, PublicCatalogViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LocationFilterSheet(viewModel: viewModel),
    );
  }

  @override
  State<LocationFilterSheet> createState() => _LocationFilterSheetState();
}

class _LocationFilterSheetState extends State<LocationFilterSheet> {
  final TextEditingController _searchZoneController = TextEditingController();
  late double _selectedRadius;
  UserLocation? _temporaryLocation;
  List<UserLocation> _manualSearchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selectedRadius = widget.viewModel.selectedRadiusKm ?? 5.0;
    _temporaryLocation = widget.viewModel.selectedLocation;
  }

  @override
  void dispose() {
    _searchZoneController.dispose();
    super.dispose();
  }

  /// HU02-RF01 Criterios 1 y 2: El permiso y obtención de ubicación se solicita
  /// únicamente cuando el usuario activa el filtro.
  Future<void> _useCurrentLocation() async {
    final location = await widget.viewModel.locationService.getCurrentLocation();
    setState(() {
      _temporaryLocation = location;
      _manualSearchResults.clear();
      _searchZoneController.clear();
    });
  }

  /// HU02-RF01 Criterio 3: Búsqueda manual de dirección o zona
  Future<void> _onSearchManualZone(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _manualSearchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await widget.viewModel.locationService.searchManualLocations(query);
    if (mounted) {
      setState(() {
        _manualSearchResults = results;
        _isSearching = false;
      });
    }
  }

  void _applyFilter() {
    if (_temporaryLocation != null) {
      widget.viewModel.setLocationFilter(
        location: _temporaryLocation!,
        radiusKm: _selectedRadius,
      );
    }
    Navigator.pop(context);
  }

  void _clearFilter() {
    widget.viewModel.clearLocationFilter();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra indicadora de modal
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Título y botón cerrar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Filtro de Ubicación',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (widget.viewModel.isLocationFilterActive)
                    TextButton(
                      key: const ValueKey('boton_quitar_filtro_modal'),
                      onPressed: _clearFilter,
                      child: const Text('Quitar filtro'),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Botón: Usar mi ubicación actual (GPS)
              FilledButton.tonalIcon(
                key: const ValueKey('boton_usar_gps_ubicacion'),
                icon: const Icon(Icons.my_location),
                label: const Text('Usar mi ubicación actual (GPS)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _useCurrentLocation,
              ),

              if (_temporaryLocation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _temporaryLocation!.isGps ? Icons.gps_fixed : Icons.place,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _temporaryLocation!.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // 2. Selector de Radio en Kilómetros (HU02-RF02 Criterio 2)
              Text(
                'Radio de búsqueda máximo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: LocationService.availableRadiiKm.map((radius) {
                  final isSelected = _selectedRadius == radius;
                  final label = '${radius.toInt()} km';

                  return ChoiceChip(
                    key: ValueKey('chip_radio_$label'),
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedRadius = radius);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // 3. Selección manual de ciudad o zona (HU02-RF01 Criterio 3)
              Text(
                'O elige una ciudad o zona manualmente',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                key: const ValueKey('campo_buscar_zona_manual'),
                controller: _searchZoneController,
                decoration: InputDecoration(
                  hintText: 'Buscar colonia, calle o ciudad...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _onSearchManualZone,
              ),

              // Resultados de búsqueda manual
              if (_manualSearchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _manualSearchResults.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _manualSearchResults[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_city, size: 20),
                        title: Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          setState(() {
                            _temporaryLocation = item;
                            _manualSearchResults.clear();
                            _searchZoneController.text = item.label;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Zonas populares predefinidas
              const Text(
                'Zonas sugeridas:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LocationPresets.presetLocations.map((loc) {
                  final isSelected = _temporaryLocation?.label == loc.label;

                  return ActionChip(
                    key: ValueKey('preset_${loc.label}'),
                    avatar: Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: isSelected ? theme.colorScheme.onPrimary : null,
                    ),
                    backgroundColor: isSelected ? theme.colorScheme.primary : null,
                    label: Text(
                      loc.label,
                      style: TextStyle(
                        color: isSelected ? theme.colorScheme.onPrimary : null,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _temporaryLocation = loc;
                        _searchZoneController.clear();
                        _manualSearchResults.clear();
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Botón Aplicar
              FilledButton(
                key: const ValueKey('boton_aplicar_filtro_ubicacion'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _temporaryLocation != null ? _applyFilter : null,
                child: Text(
                  _temporaryLocation != null
                      ? 'Filtrar restaurantes en radio de ${_selectedRadius.toInt()} km'
                      : 'Selecciona una ubicación o usa tu GPS',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
