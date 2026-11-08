import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';

/// 📅 خزمەتگوزاری ڕووداوەکان
class EventService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 📅 ڕووداوەکانی داهاتوو
  // ═══════════════════════════════════════════════════════════
  static Future<List<AppEvent>> getUpcoming({int days = 60}) async {
    try {
      final now = DateTime.now().toIso8601String();
      final future = DateTime.now()
          .add(Duration(days: days))
          .toIso8601String();

      final res = await _client
          .from('events')
          .select()
          .eq('is_published', true)
          .eq('is_cancelled', false)
          .gte('start_date', now)
          .lte('start_date', future)
          .order('start_date', ascending: true);

      return (res as List)
          .map((e) => AppEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ getUpcoming error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 ڕووداوەکانی ڕابردوو
  // ═══════════════════════════════════════════════════════════
  static Future<List<AppEvent>> getPast({int limit = 50}) async {
    try {
      final now = DateTime.now().toIso8601String();

      final res = await _client
          .from('events')
          .select()
          .lt('start_date', now)
          .order('start_date', ascending: false)
          .limit(limit);

      return (res as List)
          .map((e) => AppEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ getPast error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ ڕووداوی تایبەت
  // ═══════════════════════════════════════════════════════════
  static Future<List<AppEvent>> getFeatured() async {
    try {
      final res = await _client
          .from('events')
          .select()
          .eq('is_published', true)
          .eq('is_cancelled', false)
          .eq('is_featured', true)
          .gte('start_date', DateTime.now().toIso8601String())
          .order('start_date')
          .limit(5);

      return (res as List)
          .map((e) => AppEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ getFeatured error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ بەپێی کەرت
  // ═══════════════════════════════════════════════════════════
  static Future<List<AppEvent>> getByCategory(String category) async {
    try {
      final res = await _client
          .from('events')
          .select()
          .eq('is_published', true)
          .eq('is_cancelled', false)
          .eq('category', category)
          .gte('start_date', DateTime.now().toIso8601String())
          .order('start_date');

      return (res as List)
          .map((e) => AppEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ getByCategory error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ زیادکردن
  // ═══════════════════════════════════════════════════════════
  static Future<bool> addEvent(Map<String, dynamic> data) async {
    try {
      await _client.from('events').insert(data);
      return true;
    } catch (e) {
      debugPrint('❌ addEvent error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✏️ دەستکاریکردن
  // ═══════════════════════════════════════════════════════════
  static Future<bool> updateEvent(
      String id, Map<String, dynamic> data) async {
    try {
      await _client
          .from('events')
          .update({...data, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ updateEvent error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  static Future<bool> deleteEvent(String id) async {
    try {
      await _client.from('events').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ deleteEvent error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ❤️ حەزکردن
  // ═══════════════════════════════════════════════════════════
  static Future<bool> toggleInterest({
    required String eventId,
    required String userId,
  }) async {
    try {
      final existing = await _client
          .from('event_interests')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('event_interests')
            .delete()
            .eq('id', existing['id']);
        return false;
      } else {
        await _client.from('event_interests').insert({
          'event_id': eventId,
          'user_id': userId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ toggleInterest error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ پشکنینی حەزکردن
  // ═══════════════════════════════════════════════════════════
  static Future<bool> isInterested({
    required String eventId,
    required String userId,
  }) async {
    try {
      final res = await _client
          .from('event_interests')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      return res != null;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 👁️ زیادکردنی بینین
  // ═══════════════════════════════════════════════════════════
  static Future<void> incrementViews(String eventId) async {
    try {
      await _client
          .rpc('increment_event_views', params: {'p_event_id': eventId});
    } catch (e) {
      debugPrint('❌ incrementViews error: $e');
    }
  }
}