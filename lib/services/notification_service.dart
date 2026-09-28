import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// 🔔 خزمەتگوزاری ئاگادارکردنەوە — PRO EDITION
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

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

      debugPrint('🔔 Notification Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ بەکارهێنەر مۆڵەتی Notification ی نەدا');
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
          debugPrint('🔔 Notification clicked: ${response.payload}');
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
        debugPrint('📩 نامە گەیشت: ${message.notification?.title}');
        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });

      // ٥. گوێگرتن لە نامەکان کاتێک بەکارهێنەر کلیک دەکات
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('👆 بەکارهێنەر کلیکی کرد لەسەر Notification');
        _handleNotificationTap(message.data['route']);
      });

      // ٦. وەرگرتنی FCM Token و پاشەکەوتکردن
      await _updateFcmToken();

      // ٧. گوێگرتن لە گۆڕینی Token
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔑 Token نوێ: $newToken');
        _saveTokenToSupabase(newToken);
      });

      debugPrint('✅ Notification Service ئامادەیە');
    } catch (e) {
      debugPrint('❌ هەڵە لە Notification Service: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔑 وەرگرتن و پاشەکەوتکردنی FCM Token
  // ═══════════════════════════════════════════════════════════
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('❌ هەڵە لە وەرگرتنی Token: $e');
      return null;
    }
  }

  /// 📥 وەرگرتنی Token و پاشەکەوتکردن لە Supabase
  static Future<void> _updateFcmToken() async {
    final token = await getToken();
    if (token == null) return;

    debugPrint('🔑 FCM Token: $token');
    await _saveTokenToSupabase(token);
  }

  /// 💾 پاشەکەوتکردنی Token لە Supabase
  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = AuthSessionManager.currentUser;
      if (user == null) {
        debugPrint('⚠️ بەکارهێنەر نەچووە ژوورەوە — Token پاشەکەوت نەکرا');
        return;
      }

      await Supabase.instance.client
          .from('app_users')
          .update({'fcm_token': token})
          .eq('id', user['id']);

      debugPrint('✅ FCM Token پاشەکەوتکرا لە Supabase');
    } catch (e) {
      debugPrint('❌ هەڵە لە پاشەکەوتکردنی Token: $e');
    }
  }

  /// 🔄 دووبارە پاشەکەوتکردنی Token (کاتێک بەکارهێنەر دێتە ژوورەوە)
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
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'ئاگادارکردنەوەی گرنگ',
          channelDescription: 'ئەم کەناڵە بۆ ئاگادارکردنەوەی گرنگ بەکاردێت',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF1E88E5),
          enableLights: true,
          enableVibration: true,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
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
    if (route == null) return;
    debugPrint('🚀 چوونە ژوورەوە بۆ: $route');
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 پاککردنەوەی Token (کاتێک بەکارهێنەر دێتە دەرەوە)
  // ═══════════════════════════════════════════════════════════
  static Future<void> clearToken() async {
    try {
      final user = AuthSessionManager.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('app_users')
          .update({'fcm_token': null})
          .eq('id', user['id']);

      debugPrint('🧹 FCM Token پاککرایەوە');
    } catch (e) {
      debugPrint('❌ هەڵە لە پاککردنەوەی Token: $e');
    }
  }
}