// lib/services/featured_places.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_control.dart';

/// ⭐ شوێنی پێشنیارکراو (sponsored): dukan.featured_until.
/// ئەدمین لە ناوەندی کۆنترۆڵ دەتوانێت هەموو تایبەتمەندییەکە بکوژێنێتەوە
/// (features.featured_places)؛ ئەو کاتە هیچ شوێنێک پێشنیارکراو نییە.
class FeaturedPlaces {
  FeaturedPlaces._();

  static const String featureKey = 'featured_places';

  /// ماوەکانی ئامادە بۆ ئەدمین (ڕۆژ)
  static const List<int> durations = [7, 30, 90];

  static bool get enabled => AppControl.state.value.feature(featureKey);

  static DateTime? until(Map<String, dynamic> place) =>
      DateTime.tryParse(place['featured_until']?.toString() ?? '');

  /// ئێستا پێشنیارکراوە؟ [enabled]/[now] بۆ تاقیکردنەوە
  static bool isFeatured(Map<String, dynamic> place, {bool? enabled, DateTime? now}) {
    if (!(enabled ?? FeaturedPlaces.enabled)) return false;
    final u = until(place);
    return u != null && u.isAfter(now ?? DateTime.now());
  }

  /// پێشنیارکراوەکان لە سەرەوە؛ ڕیزی ناو هەر گروپێک وەک خۆی دەمێنێتەوە
  static List<Map<String, dynamic>> featuredFirst(
    List<Map<String, dynamic>> places, {
    bool? enabled,
    DateTime? now,
  }) {
    final on = enabled ?? FeaturedPlaces.enabled;
    if (!on) return places;
    final t = now ?? DateTime.now();
    return [
      ...places.where((p) => isFeatured(p, enabled: true, now: t)),
      ...places.where((p) => !isFeatured(p, enabled: true, now: t)),
    ];
  }

  /// ئەدمین: [days] ڕۆژ پێشنیارکراو دەکات، null = لابردن
  static Future<DateTime?> setFeatured(Object placeId, int? days) async {
    final value = days == null
        ? null
        : DateTime.now().toUtc().add(Duration(days: days));
    await Supabase.instance.client
        .from('dukan')
        .update({'featured_until': value?.toIso8601String()})
        .eq('id', placeId);
    return value;
  }
}
