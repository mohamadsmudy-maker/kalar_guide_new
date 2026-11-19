// lib/utils/error_reporter.dart
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// 📊 ناردنی هەڵە و تێکچوونەکان بۆ Firebase Crashlytics
///
/// - تەنها لە وەشانی release کار دەکات (لە debug هیچ نانێرێت).
/// - هەڵەی تۆڕ (ئینتەرنێتی لاواز) نانێرێت، چونکە کێشەی ئەپ نین.
/// - هیچ زانیاریی کەسی (ناو، ژمارە) نانێرێت؛ تەنها ناسنامەی بەکارهێنەر.
class ErrorReporter {
  ErrorReporter._();

  static bool _enabled = false;

  /// ئایا Crashlytics چالاکە (Firebase ئامادەیە و release ـە)
  static bool get enabled => _enabled;

  /// دوای `Firebase.initializeApp` بانگ دەکرێت
  static Future<void> initialize() async {
    if (kDebugMode || Firebase.apps.isEmpty) return;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _enabled = true;
    } catch (e) {
      debugPrint('❌ Crashlytics init error: $e');
    }
  }

  /// ئایا ئەم هەڵەیە شایەنی ناردنە؟ هەڵەی تۆڕ و کاتی تەواوبوو نانێردرێن.
  @visibleForTesting
  static bool shouldReport(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is HttpException) {
      return false;
    }
    final s = error.toString().toLowerCase();
    const networkHints = [
      'socketexception',
      'failed host lookup',
      'connection closed',
      'connection reset',
      'connection refused',
      'network is unreachable',
      'clientexception',
      'timed out',
      'timeoutexception',
      'handshakeexception',
    ];
    return !networkHints.any(s.contains);
  }

  /// هەڵەی تۆڕە (ئینتەرنێت نییە، کاتی تەواوبوو...)؟
  static bool isNetworkError(Object error) => !shouldReport(error);

  /// هەڵەی Flutter (لە کاتی وێنەکێشانی شاشە)
  static void recordFlutterError(FlutterErrorDetails details) {
    if (!_enabled || !shouldReport(details.exception)) return;
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {}
  }

  /// هەڵەیەکی گشتی. [fatal] بۆ ئەو هەڵانەیە کە کەس نەیگرتوون.
  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_enabled || !shouldReport(error)) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {}
  }

  /// تێبینییەک کە لەگەڵ ڕاپۆرتی تێکچوونی داهاتوو دەردەکەوێت
  static void log(String message) {
    if (!_enabled) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  /// تەنها ناسنامەی بەکارهێنەر (UUID) — نەک ناو یان ژمارە
  static Future<void> setUserId(String? id) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(id ?? '');
    } catch (_) {}
  }

  static Future<void> setKey(String key, String value) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (_) {}
  }
}
