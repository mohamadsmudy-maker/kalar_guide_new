import 'package:flutter/foundation.dart';

/// 📝 Logger ی پارێزراو — لە Release دا Log ناکات
class AppLogger {
  static void init() {
    if (kDebugMode) {
      debugPrint('🚀 Logger initialized (Debug Mode)');
    }
  }

  static void d(String msg) {
    if (kDebugMode) debugPrint('🔍 $msg');
  }

  static void i(String msg) {
    if (kDebugMode) debugPrint('ℹ️ $msg');
  }

  static void w(String msg) {
    if (kDebugMode) debugPrint('⚠️ $msg');
  }

  static void e(String msg, [Object? error, StackTrace? st]) {
    if (kDebugMode) {
      debugPrint('❌ $msg');
      if (error != null) debugPrint('   Error: $error');
      if (st != null) debugPrint('   $st');
    }
    // TODO: لێرە دەتوانیت بۆ Crashlytics / Sentry بینێریت
  }
}