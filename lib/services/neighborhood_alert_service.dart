// lib/services/neighborhood_alert_service.dart
//
// 📍 ئاگاداریی گەڕەک: هاوڵاتی گەڕەکێک هەڵدەبژێرێت → topic ـی nbh_<id> ـی
// Firebase. ئەدمین ئاگادارییەک دەنووسێت → send-neighborhood-alert دەینێرێت.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NeighborhoodAlert {
  final int id;
  final int neighborhoodId;
  final String neighborhoodName;
  final String title;
  final String body;
  final DateTime? createdAt;

  const NeighborhoodAlert({
    required this.id,
    required this.neighborhoodId,
    required this.title,
    this.neighborhoodName = '',
    this.body = '',
    this.createdAt,
  });

  factory NeighborhoodAlert.fromMap(Map<String, dynamic> m) => NeighborhoodAlert(
        id: (m['id'] as num).toInt(),
        neighborhoodId: (m['neighborhood_id'] as num).toInt(),
        neighborhoodName: (m['neighborhood_name'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        createdAt: DateTime.tryParse('${m['created_at'] ?? ''}')?.toLocal(),
      );
}

class NeighborhoodAlertService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _prefsKey = 'alert_neighborhoods';

  /// هەمان ناو لە supabase/functions/send-neighborhood-alert دا
  static String topicFor(int neighborhoodId) => 'nbh_$neighborhoodId';

  /// بۆ تێست: لە جیاتی Firebase
  @visibleForTesting
  static Future<void> Function(String topic, bool on)? topicOverride;

  static Future<void> _topic(String topic, bool on) async {
    final o = topicOverride;
    if (o != null) return o(topic, on);
    final m = FirebaseMessaging.instance;
    on ? await m.subscribeToTopic(topic) : await m.unsubscribeFromTopic(topic);
  }

  static Future<Set<int>> subscribed() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  /// سەرەتا Firebase؛ ئەگەر سەرکەوتوو نەبوو هیچ شتێک پاشەکەوت ناکرێت (هەڵە دەگەڕێتەوە)
  static Future<void> setSubscribed(int neighborhoodId, bool on) async {
    await _topic(topicFor(neighborhoodId), on);
    final prefs = await SharedPreferences.getInstance();
    final ids = await subscribed();
    on ? ids.add(neighborhoodId) : ids.remove(neighborhoodId);
    await prefs.setStringList(_prefsKey, [for (final i in ids) '$i']);
  }

  /// لە کاتی کردنەوەی ئەپ: تۆمارکردنەوەی گەڕەکە هەڵبژێردراوەکان
  static Future<void> resubscribeAll() async {
    for (final id in await subscribed()) {
      try {
        await _topic(topicFor(id), true);
      } catch (e) {
        debugPrint('⚠️ resubscribe $id: $e');
      }
    }
  }

  /// کوژاندنەوەی هەموو ئاگادارییەکان؛ لیستی گەڕەکەکان دەمێنێتەوە بۆ
  /// ئەوەی کاتێک دووبارە چالاک کرایەوە بگەڕێنەوە
  static Future<void> unsubscribeAll() async {
    for (final id in await subscribed()) {
      try {
        await _topic(topicFor(id), false);
      } catch (e) {
        debugPrint('⚠️ unsubscribe $id: $e');
      }
    }
  }

  static Future<List<NeighborhoodAlert>> recent(int neighborhoodId, {int days = 30}) async {
    final since = DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();
    final res = await _db
        .from('neighborhood_alerts')
        .select()
        .eq('neighborhood_id', neighborhoodId)
        .gte('created_at', since)
        .order('created_at', ascending: false)
        .limit(10);
    return (res as List)
        .map((e) => NeighborhoodAlert.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<List<NeighborhoodAlert>> latest({int limit = 50}) async {
    final res = await _db
        .from('neighborhood_alerts')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((e) => NeighborhoodAlert.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> neighborhoods() async {
    final res = await _db.from('neighborhoods').select('id, name_ku').order('name_ku');
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> add({
    required int neighborhoodId,
    required String neighborhoodName,
    required String title,
    String? body,
  }) async {
    await _db.from('neighborhood_alerts').insert({
      'neighborhood_id': neighborhoodId,
      'neighborhood_name': neighborhoodName,
      'title': title.trim(),
      'body': (body ?? '').trim().isEmpty ? null : body!.trim(),
    });
  }

  static Future<void> delete(int id) async {
    await _db.from('neighborhood_alerts').delete().eq('id', id);
  }
}
