// lib/services/complaint_queue.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'audio_service.dart';
import 'image_service.dart';

/// سکاڵایەک کە بە هۆی نەبوونی ئینتەرنێت هێشتا نەنێردراوە
class QueuedComplaint {
  QueuedComplaint({required this.id, required this.data, required this.images, this.voice});

  final String id;

  /// ستوونەکانی خشتەی complaints (بێ images و voice_url)
  final Map<String, dynamic> data;

  /// ڕێڕەوی وێنەکان لەسەر مۆبایل
  final List<String> images;
  final String? voice;

  Map<String, dynamic> toJson() => {'id': id, 'data': data, 'images': images, 'voice': voice};

  factory QueuedComplaint.fromJson(Map<String, dynamic> j) => QueuedComplaint(
        id: '${j['id']}',
        data: Map<String, dynamic>.from(j['data'] as Map),
        images: [for (final p in (j['images'] as List? ?? const [])) '$p'],
        voice: j['voice'] as String?,
      );
}

/// 📮 ڕیزی سکاڵا بێ ئینتەرنێت: لەسەر مۆبایل هەڵدەگیرێن و کاتێک ئینتەرنێت
/// گەڕایەوە (یان ئەپەکە کرایەوە) خۆکار دەنێردرێن.
class ComplaintQueue {
  ComplaintQueue._();

  static const String _key = 'complaint_queue_v1';

  /// ژمارەی سکاڵا چاوەڕوانەکان (بۆ پیشاندان)
  static final ValueNotifier<int> pending = ValueNotifier(0);

  // ── بۆ تاقیکردنەوە دەگۆڕدرێن ─────────────────────────────
  @visibleForTesting
  static Future<String> Function(String path) uploadImage =
      (p) => ImageCompressionService.uploadImage(XFile(p));
  @visibleForTesting
  static Future<String?> Function(String path) uploadVoice = AudioService.uploadAudio;
  @visibleForTesting
  static Future<void> Function(Map<String, dynamic> row) insert =
      (row) => Supabase.instance.client.from('complaints').insert(row);
  @visibleForTesting
  static Future<Directory> Function() storageDir = getApplicationDocumentsDirectory;

  static Future<List<QueuedComplaint>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          QueuedComplaint.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<QueuedComplaint> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode([for (final i in items) i.toJson()]));
    pending.value = items.length;
  }

  /// وێنە و دەنگەکە بۆ شوێنێکی هەمیشەیی کۆپی دەکات (نەک cache کە دەسڕدرێتەوە)
  static Future<QueuedComplaint> enqueue({
    required Map<String, dynamic> data,
    required List<String> images,
    String? voice,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dir = Directory('${(await storageDir()).path}/complaint_queue/$id');
    await dir.create(recursive: true);

    Future<String?> keep(String? path, String name) async {
      if (path == null || path.isEmpty) return null;
      final f = File(path);
      if (!await f.exists()) return null;
      final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '';
      return (await f.copy('${dir.path}/$name$ext')).path;
    }

    final kept = <String>[];
    for (var i = 0; i < images.length; i++) {
      final p = await keep(images[i], 'img$i');
      if (p != null) kept.add(p);
    }
    final item = QueuedComplaint(id: id, data: data, images: kept, voice: await keep(voice, 'voice'));
    await _save([...await load(), item]);
    return item;
  }

  static bool _flushing = false;

  /// هەموو سکاڵا چاوەڕوانەکان دەنێرێت. ژمارەی نێردراوەکان دەگەڕێنێتەوە.
  /// لە یەکەم هەڵەی تۆڕدا دەوەستێت (ئەوانی تر دەمێننەوە بۆ جاری داهاتوو).
  static Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final items = await load();
      pending.value = items.length;
      final left = [...items];
      for (final item in items) {
        try {
          final urls = <String>[for (final p in item.images) await uploadImage(p)];
          String? voiceUrl;
          if (item.voice != null) {
            try {
              voiceUrl = await uploadVoice(item.voice!);
            } catch (e) {
              debugPrint('⚠️ queued voice: $e'); // سکاڵاکە بێ دەنگیش دەنێردرێت
            }
          }
          await insert({
            ...item.data,
            'images': urls,
            if (voiceUrl != null && voiceUrl.isNotEmpty) 'voice_url': voiceUrl,
          });
          left.remove(item);
          sent++;
          await _save(left);
          await _deleteFiles(item);
        } catch (e) {
          debugPrint('📮 complaint queue: will retry later ($e)');
          break;
        }
      }
    } finally {
      _flushing = false;
    }
    return sent;
  }

  static Future<void> _deleteFiles(QueuedComplaint item) async {
    try {
      final dir = Directory('${(await storageDir()).path}/complaint_queue/${item.id}');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  static StreamSubscription<List<ConnectivityResult>>? _sub;

  /// یەکجار لە دەستپێکردنی ئەپ: ئێستا و هەر جارێک ئینتەرنێت گەڕایەوە دەنێرێت
  static void start() {
    unawaited(load().then((l) => pending.value = l.length));
    unawaited(flush());
    if (_sub != null) return;
    try {
      _sub = Connectivity().onConnectivityChanged.listen((r) {
        if (r.any((e) => e != ConnectivityResult.none)) unawaited(flush());
      }, onError: (_) {});
    } catch (_) {}
  }
}
