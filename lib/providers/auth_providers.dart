import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../utils/password_hasher.dart'; // ⚠️ دڵنیابە ئەمە import کراوە

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  // ───────────────────────────────────────────────────────
  // 🔑 Login
  // ───────────────────────────────────────────────────────
  Future<AppUser?> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (response == null) return null;

      // ⚠️ دڵنیابە لەوەی کلیلەکە لە داتابەیسەکەتدا 'password_hash' ـە
      final storedHash = response['password_hash'] as String?;
      if (storedHash == null) return null;

      final isValid = PasswordHasher.verify(password, storedHash);
      if (!isValid) return null;

      return AppUser.fromJson(response);
    } catch (e) {
      debugPrint('❌ AuthRepository.login: $e');
      rethrow;
    }
  }

  // ───────────────────────────────────────────────────────
  // 🆕 SignUp
  // ───────────────────────────────────────────────────────
  Future<bool> signUp({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      // پشکنین ئەگەر مۆبایلەکە بەکارهاتووە
      final existing = await _client
          .from('users')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();
      if (existing != null) return false;

      final hashedPassword = PasswordHasher.hash(password);

      await _client.from('users').insert({
        'name': name,
        'phone': phone,
        'password_hash': hashedPassword,
        'role': 'customer', // ڕۆڵی سەرەتایی
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ AuthRepository.signUp: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────
  // 👤 Get User by Phone
  // ───────────────────────────────────────────────────────
  Future<AppUser?> getUserByPhone(String phone) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (response == null) return null;
      return AppUser.fromJson(response);
    } catch (e) {
      debugPrint('❌ AuthRepository.getUserByPhone: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 Change Password
  // ═══════════════════════════════════════════════════════════
  Future<bool> changePassword({
    required String phone,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // 1. پشکنین لەوەی پاسۆردی ئێستا ڕاستە بە هەمان شێوەی login
      final user = await login(phone: phone, password: currentPassword);
      if (user == null) return false;

      // 2. ئەگەر ڕاست بوو، پاسۆردی نوێ هاش بکە و پاشەکەوتی بکە
      final hashedNewPassword = PasswordHasher.hash(newPassword);

      await _client
          .from('users')
          .update({'password_hash': hashedNewPassword}).eq('phone', phone);

      return true;
    } catch (e) {
      debugPrint('❌ AuthRepository.changePassword: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑 Delete Account
  // ═══════════════════════════════════════════════════════════
  Future<bool> deleteAccount({required String phone}) async {
    try {
      await _client.from('users').delete().eq('phone', phone);
      return true;
    } catch (e) {
      debugPrint('❌ AuthRepository.deleteAccount: $e');
      return false;
    }
  }
}