// lib/services/prayer/prayer_times_repository.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'kalar_prayer_times.dart';

/// کاتە فەرمییەکانی ئەدمین لە Supabase (`prayer_times_official`).
///
/// کاش لە مۆبایل هەڵدەگیرێت، بۆیە بێ ئینتەرنێتیش کار دەکات.
class PrayerTimesRepository {
  PrayerTimesRepository._();

  static const String table = 'prayer_times_official';
  static const String _cacheKey = 'prayer_times_official_v1';

  static bool _cacheLoaded = false;

  /// کاشی ناوخۆ بار دەکات (خێرا، بێ ئینتەرنێت).
  static Future<void> loadCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      KalarPrayerTimes.setAdminOverrides(_decode(jsonDecode(raw)));
    } catch (e) {
      debugPrint('⚠️ prayer cache: $e');
    }
  }

  /// داتای نوێ لە سێرڤەر دەهێنێت. true = شتێک گۆڕا.
  static Future<bool> refresh() async {
    try {
      final res = await Supabase.instance.client
          .from(table)
          .select('day_month, fajr, sunrise, dhuhr, asr, maghrib, isha')
          .timeout(const Duration(seconds: 8));
      final rows = {
        for (final r in (res as List).cast<Map<String, dynamic>>())
          r['day_month'].toString(): {
            for (final id in KalarPrayerTimes.ids) id: r[id].toString(),
          },
      };
      final changed = jsonEncode(rows) != jsonEncode(KalarPrayerTimes.adminOverrides);
      KalarPrayerTimes.setAdminOverrides(rows);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(rows));
      return changed;
    } catch (e) {
      debugPrint('⚠️ prayer refresh: $e');
      return false;
    }
  }

  /// ئەدمین: پاشەکەوتکردنی چەند ڕۆژێک.
  static Future<void> upsert(Map<String, Map<String, String>> days) async {
    await Supabase.instance.client.from(table).upsert([
      for (final e in days.entries) {'day_month': e.key, ...e.value},
    ]);
    await refresh();
  }

  /// ئەدمین: سڕینەوە → دەگەڕێتەوە بۆ خشتەی ناو ئەپ یان هەژمار.
  static Future<void> delete(String dayMonth) async {
    await Supabase.instance.client.from(table).delete().eq('day_month', dayMonth);
    await refresh();
  }

  static Map<String, Map<String, String>> _decode(dynamic json) {
    final out = <String, Map<String, String>>{};
    if (json is Map) {
      json.forEach((k, v) {
        if (v is Map) out[k.toString()] = v.map((a, b) => MapEntry(a.toString(), b.toString()));
      });
    }
    return out;
  }
}
