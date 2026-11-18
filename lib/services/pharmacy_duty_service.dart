// lib/services/pharmacy_duty_service.dart
//
// 💊 دەرمانخانەی ئێشکگر — خشتەی pharmacy_duty لە Supabase.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PharmacyDuty {
  final int id;
  final DateTime dutyDate;
  final int? dukanId;
  final String name;
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;
  final String note;

  const PharmacyDuty({
    required this.id,
    required this.dutyDate,
    required this.name,
    this.dukanId,
    this.phone = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.note = '',
  });

  bool get hasLocation =>
      latitude != null && longitude != null && latitude != 0 && longitude != 0;

  factory PharmacyDuty.fromMap(Map<String, dynamic> m) => PharmacyDuty(
        id: (m['id'] as num).toInt(),
        dutyDate: DateTime.parse(m['duty_date'].toString()),
        dukanId: (m['dukan_id'] as num?)?.toInt(),
        name: (m['name'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        address: (m['address'] ?? '').toString(),
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        note: (m['note'] ?? '').toString(),
      );
}

class PharmacyDutyService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// ئێشکگری شەو تا ئەم کاتژمێرەی بەیانی بەردەوامە
  static const int morningHour = 8;

  /// شەوی ئێشکگری ئێستا: پێش کاتژمێر ٨ی بەیانی هێشتا شەوی دوێنێیە
  static DateTime dutyNight(DateTime now) => now.hour < morningHour
      ? DateTime(now.year, now.month, now.day - 1)
      : DateTime(now.year, now.month, now.day);

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [days] شەو، لە [from] ـەوە
  static Future<List<PharmacyDuty>> fetchRange(DateTime from, int days) async {
    final to = DateTime(from.year, from.month, from.day + days - 1);
    final res = await _db
        .from('pharmacy_duty')
        .select()
        .gte('duty_date', dateKey(from))
        .lte('duty_date', dateKey(to))
        .order('duty_date')
        .order('name');
    return (res as List)
        .map((e) => PharmacyDuty.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// وشەکانی «دەرمانخانە» بە شێوازە جیاوازەکانی نووسین (ە/ه، عەرەبی، ئینگلیزی)
  static const List<String> pharmacyWords = ['دەرمان', 'ده‌رمان', 'دهرمان', 'صيدل', 'صیدل', 'pharm'];
  static const String _placeColumns = 'id, name, phone, address, latitude, longitude';

  static String _orFilter(List<String> columns) => [
        for (final w in pharmacyWords)
          for (final c in columns) '$c.ilike.*$w*',
      ].join(',');

  /// شوێنە تۆمارکراوەکان کە دەرمانخانەن (بۆ هەڵبژاردن لە ئەدمین)
  static Future<List<Map<String, dynamic>>> pharmacyPlaces() async {
    Future<List<Map<String, dynamic>>> run(List<String> cols) async {
      final res = await _db.from('dukan').select(_placeColumns).or(_orFilter(cols)).order('name').limit(300);
      return List<Map<String, dynamic>>.from(res as List);
    }

    try {
      return await run(['name', 'category', 'sub_category']);
    } on PostgrestException catch (e) {
      // داتابەیسێک کە ستوونی sub_category ی نییە
      debugPrint('⚠️ pharmacy places (sub_category?): ${e.message}');
      try {
        return await run(['name', 'category']);
      } catch (e) {
        debugPrint('⚠️ pharmacy places: $e');
        return [];
      }
    } catch (e) {
      debugPrint('⚠️ pharmacy places: $e');
      return [];
    }
  }

  /// گەڕان لە هەموو شوێنەکان بە ناو؛ بەتاڵ → تەنها دەرمانخانەکان
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final q = query.trim().replaceAll(RegExp(r'[,()*%]'), ' ').trim();
    if (q.isEmpty) return pharmacyPlaces();
    try {
      final res = await _db.from('dukan').select(_placeColumns).ilike('name', '%$q%').order('name').limit(50);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('⚠️ search places: $e');
      return [];
    }
  }

  static Future<void> add({
    required DateTime dutyDate,
    required String name,
    int? dukanId,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    String? note,
  }) async {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    await _db.from('pharmacy_duty').insert({
      'duty_date': dateKey(dutyDate),
      'name': name.trim(),
      'dukan_id': dukanId,
      'phone': clean(phone),
      'address': clean(address),
      'latitude': latitude,
      'longitude': longitude,
      'note': clean(note),
    });
  }

  static Future<void> delete(int id) async {
    await _db.from('pharmacy_duty').delete().eq('id', id);
  }
}
