import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🗑️ خزمەتگوزاری پاککردنەوەی فایلەکان لە Storage
class StorageService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 🎤 پاککردنەوەی Voice
  // ═══════════════════════════════════════════════════════════
  /// ✅ سڕینەوەی یەک Voice
  static Future<bool> deleteVoice({
    required String bucketName,
    required String voiceUrl,
  }) async {
    try {
      if (voiceUrl.isEmpty) return true;

      final fileName = _extractFileName(voiceUrl);
      if (fileName.isEmpty) return false;

      await _client.storage.from(bucketName).remove([fileName]);
      debugPrint('🗑️ Voice سڕایەوە: $fileName');
      return true;
    } catch (e) {
      debugPrint('❌ هەڵە لە سڕینەوەی Voice: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🖼️ پاککردنەوەی وێنەکان
  // ═══════════════════════════════════════════════════════════
  /// ✅ سڕینەوەی چەند وێنەیەک
  static Future<bool> deleteImages({
    required String bucketName,
    required List<String> imageUrls,
  }) async {
    try {
      if (imageUrls.isEmpty) return true;

      final fileNames = imageUrls
          .map(_extractFileName)
          .where((name) => name.isNotEmpty)
          .toList();

      if (fileNames.isEmpty) return true;

      await _client.storage.from(bucketName).remove(fileNames);
      debugPrint('🗑️ ${fileNames.length} وێنە سڕایەوە');
      return true;
    } catch (e) {
      debugPrint('❌ هەڵە لە سڕینەوەی وێنەکان: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎬 پاککردنەوەی ڤیدیۆ
  // ═══════════════════════════════════════════════════════════
  /// ✅ سڕینەوەی یەک ڤیدیۆ
  static Future<bool> deleteVideo({
    required String bucketName,
    required String videoUrl,
  }) async {
    try {
      if (videoUrl.isEmpty) return true;

      final fileName = _extractFileName(videoUrl);
      if (fileName.isEmpty) return false;

      await _client.storage.from(bucketName).remove([fileName]);
      debugPrint('🗑️ ڤیدیۆ سڕایەوە: $fileName');
      return true;
    } catch (e) {
      debugPrint('❌ هەڵە لە سڕینەوەی ڤیدیۆ: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 سڕینەوەی هەموو فایلەکانی بابەتێک
  // ═══════════════════════════════════════════════════════════

  /// ✅ سڕینەوەی هەموو فایلەکانی **سکاڵا**
  static Future<void> deleteComplaintFiles({
    required Map<String, dynamic> complaint,
  }) async {
    try {
      const bucket = 'complaints';

      // ١. Voice
      final voiceUrl = complaint['voice_url']?.toString() ?? '';
      if (voiceUrl.isNotEmpty) {
        await deleteVoice(bucketName: bucket, voiceUrl: voiceUrl);
      }

      // ٢. وێنەکان
      final images = complaint['images'];
      if (images is List && images.isNotEmpty) {
        final urls = images.map((e) => e.toString()).toList();
        await deleteImages(bucketName: bucket, imageUrls: urls);
      }

      // ٣. ڤیدیۆ (ئەگەر هەبوو)
      final videoUrl = complaint['video_url']?.toString() ?? '';
      if (videoUrl.isNotEmpty) {
        await deleteVideo(bucketName: bucket, videoUrl: videoUrl);
      }

      debugPrint('✅ هەموو فایلەکانی سکاڵا سڕایەوە');
    } catch (e) {
      debugPrint('❌ هەڵە لە سڕینەوەی فایلەکانی سکاڵا: $e');
    }
  }

  /// ✅ سڕینەوەی هەموو فایلەکانی **هەواڵ**
  static Future<void> deleteNewsFiles({
    required Map<String, dynamic> news,
  }) async {
    try {
      const bucket = 'news';

      // ١. وێنەکان
      final images = news['images'];
      if (images is List && images.isNotEmpty) {
        final urls = images.map((e) => e.toString()).toList();
        await deleteImages(bucketName: bucket, imageUrls: urls);
      }

      // ٢. ڤیدیۆ (ئەگەر هەبوو)
      final videoUrl = news['video_url']?.toString() ?? '';
      if (videoUrl.isNotEmpty) {
        await deleteVideo(bucketName: bucket, videoUrl: videoUrl);
      }

      // ٣. Voice (ئەگەر هەبوو)
      final voiceUrl = news['voice_url']?.toString() ?? '';
      if (voiceUrl.isNotEmpty) {
        await deleteVoice(bucketName: bucket, voiceUrl: voiceUrl);
      }

      debugPrint('✅ هەموو فایلەکانی هەواڵ سڕایەوە');
    } catch (e) {
      debugPrint('❌ هەڵە لە سڕینەوەی فایلەکانی هەواڵ: $e');
    }
  }

  /// ✅ سڕینەوەی هەموو فایلەکانی **شوێن**
  static Future<void> deleteStoreFiles({
    required Map<String, dynamic> store,
  }) async {
    try {
      const bucket = 'stores';

      final image = store['image']?.toString() ?? '';
      if (image.isNotEmpty) {
        await deleteVideo(bucketName: bucket, videoUrl: image);
      }

      final logo = store['logo']?.toString() ?? '';
      if (logo.isNotEmpty) {
        await deleteVideo(bucketName: bucket, videoUrl: logo);
      }

      debugPrint('✅ هەموو فایلەکانی شوێن سڕایەوە');
    } catch (e) {
      debugPrint('❌ هەڵە لە سڕینەوەی فایلەکانی شوێن: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Helpers
  // ═══════════════════════════════════════════════════════════

  /// ✅ دەرهێنانی ناوی فایل لە URL
  /// نموونە:
  /// `https://xxx.supabase.co/storage/v1/object/public/complaints/voice_123.m4a`
  /// → `voice_123.m4a`
  static String _extractFileName(String url) {
    try {
      if (url.isEmpty) return '';

      // دابەشکردن بە '/' و وەرگرتنی کۆتایی
      final parts = url.split('/');
      if (parts.isEmpty) return '';

      var fileName = parts.last;

      // لابردنی Query Parameters (ئەگەر هەبوو)
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }

      return Uri.decodeComponent(fileName);
    } catch (e) {
      debugPrint('❌ هەڵە لە دەرهێنانی ناوی فایل: $e');
      return '';
    }
  }
}