// lib/services/google_auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../l10n/tr.dart';
import '../utils/app_logger.dart';
import 'auth_service.dart';

/// ئەنجامی چوونەژوورەوە بە Google
enum GoogleLoginResult {
  ok,

  /// بەکارهێنەر پەنجەرەکەی داخست — هیچ پەیامێک پیشان مەدە
  cancelled,

  /// GOOGLE_WEB_CLIENT_ID دانەنراوە
  notConfigured,

  /// ئەکاونتی خاوەن شوێن هێشتا پەسەند نەکراوە
  pending,

  /// سێرڤەر ئەکاونتەکەی نەناسی (مایگرەیشن جێبەجێ نەکراوە؟)
  serverRejected,
  failed;

  String get message => switch (this) {
        ok => tr('بە سەرکەوتوویی چوویتە ژوورەوە'),
        cancelled => '',
        notConfigured => tr('چوونەژوورەوە بە Google هێشتا ڕێکنەخراوە'),
        pending => tr('هێشتا داواکاریت لەلایەن ئەدمینەوە پەسەند نەکراوە.'),
        serverRejected => tr('سێرڤەر ئەکاونتەکەی وەرنەگرت، دواتر هەوڵ بدەرەوە'),
        failed => tr('چوونەژوورەوە بە Google سەرکەوتوو نەبوو'),
      };
}

/// 🔵 چوونەژوورەوە بە Google (بەخۆڕایی؛ ئیمەیڵ لەلایەن Google ەوە پشتڕاست کراوەتەوە)
///
/// ١) google_sign_in → idToken
/// ٢) supabase.auth.signInWithIdToken(google)
/// ٣) RPC app_login_google → ئەکاونتی app_users دەدۆزێتەوە یان دروستی دەکات
///    و session دەبەستێتەوە (هەمان RLS ی app_login)
class GoogleAuthService {
  GoogleAuthService._();

  static bool get isAvailable => AppEnv.isGoogleConfigured;

  static Future<void>? _init;

  static Future<void> _ensureInit() => _init ??= GoogleSignIn.instance
      .initialize(serverClientId: AppEnv.googleWebClientId)
      .catchError((Object e) {
        _init = null; // هەوڵی دواتر
        throw e;
      });

  static Future<GoogleLoginResult> signIn() async {
    if (!isAvailable) return GoogleLoginResult.notConfigured;
    try {
      await _ensureInit();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) return GoogleLoginResult.failed;

      final client = Supabase.instance.client;
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final res = await client.rpc('app_login_google', params: {
        'p_name': account.displayName,
      });
      final rows = res is List ? res : const [];
      if (rows.isEmpty) return GoogleLoginResult.serverRejected;
      final user = Map<String, dynamic>.from(rows.first as Map);

      final role = user['role']?.toString() ?? 'customer';
      if (role == 'vendor_pending' || (role == 'vendor' && user['is_approved'] != true)) {
        return GoogleLoginResult.pending;
      }

      await AuthSessionManager.saveSession(
        // ئەکاونتی Google ژمارەی مۆبایلی نییە؛ ئیمەیڵ وەک ناسنامەی ناوخۆیی
        phone: '${user['phone'] ?? ''}'.isNotEmpty ? '${user['phone']}' : '${user['email'] ?? account.email}',
        name: user['name']?.toString(),
        id: user['id'],
        role: role,
        storeId: user['store_id'],
      );
      return GoogleLoginResult.ok;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return GoogleLoginResult.cancelled;
      }
      AppLogger.w('⚠️ Google sign-in: ${e.code} ${e.description}');
      return GoogleLoginResult.failed;
    } on PostgrestException catch (e) {
      AppLogger.w('⚠️ app_login_google: ${e.message}');
      return GoogleLoginResult.serverRejected;
    } catch (e) {
      AppLogger.w('⚠️ Google sign-in: $e');
      return GoogleLoginResult.failed;
    }
  }

  /// لە کاتی چوونەدەرەوە بانگ دەکرێت (هەڵە پشتگوێ دەخرێت)
  static Future<void> signOut() async {
    if (!isAvailable || _init == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('⚠️ Google signOut: $e');
    }
  }

  /// سڕینەوەی ئەکاونت (Google Play داوای دەکات). 'ok' یان هۆکار.
  static Future<String> deleteAccount() async {
    try {
      final res = await Supabase.instance.client.rpc('app_delete_account');
      final status = '$res';
      if (status == 'ok') {
        await signOut();
        await AuthSessionManager.clearSession();
      }
      return status;
    } catch (e) {
      AppLogger.w('⚠️ app_delete_account: $e');
      return 'failed';
    }
  }
}
