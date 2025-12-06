import 'package:flutter/material.dart';

enum BrandPalette {
  enterprise, // Azul oscuro, serio
  freshness,  // Verde, naturaleza
  tech,       // Negro/Gris, minimalista
  morado,     // Morado (original)
  rojo,       // Rojo (urgencia)
}

class AppTheme {
  // Colores base "Premium Fintech" (Slate/Blue/Gray)
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate800 = Color(0xFF1E293B);
  static const Color _slate50 = Color(0xFFF8FAFC);
  static const Color _blue600 = Color(0xFF2563EB);
  static const Color _emerald500 = Color(0xFF10B981);
  static const Color _rose500 = Color(0xFFF43F5E);

  static ThemeData lightThemeFor(BrandPalette palette) {
    final Color primary = _getPrimaryColor(palette);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: Colors.white,
        background: _slate50,
        primary: primary,
        secondary: _slate800,
        error: _rose500,
      ),
      scaffoldBackgroundColor: _slate50,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _slate900,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: _slate900),
      ),
      // cardTheme eliminado temporalmente por conflicto de tipos en esta versión de Flutter
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }

  static ThemeData darkThemeFor(BrandPalette palette) {
    final Color primary = _getPrimaryColor(palette);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        surface: _slate900,
        background: _slate900,
        primary: primary,
      ),
      scaffoldBackgroundColor: const Color(0xFF020617), // Almost black
      appBarTheme: const AppBarTheme(
        backgroundColor: _slate900,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // cardTheme eliminado temporalmente
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _slate900,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Helpers para compatibilidad
  static ThemeData get lightTheme => lightThemeFor(BrandPalette.morado);

  static ThemeData themeFor(BrandPalette palette, Brightness brightness) {
    return brightness == Brightness.light
        ? lightThemeFor(palette)
        : darkThemeFor(palette);
  }

  static Color _getPrimaryColor(BrandPalette palette) {
    switch (palette) {
      case BrandPalette.enterprise:
        return const Color(0xFF0F172A); // Slate 900
      case BrandPalette.freshness:
        return _emerald500;
      case BrandPalette.tech:
        return Colors.black;
      case BrandPalette.morado:
        return const Color(0xFF7C3AED); // Violet 600
      case BrandPalette.rojo:
        return _rose500;
    }
  }
}
