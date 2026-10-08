import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🛢️ خزمەتگوزاری سووتەمەنی — Single Source of Truth
class FuelService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 🎯 جۆرەکانی سووتەمەنی — یەک سەرچاوە بۆ هەموو شوێنێک
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> fuelTypes = [
    {
      'key': 'normal',
      'name_ku': 'ئاسایی',
      'name_ar': 'عادي',
      'name_en': 'Normal',
      'color': '#1E88E5',
      'order': 1,
    },
    {
      'key': 'super',
      'name_ku': 'سوپەر',
      'name_ar': 'سوبر',
      'name_en': 'Super',
      'color': '#EF4444',
      'order': 2,
    },
    {
      'key': 'muhassen',
      'name_ku': 'محەسەن',
      'name_ar': 'محسن',
      'name_en': 'Muhassen',
      'color': '#F59E0B',
      'order': 3,
    },
    {
      'key': 'oil',
      'name_ku': 'زەیت',
      'name_ar': 'زيت',
      'name_en': 'Oil',
      'color': '#14B8A6',
      'order': 4,
    },
    {
      'key': 'iraqi_gas',
      'name_ku': 'گازی عێراقی',
      'name_ar': 'غاز عراقي',
      'name_en': 'Iraqi Gas',
      'color': '#10B981',
      'order': 5,
    },
    {
      'key': 'iranian_gas',
      'name_ku': 'گازی ئێرانی',
      'name_ar': 'غاز إيراني',
      'name_en': 'Iranian Gas',
      'color': '#8B5CF6',
      'order': 6,
    },
    {
      'key': 'gas',
      'name_ku': 'گاز',
      'name_ar': 'غاز',
      'name_en': 'Gas',
      'color': '#EC4899',
      'order': 7,
    },
  ];

  /// ✅ وەرگرتنی جۆرەکان بەپێی زمان
  static List<Map<String, String>> getFuelTypesForLang(String lang) {
    return fuelTypes.map((t) {
      String name;
      switch (lang) {
        case 'ar':
          name = t['name_ar'] as String;
          break;
        case 'en':
          name = t['name_en'] as String;
          break;
        default:
          name = t['name_ku'] as String;
      }
      return {
        'key': t['key'] as String,
        'name': name,
        'color': t['color'] as String,
      };
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 🏢 بەنزینخانەکان لە `dukan`
  // ═══════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getAllStations() async {
    try {
      final res = await _client
          .from('dukan')
          .select()
          .eq('category', 'سوتەمەنی')
          .order('name');

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVendorStations(
      String phone,
      ) async {
    try {
      final res = await _client
          .from('dukan')
          .select()
          .eq('category', 'سوتەمەنی')
          .eq('phone', phone)
          .order('name');

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 نرخەکان
  // ═══════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getCurrentPrices({
    String? fuelType,
  }) async {
    try {
      final res = await _client
          .from('dukan')
          .select('id, name, phone, address, logo, image, fuel_prices')
          .eq('category', 'سوتەمەنی');

      final list = <Map<String, dynamic>>[];

      for (final station in (res as List)) {
        final stationMap = Map<String, dynamic>.from(station);
        final prices = stationMap['fuel_prices'];

        if (prices is! Map) continue;

        if (fuelType != null && fuelType.isNotEmpty) {
          final price = prices[fuelType];
          if (price != null && price is num && price > 0) {
            list.add({
              'station_id': stationMap['id'],
              'station_name': stationMap['name'],
              'station_phone': stationMap['phone'],
              'station_address': stationMap['address'],
              'station_logo': stationMap['logo'],
              'station_image': stationMap['image'],
              'fuel_type': fuelType,
              'price': price.toDouble(),
              'unit': 'لیتر',
            });
          }
        } else {
          for (final entry in prices.entries) {
            final price = entry.value;
            if (price != null && price is num && price > 0) {
              list.add({
                'station_id': stationMap['id'],
                'station_name': stationMap['name'],
                'station_phone': stationMap['phone'],
                'station_address': stationMap['address'],
                'station_logo': stationMap['logo'],
                'station_image': stationMap['image'],
                'fuel_type': entry.key.toString(),
                'price': price.toDouble(),
                'unit': 'لیتر',
              });
            }
          }
        }
      }

      list.sort((a, b) =>
          (a['price'] as double).compareTo(b['price'] as double));

      return list;
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  /// ✅ وەرگرتنی نرخی بەنزینخانەیەک — بە هەموو جۆرەکان (تەنانەت بەتاڵیش)
  static Future<Map<String, dynamic>?> getStationPrices(int stationId) async {
    try {
      final res = await _client
          .from('dukan')
          .select('id, name, phone, address, logo, image, fuel_prices')
          .eq('id', stationId)
          .maybeSingle();

      return res;
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 نوێکردنەوەی نرخ
  // ═══════════════════════════════════════════════════════════

  static Future<bool> updatePrice({
    required int stationId,
    required String fuelType,
    required double newPrice,
    String? updatedByName,
    String? notes,
  }) async {
    try {
      final station = await _client
          .from('dukan')
          .select('fuel_prices')
          .eq('id', stationId)
          .maybeSingle();

      if (station == null) return false;

      final currentPrices = station['fuel_prices'] is Map
          ? Map<String, dynamic>.from(station['fuel_prices'] as Map)
          : <String, dynamic>{};

      final oldPrice = (currentPrices[fuelType] as num?)?.toDouble();
      currentPrices[fuelType] = newPrice;

      await _client
          .from('dukan')
          .update({'fuel_prices': currentPrices})
          .eq('id', stationId);

      await _client.from('fuel_price_history').insert({
        'station_id': stationId,
        'fuel_type': fuelType,
        'old_price': oldPrice,
        'new_price': newPrice,
        'updated_by_name': updatedByName ?? 'نەناسراو',
        'notes': notes,
      });

      return true;
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📜 مێژوو
  // ═══════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getStationPriceHistory({
    required int stationId,
    String? fuelType,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = _client
          .from('fuel_price_history')
          .select()
          .eq('station_id', stationId);

      if (fuelType != null) query = query.eq('fuel_type', fuelType);
      if (from != null) {
        query = query.gte('created_at', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('created_at', to.toIso8601String());
      }

      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMonthlyHistory({
    int monthsBack = 3,
  }) async {
    try {
      final from = DateTime.now().subtract(Duration(days: monthsBack * 30));

      final res = await _client
          .from('fuel_price_history')
          .select('*, dukan(name)')
          .gte('created_at', from.toIso8601String())
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════

  static String getColorForType(String fuelType) {
    final type = fuelTypes.firstWhere(
          (t) => t['key'] == fuelType,
      orElse: () => {'color': '#1E88E5'},
    );
    return type['color'] as String;
  }

  static String getNameKu(String fuelType) {
    final type = fuelTypes.firstWhere(
          (t) => t['key'] == fuelType,
      orElse: () => {'name_ku': fuelType},
    );
    return type['name_ku'] as String;
  }

  static String getNameAr(String fuelType) {
    final type = fuelTypes.firstWhere(
          (t) => t['key'] == fuelType,
      orElse: () => {'name_ar': fuelType},
    );
    return type['name_ar'] as String;
  }

  static String getNameEn(String fuelType) {
    final type = fuelTypes.firstWhere(
          (t) => t['key'] == fuelType,
      orElse: () => {'name_en': fuelType},
    );
    return type['name_en'] as String;
  }

  static String getNameByLang(String fuelType, String lang) {
    switch (lang) {
      case 'ar':
        return getNameAr(fuelType);
      case 'en':
        return getNameEn(fuelType);
      default:
        return getNameKu(fuelType);
    }
  }
}