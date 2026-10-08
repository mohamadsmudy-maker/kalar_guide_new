import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewsService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 📰 هێنانی هەواڵەکان — بە Pagination
  // ═══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getNews({
    required int from,
    required int to,
  }) async {
    try {
      final res = await _client
          .from('news')
          .select(
        'id, title, description, images, likes, views, created_at, '
            'store_id, dukan(name, logo, image)',
      )
          .order('id', ascending: false)
          .range(from, to);  // ✅ Pagination

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('❌ getNews error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📰 هێنانی هەواڵی شوێنێک — بە Pagination
  // ═══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getStoreNews({
    required int storeId,
    required int from,
    required int to,
  }) async {
    try {
      final res = await _client
          .from('news')
          .select()
          .eq('store_id', storeId)
          .order('id', ascending: false)
          .range(from, to);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('❌ getStoreNews error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 گەڕان بە Pagination
  // ═══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> searchNews({
    required String query,
    required int from,
    required int to,
  }) async {
    try {
      final res = await _client
          .from('news')
          .select()
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('id', ascending: false)
          .range(from, to);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('❌ searchNews error: $e');
      return [];
    }
  }
}