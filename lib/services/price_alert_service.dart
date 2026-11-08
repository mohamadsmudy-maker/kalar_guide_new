import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../l10n/tr.dart';

/// 🔔 خزمەتگوزاری ئاگادارکردنەوە بۆ نرخ
class PriceAlertService {
  static const String _prefsKey = 'price_alerts';
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  /// ⭐ هەموو Alert ـەکان
  static Future<List<Map<String, dynamic>>> getAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey) ?? '[]';
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('❌ Get alerts error: $e');
      return [];
    }
  }

  /// ⭐ زیادکردنی Alert
  static Future<void> addAlert({
    required String fuelType,
    required String fuelName,
    required double targetPrice,
    required String condition, // 'below' یان 'above'
  }) async {
    try {
      final alerts = await getAllAlerts();
      alerts.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'fuel_type': fuelType,
        'fuel_name': fuelName,
        'target_price': targetPrice,
        'condition': condition,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });
      await _save(alerts);
      debugPrint('✅ Alert added: $fuelName → $condition $targetPrice');
    } catch (e) {
      debugPrint('❌ Add alert error: $e');
    }
  }

  /// ⭐ سڕینەوەی Alert
  static Future<void> deleteAlert(int id) async {
    try {
      final alerts = await getAllAlerts();
      alerts.removeWhere((a) => a['id'] == id);
      await _save(alerts);
    } catch (e) {
      debugPrint('❌ Delete alert error: $e');
    }
  }

  /// ⭐ پشکنینی Alert ـەکان لەگەڵ نرخە نوێیەکان
  static Future<void> checkAlerts({
    required List<Map<String, dynamic>> currentPrices,
  }) async {
    try {
      final alerts = await getAllAlerts();
      if (alerts.isEmpty) return;

      for (final alert in alerts) {
        if (alert['is_active'] != true) continue;

        final fuelType = alert['fuel_type'];
        final targetPrice = (alert['target_price'] as num?)?.toDouble() ?? 0;
        final condition = alert['condition'] as String;

        final pricesForType = currentPrices
            .where((p) => p['fuel_type'] == fuelType)
            .map((p) => (p['price'] as num?)?.toDouble() ?? 0)
            .where((p) => p > 0)
            .toList();

        if (pricesForType.isEmpty) continue;

        final cheapest = pricesForType.reduce((a, b) => a < b ? a : b);

        bool shouldNotify = false;
        if (condition == 'below' && cheapest <= targetPrice) {
          shouldNotify = true;
        } else if (condition == 'above' && cheapest >= targetPrice) {
          shouldNotify = true;
        }

        if (shouldNotify) {
          await _showNotification(
            title: tr('🔔 ئاگادارکردنەوەی نرخ'),
            body:
            'نرخی ${alert['fuel_name']} گەیشتە ${cheapest.toStringAsFixed(0)} د.ع',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Check alerts error: $e');
    }
  }

  static Future<void> _save(List<Map<String, dynamic>> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(alerts));
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'price_alerts',
            'ئاگادارکردنەوەی نرخ',
            channelDescription: 'ئاگادارکردنەوە بۆ گۆڕینی نرخی سووتەمەنی',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFD9822B),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Notification error: $e');
    }
  }
}