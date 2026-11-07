// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import 'auth_service.dart';

/// 🔔 خزمەتگوزاری ئاگادارکردنەوە
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  // ═══════════════════════════════════════════════════════════
  // 🚀 دەستپێکردن
  // ═══════════════════════════════════════════════════════════
  static Future<void> initialize() async {
    try {
      // ١. داواکردنی مۆڵەت
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      AppLogger.i('🔔 Notification Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.w('⚠️ بەکارهێنەر مۆڵەتی Notification ی نەدا');
        return;
      }

      // ٢. ڕێکخستنی Local Notifications
      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          AppLogger.i('🔔 Notification clicked: ${response.payload}');
          _handleNotificationTap(response.payload);
        },
      );

      // ٣. دروستکردنی Channel بۆ Android
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'ئاگادارکردنەوەی گرنگ',
        description: 'ئەم کەناڵە بۆ ئاگادارکردنەوەی گرنگ بەکاردێت',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // ٤. گوێگرتن لە نامەکان لە کاتی ئەپ چالاکە
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.i('📩 نامە گەیشت: ${message.notification?.title}');
        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });

      // ٥. گوێگرتن لە نامەکان کاتێک بەکارهێنەر کلیک دەکات
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.i('👆 بەکارهێنەر کلیکی کرد لەسەر Notification');
        _handleNotificationTap(message.data['route']?.toString());
      });

      // ٦. پشکنینی نامەی سەرەتا
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.i('📬 Initial message: ${initialMessage.data}');
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationTap(initialMessage.data['route']?.toString());
        });
      }

      // ٧. وەرگرتنی FCM Token — ✅ بێ هەڵە
      await _updateFcmToken();

      // ٨. گوێگرتن لە گۆڕینی Token
      _messaging.onTokenRefresh.listen((newToken) {
        AppLogger.i('🔑 Token نوێ: $newToken');
        _saveTokenToSupabase(newToken);
      });

      AppLogger.i('✅ Notification Service ئامادەیە');
    } catch (e) {
      AppLogger.e('❌ هەڵە لە Notification Service', e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔑 FCM Token — ✅ بێ هەڵە کاتێک Firebase ناکارا بێت
  // ═══════════════════════════════════════════════════════════
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      // ✅ ئەمە ئاگادارییەکی باوە لە سەر ئیمۆلەیتەر
      // Firebase Installations Service لە سەر ئیمۆلەیتەر کار ناکات
      AppLogger.w('⚠️ نەتوانرا FCM Token وەربگیرێت (ئیمۆلەیتەر)');
      return null;
    }
  }

  /// 📥 وەرگرتنی Token و پاشەکەوتکردن لە Supabase — ✅ بێ هەڵە
  static Future<void> _updateFcmToken() async {
    final token = await getToken();
    if (token == null) {
      // ✅ ئەمە ئاساییە لە سەر ئیمۆلەیتەر
      AppLogger.w('⚠️ FCM Token بەردەست نییە (ئیمۆلەیتەر یان کێشەی تۆڕ)');
      return;
    }

    AppLogger.i('🔑 FCM Token: $token');
    await _saveTokenToSupabase(token);
  }

  /// 💾 پاشەکەوتکردنی Token لە Supabase
  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = AuthSessionManager.currentUser;
      if (user == null) {
        AppLogger.w('⚠️ بەکارهێنەر نەچووە ژوورەوە — Token پاشەکەوت نەکرا');
        return;
      }

      final userId = user['id']?.toString();
      if (userId == null || userId.isEmpty) {
        AppLogger.w('⚠️ ID ی بەکارهێنەر نییە');
        return;
      }

      await Supabase.instance.client
          .rpc('app_set_fcm_token', params: {'p_token': token});

      AppLogger.i('✅ FCM Token پاشەکەوتکرا');
    } catch (e) {
      AppLogger.e('❌ هەڵە لە پاشەکەوتکردنی Token', e);
    }
  }

  /// 🔄 دووبارە پاشەکەوتکردنی Token
  static Future<void> refreshToken() async {
    await _updateFcmToken();
  }

  // ═══════════════════════════════════════════════════════════
  // 📩 پیشاندانی Notification
  // ═══════════════════════════════════════════════════════════
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'ئاگادارکردنەوەی گرنگ',
          channelDescription: 'ئەم کەناڵە بۆ ئاگادارکردنەوەی گرنگ بەکاردێت',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF1E88E5),
          enableLights: true,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route']?.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 👆 کردار کاتێک بەکارهێنەر کلیک لە Notification دەکات
  // ═══════════════════════════════════════════════════════════
  static void _handleNotificationTap(String? route) {
    if (route == null || route.isEmpty) {
      AppLogger.w('⚠️ Route ی Notification بەتاڵە');
      return;
    }

    AppLogger.i('🚀 چوونە ژوورەوە بۆ: $route');

    try {
      navigatorKey.currentState?.pushNamed(route);
    } catch (e) {
      AppLogger.e('❌ هەڵە لە چوونە ژوورەوە بۆ route', e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 پاککردنەوەی Token
  // ═══════════════════════════════════════════════════════════
  static Future<void> clearToken() async {
    try {
      final user = AuthSessionManager.currentUser;
      if (user == null) {
        AppLogger.w('⚠️ بەکارهێنەر نییە — Token پاک نەکرا');
        return;
      }

      final userId = user['id']?.toString();
      if (userId == null || userId.isEmpty) {
        AppLogger.w('⚠️ ID ی بەکارهێنەر نییە');
        return;
      }

      await Supabase.instance.client
          .rpc('app_set_fcm_token', params: {'p_token': null});

      try {
        await _messaging.deleteToken();
        AppLogger.i('✅ FCM Token لە FCM پاککرایەوە');
      } catch (e) {
        AppLogger.w('⚠️ deleteToken error: $e');
      }

      AppLogger.i('✅ FCM Token پاککرایەوە');
    } catch (e) {
      AppLogger.e('❌ هەڵە لە پاککردنەوەی Token', e);
    }
  }
}