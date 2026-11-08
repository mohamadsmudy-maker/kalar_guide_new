// lib/services/translation_service.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🌍 وەرگێڕانی دەق بە Gemini لە ڕێگەی Supabase Edge Function — ULTRA PRO MAX V2
///
/// ✅ کاش (LRU) — هەمان دەق دووبارە بۆ سێرڤەر نانێردرێت (خێراتر + هەرزانتر)
/// ✅ داواکاری هاوشێوە یەک دەکرێنەوە (١٠ ویجێت هەمان دەق = ١ داواکاری)
/// ✅ timeout — UI هەرگیز گیر ناخوات
/// ✅ وەڵامی String یان Map هەردووکی قبوڵە
/// ✅ هەڵەکان کاش ناکرێن، بۆیە دواتر دووبارە هەوڵ دەدرێتەوە
class TranslationService {
  TranslationService._();

  static const String _functionName = 'translate-text';
  static const String _sourceLanguage = 'ku';
  static const Set<String> _supportedTargets = {'ar', 'en'};
  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxCacheEntries = 500;
  static const int _maxTextLength = 5000;

  static final LinkedHashMap<String, String> _cache = LinkedHashMap();
  static final Map<String, Future<String?>> _inFlight = {};

  /// دەقەکە وەردەگێڕێت بۆ [targetLanguage]. لە هەر هەڵەیەکدا دەقی ئەسڵی دەگەڕێنێتەوە.
  static Future<String> translate({
    required String text,
    required String targetLanguage,
  }) async =>
      (await tryTranslate(text: text, targetLanguage: targetLanguage)) ?? text;

  /// وەک [translate]، بەڵام null = وەرگێڕان نەکرا (بۆ ئەوەی دەقە کوردییەکە
  /// وەک «وەرگێڕان» هەڵنەگیرێت و دواتر دووبارە هەوڵ بدرێتەوە)
  static Future<String?> tryTranslate({
    required String text,
    required String targetLanguage,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        targetLanguage == _sourceLanguage ||
        !_supportedTargets.contains(targetLanguage) ||
        trimmed.length > _maxTextLength ||
        _looksUntranslatable(trimmed)) {
      return SynchronousFuture(text);
    }

    final key = '$targetLanguage\u0000$trimmed';

    final cached = _cache.remove(key) ?? _disk[key];
    if (cached != null) {
      _cache[key] = cached; // LRU: بیهێنە کۆتایی
      return SynchronousFuture(cached);
    }

    if (fetchOverride != null) {
      return _inFlight[key] ??= fetchOverride!(trimmed, targetLanguage).then((result) {
        if (result != null) _put(key, result);
        return result;
      }).whenComplete(() {
        _inFlight.remove(key);
      });
    }
    // دەقە کورتەکان کۆ دەکرێنەوە و پێکەوە دەنێردرێن (سنووری خولەکی Gemini)
    if (trimmed.length <= _batchItemMax) {
      return _inFlight[key] ??= _enqueue(trimmed, targetLanguage).whenComplete(() {
        _inFlight.remove(key);
      });
    }
    return _inFlight[key] ??= _fetch(trimmed, targetLanguage).then((result) {
      if (result != null) _put(key, result);
      return result;
    }).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 📦 بە کۆمەڵ: ٤٠ دەق بە یەک داواکاری
  // ═══════════════════════════════════════════════════════════
  static const int _batchSize = 40;
  static const int _batchItemMax = 600;
  static const Duration _batchDelay = Duration(milliseconds: 350);

  /// lang → دەق → چاوەڕوانەکان
  static final Map<String, Map<String, List<Completer<String?>>>> _pending = {};
  static Timer? _flushTimer;
  static bool _flushing = false;

  /// false = فەنکشنەکە هێشتا وەشانی کۆنە (texts نازانێت) → یەک یەک
  static bool _batchSupported = true;

  static Future<String?> _enqueue(String text, String lang) {
    final c = Completer<String?>();
    ((_pending[lang] ??= {})[text] ??= []).add(c);
    _flushTimer ??= Timer(_batchDelay, _flush);
    return c.future;
  }

  static Future<void> _flush() async {
    _flushTimer = null;
    if (_flushing) {
      _flushTimer ??= Timer(_batchDelay, _flush);
      return;
    }
    _flushing = true;
    try {
      while (_pending.isNotEmpty) {
        final lang = _pending.keys.first;
        final group = _pending.remove(lang)!;
        final texts = group.keys.toList();
        for (var i = 0; i < texts.length; i += _batchSize) {
          final chunk = texts.sublist(i, math.min(i + _batchSize, texts.length));
          final results = await _translateChunk(chunk, lang);
          for (var j = 0; j < chunk.length; j++) {
            for (final c in group[chunk[j]]!) {
              if (!c.isCompleted) c.complete(results[j]);
            }
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// تەنها بۆ تاقیکردنەوە: لە جیاتی Edge Function (بە کۆمەڵ)
  @visibleForTesting
  static Future<List<String?>?> Function(List<String> texts, String lang)? fetchBatchOverride;

  /// ئەنجام: هەمان ڕیز؛ null = وەرنەگێڕدرا
  static Future<List<String?>> _translateChunk(List<String> chunk, String lang) async {
    List<String?> results = List.filled(chunk.length, null);
    if (fetchBatchOverride != null) {
      results = await fetchBatchOverride!(chunk, lang) ?? results;
    } else if (_batchSupported) {
      final batch = await _fetchBatch(chunk, lang);
      if (batch != null) {
        results = batch;
      } else if (!_batchSupported) {
        // وەشانی کۆنی فەنکشنەکە: یەک یەک
        results = [for (final t in chunk) await _fetch(t, lang)];
      }
    } else {
      results = [for (final t in chunk) await _fetch(t, lang)];
    }
    for (var j = 0; j < chunk.length; j++) {
      final r = results[j]?.trim();
      if (r != null && r.isNotEmpty) _put('$lang\u0000${chunk[j]}', r);
    }
    return results;
  }

  static List<String?>? _readBatch(dynamic data, int n) {
    dynamic d = data;
    if (d is String) {
      try {
        d = jsonDecode(d);
      } catch (_) {
        return null;
      }
    }
    final list = d is Map ? d['translations'] : null;
    if (list is! List || list.length != n) return null;
    return [
      for (final x in list) (x is String && x.trim().isNotEmpty) ? x.trim() : null,
    ];
  }

  /// null = داواکارییەکە بە تەواوی شکستی هێنا
  static Future<List<String?>?> _fetchBatch(List<String> chunk, String lang) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke(_functionName, body: {'texts': chunk, 'targetLanguage': lang})
          .timeout(const Duration(seconds: 45));
      return _readBatch(response.data, chunk.length);
    } on FunctionException catch (e) {
      // 400 «text and targetLanguage are required» = فەنکشنی کۆن
      if (e.status == 400 && '${e.details}'.contains('text and targetLanguage')) {
        _batchSupported = false;
        return null;
      }
      debugPrint('❌ translate batch ${e.status}: ${e.details}');
      // 429/502: ئەوانەی پێشتر هەبوون دەگەڕێنەوە
      return _readBatch(e.details, chunk.length);
    } catch (e) {
      debugPrint('❌ translate batch: $e');
      return null;
    }
  }

  /// 🛠️ ئەدمین: هەموو دەقەکان یەکجار وەردەگێڕێت و لە کاشی هاوبەشدا هەڵیان
  /// دەگرێت. لە نێوان داواکارییەکاندا [pause] چاوەڕێ دەکات (سنووری Gemini).
  /// ژمارەی دەقە وەرگێڕدراوەکان دەگەڕێنێتەوە.
  static Future<int> translateAllNow(
    List<String> texts,
    String lang, {
    void Function(int done, int total)? onProgress,
    Duration pause = const Duration(seconds: 7),
  }) async {
    final todo = {
      for (final t in texts)
        if (t.trim().isNotEmpty &&
            t.trim().length <= _batchItemMax &&
            !_looksUntranslatable(t.trim()) &&
            cachedOrNull(t, lang) == null)
          t.trim(),
    }.toList();
    var ok = 0;
    for (var i = 0; i < todo.length; i += _batchSize) {
      final chunk = todo.sublist(i, math.min(i + _batchSize, todo.length));
      final res = await _translateChunk(chunk, lang);
      ok += res.where((r) => r != null).length;
      onProgress?.call(math.min(i + _batchSize, todo.length), todo.length);
      if (i + _batchSize < todo.length) await Future<void>.delayed(pause);
    }
    return ok;
  }

  /// چەند دەقێک بە هاوکات وەردەگێڕێت (بۆ لیستەکان).
  static Future<List<String>> translateAll({
    required List<String> texts,
    required String targetLanguage,
  }) {
    return Future.wait([
      for (final t in texts) translate(text: t, targetLanguage: targetLanguage),
    ]);
  }

  /// ئەگەر لە کاشدا هەبێت یەکسەر دەیگەڕێنێتەوە (بۆ نیشاندانی بێ چاوەڕوانی).
  static String? cachedOrNull(String text, String targetLanguage) {
    if (targetLanguage == _sourceLanguage) return text;
    final k = '$targetLanguage\u0000${text.trim()}';
    return _cache[k] ?? _disk[k];
  }

  static void clearCache() {
    _cache.clear();
  }

  // ═══════════════════════════════════════════════════════════
  // 🌍 کاشی هاوبەش (Supabase: text_translations)
  // هەر دەقێک تەنها یەکجار بە Gemini وەردەگێڕدرێت و لێرە هەڵدەگیرێت؛
  // ئەپەکە بە یەک داواکاری تەنها ڕیزە نوێکان دادەگرێت.
  // ═══════════════════════════════════════════════════════════
  static const String _syncKeyPrefix = 'translation_sync_v1_';
  static const int _syncPageSize = 1000;
  static final Map<String, Future<int>> _syncing = {};

  /// وەرگێڕانە هاوبەشەکانی [lang] دادەگرێت (تەنها ئەوانەی دوای دوایین
  /// جار گۆڕاون). ژمارەی ڕیزە وەرگیراوەکان دەگەڕێنێتەوە.
  static Future<int> syncShared(String lang) {
    if (!_supportedTargets.contains(lang)) return SynchronousFuture(0);
    return _syncing[lang] ??= _syncShared(lang).whenComplete(() {
      _syncing.remove(lang);
    });
  }

  /// تەنها بۆ تاقیکردنەوە: لە جیاتی Edge Function
  @visibleForTesting
  static Future<String?> Function(String text, String lang)? fetchOverride;

  /// تەنها بۆ تاقیکردنەوە: لە جیاتی Supabase
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function(String lang, String? since, int limit)?
      fetchSharedPage;

  static Future<List<Map<String, dynamic>>> _fetchSharedPage(
      String lang, String? since, int limit) async {
    var q = Supabase.instance.client
        .from('text_translations')
        .select('source, translation, updated_at')
        .eq('lang', lang);
    if (since != null) q = q.gt('updated_at', since);
    final rows = await q.order('updated_at', ascending: true).limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<int> _syncShared(String lang) async {
    var received = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_syncKeyPrefix$lang';
      var since = prefs.getString(key);
      for (var page = 0; page < 20; page++) {
        final list = await (fetchSharedPage ?? _fetchSharedPage)(lang, since, _syncPageSize)
            .timeout(_timeout);
        for (final r in list) {
          final src = '${r['source'] ?? ''}'.trim();
          final tr = '${r['translation'] ?? ''}'.trim();
          if (src.isEmpty || tr.isEmpty) continue;
          final k = '$lang\u0000$src';
          _cache[k] = tr;
          _disk[k] = tr; // ڕاستکردنەوەی ئەدمین وەرگێڕانی کۆن دەگۆڕێت
        }
        received += list.length;
        if (list.isNotEmpty) since = '${list.last['updated_at']}';
        if (list.length < _syncPageSize) break;
      }
      while (_cache.length > _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      if (since != null) await prefs.setString(key, since);
      if (received > 0) _saveDisk();
    } catch (e) {
      // خشتەکە هێشتا دروست نەکراوە یان ئینتەرنێت نییە — هیچ کێشە نییە
      debugPrint('⚠️ translation sync ($lang): $e');
    }
    return received;
  }

  // ═══════════════════════════════════════════════════════════
  // Internals
  // ═══════════════════════════════════════════════════════════
  static Future<String?> _fetch(String text, String targetLanguage) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke(
            _functionName,
            body: {'text': text, 'targetLanguage': targetLanguage},
          )
          .timeout(_timeout);

      if (response.status != 200) return null;
      return _extract(response.data);
    } on TimeoutException {
      debugPrint('⏱️ TranslationService timeout ($targetLanguage)');
      return null;
    } catch (e) {
      debugPrint('❌ TranslationService error: $e');
      return null;
    }
  }

  static String? _extract(dynamic data) {
    dynamic d = data;
    if (d is String) {
      try {
        d = jsonDecode(d);
      } catch (_) {
        return d.trim().isEmpty ? null : d as String;
      }
    }
    if (d is Map) {
      final t = d['translation'] ?? d['translatedText'] ?? d['text'];
      if (t is String && t.trim().isNotEmpty) return t;
    }
    return null;
  }

  static void _put(String key, String value) {
    _cache[key] = value;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _disk[key] = value;
    _saveDisk();
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 کاشی هەمیشەیی — دوای داخستنی ئەپیش دەمێنێت (کەمتر داواکاری بۆ Gemini)
  // ═══════════════════════════════════════════════════════════
  static const String _diskKey = 'translation_cache_v1';
  static const int _maxDiskEntries = 8000;
  static final Map<String, String> _disk = {};
  static Timer? _saveTimer;

  /// لە دەستپێکی ئەپدا یەکجار بانگ بکە.
  static Future<void> loadDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskKey);
      if (raw == null) return;
      final m = jsonDecode(raw);
      if (m is Map) m.forEach((k, v) => _disk[k.toString()] = v.toString());
    } catch (e) {
      debugPrint('⚠️ translation cache load: $e');
    }
  }

  static void _saveDisk() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () async {
      while (_disk.length > _maxDiskEntries) {
        _disk.remove(_disk.keys.first);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_diskKey, jsonEncode(_disk));
      } catch (e) {
        debugPrint('⚠️ translation cache save: $e');
      }
    });
  }

  /// ژمارە، لینک، ئیمەیڵ یان تەنها هێما — پێویست بە وەرگێڕان ناکات.
  static final RegExp _noLetters = RegExp(r'^[\d\s\p{P}\p{S}٠-٩]+$', unicode: true);
  static final RegExp _urlOrEmail = RegExp(r'^(https?://\S+|\S+@\S+\.\S+)$');

  static bool _looksUntranslatable(String s) =>
      _noLetters.hasMatch(s) || _urlOrEmail.hasMatch(s);
}
