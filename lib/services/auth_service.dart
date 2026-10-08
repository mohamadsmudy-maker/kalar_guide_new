import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import '../utils/password_hasher.dart';
import 'rate_limiter.dart';

/// 🔐 بەڕێوەبردنی دانیشتن و ئەکاونتی بەکارهێنەر — PRO EDITION v4
/// ✅ Security fixes: Plaintext (Debug only) + Rate Limiting + Auto-upgrade
class AuthSessionManager {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  static String? _cachedPhone;
  static bool _isInitialized = false;

  static final ValueNotifier<Map<String, dynamic>?> userNotifier =
  ValueNotifier(null);

  static String _userRole = 'customer';
  static String? _userName;
  static dynamic _currentId;

  // ═══════════════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════════════
  static bool get isInitialized => _isInitialized;

  static String get userRole => _userRole;
  static String? get userName => _userName;
  static dynamic get currentId => _currentId;

  static bool get isAdmin => _userRole == 'admin';
  static bool get isVendor => _userRole == 'vendor' || isAdmin;
  static bool get isCustomer => _userRole == 'customer';
  static bool get isLoggedIn => _cachedPhone != null || _currentId != null;

  /// ✅ ڕێگەدان بە دەستکاریکردنی نرخ
  static bool get canEditPrices => isAdmin || isVendor;

  static Map<String, dynamic>? get currentUser {
    if (!isLoggedIn) return null;
    return {
      'id': _currentId ?? _cachedPhone,
      'phone': _cachedPhone,
      'name': _userName,
      'role': _userRole,
    };
  }

  static Map<String, dynamic>? get cachedProfile => userNotifier.value;

  // ═══════════════════════════════════════════════════════════
  // 🔐 پشکنینی پاسۆرد — ✅ Security Fix
  // ═══════════════════════════════════════════════════════════
  static bool verifyPassword(String inputPassword, String storedPassword) {
    if (storedPassword.isEmpty || inputPassword.isEmpty) return false;

    // ═══════════════════════════════════════════════════════════
    // 🔓 Plaintext Match — ⚠️ تەنها لە Debug Mode کار دەکات
    // ═══════════════════════════════════════════════════════════
    // ⚠️ لە Release دا ئەم کۆدە ناکارا دەبێت — پاراستن لە Backdoor
    // ⚠️ پاسۆردی ڕووت لە داتابەیس نابێت هەبێت
    if (kDebugMode && storedPassword == inputPassword) {
      AppLogger.w('⚠️ Plaintext password found in DB! Upgrade needed');
      return true;
    }

    // ⭐ ١. SHA-256 + Salt (نوێترین)
    try {
      final sha256Hash = PasswordHasher.hash(inputPassword);
      if (storedPassword == sha256Hash) {
        AppLogger.d('🔐 SHA-256 + Salt match');
        return true;
      }
    } catch (e) {
      AppLogger.w('SHA-256 error: $e');
    }

    // ⭐ ٢. Legacy SHA-256 (بەبێ Salt)
    try {
      final legacyHash = _legacySha256(inputPassword);
      if (storedPassword == legacyHash) {
        AppLogger.d('🔐 Legacy SHA-256 match');
        return true;
      }
    } catch (_) {}

    AppLogger.w('❌ No password match found');
    return false;
  }

  static String _legacySha256(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 نوێکردنەوەی پاسۆردی کۆن بۆ SHA-256 + Salt
  // ═══════════════════════════════════════════════════════════
  static Future<void> _upgradePasswordIfNeeded({
    required String userId,
    required String plainPassword,
    required String storedPassword,
    String tableName = 'app_users',
  }) async {
    try {
      final currentHash = PasswordHasher.hash(plainPassword);
      if (storedPassword == currentHash) {
        AppLogger.d('✅ Password already upgraded');
        return;
      }

      await Supabase.instance.client
          .from(tableName)
          .update({'password': currentHash})
          .eq('id', userId);

      AppLogger.i('🔄 Password upgraded to SHA-256 + Salt');
    } catch (e) {
      AppLogger.w('⚠️ Upgrade password error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 initSession
  // ═══════════════════════════════════════════════════════════
  static Future<void> initSession() async {
    try {
      AppLogger.i('🔐 initSession: دەستیپێکرد');

      final prefs = await SharedPreferences.getInstance();
      _cachedPhone = prefs.getString('logged_phone');

      if (_cachedPhone != null && _cachedPhone!.isNotEmpty) {
        AppLogger.i('🔐 initSession: بەکارهێنەر دۆزرایەوە');
        await fetchUserProfile();
      } else {
        AppLogger.i('🔐 initSession: هیچ بەکارهێنەرێک نەدۆزرایەوە');
        _userRole = 'customer';
        userNotifier.value = null;
      }
    } catch (e, st) {
      AppLogger.e('⚠️ initSession error', e, st);
    } finally {
      _isInitialized = true;
      AppLogger.i('✅ AuthSessionManager initialized');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 fetchUserProfile
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('logged_phone') ?? _cachedPhone;

      if (phone == null || phone.isEmpty) {
        _userRole = 'customer';
        userNotifier.value = null;
        return null;
      }

      final res = await Supabase.instance.client
          .from('app_users')
          .select('id, name, phone, role, is_approved, created_at')
          .eq('phone', phone)
          .maybeSingle();

      if (res != null) {
        _userRole = res['role']?.toString() ?? 'customer';
        _userName = res['name']?.toString();
        _currentId = res['id']?.toString();
        userNotifier.value = res;

        AppLogger.i('✅ fetchUserProfile: ${_userName ?? "?"} ($_userRole)');
        return res;
      } else {
        await _clearLocalSession();
        return null;
      }
    } catch (e, st) {
      AppLogger.e('⚠️ fetchUserProfile error', e, st);
      _userRole = 'customer';
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔑 login — ✅ بە Rate Limiting
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> login({
    required String phone,
    required String password,
  }) async {
    try {
      AppLogger.i('🔑 Login attempt: $phone');

      // ═══════════════════════════════════════════════════════
      // 🚦 Rate Limiting — پشکنینی بلۆک
      // ═══════════════════════════════════════════════════════
      final rateLimitKey = 'login_$phone';

      if (await RateLimiter.isBlocked(rateLimitKey)) {
        final minutes = await RateLimiter.getRemainingBlockMinutes(rateLimitKey);
        AppLogger.w('🚫 Login blocked for $minutes minutes');
        return {
          '__rate_limited__': true,
          '__minutes__': minutes,
        };
      }

      // ═══════════════════════════════════════════════════════
      // ⭐ ١. app_users
      // ═══════════════════════════════════════════════════════
      final userRes = await Supabase.instance.client
          .from('app_users')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (userRes != null) {
        final storedPassword = userRes['password']?.toString() ?? '';

        // ❌ پاسۆرد هەڵە
        if (!verifyPassword(password, storedPassword)) {
          await RateLimiter.recordFailedAttempt(rateLimitKey);
          AppLogger.w('❌ Login: پاسۆرد هەڵەیە (app_users)');
          return null;
        }

        // ✅ پاسۆرد دروستە — Rate limit reset
        await RateLimiter.reset(rateLimitKey);

        // 🔄 Auto-upgrade password
        await _upgradePasswordIfNeeded(
          userId: userRes['id'].toString(),
          plainPassword: password,
          storedPassword: storedPassword,
          tableName: 'app_users',
        );

        // ⚠️ پشکنینی پەسەندکردن
        if (userRes['role'] == 'vendor' && userRes['is_approved'] != true) {
          AppLogger.w('⏳ Login: چاوەڕوانی پەسەندکردن');
          return {'__pending_approval__': true};
        }

        await saveSession(
          phone: phone,
          name: userRes['name']?.toString(),
          id: userRes['id'],
          role: userRes['role']?.toString() ?? 'customer',
        );

        AppLogger.i('✅ Login success: ${userRes['name']}');
        return userRes;
      }

      // ═══════════════════════════════════════════════════════
      // ⭐ ٢. dukan
      // ═══════════════════════════════════════════════════════
      final dukanRes = await Supabase.instance.client
          .from('dukan')
          .select()
          .eq('user_phone', phone)
          .maybeSingle();

      if (dukanRes != null) {
        final storedPassword = dukanRes['password']?.toString() ?? '';

        // ❌ پاسۆرد هەڵە
        if (!verifyPassword(password, storedPassword)) {
          await RateLimiter.recordFailedAttempt(rateLimitKey);
          AppLogger.w('❌ Login: پاسۆرد هەڵەیە (dukan)');
          return null;
        }

        // ✅ پاسۆرد دروستە — Rate limit reset
        await RateLimiter.reset(rateLimitKey);

        // 🔄 Auto-upgrade password
        await _upgradePasswordIfNeeded(
          userId: dukanRes['id'].toString(),
          plainPassword: password,
          storedPassword: storedPassword,
          tableName: 'dukan',
        );

        // ⚠️ پشکنینی پەسەندکردن
        if (dukanRes['is_approved'] != true) {
          AppLogger.w('⏳ Login: چاوەڕوانی پەسەندکردن (dukan)');
          return {'__pending_approval__': true};
        }

        await saveSession(
          phone: phone,
          name: dukanRes['name']?.toString(),
          id: dukanRes['id'],
          role: dukanRes['vendor_role']?.toString() ?? 'vendor',
        );

        AppLogger.i('✅ Login success (dukan): ${dukanRes['name']}');
        return dukanRes;
      }

      // ═══════════════════════════════════════════════════════
      // ❌ هیچ بەکارهێنەرێک نەدۆزرایەوە
      // ═══════════════════════════════════════════════════════
      await RateLimiter.recordFailedAttempt(rateLimitKey);
      AppLogger.w('❌ Login: هیچ بەکارهێنەرێک نەدۆزرایەوە');
      return null;
    } catch (e, st) {
      AppLogger.e('❌ Login error', e, st);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 saveSession
  // ═══════════════════════════════════════════════════════════
  static Future<void> saveSession({
    required String phone,
    String? name,
    dynamic id,
    String role = 'customer',
  }) async {
    try {
      _cachedPhone = phone;
      _userName = name;
      _currentId = id;
      _userRole = role;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_phone', phone);

      userNotifier.value = {
        'id': id ?? phone,
        'phone': phone,
        'name': name,
        'role': role,
        'is_approved': true,
      };

      AppLogger.i('✅ saveSession: $name ($role) — $phone');
    } catch (e, st) {
      AppLogger.e('❌ saveSession error', e, st);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🚪 clearSession
  // ═══════════════════════════════════════════════════════════
  static Future<void> clearSession() async {
    try {
      AppLogger.i('🚪 clearSession: دەستیپێکرد');

      await _clearLocalSession();

      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        AppLogger.w('⚠️ signOut error: $e');
      }

      AppLogger.i('✅ clearSession: تەواو بوو');
    } catch (e, st) {
      AppLogger.e('❌ clearSession error', e, st);
    }
  }

  static Future<void> _clearLocalSession() async {
    _cachedPhone = null;
    _userRole = 'customer';
    _userName = null;
    _currentId = null;
    userNotifier.value = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_phone');
    } catch (e) {
      AppLogger.w('⚠️ Clear session error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 refreshProfile
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> refreshProfile() async {
    return await fetchUserProfile();
  }

  // ═══════════════════════════════════════════════════════════
  // 🧪 Testing
  // ═══════════════════════════════════════════════════════════
  @visibleForTesting
  static Future<void> resetForTesting() async {
    _isInitialized = false;
    _cachedPhone = null;
    _userRole = 'customer';
    _userName = null;
    _currentId = null;
    userNotifier.value = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_phone');
    } catch (_) {}
  }
}