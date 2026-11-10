// lib/services/local_favorites.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ❤️ دڵخوازی ڤیدیۆ و وێنەی گەلەری — لەسەر مۆبایل هەڵدەگیرێت
/// (پێویستی بە چوونەژوورەوە یان خشتەی Supabase نییە).
///
/// هەر بڕگەیەک Map ێکە کە کلیلی `key` ی هەیە (بۆ نموونە لینکی ڤیدیۆ یان وێنە).
class LocalFavorites {
  LocalFavorites._();

  static const String videos = 'videos';
  static const String gallery = 'gallery';

  static const _prefix = 'local_fav_';

  /// هەر گۆڕانێک → ژمارەکە زیاد دەبێت، ویجێتەکان گوێی لێ دەگرن
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  static Future<void>? _loading;

  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    for (final kind in [videos, gallery]) {
      final raw = p.getString('$_prefix$kind');
      var list = <Map<String, dynamic>>[];
      if (raw != null) {
        try {
          list = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      }
      _cache[kind] = list;
    }
    changes.value++;
  }

  static List<Map<String, dynamic>> items(String kind) => List.unmodifiable(_cache[kind] ?? const []);

  static bool contains(String kind, String key) => (_cache[kind] ?? const []).any((e) => e['key'] == key);

  /// زیاد یان لابردن؛ true = ئێستا دڵخوازە
  static Future<bool> toggle(String kind, Map<String, dynamic> item) async {
    await ensureLoaded();
    final key = '${item['key'] ?? ''}';
    if (key.isEmpty) return false;
    final list = _cache.putIfAbsent(kind, () => []);
    final exists = list.any((e) => e['key'] == key);
    if (exists) {
      list.removeWhere((e) => e['key'] == key);
    } else {
      list.insert(0, {...item, 'saved_at': DateTime.now().toIso8601String()});
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('$_prefix$kind', jsonEncode(list));
    changes.value++;
    return !exists;
  }

  static Future<void> remove(String kind, String key) async {
    await ensureLoaded();
    if (!contains(kind, key)) return;
    await toggle(kind, {'key': key});
  }
}
