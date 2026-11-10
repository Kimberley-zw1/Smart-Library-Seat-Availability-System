import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's light/dark choice and remembers it between launches.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
  static const String _key = 'theme_mode';

  /// Call once in main(), before runApp.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_key);
      mode.value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.light,
      );
    } catch (_) {
      mode.value = ThemeMode.light;
    }
  }

  static Future<void> set(ThemeMode newMode) async {
    mode.value = newMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, newMode.name);
    } catch (_) {
      // Non-critical: the choice just won't be remembered next launch
    }
  }
}
