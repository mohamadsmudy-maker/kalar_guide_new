// lib/utils/error_reporter.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// 📊 تۆمارکردنی هەڵە لە Crashlytics — Ultra Pro Max
class ErrorReporter {
  ErrorReporter._();

  static bool _crashlyticsEnabled = false;

  // ═══════════════════════════════════════════════════════════
  // 🚀 initialize
  // ═══════════════════════════════════════════════════════════
  static void initialize({bool crashlytics = true}) {
    _crashlyticsEnabled = crashlytics && !kDebugMode;

    if (kDebugMode) {
      debugPrint('📊 ErrorReporter: Debug Mode — هەڵە نانێردرێت');
      return;
    }

    if (!_crashlyticsEnabled) return;

    try {
      // Flutter Errors
      FlutterError.onError = (details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        debugPrint('🔥 Crashlytics: ${details.exception}');
      };

      // Async Errors
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      debugPrint('✅ Crashlytics چالاکە');
    } catch (e) {
      debugPrint('❌ Crashlytics init error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🐛 recordError
  // ═══════════════════════════════════════════════════════════
  static Future<void> recordError(
      dynamic error,
      StackTrace? stackTrace, {
        String? reason,
        bool fatal = false,
        Map<String, dynamic>? extras,
      }) async {
    if (kDebugMode) {
      debugPrint('🐛 [Debug] $reason: $error');
      return;
    }

    if (!_crashlyticsEnabled) return;

    try {
      List<String>? info;
      if (extras != null && extras.isNotEmpty) {
        info = extras.entries.map((e) => '${e.key}: ${e.value}').toList();
      }

      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
        information: info ?? const <String>[],
      );
    } catch (e) {
      debugPrint('❌ Crashlytics recordError: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 log
  // ═══════════════════════════════════════════════════════════
  static void log(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      debugPrint('📝 $message ${data ?? ''}');
      return;
    }

    if (!_crashlyticsEnabled) return;

    try {
      FirebaseCrashlytics.instance.log(message);
      if (data != null) {
        data.forEach((key, value) {
          if (value is String || value is num || value is bool) {
            FirebaseCrashlytics.instance.setCustomKey(key, value);
          } else {
            FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
          }
        });
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // 👤 setUser
  // ═══════════════════════════════════════════════════════════
  static Future<void> setUser({
    required String id,
    String? name,
    String? phone,
  }) async {
    if (kDebugMode || !_crashlyticsEnabled) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(id);
      if (name != null) {
        await FirebaseCrashlytics.instance.setCustomKey('user_name', name);
      }
      if (phone != null) {
        await FirebaseCrashlytics.instance.setCustomKey('user_phone', phone);
      }
    } catch (_) {}
  }
}