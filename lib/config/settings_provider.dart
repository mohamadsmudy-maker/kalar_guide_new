// lib/config/settings_provider.dart
import '../l10n/tr.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ⚙️ بەڕێوەبردنی ڕێکخستن — Ultra Pro Max
class SettingsProvider extends ChangeNotifier {
  // ═══════════════════════════════════════════════════════════
  // 🔤 فۆنتەکان
  // ═══════════════════════════════════════════════════════════
  static const List<FontOption> availableFonts = [
    FontOption(id: 'rabar', name: 'ڕەبەر (Rabar)', family: 'Rabar'),
    FontOption(id: 'cairo', name: 'قاهیرە (Cairo)', family: 'Cairo'),
    FontOption(id: 'noto_kufi', name: 'نۆتۆ کوفی', family: 'NotoKufiArabic'),
    FontOption(id: 'almarai', name: 'المرعی (Almarai)', family: 'Almarai'),
    FontOption(id: 'tajawal', name: 'تجوال (Tajawal)', family: 'Tajawal'),
    FontOption(id: 'amiri', name: 'أمیری (Amiri)', family: 'Amiri'),
    FontOption(id: 'changa', name: 'تشانگا (Changa)', family: 'Changa'),
    FontOption(id: 'elmesiri', name: 'المسیری', family: 'ElMessiri'),
    FontOption(id: 'harmattan', name: 'هرمتان (Harmattan)', family: 'Harmattan'),
    FontOption(id: 'lateef', name: 'لەتیف (Lateef)', family: 'Lateef'),
    FontOption(id: 'markazi', name: 'مرکزی', family: 'MarkaziText'),
    FontOption(id: 'mada', name: 'مدا (Mada)', family: 'Mada'),
    FontOption(id: 'scheherazade', name: 'شهرزاد', family: 'ScheherazadeNew'),
    FontOption(id: 'readex', name: 'ڕیدێکس', family: 'ReadexPro'),
    FontOption(id: 'ibm_plex', name: 'IBM Plex', family: 'IBMPlexSansArabic'),
    FontOption(id: 'rubik', name: 'ڕوبیک', family: 'Rubik'),
  ];

  // ═══════════════════════════════════════════════════════════
  // 📏 قەبارە
  // ═══════════════════════════════════════════════════════════
  static const List<FontSizeOption> availableFontSizes = [
    FontSizeOption(id: 'small', name: 'بچووک', scale: 0.85),
    FontSizeOption(id: 'normal', name: 'ئاسایی', scale: 1.0),
    FontSizeOption(id: 'large', name: 'گەورە', scale: 1.15),
    FontSizeOption(id: 'xlarge', name: 'زۆر گەورە', scale: 1.3),
  ];

  // ═══════════════════════════════════════════════════════════
  // 🌍 زمان
  // ═══════════════════════════════════════════════════════════
  static const List<LanguageOption> availableLanguages = [
    LanguageOption(id: 'ku', name: 'کوردی', native: 'کوردی', flag: '🇮🇶'),
    LanguageOption(id: 'ar', name: 'عەرەبی', native: 'العربية', flag: '🇸🇦'),
    LanguageOption(id: 'en', name: 'ئینگلیزی', native: 'English', flag: '🇬🇧'),
  ];

  // ═══════════════════════════════════════════════════════════
  // 📊 دۆخ
  // ═══════════════════════════════════════════════════════════
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

  TextTheme? _cachedLightTextTheme;
  TextTheme? _cachedDarkTextTheme;
  TextTheme? _cachedBaseLight;
  TextTheme? _cachedBaseDark;
  String _cachedFontId = '';
  double _cachedFontScale = 1.0;

  // ═══════════════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════════════
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

  FontOption get currentFont => availableFonts.firstWhere(
        (f) => f.id == _fontId,
    orElse: () => availableFonts[0],
  );

  FontSizeOption get currentFontSize => availableFontSizes.firstWhere(
        (s) => s.id == _fontSizeId,
    orElse: () => availableFontSizes[1],
  );

  LanguageOption get currentLanguage => availableLanguages.firstWhere(
        (l) => l.id == _languageId,
    orElse: () => availableLanguages[0],
  );

  // ═══════════════════════════════════════════════════════════
  // 🌍 Locale
  // ═══════════════════════════════════════════════════════════
  Locale get locale {
    switch (_languageId) {
      case 'en':
        return const Locale('en', 'US');
      case 'ar':
      case 'ku':
      default:
        return const Locale('ar', 'AE');
    }
  }

  static const List<Locale> supportedLocales = [
    Locale('ku', 'IQ'),
    Locale('ar', 'AE'),
    Locale('en', 'US'),
  ];

  // ═══════════════════════════════════════════════════════════
  // 🚀 دەستپێکردن
  // ═══════════════════════════════════════════════════════════
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
      AppLang.setCode(_languageId);

      final font = availableFonts.firstWhere(
            (f) => f.id == _fontId,
        orElse: () => availableFonts[0],
      );
      _fontFamily = font.family;

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
      if (_languageId != 'ku') {
        WidgetsBinding.instance.addPostFrameCallback((_) => AppLang.rebuildAll());
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Cache
  // ═══════════════════════════════════════════════════════════
  void _invalidateTextThemeCache() {
    _cachedLightTextTheme = null;
    _cachedDarkTextTheme = null;
    _cachedBaseLight = null;
    _cachedBaseDark = null;
    _cachedFontId = '';
  }

  TextTheme _applyFont(TextTheme base) {
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
      case 'readex':
        return GoogleFonts.readexProTextTheme(base);
      case 'ibm_plex':
        return GoogleFonts.ibmPlexSansArabicTextTheme(base);
      case 'rubik':
        return GoogleFonts.rubikTextTheme(base);
      case 'rabar':
      default:
        return base.apply(fontFamily: 'Rabar');
    }
  }

  TextTheme getTextTheme(TextTheme base) => _applyFont(base);

  TextTheme getLightTextTheme(TextTheme base) {
    if (_cachedLightTextTheme != null &&
        identical(_cachedBaseLight, base) &&
        _cachedFontId == _fontId &&
        _cachedFontScale == _fontScale) {
      return _cachedLightTextTheme!;
    }
    _cachedBaseLight = base;
    _cachedFontId = _fontId;
    _cachedFontScale = _fontScale;
    _cachedLightTextTheme = _applyFont(base);
    return _cachedLightTextTheme!;
  }

  TextTheme getDarkTextTheme(TextTheme base) {
    if (_cachedDarkTextTheme != null &&
        identical(_cachedBaseDark, base) &&
        _cachedFontId == _fontId &&
        _cachedFontScale == _fontScale) {
      return _cachedDarkTextTheme!;
    }
    _cachedBaseDark = base;
    _cachedFontId = _fontId;
    _cachedFontScale = _fontScale;
    _cachedDarkTextTheme = _applyFont(base);
    return _cachedDarkTextTheme!;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔤 گۆڕینی فۆنت
  // ═══════════════════════════════════════════════════════════
  Future<void> setFont(String fontId) async {
    if (fontId == _fontId) return;

    final font = availableFonts.firstWhere(
          (f) => f.id == fontId,
      orElse: () => availableFonts[0],
    );
    _fontId = fontId;
    _fontFamily = font.family;

    _invalidateTextThemeCache();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_id', fontId);

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // 📏 گۆڕینی قەبارە
  // ═══════════════════════════════════════════════════════════
  Future<void> setFontSize(String sizeId) async {
    if (sizeId == _fontSizeId) return;

    final size = availableFontSizes.firstWhere(
          (s) => s.id == sizeId,
      orElse: () => availableFontSizes[1],
    );
    _fontSizeId = sizeId;
    _fontScale = size.scale;

    _invalidateTextThemeCache();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_size_id', sizeId);
    await prefs.setDouble('font_scale', _fontScale);

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // 🌍 گۆڕینی زمان
  // ═══════════════════════════════════════════════════════════
  Future<void> setLanguage(String languageId) async {
    if (languageId == _languageId) return;
    if (!availableLanguages.any((l) => l.id == languageId)) return;

    _languageId = languageId;
    AppLang.setCode(languageId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_id', languageId);

    notifyListeners();
    // شاشە کراوەکانیش (نەک تەنها MaterialApp) زمانەکەیان بگۆڕن
    WidgetsBinding.instance.addPostFrameCallback((_) => AppLang.rebuildAll());
  }

  // ═══════════════════════════════════════════════════════════
  // 🔔 ئاگادارکردنەوە
  // ═══════════════════════════════════════════════════════════
  Future<void> setNotificationsEnabled(bool value) async {
    if (value == _notificationsEnabled) return;
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    notifyListeners();
  }

  Future<void> setNewsNotifications(bool value) async {
    if (value == _newsNotifications) return;
    _newsNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('news_notifications', value);
    notifyListeners();
  }

  Future<void> setComplaintNotifications(bool value) async {
    if (value == _complaintNotifications) return;
    _complaintNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('complaint_notifications', value);
    notifyListeners();
  }

  Future<void> setOrderNotifications(bool value) async {
    if (value == _orderNotifications) return;
    _orderNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('order_notifications', value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    if (value == _soundEnabled) return;
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    if (value == _vibrationEnabled) return;
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', value);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 گەڕاندنەوە
  // ═══════════════════════════════════════════════════════════
  Future<void> resetToDefaults() async {
    _fontId = 'rabar';
    _fontFamily = 'Rabar';
    _fontSizeId = 'normal';
    _fontScale = 1.0;
    _languageId = 'ku';
    AppLang.setCode('ku');
    _notificationsEnabled = true;
    _newsNotifications = true;
    _complaintNotifications = true;
    _orderNotifications = true;
    _soundEnabled = true;
    _vibrationEnabled = true;

    _invalidateTextThemeCache();

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'font_id',
      'font_size_id',
      'font_scale',
      'language_id',
      'notifications_enabled',
      'news_notifications',
      'complaint_notifications',
      'order_notifications',
      'sound_enabled',
      'vibration_enabled',
    ]) {
      await prefs.remove(key);
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // 📤 Export / Import
  // ═══════════════════════════════════════════════════════════
  Map<String, dynamic> toJson() => {
    'font_id': _fontId,
    'font_size_id': _fontSizeId,
    'font_scale': _fontScale,
    'language_id': _languageId,
    'notifications_enabled': _notificationsEnabled,
    'news_notifications': _newsNotifications,
    'complaint_notifications': _complaintNotifications,
    'order_notifications': _orderNotifications,
    'sound_enabled': _soundEnabled,
    'vibration_enabled': _vibrationEnabled,
  };

  Future<void> applyJson(Map<String, dynamic> json) async {
    if (json['font_id'] is String) {
      await setFont(json['font_id'] as String);
    }
    if (json['font_size_id'] is String) {
      await setFontSize(json['font_size_id'] as String);
    }
    if (json['language_id'] is String) {
      await setLanguage(json['language_id'] as String);
    }
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════
// 🧱 Data Models
// ═══════════════════════════════════════════════════════════════
@immutable
class FontOption {
  final String id;
  final String name;
  final String family;

  const FontOption({
    required this.id,
    required this.name,
    required this.family,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FontOption && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

@immutable
class FontSizeOption {
  final String id;
  final String name;
  final double scale;

  const FontSizeOption({
    required this.id,
    required this.name,
    required this.scale,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FontSizeOption && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

@immutable
class LanguageOption {
  final String id;
  final String name;
  final String native;
  final String flag;

  const LanguageOption({
    required this.id,
    required this.name,
    required this.native,
    required this.flag,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LanguageOption && other.id == id);

  @override
  int get hashCode => id.hashCode;
}