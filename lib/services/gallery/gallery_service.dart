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

    final url =
    _supabase.storage.from(_bucket).getPublicUrl(fileName);

    final res = await _supabase
        .from(_table)
        .insert({
      'image_url': url,
      'image_path': fileName,
      'title': title,
      'category': categoryId,
      'views': 0,
    })
        .select()
        .single();

    return GalleryImage.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> updateTitle(String id, String title) async {
    await _supabase
        .from(_table)
        .update({'title': title}).eq('id', id);
  }

  Future<void> updateCategory(String id, String categoryId) async {
    await _supabase
        .from(_table)
        .update({'category': categoryId}).eq('id', id);
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