import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/branch_model.dart';
import '../models/service_catalog_model.dart';
import '../services/geocoding_service.dart';
import '../viewmodels/restaurant_profile_viewmodel.dart';

class RestaurantProfileView extends StatefulWidget {
  final String restaurantId;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

  const RestaurantProfileView({
    super.key,
    required this.restaurantId,
    this.onCompleted,
    this.onCancel,
  });

  @override
  State<RestaurantProfileView> createState() => _RestaurantProfileViewState();
}

class _RestaurantProfileViewState extends State<RestaurantProfileView> {
  late final RestaurantProfileViewModel _viewModel;

  // Paleta de colores cálidos y elegantes
  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _lightBg = Color(0xFFFBF8F4);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamAccent = Color(0xFFF3ECE1);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);

  // Nivel de zoom del mapa (5 – 18)
  int _mapZoom = 15;

  @override
  void initState() {
    super.initState();
    _viewModel = RestaurantProfileViewModel(restaurantId: widget.restaurantId);
    _viewModel.loadInitialData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            if (_viewModel.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: _primaryTerracotta),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado
                      _buildHeader(),
                      const SizedBox(height: 28),

                      // 1. Información del Restaurante
                      _buildSectionTitle('INFORMACIÓN DEL RESTAURANTE'),
                      const SizedBox(height: 12),
                      _buildRestaurantInfoCard(),
                      const SizedBox(height: 16),
                      _buildImagePickersRow(),
                      const SizedBox(height: 14),
                      _buildMapLocationSelector(),
                      const SizedBox(height: 14),
                      _buildPreviewButton(),
                      const SizedBox(height: 28),

                      // 2. Horarios
                      _buildSectionTitle('HORARIO'),
                      const SizedBox(height: 12),
                      _buildSchedulesCard(),
                      const SizedBox(height: 28),

                      // 3. Sucursal Principal y Adicionales
                      _buildSectionTitle('SUCURSAL PRINCIPAL'),
                      const SizedBox(height: 12),
                      _buildMainBranchCard(),
                      const SizedBox(height: 14),
                      _buildAdditionalBranchesSection(),
                      const SizedBox(height: 28),

                      // 4. Servicios Disponibles
                      _buildSectionTitle('SERVICIOS DISPONIBLES'),
                      const SizedBox(height: 12),
                      _buildServicesCard(),
                      const SizedBox(height: 32),

                      // Mensajes de error / éxito
                      if (_viewModel.errorMessage != null) ...[
                        _buildErrorBanner(_viewModel.errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      if (_viewModel.successMessage != null) ...[
                        _buildSuccessBanner(_viewModel.successMessage!),
                        const SizedBox(height: 16),
                      ],

                      // Botones de acción
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Encabezado con botón de volver y título
  Widget _buildHeader() {
    return Row(
      children: [
        if (widget.onCancel != null || Navigator.of(context).canPop())
          InkWell(
            onTap: () {
              if (widget.onCancel != null) {
                widget.onCancel!();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _creamAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: _textDark,
              ),
            ),
          ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registra tu restaurante',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Da de alta tu negocio y comienza a recibir reservas.',
                style: TextStyle(
                  fontSize: 13,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Título de sección en mayúsculas
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  /// Tarjeta de campos de información general
  Widget _buildRestaurantInfoCard() {
    final fe = _viewModel.fieldErrors;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          _buildFormField(
            label: 'Nombre del restaurante *',
            hint: 'Casa Sabores',
            controller: _viewModel.nombreController,
            errorText: fe['nombre'],
            showBottomBorder: true,
          ),
          _buildFormField(
            label: 'Teléfono (10 dígitos numéricos) *',
            hint: '5512345678',
            controller: _viewModel.telefonoController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            errorText: fe['telefono'],
            showBottomBorder: true,
          ),
          _buildFormField(
            label: 'Correo electrónico',
            hint: 'contacto@mirestaurante.com',
            controller: _viewModel.correoController,
            keyboardType: TextInputType.emailAddress,
            errorText: fe['correo'],
            showBottomBorder: true,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _cardBorder, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dirección *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        foregroundColor: _primaryTerracotta,
                      ),
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text(
                        'Buscar dirección',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _openAddressSearchModal(isMainRestaurant: true),
                    ),
                  ],
                ),
                TextField(
                  controller: _viewModel.direccionController,
                  style: const TextStyle(fontSize: 14, color: _textDark),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Av. Reforma 123, Centro',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (fe['direccion'] != null && fe['direccion']!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          fe['direccion']!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _buildFormField(
            label: 'Descripción',
            hint: 'Describe tu restaurante...',
            controller: _viewModel.descripcionController,
            maxLines: 3,
            showBottomBorder: false,
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? errorText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool showBottomBorder = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showBottomBorder
            ? const Border(bottom: BorderSide(color: _cardBorder, width: 1))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: _textDark),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (errorText != null && errorText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Selector de Logo y Foto Principal con bordes punteados
  Widget _buildImagePickersRow() {
    return Row(
      children: [
        // Logo Picker
        Expanded(
          child: _buildImageCard(
            title: '+ Logo',
            icon: Icons.storefront_outlined,
            hasImage: _viewModel.logoBytes != null || _viewModel.logoUrl.isNotEmpty,
            imageBytes: _viewModel.logoBytes,
            imageUrl: _viewModel.logoUrl,
            onTap: () => _showImageSourceDialog(isLogo: true),
          ),
        ),
        const SizedBox(width: 12),
        // Foto Principal Picker
        Expanded(
          child: _buildImageCard(
            title: '+ Foto principal',
            icon: Icons.photo_camera_outlined,
            hasImage:
                _viewModel.coverBytes != null || _viewModel.imagenPrincipalUrl.isNotEmpty,
            imageBytes: _viewModel.coverBytes,
            imageUrl: _viewModel.imagenPrincipalUrl,
            onTap: () => _showImageSourceDialog(isLogo: false),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCard({
    required String title,
    required IconData icon,
    required bool hasImage,
    Uint8List? imageBytes,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _cardBorder,
            width: 1.5,
          ),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageBytes != null)
                      Image.memory(imageBytes, fit: BoxFit.cover)
                    else if (imageUrl != null && imageUrl.isNotEmpty)
                      imageUrl.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(imageUrl.split(',').last),
                              fit: BoxFit.cover,
                            )
                          : Image.network(imageUrl, fit: BoxFit.cover),
                    Container(
                      color: Colors.black.withAlpha(50),
                      child: const Center(
                        child: Icon(Icons.edit, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28, color: _textDark),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showImageSourceDialog({required bool isLogo}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Seleccionar desde Galería'),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (isLogo) {
                      _viewModel.pickLogo(ImageSource.gallery);
                    } else {
                      _viewModel.pickCover(ImageSource.gallery);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Tomar Foto con la Cámara'),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (isLogo) {
                      _viewModel.pickLogo(ImageSource.camera);
                    } else {
                      _viewModel.pickCover(ImageSource.camera);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Tarjeta de Vista Previa de Mapa y Ubicación
  Widget _buildMapLocationSelector() {
    final lat = _viewModel.coordenadas.latitude;
    final lng = _viewModel.coordenadas.longitude;
    final latStr = lat.toStringAsFixed(4);
    final lngStr = lng.toStringAsFixed(4);
    // URL de tile estático con zoom variable
    final mapTileUrl =
        'https://static-maps.yandex.ru/1.x/?lang=es_ES&ll=$lng,$lat&z=$_mapZoom&l=map&pt=$lng,$lat,pm2rdm&size=450,180';

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen / Visualizador del mapa
          SizedBox(
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  mapTileUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: _creamAccent,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.map,
                              size: 40,
                              color: _primaryTerracotta,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Punto en Mapa: ($latStr, $lngStr)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Botones de zoom (+/-) en esquina superior derecha
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _buildZoomButton(
                        icon: Icons.add,
                        tooltip: 'Acercar',
                        onTap: () {
                          if (_mapZoom < 18) {
                            setState(() => _mapZoom++);
                          }
                        },
                        enabled: _mapZoom < 18,
                      ),
                      const SizedBox(height: 4),
                      _buildZoomButton(
                        icon: Icons.remove,
                        tooltip: 'Alejar',
                        onTap: () {
                          if (_mapZoom > 5) {
                            setState(() => _mapZoom--);
                          }
                        },
                        enabled: _mapZoom > 5,
                      ),
                    ],
                  ),
                ),
                // Botón cambiar ubicación en esquina inferior derecha
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(230),
                      foregroundColor: _textDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.edit_location_alt, size: 16, color: _primaryTerracotta),
                    label: const Text('Cambiar ubicación', style: TextStyle(fontSize: 12)),
                    onPressed: _showCoordinatesDialog,
                  ),
                ),
              ],
            ),
          ),
          // Barra inferior con coordenadas y dirección sincronizada
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFFD84A38),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ubicación GPS confirmada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Coordenadas: $latStr, $lngStr (Sincronizadas con tu dirección)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Botón circular de zoom sobre el mapa (+/-)
  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withAlpha(230)
                : Colors.white.withAlpha(120),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? _textDark : _textMuted,
          ),
        ),
      ),
    );
  }

  /// Abre el modal de búsqueda inteligente de dirección y coordenadas (OpenStreetMap)
  void _openAddressSearchModal({
    required bool isMainRestaurant,
    TextEditingController? targetAddressCtrl,
    Function(GeoPoint, String)? onSelected,
  }) {
    final queryCtrl = TextEditingController(
      text: isMainRestaurant
          ? _viewModel.direccionController.text
          : (targetAddressCtrl?.text ?? ''),
    );
    List<GeocodingResult> suggestions = [];
    bool isSearching = false;
    String? searchError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> runSearch() async {
              final q = queryCtrl.text.trim();
              if (q.length < 3) {
                setModalState(() {
                  searchError = 'Escribe al menos 3 caracteres para buscar.';
                });
                return;
              }
              setModalState(() {
                isSearching = true;
                searchError = null;
              });

              final results = await _viewModel.searchAddressSuggestions(q);
              setModalState(() {
                isSearching = false;
                suggestions = results;
                if (results.isEmpty) {
                  searchError =
                      'No se encontró la dirección. Intenta agregar calle, colonia o ciudad.';
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.location_searching, color: _primaryTerracotta),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMainRestaurant
                          ? 'Buscar Dirección del Restaurante'
                          : 'Buscar Dirección de Sucursal',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Busca la calle, colonia, número o ciudad. Se validará automáticamente con OpenStreetMap y obtendrá sus coordenadas.',
                      style: TextStyle(fontSize: 12, color: _textMuted),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: queryCtrl,
                            decoration: InputDecoration(
                              hintText: 'Ej. Av. Reforma 222, Juárez, CDMX',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onSubmitted: (_) => runSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryTerracotta,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onPressed: isSearching ? null : runSearch,
                          child: isSearching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Buscar'),
                        ),
                      ],
                    ),
                    if (searchError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        searchError!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (suggestions.isNotEmpty) ...[
                      const Text(
                        'Resultados encontrados (toca uno para seleccionar):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final item = suggestions[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: const Icon(
                                Icons.pin_drop,
                                color: _primaryTerracotta,
                              ),
                              title: Text(
                                item.displayName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lat: ${item.latitude.toStringAsFixed(5)}, Lng: ${item.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(fontSize: 11, color: _textMuted),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      'https://static-maps.yandex.ru/1.x/?lang=es_ES&ll=${item.longitude},${item.latitude}&z=14&l=map&pt=${item.longitude},${item.latitude},pm2rdm&size=360,90',
                                      height: 60,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (isMainRestaurant) {
                                  _viewModel.direccionController.text =
                                      item.displayName;
                                  _viewModel.setCoordinates(
                                    item.latitude,
                                    item.longitude,
                                  );
                                } else {
                                  if (targetAddressCtrl != null) {
                                    targetAddressCtrl.text = item.displayName;
                                  }
                                  if (onSelected != null) {
                                    onSelected(
                                      GeoPoint(item.latitude, item.longitude),
                                      item.displayName,
                                    );
                                  }
                                }
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCoordinatesDialog() {
    _openAddressSearchModal(isMainRestaurant: true);
  }

  /// Botón de Vista Previa de la Tarjeta del Restaurante (HU23-RF02)
  Widget _buildPreviewButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryTerracotta,
        side: const BorderSide(color: _primaryTerracotta),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: const Icon(Icons.preview_outlined, size: 18),
      label: const Text('Ver vista previa de la tarjeta en Reservitta'),
      onPressed: _showRestaurantCardPreview,
    );
  }

  void _showRestaurantCardPreview() {
    final nombre = _viewModel.nombreController.text.trim().isNotEmpty
        ? _viewModel.nombreController.text.trim()
        : 'Nombre del Restaurante';
    final direccion = _viewModel.direccionController.text.trim().isNotEmpty
        ? _viewModel.direccionController.text.trim()
        : 'Dirección del restaurante';
    final telefono = _viewModel.telefonoController.text.trim().isNotEmpty
        ? _viewModel.telefonoController.text.trim()
        : '+52 55 0000 0000';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Vista Previa en el Listado',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tarjeta simulada de Reservitta
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Foto de portada simulada
                        Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: _creamAccent,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: _viewModel.coverBytes != null
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: Image.memory(
                                    _viewModel.coverBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.restaurant_outlined,
                                    size: 48,
                                    color: _textMuted,
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      nombre,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _textDark,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    child: const Text(
                                      'Abierto',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 15,
                                    color: _textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      direccion,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 15,
                                    color: _textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    telefono,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Chips de servicios
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ..._viewModel.selectedServiceIds.take(3).map((sId) {
                                    final sName = _viewModel.catalogServices
                                        .firstWhere(
                                          (cat) => cat.id == sId,
                                          orElse: () =>
                                              ServiceCatalogModel(id: sId, nombre: sId),
                                        )
                                        .nombre;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _creamAccent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        sName,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _textDark,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryTerracotta,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar Vista Previa'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Tarjeta de Horarios con Días Toggleables y Selectores de Hora
  Widget _buildSchedulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Días de atención',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 10),
          // Chips de días
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _viewModel.weekDays.map((dayKey) {
                final isSelected = _viewModel.schedules[dayKey]?.abierto ?? false;
                final label = _viewModel.dayLabels[dayKey] ?? dayKey;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _viewModel.toggleDay(dayKey),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryTerracotta : _creamAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : _textDark,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          // Selectores de Hora de Apertura y Cierre
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hora de apertura',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTimePickerDropdown(
                      time: _viewModel.generalApertura,
                      onTimeSelected: (t) => _viewModel.setGeneralApertura(t),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hora de cierre',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTimePickerDropdown(
                      time: _viewModel.generalCierre,
                      onTimeSelected: (t) => _viewModel.setGeneralCierre(t),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerDropdown({
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onTimeSelected,
  }) {
    final formattedTime = _formatTime12h(time);

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onTimeSelected(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _creamAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: _textDark,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime12h(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Tarjeta de Sucursal Principal
  Widget _buildMainBranchCard() {
    final direccion = _viewModel.direccionController.text.trim();
    final telefono = _viewModel.telefonoController.text.trim();
    final lat = _viewModel.coordenadas.latitude.toStringAsFixed(4);
    final lng = _viewModel.coordenadas.longitude.toStringAsFixed(4);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera informativa de la sucursal matriz
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _creamAccent.withAlpha(120),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: _cardBorder, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront,
                  size: 20,
                  color: _primaryTerracotta,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sucursal Principal (Matriz)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync, size: 13, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Sincronizada',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Nombre de la sucursal sincronizado
 Container(
   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
   decoration: const BoxDecoration(
     border: Border(
       bottom: BorderSide(color: _cardBorder, width: 1),
     ),
   ),
   child: Row(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       const Icon(
         Icons.store_outlined,
         size: 18,
         color: _primaryTerracotta,
       ),
       const SizedBox(width: 10),
       Expanded(
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Text(
               'Nombre de la sucursal sincronizado',
               style: TextStyle(
                 fontSize: 11,
                 fontWeight: FontWeight.w600,
                 color: _textMuted,
               ),
             ),
             const SizedBox(height: 3),
             ValueListenableBuilder<TextEditingValue>(
               valueListenable:
                   _viewModel.sucursalPrincipalNombreController,
               builder: (context, value, child) {
                 final nombre = value.text.trim();

                 return Text(
                   nombre.isNotEmpty
                       ? nombre
                       : '(Ingresa el nombre de la sucursal)',
                   style: TextStyle(
                     fontSize: 13,
                     fontWeight: nombre.isNotEmpty
                         ? FontWeight.w600
                         : FontWeight.normal,
                     color: nombre.isNotEmpty
                         ? _textDark
                         : Colors.orange.shade800,
                     fontStyle: nombre.isNotEmpty
                         ? FontStyle.normal
                         : FontStyle.italic,
                   ),
                 );
               },
             ),
           ],
         ),
       ),
       Icon(
         Icons.sync,
         size: 16,
         color: Colors.green.shade700,
       ),
     ],
   ),
 ),
          // Dirección física sincronizada
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _cardBorder, width: 1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: _primaryTerracotta,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dirección física que se guardará',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        direccion.isNotEmpty
                            ? direccion
                            : '(Ingresa la dirección en Información General arriba)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: direccion.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          color: direccion.isNotEmpty ? _textDark : Colors.orange.shade800,
                          fontStyle: direccion.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Teléfono de contacto sincronizado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _cardBorder, width: 1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: _primaryTerracotta,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teléfono de contacto que se guardará',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        telefono.isNotEmpty
                            ? telefono
                            : '(Ingresa el teléfono en Información General arriba)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: telefono.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          color: telefono.isNotEmpty ? _textDark : Colors.orange.shade800,
                          fontStyle: telefono.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Coordenadas GPS sincronizadas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _cardBorder, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: _primaryTerracotta,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ubicación GPS: $lat, $lng',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Nota al pie informativa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _creamAccent.withAlpha(70),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 15,
                  color: _textMuted,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Esta sucursal se guardará automáticamente como tu matriz principal vinculada a estos datos.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de Sucursales Adicionales
  Widget _buildAdditionalBranchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_viewModel.additionalBranches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Sucursales Adicionales (${_viewModel.additionalBranches.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          ..._viewModel.additionalBranches.asMap().entries.map((entry) {
            final idx = entry.key;
            final branch = entry.value;
            final coordsText = branch.coordenadas != null
                ? 'Lat: ${branch.coordenadas!.latitude.toStringAsFixed(4)}, Lng: ${branch.coordenadas!.longitude.toStringAsFixed(4)}'
                : 'Sin coordenadas asignadas';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: _creamAccent,
                      child: branch.logoUrl.isNotEmpty
                          ? Image.network(
                              branch.logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.store,
                                color: _primaryTerracotta,
                              ),
                            )
                          : const Icon(Icons.store, color: _primaryTerracotta),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          branch.direccion,
                          style: const TextStyle(fontSize: 12, color: _textMuted),
                        ),
                        Text(
                          branch.telefono,
                          style: const TextStyle(fontSize: 12, color: _textMuted),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 13,
                              color: _primaryTerracotta,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                coordsText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _showBranchDialog(index: idx, branch: branch),
                    tooltip: 'Editar sucursal',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    onPressed: () => _viewModel.removeAdditionalBranch(idx),
                    tooltip: 'Eliminar sucursal',
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _textDark,
            side: const BorderSide(color: _cardBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar otra sucursal'),
          onPressed: () => _showBranchDialog(),
        ),
      ],
    );
  }

  void _showBranchDialog({int? index, BranchModel? branch}) {
    final nombreCtrl = TextEditingController(text: branch?.nombre ?? '');
    final dirCtrl = TextEditingController(text: branch?.direccion ?? '');
    final telCtrl = TextEditingController(text: branch?.telefono ?? '');
    GeoPoint? branchCoords = branch?.coordenadas;
    String branchLogo = branch?.logoUrl ?? '';
    String branchCover = branch?.imagenPrincipalUrl ?? '';
    // Variables de error inline para el diálogo
    String? nombreErr;
    String? dirErr;
    String? telErr;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final coordsLabel = branchCoords != null
                ? 'Coordenadas: ${branchCoords!.latitude.toStringAsFixed(4)}, ${branchCoords!.longitude.toStringAsFixed(4)}'
                : 'Ubicación sin marcar (toca para buscar)';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                index == null ? 'Nueva Sucursal' : 'Editar Sucursal',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nombreCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nombre de sucursal *',
                          hintText: 'Ej. Sucursal Norte',
                          border: const OutlineInputBorder(),
                          errorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          errorText: nombreErr,
                        ),
                        onChanged: (_) {
                          if (nombreErr != null) {
                            setDialogState(() => nombreErr = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dirCtrl,
                              decoration: InputDecoration(
                                labelText: 'Dirección *',
                                hintText: 'Calle, número, colonia',
                                border: const OutlineInputBorder(),
                                errorBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red),
                                ),
                                focusedErrorBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red, width: 2),
                                ),
                                errorText: dirErr,
                              ),
                              onChanged: (_) {
                                if (dirErr != null) {
                                  setDialogState(() => dirErr = null);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: _primaryTerracotta,
                              foregroundColor: Colors.white,
                            ),
                            tooltip: 'Buscar en mapa y obtener coordenadas',
                            icon: const Icon(Icons.search, size: 20),
                            onPressed: () {
                              _openAddressSearchModal(
                                isMainRestaurant: false,
                                targetAddressCtrl: dirCtrl,
                                onSelected: (coords, address) {
                                  setDialogState(() {
                                    branchCoords = coords;
                                    dirCtrl.text = address;
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Chip indicador de coordenadas
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: branchCoords != null
                              ? Colors.green.shade50
                              : _creamAccent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: branchCoords != null
                                ? Colors.green.shade300
                                : _cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.pin_drop,
                              size: 15,
                              color: branchCoords != null
                                  ? Colors.green.shade800
                                  : _textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                coordsLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: branchCoords != null
                                      ? Colors.green.shade800
                                      : _textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: telCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Teléfono (10 dígitos numéricos) *',
                          hintText: '5512345678',
                          border: const OutlineInputBorder(),
                          errorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          errorText: telErr,
                        ),
                        onChanged: (_) {
                          if (telErr != null) {
                            setDialogState(() => telErr = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Fotos de la sucursal (opcional):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Botón Logo Sucursal
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(
                                  color: branchLogo.isNotEmpty
                                      ? Colors.green
                                      : _cardBorder,
                                ),
                              ),
                              icon: Icon(
                                branchLogo.isNotEmpty
                                    ? Icons.check_circle
                                    : Icons.storefront_outlined,
                                size: 16,
                                color: branchLogo.isNotEmpty
                                    ? Colors.green
                                    : _textDark,
                              ),
                              label: Text(
                                branchLogo.isNotEmpty
                                    ? 'Logo listo'
                                    : '+ Logo',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final b64 = await _viewModel
                                    .pickBranchImage(ImageSource.gallery);
                                if (b64 != null) {
                                  setDialogState(() {
                                    branchLogo = b64;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón Foto Sucursal
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(
                                  color: branchCover.isNotEmpty
                                      ? Colors.green
                                      : _cardBorder,
                                ),
                              ),
                              icon: Icon(
                                branchCover.isNotEmpty
                                    ? Icons.check_circle
                                    : Icons.photo_camera_outlined,
                                size: 16,
                                color: branchCover.isNotEmpty
                                    ? Colors.green
                                    : _textDark,
                              ),
                              label: Text(
                                branchCover.isNotEmpty
                                    ? 'Foto lista'
                                    : '+ Foto',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final b64 = await _viewModel
                                    .pickBranchImage(ImageSource.gallery);
                                if (b64 != null) {
                                  setDialogState(() {
                                    branchCover = b64;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryTerracotta,
                  ),
                  onPressed: () {
                    // Validar campos obligatorios con mensajes inline
                    String? nErr;
                    String? dErr;
                    String? tErr;
                    if (nombreCtrl.text.trim().isEmpty) {
                      nErr = 'El nombre de la sucursal es obligatorio.';
                    }
                    if (dirCtrl.text.trim().isEmpty) {
                      dErr = 'La dirección es obligatoria.';
                    }
                    if (telCtrl.text.trim().isEmpty) {
                      tErr = 'El teléfono es obligatorio.';
                    } else if (telCtrl.text.trim().length != 10) {
                      tErr = 'El teléfono debe tener exactamente 10 dígitos.';
                    }
                    if (nErr != null || dErr != null || tErr != null) {
                      setDialogState(() {
                        nombreErr = nErr;
                        dirErr = dErr;
                        telErr = tErr;
                      });
                      return;
                    }
                    if (index == null) {
                      _viewModel.addAdditionalBranch(
                        nombre: nombreCtrl.text,
                        direccion: dirCtrl.text,
                        telefono: telCtrl.text,
                        coordenadas: branchCoords,
                        logoUrl: branchLogo,
                        imagenPrincipalUrl: branchCover,
                      );
                    } else {
                      _viewModel.editAdditionalBranch(
                        index,
                        BranchModel(
                          id: branch?.id ?? '',
                          nombre: nombreCtrl.text,
                          direccion: dirCtrl.text,
                          telefono: telCtrl.text,
                          esPrincipal: false,
                          coordenadas: branchCoords,
                          logoUrl: branchLogo,
                          imagenPrincipalUrl: branchCover,
                        ),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Guardar Sucursal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Tarjeta de Servicios Disponibles con Checkboxes y Botón de Agregar
  Widget _buildServicesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grid 2 columnas de servicios del catálogo
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _viewModel.catalogServices.map((service) {
              final isChecked =
                  _viewModel.selectedServiceIds.contains(service.id);

              return SizedBox(
                width: MediaQuery.of(context).size.width > 500
                    ? 250
                    : double.infinity,
                child: InkWell(
                  onTap: () => _viewModel.toggleService(service.id),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? const Color(0xFFFDF1EB)
                          : _creamAccent.withAlpha(120),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isChecked ? _primaryTerracotta : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isChecked ? _primaryTerracotta : Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isChecked
                                  ? _primaryTerracotta
                                  : Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: isChecked
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            service.nombre,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isChecked
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isChecked ? _primaryTerracotta : _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Servicios personalizados adicionales
          if (_viewModel.customServices.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Servicios Personalizados:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _viewModel.customServices.map((customName) {
                return Chip(
                  label: Text(customName),
                  backgroundColor: _creamAccent,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _viewModel.removeCustomService(customName),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: _cardBorder),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),
          // Botón para agregar servicio personalizado
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _primaryTerracotta,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar servicio personalizado'),
              onPressed: _showAddCustomServiceDialog,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomServiceDialog() {
    final serviceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Agregar Servicio Personalizado'),
          content: TextField(
            controller: serviceCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ej. Área para niños, Música en vivo...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primaryTerracotta),
              onPressed: () {
                if (serviceCtrl.text.trim().isNotEmpty) {
                  _viewModel.addCustomService(serviceCtrl.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.green, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Botones de Guardar registro y Cancelar
  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _primaryTerracotta,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _viewModel.isSaving
              ? null
              : () async {
                  final success = await _viewModel.saveRestaurantProfile();
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor completa todos los campos obligatorios marcados en rojo.',
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  } else if (success && mounted) {
                    if (widget.onCompleted != null) {
                      widget.onCompleted!();
                    } else if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  }
                },
          child: _viewModel.isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Guardar registro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: _textDark,
            backgroundColor: _creamAccent.withAlpha(100),
            side: const BorderSide(color: _cardBorder),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () {
            if (widget.onCancel != null) {
              widget.onCancel!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: const Text(
            'Cancelar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
        ),
      ],
    );
  }
}
