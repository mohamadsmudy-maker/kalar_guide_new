// lib/services/waste_schedule_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/tr.dart';
import 'cache_service.dart';
import 'prayer_notification_service.dart';

/// 🗑️ ڕۆژەکانی هاتنی ئۆتۆمبێلی خۆڵ بۆ گەڕەکێک
@immutable
class WasteSchedule {
  const WasteSchedule({
    required this.neighborhoodId,
    this.neighborhoodName = '',
    this.weekdays = const [],
    this.timeText = '',
    this.note = '',
  });

  final int neighborhoodId;
  final String neighborhoodName;

  /// DateTime.weekday: ١ = دووشەممە ... ٦ = شەممە، ٧ = یەکشەممە
  final List<int> weekdays;
  final String timeText;
  final String note;

  bool get isEmpty => weekdays.isEmpty;

  factory WasteSchedule.fromMap(Map<String, dynamic> m) => WasteSchedule(
        neighborhoodId: (m['neighborhood_id'] as num).toInt(),
        neighborhoodName: (m['neighborhood_name'] ?? '').toString(),
        weekdays: [for (final d in (m['weekdays'] as List? ?? const [])) (d as num).toInt()]..sort(),
        timeText: (m['time_text'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
      );

  Map<String, dynamic> toRow() => {
        'neighborhood_id': neighborhoodId,
        'neighborhood_name': neighborhoodName,
        'weekdays': weekdays,
        'time_text': timeText.trim().isEmpty ? null : timeText.trim(),
        'note': note.trim().isEmpty ? null : note.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  /// ڕیزی ڕۆژەکانی هەفتە بۆ پیشاندان: شەممە ← هەینی
  static const List<int> weekOrder = [6, 7, 1, 2, 3, 4, 5];

  static String dayName(int weekday) => switch (weekday) {
        6 => 'شەممە',
        7 => 'یەکشەممە',
        1 => 'دووشەممە',
        2 => 'سێشەممە',
        3 => 'چوارشەممە',
        4 => 'پێنجشەممە',
        _ => 'هەینی',
      };

  /// ڕۆژی داهاتووی هاتن، لە ئەمڕۆوە (ئەمڕۆ خۆی دەژمێردرێت)
  DateTime? nextCollection(DateTime now) {
    if (weekdays.isEmpty) return null;
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 7; i++) {
      final d = today.add(Duration(days: i));
      if (weekdays.contains(d.weekday)) return d;
    }
    return null;
  }

  /// کاتی ئاگادارکردنەوەکان: شەوی پێش هەر ڕۆژێکی هاتن، کاتژمێر [hour]،
  /// تەنها ئەوانەی دواترن لە [now]، بۆ [weeks] هەفتە.
  List<DateTime> reminderTimes(DateTime now, {int weeks = 4, int hour = 20}) {
    final out = <DateTime>[];
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 1; i <= weeks * 7; i++) {
      final day = today.add(Duration(days: i));
      if (!weekdays.contains(day.weekday)) continue;
      final before = DateTime(day.year, day.month, day.day - 1, hour);
      if (before.isAfter(now)) out.add(before);
    }
    return out;
  }
}

class WasteScheduleService {
  WasteScheduleService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static const String _cacheKey = 'waste_schedule_v1';
  static const String _subKey = 'waste_reminder_neighborhood';
  static const String _subNameKey = 'waste_reminder_neighborhood_name';

  /// ناسنامەی ئاگادارکردنەوەکان (جیا لە بانگ و ڕووداو)
  static const int _baseId = 970000;
  static const int _maxReminders = 40;

  /// هەموو خشتەکان (بچووکە)، بێ ئینتەرنێتیش لە کاشەوە
  static Future<List<WasteSchedule>> all() async {
    final rows = await CacheService.fetchList(
      _cacheKey,
      () async => List<Map<String, dynamic>>.from(
          await _db.from('waste_schedule').select() as List),
      keepFor: const Duration(days: 30),
    );
    return rows.map(WasteSchedule.fromMap).toList();
  }

  static Future<WasteSchedule?> forNeighborhood(int id) async {
    try {
      for (final s in await all()) {
        if (s.neighborhoodId == id) return s;
      }
    } catch (e) {
      debugPrint('⚠️ waste schedule: $e');
    }
    return null;
  }

  // ── ئەدمین ─────────────────────────────────────────────
  static Future<void> save(WasteSchedule s) async {
    await _db.from('waste_schedule').upsert(s.toRow());
    await CacheService.remove(_cacheKey);
  }

  static Future<void> delete(int neighborhoodId) async {
    await _db.from('waste_schedule').delete().eq('neighborhood_id', neighborhoodId);
    await CacheService.remove(_cacheKey);
  }

  // ── ئاگادارکردنەوەی شەوی پێشتر ─────────────────────────
  static Future<int?> subscribedNeighborhood() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_subKey);
  }

  /// [id] = null → ئاگادارکردنەوە ناچالاک دەبێت
  static Future<void> subscribe(int? id, {String name = ''}) async {
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(_subKey);
      await p.remove(_subNameKey);
    } else {
      await p.setInt(_subKey, id);
      await p.setString(_subNameKey, name);
      await PrayerNotificationService.requestPermissions();
    }
    await resync();
  }

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// ئاگادارکردنەوەکانی ٤ هەفتەی داهاتوو دووبارە ڕێک دەخاتەوە.
  /// لە دەستپێکردنی ئەپ و دوای ڕێکخستنی بانگ بانگ دەکرێت (ئەو cancelAll دەکات).
  static Future<void> resync() async {
    if (kIsWeb) return;
    try {
      await PrayerNotificationService.initialize();
      for (var i = 0; i < _maxReminders; i++) {
        await _plugin.cancel(_baseId + i);
      }
      final p = await SharedPreferences.getInstance();
      final id = p.getInt(_subKey);
      if (id == null) return;
      final s = await forNeighborhood(id);
      if (s == null || s.isEmpty) return;
      final name = s.neighborhoodName.isNotEmpty ? s.neighborhoodName : (p.getString(_subNameKey) ?? '');
      final times = s.reminderTimes(DateTime.now()).take(_maxReminders).toList();
      for (var i = 0; i < times.length; i++) {
        await _plugin.zonedSchedule(
          _baseId + i,
          tr('🗑️ سبەی ئۆتۆمبێلی خۆڵ دێت'),
          s.timeText.isEmpty
              ? trf('بۆ گەڕەکی {0}. تکایە خۆڵەکەت ئامادە بکە.', [tr(name)])
              : trf('بۆ گەڕەکی {0}، کاتژمێر {1}. تکایە خۆڵەکەت ئامادە بکە.', [tr(name), s.timeText]),
          tz.TZDateTime.from(times[i], tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'waste_reminders',
              'کاتی ئۆتۆمبێلی خۆڵ',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              color: Color(0xFF0F9D7A),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      debugPrint('🗑️ ${times.length} waste reminders scheduled');
    } catch (e) {
      debugPrint('⚠️ waste reminders: $e');
    }
  }
}
