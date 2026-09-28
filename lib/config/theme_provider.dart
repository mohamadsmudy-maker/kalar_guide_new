import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🌙 بەڕێوەبردنی ڕەنگی ئەپ
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _key = 'theme_mode';

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadFromPrefs();
  }

  // ═══════════════════════════════════════════════════════
  // 🎨 گۆڕینی ڕەنگ (بۆ Settings Screen)
  // ═══════════════════════════════════════════════════════
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _saveToPrefs(mode.index);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  // 🔄 گۆڕینەوە (بۆ Drawer Toggle)
  // ═══════════════════════════════════════════════════════
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await _saveToPrefs(_themeMode.index);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  // 📖 خوێندنەوە لە Prefs
  // ═══════════════════════════════════════════════════════
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    _themeMode = ThemeMode.values[index];
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  // 💾 پاشەکەوتکردن لە Prefs
  // ═══════════════════════════════════════════════════════
  Future<void> _saveToPrefs(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, index);
  }
}