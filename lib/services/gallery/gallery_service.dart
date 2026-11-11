import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/gallery/gallery_image.dart';
import '../../models/gallery/gallery_category_registry.dart';

/// 🗄️ خزمەتگوزاری گەلەری — CRUD + Storage
class GalleryService {
  GalleryService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const _table = 'gallery';
  static const _bucket = 'gallery_images';
  static const int maxImageBytes = 10 * 1024 * 1024;

  // ── READ ────────────────────────────────────────────────
  Future<List<GalleryImage>> fetchAll({String? categoryId}) async {
    var q = _supabase.from(_table).select();
    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.eq('category', categoryId);
    }
    final res = await q.order('created_at', ascending: false);
    return (res as List)
        .whereType<Map>()
        .map((e) => GalleryImage.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, int>> countByCategory() async {
    final res = await _supabase.from(_table).select('category');
    final map = <String, int>{};
    for (final row in (res as List).whereType<Map>()) {
      final c = (row['category']?.toString().isNotEmpty ?? false)
          ? row['category'].toString()
          : GalleryCategoryRegistry.defaultId;
      map[c] = (map[c] ?? 0) + 1;
    }
    return map;
  }

  // ── WRITE ───────────────────────────────────────────────
  Future<GalleryImage> upload({
    required File file,
    required String title,
    required String categoryId,
  }) async {
    final len = await file.length();
    if (len > maxImageBytes) {
      throw Exception('قەبارەی وێنە زۆر گەورەیە');
    }

    final fileName = '${const Uuid().v4()}.jpg';
    await _supabase.storage.from(_bucket).upload(fileName, file);

    final url = _supabase.storage.from(_bucket).getPublicUrl(fileName);

    try {
      final res = await _insertRow(url, fileName, title, categoryId);
      return GalleryImage.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      // ڕیزەکە تۆمار نەبوو → فایلی سەربار لە storage ناهێڵینەوە
      try {
        await _supabase.storage.from(_bucket).remove([fileName]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _insertRow(
      String url, String fileName, String title, String categoryId) async {
    final row = {
      'image_url': url,
      'image_path': fileName,
      'title': title,
      'category': categoryId,
      'views': 0,
    };
    try {
      return await _supabase.from(_table).insert(row).select().single();
    } on PostgrestException catch (e) {
      // تەیبڵە کۆنەکان ستوونی image_path ـیان نییە → بەبێ ئەو دووبارە
      if (e.code == 'PGRST204' && e.message.contains('image_path')) {
        row.remove('image_path');
        return await _supabase.from(_table).insert(row).select().single();
      }
      rethrow;
    }
  }

  /// پەیامی هەڵەی ئەپلۆد بە کوردی + هۆکارە تەکنیکیەکە
  static String uploadErrorText(Object e) {
    if (e is StorageException) {
      final m = e.message;
      if (e.statusCode == '404' || m.contains('Bucket not found')) {
        return 'باکێتی "$_bucket" لە Supabase Storage نەدۆزرایەوە — دروستی بکە';
      }
      if (e.statusCode == '403' ||
          m.toLowerCase().contains('policy') ||
          m.toLowerCase().contains('unauthorized')) {
        return 'ڕێگەپێدانی Storage ڕێگە بە ئەپلۆد نادات (RLS policy) — $m';
      }
      return 'هەڵەی Storage: $m';
    }
    if (e is PostgrestException) {
      return 'هەڵەی خشتەی gallery: ${e.message}';
    }
    final t = e.toString();
    return t.length > 140 ? t.substring(0, 140) : t;
  }

  Future<void> updateTitle(String id, String title) async {
    await _supabase.from(_table).update({'title': title}).eq('id', id);
  }

  Future<void> updateCategory(String id, String categoryId) async {
    await _supabase.from(_table).update({'category': categoryId}).eq('id', id);
  }

  Future<void> delete(GalleryImage image) async {
    await _supabase.from(_table).delete().eq('id', image.id);
    final path = image.imagePath ?? _extractPath(image.imageUrl);
    if (path != null && path.isNotEmpty) {
      try {
        await _supabase.storage.from(_bucket).remove([path]);
      } catch (e) {
        debugPrint('⚠️ Storage remove failed: $e');
      }
    }
  }

  String? _extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      final idx = uri.pathSegments.indexOf(_bucket);
      if (idx < 0 || idx + 1 >= uri.pathSegments.length) return null;
      return uri.pathSegments.sublist(idx + 1).join('/');
    } catch (_) {
      return null;
    }
  }
}
