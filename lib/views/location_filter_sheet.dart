import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
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
  bool _isRequestingGps = false;
  String? _permissionErrorMessage;

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
    setState(() {
      _isRequestingGps = true;
      _permissionErrorMessage = null;
    });

    final result = await widget.viewModel.locationService.requestCurrentLocation();

    if (!mounted) return;

    setState(() {
      _isRequestingGps = false;
      if (result.isSuccess) {
        _temporaryLocation = result.location;
        _manualSearchResults.clear();
        _searchZoneController.clear();
        _permissionErrorMessage = null;
      } else {
        // HU02-RF01 Criterio 3: Si deniega o GPS apagado, ofrece elegir manualmente
        _permissionErrorMessage = result.message ?? 'No fue posible obtener tu ubicación GPS.';
      }
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
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Filtro de Ubicación',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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

              // 1. Botón: Usar mi ubicación actual (GPS) (HU02-RF01 Criterios 1 y 2)
              FilledButton.tonalIcon(
                key: const ValueKey('boton_usar_gps_ubicacion'),
                icon: _isRequestingGps
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _isRequestingGps
                      ? 'Detectando coordenadas...'
                      : 'Usar mi ubicación actual (GPS)',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _isRequestingGps ? null : _useCurrentLocation,
              ),

              // HU02-RF01 Criterio 3: Si deniega el permiso o el GPS está apagado, se ofrece elegir manualmente
              if (_permissionErrorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey('aviso_permiso_denegado_o_gps_apagado'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withAlpha(90),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.error.withAlpha(120),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _permissionErrorMessage!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No te preocupes: puedes elegir manualmente una ciudad o zona a continuación sin restricciones.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_temporaryLocation != null) ...[
                _buildMinimapPreview(theme),
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

              // Botón Aplicar Rediseñado (Premium)
              FilledButton(
                key: const ValueKey('boton_aplicar_filtro_ubicacion'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: _temporaryLocation != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: _temporaryLocation != null
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  elevation: _temporaryLocation != null ? 3 : 0,
                  shadowColor: theme.colorScheme.primary.withAlpha(120),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _temporaryLocation != null ? _applyFilter : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _temporaryLocation != null
                          ? Icons.travel_explore_rounded
                          : Icons.location_searching_rounded,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _temporaryLocation != null
                                ? 'Filtrar restaurantes en radio de ${_selectedRadius.toInt()} km'
                                : 'Selecciona una ubicación o usa tu GPS',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_temporaryLocation != null)
                            Text(
                              'Alrededor de ${_temporaryLocation!.label}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onPrimary.withAlpha(200),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
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

  /// Minimapa visual interactivo / radar de cobertura (HU02-RF01, HU02-RF02)
  Widget _buildMinimapPreview(ThemeData theme) {
    if (_temporaryLocation == null) return const SizedBox.shrink();

    final lat = _temporaryLocation!.latitude;
    final lon = _temporaryLocation!.longitude;
    final isGps = _temporaryLocation!.isGps;

    double zoom = 13.5;
    if (_selectedRadius >= 20) {
      zoom = 10.5;
    } else if (_selectedRadius >= 10) {
      zoom = 11.5;
    } else if (_selectedRadius >= 5) {
      zoom = 12.5;
    } else if (_selectedRadius <= 1) {
      zoom = 14.5;
    }

    final centerPoint = latlng.LatLng(lat, lon);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(120),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            key: ValueKey('mapa_real_${lat}_${lon}_$_selectedRadius'),
            options: MapOptions(
              initialCenter: centerPoint,
              initialZoom: zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.reservitta.reservitta',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: centerPoint,
                    radius: _selectedRadius * 1000,
                    useRadiusInMeter: true,
                    color: theme.colorScheme.primary.withAlpha(45),
                    borderColor: theme.colorScheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: centerPoint,
                    width: 38,
                    height: 38,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isGps ? Colors.green.shade600 : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(90),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isGps ? Icons.my_location : Icons.location_on,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Badge superior izquierdo (Tipo de señal)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGps ? Icons.sensors : Icons.pin_drop,
                    size: 13,
                    color: isGps ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isGps ? 'GPS Activo' : 'Zona Manual',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Badge superior derecho (Radio seleccionado)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(100),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                'Radio: ${_selectedRadius.toInt()} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Barra inferior con coordenadas y ubicación
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.black.withAlpha(190),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _temporaryLocation!.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
