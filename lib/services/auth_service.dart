// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import '../utils/password_hasher.dart';
import 'notification_service.dart';
import 'rate_limiter.dart';

/// 🔐 بەڕێوەبردنی دانیشتن و ئەکاونتی بەکارهێنەر
class AuthSessionManager {
  static String? _cachedPhone;
  static bool _isInitialized = false;

  static final ValueNotifier<Map<String, dynamic>?> userNotifier =
  ValueNotifier(null);

  static String _userRole = 'customer';
  static String? _userName;
  static dynamic _currentId;

  static const Duration _supabaseTimeout = Duration(seconds: 5);

  static bool get isInitialized => _isInitialized;
  static String get userRole => _userRole;
  static String? get userName => _userName;
  static dynamic get currentId => _currentId;

  static bool get isAdmin => _userRole == 'admin';
  static bool get isVendor => _userRole == 'vendor' || isAdmin;
  static bool get isCustomer => _userRole == 'customer';
  static bool get isLoggedIn => _cachedPhone != null || _currentId != null;
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

  static bool verifyPassword(String inputPassword, String storedPassword) {
    if (storedPassword.isEmpty || inputPassword.isEmpty) return false;
    return PasswordHasher.verify(inputPassword, storedPassword);
  }

  static Future<void> _upgradePasswordIfNeeded({
    required String userId,
    required String plainPassword,
    required String storedPassword,
    String tableName = 'app_users',
  }) async {
    try {
      if (!PasswordHasher.needsUpgrade(storedPassword)) {
        AppLogger.d('✅ Password already bcrypt');
        return;
      }

      AppLogger.i('🔄 Upgrading password');
      final newHash = await PasswordHasher.hash(plainPassword);

      if (tableName == 'app_users') {
        await Supabase.instance.client.rpc(
          'upgrade_user_password',
          params: {
            'user_id_param': userId,
            'new_hash_param': newHash,
          },
        ).timeout(_supabaseTimeout);
      } else if (tableName == 'dukan') {
        await Supabase.instance.client.rpc(
          'upgrade_dukan_password',
          params: {
            'dukan_id_param': userId,
            'new_hash_param': newHash,
          },
        ).timeout(_supabaseTimeout);
      }

      AppLogger.i('✅ Password upgraded');
    } catch (e) {
      AppLogger.w('⚠️ Upgrade error: $e');
    }
  }

  static Future<void> initSession() async {
    try {
      AppLogger.i('🔐 initSession');

      final prefs = await SharedPreferences.getInstance();
      _cachedPhone = prefs.getString('logged_phone');

      if (_cachedPhone != null && _cachedPhone!.isNotEmpty) {
        await fetchUserProfile().timeout(
          _supabaseTimeout,
          onTimeout: () => null,
        );
      } else {
        _userRole = 'customer';
        userNotifier.value = null;
      }
    } catch (e, st) {
      AppLogger.e('⚠️ initSession error', e, st);
    } finally {
      _isInitialized = true;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 fetchUserProfile — بە RPC
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
          .rpc('get_user_for_login', params: {'phone_param': phone})
          .timeout(_supabaseTimeout);

      if (res is List && res.isNotEmpty) {
        final userData = Map<String, dynamic>.from(res.first);

        _userRole = userData['role']?.toString() ?? 'customer';
        _userName = userData['name']?.toString();
        _currentId = userData['id']?.toString();
        userNotifier.value = userData;

        AppLogger.i('✅ fetchUserProfile: $_userName ($_userRole)');
        return userData;
      } else {
        _userRole = 'customer';
        userNotifier.value = null;
        return null;
      }
    } catch (e, st) {
      AppLogger.e('⚠️ fetchUserProfile error', e, st);
      _userRole = 'customer';
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔑 login — بە RPC
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> login({
    required String phone,
    required String password,
  }) async {
    try {
      AppLogger.i('🔑 Login attempt: $phone');

      final rateLimitKey = 'login_$phone';

      try {
        if (await RateLimiter.isBlocked(rateLimitKey)) {
          final minutes =
          await RateLimiter.getRemainingBlockMinutes(rateLimitKey);
          AppLogger.w('🚫 Login blocked for $minutes minutes');
          return {'__rate_limited__': true, '__minutes__': minutes};
        }
      } catch (e) {
        AppLogger.w('⚠️ RateLimiter error: $e');
      }

      // ⭐ ١. app_users — بە RPC
      Map<String, dynamic>? userRes;
      try {
        final res = await Supabase.instance.client
            .rpc('get_user_for_login', params: {'phone_param': phone})
            .timeout(_supabaseTimeout);

        if (res is List && res.isNotEmpty) {
          userRes = Map<String, dynamic>.from(res.first);
        }
      } catch (e) {
        AppLogger.w('⚠️ app_users RPC error: $e');
      }

      if (userRes != null) {
        final storedPassword = userRes['password']?.toString() ?? '';

        if (!verifyPassword(password, storedPassword)) {
          await RateLimiter.recordFailedAttempt(rateLimitKey);
          AppLogger.w('❌ Login: پاسۆرد هەڵەیە (app_users)');
          return null;
        }

        await RateLimiter.reset(rateLimitKey);

        await _upgradePasswordIfNeeded(
          userId: userRes['id'].toString(),
          plainPassword: password,
          storedPassword: storedPassword,
          tableName: 'app_users',
        );

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

      // ⭐ ٢. dukan — بە RPC
      Map<String, dynamic>? dukanRes;
      try {
        final res = await Supabase.instance.client
            .rpc('get_dukan_for_login', params: {'phone_param': phone})
            .timeout(_supabaseTimeout);

        if (res is List && res.isNotEmpty) {
          dukanRes = Map<String, dynamic>.from(res.first);
        }
      } catch (e) {
        AppLogger.w('⚠️ dukan RPC error: $e');
      }

      if (dukanRes != null) {
        final storedPassword = dukanRes['password']?.toString() ?? '';

        if (!verifyPassword(password, storedPassword)) {
          await RateLimiter.recordFailedAttempt(rateLimitKey);
          AppLogger.w('❌ Login: پاسۆرد هەڵەیە (dukan)');
          return null;
        }

        await RateLimiter.reset(rateLimitKey);

        await _upgradePasswordIfNeeded(
          userId: dukanRes['id'].toString(),
          plainPassword: password,
          storedPassword: storedPassword,
          tableName: 'dukan',
        );

        if (dukanRes['is_approved'] != true) {
          AppLogger.w('⏳ Login: چاوەڕوانی پەسەندکردن');
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

      await RateLimiter.recordFailedAttempt(rateLimitKey);
      AppLogger.w('❌ Login: هیچ بەکارهێنەرێک نەدۆزرایەوە');
      return null;
    } catch (e, st) {
      AppLogger.e('❌ Login error', e, st);
      return null;
    }
  }

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
      };

      AppLogger.i('✅ saveSession: $name ($role)');

      try {
        await NotificationService.refreshToken();
      } catch (e) {
        AppLogger.w('⚠️ refreshToken error: $e');
      }
    } catch (e, st) {
      AppLogger.e('❌ saveSession error', e, st);
    }
  }

  static Future<void> clearSession() async {
    try {
      try {
        await NotificationService.clearToken();
      } catch (e) {
        AppLogger.w('⚠️ clearToken error: $e');
      }

      await _clearLocalSession();

      try {
        await Supabase.instance.client.auth.signOut().timeout(_supabaseTimeout);
      } catch (e) {
        AppLogger.w('⚠️ signOut error: $e');
      }
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
      AppLogger.w('⚠️ Clear error: $e');
    }
  }

  static Future<Map<String, dynamic>?> refreshProfile() async {
    try {
      return await fetchUserProfile().timeout(_supabaseTimeout);
    } catch (e) {
      AppLogger.w('⚠️ refreshProfile error: $e');
      return null;
    }
  }

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