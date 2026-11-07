import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 👁️ زیادکردنی ژمارەی بینین بە شێوەی atomic
class GalleryViewTracker {
  GalleryViewTracker({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> increment(String imageId) async {
    if (imageId.isEmpty) return;
    try {
      await _supabase.rpc(
        'increment_gallery_view',
        params: {'image_id': imageId},
      );
    } catch (e) {
      // ⚠️ fallback ئەگەر RPC نەبوو
      debugPrint('⚠️ RPC increment failed: $e');
      try {
        await _supabase.rpc(
          'increment_gallery_view',
          params: {'image_id': imageId},
        );
      } catch (_) {}
    }
  }
}