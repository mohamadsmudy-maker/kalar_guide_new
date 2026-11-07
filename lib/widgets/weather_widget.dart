// lib/widgets/weather_widget.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../config/settings_provider.dart';
import '../services/weather_service.dart';

/// 🌤️ ویجێتی کەشوهەوا — Ultra Pro Max V4
///
/// ✅ تەنها یەک سەرچاوەی داتا: [WeatherService] (هیچ داواکارییەکی دووبارە نییە)
/// ✅ دوگمەی AppBar و ڕاکێشان بۆ نوێکردنەوە ئێستا ڕاستەوخۆ کار دەکەن
/// ✅ [full] = false → کارتی ئێستا + ٧ ڕۆژ (بۆ ماڵەوە)
/// ✅ [full] = true  → + کاتژمێری، خۆر، وردەکاری، کوالیتی هەوا
/// ✅ کلیک لەسەر هەر ڕۆژێک → وردەکاری ئەو ڕۆژە
/// ✅ دۆخی تاریک/ڕووناک، RTL/LTR، ژمارەی کوردی/عەرەبی
class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key, this.full = false});

  /// ئەگەر true بێت هەموو بەشەکان پیشان دەدرێن (بۆ شاشەی کەشوهەوا).
  final bool full;

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _autoRefresh = Duration(minutes: 15);
  static const Duration _resumeStale = Duration(minutes: 10);
  static const Color _accent = Color(0xFF0288D1);

  final WeatherService _svc = WeatherService.instance;
  String _lang = 'ku';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  Timer? _timer;

  // ═══════════════════════════════════════════════════════════
  // 🌍 زمانەکان
  // ═══════════════════════════════════════════════════════════
  static const Map<String, Map<String, String>> _tr = {
    'location': {'ku': 'کەلار', 'ar': 'كلار', 'en': 'Kalar'},
    'official': {'ku': '🏛️ فەرمی', 'ar': '🏛️ رسمي', 'en': '🏛️ Official'},
    'live': {'ku': '🌐 ڕاستەوخۆ', 'ar': '🌐 مباشر', 'en': '🌐 Live'},
    'feels': {'ku': 'هەست پێکراو', 'ar': 'يبدو كأنه', 'en': 'Feels like'},
    'humidity': {'ku': 'شێداری', 'ar': 'الرطوبة', 'en': 'Humidity'},
    'wind': {'ku': 'با', 'ar': 'الرياح', 'en': 'Wind'},
    'pressure': {'ku': 'پەستان', 'ar': 'الضغط', 'en': 'Pressure'},
    'kmh': {'ku': 'کم/س', 'ar': 'كم/س', 'en': 'km/h'},
    'km': {'ku': 'کم', 'ar': 'كم', 'en': 'km'},
    'mm': {'ku': 'ملم', 'ar': 'ملم', 'en': 'mm'},
    'forecast': {
      'ku': 'پێشبینی ٧ ڕۆژی داهاتوو',
      'ar': 'توقعات ٧ أيام',
      'en': '7-day forecast'
    },
    'hourly': {
      'ku': 'پێشبینی کاتژمێری',
      'ar': 'توقعات كل ساعة',
      'en': 'Hourly forecast'
    },
    'details': {'ku': 'وردەکاری', 'ar': 'التفاصيل', 'en': 'Details'},
    'sun': {'ku': 'خۆر', 'ar': 'الشمس', 'en': 'Sun'},
    'air': {'ku': 'کوالیتی هەوا', 'ar': 'جودة الهواء', 'en': 'Air quality'},
    'today': {'ku': 'ئەمڕۆ', 'ar': 'اليوم', 'en': 'Today'},
    'tomorrow': {'ku': 'سبەینێ', 'ar': 'غداً', 'en': 'Tomorrow'},
    'now': {'ku': 'ئێستا', 'ar': 'الآن', 'en': 'Now'},
    'uv': {'ku': 'تیشکی UV', 'ar': 'مؤشر UV', 'en': 'UV index'},
    'uv_max': {'ku': 'بەرزترین UV', 'ar': 'أعلى UV', 'en': 'Max UV'},
    'visibility': {'ku': 'بینین', 'ar': 'الرؤية', 'en': 'Visibility'},
    'gust': {'ku': 'زەبری با', 'ar': 'هبات الرياح', 'en': 'Wind gusts'},
    'wind_dir': {
      'ku': 'ئاراستەی با',
      'ar': 'اتجاه الرياح',
      'en': 'Wind direction'
    },
    'wind_max': {'ku': 'بەهێزترین با', 'ar': 'أقصى رياح', 'en': 'Max wind'},
    'cloud': {'ku': 'هەور', 'ar': 'الغيوم', 'en': 'Cloud cover'},
    'rain': {'ku': 'باران', 'ar': 'الأمطار', 'en': 'Rain'},
    'rain_chance': {
      'ku': 'ئەگەری باران',
      'ar': 'احتمال المطر',
      'en': 'Chance of rain'
    },
    'sunrise': {'ku': 'خۆرهەڵاتن', 'ar': 'الشروق', 'en': 'Sunrise'},
    'sunset': {'ku': 'خۆرئاوابوون', 'ar': 'الغروب', 'en': 'Sunset'},
    'daylight': {'ku': 'درێژی ڕۆژ', 'ar': 'طول النهار', 'en': 'Daylight'},
    'dust': {'ku': 'تۆز', 'ar': 'الغبار', 'en': 'Dust'},
    'dust_alert': {
      'ku': 'تەپوتۆز — ئەگەر هەناسەت تەنگە، لە ماڵەوە بمێنەوە',
      'ar': 'غبار — يُنصح مرضى الربو بالبقاء في الداخل',
      'en': 'Dusty air — sensitive groups should stay indoors'
    },
    'uv_low': {'ku': 'نزم', 'ar': 'منخفض', 'en': 'Low'},
    'uv_moderate': {'ku': 'مامناوەند', 'ar': 'متوسط', 'en': 'Moderate'},
    'uv_high': {'ku': 'بەرز', 'ar': 'مرتفع', 'en': 'High'},
    'uv_very_high': {'ku': 'زۆر بەرز', 'ar': 'مرتفع جداً', 'en': 'Very high'},
    'uv_extreme': {'ku': 'مەترسیدار', 'ar': 'شديد', 'en': 'Extreme'},
    'aqi_good': {'ku': 'باش', 'ar': 'جيد', 'en': 'Good'},
    'aqi_moderate': {'ku': 'مامناوەند', 'ar': 'متوسط', 'en': 'Moderate'},
    'aqi_sensitive': {
      'ku': 'نالەبار بۆ هەستیاران',
      'ar': 'غير صحي للحساسين',
      'en': 'Unhealthy for sensitive groups'
    },
    'aqi_unhealthy': {'ku': 'نالەبار', 'ar': 'غير صحي', 'en': 'Unhealthy'},
    'aqi_very': {
      'ku': 'زۆر نالەبار',
      'ar': 'غير صحي جداً',
      'en': 'Very unhealthy'
    },
    'aqi_hazard': {'ku': 'مەترسیدار', 'ar': 'خطير', 'en': 'Hazardous'},
    'loading': {
      'ku': 'خەریکی هێنانی کەشوهەوا...',
      'ar': 'جارٍ تحميل الطقس...',
      'en': 'Loading weather...'
    },
    'error': {
      'ku': 'کەشوهەوا نەهات',
      'ar': 'تعذر تحميل الطقس',
      'en': 'Could not load weather'
    },
    'error_sub': {
      'ku': 'ئینتەرنێتەکەت بپشکنە',
      'ar': 'تحقق من الاتصال',
      'en': 'Check your connection'
    },
    'retry': {'ku': 'دووبارە', 'ar': 'إعادة', 'en': 'Retry'},
    'offline': {
      'ku': 'ئۆفلاین — داتای کۆن',
      'ar': 'غير متصل — بيانات قديمة',
      'en': 'Offline — showing old data'
    },
    'refresh': {'ku': 'نوێکردنەوە', 'ar': 'تحديث', 'en': 'Refresh'},
  };

  static const Map<String, Map<String, String>> _cond = {
    'clear': {'ku': 'ساماڵ', 'ar': 'صافٍ', 'en': 'Clear'},
    'clear_night': {'ku': 'شەوی ساماڵ', 'ar': 'ليل صافٍ', 'en': 'Clear night'},
    'mostly_clear': {
      'ku': 'زۆربەی ساماڵ',
      'ar': 'صافٍ غالباً',
      'en': 'Mostly clear'
    },
    'partly': {'ku': 'کەمێک هەور', 'ar': 'غائم جزئياً', 'en': 'Partly cloudy'},
    'cloudy': {'ku': 'هەور', 'ar': 'غائم', 'en': 'Cloudy'},
    'fog': {'ku': 'تەم', 'ar': 'ضباب', 'en': 'Fog'},
    'drizzle': {'ku': 'نەمەباران', 'ar': 'رذاذ', 'en': 'Drizzle'},
    'rain': {'ku': 'باران', 'ar': 'مطر', 'en': 'Rain'},
    'freezing_rain': {
      'ku': 'بارانی بەستەڵەک',
      'ar': 'مطر متجمد',
      'en': 'Freezing rain'
    },
    'showers': {'ku': 'بارانی بەخوڕ', 'ar': 'زخات مطر', 'en': 'Showers'},
    'snow': {'ku': 'بەفر', 'ar': 'ثلج', 'en': 'Snow'},
    'snow_showers': {
      'ku': 'بەفری بەخوڕ',
      'ar': 'زخات ثلج',
      'en': 'Snow showers'
    },
    'thunder': {'ku': 'هەورەبروسکە', 'ar': 'عاصفة رعدية', 'en': 'Thunderstorm'},
    'hot': {'ku': 'زۆر گەرم', 'ar': 'حار جداً', 'en': 'Very hot'},
    'cold': {'ku': 'زۆر سارد', 'ar': 'بارد جداً', 'en': 'Very cold'},
    'unknown': {'ku': 'نەزانراو', 'ar': 'غير معروف', 'en': 'Unknown'},
  };

  static const Map<String, List<String>> _dayNames = {
    'ku': [
      'دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە',
      'هەینی', 'شەممە', 'یەکشەممە'
    ],
    'ar': [
      'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
      'الجمعة', 'السبت', 'الأحد'
    ],
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  };

  static const Map<String, List<String>> _compassNames = {
    'ku': [
      'باکوور', 'باکووری ڕۆژهەڵات', 'ڕۆژهەڵات', 'باشووری ڕۆژهەڵات',
      'باشوور', 'باشووری ڕۆژئاوا', 'ڕۆژئاوا', 'باکووری ڕۆژئاوا'
    ],
    'ar': [
      'شمال', 'شمال شرق', 'شرق', 'جنوب شرق',
      'جنوب', 'جنوب غرب', 'غرب', 'شمال غرب'
    ],
    'en': ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'],
  };

  String _t(String k) => _tr[k]?[_lang] ?? _tr[k]?['en'] ?? k;

  /// ژمارەی ئینگلیزی → ژمارەی کوردی/عەرەبی
  String _n(Object v) {
    final s = '$v';
    if (_lang == 'en') return s;
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final d = int.tryParse(ch);
      if (d != null) {
        b.write(ar[d]);
      } else if (ch == '.') {
        b.write('٫');
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  String _hm(DateTime t) => _n(intl.DateFormat('HH:mm').format(t));

  String _fmt1(double v) {
    if (v >= 10) return '${v.round()}';
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  String _compass(int deg) {
    final i = (((deg % 360) + 22.5) ~/ 45) % 8;
    return (_compassNames[_lang] ?? _compassNames['en']!)[i];
  }

  String _dayName(WeatherDay d, DateTime now) {
    if (WeatherSnapshot.isSameDay(d.date, now)) return _t('today');
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (WeatherSnapshot.isSameDay(d.date, tomorrow)) return _t('tomorrow');
    return (_dayNames[_lang] ?? _dayNames['en']!)[d.date.weekday - 1];
  }

  Color _text(bool isDark) => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color _sub(bool isDark) => isDark ? Colors.white60 : Colors.black54;

  // ═══════════════════════════════════════════════════════════
  // 🔄 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    if (_svc.snapshot.value != null) _fadeController.value = 1;
    _svc.snapshot.addListener(_onSnapshot);

    unawaited(_svc.ensureFresh());
    _timer = Timer.periodic(
      _autoRefresh,
          (_) => _svc.ensureFresh(maxAge: _autoRefresh - const Duration(minutes: 1)),
    );
  }

  void _onSnapshot() {
    if (_svc.snapshot.value != null &&
        _fadeController.value == 0 &&
        !_fadeController.isAnimating) {
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _svc.snapshot.removeListener(_onSnapshot);
    _timer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_svc.ensureFresh(maxAge: _resumeStale));
    }
  }

  void _manualRefresh() {
    HapticFeedback.selectionClick();
    unawaited(_svc.refresh());
  }

  // ═══════════════════════════════════════════════════════════
  // 🌦️ Condition / colors
  // ═══════════════════════════════════════════════════════════
  ({String emoji, String text}) _condition(WeatherCurrent c) {
    final base = WeatherService.conditionOf(c.code, c.temp, c.isDay);
    return (
    emoji: c.emojiOverride ?? base.emoji,
    text: c.textOverride ?? (_cond[base.key]?[_lang] ?? base.key),
    );
  }

  String _condText(String key) => _cond[key]?[_lang] ?? key;

  List<Color> _gradient(WeatherCurrent c) {
    final code = c.code;
    if (!c.isDay && (code == null || code <= 3)) {
      return const [Color(0xFF3949AB), Color(0xFF1A237E), Color(0xFF0D1445)];
    }
    if (code != null) {
      if (code >= 95) {
        return const [Color(0xFF7E57C2), Color(0xFF4527A0), Color(0xFF1A1055)];
      }
      if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
        return const [Color(0xFF78909C), Color(0xFF546E7A), Color(0xFF37474F)];
      }
      if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
        return const [Color(0xFF90CAF9), Color(0xFF64B5F6), Color(0xFF1E88E5)];
      }
      if (code == 45 || code == 48) {
        return const [Color(0xFFB0BEC5), Color(0xFF90A4AE), Color(0xFF607D8B)];
      }
    }
    if (c.temp >= 40) {
      return const [Color(0xFFFFB74D), Color(0xFFF57C00), Color(0xFFBF360C)];
    }
    return const [Color(0xFF4FC3F7), Color(0xFF0288D1), Color(0xFF01579B)];
  }

  static Color _tempColor(int t) {
    if (t <= 0) return const Color(0xFF90CAF9);
    if (t <= 10) return const Color(0xFF4FC3F7);
    if (t <= 20) return const Color(0xFF66BB6A);
    if (t <= 30) return const Color(0xFFFFCA28);
    if (t <= 40) return const Color(0xFFFF7043);
    return const Color(0xFFD32F2F);
  }

  ({String text, Color color}) _uvLevel(double uv) {
    if (uv < 3) return (text: _t('uv_low'), color: const Color(0xFF43A047));
    if (uv < 6) {
      return (text: _t('uv_moderate'), color: const Color(0xFFF9A825));
    }
    if (uv < 8) return (text: _t('uv_high'), color: const Color(0xFFFB8C00));
    if (uv < 11) {
      return (text: _t('uv_very_high'), color: const Color(0xFFE53935));
    }
    return (text: _t('uv_extreme'), color: const Color(0xFF8E24AA));
  }

  ({String text, Color color}) _aqiLevel(int aqi) {
    if (aqi <= 50) return (text: _t('aqi_good'), color: const Color(0xFF43A047));
    if (aqi <= 100) {
      return (text: _t('aqi_moderate'), color: const Color(0xFFF9A825));
    }
    if (aqi <= 150) {
      return (text: _t('aqi_sensitive'), color: const Color(0xFFFB8C00));
    }
    if (aqi <= 200) {
      return (text: _t('aqi_unhealthy'), color: const Color(0xFFE53935));
    }
    if (aqi <= 300) {
      return (text: _t('aqi_very'), color: const Color(0xFF8E24AA));
    }
    return (text: _t('aqi_hazard'), color: const Color(0xFF7E0023));
  }

  BoxDecoration _surface(bool isDark, {double radius = 20}) => BoxDecoration(
    color: isDark ? const Color(0xFF1A1A22) : Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    _lang = context.select<SettingsProvider, String>((s) => s.languageId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _svc.listenable,
      builder: (context, _) {
        final snap = _svc.snapshot.value;
        final refreshing = _svc.refreshing.value;
        final failed = _svc.lastFailed.value;

        if (snap == null) {
          return (failed && !refreshing) ? _buildError() : _buildLoading();
        }

        final hours = snap.upcomingHours;

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCurrentCard(snap, refreshing, failed),
              if (widget.full && hours.isNotEmpty) ...[
                _sectionTitle(Icons.schedule_rounded, _t('hourly'), isDark),
                _buildHourly(hours, isDark),
              ],
              if (widget.full) ..._buildSunSection(snap, isDark),
              if (widget.full) ...[
                _sectionTitle(Icons.tune_rounded, _t('details'), isDark),
                _buildDetailsGrid(snap, isDark),
              ],
              if (widget.full && snap.air != null) ...[
                _sectionTitle(Icons.masks_rounded, _t('air'), isDark),
                _buildAir(snap.air!, isDark),
              ],
              if (snap.days.isNotEmpty) ...[
                _sectionTitle(
                    Icons.calendar_month_rounded, _t('forecast'), isDark),
                _buildForecast(snap, isDark),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _text(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌡️ کارتی ئێستا
  // ═══════════════════════════════════════════════════════════
  Widget _buildCurrentCard(WeatherSnapshot snap, bool refreshing, bool failed) {
    final c = snap.current;
    final cond = _condition(c);
    final colors = _gradient(c);
    final today = snap.today;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors[1].withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── سەرەوە ───
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.white, size: 12),
              ),
              const SizedBox(width: 6),
              Text(
                _t('location'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.official
                      ? Colors.amber.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.official ? _t('official') : _t('live'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              if (failed)
                Tooltip(
                  message: _t('offline'),
                  child: const Padding(
                    padding: EdgeInsetsDirectional.only(end: 6),
                    child: Icon(Icons.cloud_off_rounded,
                        color: Colors.amberAccent, size: 13),
                  ),
                ),
              Icon(Icons.access_time_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 11),
              const SizedBox(width: 3),
              Text(
                _hm(c.updatedAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              _RefreshButton(
                spinning: refreshing,
                tooltip: _t('refresh'),
                onTap: refreshing ? null : _manualRefresh,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── پلەی گەرمی و ئایکۆن ───
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _n(c.temp),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            '°C',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      cond.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RepaintBoundary(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(cond.emoji,
                          style: const TextStyle(fontSize: 50)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── وردەکاری ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _detail(
                    Icons.water_drop_rounded,
                    _t('humidity'),
                    c.humidity == null ? '--' : '${_n(c.humidity!)}%',
                  ),
                ),
                _vDivider(),
                Expanded(
                  child: _detail(
                    Icons.air_rounded,
                    _t('wind'),
                    c.wind == null ? '--' : '${_n(c.wind!)} ${_t('kmh')}',
                  ),
                ),
                _vDivider(),
                Expanded(
                  child: _detail(
                    Icons.speed_rounded,
                    _t('pressure'),
                    c.pressure == null ? '--' : '${_n(c.pressure!)} hPa',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── هەست پێکراو + بەرز/نزم ───
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              if (c.feels != null)
                _pill(
                  Icons.thermostat_rounded,
                  '${_t('feels')}: ${_n(c.feels!)}°',
                ),
              if (today != null)
                _pill(
                  Icons.swap_vert_rounded,
                  '${_n(today.max)}° / ${_n(today.min)}°',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 40,
    color: Colors.white.withValues(alpha: 0.2),
  );

  // ═══════════════════════════════════════════════════════════
  // 🕐 پێشبینی کاتژمێری
  // ═══════════════════════════════════════════════════════════
  Widget _buildHourly(List<WeatherHour> hours, bool isDark) {
    final list = hours.take(24).toList();

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final h = list[i];
          final isNow = i == 0;
          final cond = WeatherService.conditionOf(h.code, h.temp, h.isDay);
          final rain = h.rainChance;
          final fg = isNow ? Colors.white : _text(isDark);

          return Container(
            width: 66,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: isNow
                ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            )
                : _surface(isDark, radius: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isNow ? _t('now') : _hm(h.time),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isNow ? Colors.white : _sub(isDark),
                    height: 1.2,
                  ),
                ),
                Text(cond.emoji,
                    style: const TextStyle(fontSize: 24, height: 1.2)),
                Text(
                  '${_n(h.temp)}°',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: fg,
                    height: 1.2,
                  ),
                ),
                Text(
                  (rain != null && rain >= 20) ? '💧${_n(rain)}%' : ' ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isNow ? Colors.white : const Color(0xFF29B6F6),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ☀️ خۆرهەڵاتن / خۆرئاوابوون
  // ═══════════════════════════════════════════════════════════
  List<Widget> _buildSunSection(WeatherSnapshot snap, bool isDark) {
    final today = snap.today;
    final rise = today?.sunrise;
    final set = today?.sunset;
    if (rise == null || set == null || !set.isAfter(rise)) return const [];

    final now = snap.nowEstimate;
    final total = set.difference(rise);
    final p =
    (now.difference(rise).inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final isDayNow = now.isAfter(rise) && now.isBefore(set);
    final daylight =
        '${total.inHours}:${(total.inMinutes % 60).toString().padLeft(2, '0')}';

    Widget end(IconData icon, String label, String value, Color color) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _text(isDark))),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _sub(isDark))),
        ],
      );
    }

    return [
      _sectionTitle(Icons.wb_sunny_rounded, _t('sun'), isDark),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: _surface(isDark),
        child: Column(
          children: [
            Row(
              children: [
                end(Icons.wb_twilight_rounded, _t('sunrise'), _hm(rise),
                    const Color(0xFFFFA000)),
                const Spacer(),
                end(Icons.hourglass_bottom_rounded, _t('daylight'),
                    _n(daylight), _accent),
                const Spacer(),
                end(Icons.nights_stay_rounded, _t('sunset'), _hm(set),
                    const Color(0xFFF4511E)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 28,
              child: LayoutBuilder(
                builder: (context, cons) {
                  const dot = 28.0;
                  final x = (cons.maxWidth - dot) * p;
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              begin: AlignmentDirectional.centerStart,
                              end: AlignmentDirectional.centerEnd,
                              colors: [
                                Color(0xFFFFCA28),
                                Color(0xFFFFA000),
                                Color(0xFFF4511E),
                              ],
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: x,
                        top: 0,
                        child: Container(
                          width: dot,
                          height: dot,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDayNow
                                ? const Color(0xFFFFB300)
                                : const Color(0xFF3949AB),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            isDayNow
                                ? Icons.wb_sunny_rounded
                                : Icons.nightlight_round,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 وردەکاری
  // ═══════════════════════════════════════════════════════════
  Widget _buildDetailsGrid(WeatherSnapshot snap, bool isDark) {
    final c = snap.current;
    final today = snap.today;
    final uv = c.uv ?? today?.uvMax;
    final uvL = uv == null ? null : _uvLevel(uv);
    final vis = c.visibilityKm;
    final rainMm = today?.rainMm;

    final tiles = <Widget>[
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.wb_sunny_rounded),
        color: const Color(0xFFFFA000),
        label: _t('uv'),
        value: uv == null ? '--' : _n(uv.round()),
        sub: uvL?.text,
        subColor: uvL?.color,
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.visibility_rounded),
        color: const Color(0xFF26A69A),
        label: _t('visibility'),
        value: vis == null ? '--' : '${_n(_fmt1(vis))} ${_t('km')}',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.storm_rounded),
        color: const Color(0xFF5C6BC0),
        label: _t('gust'),
        value: c.gust == null ? '--' : '${_n(c.gust!)} ${_t('kmh')}',
      ),
      _tile(
        isDark: isDark,
        icon: Transform.rotate(
          // ئاراستەی با = ئەو لایەی لێیەوە دێت، تیرەکە بەرەو کوێ دەڕوات
          angle: ((c.windDir ?? 0) + 180) * math.pi / 180,
          child: const Icon(Icons.navigation_rounded),
        ),
        color: const Color(0xFF29B6F6),
        label: _t('wind_dir'),
        value: c.windDir == null ? '--' : _compass(c.windDir!),
        sub: c.windDir == null ? null : '${_n(c.windDir!)}°',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.cloud_rounded),
        color: const Color(0xFF78909C),
        label: _t('cloud'),
        value: c.cloud == null ? '--' : '${_n(c.cloud!)}%',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.umbrella_rounded),
        color: const Color(0xFF1E88E5),
        label: _t('rain'),
        value: rainMm == null ? '--' : '${_n(_fmt1(rainMm))} ${_t('mm')}',
        sub: today?.rainChance == null
            ? null
            : '${_t('rain_chance')}: ${_n(today!.rainChance!)}%',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _grid(tiles),
    );
  }

  Widget _grid(List<Widget> tiles) {
    return LayoutBuilder(
      builder: (context, cons) {
        final w = (cons.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  Widget _tile({
    required bool isDark,
    required Widget icon,
    required Color color,
    required String label,
    required String value,
    String? sub,
    Color? subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _surface(isDark, radius: 18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: color, size: 22),
                child: icon,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _sub(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _text(isDark),
                  ),
                ),
                // هەمیشە هەیە تا هەموو خانەکان هەمان بەرزییان هەبێت
                Text(
                  sub ?? ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: subColor ?? _sub(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌫️ کوالیتی هەوا
  // ═══════════════════════════════════════════════════════════
  Widget _buildAir(AirQuality a, bool isDark) {
    final lvl = _aqiLevel(a.aqi);
    final dusty = (a.dust ?? 0) >= 100;

    Widget stat(String label, double? v) => Column(
      children: [
        Text(
          v == null ? '--' : _n(v.round()),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _text(isDark),
          ),
        ),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _sub(isDark))),
        Text('µg/m³',
            style: TextStyle(fontSize: 9, color: _sub(isDark))),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _surface(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lvl.color.withValues(alpha: 0.15),
                  border: Border.all(color: lvl.color, width: 2),
                ),
                child: Center(
                  child: Text(
                    _n(a.aqi),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: lvl.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lvl.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: lvl.color,
                      ),
                    ),
                    Text('US AQI',
                        style: TextStyle(fontSize: 11, color: _sub(isDark))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AqiBar(aqi: a.aqi),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: stat('PM2.5', a.pm25)),
              Expanded(child: stat('PM10', a.pm10)),
              Expanded(child: stat(_t('dust'), a.dust)),
            ],
          ),
          if (dusty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA000).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFA000).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFFA000), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t('dust_alert'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _text(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 پێشبینی ٧ ڕۆژ
  // ═══════════════════════════════════════════════════════════
  Widget _buildForecast(WeatherSnapshot snap, bool isDark) {
    final now = snap.nowEstimate;
    final weekMin = snap.days.map((d) => d.min).reduce(math.min);
    final weekMax = snap.days.map((d) => d.max).reduce(math.max);
    final span = math.max(1, weekMax - weekMin);

    return Column(
      children: snap.days.map((day) {
        final isToday = WeatherSnapshot.isSameDay(day.date, now);
        final cond = WeatherService.conditionOf(day.code, day.max, true);

        final bgColor = isToday
            ? _accent.withValues(alpha: isDark ? 0.2 : 0.08)
            : (isDark ? const Color(0xFF1A1A22) : Colors.white);
        final borderColor =
        isToday ? _accent.withValues(alpha: 0.3) : Colors.transparent;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openDay(day, now),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // ١. ناوی ڕۆژ
                SizedBox(
                  width: 84,
                  child: Text(
                    _dayName(day, now),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.bold,
                      color: isToday
                          ? _accent
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                // ٢. ئایکۆن + ئەگەری باران
                SizedBox(
                  width: 30,
                  child: Text(cond.emoji, style: const TextStyle(fontSize: 22)),
                ),
                SizedBox(
                  width: 38,
                  child: (day.rainChance != null && day.rainChance! >= 30)
                      ? Text(
                    '${_n(day.rainChance!)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF29B6F6),
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
                // ٣. نزم — هێڵی مەودا — بەرز
                SizedBox(
                  width: 30,
                  child: Text(
                    '${_n(day.min)}°',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RangeBar(
                    start: (day.min - weekMin) / span,
                    end: (day.max - weekMin) / span,
                    from: _tempColor(day.min),
                    to: _tempColor(day.max),
                    track: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${_n(day.max)}°',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── وردەکاری ڕۆژێک (Bottom Sheet) ───
  void _openDay(WeatherDay day, DateTime now) {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cond = WeatherService.conditionOf(day.code, day.max, true);
    final uvL = day.uvMax == null ? null : _uvLevel(day.uvMax!);

    final tiles = <Widget>[
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.water_drop_rounded),
        color: const Color(0xFF29B6F6),
        label: _t('rain_chance'),
        value: day.rainChance == null ? '--' : '${_n(day.rainChance!)}%',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.umbrella_rounded),
        color: const Color(0xFF1E88E5),
        label: _t('rain'),
        value: day.rainMm == null
            ? '--'
            : '${_n(_fmt1(day.rainMm!))} ${_t('mm')}',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.wb_sunny_rounded),
        color: const Color(0xFFFFA000),
        label: _t('uv_max'),
        value: day.uvMax == null ? '--' : _n(day.uvMax!.round()),
        sub: uvL?.text,
        subColor: uvL?.color,
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.air_rounded),
        color: const Color(0xFF5C6BC0),
        label: _t('wind_max'),
        value:
        day.windMax == null ? '--' : '${_n(day.windMax!)} ${_t('kmh')}',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.wb_twilight_rounded),
        color: const Color(0xFFFFA000),
        label: _t('sunrise'),
        value: day.sunrise == null ? '--' : _hm(day.sunrise!),
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.nights_stay_rounded),
        color: const Color(0xFFF4511E),
        label: _t('sunset'),
        value: day.sunset == null ? '--' : _hm(day.sunset!),
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: _lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121218) : const Color(0xFFF5F7FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, 20 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _sub(isDark).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(cond.emoji, style: const TextStyle(fontSize: 44)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dayName(day, now),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _text(isDark),
                          ),
                        ),
                        Text(
                          '${_condText(cond.key)} · '
                              '${_n(intl.DateFormat('d/M').format(day.date))}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _sub(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_n(day.max)}°',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _text(isDark),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_n(day.min)}°',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _sub(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _grid(tiles),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ Loading / ❌ Error
  // ═══════════════════════════════════════════════════════════
  BoxDecoration _placeholderDecoration() => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: _accent.withValues(alpha: 0.3),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  Widget _buildLoading() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _placeholderDecoration(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t('loading'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _placeholderDecoration().copyWith(
        gradient: const LinearGradient(
          colors: [Color(0xFF90A4AE), Color(0xFF546E7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              _t('error'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _t('error_sub'),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _manualRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                _t('retry'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🌡️ هێڵی مەودای پلەی گەرمی (نزم ← → بەرز)
// ═══════════════════════════════════════════════════════════
class _RangeBar extends StatelessWidget {
  final double start; // 0..1
  final double end; // 0..1
  final Color from;
  final Color to;
  final Color track;

  const _RangeBar({
    required this.start,
    required this.end,
    required this.from,
    required this.to,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: LayoutBuilder(
        builder: (context, cons) {
          final w = cons.maxWidth;
          final width = math.min(w, math.max(6.0, w * (end - start)));
          final s = math.max(0.0, math.min(w * start, w - width));
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              PositionedDirectional(
                start: s,
                width: width,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [from, to],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🌫️ هێڵی ڕەنگاوڕەنگی AQI
// ═══════════════════════════════════════════════════════════
class _AqiBar extends StatelessWidget {
  final int aqi;
  const _AqiBar({required this.aqi});

  @override
  Widget build(BuildContext context) {
    final p = (aqi.clamp(0, 300)) / 300;
    return SizedBox(
      height: 16,
      child: LayoutBuilder(
        builder: (context, cons) {
          const dot = 16.0;
          final x = (cons.maxWidth - dot) * p;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        Color(0xFF43A047),
                        Color(0xFFF9A825),
                        Color(0xFFFB8C00),
                        Color(0xFFE53935),
                        Color(0xFF8E24AA),
                        Color(0xFF7E0023),
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: x,
                top: 0,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.black26, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔄 دوگمەی نوێکردنەوە
// ═══════════════════════════════════════════════════════════
class _RefreshButton extends StatefulWidget {
  final bool spinning;
  final String tooltip;
  final VoidCallback? onTap;

  const _RefreshButton({
    required this.spinning,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _RefreshButton old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.animateTo(1).whenComplete(() {
        if (mounted) _c.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: InkResponse(
        onTap: widget.onTap,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: RotationTransition(
            turns: _c,
            child: Icon(
              Icons.refresh_rounded,
              color: Colors.white.withValues(alpha: 0.85),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}