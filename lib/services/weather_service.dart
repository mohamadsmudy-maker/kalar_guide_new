// lib/services/weather_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// 📦 Models
// ═══════════════════════════════════════════════════════════
class WeatherCurrent {
  final int temp;
  final int? feels;
  final int? humidity;
  final int? wind;
  final int? windDir;
  final int? gust;
  final int? pressure;
  final int? code;
  final int? cloud;
  final double? visibilityKm;
  final double? uv;
  final bool isDay;
  final String? textOverride;
  final String? emojiOverride;
  final DateTime updatedAt;
  final bool official;

  const WeatherCurrent({
    required this.temp,
    this.feels,
    this.humidity,
    this.wind,
    this.windDir,
    this.gust,
    this.pressure,
    this.code,
    this.cloud,
    this.visibilityKm,
    this.uv,
    this.isDay = true,
    this.textOverride,
    this.emojiOverride,
    required this.updatedAt,
    this.official = false,
  });
}

class WeatherHour {
  final DateTime time;
  final int temp;
  final int? code;
  final int? rainChance;
  final bool isDay;

  const WeatherHour({
    required this.time,
    required this.temp,
    this.code,
    this.rainChance,
    this.isDay = true,
  });
}

class WeatherDay {
  final DateTime date;
  final int max;
  final int min;
  final int? code;
  final int? rainChance;
  final double? rainMm;
  final double? uvMax;
  final int? windMax;
  final DateTime? sunrise;
  final DateTime? sunset;

  const WeatherDay({
    required this.date,
    required this.max,
    required this.min,
    this.code,
    this.rainChance,
    this.rainMm,
    this.uvMax,
    this.windMax,
    this.sunrise,
    this.sunset,
  });
}

class AirQuality {
  final int aqi;
  final double? pm25;
  final double? pm10;
  final double? dust;

  const AirQuality({required this.aqi, this.pm25, this.pm10, this.dust});
}

class WeatherSnapshot {
  final WeatherCurrent current;
  final List<WeatherHour> hours;
  final List<WeatherDay> days;
  final AirQuality? air;
  final DateTime fetchedAt;

  /// کاتی ناوخۆیی کەلار (Asia/Baghdad) لە کاتی هێنانی داتاکەدا.
  final DateTime nowLocal;

  const WeatherSnapshot({
    required this.current,
    required this.hours,
    required this.days,
    required this.air,
    required this.fetchedAt,
    required this.nowLocal,
  });

  /// کاتی ئێستای کەلار (بە حیسابکردنی ئەو کاتەی لە هێنانەوە تێپەڕیوە).
  DateTime get nowEstimate =>
      nowLocal.add(DateTime.now().difference(fetchedAt));

  /// ڕۆژی ئەمڕۆ بەپێی کاتی کەلار — نەک ڕۆژی ئامێرەکە.
  WeatherDay? get today {
    if (days.isEmpty) return null;
    final n = nowEstimate;
    for (final d in days) {
      if (isSameDay(d.date, n)) return d;
    }
    return days.first;
  }

  /// کاتژمێرەکانی داهاتوو لە ئێستاوە (ئەوانەی تێپەڕیون لادەبرێن).
  List<WeatherHour> get upcomingHours {
    final n = nowEstimate;
    final floor = DateTime(n.year, n.month, n.day, n.hour);
    return hours.where((h) => !h.time.isBefore(floor)).toList();
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Live {
  final WeatherCurrent current;
  final List<WeatherHour> hours;
  final List<WeatherDay> days;
  final DateTime nowLocal;
  const _Live(this.current, this.hours, this.days, this.nowLocal);
}

// ═══════════════════════════════════════════════════════════
// 🔧 Parsing Helpers
// ═══════════════════════════════════════════════════════════
int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.round();
  return num.tryParse('$v')?.round();
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

List<dynamic>? _listOf(Map<String, dynamic>? m, String key) {
  final v = m?[key];
  return v is List ? v : null;
}

dynamic _at(List<dynamic>? l, int i) =>
    (l == null || i < 0 || i >= l.length) ? null : l[i];

DateTime? _toTime(dynamic v) => v == null ? null : DateTime.tryParse('$v');

String? _clean(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

// ═══════════════════════════════════════════════════════════
// 🌤️ WeatherService (Singleton) — تاکە سەرچاوەی داتای کەشوهەوا
// ═══════════════════════════════════════════════════════════
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  static const double lat = 34.6189;
  static const double lon = 45.3156;
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _officialMaxAge = Duration(hours: 3);

  final ValueNotifier<WeatherSnapshot?> snapshot = ValueNotifier(null);
  final ValueNotifier<bool> refreshing = ValueNotifier(false);
  final ValueNotifier<bool> lastFailed = ValueNotifier(false);

  /// هەموو ئەو ValueNotifier ـانە پێکەوە — بۆ ListenableBuilder.
  late final Listenable listenable =
  Listenable.merge([snapshot, refreshing, lastFailed]);

  final http.Client _http = http.Client();
  Future<void>? _running;

  /// نوێکردنەوە. ئەگەر یەکێک لە کاردا بێت، هەمان Future دەگەڕێنێتەوە.
  Future<void> refresh() {
    final running = _running;
    if (running != null) return running;
    final f = _doRefresh();
    _running = f;
    f.whenComplete(() => _running = null);
    return f;
  }

  /// تەنها ئەگەر داتاکە لە [maxAge] کۆنتر بێت نوێ دەکاتەوە.
  Future<void> ensureFresh({Duration maxAge = const Duration(minutes: 5)}) {
    final s = snapshot.value;
    if (s != null && DateTime.now().difference(s.fetchedAt) <= maxAge) {
      return Future.value();
    }
    return refresh();
  }

  Future<void> _doRefresh() async {
    refreshing.value = true;
    try {
      final snap = await _load();
      if (snap != null) {
        snapshot.value = snap;
        lastFailed.value = false;
      } else {
        lastFailed.value = true;
      }
    } catch (e) {
      debugPrint('❌ Weather error: $e');
      lastFailed.value = true;
    } finally {
      refreshing.value = false;
    }
  }

  Future<WeatherSnapshot?> _load() async {
    // هەر سێکیان بە هاوکات دەنێردرێن
    final liveF = _fetchLive();
    final officialF = _fetchOfficial();
    final airF = _fetchAir();
    final live = await liveF;
    final official = await officialF;
    final air = await airF;

    if (live == null && official == null) return null;

    final WeatherCurrent current;
    if (official != null) {
      final l = live?.current;

      // "هەست پێکراو" بە هەمان جیاوازی پلەی فەرمی دەگوازرێتەوە
      int? feels = l?.feels;
      if (feels != null && l != null) feels += (official.temp - l.temp);

      current = WeatherCurrent(
        temp: official.temp,
        feels: feels,
        humidity: official.humidity ?? l?.humidity,
        wind: official.wind ?? l?.wind,
        windDir: l?.windDir,
        gust: l?.gust,
        pressure: l?.pressure,
        code: l?.code,
        cloud: l?.cloud,
        visibilityKm: l?.visibilityKm,
        uv: l?.uv,
        isDay: l?.isDay ?? true,
        textOverride: official.textOverride,
        emojiOverride: official.emojiOverride,
        updatedAt: official.updatedAt,
        official: true,
      );
    } else {
      current = live!.current;
    }

    return WeatherSnapshot(
      current: current,
      hours: live?.hours ?? const [],
      days: live?.days ?? const [],
      air: air,
      fetchedAt: DateTime.now(),
      nowLocal: live?.nowLocal ?? DateTime.now(),
    );
  }

  // ─── 🏛️ داتای فەرمی (Supabase) ───
  Future<WeatherCurrent?> _fetchOfficial() async {
    try {
      final res = await Supabase.instance.client
          .from('weather')
          .select()
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(_timeout);

      if (res == null) return null;

      final updatedAt = _toTime(res['updated_at'])?.toLocal();

      if (updatedAt != null &&
          DateTime.now().difference(updatedAt) > _officialMaxAge) {
        debugPrint('⚠️ داتای فەرمی کۆنە — Open-Meteo بەکاردێت');
        return null;
      }

      final temp = _toInt(res['temperature']);
      if (temp == null) return null;

      return WeatherCurrent(
        temp: temp,
        humidity: _toInt(res['humidity']),
        wind: _toInt(res['wind_speed']),
        textOverride: _clean(res['condition_text']),
        emojiOverride: _clean(res['icon_emoji']),
        updatedAt: updatedAt ?? DateTime.now(),
        official: true,
      );
    } catch (e) {
      // ئەگەر Supabase ئامادە نەکرابێت یان هەڵە ڕووبدات
      debugPrint('⚠️ Supabase weather error: $e');
      return null;
    }
  }

  // ─── 🌐 Open-Meteo ───
  Future<_Live?> _fetchLive() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
            '?latitude=$lat&longitude=$lon'
            '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
            'is_day,weather_code,cloud_cover,surface_pressure,wind_speed_10m,'
            'wind_direction_10m,wind_gusts_10m'
            '&hourly=temperature_2m,weather_code,precipitation_probability,'
            'is_day,visibility,uv_index'
            '&daily=weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max,sunrise,sunset,uv_index_max,'
            'precipitation_sum,wind_speed_10m_max'
            '&timezone=Asia%2FBaghdad'
            '&forecast_days=7',
      );

      final response = await _http.get(url).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final c = data['current'] as Map<String, dynamic>?;
      final h = data['hourly'] as Map<String, dynamic>?;
      final d = data['daily'] as Map<String, dynamic>?;
      if (c == null) return null;

      final temp = _toInt(c['temperature_2m']);
      if (temp == null) return null;

      final nowLocal = _toTime(c['time']) ?? DateTime.now();
      final hourFloor =
      DateTime(nowLocal.year, nowLocal.month, nowLocal.day, nowLocal.hour);

      // ─── کاتژمێرەکان ───
      final hTimes = _listOf(h, 'time') ?? const [];
      final hTemps = _listOf(h, 'temperature_2m');
      final hCodes = _listOf(h, 'weather_code');
      final hRain = _listOf(h, 'precipitation_probability');
      final hDay = _listOf(h, 'is_day');
      final hVis = _listOf(h, 'visibility');
      final hUv = _listOf(h, 'uv_index');

      int start = 0;
      for (int i = 0; i < hTimes.length; i++) {
        final t = _toTime(hTimes[i]);
        if (t != null && !t.isBefore(hourFloor)) {
          start = i;
          break;
        }
      }

      final hours = <WeatherHour>[];
      // 30 کاتژمێر هەڵدەگیرێت تا دوای چەند کاتژمێرێکیش 24 ـی داهاتوو بمێنێت
      for (int i = start; i < hTimes.length && hours.length < 30; i++) {
        final t = _toTime(hTimes[i]);
        final ht = _toInt(_at(hTemps, i));
        if (t == null || ht == null) continue;
        hours.add(WeatherHour(
          time: t,
          temp: ht,
          code: _toInt(_at(hCodes, i)),
          rainChance: _toInt(_at(hRain, i)),
          isDay: (_toInt(_at(hDay, i)) ?? 1) == 1,
        ));
      }

      final visM = _toDouble(_at(hVis, start));
      final uvNow = _toDouble(_at(hUv, start));

      final current = WeatherCurrent(
        temp: temp,
        feels: _toInt(c['apparent_temperature']),
        humidity: _toInt(c['relative_humidity_2m']),
        wind: _toInt(c['wind_speed_10m']),
        windDir: _toInt(c['wind_direction_10m']),
        gust: _toInt(c['wind_gusts_10m']),
        pressure: _toInt(c['surface_pressure']),
        code: _toInt(c['weather_code']),
        cloud: _toInt(c['cloud_cover']),
        visibilityKm: visM == null ? null : visM / 1000,
        uv: uvNow,
        isDay: (_toInt(c['is_day']) ?? 1) == 1,
        updatedAt: DateTime.now(),
      );

      // ─── ڕۆژەکان ───
      final times = _listOf(d, 'time') ?? const [];
      final codes = _listOf(d, 'weather_code');
      final maxes = _listOf(d, 'temperature_2m_max');
      final mins = _listOf(d, 'temperature_2m_min');
      final rains = _listOf(d, 'precipitation_probability_max');
      final sunr = _listOf(d, 'sunrise');
      final suns = _listOf(d, 'sunset');
      final uvs = _listOf(d, 'uv_index_max');
      final rainSum = _listOf(d, 'precipitation_sum');
      final winds = _listOf(d, 'wind_speed_10m_max');

      final days = <WeatherDay>[];
      for (int i = 0; i < times.length; i++) {
        final date = _toTime(times[i]);
        final mx = _toInt(_at(maxes, i));
        final mn = _toInt(_at(mins, i));
        if (date == null || mx == null || mn == null) continue;
        days.add(WeatherDay(
          date: date,
          max: mx,
          min: mn,
          code: _toInt(_at(codes, i)),
          rainChance: _toInt(_at(rains, i)),
          rainMm: _toDouble(_at(rainSum, i)),
          uvMax: _toDouble(_at(uvs, i)),
          windMax: _toInt(_at(winds, i)),
          sunrise: _toTime(_at(sunr, i)),
          sunset: _toTime(_at(suns, i)),
        ));
      }

      return _Live(current, hours, days, nowLocal);
    } catch (e) {
      debugPrint('⚠️ Open-Meteo error: $e');
      return null;
    }
  }

  // ─── 🌫️ کوالیتی هەوا ───
  Future<AirQuality?> _fetchAir() async {
    try {
      final url = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
            '?latitude=$lat&longitude=$lon'
            '&current=us_aqi,pm10,pm2_5,dust'
            '&timezone=Asia%2FBaghdad',
      );
      final response = await _http.get(url).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final c = data['current'] as Map<String, dynamic>?;
      final aqi = _toInt(c?['us_aqi']);
      if (aqi == null) return null;

      return AirQuality(
        aqi: aqi,
        pm25: _toDouble(c?['pm2_5']),
        pm10: _toDouble(c?['pm10']),
        dust: _toDouble(c?['dust']),
      );
    } catch (e) {
      debugPrint('⚠️ Air quality error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🌦️ WMO code → emoji + translation key
  // ═══════════════════════════════════════════════════════════
  static ({String emoji, String key}) conditionOf(
      int? code, int temp, bool isDay) {
    if (code == null) return (emoji: '🌤️', key: 'unknown');

    if (code == 0 || code == 1) {
      if (temp >= 40 && isDay) return (emoji: '🔥', key: 'hot');
      if (temp <= 2) return (emoji: '🥶', key: 'cold');
      if (code == 0) {
        return isDay
            ? (emoji: '☀️', key: 'clear')
            : (emoji: '🌙', key: 'clear_night');
      }
      return isDay
          ? (emoji: '🌤️', key: 'mostly_clear')
          : (emoji: '🌙', key: 'mostly_clear');
    }
    if (code == 2) return (emoji: isDay ? '⛅' : '☁️', key: 'partly');
    if (code == 3) return (emoji: '☁️', key: 'cloudy');
    if (code == 45 || code == 48) return (emoji: '🌫️', key: 'fog');
    if (code >= 51 && code <= 55) return (emoji: '🌦️', key: 'drizzle');
    if (code == 56 || code == 57 || code == 66 || code == 67) {
      return (emoji: '🌧️', key: 'freezing_rain');
    }
    if (code >= 61 && code <= 65) return (emoji: '🌧️', key: 'rain');
    if (code >= 71 && code <= 77) return (emoji: '❄️', key: 'snow');
    if (code >= 80 && code <= 82) return (emoji: '🌦️', key: 'showers');
    if (code == 85 || code == 86) return (emoji: '🌨️', key: 'snow_showers');
    if (code >= 95) return (emoji: '⛈️', key: 'thunder');
    return (emoji: '🌤️', key: 'unknown');
  }
}