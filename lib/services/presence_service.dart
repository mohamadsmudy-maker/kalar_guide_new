// lib/services/presence_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../config/constants.dart';
import '../l10n/tr.dart';
import 'auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 👥 Presence Service — Ultra Pro
class PresenceService {
  static SupabaseClient get _client => Supabase.instance.client;
  static Timer? _heartbeatTimer;
  static String? _deviceId;
  static bool _isRunning = false;

  static Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    _deviceId = id;
    return id;
  }

  static final _observer = _PresenceObserver();
  static const Duration _interval = Duration(seconds: 60);

  /// یەکجار لە دەستپێکردنی ئەپ. پێشتر ئەمە هەرگیز بانگ نەدەکرا، بۆیە ژمارەی
  /// «بەکارهێنەرانی چالاک» هەمیشە ٠ بوو. ئێستا هەر خولەکێک ئەگەر ئەپەکە
  /// کراوە بێت RPC ی `app_presence_ping` بانگ دەکرێت (ناسنامەی هەڕەمەکی ئامێر،
  /// زمان، وەشان، پلاتفۆرم — بێ ناو و مۆبایل).
  static Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    WidgetsBinding.instance.addObserver(_observer);
    await ping();
    _startTimer();
  }

  static void _startTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_interval, (_) => ping());
  }

  static Future<void> ping() async {
    try {
      final deviceId = await _getDeviceId();
      await _client.rpc('app_presence_ping', params: {
        'p_device': deviceId,
        'p_user': null,
        'p_name': null,
        'p_role': AuthSessionManager.userRole,
        'p_version': AppConstants.appVersion,
        'p_platform': defaultTargetPlatform.name,
        'p_lang': AppLang.code,
        'p_neighborhood': null,
      });
    } catch (e) {
      debugPrint('⚠️ Presence ping: $e');
    }
  }

  static void _onLifecycle(AppLifecycleState state) {
    if (!_isRunning) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(ping());
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  static Future<void> stop() async {
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    WidgetsBinding.instance.removeObserver(_observer);
  }

  static Stream<int> watchOnlineCount() {
    return _client
        .from('active_users')
        .stream(primaryKey: ['id'])
        .map((data) {
      final now = DateTime.now().toUtc();
      return data.where((row) {
        final lastSeen = DateTime.tryParse(row['last_seen'] ?? '');
        if (lastSeen == null) return false;
        return now.difference(lastSeen).inMinutes < 3;
      }).length;
    });
  }

  static Stream<List<Map<String, dynamic>>> watchOnlineUsers() {
    return _client
        .from('active_users')
        .stream(primaryKey: ['id'])
        .order('last_seen', ascending: false)
        .map((data) {
      final now = DateTime.now().toUtc();
      return data.where((row) {
        final lastSeen = DateTime.tryParse(row['last_seen'] ?? '');
        if (lastSeen == null) return false;
        return now.difference(lastSeen).inMinutes < 5;
      }).toList();
    });
  }

  static Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await _client.rpc('get_presence_stats');
      if (res is Map) return Map<String, dynamic>.from(res);
      return _emptyStats();
    } catch (e) {
      debugPrint('⚠️ getStats error: $e');
      return _emptyStats();
    }
  }

  static Map<String, dynamic> _emptyStats() {
    return {
      'online_now': 0,
      'last_5min': 0,
      'last_30min': 0,
      'last_1hour': 0,
      'today': 0,
      'total_users': 0,
    };
  }
}

class _PresenceObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      PresenceService._onLifecycle(state);
}
