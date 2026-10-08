import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';

/// ⭐ خزمەتگوزاری هەڵسەنگاندن
class ReviewService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 📋 هێنانی کۆمێنتەکان بۆ شوێنێک
  // ═══════════════════════════════════════════════════════════
  static Future<List<Review>> getStoreReviews({
    required int storeId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final res = await _client
          .from('reviews')
          .select()
          .eq('store_id', storeId)
          .eq('is_approved', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (res as List)
          .map((e) => Review.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ getStoreReviews error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ئاماری هەڵسەنگاندن بۆ شوێنێک
  // ═══════════════════════════════════════════════════════════
  static Future<StoreRating?> getStoreRating(int storeId) async {
    try {
      final res = await _client
          .from('store_ratings')
          .select()
          .eq('store_id', storeId)
          .maybeSingle();

      if (res == null) return null;
      return StoreRating.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('❌ getStoreRating error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ زیادکردنی کۆمێنت
  // ═══════════════════════════════════════════════════════════
  static Future<Review?> addReview({
    required int storeId,
    required String? userId,
    required String userName,
    String? userPhone,
    required int rating,
    String? comment,
  }) async {
    try {
      // ✅ پشکنین: rating لە ١ بۆ ٥
      if (rating < 1 || rating > 5) {
        throw ArgumentError('Rating must be 1-5');
      }

      // ✅ پشکنین: ئایا بەکارهێنەر پێشتر هەڵسەنگاندووە؟
      if (userId != null) {
        final existing = await _client
            .from('reviews')
            .select('id')
            .eq('store_id', storeId)
            .eq('user_id', userId)
            .maybeSingle();

        if (existing != null) {
          // ✅ Update ی کۆمێنتی کۆن
          final res = await _client
              .from('reviews')
              .update({
            'rating': rating,
            'comment': comment,
            'updated_at': DateTime.now().toIso8601String(),
          })
              .eq('id', existing['id'])
              .select()
              .maybeSingle();

          return res != null ? Review.fromJson(res) : null;
        }
      }

      // ✅ زیادکردنی کۆمێنتی نوێ
      final res = await _client
          .from('reviews')
          .insert({
        'store_id': storeId,
        'user_id': userId,
        'user_name': userName,
        'user_phone': userPhone,
        'rating': rating,
        'comment': comment,
      })
          .select()
          .maybeSingle();

      return res != null ? Review.fromJson(res) : null;
    } catch (e) {
      debugPrint('❌ addReview error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوەی کۆمێنت
  // ═══════════════════════════════════════════════════════════
  static Future<bool> deleteReview(String reviewId) async {
    try {
      await _client.from('reviews').delete().eq('id', reviewId);
      return true;
    } catch (e) {
      debugPrint('❌ deleteReview error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 👤 کۆمێنتی بەکارهێنەری ئێستا
  // ═══════════════════════════════════════════════════════════
  static Future<Review?> getUserReview({
    required int storeId,
    required String? userId,
  }) async {
    if (userId == null) return null;

    try {
      final res = await _client
          .from('reviews')
          .select()
          .eq('store_id', storeId)
          .eq('user_id', userId)
          .maybeSingle();

      return res != null ? Review.fromJson(res) : null;
    } catch (e) {
      debugPrint('❌ getUserReview error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔝 باشترین شوێنەکان بەپێی Rating
  // ═══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getTopRatedStores({
    int limit = 10,
    double minRating = 4.0,
    int minReviews = 3,
  }) async {
    try {
      final res = await _client
          .from('dukan')
          .select()
          .gte('average_rating', minRating)
          .gte('total_reviews', minReviews)
          .order('average_rating', ascending: false)
          .order('total_reviews', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ getTopRatedStores error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ئاماری گشتی (بۆ ئەدمین)
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      final res = await _client.from('reviews').select('rating');
      final ratings = (res as List)
          .map((e) => int.tryParse(e['rating'].toString()) ?? 0)
          .where((r) => r > 0)
          .toList();

      if (ratings.isEmpty) {
        return {
          'total': 0,
          'average': 0.0,
          'five': 0,
          'four': 0,
          'three': 0,
          'two': 0,
          'one': 0,
        };
      }

      final total = ratings.length;
      final sum = ratings.reduce((a, b) => a + b);

      return {
        'total': total,
        'average': sum / total,
        'five': ratings.where((r) => r == 5).length,
        'four': ratings.where((r) => r == 4).length,
        'three': ratings.where((r) => r == 3).length,
        'two': ratings.where((r) => r == 2).length,
        'one': ratings.where((r) => r == 1).length,
      };
    } catch (e) {
      debugPrint('❌ getGlobalStats error: $e');
      return {
        'total': 0,
        'average': 0.0,
        'five': 0,
        'four': 0,
        'three': 0,
        'two': 0,
        'one': 0,
      };
    }
  }
}