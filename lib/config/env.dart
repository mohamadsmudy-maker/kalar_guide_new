// 📁 lib/config/env.dart
import 'package:flutter/foundation.dart';

/// 🔐 کلیلەکانی ئەپ — تەنها لە `--dart-define` دێن
///
/// ⚠️ هەرگیز کلیلەکان لێرە بنووسە. بۆ dev، لە terminal بەکاربهێنە:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=xxx \
///   --dart-define=GEMINI_API_KEY=xxx \
///   --dart-define=GOOGLE_MAPS_API_KEY=xxx \
///   --dart-define=PASSWORD_SALT=xxx
/// ```
class AppEnv {
  AppEnv._();

  // ═══════════════════════════════════════════════════════════
  // 🔑 Supabase
  // ═══════════════════════════════════════════════════════════
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // ═══════════════════════════════════════════════════════════
  // 🤖 Gemini AI
  // ═══════════════════════════════════════════════════════════
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-1.5-flash',
  );

  static const String geminiApiVersion = String.fromEnvironment(
    'GEMINI_API_VERSION',
    defaultValue: 'v1beta',
  );

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Google Maps
  // ═══════════════════════════════════════════════════════════
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // ═══════════════════════════════════════════════════════════
  // 🔐 Password Salt (legacy)
  // ═══════════════════════════════════════════════════════════
  static const String passwordSalt = String.fromEnvironment(
    'PASSWORD_SALT',
    defaultValue: '',
  );

  // ═══════════════════════════════════════════════════════════
  // ✅ پشکنینی سەرەکی
  // ═══════════════════════════════════════════════════════════
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isGeminiConfigured => geminiApiKey.isNotEmpty;

  static bool get isMapsConfigured => googleMapsApiKey.isNotEmpty;

  /// 🚨 پشکنینی ئاسایش — لە release دا هەموو کلیلەکان دەبێت هەبن
  static void validateInRelease() {
    if (!kReleaseMode) return;

    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (passwordSalt.isEmpty) missing.add('PASSWORD_SALT');

    if (missing.isNotEmpty) {
      throw StateError(
        '❌ Missing required env vars in release: ${missing.join(', ')}\n'
            'Run with: flutter build apk --dart-define=SUPABASE_URL=... etc.',
      );
    }

    // ⚠️ ئاگاداری: ئەمە تەنها ئاگادارییە، نەک هەڵە
    if (geminiApiKey.isEmpty) {
      debugPrint('⚠️ GEMINI_API_KEY نەدۆزرایەوە — AI کار ناکات');
    }
    if (googleMapsApiKey.isEmpty) {
      debugPrint('⚠️ GOOGLE_MAPS_API_KEY نەدۆزرایەوە — Maps کار ناکات');
    }
  }
}