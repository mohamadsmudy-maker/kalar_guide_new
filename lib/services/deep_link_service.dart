// lib/services/deep_link_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/app_links.dart';

/// 🔗 لینکی `kalarguide://place/12` یان `kalarguide://news/5` (لە MainActivity،
/// کەناڵی kalar/link). ئەنجام: (جۆر، ناسنامە).
class DeepLinkService {
  DeepLinkService._();

  static const _channel = MethodChannel('kalar/link');
  static final _controller = StreamController<(String, String)>.broadcast();
  static bool _started = false;

  static Stream<(String, String)> get stream => _controller.stream;

  static (String, String)? _parse(Object? raw) {
    final uri = raw is String ? Uri.tryParse(raw) : null;
    return uri == null ? null : AppLinks.parse(uri);
  }

  static Future<(String, String)?> initial() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    if (!_started) {
      _started = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onLink') {
          final l = _parse(call.arguments);
          if (l != null) _controller.add(l);
        }
      });
    }
    try {
      return _parse(await _channel.invokeMethod<Object?>('getInitialLink'));
    } catch (e) {
      debugPrint('⚠️ deep link: $e');
      return null;
    }
  }
}
