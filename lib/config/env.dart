// lib/config/env.dart
import 'package:flutter/foundation.dart';

/// 🔐 کلیلەکانی ئەپ — Ultra Pro Max
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
  // 🛠️ Debug Flags
  // ═══════════════════════════════════════════════════════════
  static const bool enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: true,
  );

  static const bool enableDebugBanner = bool.fromEnvironment(
    'ENABLE_DEBUG_BANNER',
    defaultValue: false,
  );

  // ═══════════════════════════════════════════════════════════
  // ✅ پشکنین
  // ═══════════════════════════════════════════════════════════
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static List<String> get missingVariables {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    return missing;
  }

  static void validateInRelease() {
    final missing = missingVariables;
    if (missing.isEmpty) return;

    final message =
        '❌ Missing required env vars: ${missing.join(', ')}\n'
        'Run with:\n'
        '  flutter build apk \\\n'
        '    --dart-define=SUPABASE_URL=... \\\n'
        '    --dart-define=SUPABASE_ANON_KEY=...';

    if (kReleaseMode) {
      throw StateError(message);
    } else {
      debugPrint('⚠️ WARNING: $message');
      debugPrint('⚠️ App may not function correctly in debug mode.');
    }
  }

  static bool get isReady => isSupabaseConfigured;

  static void printStatus() {
    if (!enableLogging || kReleaseMode) return;
    debugPrint('═══════════════════════════════════════════');
    debugPrint('🔐 AppEnv Status');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('  Supabase URL:      ${supabaseUrl.isEmpty ? "❌ missing" : "✅ set"}');
    debugPrint('  Supabase Key:      ${supabaseAnonKey.isEmpty ? "❌ missing" : "✅ set"}');
    debugPrint('  Logging:           ${enableLogging ? "✅ on" : "❌ off"}');
    debugPrint('  Release mode:      ${kReleaseMode ? "✅ yes" : "❌ no (debug)"}');
    debugPrint('═══════════════════════════════════════════');
  }
}