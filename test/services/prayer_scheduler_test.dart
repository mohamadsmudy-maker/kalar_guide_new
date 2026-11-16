import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/prayer/prayer_scheduler.dart';

Map<String, String> fixed(DateTime d) => {
      'fajr': '04:30',
      'sunrise': '06:00',
      'dhuhr': '12:10',
      'asr': '15:20',
      'maghrib': '17:40',
      'isha': '19:00',
    };

void main() {
  test('٧ ڕۆژ × ٥ بانگ؛ خۆرهەڵاتن بانگ نییە', () {
    final plan = PrayerScheduler.plan(DateTime(2026, 11, 13, 0, 1), timesForDay: fixed);
    expect(plan.length, 35);
    expect(plan.where((p) => p.prayerId == 'sunrise'), isEmpty);
    expect(plan.first.prayerId, 'fajr');
    expect(plan.last.at, DateTime(2026, 11, 19, 19, 0));
  });

  test('ئەوانەی تێپەڕیون دەرەوە دەمێنن', () {
    final plan = PrayerScheduler.plan(DateTime(2026, 11, 13, 13, 0), timesForDay: fixed);
    // ئەمڕۆ تەنها عەسر، مەغریب، عیشا ماون
    expect(plan.take(3).map((p) => p.prayerId), ['asr', 'maghrib', 'isha']);
    expect(plan.length, 3 + 6 * 5);
  });

  test('ناسنامەکان جێگیر و جیاوازن (بۆ سڕینەوە و نوێکردنەوە)', () {
    final now = DateTime(2026, 11, 13, 0, 1);
    final a = PrayerScheduler.plan(now, timesForDay: fixed);
    final b = PrayerScheduler.plan(now, timesForDay: fixed);
    expect(a.map((p) => p.id), b.map((p) => p.id));
    expect(a.map((p) => p.id).toSet().length, a.length);
    expect(a.every((p) => p.id >= PrayerScheduler.baseId), isTrue);
  });

  test('هەر ڕۆژێک کاتی ڕاستی خۆی وەردەگرێت (نەک هەمان کات دووبارە)', () {
    final plan = PrayerScheduler.plan(
      DateTime(2026, 11, 13, 0, 1),
      timesForDay: (d) => {
        ...fixed(d),
        'fajr': '04:${(30 + d.day).toString().padLeft(2, '0')}',
      },
    );
    final fajr = plan.where((p) => p.prayerId == 'fajr').toList();
    expect(fajr[0].at, DateTime(2026, 11, 13, 4, 43));
    expect(fajr[1].at, DateTime(2026, 11, 14, 4, 44));
  });

  test('کاتی هەڵە (نەخوێنراو) نادرێتە ڕێکخستن', () {
    final plan = PrayerScheduler.plan(
      DateTime(2026, 11, 13, 0, 1),
      dayCount: 1,
      timesForDay: (d) => {...fixed(d), 'asr': 'xx', 'isha': ''},
    );
    expect(plan.map((p) => p.prayerId), ['fajr', 'dhuhr', 'maghrib']);
  });

  test('بە کاتی ڕاستەقینەی کەلار: ٧ ڕۆژ ٣٥ بانگ و هەمووی لە ئایندەدا', () {
    final now = DateTime(2026, 11, 13, 0, 1);
    final plan = PrayerScheduler.plan(now);
    expect(plan.length, 35);
    expect(plan.every((p) => p.at.isAfter(now)), isTrue);
    final sorted = [...plan]..sort((a, b) => a.at.compareTo(b.at));
    expect(plan.map((p) => p.id), sorted.map((p) => p.id));
  });
}
