// lib/services/app_settings_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ⚙️ ڕێکخستنە گشتییەکانی ئەپ (Supabase: app_settings) — ئەدمین دەیانگۆڕێت
class AppSettingsService {
  AppSettingsService._();

  static const String placeSuggestions = 'place_suggestions_enabled';

  static final Map<String, Object?> _cache = {};

  /// true/false؛ ئەگەر خشتەکە نەبوو یان هەڵە ڕوویدا → [fallback]
  static Future<bool> isOn(String key, {bool fallback = false, bool refresh = false}) async {
    if (!refresh && _cache.containsKey(key)) return _cache[key] == true;
    try {
      final row = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final on = row?['value'] == true;
      _cache[key] = on;
      return on;
    } catch (e) {
      debugPrint('⚠️ app_settings $key: $e');
      return fallback;
    }
  }

  /// تەنها ئەدمین (RLS). true = پاشەکەوت کرا
  static Future<bool> set(String key, bool on) async {
    try {
      await Supabase.instance.client.from('app_settings').upsert({
        'key': key,
        'value': on,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _cache[key] = on;
      return true;
    } catch (e) {
      debugPrint('⚠️ app_settings set $key: $e');
      return false;
    }
  }
}
