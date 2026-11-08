import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import 'google_auth_service.dart';
import 'notification_service.dart';

class AuthSessionManager {
  static String? _cachedPhone;
  static bool _isInitialized = false;

  static final ValueNotifier<Map<String, dynamic>?> userNotifier = ValueNotifier(null);

  static String _userRole = 'customer';
  static String? _userName;
  static dynamic _currentId;
  static dynamic _storeId; // ✅ هەڵگرتنی ئایدی شوێن

  static const Duration _supabaseTimeout = Duration(seconds: 5);

  static bool get isInitialized => _isInitialized;
  static String get userRole => _userRole;
  static String? get userName => _userName;
  static dynamic get currentId => _currentId;
  static dynamic get storeId => _storeId;

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
      'store_id': _storeId,
    };
  }

  static Map<String, dynamic>? get cachedProfile => userNotifier.value;

  // 🔐 پشکنینی پاسۆرد لەسەر سێرڤەر دەکرێت (RPC: app_login) — بڕوانە auth_screen.dart

  static Future<void> initSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPhone = prefs.getString('logged_phone');
      if (_cachedPhone != null && _cachedPhone!.isNotEmpty) {
        // ✅ پشکنینی ئەوەی کە ئایا بەکارهێنەرەکە بە شێوەیەکی نهێنی چووەتە ژوورەوە
        if (Supabase.instance.client.auth.currentSession == null) {
          await Supabase.instance.client.auth.signInAnonymously();
        }
        await fetchUserProfile().timeout(_supabaseTimeout, onTimeout: () => null);
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

  static Future<Map<String, dynamic>?> fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('logged_phone') ?? _cachedPhone;

      if (phone == null || phone.isEmpty) {
        _userRole = 'customer';
        userNotifier.value = null;
        return null;
      }

      // 🔐 ڕۆڵ لە سێرڤەرەوە دێت (app_sessions)، نەک لەو ژمارەیەی لە مۆبایل هەڵگیراوە
      final res = await Supabase.instance.client
          .rpc('app_current_user')
          .timeout(_supabaseTimeout);

      if (res is List && res.isNotEmpty) {
        final userData = Map<String, dynamic>.from(res.first);
        _userRole = userData['role']?.toString() ?? 'customer';
        _userName = userData['name']?.toString();
        _currentId = userData['id']?.toString();
        _storeId = userData['store_id'];
        userNotifier.value = userData;

        AppLogger.i('✅ fetchUserProfile: $_userName ($_userRole) - Store: $_storeId');
        return userData;
      } else {
        // session ی سێرڤەر نییە (یان بەسەرچووە) → دەبێت دووبارە بچێتە ژوورەوە
        await _clearLocalSession();
        return null;
      }
    } catch (e, st) {
      AppLogger.e('⚠️ fetchUserProfile error', e, st);
      _userRole = 'customer';
      return null;
    }
  }

  static Future<void> saveSession({
    required String phone,
    String? name,
    dynamic id,
    String role = 'customer',
    dynamic storeId,
  }) async {
    try {
      _cachedPhone = phone;
      _userName = name;
      _currentId = id;
      _userRole = role;
      _storeId = storeId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_phone', phone);

      // ✅ گرنگترین بەش: چوونەژوورەوەی نهێنی (Anonymous) بۆ ئەوەی سیستەمەکە ناسنامەیەک بداتێ
      if (Supabase.instance.client.auth.currentSession == null) {
        await Supabase.instance.client.auth.signInAnonymously();
      }

      userNotifier.value = {
        'id': id ?? phone,
        'phone': phone,
        'name': name,
        'role': role,
        'store_id': storeId,
      };

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
      // هەر هەنگاوێک سەربەخۆیە: ئەگەر یەکێکیان شکستی هێنا، ئەوانی تر هەر دەکرێن
      try {
        await NotificationService.clearToken();
      } catch (e) {
        AppLogger.w('⚠️ clearToken: $e');
      }
      try {
        await Supabase.instance.client.rpc('app_logout').timeout(_supabaseTimeout);
      } catch (e) {
        AppLogger.w('⚠️ app_logout: $e');
      }
      await _clearLocalSession();
      await GoogleAuthService.signOut();
      try {
        await Supabase.instance.client.auth.signOut().timeout(_supabaseTimeout);
      } catch (e) {
        AppLogger.w('⚠️ signOut: $e');
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
    _storeId = null;
    userNotifier.value = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_phone');
    } catch (e) {
      AppLogger.w('⚠️ remove logged_phone: $e');
    }
  }
}