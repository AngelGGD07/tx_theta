import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Única fuente de verdad para el modo de tema.
final ValueNotifier<ThemeMode> themeModeNotifier =
ValueNotifier<ThemeMode>(ThemeMode.system);

class ThemeModeController {
  static const String _key = 'theme_mode';

  /// Carga la preferencia guardada con un tiempo máximo de espera.
  /// Si falla o expira, se mantiene `ThemeMode.system`.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final stored = prefs.getString(_key);
      if (stored != null) {
        themeModeNotifier.value = _parseThemeMode(stored);
      }
    } catch (_) {
      // Fallback silencioso a ThemeMode.system
    }
  }

  /// Guarda el modo actual en shared_preferences.
  static Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // No interrumpir la app
    }
  }

  static ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Actualiza el notifier y guarda la preferencia.
  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await save(mode);
  }
}