import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/emergency_service.dart';

/// 🚑 خزمەتگوزاری فریاکەوتن
class EmergencyServiceService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 📋 هێنانی هەموو خزمەتگوزارییەکان
  // ═══════════════════════════════════════════════════════════
  static Future<List<EmergencyService>> getAll() async {
    try {
      final res = await _client
          .from('emergency_services')
          .select()
          .order('display_order');

      return (res as List)
          .map((e) => EmergencyService.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ getAll emergency error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ هێنانی بەپێی کەرت
  // ═══════════════════════════════════════════════════════════
  static Future<List<EmergencyService>> getByCategory(
      String category) async {
    try {
      final res = await _client
          .from('emergency_services')
          .select()
          .eq('category', category)
          .order('display_order');

      return (res as List)
          .map((e) => EmergencyService.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ getByCategory error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ هێنانی گرنگەکان
  // ═══════════════════════════════════════════════════════════
  static Future<List<EmergencyService>> getImportant() async {
    try {
      final res = await _client
          .from('emergency_services')
          .select()
          .eq('is_important', true)
          .order('display_order');

      return (res as List)
          .map((e) => EmergencyService.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ getImportant error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ زیادکردن (بۆ ئەدمین)
  // ═══════════════════════════════════════════════════════════
  static Future<bool> addService(Map<String, dynamic> data) async {
    try {
      await _client.from('emergency_services').insert(data);
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
          .from('emergency_services')
          .update(data)
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
      await _client.from('emergency_services').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ deleteService error: $e');
      return false;
    }
  }
}