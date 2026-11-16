import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import 'app_settings_service.dart';

enum AnnounceLevel { info, warning, success }

/// ڕێکخستنەکانی کۆنترۆڵی ئەپ، لە خشتەی `app_settings` (ئەدمین دەیگۆڕێت، هەمووان دەیخوێننەوە).
///
/// کلیلەکان:
///  • `maintenance`  {enabled, message}
///  • `announcement` {enabled, text, level}
///  • `min_version`  {version, message, url}
///  • `features`     {gallery: bool, videos: bool, events: bool, complaints: bool}
///  • `place_suggestions_enabled` (بوولی، پێشتر هەبوو) ← تایبەتمەندی `suggest_place`
///
/// ئەگەر هەر شتێک نەبوو یان هەڵە بوو، هەموو شتێک کراوەیە — هەرگیز بەکارهێنەر
/// بەهۆی هەڵەی ئینتەرنێتەوە بلۆک ناکرێت.
@immutable
class AppControlState {
  const AppControlState({
    this.maintenance = false,
    this.maintenanceMessage = '',
    this.announcementOn = false,
    this.announcementText = '',
    this.announcementLevel = AnnounceLevel.info,
    this.announcementId = '',
    this.minVersion = '',
    this.updateMessage = '',
    this.updateUrl = '',
    this.features = const {},
  });

  final bool maintenance;
  final String maintenanceMessage;
  final bool announcementOn;
  final String announcementText;
  final AnnounceLevel announcementLevel;

  /// بۆ «ئیتر نیشانم مەدە»: هەر گۆڕانکارییەک ناسنامەیەکی نوێ دەدات
  final String announcementId;
  final String minVersion;
  final String updateMessage;
  final String updateUrl;
  final Map<String, bool> features;

  /// کلیلەکانی تایبەتمەندییەکان — بەکارهێنراو لە ئەدمین و ئەپ
  static const List<String> featureKeys = [
    'complaints',
    'suggest_place',
    'gallery',
    'videos',
    'events',
  ];

  bool feature(String key) => features[key] ?? true;

  bool get hasAnnouncement => announcementOn && announcementText.trim().isNotEmpty;

  /// وەشانی ئێستا لە کەمترین وەشان کەمترە؟
  bool needsUpdate(String currentVersion) {
    final min = minVersion.trim();
    if (min.isEmpty) return false;
    return compareVersions(currentVersion, min) < 0;
  }

  /// -1 / 0 / 1 — «1.2.0» لەگەڵ «1.10.0»، بێ گوێدانە +build
  static int compareVersions(String a, String b) {
    List<int> parts(String v) {
      final core = v.trim().split('+').first.split('-').first;
      final p = core.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
      while (p.length < 3) {
        p.add(0);
      }
      return p;
    }

    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      if (x[i] != y[i]) return x[i] < y[i] ? -1 : 1;
    }
    return 0;
  }

  static AppControlState fromRows(List<Map<String, dynamic>> rows) {
    final byKey = <String, dynamic>{
      for (final r in rows) '${r['key']}': r['value'],
    };
    final stamps = <String, String>{
      for (final r in rows) '${r['key']}': '${r['updated_at'] ?? ''}',
    };
    Map<String, dynamic> obj(String k) {
      final v = byKey[k];
      return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    }

    String str(dynamic v) => v == null ? '' : '$v'.trim();

    final m = obj('maintenance');
    final a = obj('announcement');
    final u = obj('min_version');
    final f = obj('features');

    final level = switch (str(a['level'])) {
      'warning' => AnnounceLevel.warning,
      'success' => AnnounceLevel.success,
      _ => AnnounceLevel.info,
    };

    final features = <String, bool>{
      for (final k in featureKeys)
        if (f[k] is bool) k: f[k] as bool,
    };
    if (byKey['place_suggestions_enabled'] is bool) {
      features['suggest_place'] = byKey['place_suggestions_enabled'] as bool;
    }

    return AppControlState(
      maintenance: m['enabled'] == true,
      maintenanceMessage: str(m['message']),
      announcementOn: a['enabled'] == true,
      announcementText: str(a['text']),
      announcementLevel: level,
      announcementId: '${stamps['announcement'] ?? ''}|${str(a['text']).hashCode}',
      minVersion: str(u['version']),
      updateMessage: str(u['message']),
      updateUrl: str(u['url']),
      features: features,
    );
  }
}

class AppControl with WidgetsBindingObserver {
  AppControl._();
  static final AppControl instance = AppControl._();

  static const String _cacheKey = 'app_control_rows_v1';
  static const Duration _minGap = Duration(minutes: 10);

  static final ValueNotifier<AppControlState> state =
      ValueNotifier(const AppControlState());

  bool _started = false;
  bool _loading = false;
  DateTime? _last;

  /// یەکجار لە دەستپێکردنی ئەپ، دوای Supabase
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_readCache().then((_) => refresh(force: true)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    final now = DateTime.now();
    if (!force && _last != null && now.difference(_last!) < _minGap) return;
    _loading = true;
    try {
      final res = await Supabase.instance.client
          .from('app_settings')
          .select('key, value, updated_at')
          .timeout(const Duration(seconds: 8));
      final rows = List<Map<String, dynamic>>.from(res as List);
      state.value = AppControlState.fromRows(rows);
      _last = now;
      unawaited(_writeCache(rows));
    } catch (e) {
      debugPrint('⚠️ app_control: $e');
    } finally {
      _loading = false;
    }
  }

  Future<void> _readCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_cacheKey);
      if (raw == null) return;
      final rows = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      state.value = AppControlState.fromRows(rows);
    } catch (_) {}
  }

  Future<void> _writeCache(List<Map<String, dynamic>> rows) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_cacheKey, jsonEncode(rows));
    } catch (_) {}
  }

  /// تەنها ئەدمین (RLS). true = پاشەکەوت کرا، پاشان ئەپ خۆی نوێ دەکاتەوە
  static Future<bool> save(String key, Object value) async {
    try {
      await Supabase.instance.client.from('app_settings').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await instance.refresh(force: true);
      return true;
    } catch (e) {
      debugPrint('⚠️ app_control save $key: $e');
      return false;
    }
  }

  /// تایبەتمەندییەک: `suggest_place` کلیلی کۆنی خۆی هەیە
  static Future<bool> saveFeatures(Map<String, bool> features) async {
    final ok = await save('features', {
      for (final e in features.entries)
        if (e.key != 'suggest_place') e.key: e.value,
    });
    if (features.containsKey('suggest_place')) {
      final ok2 = await AppSettingsService.set(
          AppSettingsService.placeSuggestions, features['suggest_place']!);
      await instance.refresh(force: true);
      return ok && ok2;
    }
    return ok;
  }

  /// وەشانی ئێستای ئەم ئەپە
  static String get currentVersion => AppConstants.appVersion;
}
