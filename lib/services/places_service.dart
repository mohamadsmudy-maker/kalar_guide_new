// lib/services/places_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🗺️ خزمەتگوزاری Places — بە Edge Function
///
/// ✅ کلیلەکە لە server دەمێنێت، هەرگیز لە client نابێت
class PlacesService {
  PlacesService._();

  /// 🔍 گەڕان بە Places API
  static Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    double? biasLat,
    double? biasLng,
    int radius = 30000,
  }) async {
    try {
      // ⚠️ پشکنینی query
      if (query.trim().length < 2) return [];

      final response = await Supabase.instance.client.functions.invoke(
        'places-search',
        body: {
          'query': query.trim(),
          'biasLat': biasLat,
          'biasLng': biasLng,
          'radius': radius,
        },
      );

      if (response.status != 200) {
        debugPrint('❌ Places search error: ${response.status}');
        return [];
      }

      final data = response.data as Map<String, dynamic>?;
      final results = data?['results'] as List? ?? [];
      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Places search exception: $e');
      return [];
    }
  }

  /// 📋 وەرگرتنی زانیاری شوێن بە place_id
  static Future<Map<String, dynamic>?> getPlaceDetails(
      String placeId,
      ) async {
    try {
      if (placeId.isEmpty) return null;

      final response = await Supabase.instance.client.functions.invoke(
        'places-details',
        body: {'placeId': placeId},
      );

      if (response.status != 200) {
        debugPrint('❌ Place details error: ${response.status}');
        return null;
      }

      return response.data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ Place details exception: $e');
      return null;
    }
  }

  /// 📍 گەڕان بۆ نزیکترین شوێن
  static Future<Map<String, dynamic>?> findNearest({
    required double lat,
    required double lng,
    int radius = 50,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'places-nearby',
        body: {
          'lat': lat,
          'lng': lng,
          'radius': radius,
        },
      );

      if (response.status != 200) return null;

      return response.data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ Find nearest exception: $e');
      return null;
    }
  }
}