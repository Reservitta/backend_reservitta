import 'package:flutter/material.dart';

/// Colores y medidas de Reservitta en un solo lugar, para que toda la app se vea igual.
///
/// Los colores salen de los que ya usaban las pantallas. Cada par texto/fondo
/// cumple contraste WCAG AA (4.5:1 para texto, 3:1 para bordes y controles).
class AppColors {
  AppColors._();

  /// Café: color principal de la marca.
  static const marca = Color(0xFF6F4528);

  /// Caramelo oscuro: acentos y detalles (también cumple contraste para texto).
  static const acento = Color(0xFF9A5B13);

  /// Café muy claro para fondos tonales (botones suaves, portadas sin foto).
  static const marcaSuave = Color(0xFFF1E6DA);
  static const marcaMedia = Color(0xFFE3CDB5);
  static const sobreMarca = Color(0xFFFFFFFF);
  /// Blanco perla.
  static const fondo = Color(0xFFFAF7F2);
  static const superficie = Color(0xFFFFFFFF);
  static const texto = Color(0xFF2B1D14);
  static const textoSuave = Color(0xFF6A5B50);
  static const divisor = Color(0xFFE9E1D6);

  /// Borde de campos y controles: contraste mínimo de 3:1 contra el fondo.
  static const borde = Color(0xFF8C7B6E);
  static const error = Color(0xFFB3261E);
  static const exito = Color(0xFF2E7D32);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Tamaño mínimo recomendado para cualquier zona que se toca (Material y WCAG 2.5.8).
  static const double zonaTactil = 48;
}

class AppTheme {
  AppTheme._();

  /// Letra de los títulos: Fraunces, serif suave y con carácter gastronómico.
  /// El texto corrido usa la letra básica del sistema para que se lea fácil.
  static const familiaTitulos = 'Fraunces';

  static TextTheme _textos(TextTheme base) {
    TextStyle? titulo(TextStyle? e, FontWeight peso) => e?.copyWith(
          fontFamily: familiaTitulos,
          fontWeight: peso,
          fontVariations: [FontVariation('wght', peso.value.toDouble())],
          color: AppColors.texto,
        );
    return base
        .copyWith(
          displayLarge: titulo(base.displayLarge, FontWeight.w700),
          displayMedium: titulo(base.displayMedium, FontWeight.w700),
          displaySmall: titulo(base.displaySmall, FontWeight.w700),
          headlineLarge: titulo(base.headlineLarge, FontWeight.w700),
          headlineMedium: titulo(base.headlineMedium, FontWeight.w700),
          headlineSmall: titulo(base.headlineSmall, FontWeight.w600),
          titleLarge: titulo(base.titleLarge, FontWeight.w600),
        )
        .apply(bodyColor: AppColors.texto, displayColor: AppColors.texto);
  }

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(seedColor: AppColors.marca).copyWith(
      primary: AppColors.marca,
      onPrimary: AppColors.sobreMarca,
      surface: AppColors.superficie,
      onSurface: AppColors.texto,
      onSurfaceVariant: AppColors.textoSuave,
      outline: AppColors.borde,
      outlineVariant: AppColors.divisor,
      error: AppColors.error,
    );

    final bordeCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borde),
    );

    const formaBoton = StadiumBorder();
    const tamanoMinimo = Size(AppSpacing.zonaTactil, AppSpacing.zonaTactil);

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fondo,
      textTheme: _textos(ThemeData(brightness: Brightness.light).textTheme),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.fondo,
        foregroundColor: AppColors.texto,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: tamanoMinimo,
          shape: formaBoton,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: tamanoMinimo,
          shape: formaBoton,
          backgroundColor: AppColors.marca,
          foregroundColor: AppColors.sobreMarca,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: tamanoMinimo,
          shape: formaBoton,
          foregroundColor: AppColors.marca,
          side: const BorderSide(color: AppColors.marca),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: tamanoMinimo,
          foregroundColor: AppColors.marca,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: tamanoMinimo),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.superficie,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: bordeCampo,
        enabledBorder: bordeCampo,
        focusedBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.marca, width: 2),
        ),
        errorBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textoSuave),
        hintStyle: const TextStyle(color: AppColors.textoSuave),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12.5),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: AppColors.borde),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(color: AppColors.texto),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.superficie,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.texto,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divisor, space: 1),
      focusColor: AppColors.marca.withValues(alpha: 0.16),
    );
  }
}
