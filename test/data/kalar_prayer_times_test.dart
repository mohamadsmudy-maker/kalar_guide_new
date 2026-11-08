// test/data/kalar_prayer_times_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/data/kalar_prayer_times.dart';
import 'package:kalar_guide_new/services/prayer/kalar_prayer_times.dart';

int _min(String hm) {
  final p = hm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// کلیلی خشتە `dd-MM` ـە؛ ساڵی سەرچاوەکە ٢٠٢٦ ـە
DateTime _date(String key) {
  final p = key.split('-');
  return DateTime(2026, int.parse(p[1]), int.parse(p[0]));
}

void main() {
  group('خشتەی فەرمی کەلار', () {
    test('هەموو ڕیزێک ٦ کاتی هەیە و بە ڕیزن', () {
      for (final e in kalarOfficialPrayerTimes.entries) {
        final t = e.value;
        expect(t.keys.toSet(), KalarPrayerTimes.ids.toSet(), reason: e.key);
        final m = KalarPrayerTimes.ids.map((id) => _min(t[id]!)).toList();
        for (var i = 1; i < m.length; i++) {
          expect(m[i], greaterThan(m[i - 1]), reason: '${e.key}: ${KalarPrayerTimes.ids[i]}');
        }
      }
    });

    test('ڕۆژی دواتر لە هەر کاتێک زیاتر لە ٣ خولەک ناگۆڕێت (هەڵەی نووسین)', () {
      final keys = kalarOfficialPrayerTimes.keys.toList()
        ..sort((a, b) => _date(a).compareTo(_date(b)));
      for (var i = 1; i < keys.length; i++) {
        final gap = _date(keys[i]).difference(_date(keys[i - 1])).inDays;
        for (final id in KalarPrayerTimes.ids) {
          final d = (_min(kalarOfficialPrayerTimes[keys[i]]![id]!) -
                  _min(kalarOfficialPrayerTimes[keys[i - 1]]![id]!))
              .abs();
          expect(d, lessThanOrEqualTo(2 * gap), reason: '${keys[i]} $id');
        }
      }
    });

    test('٧ی تشرینی دووەم — وەک amozhgary.tv', () {
      final day = KalarPrayerTimes.forDay(DateTime(2026, 11, 7));
      expect(day.isOfficial, isTrue);
      expect(day.times, {
        'fajr': '05:05', 'sunrise': '06:30', 'dhuhr': '11:47',
        'asr': '14:37', 'maghrib': '17:04', 'isha': '18:15',
      });
    });
  });

  group('هەژماری خۆکاری', () {
    test('لەگەڵ هەموو ڕۆژە فەرمییەکان دەگونجێت', () {
      for (final e in kalarOfficialPrayerTimes.entries) {
        final calc = KalarPrayerTimes.calculate(_date(e.key));
        for (final id in KalarPrayerTimes.ids) {
          final diff = (_min(calc[id]!) - _min(e.value[id]!)).abs();
          // بەیانی و خۆرهەڵاتن لە زستاندا تا ٢ خولەک جیاوازن
          expect(diff, lessThanOrEqualTo(id == 'fajr' || id == 'sunrise' ? 2 : 1),
              reason: '${e.key} $id: هەژمار ${calc[id]} ، فەرمی ${e.value[id]}');
        }
      }
    });

    test('ڕۆژێک کە لە خشتەدا نییە (١٥ی کانوونی دووەم) هەژمار دەکرێت', () {
      final day = KalarPrayerTimes.forDay(DateTime(2027, 1, 15));
      expect(day.isOfficial, isFalse);
      final m = KalarPrayerTimes.ids.map((id) => _min(day.times[id]!)).toList();
      for (var i = 1; i < m.length; i++) {
        expect(m[i], greaterThan(m[i - 1]));
      }
      // نزیک لە کۆتایی کانوونی یەکەم (خشتەی فەرمی)
      final dec31 = kalarOfficialPrayerTimes['31-12']!;
      for (final id in KalarPrayerTimes.ids) {
        expect((_min(day.times[id]!) - _min(dec31[id]!)).abs(), lessThanOrEqualTo(15), reason: id);
      }
    });

    test('تشرینی دووەم و کانوونی یەکەم تەواون', () {
      for (var d = 1; d <= 30; d++) {
        expect(KalarPrayerTimes.forDay(DateTime(2026, 11, d)).isOfficial, isTrue, reason: '$d-11');
      }
      for (var d = 1; d <= 31; d++) {
        expect(KalarPrayerTimes.forDay(DateTime(2026, 12, d)).isOfficial, isTrue, reason: '$d-12');
      }
      expect(KalarPrayerTimes.forDay(DateTime(2026, 12, 31)).times['fajr'], '05:41');
      expect(KalarPrayerTimes.forDay(DateTime(2026, 11, 10)).times['maghrib'], '17:01');
    });

    test('خشتەکە بۆ ساڵانی تریش کار دەکات و جیاوازی ساڵانە < ٢ خولەکە', () {
      expect(KalarPrayerTimes.forDay(DateTime(2027, 11, 7)).times['maghrib'], '17:04');
      for (final day in [DateTime(2026, 1, 15), DateTime(2026, 6, 21), DateTime(2026, 11, 7)]) {
        final a = KalarPrayerTimes.calculate(day);
        for (final y in [2027, 2028, 2030]) {
          final b = KalarPrayerTimes.calculate(DateTime(y, day.month, day.day));
          for (final id in KalarPrayerTimes.ids) {
            expect((_min(a[id]!) - _min(b[id]!)).abs(), lessThanOrEqualTo(1), reason: '$y $day $id');
          }
        }
      }
    });

    test('مانگێکی تر (حوزەیران) کاتی ڕێکی هەیە', () {
      final t = KalarPrayerTimes.forDay(DateTime(2027, 6, 21)).times;
      final m = KalarPrayerTimes.ids.map((id) => _min(t[id]!)).toList();
      for (var i = 1; i < m.length; i++) {
        expect(m[i], greaterThan(m[i - 1]));
      }
      expect(_min(t['maghrib']!), inInclusiveRange(19 * 60, 19 * 60 + 30));
    });
  });

  group('format12', () {
    test('پێش و دوای نیوەڕۆ', () {
      expect(KalarPrayerTimes.format12('05:05'), '5:05 پ.ن');
      expect(KalarPrayerTimes.format12('11:47'), '11:47 پ.ن');
      expect(KalarPrayerTimes.format12('12:10'), '12:10 د.ن');
      expect(KalarPrayerTimes.format12('17:04'), '5:04 د.ن');
      expect(KalarPrayerTimes.format12('00:30'), '12:30 پ.ن');
    });
    test('دەقی هەڵە وەک خۆی دەگەڕێتەوە', () {
      expect(KalarPrayerTimes.format12('abc'), 'abc');
    });
  });

  group('گۆڕانکاری ئەدمین', () {
    tearDown(() => KalarPrayerTimes.setAdminOverrides(const {}));

    test('پێش خشتەی ناو ئەپ دەکەوێت', () {
      KalarPrayerTimes.setAdminOverrides({
        '07-11': {'fajr': '05:00', 'sunrise': '06:30', 'dhuhr': '11:47',
                  'asr': '14:37', 'maghrib': '17:05', 'isha': '18:15'},
      });
      final d = KalarPrayerTimes.forDay(DateTime(2026, 11, 7));
      expect(d.source, PrayerSource.admin);
      expect(d.times['maghrib'], '17:05');
      expect(KalarPrayerTimes.forDay(DateTime(2026, 11, 8)).source, PrayerSource.official);
    });

    test('ڕۆژی هەڵە (ڕیزبەندی تێکچوو) پشتگوێ دەخرێت', () {
      KalarPrayerTimes.setAdminOverrides({
        '07-11': {'fajr': '05:00', 'sunrise': '04:00', 'dhuhr': '11:47',
                  'asr': '14:37', 'maghrib': '17:05', 'isha': '18:15'},
      });
      expect(KalarPrayerTimes.forDay(DateTime(2026, 11, 7)).source, PrayerSource.official);
    });
  });

  group('normalize (پەیستکردن لە ئامۆژگاری)', () {
    test('کاتی دوای نیوەڕۆ بێ پ.ن/د.ن', () {
      expect(KalarPrayerTimes.normalize('fajr', '04:59'), '04:59');
      expect(KalarPrayerTimes.normalize('dhuhr', '11:47'), '11:47');
      expect(KalarPrayerTimes.normalize('dhuhr', '12:50'), '12:50');
      expect(KalarPrayerTimes.normalize('dhuhr', '1:02'), '13:02');
      expect(KalarPrayerTimes.normalize('asr', '02:42'), '14:42');
      expect(KalarPrayerTimes.normalize('maghrib', '05:09'), '17:09');
      expect(KalarPrayerTimes.normalize('isha', '06:20'), '18:20');
      expect(KalarPrayerTimes.normalize('isha', '18:20'), '18:20');
    });
    test('ژمارەی کوردی و هەڵە', () {
      expect(KalarPrayerTimes.normalize('asr', '٠٢:٤٢'), '14:42');
      expect(KalarPrayerTimes.normalize('asr', '2:7'), isNull);
      expect(KalarPrayerTimes.normalize('asr', 'x'), isNull);
    });
  });

  test('format12 بە ژمارەی کوردی', () {
    expect(KalarPrayerTimes.format12('17:04', kurdishDigits: true), '٥:٠٤ د.ن');
  });
}
