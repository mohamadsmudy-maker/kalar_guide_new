import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ❤️ خزمەتگوزاری دڵخوازکردنی جۆری سووتەمەنی
class FuelFavoritesService {
  static const String _prefsKey = 'fuel_favorites';

  /// ⭐ هەموو
  static Future<Set<String>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      return list.toSet();
    } catch (e) {
      debugPrint('❌ Favorites error: $e');
      return {};
    }
  }

  /// ⭐ Toggle
  static Future<bool> toggle(String fuelType) async {
    try {
      final favorites = await getAll();
      final isFav = favorites.contains(fuelType);

      if (isFav) {
        favorites.remove(fuelType);
      } else {
        favorites.add(fuelType);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, favorites.toList());

      return !isFav;
    } catch (e) {
      debugPrint('❌ Toggle favorite error: $e');
      return false;
    }
  }

  /// ⭐ ئایا دڵخوازە؟
  static Future<bool> isFavorite(String fuelType) async {
    final favorites = await getAll();
    return favorites.contains(fuelType);
  }
}