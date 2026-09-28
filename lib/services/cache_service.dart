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
        } else {
          await prefs.remove('cache_$key');
        }
      }
    } catch (_) {}

    return null;
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