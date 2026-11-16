import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewsService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// news_type = جۆری بڵاوکراوە (هەواڵ، هۆشداری، ئاگاداری...). بێ ئەمە هەموویان
  /// وەک «هەواڵ» دەردەکەوتن.
  static const String _columns =
      'id, title, description, images, likes, views, created_at, news_type, '
      'store_id, dukan(name, logo, image)';

  /// داتابەیسێکی کۆن کە ستوونی news_type ی نییە
  static bool _hasTypeColumn = true;

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
          .select(_hasTypeColumn ? _columns : _columns.replaceAll('news_type, ', ''))
          .order('id', ascending: false)
          .range(from, to);  // ✅ Pagination

      return List<Map<String, dynamic>>.from(res);
    } on PostgrestException catch (e) {
      if (_hasTypeColumn && e.message.contains('news_type')) {
        _hasTypeColumn = false;
        return getNews(from: from, to: to);
      }
      debugPrint('❌ getNews error: $e');
      return [];
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