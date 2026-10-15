import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/neighborhood.dart';

/// 🗺️ خزمەتگوزاری سنوورەکان
class BoundaryService {
  static Map<String, List<LatLng>>? _cache;

  /// هێنانی هەموو سنوورەکان بە شێوەی Map
  static Future<Map<String, List<LatLng>>> loadAll() async {
    if (_cache != null) return _cache!;

    try {
      final raw = await rootBundle.loadString(
        'assets/data/kelar_boundaries.geojson',
      );
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final features = data['features'] as List;

      final result = <String, List<LatLng>>{};

      for (final f in features) {
        final props = f['properties'] as Map<String, dynamic>;
        final geom = f['geometry'] as Map<String, dynamic>;
        final name = props['name'] as String;

        final coords = (geom['coordinates'] as List).first as List;
        final points = coords
            .map<LatLng>((c) => LatLng(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        ))
            .toList();

        // ✅ تەنها ئەو پۆلیگۆنانە وەربگرە کە لانیکەم ٣ خاڵیان هەیە
        if (points.length >= 3) {
          result[name] = points;
        } else {
          debugPrint(
            '⚠️ BoundaryService: $name تەنها ${points.length} خاڵی هەیە — پشتگوێ خرا',
          );
        }
      }

      _cache = result;
      debugPrint('✅ BoundaryService: ${result.length} پۆلیگۆن بارکرا');
      return result;
    } catch (e) {
      debugPrint('❌ BoundaryService.loadAll error: $e');
      return {};
    }
  }

  /// زیادکردنی سنوور بۆ گەڕەکەکان
  static Future<List<Neighborhood>> attachBoundaries(
      List<Neighborhood> neighborhoods,
      ) async {
    final boundaries = await loadAll();

    for (final n in neighborhoods) {
      final points = boundaries[n.nameKu];
      if (points != null && points.length >= 3) {
        n.setBoundary(points);
      }
    }

    return neighborhoods;
  }

  /// پاککردنەوەی کاش
  static void clearCache() => _cache = null;
}