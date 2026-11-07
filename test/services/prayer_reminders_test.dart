// test/services/prayer_reminders_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/prayer/prayer_reminders.dart';

void main() {
  const s = PrayerReminderSettings();

  test('هەینی: ٣٠ خولەک پێش نیوەڕۆ', () {
    // پێنجشەممە ٥ی تشرینی دووەمی ٢٠٢٦ → هەینی ٦ی مانگ، نیوەڕۆ 11:47
    final r = PrayerReminders.upcoming(DateTime(2026, 11, 5, 9), s, days: 9);
    final friday = r.where((x) => x.title.contains('هەینی')).toList();
    expect(friday, hasLength(2)); // ٦ و ١٣ی مانگ
    expect(friday.first.at, DateTime(2026, 11, 6, 11, 17));
  });

  test('هەینی ناکرێت ئەگەر ناچالاک بێت یان کاتەکەی ڕۆیشتبێت', () {
    expect(
      PrayerReminders.upcoming(DateTime(2026, 11, 5), const PrayerReminderSettings(friday: false))
          .where((x) => x.title.contains('هەینی')),
      isEmpty,
    );
    final late = PrayerReminders.upcoming(DateTime(2026, 11, 6, 11, 30), s, days: 1);
    expect(late.where((x) => x.title.contains('هەینی')), isEmpty);
  });

  test('ڕەمەزان: پارشێو و بەربانگ', () {
    // ١ی ڕەمەزانی ١٤٤٨ ≈ ٨ی شوباتی ٢٠٢٧
    final day = DateTime(2027, 2, 20);
    expect(PrayerReminders.isRamadan(day), isTrue);
    final r = PrayerReminders.upcoming(DateTime(day.year, day.month, day.day), s, days: 1);
    expect(r.map((x) => x.title), containsAll(['🌙 پارشێو', '🌅 بەربانگ']));
  });

  test('دەرەوەی ڕەمەزان هیچ بیرخستنەوەیەکی ڕەمەزان نییە', () {
    expect(PrayerReminders.isRamadan(DateTime(2026, 11, 7)), isFalse);
    final r = PrayerReminders.upcoming(DateTime(2026, 11, 7), s);
    expect(r.where((x) => !x.title.contains('هەینی')), isEmpty);
  });

  test('ئایدییەکان جیاوازن', () {
    final r = PrayerReminders.upcoming(DateTime(2027, 2, 15), s);
    expect(r.map((x) => x.id).toSet().length, r.length);
  });
}
