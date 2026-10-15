// lib/services/presence_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
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

  static Future<void> start({
    String? userId,
    String? userName,
    String? userRole,
    String? language,
    String? neighborhood,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final deviceId = await _getDeviceId();

      await _client.from('active_users').upsert({
        'device_id': deviceId,
        'user_id': userId,
        'user_name': userName,
        'user_role': userRole ?? 'customer',
        'app_version': '1.0.0',
        'platform': defaultTargetPlatform.name,
        'language': language ?? 'ku',
        'neighborhood': neighborhood,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_id');

      debugPrint('👥 Presence started: $deviceId');

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 20),
            (_) => _updateHeartbeat(),
      );
    } catch (e) {
      debugPrint('⚠️ Presence start error: $e');
      _isRunning = false;
    }
  }

  static Future<void> _updateHeartbeat() async {
    try {
      final deviceId = await _getDeviceId();
      await _client
          .from('active_users')
          .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
          .eq('device_id', deviceId);
    } catch (e) {
      debugPrint('⚠️ Heartbeat error: $e');
    }
  }

  static Future<void> stop() async {
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    try {
      final deviceId = await _getDeviceId();
      await _client.from('active_users').delete().eq('device_id', deviceId);
    } catch (e) {
      debugPrint('⚠️ Presence stop error: $e');
    }
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
        return now.difference(lastSeen).inMinutes < 2;
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