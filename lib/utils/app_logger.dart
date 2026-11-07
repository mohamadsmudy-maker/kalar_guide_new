// lib/utils/app_logger.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 📝 Logger ی پارێزراو — لە Release دا Log ناکات
class AppLogger {
  AppLogger._();

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگەکان
  // ═══════════════════════════════════════════════════════════
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';

  // ═══════════════════════════════════════════════════════════
  // 🚀 init
  // ═══════════════════════════════════════════════════════════
  static void init() {
    if (kDebugMode) {
      debugPrint(
        '$_green🚀 [INIT] Logger initialized (Debug Mode) - Ultra Pro Max$_reset',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Helpers
  // ═══════════════════════════════════════════════════════════
  static String _getTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
  }

  static void _log(String prefix, String color, String msg) {
    if (kDebugMode) {
      debugPrint('$color[$prefix] ${_getTime()} | $msg$_reset');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 Levels
  // ═══════════════════════════════════════════════════════════
  static void d(String msg) => _log('DEBUG', _cyan, '🔍 $msg');

  static void i(String msg) => _log('INFO', _blue, 'ℹ️ $msg');

  static void w(String msg) => _log('WARN', _yellow, '⚠️ $msg');

  static void s(String msg) => _log('SUCCESS', _green, '✅ $msg');

  static void e(String msg, [Object? error, StackTrace? st]) {
    if (kDebugMode) {
      debugPrint('$_red[ERROR] ${_getTime()} | ❌ $msg$_reset');
      if (error != null) debugPrint('$_red   Error: $error$_reset');
      if (st != null) debugPrint('$_red   StackTrace:\n$st$_reset');
    }
    // TODO: ناردنی هەڵە بۆ Crashlytics / Sentry
  }

  static void feature(String feature, String msg) {
    if (kDebugMode) {
      debugPrint(
        '$_magenta[FEATURE] ${_getTime()} | 🎯 [$feature] $msg$_reset',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🌐 API
  // ═══════════════════════════════════════════════════════════
  static void api(
      String method,
      String url, {
        int? status,
        dynamic response,
      }) {
    if (kDebugMode) {
      final statusStr = status != null ? ' [$status]' : '';
      final color = (status != null && status >= 200 && status < 300)
          ? _green
          : (status != null && status >= 400 ? _red : _cyan);

      debugPrint(
        '$color[API] ${_getTime()} | 🌐 $method$statusStr: $url$_reset',
      );

      if (response != null) {
        prettyJson(response, tag: 'API RESPONSE');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Data
  // ═══════════════════════════════════════════════════════════
  static void data(String msg, {Object? data}) {
    if (kDebugMode) {
      debugPrint('$_blue[DATA] ${_getTime()} | 📊 $msg$_reset');
      if (data != null) {
        if (data is Map || data is List) {
          prettyJson(data);
        } else {
          debugPrint('$_blue   Data: $data$_reset');
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🪄 prettyJson
  // ═══════════════════════════════════════════════════════════
  static void prettyJson(dynamic jsonObject, {String? tag}) {
    if (kDebugMode) {
      try {
        const encoder = JsonEncoder.withIndent('  ');
        final prettyString = encoder.convert(jsonObject);
        final title = tag != null ? ' $tag ' : ' JSON DATA ';

        debugPrint('$_yellow---$title---$_reset');
        prettyString.split('\n').forEach((element) {
          debugPrint('$_yellow$element$_reset');
        });
        debugPrint('$_yellow------------------$_reset');
      } catch (e) {
        debugPrint('$_red[JSON PARSE ERROR] Could not parse json: $e$_reset');
      }
    }
  }
}