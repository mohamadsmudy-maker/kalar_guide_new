// lib/services/share_intent_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// هەواڵێکی ئامادە لە شێرێکەوە (Facebook و ئەپەکانی تر)
@immutable
class SharedNewsDraft {
  const SharedNewsDraft({
    required this.title,
    required this.description,
    this.sourceUrl,
    this.imagePaths = const [],
  });

  final String title;
  final String description;
  final String? sourceUrl;
  final List<String> imagePaths;

  bool get isEmpty => title.isEmpty && description.isEmpty && imagePaths.isEmpty;

  static final RegExp _url = RegExp(r'https?://\S+');

  /// ناوی سەرچاوە لە لینکەکەوە (Facebook، Instagram...)
  static String sourceName(String url) {
    final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    if (host.contains('facebook.com') || host.contains('fb.watch') || host == 'fb.me') return 'Facebook';
    if (host.contains('instagram.com')) return 'Instagram';
    if (host.contains('t.me') || host.contains('telegram')) return 'Telegram';
    if (host.contains('youtube.com') || host == 'youtu.be') return 'YouTube';
    return host.replaceFirst(RegExp(r'^www\.'), '');
  }

  /// دەقی شێرکراو → ناونیشان (یەکەم دێڕ) + وەسف + دێڕی سەرچاوە
  factory SharedNewsDraft.fromShare({String? text, String? subject, List<String> images = const []}) {
    final raw = (text ?? '').trim();
    final url = _url.firstMatch(raw)?.group(0)?.replaceAll(RegExp(r'[).,،]+$'), '');
    final body = raw.replaceAll(_url, '').replaceAll(RegExp(r'[ \t]+\n'), '\n').trim();
    final lines = body.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    var title = (subject ?? '').trim();
    var rest = lines;
    if (title.isEmpty && lines.isNotEmpty) {
      title = lines.first;
      rest = lines.skip(1).toList();
    }
    if (title.length > 120) {
      final cut = title.lastIndexOf(' ', 117);
      title = '${title.substring(0, cut > 60 ? cut : 117)}…';
      rest = lines; // ناونیشان کورتکرایەوە: هەموو دەقەکە لە وەسفدا بمێنێتەوە
    }

    final desc = StringBuffer(rest.join('\n'));
    if (url != null) {
      if (desc.isNotEmpty) desc.write('\n\n');
      desc.write('🔗 سەرچاوە: ${sourceName(url)}\n$url');
    }
    return SharedNewsDraft(
      title: title,
      description: desc.toString(),
      sourceUrl: url,
      imagePaths: images,
    );
  }
}

/// شێرەکان لە MainActivity (کەناڵی kalar/share) وەردەگرێت.
class ShareIntentService {
  ShareIntentService._();

  static const _channel = MethodChannel('kalar/share');
  static final _controller = StreamController<SharedNewsDraft>.broadcast();
  static bool _started = false;

  /// شێرە نوێیەکان کاتێک ئەپەکە کراوەیە
  static Stream<SharedNewsDraft> get stream => _controller.stream;

  static SharedNewsDraft? _parse(Object? args) {
    if (args is! Map) return null;
    final images = (args['images'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final d = SharedNewsDraft.fromShare(
      text: args['text'] as String?,
      subject: args['subject'] as String?,
      images: images,
    );
    return d.isEmpty ? null : d;
  }

  /// ئەو شێرەی ئەپەکەی پێ کرایەوە (یەکجار)
  static Future<SharedNewsDraft?> initial() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    _start();
    try {
      return _parse(await _channel.invokeMethod<Object?>('getInitialShare'));
    } catch (e) {
      debugPrint('⚠️ share intent: $e');
      return null;
    }
  }

  static void _start() {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final d = _parse(call.arguments);
        if (d != null) _controller.add(d);
      }
    });
  }
}
