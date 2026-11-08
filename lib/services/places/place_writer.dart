// lib/services/places/place_writer.dart
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// ✍️ زیادکردنی شوێن بۆ خشتەی dukan — هەمان ستوونەکانی شاشەی «زیادکردنی
/// شوێن»، بۆ ئەوەی شوێنە هاوردەکراوەکانیش لە هەموو شاشەکاندا وەک ئەوانی تر بن.
/// تەنها ئەدمین (RLS: admin_insert).
class PlaceWriter {
  PlaceWriter._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// ڕیزی ئامادە بۆ dukan
  static Map<String, dynamic> row({
    required String name,
    required String category,
    required double lat,
    required double lng,
    required String source,
    String? externalId,
    String? phone,
    String? address,
    String? description,
    bool government = false,
    String? neighborhood,
  }) {
    final type = government ? 'حکومی' : 'ناحکومی';
    return {
      'name': name.trim(),
      'phone': (phone ?? '').trim(),
      'address': (address ?? '').trim().isEmpty ? 'کەلار' : address!.trim(),
      'description': (description ?? '').trim(),
      'category': category,
      'sector': category,
      'type': type,
      'ownership_type': type,
      'latitude': lat,
      'longitude': lng,
      'location': jsonEncode({
        'type': 'Point',
        'coordinates': [lng, lat],
      }),
      'neighborhood_name': neighborhood,
      'image': '',
      'images': <String>[],
      'is_approved': true,
      'is_verified': false,
      'average_rating': 0.0,
      'total_reviews': 0,
      'services': <dynamic>[],
      'source': source,
      if (externalId != null) 'external_id': externalId,
    };
  }

  /// گەڕەکی شوێنەکە (هەمان RPC ی شاشەی زیادکردنی شوێن)؛ هەڵە → null
  static Future<String?> neighborhoodOf(double lat, double lng) async {
    try {
      final res = await _db.rpc('get_neighborhood_by_location', params: {
        'p_longitude': lng,
        'p_latitude': lat,
      });
      final s = res?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  /// زیادی دەکات و ئایدی شوێنە نوێکە دەگەڕێنێتەوە
  static Future<int?> insert(Map<String, dynamic> row) async {
    final res = await _db.from('dukan').insert(row).select('id').single();
    return (res['id'] as num?)?.toInt();
  }
}
