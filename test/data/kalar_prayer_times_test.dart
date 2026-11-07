// test/data/kalar_prayer_times_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/data/kalar_prayer_times.dart';
import 'package:kalar_guide_new/services/prayer/kalar_prayer_times.dart';

int _min(String hm) {
  final p = hm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

DateTime _date(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
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
          expect(diff, lessThanOrEqualTo(id == 'fajr' ? 2 : 1),
              reason: '${e.key} $id: هەژمار ${calc[id]} ، فەرمی ${e.value[id]}');
        }
      }
    });

    test('ڕۆژی نەبوو لە خشتە (١٠ی تشرینی دووەم) هەژمار دەکرێت', () {
      final day = KalarPrayerTimes.forDay(DateTime(2026, 11, 10));
      expect(day.isOfficial, isFalse);
      final before = kalarOfficialPrayerTimes['09-11-2026']!;
      final after = kalarOfficialPrayerTimes['11-11-2026']!;
      for (final id in KalarPrayerTimes.ids) {
        final m = _min(day.times[id]!);
        expect(m, inInclusiveRange(_min(before[id]!) - 2, _min(after[id]!) + 2), reason: id);
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
}
