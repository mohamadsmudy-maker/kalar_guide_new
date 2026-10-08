import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 💱 خزمەتگوزاری دراو — Single Source of Truth
class CurrencyService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 🎯 جۆرەکانی دراو — یەک سەرچاوە بۆ هەموو شوێنێک
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> currencyTypes = [
    {
      'key': 'usd',
      'name_ku': 'دۆلاری ئەمەریکی',
      'name_ar': 'دولار أمريكي',
      'name_en': 'US Dollar',
      'color': '#10B981',
      'order': 1,
    },
    {
      'key': 'iqd',
      'name_ku': 'دیناری عێراقی',
      'name_ar': 'دينار عراقي',
      'name_en': 'Iraqi Dinar',
      'color': '#14B8A6',
      'order': 2,
    },
    {
      'key': 'eur',
      'name_ku': 'یۆرۆ',
      'name_ar': 'يورو',
      'name_en': 'Euro',
      'color': '#1E88E5',
      'order': 3,
    },
    {
      'key': 'gbp',
      'name_ku': 'پاوەندی ئینگلیزی',
      'name_ar': 'جنيه إسترليني',
      'name_en': 'British Pound',
      'color': '#8B5CF6',
      'order': 4,
    },
    {
      'key': 'try',
      'name_ku': 'لیرەی تورکی',
      'name_ar': 'ليرة تركية',
      'name_en': 'Turkish Lira',
      'color': '#EF4444',
      'order': 5,
    },
    {
      'key': 'aed',
      'name_ku': 'دیرھەمی ئیماراتی',
      'name_ar': 'درهم إماراتي',
      'name_en': 'UAE Dirham',
      'color': '#F59E0B',
      'order': 6,
    },
    {
      'key': 'gold_24',
      'name_ku': 'زێڕی ٢٤ عەیار',
      'name_ar': 'ذهب عيار 24',
      'name_en': 'Gold 24K',
      'color': '#FCD34D',
      'order': 7,
    },
    {
      'key': 'gold_22',
      'name_ku': 'زێڕی ٢٢ عەیار',
      'name_ar': 'ذهب عيار 22',
      'name_en': 'Gold 22K',
      'color': '#FBBF24',
      'order': 8,
    },
    {
      'key': 'gold_21',
      'name_ku': 'زێڕی ٢١ عەیار',
      'name_ar': 'ذهب عيار 21',
      'name_en': 'Gold 21K',
      'color': '#F59E0B',
      'order': 9,
    },
    {
      'key': 'gold_18',
      'name_ku': 'زێڕی ١٨ عەیار',
      'name_ar': 'ذهب عيار 18',
      'name_en': 'Gold 18K',
      'color': '#D97706',
      'order': 10,
    },
  ];

  static List<Map<String, String>> getCurrencyTypesForLang(String lang) {
    return currencyTypes.map((t) {
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
  // 🏢 نوسینگەکانی دراو
  // ═══════════════════════════════════════════════════════════

  /// ✅ وەرگرتنی هەموو نوسینگەکانی دراو
  static Future<List<Map<String, dynamic>>> getAllStations() async {
    try {
      var res = await _client
          .from('dukan')
          .select()
          .eq('sub_category', 'نوسینگەی دراو')
          .order('name');

      if ((res as List).isEmpty) {
        res = await _client
            .from('dukan')
            .select()
            .ilike('category', '%نوسینگەی دراو%')
            .order('name');
      }

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە لە getAllStations: $e');
      return [];
    }
  }

  /// ✅ وەرگرتنی نوسینگەکانی ڤێندەر بەپێی مۆبایل
  static Future<List<Map<String, dynamic>>> getVendorStations(
      String phone) async {
    try {
      var res = await _client
          .from('dukan')
          .select()
          .eq('sub_category', 'نوسینگەی دراو')
          .eq('phone', phone)
          .order('name');

      if ((res as List).isEmpty) {
        res = await _client
            .from('dukan')
            .select()
            .ilike('category', '%نوسینگەی دراو%')
            .eq('phone', phone)
            .order('name');
      }

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە لە getVendorStations: $e');
      return [];
    }
  }

  /// ✅ وەرگرتنی نوسینگەیەک بە ID
  static Future<Map<String, dynamic>?> getStationById(int stationId) async {
    try {
      final res = await _client
          .from('dukan')
          .select()
          .eq('id', stationId)
          .maybeSingle();

      return res;
    } catch (e) {
      debugPrint('❌ هەڵە لە getStationById: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 نرخەکان
  // ═══════════════════════════════════════════════════════════

  /// ✅ وەرگرتنی نرخەکانی ئێستا — هەموو نوسینگەکان
  static Future<List<Map<String, dynamic>>> getCurrentPrices({
    String? currencyType,
  }) async {
    try {
      var res = await _client
          .from('dukan')
          .select('id, name, phone, address, logo, image, currency_prices')
          .eq('sub_category', 'نوسینگەی دراو');

      if ((res as List).isEmpty) {
        res = await _client
            .from('dukan')
            .select('id, name, phone, address, logo, image, currency_prices')
            .ilike('category', '%نوسینگەی دراو%');
      }

      final list = <Map<String, dynamic>>[];

      for (final station in (res as List)) {
        final stationMap = Map<String, dynamic>.from(station);
        final prices = stationMap['currency_prices'];

        if (prices is! Map) continue;

        if (currencyType != null && currencyType.isNotEmpty) {
          final data = prices[currencyType];
          if (data is Map) {
            final buy = (data['buy'] as num?)?.toDouble() ?? 0;
            final sell = (data['sell'] as num?)?.toDouble() ?? 0;
            if (buy > 0 || sell > 0) {
              list.add({
                'station_id': stationMap['id'],
                'station_name': stationMap['name'],
                'station_phone': stationMap['phone'],
                'station_address': stationMap['address'],
                'station_logo': stationMap['logo'],
                'station_image': stationMap['image'],
                'currency_type': currencyType,
                'buy_price': buy,
                'sell_price': sell,
                'unit': 'دینار',
              });
            }
          }
        } else {
          for (final entry in prices.entries) {
            final data = entry.value;
            if (data is! Map) continue;

            final buy = (data['buy'] as num?)?.toDouble() ?? 0;
            final sell = (data['sell'] as num?)?.toDouble() ?? 0;

            if (buy > 0 || sell > 0) {
              list.add({
                'station_id': stationMap['id'],
                'station_name': stationMap['name'],
                'station_phone': stationMap['phone'],
                'station_address': stationMap['address'],
                'station_logo': stationMap['logo'],
                'station_image': stationMap['image'],
                'currency_type': entry.key.toString(),
                'buy_price': buy,
                'sell_price': sell,
                'unit': 'دینار',
              });
            }
          }
        }
      }

      list.sort((a, b) =>
          (a['sell_price'] as double).compareTo(b['sell_price'] as double));

      return list;
    } catch (e) {
      debugPrint('❌ هەڵە لە getCurrentPrices: $e');
      return [];
    }
  }

  /// ✅ وەرگرتنی نرخی نوسینگەیەک — بە هەموو جۆرەکان
  static Future<Map<String, dynamic>?> getStationPrices(int stationId) async {
    try {
      final res = await _client
          .from('dukan')
          .select('id, name, phone, address, logo, image, currency_prices')
          .eq('id', stationId)
          .maybeSingle();

      return res;
    } catch (e) {
      debugPrint('❌ هەڵە لە getStationPrices: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 نوێکردنەوەی نرخ
  // ═══════════════════════════════════════════════════════════

  static Future<bool> updatePrice({
    required int stationId,
    required String currencyType,
    required double newBuyPrice,
    required double newSellPrice,
    String? updatedByName,
    String? notes,
  }) async {
    try {
      final station = await _client
          .from('dukan')
          .select('currency_prices')
          .eq('id', stationId)
          .maybeSingle();

      if (station == null) return false;

      final currentPrices = station['currency_prices'] is Map
          ? Map<String, dynamic>.from(station['currency_prices'] as Map)
          : <String, dynamic>{};

      final currentData = currentPrices[currencyType];
      final oldBuy = (currentData is Map)
          ? (currentData['buy'] as num?)?.toDouble()
          : null;
      final oldSell = (currentData is Map)
          ? (currentData['sell'] as num?)?.toDouble()
          : null;

      currentPrices[currencyType] = {
        'buy': newBuyPrice,
        'sell': newSellPrice,
      };

      await _client
          .from('dukan')
          .update({'currency_prices': currentPrices})
          .eq('id', stationId);

      await _client.from('currency_price_history').insert({
        'station_id': stationId,
        'currency_type': currencyType,
        'old_buy_price': oldBuy,
        'new_buy_price': newBuyPrice,
        'old_sell_price': oldSell,
        'new_sell_price': newSellPrice,
        'updated_by_name': updatedByName ?? 'نەناسراو',
        'notes': notes,
      });

      return true;
    } catch (e) {
      debugPrint('❌ هەڵە لە updatePrice: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📜 مێژوو
  // ═══════════════════════════════════════════════════════════

  /// ✅ مێژووی نرخی نوسینگەیەک
  static Future<List<Map<String, dynamic>>> getStationPriceHistory({
    required int stationId,
    String? currencyType,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = _client
          .from('currency_price_history')
          .select()
          .eq('station_id', stationId);

      if (currencyType != null && currencyType.isNotEmpty) {
        query = query.eq('currency_type', currencyType);
      }
      if (from != null) {
        query = query.gte('created_at', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('created_at', to.toIso8601String());
      }

      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە لە getStationPriceHistory: $e');
      return [];
    }
  }

  /// ✅ مێژووی مانگانە
  static Future<List<Map<String, dynamic>>> getMonthlyHistory({
    int monthsBack = 3,
  }) async {
    try {
      final from = DateTime.now().subtract(Duration(days: monthsBack * 30));

      final res = await _client
          .from('currency_price_history')
          .select('*, dukan(name)')
          .gte('created_at', from.toIso8601String())
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە لە getMonthlyHistory: $e');
      return [];
    }
  }

  /// ✅ نوێ: مێژووی دراوێکی دیاریکراو
  static Future<List<Map<String, dynamic>>> getCurrencyHistory({
    required int stationId,
  }) async {
    try {
      final res = await _client
          .from('currency_price_history')
          .select()
          .eq('station_id', stationId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ getCurrencyHistory: $e');
      return [];
    }
  }

  /// ✅ نوێ: هەموو مێژووی هەموو دراوەکان (بۆ Chart ی گشتی)
  static Future<List<Map<String, dynamic>>> getAllHistory() async {
    try {
      final res = await _client
          .from('currency_price_history')
          .select('*, dukan(name)')
          .order('created_at', ascending: false)
          .limit(500);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ getAllHistory: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════

  static String getColorForType(String currencyType) {
    final type = currencyTypes.firstWhere(
          (t) => t['key'] == currencyType,
      orElse: () => {'color': '#10B981'},
    );
    return type['color'] as String;
  }

  static String getNameKu(String currencyType) {
    final type = currencyTypes.firstWhere(
          (t) => t['key'] == currencyType,
      orElse: () => {'name_ku': currencyType},
    );
    return type['name_ku'] as String;
  }

  static String getNameAr(String currencyType) {
    final type = currencyTypes.firstWhere(
          (t) => t['key'] == currencyType,
      orElse: () => {'name_ar': currencyType},
    );
    return type['name_ar'] as String;
  }

  static String getNameEn(String currencyType) {
    final type = currencyTypes.firstWhere(
          (t) => t['key'] == currencyType,
      orElse: () => {'name_en': currencyType},
    );
    return type['name_en'] as String;
  }

  static String getNameByLang(String currencyType, String lang) {
    switch (lang) {
      case 'ar':
        return getNameAr(currencyType);
      case 'en':
        return getNameEn(currencyType);
      default:
        return getNameKu(currencyType);
    }
  }
}