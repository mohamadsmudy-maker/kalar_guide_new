import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ⚙️ بەڕێوەبردنی ڕێکخستنەکانی ئەپ — PRO EDITION
class SettingsProvider extends ChangeNotifier {
  // ═══════════════════════════════════════════════════
  // 🔤 فۆنتەکان
  // ═══════════════════════════════════════════════════
  static const List<Map<String, String>> availableFonts = [
    {'id': 'rabar', 'name': 'ڕەبەر (Rabar)', 'family': 'Rabar'},
    {'id': 'cairo', 'name': 'قاهیرە (Cairo)', 'family': 'Cairo'},
    {'id': 'noto_kufi', 'name': 'نۆتۆ کوفی', 'family': 'NotoKufiArabic'},
    {'id': 'almarai', 'name': 'المرعی (Almarai)', 'family': 'Almarai'},
    {'id': 'tajawal', 'name': 'تجوال (Tajawal)', 'family': 'Tajawal'},
    {'id': 'amiri', 'name': 'أمیری (Amiri)', 'family': 'Amiri'},
    {'id': 'changa', 'name': 'تشانگا (Changa)', 'family': 'Changa'},
    {'id': 'elmesiri', 'name': 'المسیری (ElMessiri)', 'family': 'ElMessiri'},
    {'id': 'harmattan', 'name': 'هرمتان (Harmattan)', 'family': 'Harmattan'},
    {'id': 'lateef', 'name': 'لەتیف (Lateef)', 'family': 'Lateef'},
    {'id': 'markazi', 'name': 'مرکزی', 'family': 'MarkaziText'},
    {'id': 'mada', 'name': 'مدا (Mada)', 'family': 'Mada'},
    {'id': 'scheherazade', 'name': 'شهرزاد', 'family': 'ScheherazadeNew'},
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
  String _languageId = 'ku';

  bool _notificationsEnabled = true;
  bool _newsNotifications = true;
  bool _complaintNotifications = true;
  bool _orderNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // ═══════════════════════════════════════════════════
  // 🎨 TextTheme Cache
  // ═══════════════════════════════════════════════════
  TextTheme? _cachedLightTextTheme;
  TextTheme? _cachedDarkTextTheme;
  TextTheme? _cachedBaseLight;
  TextTheme? _cachedBaseDark;

  // ═══════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════
  String get fontFamily => _fontFamily;
  String get fontId => _fontId;
  double get fontScale => _fontScale;
  String get fontSizeId => _fontSizeId;
  String get languageId => _languageId;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get newsNotifications => _newsNotifications;
  bool get complaintNotifications => _complaintNotifications;
  bool get orderNotifications => _orderNotifications;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  bool get isRtl => _languageId != 'en';

  // ═══════════════════════════════════════════════════════════
  // 🌍 Locale — ✅ چاککراو
  // ═══════════════════════════════════════════════════════════
  /// ⚠️ گرنگ: Flutter بە فەرمی Kurdish پشتگیری ناکات
  /// بۆیە بۆ کوردی، `ar_AE` بەکاردەهێنین (چونکە RTLـە)
  Locale get locale {
    switch (_languageId) {
      case 'ar':
        return const Locale('ar', 'AE');
      case 'en':
        return const Locale('en', 'US');
      case 'ku':
      default:
      // ✅ کوردی — عەرەبی بەکاردەهێنین چونکە:
      // 1. RTLـە (وەک کوردی)
      // 2. Flutter MaterialLocalizations پشتگیری دەکات
      // 3. مێژوو و کاتەکان دروست کار دەکەن
        return const Locale('ar', 'AE');
    }
  }

  /// 🎯 زمانەکانی پشتگیریکراو لە Flutter
  static const List<Locale> supportedLocales = [
    Locale('ku', 'IQ'),  // کوردی (custom delegate)
    Locale('ar', 'AE'),  // عەرەبی
    Locale('en', 'US'),  // ئینگلیزی
  ];

  // ═══════════════════════════════════════════════════
  // 🚀 دەستپێکردن
  // ═══════════════════════════════════════════════════
  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _fontId = prefs.getString('font_id') ?? 'rabar';
      _fontSizeId = prefs.getString('font_size_id') ?? 'normal';
      _fontScale = prefs.getDouble('font_scale') ?? 1.0;
      _languageId = prefs.getString('language_id') ?? 'ku';

      final font = availableFonts.firstWhere(
            (f) => f['id'] == _fontId,
        orElse: () => availableFonts[0],
      );
      _fontFamily = font['family']!;

      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _newsNotifications = prefs.getBool('news_notifications') ?? true;
      _complaintNotifications =
          prefs.getBool('complaint_notifications') ?? true;
      _orderNotifications = prefs.getBool('order_notifications') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    } catch (e) {
      debugPrint('⚠️ SettingsProvider load error: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════
  // 🎨 Cache
  // ═══════════════════════════════════════════════════
  void _invalidateTextThemeCache() {
    _cachedLightTextTheme = null;
    _cachedDarkTextTheme = null;
    _cachedBaseLight = null;
    _cachedBaseDark = null;
  }

  TextTheme getTextTheme(TextTheme base) {
    switch (_fontId) {
      case 'cairo':
        return GoogleFonts.cairoTextTheme(base);
      case 'noto_kufi':
        return GoogleFonts.notoKufiArabicTextTheme(base);
      case 'almarai':
        return GoogleFonts.almaraiTextTheme(base);
      case 'tajawal':
        return GoogleFonts.tajawalTextTheme(base);
      case 'amiri':
        return GoogleFonts.amiriTextTheme(base);
      case 'changa':
        return GoogleFonts.changaTextTheme(base);
      case 'elmesiri':
        return GoogleFonts.elMessiriTextTheme(base);
      case 'harmattan':
        return GoogleFonts.harmattanTextTheme(base);
      case 'lateef':
        return GoogleFonts.lateefTextTheme(base);
      case 'markazi':
        return GoogleFonts.markaziTextTextTheme(base);
      case 'mada':
        return GoogleFonts.madaTextTheme(base);
      case 'scheherazade':
        return GoogleFonts.scheherazadeNewTextTheme(base);
      case 'rabar':
      default:
        return base.apply(fontFamily: 'Rabar');
    }
  }

  TextTheme getLightTextTheme(TextTheme base) {
    if (_cachedLightTextTheme != null && _cachedBaseLight == base) {
      return _cachedLightTextTheme!;
    }
    _cachedBaseLight = base;
    _cachedLightTextTheme = getTextTheme(base);
    return _cachedLightTextTheme!;
  }

  TextTheme getDarkTextTheme(TextTheme base) {
    if (_cachedDarkTextTheme != null && _cachedBaseDark == base) {
      return _cachedDarkTextTheme!;
    }
    _cachedBaseDark = base;
    _cachedDarkTextTheme = getTextTheme(base);
    return _cachedDarkTextTheme!;
  }

  // ═══════════════════════════════════════════════════
  // 🔤 گۆڕینی فۆنت
  // ═══════════════════════════════════════════════════
  Future<void> setFont(String fontId) async {
    if (fontId == _fontId) return;

    final font = availableFonts.firstWhere(
          (f) => f['id'] == fontId,
      orElse: () => availableFonts[0],
    );
    _fontId = fontId;
    _fontFamily = font['family']!;

    _invalidateTextThemeCache();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_id', fontId);

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // 📏 گۆڕینی قەبارە
  // ═══════════════════════════════════════════════════
  Future<void> setFontSize(String sizeId) async {
    if (sizeId == _fontSizeId) return;

    final size = availableFontSizes.firstWhere(
          (s) => s['id'] == sizeId,
      orElse: () => availableFontSizes[1],
    );
    _fontSizeId = sizeId;
    _fontScale = (size['scale'] as num).toDouble();

    _invalidateTextThemeCache();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_size_id', sizeId);
    await prefs.setDouble('font_scale', _fontScale);

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // 🌍 گۆڕینی زمان
  // ═══════════════════════════════════════════════════
  Future<void> setLanguage(String languageId) async {
    if (languageId == _languageId) return;

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
    _languageId = 'ku';
    _notificationsEnabled = true;
    _newsNotifications = true;
    _complaintNotifications = true;
    _orderNotifications = true;
    _soundEnabled = true;
    _vibrationEnabled = true;

    _invalidateTextThemeCache();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('font_id');
    await prefs.remove('font_size_id');
    await prefs.remove('font_scale');
    await prefs.remove('language_id');
    await prefs.remove('notifications_enabled');
    await prefs.remove('news_notifications');
    await prefs.remove('complaint_notifications');
    await prefs.remove('order_notifications');
    await prefs.remove('sound_enabled');
    await prefs.remove('vibration_enabled');

    notifyListeners();
  }
}