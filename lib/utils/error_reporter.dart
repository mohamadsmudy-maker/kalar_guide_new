import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// 📊 تۆمارکردنی هەڵە لە Crashlytics
///
/// ✅ Sentry لابرا — تەنها Crashlytics بەکاردەهێنرێت
/// ✅ ئەگەر دەتەوێت Sentry زیاد بکەیت، لە pubspec.yaml
///    `sentry_flutter: ^8.11.0` زیاد بکە و کۆدی Sentry بگەڕێنەوە.
class ErrorReporter {
  ErrorReporter._();

  static bool _crashlyticsEnabled = false;

  /// ✅ دەستپێکردن — لە main.dart بانگ بکە
  static void initialize({
    bool crashlytics = true,
  }) {
    _crashlyticsEnabled = crashlytics && !kDebugMode;

    if (kDebugMode) {
      debugPrint('📊 ErrorReporter: Debug Mode — هەڵە نانێردرێت');
      return;
    }

    // ✅ Crashlytics
    if (_crashlyticsEnabled) {
      FlutterError.onError = (details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        debugPrint('🔥 Crashlytics: ${details.exception}');
      };

      // ✅ Async Errors
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: true,
        );
        return true;
      };

      debugPrint('✅ Crashlytics چالاکە');
    }
  }

  /// ✅ تۆمارکردنی هەڵە
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

    // ✅ Crashlytics
    if (_crashlyticsEnabled) {
      try {
        List<String>? info;
        if (extras != null && extras.isNotEmpty) {
          info = extras.entries
              .map((e) => '${e.key}: ${e.value}')
              .toList();
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
  }

  /// ✅ تۆمارکردنی Log
  static void log(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      debugPrint('📝 $message ${data ?? ''}');
      return;
    }

    if (_crashlyticsEnabled) {
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
  }

  /// ✅ دانانی User ID
  static Future<void> setUser({
    required String id,
    String? name,
    String? phone,
  }) async {
    if (kDebugMode) return;

    if (_crashlyticsEnabled) {
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
}