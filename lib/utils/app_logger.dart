import 'package:flutter/foundation.dart';

/// 📝 Logger ی پارێزراو — لە Release دا Log ناکات
class AppLogger {
  AppLogger._();

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

  static void feature(String feature, String msg) {
    if (kDebugMode) debugPrint('🎯 [$feature] $msg');
  }

  static void api(String method, String url, {int? status}) {
    if (kDebugMode) {
      final statusStr = status != null ? ' [$status]' : '';
      debugPrint('🌐 $method$statusStr: $url');
    }
  }

  static void data(String msg, {Object? data}) {
    if (kDebugMode) {
      debugPrint('📊 $msg');
      if (data != null) debugPrint('   Data: $data');
    }
  }
}