import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_service.dart';

/// 📋 خزمەتگوزاری مامەڵەکانی شوێن
class StoreServiceService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 📋 هێنانی مامەڵەکانی شوێنێک
  // ═══════════════════════════════════════════════════════════
  static Future<List<StoreService>> getStoreServices(int storeId) async {
    try {
      final res = await _client
          .from('store_services')
          .select()
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('display_order');

      return (res as List)
          .map((e) => StoreService.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ getStoreServices error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 هێنانی هەموو (بۆ ئەدمین — تەنانەت ناچالاکیش)
  // ═══════════════════════════════════════════════════════════
  static Future<List<StoreService>> getAllForAdmin(int storeId) async {
    try {
      final res = await _client
          .from('store_services')
          .select()
          .eq('store_id', storeId)
          .order('display_order');

      return (res as List)
          .map((e) => StoreService.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ getAllForAdmin error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ زیادکردن
  // ═══════════════════════════════════════════════════════════
  static Future<bool> addService(Map<String, dynamic> data) async {
    try {
      await _client.from('store_services').insert(data);
      return true;
    } catch (e) {
      debugPrint('❌ addService error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✏️ دەستکاریکردن
  // ═══════════════════════════════════════════════════════════
  static Future<bool> updateService(
      String id, Map<String, dynamic> data) async {
    try {
      await _client
          .from('store_services')
          .update({
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ updateService error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  static Future<bool> deleteService(String id) async {
    try {
      await _client.from('store_services').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ deleteService error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔢 ژمارەی مامەڵەکانی شوێن
  // ═══════════════════════════════════════════════════════════
  static Future<int> getCount(int storeId) async {
    try {
      final res = await _client
          .from('store_services')
          .select('id')
          .eq('store_id', storeId)
          .eq('is_active', true);

      return (res as List).length;
    } catch (e) {
      debugPrint('❌ getCount error: $e');
      return 0;
    }
  }
}