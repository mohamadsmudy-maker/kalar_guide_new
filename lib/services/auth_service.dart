import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import 'notification_service.dart';

/// 🔐 بەڕێوەبردنی دانیشتن و ئەکاونتی بەکارهێنەر — PRO EDITION
class AuthSessionManager {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  static String? _cachedPhone;
  static bool _isInitialized = false;

  /// ✅ ValueNotifier — Drawer و وێجێتەکان گوێی دەگرن
  /// ئەمە کێشەی Static Global ی چارەسەر دەکات (کە Drawer نوێ نەدەبوو)
  static final ValueNotifier<Map<String, dynamic>?> userNotifier =
  ValueNotifier(null);

  static String _userRole = 'customer';
  static String? _userName;
  static dynamic _currentId;

  // ═══════════════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════════════

  /// ✅ ئایا `initSession()` تەواو بووە؟
  /// بەکارهێنراوە لە SplashScreen بۆ چاوەڕوانی
  static bool get isInitialized => _isInitialized;

  static String get userRole => _userRole;
  static String? get userName => _userName;
  static dynamic get currentId => _currentId;

  static bool get isAdmin => _userRole == 'admin';
  static bool get isVendor => _userRole == 'vendor' || isAdmin;
  static bool get isCustomer => _userRole == 'customer';
  static bool get isLoggedIn => _cachedPhone != null || _currentId != null;

  /// 📱 پرۆفایلی ئێستا (بێ هێنانی نوێ لە Supabase)
  static Map<String, dynamic>? get currentUser {
    if (!isLoggedIn) return null;
    return {
      'id': _currentId ?? _cachedPhone,
      'phone': _cachedPhone,
      'name': _userName,
      'role': _userRole,
    };
  }

  /// 🗂️ پرۆفایلی هەڵگیراو (لە userNotifier)
  static Map<String, dynamic>? get cachedProfile => userNotifier.value;

  // ═══════════════════════════════════════════════════════════
  // 🚀 دەستپێکردنی دانیشتن (لە main())
  // ═══════════════════════════════════════════════════════════
  static Future<void> initSession() async {
    try {
      AppLogger.i('🔐 initSession: دەستیپێکرد');

      final prefs = await SharedPreferences.getInstance();
      _cachedPhone = prefs.getString('logged_phone');

      if (_cachedPhone != null && _cachedPhone!.isNotEmpty) {
        AppLogger.i('🔐 initSession: بەکارهێنەر دۆزرایەوە — هێنانی پرۆفایل');

        // ✅ هێنانی پرۆفایل و هەڵگرتنی لە userNotifier
        await fetchUserProfile();

        // ✅ دوای هێنانی پرۆفایل، FCM Token بنێرە
        try {
          await NotificationService.refreshToken();
          AppLogger.i('🔐 initSession: FCM Token refreshed');
        } catch (e) {
          AppLogger.w('⚠️ FCM refreshToken failed (غیر کریتیکی): $e');
        }
      } else {
        AppLogger.i('🔐 initSession: هیچ بەکارهێنەرێک نەدۆزرایەوە');
        _userRole = 'customer';
        userNotifier.value = null;
      }
    } catch (e, st) {
      AppLogger.e('⚠️ initSession error', e, st);
    } finally {
      // ✅ هەمیشە `_isInitialized` true دەکەین
      // تەنانەت ئەگەر هەڵەیەکیش ڕوویدا، Splash دەبێت بەردەوام بێت
      _isInitialized = true;
      AppLogger.i('✅ AuthSessionManager initialized');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 هێنانی پرۆفایل لە Supabase
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

      // ✅ تەنها ئەو کۆلۆمانە هێنە کە پێویستە (نەک هەمووی)
      final res = await Supabase.instance.client
          .from('app_users')
          .select('id, name, phone, role, is_approved, fcm_token, created_at')
          .eq('phone', phone)
          .maybeSingle();

      if (res != null) {
        _userRole = res['role']?.toString() ?? 'customer';
        _userName = res['name']?.toString();
        _currentId = res['id']?.toString();

        // ✅ Notify listeners (Drawer، وێجێتەکان)
        userNotifier.value = res;

        AppLogger.i(
          '✅ fetchUserProfile: ${_userName ?? "?"} '
              '(${_userRole}) — ID: $_currentId',
        );

        return res;
      } else {
        // ئەکاونت نەدۆزرایەوە — پاکی بکەرەوە
        AppLogger.w('⚠️ fetchUserProfile: بەکارهێنەر نەدۆزرایەوە — پاککردنەوە');
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
  // 💾 پاشەکەوتکردنی دانیشتن دوای چوونەژوورەوە
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

      // ✅ Notify listeners — بەبێ هێنان لە سێرڤەر
      userNotifier.value = {
        'id': id ?? phone,
        'phone': phone,
        'name': name,
        'role': role,
        'is_approved': true,
      };

      AppLogger.i('✅ saveSession: $name ($role) — $phone');

      // ✅ FCM Token پاشەکەوت بکە (دەبێت Firebase ئامادە بێت)
      try {
        await NotificationService.refreshToken();
      } catch (e) {
        AppLogger.w('⚠️ FCM refreshToken error (غیر کریتیکی): $e');
      }
    } catch (e, st) {
      AppLogger.e('❌ saveSession error', e, st);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🚪 چوونەدەرەوە
  // ═══════════════════════════════════════════════════════════
  static Future<void> clearSession() async {
    try {
      AppLogger.i('🚪 clearSession: دەستیپێکرد');

      // ✅ FCM Token پاک بکەرەوە پێش چوونەدەرەوە
      try {
        await NotificationService.clearToken();
      } catch (e) {
        AppLogger.w('⚠️ clearToken error (غیر کریتیکی): $e');
      }

      // ✅ پاککردنەوەی داتای ناوخۆیی
      await _clearLocalSession();

      // ✅ Supabase Auth signOut (ئەگەر بەکارت هێناوە)
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        AppLogger.w('⚠️ Supabase signOut error (غیر کریتیکی): $e');
      }

      AppLogger.i('✅ clearSession: تەواو بوو');
    } catch (e, st) {
      AppLogger.e('❌ clearSession error', e, st);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 پاککردنەوەی ناوخۆیی
  // ═══════════════════════════════════════════════════════════
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
      AppLogger.w('⚠️ _clearLocalSession prefs error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 نوێکردنەوەی پرۆفایل بە دەستی (بۆ Pull-to-Refresh)
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> refreshProfile() async {
    return await fetchUserProfile();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Reset — تەنها بۆ Debug و Tests
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