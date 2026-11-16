import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 🗄️ خزمەتگوزاری کاش
class CacheService {
  static const Duration defaultCacheDuration = Duration(minutes: 30);
  static final Map<String, _CacheEntry> _memoryCache = {};

  static Future<void> save(
      String key,
      dynamic data, {
        Duration? duration,
      }) async {
    final expiry = DateTime.now().add(duration ?? defaultCacheDuration);
    _memoryCache[key] = _CacheEntry(data: data, expiry: expiry);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cache_$key',
        jsonEncode({
          'data': data,
          'expiry': expiry.toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  static Future<dynamic> get(String key) async {
    final memEntry = _memoryCache[key];
    if (memEntry != null) {
      if (DateTime.now().isBefore(memEntry.expiry)) {
        return memEntry.data;
      } else {
        _memoryCache.remove(key);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_$key');
      if (cached != null) {
        final decoded = jsonDecode(cached);
        final expiry = DateTime.parse(decoded['expiry']);

        if (DateTime.now().isBefore(expiry)) {
          _memoryCache[key] = _CacheEntry(
            data: decoded['data'],
            expiry: expiry,
          );
          return decoded['data'];
        }
        // ماوەکەی بەسەرچووە: دەمێنێتەوە بۆ getStale (کاتی نەبوونی ئینتەرنێت)
      }
    } catch (_) {}

    return null;
  }

  /// دوایین داتای هەڵگیراو، تەنانەت ئەگەر ماوەکەی بەسەرچووبێت — بۆ کاتێک
  /// ئینتەرنێت نییە. null ئەگەر هەرگیز هەڵنەگیرابێت.
  static Future<dynamic> getStale(String key) async {
    final fresh = await get(key);
    if (fresh != null) return fresh;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_$key');
      if (cached == null) return null;
      return jsonDecode(cached)['data'];
    } catch (_) {
      return null;
    }
  }

  /// لیستی نەخشەکان لە سێرڤەر دەهێنێت و هەڵیدەگرێت؛ ئەگەر ئینتەرنێت نەبوو
  /// دوایین لیستی هەڵگیراو دەگەڕێنێتەوە (و تەنها ئەگەر هەرگیز نەبووبێت هەڵە دەدات).
  static Future<List<Map<String, dynamic>>> fetchList(
    String key,
    Future<List<Map<String, dynamic>>> Function() fetch, {
    Duration keepFor = const Duration(minutes: 30),
  }) async {
    try {
      final list = await fetch();
      if (list.isNotEmpty) await save(key, list, duration: keepFor);
      return list;
    } catch (e) {
      final stale = await getStale(key);
      if (stale is List) {
        return [for (final m in stale) Map<String, dynamic>.from(m as Map)];
      }
      rethrow;
    }
  }

  static Future<void> remove(String key) async {
    _memoryCache.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_$key');
    } catch (_) {}
  }

  static Future<void> clear() async {
    _memoryCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
      for (var key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  static Future<bool> has(String key) async {
    final data = await get(key);
    return data != null;
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry({required this.data, required this.expiry});
}