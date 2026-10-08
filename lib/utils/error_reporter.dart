import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// 📊 تۆمارکردنی هەڵە لە Crashlytics و Sentry
class ErrorReporter {
  ErrorReporter._();

  static bool _crashlyticsEnabled = false;
  static bool _sentryEnabled = false;

  /// ✅ دەستپێکردن — لە main.dart بانگ بکە
  static void initialize({
    bool crashlytics = true,
    bool sentry = false,
    String? sentryDsn,
  }) {
    _crashlyticsEnabled = crashlytics && !kDebugMode;
    _sentryEnabled = sentry && sentryDsn != null && sentryDsn.isNotEmpty;

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

    // ✅ Sentry
    if (_sentryEnabled) {
      debugPrint('✅ Sentry چالاکە');
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
        await FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: reason,
          fatal: fatal,
          information: extras?.entries
              .map((e) => '${e.key}: ${e.value}')
              .toList(),
        );
      } catch (e) {
        debugPrint('❌ Crashlytics recordError: $e');
      }
    }

    // ✅ Sentry
    if (_sentryEnabled) {
      try {
        await Sentry.captureException(
          error,
          stackTrace: stackTrace,
          withScope: (scope) {
            if (reason != null) scope.setTag('reason', reason);
            if (extras != null) {
              extras.forEach((key, value) {
                scope.setExtra(key, value);
              });
            }
          },
        );
      } catch (e) {
        debugPrint('❌ Sentry recordError: $e');
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
            FirebaseCrashlytics.instance.setCustomKey(key, value);
          });
        }
      } catch (_) {}
    }

    if (_sentryEnabled) {
      try {
        Sentry.addBreadcrumb(
          Breadcrumb(message: message, data: data),
        );
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

    if (_sentryEnabled) {
      try {
        Sentry.configureScope((scope) {
          scope.setUser(SentryUser(id: id, username: name));
        });
      } catch (_) {}
    }
  }
}