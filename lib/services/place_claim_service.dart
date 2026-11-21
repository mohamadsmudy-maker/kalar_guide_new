// lib/services/place_claim_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// داوایەکی «ئەم شوێنە هی منە» (بۆ ئەدمین)
class PlaceClaim {
  const PlaceClaim({
    required this.id,
    required this.storeId,
    this.storeName = '',
    this.userName = '',
    this.userPhone = '',
    this.note = '',
    this.createdAt,
  });

  final int id;
  final String storeId;
  final String storeName;
  final String userName;
  final String userPhone;
  final String note;
  final DateTime? createdAt;

  factory PlaceClaim.fromMap(Map<String, dynamic> m) => PlaceClaim(
        id: (m['id'] as num).toInt(),
        storeId: '${m['store_id']}',
        storeName: '${m['store_name'] ?? ''}',
        userName: '${m['user_name'] ?? ''}',
        userPhone: '${m['user_phone'] ?? ''}',
        note: '${m['note'] ?? ''}',
        createdAt: DateTime.tryParse('${m['created_at'] ?? ''}')?.toLocal(),
      );
}

/// 🏪 خاوەن شوێن داوا دەکات پەڕەی شوێنەکەی بەڕێوە ببات (مایگرەیشنی ٣٠)
class PlaceClaimService {
  PlaceClaimService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// 'ok' | 'duplicate' | 'not_found' | 'login' | 'already_owner'
  static Future<String> claim(Object storeId, {String? note}) async {
    final r = await _db.rpc('app_claim_place', params: {'p_store_id': '$storeId', 'p_note': note});
    return '$r';
  }

  static Future<List<PlaceClaim>> pending() async {
    final rows = await _db.rpc('app_pending_claims') as List;
    return [for (final r in rows) PlaceClaim.fromMap(Map<String, dynamic>.from(r as Map))];
  }

  static Future<bool> review(int claimId, {required bool approve}) async {
    final r = await _db.rpc('app_review_claim', params: {'p_claim_id': claimId, 'p_approve': approve});
    return r == 'ok';
  }
}
