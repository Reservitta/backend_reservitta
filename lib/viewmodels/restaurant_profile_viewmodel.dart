import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/branch_model.dart';
import '../models/restaurant_model.dart';
import '../models/service_catalog_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';
import '../services/restaurant_service.dart';
import '../services/storage_service.dart';
import '../utils/validators.dart';

class RestaurantProfileViewModel extends ChangeNotifier {
  final RestaurantService _restaurantService;
  final StorageService _storageService;
  final ImagePicker _imagePicker;
  final AuthService _authService;
  final GeocodingService _geocodingService;

  final String restaurantId;
  DocumentReference? adminIdReference;

  // Controladores de texto para información del restaurante
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController direccionController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();

  // Controlador para sucursal principal
  final TextEditingController sucursalPrincipalNombreController =
      TextEditingController(text: 'Sucursal Principal');

  // Coordenadas
  GeoPoint coordenadas = const GeoPoint(19.432608, -99.133209); // Default CDMX

  // Imágenes
  Uint8List? logoBytes;
  String? logoFileName;
  String logoUrl = '';

  Uint8List? coverBytes;
  String? coverFileName;
  String imagenPrincipalUrl = '';

  // Horarios
  final List<String> weekDays = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];

  final Map<String, String> dayLabels = {
    'lunes': 'Lun',
    'martes': 'Mar',
    'miercoles': 'Mié',
    'jueves': 'Jue',
    'viernes': 'Vie',
    'sabado': 'Sáb',
    'domingo': 'Dom',
  };

  final Map<String, String> dayFullNames = {
    'lunes': 'Lunes',
    'martes': 'Martes',
    'miercoles': 'Miércoles',
    'jueves': 'Jueves',
    'viernes': 'Viernes',
    'sabado': 'Sábado',
    'domingo': 'Domingo',
  };

  Map<String, DaySchedule> schedules = {};
  TimeOfDay generalApertura = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay generalCierre = const TimeOfDay(hour: 22, minute: 0);

  // Sucursales adicionales
  List<BranchModel> additionalBranches = [];

  // Servicios
  List<ServiceCatalogModel> catalogServices = [];
  Set<String> selectedServiceIds = {'reservaciones', 'preorden'};
  List<String> customServices = [];

  // Estados de carga y validación
  bool isLoading = true;
  bool isSaving = false;
  bool _formSubmitted = false;
  String? errorMessage;
  String? successMessage;
  Map<String, String?> fieldErrors = {};

  RestaurantProfileViewModel({
    required this.restaurantId,
    RestaurantService? restaurantService,
    StorageService? storageService,
    ImagePicker? imagePicker,
    AuthService? authService,
    GeocodingService? geocodingService,
  })  : _restaurantService = restaurantService ?? RestaurantService(),
        _storageService = storageService ?? StorageService(),
        _imagePicker = imagePicker ?? ImagePicker(),
        _authService = authService ?? AuthService(),
        _geocodingService = geocodingService ?? GeocodingService() {
    _initDefaultSchedules();
    _attachRealtimeValidationListeners();
  }

  void _initDefaultSchedules() {
    schedules = {
      for (final day in weekDays)
        day: DaySchedule(
          abierto: day != 'sabado' && day != 'domingo',
          apertura: _formatTimeOfDay(generalApertura),
          cierre: _formatTimeOfDay(generalCierre),
        ),
    };
  }

  void _attachRealtimeValidationListeners() {
    nombreController.addListener(() {
      if (_formSubmitted) {
        fieldErrors['nombre'] = AppValidators.validateRestaurantName(
          nombreController.text,
          isRequired: true,
        );
      }
      sucursalPrincipalNombreController.text = nombreController.text;
      notifyListeners();
    });
    telefonoController.addListener(() {
      if (_formSubmitted) {
        fieldErrors['telefono'] =
            AppValidators.validatePhone(telefonoController.text);
      }
      notifyListeners();
    });
    direccionController.addListener(() {
      if (_formSubmitted) {
        fieldErrors['direccion'] =
            AppValidators.validateAddress(direccionController.text);
      }
      notifyListeners();
    });
    correoController.addListener(() {
      if (_formSubmitted) {
        if (correoController.text.trim().isNotEmpty) {
          fieldErrors['correo'] =
              AppValidators.validateEmail(correoController.text);
        } else {
          fieldErrors['correo'] = null;
        }
      }
      notifyListeners();
    });
    sucursalPrincipalNombreController.addListener(() {
      notifyListeners();
    });
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 13;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }
    return const TimeOfDay(hour: 13, minute: 0);
  }

  /// Carga datos iniciales desde Firestore
  Future<void> loadInitialData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    // 1. Cargar catálogo de servicios (con fallback robusto)
    try {
      catalogServices = await _restaurantService.getServicesCatalog();
    } catch (_) {
      catalogServices = RestaurantService.defaultServicesList.map((item) {
        return ServiceCatalogModel(
          id: item['id']!,
          nombre: item['nombre']!,
          icono: item['icono']!,
          activo: true,
        );
      }).toList();
    }

    // Consultar información del usuario autenticado para sobrecargar datos
    UserModel? userProfile;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        userProfile = await _authService.getUserProfile(currentUser.uid);
      } catch (_) {}
    }

    // 2. Cargar datos actuales del restaurante
    try {
      final restaurant =
          await _restaurantService.getRestaurantById(restaurantId);

      if (restaurant != null) {
        adminIdReference = restaurant.adminId;

        // Nombre del restaurante
        if (restaurant.nombre.trim().isNotEmpty &&
            restaurant.nombre.trim() != 'Sin nombre') {
          nombreController.text = restaurant.nombre.trim();
        } else if (userProfile != null &&
            userProfile.nombre.trim().isNotEmpty) {
          nombreController.text = 'Restaurante de ${userProfile.nombre.trim()}';
        }

        // Teléfono: usar el guardado o sobrecargar con el del usuario registrado
        if (restaurant.telefono.trim().isNotEmpty) {
          telefonoController.text = restaurant.telefono.trim();
        } else if (userProfile != null &&
            userProfile.telefono.trim().isNotEmpty) {
          telefonoController.text = userProfile.telefono.trim();
        }

        // Correo: usar el guardado o sobrecargar con el del usuario registrado
        if (restaurant.correo.trim().isNotEmpty) {
          correoController.text = restaurant.correo.trim();
        } else if (userProfile != null &&
            userProfile.correo.trim().isNotEmpty) {
          correoController.text = userProfile.correo.trim();
        } else if (currentUser?.email != null &&
            currentUser!.email!.trim().isNotEmpty) {
          correoController.text = currentUser.email!.trim();
        }

        direccionController.text = restaurant.direccion;
        descripcionController.text = restaurant.descripcion;

        if (restaurant.coordenadas != null) {
          coordenadas = restaurant.coordenadas!;
        }

        logoUrl = restaurant.logoUrl;
        imagenPrincipalUrl = restaurant.imagenPrincipalUrl;

        if (restaurant.horarios.isNotEmpty) {
          schedules = Map.from(restaurant.horarios);
          final firstOpen = schedules.values.firstWhere(
            (s) => s.abierto,
            orElse: () => const DaySchedule(
              abierto: true,
              apertura: '13:00',
              cierre: '22:00',
            ),
          );
          generalApertura = _parseTimeOfDay(firstOpen.apertura);
          generalCierre = _parseTimeOfDay(firstOpen.cierre);
        }

        if (restaurant.serviciosIds.isNotEmpty) {
          selectedServiceIds = Set.from(restaurant.serviciosIds);
        }
        customServices = List.from(restaurant.serviciosPersonalizados);
      } else {
        // En caso de que no exista el documento aún, sobrecargar con datos del usuario
        if (userProfile != null && userProfile.nombre.trim().isNotEmpty) {
          nombreController.text = 'Restaurante de ${userProfile.nombre.trim()}';
        }
        if (userProfile != null && userProfile.telefono.trim().isNotEmpty) {
          telefonoController.text = userProfile.telefono.trim();
        }
        if (userProfile != null && userProfile.correo.trim().isNotEmpty) {
          correoController.text = userProfile.correo.trim();
        } else if (currentUser?.email != null &&
            currentUser!.email!.trim().isNotEmpty) {
          correoController.text = currentUser.email!.trim();
        }
      }
    } catch (e) {
      // Si es un borrador recién creado o permisos locales, sobrecargar con datos del usuario
      if (nombreController.text.trim().isEmpty &&
          userProfile != null &&
          userProfile.nombre.trim().isNotEmpty) {
        nombreController.text = 'Restaurante de ${userProfile.nombre.trim()}';
      }
      if (telefonoController.text.trim().isEmpty &&
          userProfile != null &&
          userProfile.telefono.trim().isNotEmpty) {
        telefonoController.text = userProfile.telefono.trim();
      }
      if (correoController.text.trim().isEmpty) {
        if (userProfile != null && userProfile.correo.trim().isNotEmpty) {
          correoController.text = userProfile.correo.trim();
        } else if (currentUser?.email != null &&
            currentUser!.email!.trim().isNotEmpty) {
          correoController.text = currentUser.email!.trim();
        }
      }
    }

    // 3. Cargar sucursales existentes
    try {
      final branches = await _restaurantService.getBranches(restaurantId);
      final mainBranches = branches.where((b) => b.esPrincipal).toList();
      if (mainBranches.isNotEmpty &&
          mainBranches.first.nombre.trim().isNotEmpty) {
        sucursalPrincipalNombreController.text = mainBranches.first.nombre;
      } else {
        sucursalPrincipalNombreController.text =
            nombreController.text.trim().isNotEmpty
                ? nombreController.text.trim()
                : 'Sucursal Principal';
      }
      additionalBranches = branches.where((b) => !b.esPrincipal).toList();
    } catch (_) {
      sucursalPrincipalNombreController.text =
          nombreController.text.trim().isNotEmpty
              ? nombreController.text.trim()
              : 'Sucursal Principal';
    }

    isLoading = false;
    notifyListeners();
  }

  // Selección de Logo
  Future<void> pickLogo(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        logoBytes = await picked.readAsBytes();
        logoFileName = picked.name;
        errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      errorMessage = 'No se pudo seleccionar el logo: $e';
      notifyListeners();
    }
  }

  // Selección de Foto Principal / Portada
  Future<void> pickCover(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        coverBytes = await picked.readAsBytes();
        coverFileName = picked.name;
        errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      errorMessage = 'No se pudo seleccionar la foto principal: $e';
      notifyListeners();
    }
  }

  // Ubicación en Mapa
  String? setCoordinates(double lat, double lng) {
    final validationError = AppValidators.validateCoordinates(
      latitude: lat,
      longitude: lng,
    );
    if (validationError != null) {
      return validationError;
    }
    coordenadas = GeoPoint(lat, lng);
    notifyListeners();
    return null;
  }

  // Geocodificación: buscar sugerencias para cualquier dirección
  Future<List<GeocodingResult>> searchAddressSuggestions(String query) async {
    return await _geocodingService.searchAddress(query);
  }

  // Geocodificación directa para el restaurante principal
  Future<GeocodingResult?> geocodeMainRestaurantAddress() async {
    final query = direccionController.text.trim();
    if (query.isEmpty) return null;
    final results = await _geocodingService.searchAddress(query);
    if (results.isNotEmpty) {
      final best = results.first;
      coordenadas = GeoPoint(best.latitude, best.longitude);
      notifyListeners();
      return best;
    }
    return null;
  }

  // Selección de Logo o Imagen de Sucursal
  Future<String?> pickBranchImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last;
        final b64 = base64Encode(bytes);
        return 'data:image/$ext;base64,$b64';
      }
    } catch (_) {}
    return null;
  }

  // Toggle de día de atención
  void toggleDay(String dayKey) {
    final current = schedules[dayKey] ??
        DaySchedule(
          abierto: false,
          apertura: _formatTimeOfDay(generalApertura),
          cierre: _formatTimeOfDay(generalCierre),
        );

    schedules[dayKey] = DaySchedule(
      abierto: !current.abierto,
      apertura: current.apertura,
      cierre: current.cierre,
    );
    notifyListeners();
  }

  // Actualizar horario de apertura para todos los días abiertos
  void setGeneralApertura(TimeOfDay tod) {
    generalApertura = tod;
    final formatted = _formatTimeOfDay(tod);
    schedules.updateAll((key, val) => DaySchedule(
          abierto: val.abierto,
          apertura: formatted,
          cierre: val.cierre,
        ));
    notifyListeners();
  }

  // Actualizar horario de cierre para todos los días abiertos
  void setGeneralCierre(TimeOfDay tod) {
    generalCierre = tod;
    final formatted = _formatTimeOfDay(tod);
    schedules.updateAll((key, val) => DaySchedule(
          abierto: val.abierto,
          apertura: val.apertura,
          cierre: formatted,
        ));
    notifyListeners();
  }

  // Gestión de sucursales adicionales
  void addAdditionalBranch({
    required String nombre,
    required String direccion,
    required String telefono,
    GeoPoint? coordenadas,
    String logoUrl = '',
    String imagenPrincipalUrl = '',
  }) {
    final newBranch = BranchModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: nombre.trim(),
      direccion: direccion.trim(),
      telefono: telefono.trim(),
      esPrincipal: false,
      coordenadas: coordenadas,
      logoUrl: logoUrl,
      imagenPrincipalUrl: imagenPrincipalUrl,
    );
    additionalBranches.add(newBranch);
    notifyListeners();
  }

  void editAdditionalBranch(int index, BranchModel updated) {
    if (index >= 0 && index < additionalBranches.length) {
      additionalBranches[index] = updated;
      notifyListeners();
    }
  }

  void removeAdditionalBranch(int index) {
    if (index >= 0 && index < additionalBranches.length) {
      additionalBranches.removeAt(index);
      notifyListeners();
    }
  }

  // Gestión de servicios
  void toggleService(String serviceId) {
    if (selectedServiceIds.contains(serviceId)) {
      selectedServiceIds.remove(serviceId);
    } else {
      selectedServiceIds.add(serviceId);
    }
    notifyListeners();
  }

  void addCustomService(String serviceName) {
    final trimmed = serviceName.trim();
    if (trimmed.isNotEmpty && !customServices.contains(trimmed)) {
      customServices.add(trimmed);
      notifyListeners();
    }
  }

  void removeCustomService(String serviceName) {
    customServices.remove(serviceName);
    notifyListeners();
  }

  // Validaciones del formulario
  bool validateForm() {
    _formSubmitted = true;
    fieldErrors = AppValidators.validateRestaurantProfile(
      nombre: nombreController.text,
      telefono: telefonoController.text,
      direccion: direccionController.text,
      correo: correoController.text,
    );

    // Validar que al menos un día esté abierto
    final openDays = schedules.entries.where((e) => e.value.abierto).toList();
    if (openDays.isEmpty) {
      errorMessage = 'Debes seleccionar al menos un día de atención.';
      notifyListeners();
      return false;
    }

    // Validar horarios: cierre > apertura
    for (final entry in openDays) {
      final ap = _parseTimeOfDay(entry.value.apertura);
      final ci = _parseTimeOfDay(entry.value.cierre);
      final err = AppValidators.validateScheduleHours(
        apertura: ap,
        cierre: ci,
      );
      if (err != null) {
        errorMessage = 'En ${dayFullNames[entry.key]}: $err';
        notifyListeners();
        return false;
      }
    }

    final hasErrors = fieldErrors.values.any((e) => e != null);
    if (hasErrors) {
      errorMessage = 'Por favor corrige los campos marcados.';
      notifyListeners();
      return false;
    }

    errorMessage = null;
    return true;
  }

  // Guardar perfil completo de restaurante
  Future<bool> saveRestaurantProfile() async {
    if (!validateForm()) return false;

    isSaving = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      String finalLogoUrl = logoUrl;
      String finalCoverUrl = imagenPrincipalUrl;

      // 1. Subir logo si fue modificado (en Web usa Data URI para evitar bloqueo CORS en localhost)
      if (logoBytes != null) {
        final ext = logoFileName?.split('.').last ?? 'jpg';
        if (kIsWeb) {
          final b64 = base64Encode(logoBytes!);
          finalLogoUrl = 'data:image/$ext;base64,$b64';
        } else {
          try {
            finalLogoUrl = await _storageService.uploadRestaurantImage(
              restaurantId: restaurantId,
              folder: 'logos',
              imageBytes: logoBytes!,
              fileExtension: ext,
            );
          } catch (_) {
            final b64 = base64Encode(logoBytes!);
            finalLogoUrl = 'data:image/$ext;base64,$b64';
          }
        }
      }

      // 2. Subir imagen principal si fue modificada
      if (coverBytes != null) {
        final ext = coverFileName?.split('.').last ?? 'jpg';
        if (kIsWeb) {
          final b64 = base64Encode(coverBytes!);
          finalCoverUrl = 'data:image/$ext;base64,$b64';
        } else {
          try {
            finalCoverUrl = await _storageService.uploadRestaurantImage(
              restaurantId: restaurantId,
              folder: 'covers',
              imageBytes: coverBytes!,
              fileExtension: ext,
            );
          } catch (_) {
            final b64 = base64Encode(coverBytes!);
            finalCoverUrl = 'data:image/$ext;base64,$b64';
          }
        }
      }

      // 3. Construir lista de días abiertos
      final openDaysList = schedules.entries
          .where((e) => e.value.abierto)
          .map((e) => e.key)
          .toList();

      // Asegurar referencia del admin
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final effectiveAdminRef = adminIdReference ??
          (currentUid != null
              ? FirebaseFirestore.instance.collection('users').doc(currentUid)
              : null);

      final updatedRestaurant = RestaurantModel(
        id: restaurantId,
        adminId: effectiveAdminRef,
        nombre: nombreController.text.trim(),
        telefono: telefonoController.text.trim(),
        correo: correoController.text.trim(),
        direccion: direccionController.text.trim(),
        descripcion: descripcionController.text.trim(),
        coordenadas: coordenadas,
        logoUrl: finalLogoUrl,
        imagenPrincipalUrl: finalCoverUrl,
        estado: 'activo',
        perfilCompleto: true,
        diasAbiertos: openDaysList,
        horarios: schedules,
        cierresEspeciales: const [],
        serviciosIds: selectedServiceIds.toList(),
        serviciosPersonalizados: customServices,
      );

      final mainBranch = BranchModel(
        id: 'principal',
        nombre: sucursalPrincipalNombreController.text.trim().isNotEmpty
            ? sucursalPrincipalNombreController.text.trim()
            : 'Sucursal Principal',
        direccion: direccionController.text.trim(),
        telefono: telefonoController.text.trim(),
        esPrincipal: true,
        coordenadas: coordenadas,
        logoUrl: finalLogoUrl,
        imagenPrincipalUrl: finalCoverUrl,
      );

      await _restaurantService.saveFullRestaurantProfile(
        restaurantId: restaurantId,
        restaurant: updatedRestaurant,
        mainBranch: mainBranch,
        additionalBranches: additionalBranches,
      );

      successMessage = '¡Perfil de restaurante registrado exitosamente!';
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'No se pudo guardar el perfil: $e';
      notifyListeners();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    telefonoController.dispose();
    correoController.dispose();
    direccionController.dispose();
    descripcionController.dispose();
    sucursalPrincipalNombreController.dispose();
    super.dispose();
  }
}
