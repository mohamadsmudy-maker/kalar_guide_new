// lib/services/prayer/kalar_prayer_times.dart
import 'package:adhan/adhan.dart';

import '../../data/kalar_prayer_times.dart';

/// سەرچاوەی کاتەکانی ڕۆژێک
enum PrayerSource {
  /// ئەدمین لە پانێڵەکەوە داینا (Supabase)
  admin,

  /// خشتەی فەرمی ناو ئەپ (amozhgary.tv)
  official,

  /// هەژمارکراو
  calculated,
}

/// کاتەکانی نوێژی یەک ڕۆژ.
class PrayerDay {
  const PrayerDay(this.times, {required this.source});

  /// `fajr`, `sunrise`, `dhuhr`, `asr`, `maghrib`, `isha` → `HH:mm` (٢٤ کاتژمێر)
  final Map<String, String> times;
  final PrayerSource source;

  /// true = کاتی فەرمییە (ئەدمین یان خشتەی ئامۆژگاری)
  bool get isOfficial => source != PrayerSource.calculated;
}

/// تاکە سەرچاوەی کاتی نوێژ بۆ هەموو ئەپەکە.
///
/// ڕیزبەندی: ١) گۆڕانکاری ئەدمین (Supabase) ٢) خشتەی فەرمی ناو ئەپ
/// ٣) هەژمار — بە ڕێکخستنێک کە لەگەڵ خشتەی ئامۆژگاری بەراورد کراوە
/// (تشرینی دووەم: خەوتنان ڕێک، ئەوانی تر ±١، بەیانی ±٢ خولەک).
///
/// کلیلی خشتەکان `dd-MM` ـە (بێ ساڵ)، چونکە کاتەکان ساڵانە دووبارە دەبنەوە.
class KalarPrayerTimes {
  KalarPrayerTimes._();

  static const double kalarLat = 34.6178;
  static const double kalarLng = 45.3325;

  /// کاتی عێراق (UTC+3، بێ گۆڕینی هاوینە)
  static const Duration _utcOffset = Duration(hours: 3);

  static const List<String> ids = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

  static final RegExp _hmPattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// گۆڕانکارییەکانی ئەدمین — لە [PrayerTimesRepository] ەوە پڕ دەکرێتەوە
  static Map<String, Map<String, String>> _admin = const {};

  static void setAdminOverrides(Map<String, Map<String, String>> rows) {
    _admin = {
      for (final e in rows.entries)
        if (isValidDay(e.value)) e.key: Map.unmodifiable(e.value),
    };
  }

  static Map<String, Map<String, String>> get adminOverrides => _admin;

  static CalculationParameters get _params =>
      CalculationMethod.muslim_world_league.getParameters()
        ..madhab = Madhab.shafi
        ..fajrAngle = 16
        ..ishaAngle = 15.5
        ..adjustments = PrayerAdjustments(
          fajr: -2,
          sunrise: 6,
          dhuhr: 4,
          asr: 0,
          maghrib: 4,
          isha: 2,
        );

  /// `dd-MM`
  static String dayKey(DateTime d) => '${_two(d.day)}-${_two(d.month)}';

  /// `dd-MM-yyyy`
  static String dateKey(DateTime d) => '${dayKey(d)}-${d.year}';

  static bool isValidTime(String? hm) => hm != null && _hmPattern.hasMatch(hm);

  /// هەر ٦ کاتەکە هەن، دروستن و بە ڕیزن
  static bool isValidDay(Map<String, String>? t) {
    if (t == null) return false;
    var prev = -1;
    for (final id in ids) {
      final v = t[id];
      if (!isValidTime(v)) return false;
      final m = toMinutes(v!);
      if (m <= prev) return false;
      prev = m;
    }
    return true;
  }

  static PrayerDay forDay(
    DateTime day, {
    double lat = kalarLat,
    double lng = kalarLng,
  }) {
    final key = dayKey(day);
    final admin = _admin[key];
    if (admin != null) return PrayerDay(admin, source: PrayerSource.admin);
    final official = kalarOfficialPrayerTimes[key];
    if (official != null) return PrayerDay(official, source: PrayerSource.official);
    return PrayerDay(calculate(day, lat: lat, lng: lng), source: PrayerSource.calculated);
  }

  /// هەژمار بەبێ سەیرکردنی خشتەکان.
  static Map<String, String> calculate(
    DateTime day, {
    double lat = kalarLat,
    double lng = kalarLng,
  }) {
    final t = PrayerTimes(
      Coordinates(lat, lng),
      DateComponents(day.year, day.month, day.day),
      _params,
    );
    return {
      'fajr': _hm(t.fajr),
      'sunrise': _hm(t.sunrise),
      'dhuhr': _hm(t.dhuhr),
      'asr': _hm(t.asr),
      'maghrib': _hm(t.maghrib),
      'isha': _hm(t.isha),
    };
  }

  /// کاتی [id] لە ڕۆژی [day] وەک DateTime (کاتی ناوخۆیی).
  static DateTime at(DateTime day, String id) {
    final m = toMinutes(forDay(day).times[id]!);
    return DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
  }

  static int toMinutes(String hm) {
    final p = hm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1].substring(0, 2));
  }

  /// کاتێک لە شێوەی ئامۆژگاری (١٢ سەعاتی بێ پ.ن/د.ن) دەگۆڕێت بۆ `HH:mm`.
  /// بەیانی و خۆرهەڵاتن هەمیشە پێش نیوەڕۆن؛ عەسر، ئێوارە و خەوتنان دوای
  /// نیوەڕۆن؛ نیوەڕۆ لە نێوان ١١ و ١ دایە.
  static String? normalize(String id, String raw) {
    final m = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(toLatinDigits(raw.trim()));
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    switch (id) {
      case 'fajr':
      case 'sunrise':
        if (h == 12) h = 0;
      case 'dhuhr':
        if (h < 9) h += 12;
      default:
        if (h < 12) h += 12;
    }
    final out = '${_two(h)}:${_two(min)}';
    return isValidTime(out) ? out : null;
  }

  /// `HH:mm` → `h:mm پ.ن` / `h:mm د.ن` (سیستەمی ١٢ سەعاتی)
  static String format12(String hm, {bool kurdishDigits = false}) {
    final p = hm.split(':');
    if (p.length < 2) return hm;
    final h24 = int.tryParse(p[0]);
    final m = p[1].split(' ').first;
    if (h24 == null) return hm;
    final suffix = h24 < 12 ? 'پ.ن' : 'د.ن';
    final h = h24 % 12 == 0 ? 12 : h24 % 12;
    final text = '$h:$m';
    return '${kurdishDigits ? toKurdishDigits(text) : text} $suffix';
  }

  static String toKurdishDigits(String s) {
    const ku = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final c in s.codeUnits) {
      b.write(c >= 48 && c <= 57 ? ku[c - 48] : String.fromCharCode(c));
    }
    return b.toString();
  }

  static String toLatinDigits(String s) {
    const ku = '٠١٢٣٤٥٦٧٨٩';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = ku.indexOf(ch);
      final j = fa.indexOf(ch);
      b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : ch));
    }
    return b.toString();
  }

  static String _hm(DateTime d) {
    final l = d.toUtc().add(_utcOffset);
    return '${_two(l.hour)}:${_two(l.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
