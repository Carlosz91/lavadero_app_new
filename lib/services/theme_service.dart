import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Controlador de modo de tema (claro/oscuro) persistente.
class ThemeController {
  static const String _key = 'darkMode';

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<bool> isDark = ValueNotifier(false);

  /// Pulsa el brillo a la paleta de la app (debe correr antes del build).
  static void _applyPalette(ThemeMode themeMode) {
    final brightness = _resolveBrightness(themeMode);
    AppColors.apply(brightness);
  }

  static Brightness _resolveBrightness(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.system:
        final platformBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return platformBrightness;
    }
  }

  /// Carga la preferencia guardada antes del primer build.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_key) ?? false;
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    isDark.value = dark;
    _applyPalette(mode.value);
  }

  static Future<void> setDark(bool dark) async {
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    isDark.value = dark;
    _applyPalette(mode.value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, dark);
  }

  static void toggle() => setDark(!isDark.value);
}
