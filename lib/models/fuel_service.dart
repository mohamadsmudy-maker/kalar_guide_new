import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fuel_price.dart';
import '../models/fuel_price_history.dart';
import '../models/fuel_station.dart';

/// 🛢️ خزمەتگوزاری سووتەمەنی — PRO
class FuelService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════
  // 🏢 بەنزینخانەکان
  // ═══════════════════════════════════════════════════

  static Future<List<FuelStation>> getAllStations() async {
    try {
      final res = await _client
          .from('fuel_stations')
          .select()
          .order('is_featured', ascending: false)
          .order('name_ku');

      return (res as List)
          .map((e) => FuelStation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  static Stream<List<FuelStation>> streamStations() {
    return _client
        .from('fuel_stations')
        .stream(primaryKey: ['id'])
        .order('name_ku')
        .map((data) => data.map((e) => FuelStation.fromJson(e)).toList());
  }

  static Future<bool> addStation(FuelStation station) async {
    try {
      await _client.from('fuel_stations').insert(station.toJson());
      return true;
    } catch (e) {
      debugPrint('❌ $e');
      return false;
    }
  }

  static Future<bool> updateStation(FuelStation station) async {
    if (station.id == null) return false;
    try {
      await _client
          .from('fuel_stations')
          .update(station.toJson())
          .eq('id', station.id!);
      return true;
    } catch (e) {
      debugPrint('❌ $e');
      return false;
    }
  }

  static Future<bool> deleteStation(int id) async {
    try {
      await _client.from('fuel_stations').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════
  // 💰 نرخەکان
  // ═══════════════════════════════════════════════════

  static Future<List<FuelPriceHistory>> getCurrentPrices({
    String? fuelType,
  }) async {
    try {
      var query = _client.from('current_fuel_prices').select();

      if (fuelType != null && fuelType.isNotEmpty) {
        query = query.eq('fuel_type', fuelType);
      }

      final res = await query.order('price', ascending: true);

      return (res as List)
          .map((e) => FuelPriceHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  static Future<List<FuelPriceHistory>> getStationPrices(int stationId) async {
    try {
      final res = await _client
          .from('current_fuel_prices')
          .select()
          .eq('station_id', stationId)
          .order('price');

      return (res as List)
          .map((e) => FuelPriceHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════
  // 💾 نوێکردنەوەی نرخ
  // ═══════════════════════════════════════════════════

  static Future<bool> updatePrice({
    required int stationId,
    required String fuelType,
    required double newPrice,
    String? updatedByName,
    String? notes,
  }) async {
    try {
      await _client.from('fuel_prices_history').insert({
        'station_id': stationId,
        'fuel_type': fuelType,
        'price': newPrice,
        'updated_by_name': updatedByName ?? 'نەناسراو',
        'notes': notes,
      });
      return true;
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return false;
    }
  }

  static Future<List<FuelPriceHistory>> getStationPriceHistory({
    required int stationId,
    String? fuelType,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = _client
          .from('fuel_prices_history')
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

      return (res as List)
          .map((e) => FuelPriceHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  static Future<List<FuelPriceHistory>> getMonthlyHistory({
    int monthsBack = 3,
  }) async {
    try {
      final from = DateTime.now().subtract(Duration(days: monthsBack * 30));

      final res = await _client
          .from('fuel_prices_history')
          .select()
          .gte('created_at', from.toIso8601String())
          .order('created_at', ascending: false);

      return (res as List)
          .map((e) => FuelPriceHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════

  static double? getPriceChangePercent(
      List<FuelPriceHistory> history,
      int index,
      ) {
    if (index >= history.length - 1) return null;
    final current = history[index].price;
    final previous = history[index + 1].price;
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  static String getColorForType(String fuelType) {
    switch (fuelType) {
      case 'normal': return '#1E88E5';
      case 'muhassen': return '#F59E0B';
      case 'super': return '#EF4444';
      case 'iraqi_gas': return '#10B981';
      case 'iranian_gas': return '#8B5CF6';
      case 'oil': return '#14B8A6';
      case 'gas': return '#EC4899';
      default: return '#1E88E5';
    }
  }
}