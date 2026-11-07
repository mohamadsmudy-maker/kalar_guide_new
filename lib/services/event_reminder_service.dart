// lib/services/event_reminder_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter/material.dart' show Color;
import '../l10n/tr.dart';

class EventReminderService {
  static const _prefsKey = 'event_reminders';
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));

      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      await _notifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );
      debugPrint('✅ Reminder service initialized');
    } catch (e) {
      debugPrint('❌ Reminder init error: $e');
    }
  }

  static Future<void> scheduleReminder({
    required String eventId,
    required String eventTitle,
    required DateTime eventDate,
    int minutesBefore = 60,
  }) async {
    try {
      final reminderTime = eventDate.subtract(
        Duration(minutes: minutesBefore),
      );

      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint('⚠️ Reminder time has passed');
        return;
      }

      final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

      await _notifications.zonedSchedule(
        eventId.hashCode,
        trf('📅 یادخستنەوە: {0}', [eventTitle]),
        trf('دوای {0} خولەک دەست پێدەکات', [minutesBefore]),
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_reminders',
            'یادخستنەوەی ڕووداوەکان',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF6C5CE7),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime, // ✅ زیادکرا
      );

      // ⭐ پاشەکەوتکردن
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      if (!list.contains(eventId)) {
        list.add(eventId);
        await prefs.setStringList(_prefsKey, list);
      }

      debugPrint('✅ Reminder scheduled: $eventTitle');
    } catch (e) {
      debugPrint('❌ Schedule reminder error: $e');
    }
  }

  static Future<bool> hasReminder(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      return list.contains(eventId);
    } catch (e) {
      debugPrint('❌ hasReminder error: $e');
      return false;
    }
  }

  static Future<void> cancelReminder(String eventId) async {
    try {
      await _notifications.cancel(eventId.hashCode);
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      list.remove(eventId);
      await prefs.setStringList(_prefsKey, list);
      debugPrint('🗑️ Reminder cancelled: $eventId');
    } catch (e) {
      debugPrint('❌ Cancel reminder error: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      debugPrint('🗑️ All reminders cancelled');
    } catch (e) {
      debugPrint('❌ Cancel all error: $e');
    }
  }
}