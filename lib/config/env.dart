// lib/config/env.dart
import 'package:flutter/foundation.dart';

/// 🔐 کلیلەکانی ئەپ — تەنها لە `--dart-define` دێن
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
  // 🔐 Password Salt (legacy — بۆ migration تەنها)
  // ═══════════════════════════════════════════════════════════
  static const String passwordSalt = String.fromEnvironment(
    'PASSWORD_SALT',
    defaultValue: '',
  );

  // ═══════════════════════════════════════════════════════════
  // ✅ پشکنینەکان
  // ═══════════════════════════════════════════════════════════
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

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
  }
}