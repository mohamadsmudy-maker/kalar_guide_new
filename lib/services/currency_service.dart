import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'price_save_result.dart';

import 'auth_service.dart';

/// 📊 بارودۆخی بازاڕ بۆ یەک جۆری دراو
class CurrencyMarket {
  final String type;

  /// نوسینگەی هەرزانترین نرخی فرۆشتن (باشترین بۆ کڕینی دراو)
  final Map<String, dynamic>? bestSell;

  /// نوسینگەی بەرزترین نرخی کڕین (باشترین بۆ فرۆشتنی دراو)
  final Map<String, dynamic>? bestBuy;

  final double avgSell;
  final double avgBuy;
  final double minSell;
  final double maxSell;
  final int stationCount;
  final DateTime? lastUpdated;

  /// دوایین گۆڕانکاری لە نرخی فرۆشتن (نوێ − کۆن)
  final double? lastChange;

  const CurrencyMarket({
    required this.type,
    this.bestSell,
    this.bestBuy,
    this.avgSell = 0,
    this.avgBuy = 0,
    this.minSell = 0,
    this.maxSell = 0,
    this.stationCount = 0,
    this.lastUpdated,
    this.lastChange,
  });

  bool get hasData => stationCount > 0;
  double? get bestSellPrice => (bestSell?['sell_price'] as num?)?.toDouble();
  double? get bestBuyPrice => (bestBuy?['buy_price'] as num?)?.toDouble();

  /// جیاوازی نێوان باشترین فرۆشتن و باشترین کڕین
  double? get spread {
    final s = bestSellPrice, b = bestBuyPrice;
    if (s == null || b == null || s <= 0 || b <= 0) return null;
    return s - b;
  }
}

/// 📦 هەموو داتای شاشەی سەرەکی بە یەک داواکاری
class CurrencySnapshot {
  final Map<String, CurrencyMarket> markets;
  final List<Map<String, dynamic>> prices;
  final List<Map<String, dynamic>> history;
  final DateTime fetchedAt;

  const CurrencySnapshot({
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

/// 💱 خزمەتگوزاری دراو — Single Source of Truth (ULTRA PRO MAX)
class CurrencyService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String _subCategory = 'نوسینگەی دراو';
  static const String _stationColumns =
      'id, name, phone, address, logo, image, currency_prices';

  // ═══════════════════════════════════════════════════════════
  // 🎯 جۆرەکانی دراو — یەک سەرچاوە بۆ هەموو شوێنێک
  //   per  = نرخەکە بۆ چەند یەکەیە (بۆ نموونە ١٠٠ دۆلار)
  //   unit = ناوی یەکەکە
  //   ⚠️ ئەگەر نوسینگەکان بە شێوەیەکی تر نرخ دادەنێن، تەنها `per` بگۆڕە
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> currencyTypes = [
    {
      'key': 'usd', 'symbol': '\$', 'flag': '🇺🇸', 'group': 'fiat', 'per': 100,
      'name_ku': 'دۆلاری ئەمەریکی', 'name_ar': 'دولار أمريكي', 'name_en': 'US Dollar',
      'unit_ku': 'دۆلار', 'unit_ar': 'دولار', 'unit_en': 'USD',
      'color': '#10B981', 'order': 1,
    },
    {
      'key': 'iqd', 'symbol': 'د.ع', 'flag': '🇮🇶', 'group': 'fiat', 'per': 1,
      'name_ku': 'دیناری عێراقی', 'name_ar': 'دينار عراقي', 'name_en': 'Iraqi Dinar',
      'unit_ku': 'دینار', 'unit_ar': 'دينار', 'unit_en': 'IQD',
      'color': '#14B8A6', 'order': 2,
    },
    {
      'key': 'eur', 'symbol': '€', 'flag': '🇪🇺', 'group': 'fiat', 'per': 100,
      'name_ku': 'یۆرۆ', 'name_ar': 'يورو', 'name_en': 'Euro',
      'unit_ku': 'یۆرۆ', 'unit_ar': 'يورو', 'unit_en': 'EUR',
      'color': '#1E88E5', 'order': 3,
    },
    {
      'key': 'gbp', 'symbol': '£', 'flag': '🇬🇧', 'group': 'fiat', 'per': 100,
      'name_ku': 'پاوەندی ئینگلیزی', 'name_ar': 'جنيه إسترليني', 'name_en': 'British Pound',
      'unit_ku': 'پاوەند', 'unit_ar': 'جنيه', 'unit_en': 'GBP',
      'color': '#8B5CF6', 'order': 4,
    },
    {
      'key': 'try', 'symbol': '₺', 'flag': '🇹🇷', 'group': 'fiat', 'per': 100,
      'name_ku': 'لیرەی تورکی', 'name_ar': 'ليرة تركية', 'name_en': 'Turkish Lira',
      'unit_ku': 'لیرە', 'unit_ar': 'ليرة', 'unit_en': 'TRY',
      'color': '#EF4444', 'order': 5,
    },
    {
      'key': 'aed', 'symbol': 'د.إ', 'flag': '🇦🇪', 'group': 'fiat', 'per': 100,
      'name_ku': 'دیرھەمی ئیماراتی', 'name_ar': 'درهم إماراتي', 'name_en': 'UAE Dirham',
      'unit_ku': 'دیرھەم', 'unit_ar': 'درهم', 'unit_en': 'AED',
      'color': '#F59E0B', 'order': 6,
    },
    {
      'key': 'gold_24', 'symbol': '24K', 'flag': '🥇', 'group': 'gold', 'per': 1,
      'name_ku': 'زێڕی ٢٤ عەیار', 'name_ar': 'ذهب عيار 24', 'name_en': 'Gold 24K',
      'unit_ku': 'مسقاڵ', 'unit_ar': 'مثقال', 'unit_en': 'mithqal',
      'color': '#FCD34D', 'order': 7,
    },
    {
      'key': 'gold_22', 'symbol': '22K', 'flag': '🥇', 'group': 'gold', 'per': 1,
      'name_ku': 'زێڕی ٢٢ عەیار', 'name_ar': 'ذهب عيار 22', 'name_en': 'Gold 22K',
      'unit_ku': 'مسقاڵ', 'unit_ar': 'مثقال', 'unit_en': 'mithqal',
      'color': '#FBBF24', 'order': 8,
    },
    {
      'key': 'gold_21', 'symbol': '21K', 'flag': '🥇', 'group': 'gold', 'per': 1,
      'name_ku': 'زێڕی ٢١ عەیار', 'name_ar': 'ذهب عيار 21', 'name_en': 'Gold 21K',
      'unit_ku': 'مسقاڵ', 'unit_ar': 'مثقال', 'unit_en': 'mithqal',
      'color': '#F59E0B', 'order': 9,
    },
    {
      'key': 'gold_18', 'symbol': '18K', 'flag': '🥇', 'group': 'gold', 'per': 1,
      'name_ku': 'زێڕی ١٨ عەیار', 'name_ar': 'ذهب عيار 18', 'name_en': 'Gold 18K',
      'unit_ku': 'مسقاڵ', 'unit_ar': 'مثقال', 'unit_en': 'mithqal',
      'color': '#D97706', 'order': 10,
    },
  ];

  static List<Map<String, String>> getCurrencyTypesForLang(String lang) {
    return currencyTypes.map((t) {
      return {
        'key': t['key'] as String,
        'name': _pick(t, 'name', lang),
        'color': t['color'] as String,
        'symbol': t['symbol'] as String,
        'flag': t['flag'] as String,
        'group': t['group'] as String,
        'unit': _pick(t, 'unit', lang),
      };
    }).toList();
  }

  static String _pick(Map<String, dynamic> t, String field, String lang) {
    final l = (lang == 'ar' || lang == 'en') ? lang : 'ku';
    return (t['${field}_$l'] ?? t['${field}_ku'] ?? t['key']).toString();
  }

  static Map<String, dynamic>? _type(String key) {
    final k = key.toLowerCase();
    for (final t in currencyTypes) {
      if (t['key'] == k) return t;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // 🏢 نوسینگەکانی دراو
  // ═══════════════════════════════════════════════════════════

  /// نوسینگەکان دەهێنێت — سەرەتا بە sub_category، ئەگەر نەبوو بە category
  static Future<List<Map<String, dynamic>>> _fetchStations({
    String columns = '*',
    String? phone,
  }) async {
    var q1 = _client.from('dukan').select(columns).eq('sub_category', _subCategory);
    if (phone != null) q1 = q1.eq('phone', phone);
    var res = await q1.order('name');

    if ((res as List).isEmpty) {
      var q2 = _client.from('dukan').select(columns).ilike('category', '%$_subCategory%');
      if (phone != null) q2 = q2.eq('phone', phone);
      res = await q2.order('name');
    }
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// ✅ وەرگرتنی هەموو نوسینگەکانی دراو
  static Future<List<Map<String, dynamic>>> getAllStations() async {
    try {
      return await _fetchStations();
    } catch (e) {
      debugPrint('❌ هەڵە لە getAllStations: $e');
      return [];
    }
  }

  /// ✅ وەرگرتنی نوسینگەکانی ڤێندەر بەپێی مۆبایل
  static Future<List<Map<String, dynamic>>> getVendorStations(String phone) async {
    try {
      if (phone.trim().isEmpty) return [];
      return await _fetchStations(phone: phone);
    } catch (e) {
      debugPrint('❌ هەڵە لە getVendorStations: $e');
      return [];
    }
  }

  /// ✅ وەرگرتنی نوسینگەیەک بە ID
  static Future<Map<String, dynamic>?> getStationById(int stationId) async {
    try {
      return await _client.from('dukan').select().eq('id', stationId).maybeSingle();
    } catch (e) {
      debugPrint('❌ هەڵە لە getStationById: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 دەسەڵات
  // ═══════════════════════════════════════════════════════════

  /// ئەدمین هەموو نوسینگەیەک، ڤێندەر تەنها نوسینگەی خۆی
  static bool canEditStation({dynamic stationId, String? stationPhone}) {
    if (AuthSessionManager.isAdmin) return true;
    if (AuthSessionManager.userRole != 'vendor') return false;

    final user = AuthSessionManager.currentUser;
    final storeId = AuthSessionManager.storeId?.toString();
    if (storeId != null && storeId.isNotEmpty && storeId == stationId?.toString()) {
      return true;
    }
    final phone = user?['phone']?.toString() ?? '';
    return phone.isNotEmpty && phone == (stationPhone ?? '');
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 نرخەکان
  // ═══════════════════════════════════════════════════════════

  static Map<String, dynamic>? _entry(
    Map<String, dynamic> station,
    String type,
    dynamic data,
  ) {
    if (data is! Map) return null;
    final buy = (data['buy'] as num?)?.toDouble() ?? 0;
    final sell = (data['sell'] as num?)?.toDouble() ?? 0;
    if (buy <= 0 && sell <= 0) return null;
    return {
      'station_id': station['id'],
      'station_name': station['name'],
      'station_phone': station['phone'],
      'station_address': station['address'],
      'station_logo': station['logo'],
      'station_image': station['image'],
      'currency_type': type,
      'buy_price': buy,
      'sell_price': sell,
      'updated_at': data['updated_at'],
      'unit': 'دینار',
    };
  }

  /// ✅ وەرگرتنی نرخەکانی ئێستا — هەموو نوسینگەکان
  static Future<List<Map<String, dynamic>>> getCurrentPrices({String? currencyType}) async {
    try {
      final stations = await _fetchStations(columns: _stationColumns);
      final list = <Map<String, dynamic>>[];

      for (final station in stations) {
        final prices = station['currency_prices'];
        if (prices is! Map) continue;

        if (currencyType != null && currencyType.isNotEmpty) {
          final e = _entry(station, currencyType, prices[currencyType]);
          if (e != null) list.add(e);
        } else {
          for (final entry in prices.entries) {
            final e = _entry(station, entry.key.toString(), entry.value);
            if (e != null) list.add(e);
          }
        }
      }

      // نرخی ٠ دەچێتە کۆتایی
      double key(Map<String, dynamic> m) {
        final s = m['sell_price'] as double;
        return s > 0 ? s : double.infinity;
      }

      list.sort((a, b) => key(a).compareTo(key(b)));
      return list;
    } catch (e) {
      debugPrint('❌ هەڵە لە getCurrentPrices: $e');
      return [];
    }
  }

  /// ✅ هەموو داتای شاشەی سەرەکی: باشترین نرخ، تێکڕا، گۆڕانکاری، کاتی نوێکردنەوە
  static Future<CurrencySnapshot> getMarketSnapshot({int monthsBack = 6}) async {
    final results = await Future.wait([
      getCurrentPrices(),
      getMonthlyHistory(monthsBack: monthsBack),
    ]);
    final prices = results[0];
    final history = results[1];

    // دوایین کاتی نوێکردنەوە بۆ هەر (نوسینگە + دراو) لە مێژووەوە
    final lastByStation = <String, DateTime>{};
    final lastChange = <String, double>{};
    for (final h in history) {
      final type = h['currency_type']?.toString() ?? '';
      final at = DateTime.tryParse(h['created_at']?.toString() ?? '');
      if (type.isEmpty || at == null) continue;

      lastByStation.putIfAbsent('${h['station_id']}|$type', () => at);

      if (!lastChange.containsKey(type)) {
        final oldSell = (h['old_sell_price'] as num?)?.toDouble();
        final newSell = (h['new_sell_price'] as num?)?.toDouble();
        if (oldSell != null && newSell != null && oldSell > 0 && newSell > 0) {
          lastChange[type] = newSell - oldSell;
        }
      }
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in prices) {
      final type = p['currency_type']?.toString() ?? '';
      if (type.isEmpty) continue;
      p['updated_at'] ??= lastByStation['${p['station_id']}|$type']?.toIso8601String();
      grouped.putIfAbsent(type, () => []).add(p);
    }

    final markets = <String, CurrencyMarket>{};
    for (final t in currencyTypes) {
      final type = t['key'] as String;
      final list = grouped[type] ?? const [];

      Map<String, dynamic>? bestSell, bestBuy;
      double sumSell = 0, sumBuy = 0, minSell = 0, maxSell = 0;
      int nSell = 0, nBuy = 0;
      DateTime? updated;

      for (final p in list) {
        final sell = p['sell_price'] as double;
        final buy = p['buy_price'] as double;
        if (sell > 0) {
          sumSell += sell;
          nSell++;
          if (bestSell == null || sell < (bestSell['sell_price'] as double)) bestSell = p;
          if (minSell == 0 || sell < minSell) minSell = sell;
          if (sell > maxSell) maxSell = sell;
        }
        if (buy > 0) {
          sumBuy += buy;
          nBuy++;
          if (bestBuy == null || buy > (bestBuy['buy_price'] as double)) bestBuy = p;
        }
        final at = DateTime.tryParse(p['updated_at']?.toString() ?? '');
        if (at != null && (updated == null || at.isAfter(updated))) updated = at;
      }

      markets[type] = CurrencyMarket(
        type: type,
        bestSell: bestSell,
        bestBuy: bestBuy,
        avgSell: nSell > 0 ? sumSell / nSell : 0,
        avgBuy: nBuy > 0 ? sumBuy / nBuy : 0,
        minSell: minSell,
        maxSell: maxSell,
        stationCount: list.length,
        lastUpdated: updated,
        lastChange: lastChange[type],
      );
    }

    return CurrencySnapshot(
      markets: markets,
      prices: prices,
      history: history,
      fetchedAt: DateTime.now(),
    );
  }

  /// ✅ نوسینگەکانی یەک دراو لەگەڵ کاتی دوایین نوێکردنەوە (بۆ داتای کۆنیش)
  static Future<List<Map<String, dynamic>>> getStationsForType(String currencyType) async {
    final results = await Future.wait([
      getCurrentPrices(currencyType: currencyType),
      _latestUpdatesForType(currencyType),
    ]);
    final prices = results[0] as List<Map<String, dynamic>>;
    final latest = results[1] as Map<String, String>;
    for (final p in prices) {
      p['updated_at'] ??= latest[p['station_id']?.toString()];
    }
    return prices;
  }

  static Future<Map<String, String>> _latestUpdatesForType(String currencyType) async {
    try {
      final res = await _client
          .from('currency_price_history')
          .select('station_id, created_at')
          .eq('currency_type', currencyType)
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

  /// ✅ وەرگرتنی نرخی نوسینگەیەک — بە هەموو جۆرەکان
  static Future<Map<String, dynamic>?> getStationPrices(int stationId) async {
    try {
      return await _client
          .from('dukan')
          .select(_stationColumns)
          .eq('id', stationId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ هەڵە لە getStationPrices: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 نوێکردنەوەی نرخ
  // ═══════════════════════════════════════════════════════════

  /// سەرەتا فەنکشنی سێرڤەر (app_update_currency_price)؛ ئەگەر هێشتا
  /// مایگرەیشنەکە جێبەجێ نەکرابێت، ڕێگەی کۆن بەکاردێت.
  static Future<PriceSaveResult> updatePrice({
    required int stationId,
    required String currencyType,
    required double newBuyPrice,
    required double newSellPrice,
    String? updatedByName,
    String? notes,
  }) async {
    PriceSaveResult.lastError = null;
    try {
      final res = await _client.rpc('app_update_currency_price', params: {
        'p_station_id': stationId,
        'p_type': currencyType,
        'p_buy': newBuyPrice,
        'p_sell': newSellPrice,
        'p_notes': notes,
      });
      final result = PriceSaveResult.fromServer(res);
      if (result == PriceSaveResult.failed) PriceSaveResult.noteError('server: $res');
      return result;
    } catch (e) {
      if (!isMissingRpc(e)) {
        debugPrint('❌ app_update_currency_price: $e');
      PriceSaveResult.noteError(e);
        return PriceSaveResult.failed;
      }
    }
    return _legacyUpdatePrice(
      stationId: stationId,
      currencyType: currencyType,
      newBuyPrice: newBuyPrice,
      newSellPrice: newSellPrice,
      updatedByName: updatedByName,
      notes: notes,
    );
  }

  static Future<PriceSaveResult> _legacyUpdatePrice({
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

      if (station == null) return PriceSaveResult.notFound;

      final currentPrices = station['currency_prices'] is Map
          ? Map<String, dynamic>.from(station['currency_prices'] as Map)
          : <String, dynamic>{};

      final currentData = currentPrices[currencyType];
      final oldBuy = (currentData is Map) ? (currentData['buy'] as num?)?.toDouble() : null;
      final oldSell = (currentData is Map) ? (currentData['sell'] as num?)?.toDouble() : null;

      currentPrices[currencyType] = {
        'buy': newBuyPrice,
        'sell': newSellPrice,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // RLS بە بێدەنگی ٠ ڕیز نوێ دەکاتەوە — بە select دەیناسینەوە
      final updated = await _client
          .from('dukan')
          .update({'currency_prices': currentPrices})
          .eq('id', stationId)
          .select('id');
      if ((updated as List).isEmpty) return PriceSaveResult.forbidden;

      await _client.from('currency_price_history').insert({
        'station_id': stationId,
        'currency_type': currencyType,
        'old_buy_price': oldBuy,
        'new_buy_price': newBuyPrice,
        'old_sell_price': oldSell,
        'new_sell_price': newSellPrice,
        'updated_by_name': updatedByName ?? AuthSessionManager.userName ?? 'نەناسراو',
        'notes': notes,
      });

      return PriceSaveResult.ok;
    } catch (e) {
      debugPrint('❌ هەڵە لە updatePrice: $e');
      PriceSaveResult.noteError(e);
      return isPermissionError(e) ? PriceSaveResult.forbidden : PriceSaveResult.failed;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 Realtime — هەر نرخێک گۆڕا، شاشەکان خۆیان نوێ دەبنەوە
  //   ⚠️ پێویستە Realtime بۆ خشتەی currency_price_history چالاک بێت
  // ═══════════════════════════════════════════════════════════

  static RealtimeChannel? subscribeToPriceChanges(String channelName, VoidCallback onChange) {
    try {
      return _client
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'currency_price_history',
            callback: (_) => onChange(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ currency realtime unavailable: $e');
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

  /// ✅ مێژووی نرخی نوسینگەیەک
  static Future<List<Map<String, dynamic>>> getStationPriceHistory({
    required int stationId,
    String? currencyType,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = _client.from('currency_price_history').select().eq('station_id', stationId);

      if (currencyType != null && currencyType.isNotEmpty) {
        query = query.eq('currency_type', currencyType);
      }
      if (from != null) query = query.gte('created_at', from.toIso8601String());
      if (to != null) query = query.lte('created_at', to.toIso8601String());

      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە لە getStationPriceHistory: $e');
      return [];
    }
  }

  /// ✅ مێژووی مانگانە
  static Future<List<Map<String, dynamic>>> getMonthlyHistory({int monthsBack = 3}) async {
    try {
      final from = DateTime.now().subtract(Duration(days: monthsBack * 30));
      final res = await _client
          .from('currency_price_history')
          .select('*, dukan(name)')
          .gte('created_at', from.toIso8601String())
          .order('created_at', ascending: false)
          .limit(2000);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ هەڵە لە getMonthlyHistory: $e');
      return [];
    }
  }

  /// ✅ مێژووی دراوێکی دیاریکراو
  static Future<List<Map<String, dynamic>>> getCurrencyHistory({required int stationId}) {
    return getStationPriceHistory(stationId: stationId);
  }

  /// ✅ هەموو مێژووی هەموو دراوەکان (بۆ Chart ی گشتی)
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

  static String getColorForType(String currencyType) =>
      (_type(currencyType)?['color'] ?? '#10B981') as String;

  static String getSymbol(String currencyType) =>
      (_type(currencyType)?['symbol'] ?? currencyType.toUpperCase()) as String;

  static String getFlag(String currencyType) => (_type(currencyType)?['flag'] ?? '💱') as String;

  static bool isGold(String currencyType) => _type(currencyType)?['group'] == 'gold';

  /// نرخەکە بۆ چەند یەکەیە (بۆ نموونە ١٠٠ دۆلار)
  static int getQuoteUnit(String currencyType) => (_type(currencyType)?['per'] as int?) ?? 1;

  static String getUnitName(String currencyType, String lang) {
    final t = _type(currencyType);
    return t == null ? currencyType : _pick(t, 'unit', lang);
  }

  static String getNameKu(String currencyType) => getNameByLang(currencyType, 'ku');
  static String getNameAr(String currencyType) => getNameByLang(currencyType, 'ar');
  static String getNameEn(String currencyType) => getNameByLang(currencyType, 'en');

  static String getNameByLang(String currencyType, String lang) {
    final t = _type(currencyType);
    return t == null ? currencyType : _pick(t, 'name', lang);
  }

  static int getOrder(String currencyType) => (_type(currencyType)?['order'] as int?) ?? 99;

  // ── ژمارە ──
  static const _easternDigits = '٠١٢٣٤٥٦٧٨٩';

  static String localizeDigits(String s, String lang) {
    if (lang == 'en') return s;
    return s.replaceAllMapped(RegExp(r'\d'), (m) => _easternDigits[int.parse(m[0]!)]);
  }

  /// 148500 → ١٤٨,٥٠٠
  static String formatPrice(num? value, String lang, {int decimals = 0}) {
    if (value == null || value == 0) return '--';
    final pattern = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
    return localizeDigits(NumberFormat(pattern, 'en').format(value), lang);
  }

  static Color hexToColor(String hex) {
    try {
      var h = hex.replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return const Color(0xFF0F9D7A);
    }
  }
}
