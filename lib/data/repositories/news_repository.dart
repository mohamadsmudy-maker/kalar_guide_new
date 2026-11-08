import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/news.dart';

/// 📰 Repository بۆ هەواڵەکان — Data Layer
class NewsRepository {
  final SupabaseClient _client;

  NewsRepository(this._client);

  // ═══════════════════════════════════════════════════════════
  // 📖 خوێندنەوە
  // ═══════════════════════════════════════════════════════════

  /// ✅ وەرگرتنی هەموو هەواڵەکان (بە Pagination)
  Future<List<News>> getNews({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final res = await _client
          .from('news')
          .select(
        'id, title, description, images, likes, views, created_at, '
            'store_id, dukan(name, logo, image)',
      )
          .order('id', ascending: false)
          .range(from, to);

      return (res as List)
          .map((e) => News.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('❌ NewsRepository.getNews: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ NewsRepository.getNews: $e');
      rethrow;
    }
  }

  /// ✅ وەرگرتنی هەواڵی یەکێک
  Future<News?> getNewsById(String id) async {
    try {
      final res = await _client
          .from('news')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (res == null) return null;
      return News.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('❌ NewsRepository.getNewsById: $e');
      return null;
    }
  }

  /// ✅ وەرگرتنی هەواڵی شوێنێک
  Future<List<News>> getNewsByStore(
      int storeId, {
        int limit = 20,
      }) async {
    try {
      final res = await _client
          .from('news')
          .select()
          .eq('store_id', storeId)
          .order('id', ascending: false)
          .limit(limit);

      return (res as List)
          .map((e) => News.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ NewsRepository.getNewsByStore: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✏️ نووسین
  // ═══════════════════════════════════════════════════════════

  /// ✅ زیادکردنی هەواڵ
  Future<bool> addNews({
    required String title,
    required String description,
    required List<String> images,
    int? storeId,
  }) async {
    try {
      await _client.from('news').insert({
        'title': title,
        'description': description,
        'images': images,
        'likes': 0,
        'views': 0,
        'store_id': storeId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ NewsRepository.addNews: $e');
      return false;
    }
  }

  /// ✅ زیادکردنی View
  Future<void> incrementViews(String newsId, int currentViews) async {
    try {
      await _client.rpc('increment_views', params: {'news_id': newsId});
    } catch (e) {
      debugPrint('❌ NewsRepository.incrementViews: $e');
    }
  }

  /// ✅ Like / Unlike
  Future<bool> toggleLike({
    required String newsId,
    required String userId,
    required bool isLiked,
    required int currentLikes,
  }) async {
    try {
      if (isLiked) {
        // Unlike
        await _client
            .from('news_likes')
            .delete()
            .eq('user_id', userId)
            .eq('news_id', newsId);
      } else {
        // Like
        await _client.from('news_likes').insert({
          'user_id': userId,
          'news_id': newsId,
        });
      }

      await _client.rpc(
        isLiked ? 'decrement_likes' : 'increment_likes',
        params: {'news_id': newsId},
      );

      return !isLiked;
    } catch (e) {
      debugPrint('❌ NewsRepository.toggleLike: $e');
      return isLiked;
    }
  }

  /// ✅ سڕینەوەی هەواڵ
  Future<bool> deleteNews(String id) async {
    try {
      await _client.from('news').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ NewsRepository.deleteNews: $e');
      return false;
    }
  }
}