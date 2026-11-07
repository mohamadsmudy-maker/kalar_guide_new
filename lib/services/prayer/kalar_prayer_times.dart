// lib/services/prayer/kalar_prayer_times.dart
import 'package:adhan/adhan.dart';

import '../../data/kalar_prayer_times.dart';

/// کاتەکانی نوێژی یەک ڕۆژ.
class PrayerDay {
  const PrayerDay(this.times, {required this.isOfficial});

  /// `fajr`, `sunrise`, `dhuhr`, `asr`, `maghrib`, `isha` → `HH:mm` (٢٤ کاتژمێر)
  final Map<String, String> times;

  /// true = لە خشتەی فەرمی ئامۆژگارییەوە هاتووە، false = هەژمارکراوە
  final bool isOfficial;
}

/// تاکە سەرچاوەی کاتی نوێژ بۆ هەموو ئەپەکە.
///
/// ١. ئەگەر ڕۆژەکە لە [kalarOfficialPrayerTimes] دا هەبێت، هەمان کاتی فەرمی.
/// ٢. ئەگەرنا هەژمار دەکرێت بە ڕێکخستنێک کە لەگەڵ خشتەی ئامۆژگاری
///    بەراورد کراوە (تشرینی دووەم ٢٠٢٦، ٢٩ ڕۆژ): خەوتنان ڕێک، ئەوانی تر
///    ±١ خولەک، بەیانی ±٢ خولەک.
class KalarPrayerTimes {
  KalarPrayerTimes._();

  static const double kalarLat = 34.6178;
  static const double kalarLng = 45.3325;

  /// کاتی عێراق (UTC+3، بێ گۆڕینی هاوینە)
  static const Duration _utcOffset = Duration(hours: 3);

  static const List<String> ids = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

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

  static String dateKey(DateTime d) =>
      '${_two(d.day)}-${_two(d.month)}-${d.year}';

  static PrayerDay forDay(
    DateTime day, {
    double lat = kalarLat,
    double lng = kalarLng,
  }) {
    final official = kalarOfficialPrayerTimes[dateKey(day)];
    if (official != null) return PrayerDay(official, isOfficial: true);
    return PrayerDay(calculate(day, lat: lat, lng: lng), isOfficial: false);
  }

  /// هەژمار بەبێ سەیرکردنی خشتەی فەرمی (بۆ تێست و شوێنی تر).
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

  /// `HH:mm` → `h:mm پ.ن` / `h:mm د.ن` (سیستەمی ١٢ سەعاتی)
  static String format12(String hm) {
    final p = hm.split(':');
    if (p.length < 2) return hm;
    final h24 = int.tryParse(p[0]);
    final m = p[1].split(' ').first;
    if (h24 == null) return hm;
    final suffix = h24 < 12 ? 'پ.ن' : 'د.ن';
    final h = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h:$m $suffix';
  }

  static String _hm(DateTime d) {
    final l = d.toUtc().add(_utcOffset);
    return '${_two(l.hour)}:${_two(l.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
