import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user.dart';
import '../../utils/password_hasher.dart';

/// 🔐 Repository بۆ Authentication — Data Layer
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  // ═══════════════════════════════════════════════════════════
  // 🔑 Login
  // ═══════════════════════════════════════════════════════════
  Future<AppUser?> login({
    required String phone,
    required String password,
  }) async {
    try {
      // ⭐ ١. لە app_users
      final userRes = await _client
          .from('app_users')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (userRes != null) {
        final storedPassword = userRes['password']?.toString() ?? '';
        if (!PasswordHasher.verify(password, storedPassword)) {
          debugPrint('❌ AuthRepository: پاسۆرد هەڵەیە');
          return null;
        }

        if (userRes['role'] == 'vendor' && userRes['is_approved'] != true) {
          debugPrint('⏳ AuthRepository: چاوەڕوانی پەسەندکردن');
          return AppUser(
            id: userRes['id']?.toString(),
            name: userRes['name']?.toString(),
            phone: phone,
            role: 'pending',
          );
        }

        return AppUser.fromJson(Map<String, dynamic>.from(userRes));
      }

      // ⭐ ٢. لە dukan
      final dukanRes = await _client
          .from('dukan')
          .select()
          .eq('user_phone', phone)
          .maybeSingle();

      if (dukanRes != null) {
        final storedPassword = dukanRes['password']?.toString() ?? '';
        if (!PasswordHasher.verify(password, storedPassword)) {
          return null;
        }

        if (dukanRes['is_approved'] != true) {
          return AppUser(
            id: dukanRes['id']?.toString(),
            name: dukanRes['name']?.toString(),
            phone: phone,
            role: 'pending',
          );
        }

        return AppUser(
          id: dukanRes['id']?.toString(),
          name: dukanRes['name']?.toString(),
          phone: phone,
          role: dukanRes['vendor_role']?.toString() ?? 'vendor',
          isApproved: true,
        );
      }

      return null;
    } catch (e) {
      debugPrint('❌ AuthRepository.login: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 وەرگرتنی پرۆفایل
  // ═══════════════════════════════════════════════════════════
  Future<AppUser?> getUserByPhone(String phone) async {
    try {
      final res = await _client
          .from('app_users')
          .select('id, name, phone, role, is_approved, created_at')
          .eq('phone', phone)
          .maybeSingle();

      if (res == null) return null;
      return AppUser.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('❌ AuthRepository.getUserByPhone: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✍️ زیادکردنی بەکارهێنەری نوێ
  // ═══════════════════════════════════════════════════════════
  Future<bool> signUp({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      final hashed = PasswordHasher.hash(password);

      await _client.from('app_users').insert({
        'name': name,
        'phone': phone,
        'password': hashed,
        'role': 'customer',
        'is_approved': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ AuthRepository.signUp: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 نوێکردنەوەی پاسۆرد
  // ═══════════════════════════════════════════════════════════
  Future<bool> updatePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _client.from('app_users').update({
        'password': PasswordHasher.hash(newPassword),
      }).eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('❌ AuthRepository.updatePassword: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ❤️ دڵخوازەکان
  // ═══════════════════════════════════════════════════════════
  Future<bool> isFavorite({
    required String userId,
    required String storeId,
  }) async {
    try {
      final res = await _client
          .from('favorite_stores')
          .select()
          .eq('user_id', userId)
          .eq('store_id', storeId)
          .maybeSingle();

      return res != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleFavorite({
    required String userId,
    required String storeId,
    required bool isFav,
  }) async {
    try {
      if (isFav) {
        await _client
            .from('favorite_stores')
            .delete()
            .eq('user_id', userId)
            .eq('store_id', storeId);
        return false;
      } else {
        await _client.from('favorite_stores').insert({
          'user_id': userId,
          'store_id': storeId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ AuthRepository.toggleFavorite: $e');
      return isFav;
    }
  }
}