import 'package:flutter/material.dart';

/// Variantes de paleta de marca soportadas.
enum BrandPalette {
  enterprise,   // Azul sobrio
  freshness,    // Verde frescura
  tech,         // Cyan/teal tecnológico
  morado,       // Violeta actual
  rojo,         // Rojo suave
}

class AppTheme {
  AppTheme._();

  /// Mapa de colores seed por variante.
  static const Map<BrandPalette, Color> _seedColors = {
    BrandPalette.enterprise: Color(0xFF1E3A8A),
    BrandPalette.freshness: Color(0xFF059669),
    BrandPalette.tech: Color(0xFF0891B2),
    BrandPalette.morado: Color(0xFF4F46E5),
    BrandPalette.rojo: Color(0xFFFA8484), 
  };

  /// Tema por defecto (puedes cambiar la variante aquí si quieres un fallback global).
  static final ThemeData lightTheme = lightThemeFor(BrandPalette.morado);

  /// Builder unificado que aplica seed y brillo (claro/oscuro).
  static ThemeData themeFor(BrandPalette palette, Brightness brightness) {
    final seed = _seedColors[palette]!;
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    // Fill y fondos adaptados a cada modo
    final Color inputFill = isDark
        ? scheme.surfaceVariant.withAlpha((255 * 0.20).round())
        : const Color(0xFFF9FAFB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? scheme.surface : const Color(0xFFF3F4F6),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? null : Colors.white, // en oscuro, usa surface por defecto
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? scheme.outlineVariant : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? scheme.outlineVariant : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed, width: 1.5),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }

  /// Compat: temas específicos por modo
  static ThemeData lightThemeFor(BrandPalette palette) => themeFor(palette, Brightness.light);
  static ThemeData darkThemeFor(BrandPalette palette) => themeFor(palette, Brightness.dark);
}
