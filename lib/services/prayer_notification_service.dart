import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'prayer/prayer_reminders.dart';
import '../l10n/tr.dart';

class PrayerNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'prayer_times_channel';
  static const String _channelName = 'کاتەکانی نوێژ';
  static const String _channelDesc = 'ئاگادارکردنەوە بۆ کاتەکانی نوێژ';

  /// ✅ ئایا مۆڵەتی exact alarm دراوە؟
  static bool _exactAlarmGranted = false;
  static bool get exactAlarmGranted => _exactAlarmGranted;

  static Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));

      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _notifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // تەنها پشکنین — داواکردن (کردنەوەی ڕێکخستنی ئەندرۆید) تەنها بە دوگمە دەبێت
      await checkExactAlarm();

      debugPrint('✅ Prayer Notifications initialized');
    } catch (e) {
      debugPrint('❌ Prayer Notification error: $e');
    }
  }

  /// ئایا ئەپەکە دەتوانێت بانگ ڕێک لە کاتی خۆیدا ڕابگەیەنێت؟ (بێ کردنەوەی هیچ شاشەیەک)
  static Future<bool> checkExactAlarm() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl == null) {
        _exactAlarmGranted = true;
        return true;
      }
      _exactAlarmGranted = await androidImpl.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('⚠️ Exact alarm check error: $e');
    }
    return _exactAlarmGranted;
  }

  /// شاشەی «Alarms and reminders» ی ئەندرۆید دەکاتەوە (تەنها کاتێک بەکارهێنەر داوای دەکات)
  static Future<bool> openExactAlarmSettings() async {
    await _requestExactAlarmPermission();
    return checkExactAlarm();
  }

  /// ✅ داواکردنی مۆڵەتی exact alarm
  static Future<void> _requestExactAlarmPermission() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted =
            await androidImpl.requestExactAlarmsPermission() ?? false;
        _exactAlarmGranted = granted;
        debugPrint('🔔 Exact alarm permission: $granted');
      }
    } catch (e) {
      debugPrint('⚠️ Exact alarm permission error: $e');
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        // exact alarm تەنها پشکنین؛ بە هەر کردنەوەیەکی شاشەکە ناچێتە ڕێکخستنەکان
        await checkExactAlarm();
        return granted ?? false;
      }

      final iosImpl = _notifications
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      return false;
    }
  }

  static Future<void> scheduleAllPrayers({
    required Map<String, String> prayerTimes,
    required bool is24Hour,
    bool enabled = true,
  }) async {
    if (!enabled) {
      debugPrint('⚠️ Notifications چالاک نین');
      return;
    }

    // ✅ دڵنیابوونەوە لە مۆڵەتی exact alarm
    if (!_exactAlarmGranted) {
      await checkExactAlarm();
    }

    // ✅ هەڵبژاردنی Schedule Mode بەپێی مۆڵەت
    final scheduleMode = _exactAlarmGranted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint('📅 Schedule mode: $scheduleMode');

    await _notifications.cancelAll();

    for (final entry in prayerTimes.entries) {
      if (entry.key == 'خۆرهەڵات' || entry.key == 'Sunrise') continue;

      await _schedulePrayerNotification(
        prayerName: entry.key,
        time: entry.value,
        is24Hour: is24Hour,
        scheduleMode: scheduleMode,
      );
    }

    debugPrint('✅ ${prayerTimes.length} Notifications scheduled');
  }

  static Future<void> _schedulePrayerNotification({
    required String prayerName,
    required String time,
    required bool is24Hour,
    required AndroidScheduleMode scheduleMode,
  }) async {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = DateTime.now();
      var scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);
      final id = prayerName.hashCode.abs() % 100000;

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFD9822B),
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ongoing: false,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(
          trf('کاتی {0}ـە. تکایە بۆ نوێژ ئامادە بە. 🕌', [prayerName]),
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        trf('🕌 کاتی {0}', [prayerName]),
        trf('کاتی {0}ـە. تکایە بۆ نوێژ ئامادە بە.', [prayerName]),
        tzScheduled,
        details,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: prayerName,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✅ Scheduled: $prayerName لە $time');
    } catch (e) {
      debugPrint('❌ Schedule error ($prayerName): $e');
    }
  }

  /// بیرخستنەوە یەکجارییەکان (هەینی، ڕەمەزان). دوای [scheduleAllPrayers]
  /// بانگی بکە، چونکە ئەو هەموو ئاگادارکردنەوەکان دەسڕێتەوە.
  static Future<void> scheduleReminders(List<PrayerReminder> reminders) async {
    final scheduleMode = _exactAlarmGranted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final r in reminders) {
      try {
        await _notifications.zonedSchedule(
          r.id,
          r.title,
          r.body,
          tz.TZDateTime.from(r.at, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              color: Color(0xFFD9822B),
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('❌ reminder ${r.id}: $e');
      }
    }
    debugPrint('✅ ${reminders.length} reminders scheduled');
  }

  static Future<void> scheduleTestNotification({
    Duration delay = const Duration(seconds: 5),
  }) async {
    try {
      final scheduled = DateTime.now().add(delay);
      final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);

      final scheduleMode = _exactAlarmGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _notifications.zonedSchedule(
        999999,
        '🕌 کاتی نوێژ (Test)',
        'ئەمە Notification ی تاقیکردنەوەیە',
        tzScheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFD9822B),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✅ Test notification scheduled for $scheduled');
    } catch (e) {
      debugPrint('❌ Test notification error: $e');
    }
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('🗑️ All prayer notifications canceled');
  }

  static Future<void> cancel(String prayerName) async {
    final id = prayerName.hashCode.abs() % 100000;
    await _notifications.cancel(id);
  }

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}