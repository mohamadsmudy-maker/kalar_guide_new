// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// 📊 Firebase Analytics Service
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver getObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  // ═══ Log Screen View ═══
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      debugPrint('📊 Screen: $screenName');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  // ═══ Log Event ═══
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('📊 Event: $name');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  // ═══ Log Login ═══
  static Future<void> logLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  // ═══ Log Signup ═══
  static Future<void> logSignup({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  // ═══ Log Complaint ═══
  static Future<void> logComplaintSubmitted({
    required String type,
    required String? neighborhood,
  }) async {
    await logEvent(
      name: 'complaint_submitted',
      parameters: {
        'type': type,
        if (neighborhood != null) 'neighborhood': neighborhood,
      },
    );
  }

  // ═══ Log Neighborhood View ═══
  static Future<void> logNeighborhoodView(String name) async {
    await logEvent(
      name: 'neighborhood_view',
      parameters: {'name': name},
    );
  }

  // ═══ Log Map View ═══
  static Future<void> logMapView() async {
    await logEvent(name: 'map_view');
  }

  // ═══ Set User ID ═══
  static Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  // ═══ Clear User ═══
  static Future<void> clearUser() async {
    try {
      await _analytics.setUserId(id: null);
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }
}