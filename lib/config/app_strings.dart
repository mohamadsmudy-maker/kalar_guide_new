import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

/// ⚙️ بەڕێوەبردنی ڕێکخستنەکانی ئەپ
class SettingsProvider extends ChangeNotifier {
  // ═══════════════════════════════════════════════════
  // 🔤 فۆنتەکان (زیاتر لە ١٣ فۆنت)
  // ═══════════════════════════════════════════════════
  static const List<Map<String, String>> availableFonts = [
    {'id': 'rabar', 'name': 'ڕەبەر (Rabar)', 'family': 'Rabar'},
    {'id': 'cairo', 'name': 'قاهیرە (Cairo)', 'family': 'Cairo'},
    {'id': 'noto_kufi', 'name': 'نۆتۆ کوفی (Noto Kufi)', 'family': 'NotoKufiArabic'},
    {'id': 'almarai', 'name': 'المرعی (Almarai)', 'family': 'Almarai'},
    {'id': 'tajawal', 'name': 'تجوال (Tajawal)', 'family': 'Tajawal'},
    {'id': 'amiri', 'name': 'أمیری (Amiri)', 'family': 'Amiri'},
    {'id': 'changa', 'name': 'تشانگا (Changa)', 'family': 'Changa'},
    {'id': 'elmesiri', 'name': 'المسیری (El Messiri)', 'family': 'ElMessiri'},
    {'id': 'harmattan', 'name': 'هرمتان (Harmattan)', 'family': 'Harmattan'},
    {'id': 'lateef', 'name': 'لەتیف (Lateef)', 'family': 'Lateef'},
    {'id': 'markazi', 'name': 'مرکزی (Markazi)', 'family': 'MarkaziText'},
    {'id': 'mada', 'name': 'مدا (Mada)', 'family': 'Mada'},
    {'id': 'scheherazade', 'name': 'شهرزاد (Scheherazade)', 'family': 'ScheherazadeNew'},
  ];

  // ═══════════════════════════════════════════════════
  // 📏 قەبارەکانی فۆنت
  // ═══════════════════════════════════════════════════
  static const List<Map<String, dynamic>> availableFontSizes = [
    {'id': 'small', 'name': 'بچووک', 'scale': 0.85},
    {'id': 'normal', 'name': 'ئاسایی', 'scale': 1.0},
    {'id': 'large', 'name': 'گەورە', 'scale': 1.15},
    {'id': 'xlarge', 'name': 'زۆر گەورە', 'scale': 1.3},
  ];

  // ═══════════════════════════════════════════════════
  // 🌍 زمانەکان
  // ═══════════════════════════════════════════════════
  static const List<Map<String, String>> availableLanguages = [
    {'id': 'ku', 'name': 'کوردی', 'native': 'کوردی', 'flag': '🇮🇶'},
    {'id': 'ar', 'name': 'عەرەبی', 'native': 'العربية', 'flag': '🇸🇦'},
    {'id': 'en', 'name': 'ئینگلیزی', 'native': 'English', 'flag': '🇬🇧'},
  ];

  // ═══════════════════════════════════════════════════
  // 📊 دۆخەکان
  // ═══════════════════════════════════════════════════
  String _fontFamily = 'Rabar';
  String _fontId = 'rabar';
  double _fontScale = 1.0;
  String _fontSizeId = 'normal';
  ThemeMode _themeMode = ThemeMode.light;
  String _languageId = 'ku';

  // 🔔 ئاگادارکردنەوە
  bool _notificationsEnabled = true;
  bool _newsNotifications = true;
  bool _complaintNotifications = true;
  bool _orderNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // ═══════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════
  String get fontFamily => _fontFamily;
  String get fontId => _fontId;
  double get fontScale => _fontScale;
  String get fontSizeId => _fontSizeId;
  ThemeMode get themeMode => _themeMode;
  String get languageId => _languageId;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get newsNotifications => _newsNotifications;
  bool get complaintNotifications => _complaintNotifications;
  bool get orderNotifications => _orderNotifications;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// 📝 وەرگرتنی TextTheme بەپێی فۆنتی هەڵبژێردراو
  TextTheme getTextTheme(BuildContext context) {
    final baseTheme = Theme.of(context).textTheme;

    // ✅ بەکارهێنانی فۆنتی هەڵبژێردراو
    TextTheme themedTextTheme;
    switch (_fontId) {
      case 'cairo':
        themedTextTheme = GoogleFonts.cairoTextTheme(baseTheme);
        break;
      case 'noto_kufi':
        themedTextTheme = GoogleFonts.notoKufiArabicTextTheme(baseTheme);
        break;
      case 'almarai':
        themedTextTheme = GoogleFonts.almaraiTextTheme(baseTheme);
        break;
      case 'tajawal':
        themedTextTheme = GoogleFonts.tajawalTextTheme(baseTheme);
        break;
      case 'amiri':
        themedTextTheme = GoogleFonts.amiriTextTheme(baseTheme);
        break;
      case 'changa':
        themedTextTheme = GoogleFonts.changaTextTheme(baseTheme);
        break;
      case 'elmesiri':
        themedTextTheme = GoogleFonts.elMessiriTextTheme(baseTheme);
        break;
      case 'harmattan':
        themedTextTheme = GoogleFonts.harmattanTextTheme(baseTheme);
        break;
      case 'lateef':
        themedTextTheme = GoogleFonts.lateefTextTheme(baseTheme);
        break;
      case 'markazi':
        themedTextTheme = GoogleFonts.markaziTextTextTheme(baseTheme);
        break;
      case 'mada':
        themedTextTheme = GoogleFonts.madaTextTheme(baseTheme);
        break;
      case 'scheherazade':
        themedTextTheme = GoogleFonts.scheherazadeNewTextTheme(baseTheme);
        break;
      case 'rabar':
      default:
        themedTextTheme = baseTheme.apply(fontFamily: 'Rabar');
        break;
    }

    // ✅ بەکارهێنانی قەبارەی فۆنت
    return themedTextTheme.apply(fontSizeFactor: _fontScale);
  }

  // ═══════════════════════════════════════════════════
  // 🚀 دەستپێکردن
  // ═══════════════════════════════════════════════════
  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔤 فۆنت
    _fontId = prefs.getString('font_id') ?? 'rabar';
    _fontSizeId = prefs.getString('font_size_id') ?? 'normal';
    _fontScale = prefs.getDouble('font_scale') ?? 1.0;

    final font = availableFonts.firstWhere(
          (f) => f['id'] == _fontId,
      orElse: () => availableFonts[0],
    );
    _fontFamily = font['family']!;

    // 🌙 Theme
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    // 🌍 زمان
    _languageId = prefs.getString('language_id') ?? 'ku';

    // 🔔 ئاگادارکردنەوە
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _newsNotifications = prefs.getBool('news_notifications') ?? true;
    _complaintNotifications = prefs.getBool('complaint_notifications') ?? true;
    _orderNotifications = prefs.getBool('order_notifications') ?? true;
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // 🔤 گۆڕینی فۆنت
  // ═══════════════════════════════════════════════════
  Future<void> setFont(String fontId) async {
    final font = availableFonts.firstWhere(
          (f) => f['id'] == fontId,
      orElse: () => availableFonts[0],
    );
    _fontId = fontId;
    _fontFamily = font['family']!;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_id', fontId);

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // 📏 گۆڕینی قەبارەی فۆنت
  // ═══════════════════════════════════════════════════
  Future<void> setFontSize(String sizeId) async {
    final size = availableFontSizes.firstWhere(
          (s) => s['id'] == sizeId,
      orElse: () => availableFontSizes[1],
    );
    _fontSizeId = sizeId;
    _fontScale = (size['scale'] as num).toDouble();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_size_id', sizeId);
    await prefs.setDouble('font_scale', _fontScale);

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // 🌙 گۆڕینی Theme
  // ═══════════════════════════════════════════════════
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // 🌍 گۆڕینی زمان
  // ═══════════════════════════════════════════════════
  Future<void> setLanguage(String languageId) async {
    _languageId = languageId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_id', languageId);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // 🔔 ئاگادارکردنەوە
  // ═══════════════════════════════════════════════════
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    notifyListeners();
  }

  Future<void> setNewsNotifications(bool value) async {
    _newsNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('news_notifications', value);
    notifyListeners();
  }

  Future<void> setComplaintNotifications(bool value) async {
    _complaintNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('complaint_notifications', value);
    notifyListeners();
  }

  Future<void> setOrderNotifications(bool value) async {
    _orderNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('order_notifications', value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', value);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // 🔄 گەڕاندنەوە بۆ دۆخی سەرەتا
  // ═══════════════════════════════════════════════════
  Future<void> resetToDefaults() async {
    _fontId = 'rabar';
    _fontFamily = 'Rabar';
    _fontSizeId = 'normal';
    _fontScale = 1.0;
    _themeMode = ThemeMode.light;
    _languageId = 'ku';
    _notificationsEnabled = true;
    _newsNotifications = true;
    _complaintNotifications = true;
    _orderNotifications = true;
    _soundEnabled = true;
    _vibrationEnabled = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }
}