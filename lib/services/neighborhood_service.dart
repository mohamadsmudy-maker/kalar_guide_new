import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/neighborhood.dart';
import 'boundary_service.dart';

/// 🏘️ خزمەتگوزاری گەڕەکەکان
class NeighborhoodService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 📋 هێنانی هەموو گەڕەکەکان (لەگەڵ سنوورەکان)
  // ═══════════════════════════════════════════════════════════
  static Future<List<Neighborhood>> getAll() async {
    try {
      final res = await _client
          .from('neighborhoods')
          .select()
          .eq('is_active', true)
          .order('display_order');

      final list = (res as List)
          .map((e) => Neighborhood.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // ⭐ پێکەوە بەستن لەگەڵ GeoJSON
      return await BoundaryService.attachBoundaries(list);
    } catch (e) {
      debugPrint('❌ getAll neighborhoods error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 گەڕان بە ناو
  // ═══════════════════════════════════════════════════════════
  static Future<List<Neighborhood>> search(String query) async {
    try {
      final res = await _client
          .from('neighborhoods')
          .select()
          .eq('is_active', true)
          .ilike('name_ku', '%$query%')
          .order('display_order');

      final list = (res as List)
          .map((e) => Neighborhood.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      return await BoundaryService.attachBoundaries(list);
    } catch (e) {
      debugPrint('❌ search neighborhoods error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 هێنانی گەڕەک بە ID
  // ═══════════════════════════════════════════════════════════
  static Future<Neighborhood?> getById(int id) async {
    try {
      final res = await _client
          .from('neighborhoods')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (res == null) return null;

      final n = Neighborhood.fromJson(Map<String, dynamic>.from(res));
      final list = await BoundaryService.attachBoundaries([n]);
      return list.first;
    } catch (e) {
      debugPrint('❌ getById error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 هێنانی شوێنەکانی گەڕەک
  // ═══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getStoresInNeighborhood(
      int neighborhoodId,
      ) async {
    try {
      final res = await _client
          .from('dukan')
          .select()
          .eq('neighborhood_id', neighborhoodId)
          .order('name');

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ getStoresInNeighborhood error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ئاماری گەڕەکەکان
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await _client
          .from('neighborhoods')
          .select('population, total_stores, area_km2')
          .eq('is_active', true);

      int totalPopulation = 0;
      int totalStores = 0;
      double totalArea = 0;

      for (var n in (res as List)) {
        totalPopulation +=
            int.tryParse(n['population']?.toString() ?? '0') ?? 0;
        totalStores +=
            int.tryParse(n['total_stores']?.toString() ?? '0') ?? 0;
        totalArea +=
            double.tryParse(n['area_km2']?.toString() ?? '0') ?? 0;
      }

      return {
        'total_neighborhoods': (res).length,
        'total_population': totalPopulation,
        'total_stores': totalStores,
        'total_area_km2': totalArea,
      };
    } catch (e) {
      debugPrint('❌ getStats error: $e');
      return {
        'total_neighborhoods': 0,
        'total_population': 0,
        'total_stores': 0,
        'total_area_km2': 0.0,
      };
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 دۆزینەوەی گەڕەک بەپێی کۆئۆردینەت (Point-in-Polygon)
  // ═══════════════════════════════════════════════════════════
  static Future<Neighborhood?> findNeighborhoodByLocation({
    required double lat,
    required double lng,
  }) async {
    try {
      final neighborhoods = await getAll();

      for (var n in neighborhoods) {
        if (n.hasBoundary && _isPointInPolygon(lat, lng, n.boundaryPoints)) {
          return n;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ findNeighborhoodByLocation error: $e');
      return null;
    }
  }

  /// 📐 Point-in-Polygon (Ray Casting Algorithm)
  static bool _isPointInPolygon(
      double lat,
      double lng,
      List<dynamic> polygon,
      ) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ زیادکردن (بۆ ئەدمین)
  // ═══════════════════════════════════════════════════════════
  static Future<bool> addNeighborhood(Map<String, dynamic> data) async {
    try {
      await _client.from('neighborhoods').insert(data);
      return true;
    } catch (e) {
      debugPrint('❌ addNeighborhood error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✏️ دەستکاریکردن
  // ═══════════════════════════════════════════════════════════
  static Future<bool> updateNeighborhood(
      String id,
      Map<String, dynamic> data,
      ) async {
    try {
      await _client
          .from('neighborhoods')
          .update({
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ updateNeighborhood error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  static Future<bool> deleteNeighborhood(String id) async {
    try {
      await _client.from('neighborhoods').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ deleteNeighborhood error: $e');
      return false;
    }
  }
}