// lib/services/prayer/prayer_reminders.dart
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kalar_prayer_times.dart';

/// ڕێکخستنەکانی بیرخستنەوە (SharedPreferences).
class PrayerReminderSettings {
  const PrayerReminderSettings({
    this.friday = true,
    this.fridayMinutes = 30,
    this.ramadan = true,
    this.ramadanMinutes = 30,
    this.kurdishDigits = false,
  });

  final bool friday;
  final int fridayMinutes;
  final bool ramadan;
  final int ramadanMinutes;
  final bool kurdishDigits;

  static const kFriday = 'prayer_friday_reminder';
  static const kFridayMinutes = 'prayer_friday_minutes';
  static const kRamadan = 'prayer_ramadan_reminder';
  static const kRamadanMinutes = 'prayer_ramadan_minutes';
  static const kKurdishDigits = 'prayer_kurdish_digits';

  static Future<PrayerReminderSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return PrayerReminderSettings(
      friday: p.getBool(kFriday) ?? true,
      fridayMinutes: p.getInt(kFridayMinutes) ?? 30,
      ramadan: p.getBool(kRamadan) ?? true,
      ramadanMinutes: p.getInt(kRamadanMinutes) ?? 30,
      kurdishDigits: p.getBool(kKurdishDigits) ?? false,
    );
  }
}

/// یەک بیرخستنەوەی یەکجاری.
class PrayerReminder {
  const PrayerReminder(this.id, this.at, this.title, this.body);
  final int id;
  final DateTime at;
  final String title;
  final String body;

  @override
  String toString() => 'PrayerReminder($id, $at, $title)';
}

/// ڕەمەزان و بیرخستنەوەی هەینی — لۆژیکی پاک، بێ پێوەندی بە پلاتفۆرمەوە
/// (تێستکراوە لە test/services/prayer_reminders_test.dart).
class PrayerReminders {
  PrayerReminders._();

  static const int fridayBaseId = 200000;
  static const int suhoorBaseId = 210000;
  static const int iftarBaseId = 220000;

  /// ڕۆژی ڕەمەزانە؟ (ساڵنامەی ئوم القورا؛ لەوانەیە ڕۆژێک جیاواز بێت
  /// لەگەڵ ڕاگەیاندنی فەرمی)
  static bool isRamadan(DateTime day) => HijriCalendar.fromDate(day).hMonth == 9;

  /// بیرخستنەوەکانی [days] ڕۆژی داهاتوو، لە [now] ـەوە.
  static List<PrayerReminder> upcoming(
    DateTime now,
    PrayerReminderSettings s, {
    int days = 8,
  }) {
    final out = <PrayerReminder>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day + i);

      if (s.friday && day.weekday == DateTime.friday) {
        final at = KalarPrayerTimes.at(day, 'dhuhr').subtract(Duration(minutes: s.fridayMinutes));
        if (at.isAfter(now)) {
          out.add(PrayerReminder(
            fridayBaseId + i,
            at,
            '🕌 نوێژی هەینی',
            '${s.fridayMinutes} خولەکی ماوە بۆ بانگی نیوەڕۆی هەینی. خۆت ئامادە بکە.',
          ));
        }
      }

      if (s.ramadan && isRamadan(day)) {
        final suhoor = KalarPrayerTimes.at(day, 'fajr').subtract(Duration(minutes: s.ramadanMinutes));
        if (suhoor.isAfter(now)) {
          out.add(PrayerReminder(
            suhoorBaseId + i,
            suhoor,
            '🌙 پارشێو',
            '${s.ramadanMinutes} خولەکی ماوە بۆ بانگی بەیانی.',
          ));
        }
        final iftar = KalarPrayerTimes.at(day, 'maghrib').subtract(Duration(minutes: s.ramadanMinutes));
        if (iftar.isAfter(now)) {
          out.add(PrayerReminder(
            iftarBaseId + i,
            iftar,
            '🌅 بەربانگ',
            '${s.ramadanMinutes} خولەکی ماوە بۆ بانگی ئێوارە.',
          ));
        }
      }
    }
    return out;
  }
}
