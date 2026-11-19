// lib/services/network_status.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 📡 ئایا مۆبایلەکە هیچ تۆڕێکی نییە؟ (WiFi و داتای مۆبایل هەردووکیان کوژاون)
///
/// بەکاردێت بۆ ئەوەی بێ ئینتەرنێت یەکسەر داتای هەڵگیراو پیشان بدرێت، نەک
/// چاوەڕێی سێرڤەر بکرێت تا کاتی تەواوبوون.
class NetworkStatus {
  NetworkStatus._();

  static bool _offline = false;
  static StreamSubscription<List<ConnectivityResult>>? _sub;

  static bool get offline => _offline;

  @visibleForTesting
  static set offlineForTest(bool v) => _offline = v;

  static bool isOfflineResult(List<ConnectivityResult> r) =>
      r.isNotEmpty && r.every((e) => e == ConnectivityResult.none);

  /// یەکجار لە سەرەتای ئەپ (زۆرترین ١ چرکە)
  static Future<void> start() async {
    try {
      final c = Connectivity();
      _offline = isOfflineResult(await c.checkConnectivity().timeout(const Duration(seconds: 1)));
      _sub ??= c.onConnectivityChanged.listen((r) => _offline = isOfflineResult(r), onError: (_) {});
    } catch (_) {
      _offline = false; // نازانرێت → هەوڵی سێرڤەر دەدرێت
    }
  }
}
