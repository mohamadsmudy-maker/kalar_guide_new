import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'adhan_service.dart';
import 'prayer/prayer_reminders.dart';
import 'prayer/prayer_scheduler.dart';
import '../l10n/tr.dart';

class PrayerNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const String _channelName = 'کاتەکانی نوێژ';
  static const String _channelDesc = 'ئاگادارکردنەوە بۆ کاتەکانی نوێژ';

  // سێ کەناڵی جیاواز: دەنگی کەناڵ دوای دروستکردن ناگۆڕدرێت، بۆیە بۆ هەر دەنگێک
  // کەناڵێکی جیا هەیە. «_v2» چونکە کەناڵە کۆنەکە (بێ دەنگی بانگ) بەکارنایەت.
  static const String _chAdhan = 'prayer_adhan_v2';
  static const String _chBeep = 'prayer_beep_v2';
  static const String _chSilent = 'prayer_silent_v2';
  static const String _legacyChannel = 'prayer_times_channel';

  /// فایلی بانگ: android/app/src/main/res/raw/adhan_default.mp3
  static const RawResourceAndroidNotificationSound _adhanSound =
      RawResourceAndroidNotificationSound('adhan_default');

  static bool _initialized = false;

  /// ✅ ئایا مۆڵەتی exact alarm دراوە؟
  static bool _exactAlarmGranted = false;
  static bool get exactAlarmGranted => _exactAlarmGranted;

  static Future<void> initialize() async {
    if (_initialized) return;
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

      final android = _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.deleteNotificationChannel(_legacyChannel);
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _chAdhan,
        'بانگ (دەنگی ئەدان)',
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        sound: _adhanSound,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _chBeep,
        'بانگ (دەنگی ئاگادارکردنەوە)',
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _chSilent,
        'بانگ (بێدەنگ)',
        description: _channelDesc,
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ));

      // تەنها پشکنین — داواکردن (کردنەوەی ڕێکخستنی ئەندرۆید) تەنها بە دوگمە دەبێت
      await checkExactAlarm();

      _initialized = true;
      debugPrint('✅ Prayer Notifications initialized');
    } catch (e) {
      debugPrint('❌ Prayer Notification error: $e');
    }
  }

  /// ئایا ئەپەکە مۆڵەتی نیشاندانی ئاگادارکردنەوەی هەیە؟ (ئەندرۆید ١٣+ دەبێت
  /// بەکارهێنەر ڕێگە بدات؛ ئەگەر نا، هیچ بانگێک نایەت)
  static Future<bool> areNotificationsEnabled() async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      return await android.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
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

  static AndroidScheduleMode get _mode => _exactAlarmGranted
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  /// کەناڵ و دەنگی بانگێک بەپێی هەڵبژاردنی بەکارهێنەر (ڕێکخستنی دەنگی بانگ)
  static Future<(String channel, RawResourceAndroidNotificationSound? sound, bool playSound)>
      _soundFor(String prayerName) async {
    final choice = await AdhanService.getSoundForPrayer(prayerName);
    if (choice == 'silent') return (_chSilent, null, false);
    if (choice == 'beep') return (_chBeep, null, true);
    // هەموو دەنگەکانی تر لەسەر یەک فایلی ئەدان دادەنرێن (تەنها یەک فایل هەیە)
    return (_chAdhan, _adhanSound, true);
  }

  static Future<void> _scheduleOne({
    required int id,
    required String prayerName,
    required DateTime at,
    required AndroidScheduleMode mode,
  }) async {
    final (channel, sound, playSound) = await _soundFor(prayerName);
    final shown = tr(prayerName);
    final androidDetails = AndroidNotificationDetails(
      channel,
      _channelName,
      channelDescription: _channelDesc,
      importance: channel == _chSilent ? Importance.defaultImportance : Importance.max,
      priority: channel == _chSilent ? Priority.defaultPriority : Priority.high,
      playSound: playSound,
      sound: sound,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFD9822B),
      enableVibration: channel != _chSilent,
      category: AndroidNotificationCategory.alarm,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        trf('کاتی {0}ـە. تکایە بۆ نوێژ ئامادە بە. 🕌', [shown]),
      ),
    );

    await _notifications.zonedSchedule(
      id,
      trf('🕌 کاتی {0}', [shown]),
      trf('کاتی {0}ـە. تکایە بۆ نوێژ ئامادە بە.', [shown]),
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: playSound,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: mode,
      payload: prayerName,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// ✅ ڕێکخستنی ٧ ڕۆژ: هەموو شتێکی کۆن دەسڕێتەوە (لەوانە ئەوانەی وەشانە کۆنەکان
  /// کە «هەموو ڕۆژێک» دووبارە دەبوونەوە) و پلانی نوێ دەنووسێت.
  static Future<void> scheduleAll({
    required List<PlannedPrayer> prayers,
    List<PrayerReminder> reminders = const [],
  }) async {
    if (!_exactAlarmGranted) await checkExactAlarm();
    final mode = _mode;
    debugPrint('📅 Schedule mode: $mode');

    await _notifications.cancelAll();

    var ok = 0;
    for (final p in prayers) {
      try {
        await _scheduleOne(id: p.id, prayerName: p.name, at: p.at, mode: mode);
        ok++;
      } catch (e) {
        // ئەگەر ئەمە هەرچی ڕووبدات، بزانرێت: لە release ـدا «Missing type parameter»
        // واتە ڕێساکانی proguard-rules.pro کار ناکەن
        debugPrint('❌ Schedule error (${p.name} ${p.at}): $e');
      }
    }
    debugPrint('✅ $ok/${prayers.length} prayers scheduled');
    await scheduleReminders(reminders);
  }

  /// تەنها بۆ شاشەی تاقیکردنەوە: ناوی نوێژ ← کاتی `HH:mm` (یەکەم کاتی داهاتوو)
  static Future<void> scheduleAllPrayers({
    required Map<String, String> prayerTimes,
    required bool is24Hour,
    bool enabled = true,
  }) async {
    if (!enabled) return;
    if (!_exactAlarmGranted) await checkExactAlarm();
    final mode = _mode;
    await _notifications.cancelAll();

    var n = 0;
    for (final entry in prayerTimes.entries) {
      if (entry.key == 'خۆرهەڵات' || entry.key == 'Sunrise') continue;
      try {
        final parts = entry.value.split(':');
        final now = DateTime.now();
        var at = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
        await _scheduleOne(
          id: 900000 + n++,
          prayerName: entry.key,
          at: at,
          mode: mode,
        );
      } catch (e) {
        debugPrint('❌ Schedule error (${entry.key}): $e');
      }
    }
  }

  /// بیرخستنەوە یەکجارییەکان (هەینی، ڕەمەزان). دوای [scheduleAllPrayers]
  /// بانگی بکە، چونکە ئەو هەموو ئاگادارکردنەوەکان دەسڕێتەوە.
  static Future<void> scheduleReminders(List<PrayerReminder> reminders) async {
    final scheduleMode = _mode;
    for (final r in reminders) {
      try {
        await _notifications.zonedSchedule(
          r.id,
          r.title,
          r.body,
          tz.TZDateTime.from(r.at, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _chBeep,
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

      final scheduleMode = _mode;

      await _notifications.zonedSchedule(
        999999,
        '🕌 کاتی نوێژ (Test)',
        'ئەمە Notification ی تاقیکردنەوەیە',
        tzScheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _chAdhan,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: _adhanSound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
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

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}