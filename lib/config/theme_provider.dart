// lib/config/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🌙 بەڕێوەبردنی ڕەنگی ئەپ — Ultra Pro Max
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;
  static const String _key = 'theme_mode';

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  bool get isInitialized => _isInitialized;

  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Brightness effectiveBrightness(BuildContext context) =>
      isDark(context) ? Brightness.dark : Brightness.light;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _saveToPrefs(mode.index);
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> toggleThemeFromCurrent(BuildContext context) async {
    await setThemeMode(
      isDark(context) ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> cycleTheme(BuildContext context) async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_key);

      if (index != null && index >= 0 && index < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[index];
      } else {
        _themeMode = ThemeMode.system;
      }
    } catch (e) {
      debugPrint('⚠️ ThemeProvider load error: $e');
      _themeMode = ThemeMode.system;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, index);
    } catch (e) {
      debugPrint('⚠️ ThemeProvider save error: $e');
    }
  }

  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('⚠️ ThemeProvider reset error: $e');
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'theme_mode': _themeMode.name,
  };

  Future<void> applyJson(Map<String, dynamic> json) async {
    final name = json['theme_mode'];
    if (name is String) {
      final mode = ThemeMode.values.firstWhere(
            (m) => m.name == name,
        orElse: () => ThemeMode.system,
      );
      await setThemeMode(mode);
    }
  }
}