import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;

  ThemeService._internal();

  BrandPalette _palette = BrandPalette.morado;
  ThemeMode _themeMode = ThemeMode.system;

  BrandPalette get palette => _palette;
  ThemeMode get themeMode => _themeMode;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final paletteName = prefs.getString('brand_palette');
    if (paletteName != null) {
      _palette = BrandPalette.values.firstWhere(
        (e) => e.name == paletteName,
        orElse: () => BrandPalette.morado,
      );
    }

    final modeName = prefs.getString('theme_mode');
    if (modeName != null) {
      switch (modeName) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    }
    notifyListeners();
  }

  Future<void> setPalette(BrandPalette newPalette) async {
    _palette = newPalette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('brand_palette', newPalette.name);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode newMode) async {
    _themeMode = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', newMode.name);
    notifyListeners();
  }
}
