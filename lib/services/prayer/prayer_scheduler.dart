import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prayer_notification_service.dart';
import 'kalar_prayer_times.dart';
import 'prayer_reminders.dart';
import 'prayer_times_repository.dart';

/// یەک بانگی ڕێکخراو: کاتێکی دیاریکراو لە ڕۆژێکی دیاریکراودا.
class PlannedPrayer {
  const PlannedPrayer(this.id, this.prayerId, this.name, this.at);

  /// ناسنامەی ئاگادارکردنەوە (جێگیر، بۆ سڕینەوە و نوێکردنەوە)
  final int id;

  /// fajr / dhuhr / asr / maghrib / isha
  final String prayerId;

  /// ناوی کوردی (کلیلی دەنگ و دەقی ئاگادارکردنەوە)
  final String name;

  final DateTime at;

  @override
  String toString() => 'PlannedPrayer($id, $prayerId, $at)';
}

/// 🕌 بانگەکانی ٧ ڕۆژی داهاتوو ڕێک دەخات و هەموو جارێک نوێیان دەکاتەوە.
///
/// پێشتر ئاگادارکردنەوەکان تەنها کاتێک ڕێک دەخران کە شاشەی کاتی نوێژ بکرایەوە،
/// و بە «هەموو ڕۆژێک لە هەمان کاتدا» دووبارە دەبوونەوە، بۆیە لە دوای چەند
/// ڕۆژێک کاتەکان هەڵە دەبوون. ئێستا هەر ڕۆژێک بە کاتی ڕاستی خۆی ڕێک دەخرێت
/// و ئەمە لە دەستپێکردنی ئەپ، گەڕانەوە بۆ ئەپ، و گۆڕینی ڕێکخستنەکان دەکرێت.
class PrayerScheduler with WidgetsBindingObserver {
  PrayerScheduler._();
  static final PrayerScheduler instance = PrayerScheduler._();

  static const String enabledKey = 'prayer_notif';
  static const int days = 7;
  static const int baseId = 300000; // + ڕۆژ×١٠ + ژمارەی نوێژ
  static const Duration _minGap = Duration(hours: 4);

  /// ناوی کوردی؛ بەیانی، نیوەڕۆ، عەسر، مەغریب، عیشا (خۆرهەڵاتن بانگ نییە)
  static const Map<String, String> names = {
    'fajr': 'بەیانی',
    'dhuhr': 'نیوەڕۆ',
    'asr': 'عەسر',
    'maghrib': 'مەغریب',
    'isha': 'عیشا',
  };

  static const List<String> _order = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  bool _started = false;
  bool _running = false;
  DateTime? _last;

  /// پلانی ڕێکخستن: بانگەکانی [days] ڕۆژی داهاتوو کە لە [now] ـەوە ماون.
  /// لۆژیکی پاک — بێ پلاتفۆرم، بۆیە تێست دەکرێت.
  @visibleForTesting
  static List<PlannedPrayer> plan(
    DateTime now, {
    int dayCount = days,
    Map<String, String> Function(DateTime day)? timesForDay,
  }) {
    final times = timesForDay ?? (d) => KalarPrayerTimes.forDay(d).times;
    final out = <PlannedPrayer>[];
    for (var d = 0; d < dayCount; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final t = times(day);
      for (var i = 0; i < _order.length; i++) {
        final hm = t[_order[i]];
        if (hm == null || !KalarPrayerTimes.isValidTime(hm)) continue;
        final m = KalarPrayerTimes.toMinutes(hm);
        final at = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
        if (!at.isAfter(now.add(const Duration(seconds: 5)))) continue;
        out.add(PlannedPrayer(baseId + d * 10 + i, _order[i], names[_order[i]]!, at));
      }
    }
    return out;
  }

  /// یەکجار لە دەستپێکردنی ئەپ
  void start() {
    if (_started || kIsWeb) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await PrayerTimesRepository.loadCache();
      await rescheduleAll(force: true);
      // کاتی نوێی ئەدمین هات؟ دووبارە ڕێک بخە
      if (await PrayerTimesRepository.refresh()) {
        await rescheduleAll(force: true);
      }
    } catch (e) {
      debugPrint('⚠️ prayer scheduler boot: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(rescheduleAll());
  }

  /// هەموو بانگ و بیرخستنەوەکان لە سەرەوە ڕێک دەخاتەوە. هەرگیز هەڵە ناگەڕێنێتەوە.
  Future<void> rescheduleAll({bool force = false}) async {
    if (kIsWeb || _running) return;
    final now = DateTime.now();
    if (!force && _last != null && now.difference(_last!) < _minGap) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(enabledKey) ?? true;
      await PrayerNotificationService.initialize();

      if (!enabled) {
        await PrayerNotificationService.cancelAll();
        _last = now;
        return;
      }

      final settings = await PrayerReminderSettings.load();
      await PrayerNotificationService.scheduleAll(
        prayers: plan(now),
        reminders: PrayerReminders.upcoming(now, settings),
      );
      _last = now;
    } catch (e) {
      debugPrint('⚠️ prayer reschedule: $e');
    } finally {
      _running = false;
    }
  }
}
