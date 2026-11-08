// lib/services/fuel_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'price_save_result.dart';

import 'auth_service.dart';

/// 📊 بارودۆخی بازاڕ بۆ یەک جۆری سووتەمەنی
class FuelMarket {
  final String type;
  final Map<String, dynamic>? cheapest;
  final Map<String, dynamic>? mostExpensive;
  final double avg;
  final int stationCount;
  final DateTime? lastUpdated;

  /// دوایین گۆڕانکاری (نوێ − کۆن)
  final double? lastChange;

  const FuelMarket({
    required this.type,
    this.cheapest,
    this.mostExpensive,
    this.avg = 0,
    this.stationCount = 0,
    this.lastUpdated,
    this.lastChange,
  });

  bool get hasData => stationCount > 0;
  double? get minPrice => (cheapest?['price'] as num?)?.toDouble();
  double? get maxPrice => (mostExpensive?['price'] as num?)?.toDouble();

  /// چەند پارە پاشەکەوت دەکەیت ئەگەر لە هەرزانترین بکڕیت نەک گرانترین
  double? get saving {
    final a = minPrice, b = maxPrice;
    if (a == null || b == null || b <= a) return null;
    return b - a;
  }
}

class FuelSnapshot {
  final Map<String, FuelMarket> markets;
  final List<Map<String, dynamic>> prices;
  final List<Map<String, dynamic>> history;
  final DateTime fetchedAt;

  const FuelSnapshot({
    required this.markets,
    required this.prices,
    required this.history,
    required this.fetchedAt,
  });

  DateTime? get lastUpdated {
    DateTime? latest;
    for (final m in markets.values) {
      final d = m.lastUpdated;
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    return latest;
  }
}

/// 🛢️ خزمەتگوزاری سووتەمەنی — ULTRA PRO MAX
class FuelService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// بەنزینخانەکان لە داتابەیسدا بە چەند ناوێک تۆمار کراون
  /// (بۆ نموونە «بەنزینخانەکان» یان «سوتەمەنی»)، لە category یان sub_category.
  /// هەر شوێنێک یەکێک لەم وشانەی تێدابێت بەنزینخانەیە.
  static const List<String> stationKeywords = ['بەنزین', 'سوتەمەنی', 'سووتەمەنی'];

  /// فلتەری PostgREST بۆ `.or(...)`
  static String get stationFilter => [
        for (final k in stationKeywords) ...['category.ilike.*$k*', 'sub_category.ilike.*$k*'],
      ].join(',');

  /// ئەگەر ستوونی sub_category لە داتابەیسدا نەبێت، تەنها category
  static String get _categoryOnlyFilter =>
      [for (final k in stationKeywords) 'category.ilike.*$k*'].join(',');

  static Future<List<Map<String, dynamic>>> _stations(String columns, {String? phone}) async {
    Future<List> run(String filter) {
      var q = _client.from('dukan').select(columns).or(filter);
      if (phone != null) q = q.eq('phone', phone);
      return q.order('name');
    }

    List res;
    try {
      res = await run(stationFilter);
    } on PostgrestException catch (e) {
      debugPrint('⚠️ fuel stations (sub_category?): ${e.message}');
      res = await run(_categoryOnlyFilter);
    }
    return List<Map<String, dynamic>>.from(res);
  }

  /// بۆ پشکنینی شوێنێک کە پێشتر هێنراوە
  static bool isStation(Map<String, dynamic> row) {
    final c = '${row['category'] ?? ''} ${row['sub_category'] ?? ''}';
    return stationKeywords.any(c.contains);
  }
  static const String _stationColumns =
      'id, name, phone, address, logo, image, latitude, longitude, fuel_prices';

  // ═══════════════════════════════════════════════════════════
  // 🎯 جۆرەکانی سووتەمەنی
  //   group: fuel | gas      unit: یەکەی نرخ
  //   ⚠️ ئەگەر نرخی گاز بۆ بوتڵ نییە، unit_* بگۆڕە
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> fuelTypes = [
    {
      'key': 'normal', 'name_ku': 'ئاسایی', 'name_ar': 'عادي', 'name_en': 'Normal',
      'color': '#1E88E5', 'order': 1, 'group': 'fuel', 'emoji': '⛽',
      'unit_ku': 'لیتر', 'unit_ar': 'لتر', 'unit_en': 'L',
    },
    {
      'key': 'super', 'name_ku': 'سوپەر', 'name_ar': 'سوبر', 'name_en': 'Super',
      'color': '#EF4444', 'order': 2, 'group': 'fuel', 'emoji': '🔥',
      'unit_ku': 'لیتر', 'unit_ar': 'لتر', 'unit_en': 'L',
    },
    {
      'key': 'muhassen', 'name_ku': 'محەسەن', 'name_ar': 'محسن', 'name_en': 'Muhassen',
      'color': '#F59E0B', 'order': 3, 'group': 'fuel', 'emoji': '✨',
      'unit_ku': 'لیتر', 'unit_ar': 'لتر', 'unit_en': 'L',
    },
    {
      'key': 'oil', 'name_ku': 'زەیت', 'name_ar': 'زيت', 'name_en': 'Oil',
      'color': '#14B8A6', 'order': 4, 'group': 'fuel', 'emoji': '🛢️',
      'unit_ku': 'لیتر', 'unit_ar': 'لتر', 'unit_en': 'L',
    },
    {
      'key': 'iraqi_gas', 'name_ku': 'گازی عێراقی', 'name_ar': 'غاز عراقي', 'name_en': 'Iraqi Gas',
      'color': '#10B981', 'order': 5, 'group': 'gas', 'emoji': '🔵',
      'unit_ku': 'بوتڵ', 'unit_ar': 'قنينة', 'unit_en': 'cylinder',
    },
    {
      'key': 'iranian_gas', 'name_ku': 'گازی ئێرانی', 'name_ar': 'غاز إيراني', 'name_en': 'Iranian Gas',
      'color': '#8B5CF6', 'order': 6, 'group': 'gas', 'emoji': '🟣',
      'unit_ku': 'بوتڵ', 'unit_ar': 'قنينة', 'unit_en': 'cylinder',
    },
    {
      'key': 'gas', 'name_ku': 'گاز', 'name_ar': 'غاز', 'name_en': 'Gas',
      'color': '#EC4899', 'order': 7, 'group': 'gas', 'emoji': '🔴',
      'unit_ku': 'بوتڵ', 'unit_ar': 'قنينة', 'unit_en': 'cylinder',
    },
  ];

  static String _pick(Map<String, dynamic> t, String field, String lang) {
    final l = (lang == 'ar' || lang == 'en') ? lang : 'ku';
    return (t['${field}_$l'] ?? t['${field}_ku'] ?? t['key']).toString();
  }

  static Map<String, dynamic>? _type(String key) {
    for (final t in fuelTypes) {
      if (t['key'] == key) return t;
    }
    return null;
  }

  static List<Map<String, String>> getFuelTypesForLang(String lang) {
    return fuelTypes.map((t) {
      return {
        'key': t['key'] as String,
        'name': _pick(t, 'name', lang),
        'color': t['color'] as String,
        'group': t['group'] as String,
        'emoji': t['emoji'] as String,
        'unit': _pick(t, 'unit', lang),
      };
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 🏢 بەنزینخانەکان
  // ═══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getAllStations() async {
    try {
      return await _stations('*');
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی بەنزینخانەکان: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVendorStations(String phone) async {
    try {
      if (phone.trim().isEmpty) return [];
      return await _stations('*', phone: phone);
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی بەنزینخانەکانی فرۆشیار: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 دەسەڵات — ئەدمین هەموو، ڤێندەر تەنها هی خۆی
  // ═══════════════════════════════════════════════════════════
  static bool canEditStation({dynamic stationId, String? stationPhone}) {
    if (AuthSessionManager.isAdmin) return true;
    if (AuthSessionManager.userRole != 'vendor') return false;

    final storeId = AuthSessionManager.storeId?.toString();
    if (storeId != null && storeId.isNotEmpty && storeId == stationId?.toString()) return true;

    final phone = AuthSessionManager.currentUser?['phone']?.toString() ?? '';
    return phone.isNotEmpty && phone == (stationPhone ?? '');
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 نرخەکان
  // ═══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getCurrentPrices({String? fuelType}) async {
    try {
      final res = await _stations(_stationColumns);
      final list = <Map<String, dynamic>>[];

      for (final station in (res as List)) {
        final stationMap = Map<String, dynamic>.from(station);
        final prices = stationMap['fuel_prices'];
        if (prices is! Map || prices.isEmpty) continue;

        if (fuelType != null && fuelType.isNotEmpty) {
          final price = prices[fuelType];
          if (price is num && price > 0) {
            list.add(_mapStationWithPrice(stationMap, fuelType, price.toDouble()));
          }
        } else {
          for (final entry in prices.entries) {
            final price = entry.value;
            if (price is num && price > 0) {
              list.add(_mapStationWithPrice(stationMap, entry.key.toString(), price.toDouble()));
            }
          }
        }
      }

      list.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
      return list;
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی نرخەکان: $e');
      return [];
    }
  }

  static Map<String, dynamic> _mapStationWithPrice(
    Map<String, dynamic> station,
    String type,
    double price,
  ) {
    return {
      'station_id': station['id'],
      'station_name': station['name'],
      'station_phone': station['phone'],
      'station_address': station['address'],
      'station_logo': station['logo'],
      'station_image': station['image'],
      // ✅ پێشتر نەدەهێنران — بۆیە نەخشەکە هیچ نیشانەیەکی نەبوو
      'latitude': station['latitude'],
      'longitude': station['longitude'],
      'fuel_type': type,
      'price': price,
      'unit': 'لیتر',
    };
  }

  /// ✅ هەموو داتای شاشەی سەرەکی بە یەک جار
  static Future<FuelSnapshot> getMarketSnapshot({int monthsBack = 6}) async {
    final results = await Future.wait([
      getCurrentPrices(),
      getMonthlyHistory(monthsBack: monthsBack),
    ]);
    final prices = results[0];
    final history = results[1];

    final lastByStation = <String, DateTime>{};
    final lastChange = <String, double>{};
    for (final h in history) {
      final type = h['fuel_type']?.toString() ?? '';
      final at = DateTime.tryParse(h['created_at']?.toString() ?? '');
      if (type.isEmpty || at == null) continue;
      lastByStation.putIfAbsent('${h['station_id']}|$type', () => at);
      if (!lastChange.containsKey(type)) {
        final o = (h['old_price'] as num?)?.toDouble();
        final n = (h['new_price'] as num?)?.toDouble();
        if (o != null && n != null && o > 0 && n > 0) lastChange[type] = n - o;
      }
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in prices) {
      final type = p['fuel_type']?.toString() ?? '';
      if (type.isEmpty) continue;
      p['updated_at'] ??= lastByStation['${p['station_id']}|$type']?.toIso8601String();
      grouped.putIfAbsent(type, () => []).add(p);
    }

    final markets = <String, FuelMarket>{};
    for (final t in fuelTypes) {
      final type = t['key'] as String;
      final list = grouped[type] ?? const <Map<String, dynamic>>[];
      Map<String, dynamic>? min, max;
      double sum = 0;
      DateTime? updated;
      for (final p in list) {
        final price = p['price'] as double;
        sum += price;
        if (min == null || price < (min['price'] as double)) min = p;
        if (max == null || price > (max['price'] as double)) max = p;
        final at = DateTime.tryParse(p['updated_at']?.toString() ?? '');
        if (at != null && (updated == null || at.isAfter(updated))) updated = at;
      }
      markets[type] = FuelMarket(
        type: type,
        cheapest: min,
        mostExpensive: max,
        avg: list.isEmpty ? 0 : sum / list.length,
        stationCount: list.length,
        lastUpdated: updated,
        lastChange: lastChange[type],
      );
    }

    return FuelSnapshot(markets: markets, prices: prices, history: history, fetchedAt: DateTime.now());
  }

  /// ✅ بەنزینخانەکانی یەک جۆر لەگەڵ کاتی دوایین نوێکردنەوە
  static Future<List<Map<String, dynamic>>> getStationsForType(String fuelType) async {
    final results = await Future.wait([
      getCurrentPrices(fuelType: fuelType),
      _latestUpdatesForType(fuelType),
    ]);
    final prices = results[0] as List<Map<String, dynamic>>;
    final latest = results[1] as Map<String, String>;
    for (final p in prices) {
      p['updated_at'] ??= latest[p['station_id']?.toString()];
    }
    return prices;
  }

  static Future<Map<String, String>> _latestUpdatesForType(String fuelType) async {
    try {
      final res = await _client
          .from('fuel_price_history')
          .select('station_id, created_at')
          .eq('fuel_type', fuelType)
          .order('created_at', ascending: false)
          .limit(500);
      final map = <String, String>{};
      for (final r in (res as List)) {
        map.putIfAbsent(r['station_id'].toString(), () => r['created_at'].toString());
      }
      return map;
    } catch (e) {
      debugPrint('⚠️ _latestUpdatesForType: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>?> getStationPrices(int stationId) async {
    try {
      return await _client.from('dukan').select(_stationColumns).eq('id', stationId).maybeSingle();
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی نرخی بەنزینخانە: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 نوێکردنەوەی نرخ
  // ═══════════════════════════════════════════════════════════
  /// سەرەتا فەنکشنی سێرڤەر (app_update_fuel_price)؛ ئەگەر هێشتا
  /// مایگرەیشنەکە جێبەجێ نەکرابێت، ڕێگەی کۆن بەکاردێت.
  static Future<PriceSaveResult> updatePrice({
    required int stationId,
    required String fuelType,
    required double newPrice,
    String? updatedByName,
    String? notes,
  }) async {
    try {
      final res = await _client.rpc('app_update_fuel_price', params: {
        'p_station_id': stationId,
        'p_type': fuelType,
        'p_price': newPrice,
        'p_notes': notes,
      });
      return PriceSaveResult.fromServer(res);
    } catch (e) {
      if (!isMissingRpc(e)) {
        debugPrint('❌ app_update_fuel_price: $e');
        return PriceSaveResult.failed;
      }
    }

    try {
      final station = await _client.from('dukan').select('fuel_prices').eq('id', stationId).maybeSingle();
      if (station == null) return PriceSaveResult.notFound;

      final currentPrices = station['fuel_prices'] is Map
          ? Map<String, dynamic>.from(station['fuel_prices'] as Map)
          : <String, dynamic>{};

      final oldPrice = (currentPrices[fuelType] as num?)?.toDouble();
      currentPrices[fuelType] = newPrice;

      // RLS بە بێدەنگی ٠ ڕیز نوێ دەکاتەوە — بە select دەیناسینەوە
      final updated = await _client
          .from('dukan')
          .update({'fuel_prices': currentPrices})
          .eq('id', stationId)
          .select('id');
      if ((updated as List).isEmpty) return PriceSaveResult.forbidden;

      await _client.from('fuel_price_history').insert({
        'station_id': stationId,
        'fuel_type': fuelType,
        'old_price': oldPrice,
        'new_price': newPrice,
        'updated_by_name': updatedByName ?? AuthSessionManager.userName ?? 'نەناسراو',
        'notes': notes,
      });
      return PriceSaveResult.ok;
    } catch (e) {
      debugPrint('❌ هەڵە لە نوێکردنەوەی نرخ: $e');
      return isPermissionError(e) ? PriceSaveResult.forbidden : PriceSaveResult.failed;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 Realtime — ⚠️ پێویستە Realtime بۆ fuel_price_history چالاک بێت
  // ═══════════════════════════════════════════════════════════
  static RealtimeChannel? subscribeToPriceChanges(String channelName, VoidCallback onChange) {
    try {
      return _client
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'fuel_price_history',
            callback: (_) => onChange(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ fuel realtime unavailable: $e');
      return null;
    }
  }

  static Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      await _client.removeChannel(channel);
    } catch (_) {}
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
      var query = _client.from('fuel_price_history').select().eq('station_id', stationId);
      if (fuelType != null) query = query.eq('fuel_type', fuelType);
      if (from != null) query = query.gte('created_at', from.toIso8601String());
      if (to != null) query = query.lte('created_at', to.toIso8601String());
      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی مێژووی بەنزینخانە: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMonthlyHistory({int monthsBack = 3}) async {
    try {
      final from = DateTime.now().subtract(Duration(days: monthsBack * 30));
      final res = await _client
          .from('fuel_price_history')
          .select('*, dukan(name)')
          .gte('created_at', from.toIso8601String())
          .order('created_at', ascending: false)
          .limit(2000);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی مێژووی مانگانە: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  static String getColorForType(String fuelType) => (_type(fuelType)?['color'] ?? '#1E88E5') as String;
  static String getEmoji(String fuelType) => (_type(fuelType)?['emoji'] ?? '⛽') as String;
  static bool isGas(String fuelType) => _type(fuelType)?['group'] == 'gas';
  static int getOrder(String fuelType) => (_type(fuelType)?['order'] as int?) ?? 99;

  static String getUnitName(String fuelType, String lang) {
    final t = _type(fuelType);
    return t == null ? 'لیتر' : _pick(t, 'unit', lang);
  }

  static String getNameKu(String fuelType) => getNameByLang(fuelType, 'ku');
  static String getNameAr(String fuelType) => getNameByLang(fuelType, 'ar');
  static String getNameEn(String fuelType) => getNameByLang(fuelType, 'en');

  static String getNameByLang(String fuelType, String lang) {
    final t = _type(fuelType);
    return t == null ? fuelType : _pick(t, 'name', lang);
  }
}
