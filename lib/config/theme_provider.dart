import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🌙 بەڕێوەبردنی ڕەنگی ئەپ
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;
  static const String _key = 'theme_mode';

  // ═══════════════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════════════
  ThemeMode get themeMode => _themeMode;

  /// ✅ ئایا تاریکە؟ (لە ڕاستیدا بەکاردێت لە Drawer)
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// ✅ ئایا System ـە؟
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// ✅ ئایا ئامادەیە؟
  bool get isInitialized => _isInitialized;

  /// ✅ دۆخی تاریکی ڕاستەقینە (بەپێی Brightness ی ئێستا)
  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 Constructor
  // ═══════════════════════════════════════════════════════════
  ThemeProvider() {
    _loadFromPrefs();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 گۆڕینی ڕەنگ (بۆ Settings Screen)
  // ═══════════════════════════════════════════════════════════
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    await _saveToPrefs(mode.index);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 گۆڕینەوە (بۆ Drawer Toggle)
  // ✅ چاککراو — پشتگیری System
  // ═══════════════════════════════════════════════════════════
  Future<void> toggleTheme(bool isDark) async {
    // ✅ ئەگەر System بوو، بۆ Light یان Dark بگۆڕە
    // ✅ ئەگەر Light بوو، بۆ Dark بگۆڕە
    // ✅ ئەگەر Dark بوو، بۆ Light بگۆڕە
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 گۆڕینەوە بەپێی دۆخی ئێستا (بۆ Drawer بێ پارامەتەر)
  // ═══════════════════════════════════════════════════════════
  Future<void> toggleThemeFromCurrent(BuildContext context) async {
    final currentIsDark = isDark(context);
    await setThemeMode(currentIsDark ? ThemeMode.light : ThemeMode.dark);
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 خوێندنەوە لە Prefs
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_key) ?? 0;

      // ✅ پشکنینی index
      if (index >= 0 && index < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[index];
      } else {
        _themeMode = ThemeMode.light;
      }
    } catch (e) {
      debugPrint('⚠️ ThemeProvider load error: $e');
      _themeMode = ThemeMode.light;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 پاشەکەوتکردن لە Prefs
  // ═══════════════════════════════════════════════════════════
  Future<void> _saveToPrefs(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, index);
    } catch (e) {
      debugPrint('⚠️ ThemeProvider save error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 گەڕاندنەوە بۆ دۆخی سەرەتا
  // ═══════════════════════════════════════════════════════════
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('⚠️ ThemeProvider reset error: $e');
    }
    notifyListeners();
  }
}