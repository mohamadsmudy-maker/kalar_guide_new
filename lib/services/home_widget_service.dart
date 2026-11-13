import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../l10n/tr.dart';
import 'currency_service.dart';
import 'prayer/kalar_prayer_times.dart';
import 'weather_service.dart';

/// 📱 ویجێتی سەر شاشەی ئەندرۆید: نوێژی داهاتوو، پلەی گەرما و نرخی دۆلار.
///
/// ئەپەکە داتا دەنێرێت بۆ SharedPreferences ـی ویجێتەکە، و `KalarWidgetProvider`
/// (Kotlin) لەوێوە دەیخوێنێتەوە. کاتی نوێژەکانی ئەمڕۆ و بەیانی دەنێردرێن، بۆ ئەوەی
/// ویجێتەکە بێ ئینتەرنێت و بێ کردنەوەی ئەپ «نوێژی داهاتوو» بدۆزێتەوە.
/// هەرگیز هەڵە ناگەڕێنێتەوە: ئەگەر شتێک شکا، ویجێتەکە داتای پێشوو پیشان دەدات.
class HomeWidgetService with WidgetsBindingObserver {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const String androidProvider =
      'com.muhammad.kalar.kalar_guide.KalarWidgetProvider';
  static const Duration _minGap = Duration(minutes: 10);
  static const List<String> prayerIds = [
    'fajr',
    'sunrise',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  bool _started = false;
  bool _running = false;
  DateTime? _last;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// یەکجار لە دەستپێکردنی ئەپ بانگ بکە
  void start() {
    if (_started || !_supported) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// داتا دەنێرێت و ویجێتەکە نوێ دەکاتەوە
  Future<void> refresh({bool force = false}) async {
    if (!_supported || _running) return;
    final now = DateTime.now();
    if (!force && _last != null && now.difference(_last!) < _minGap) return;
    _running = true;
    _last = now;
    try {
      final data = <String, String>{...prayerData(now)};
      data.addAll(await _weatherData());
      data.addAll(await _currencyData());
      data['updated'] = _digits('${_two(now.hour)}:${_two(now.minute)}');
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } catch (e) {
      debugPrint('⚠️ home widget: $e');
    } finally {
      _running = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🕌 نوێژ (بێ ئینتەرنێت)
  // ═══════════════════════════════════════════════════════════
  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String _digits(String s) {
    if (!AppLang.isRtl) return s;
    const ku = '٠١٢٣٤٥٦٧٨٩';
    return s.replaceAllMapped(RegExp(r'\d'), (m) => ku[int.parse(m[0]!)]);
  }

  /// ناوی نوێژەکان بە زمانی ئێستا
  static Map<String, String> prayerNames() => {
        'fajr': tr('بەیانی'),
        'sunrise': tr('خۆرهەڵاتن'),
        'dhuhr': tr('نیوەڕۆ'),
        'asr': tr('عەسر'),
        'maghrib': tr('مەغریب'),
        'isha': tr('عیشا'),
      };

  /// کاتی نوێژی ئەمڕۆ (d0) و بەیانی (d1) + ناو و دەقە وەرگێڕدراوەکان.
  /// کاتەکان بە ژمارەی لاتینی (`HH:mm`) دەنێردرێن، چونکە Kotlin دەیانخوێنێتەوە؛
  /// پیشاندانی ژمارە بە `digits` دیاری دەکرێت.
  @visibleForTesting
  static Map<String, String> prayerData(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final out = <String, String>{
      'lang': AppLang.code,
      'digits': AppLang.isRtl ? '1' : '0',
      'title': tr('ڕێبەری کەلار'),
      'next_label': tr('نوێژی داهاتوو'),
      'tpl_min': tr('{0} خولەکی ماوە'),
      'tpl_hm': tr('{0} کاتژمێر و {1} خولەک'),
      'd0_date': _date(today),
      'd1_date': _date(tomorrow),
    };
    final names = prayerNames();
    final t0 = KalarPrayerTimes.forDay(today).times;
    final t1 = KalarPrayerTimes.forDay(tomorrow).times;
    for (final id in prayerIds) {
      out['name_$id'] = names[id]!;
      out['d0_$id'] = t0[id] ?? '';
      out['d1_$id'] = t1[id] ?? '';
    }
    return out;
  }

  // ═══════════════════════════════════════════════════════════
  // 🌤️ کەشوهەوا و 💵 دراو — تەنها ئەگەر هاتن؛ ئەگەرنا داتای پێشوو دەمێنێت
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, String>> _weatherData() async {
    try {
      final svc = WeatherService.instance;
      if (svc.snapshot.value == null) {
        await svc.refresh().timeout(const Duration(seconds: 8));
      }
      final c = svc.snapshot.value?.current;
      if (c == null) return const {};
      final cond = WeatherService.conditionOf(c.code, c.temp, c.isDay);
      return {
        'temp': _digits('${c.temp}°'),
        'emoji': c.emojiOverride ?? cond.emoji,
      };
    } catch (e) {
      debugPrint('⚠️ home widget weather: $e');
      return const {};
    }
  }

  Future<Map<String, String>> _currencyData() async {
    try {
      final snap = await CurrencyService.getMarketSnapshot(monthsBack: 1)
          .timeout(const Duration(seconds: 10));
      final usd = snap.markets['usd'];
      if (usd == null || !usd.hasData || usd.avgSell <= 0) return const {};
      final per = (CurrencyService.currencyTypes
                  .where((t) => t['key'] == 'usd')
                  .map((t) => t['per'] as num?)
                  .firstOrNull ??
              100)
          .toInt();
      final v = usd.avgSell.round().toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => ',',
          );
      return {
        'usd_label': '${_digits('$per')} ${tr('دۆلار')}',
        'usd_value': '${_digits(v)} ${tr('دینار')}',
      };
    } catch (e) {
      debugPrint('⚠️ home widget currency: $e');
      return const {};
    }
  }
}
