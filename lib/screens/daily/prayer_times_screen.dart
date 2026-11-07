// lib/screens/daily/prayer_times_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_colors.dart';
import '../../services/prayer/kalar_prayer_times.dart';
import '../../services/prayer_notification_service.dart';
import '../daily/qibla_finder_screen.dart';
import '../prayer/adhan_settings_screen.dart';
import '../prayer/prayer_weekly_view.dart';

part 'prayer_times_screen_ui.dart';

/// 🕌 کاتەکانی نوێژ — ULTRA PRO MAX V11
///
/// ✅ کاتەکان یەکسەر پیشان دەدرێن (شوێن لە پاشەوە وردتر دەکرێتەوە)
/// ✅ نوێبوونەوەی خۆکار لە نیوەشەو (ڕۆژی نوێ)
/// ✅ ستریک بە دروستی سفر دەبێتەوە ئەگەر ڕۆژێک لەدەست بچێت
/// ✅ تەنها کاونتداونەکە هەموو چرکەیەک نوێ دەبێتەوە، نەک هەموو شاشەکە
/// ✅ گوێگری ئەزان یەک جار تۆمار دەکرێت (leak نییە)
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

// ═══════════════════════════════════════════════════════════
// 📦 Models
// ═══════════════════════════════════════════════════════════
class _Prayer {
  final String id;
  final String name;
  final String time; // HH:mm
  final IconData icon;
  final Color color;

  const _Prayer(this.id, this.name, this.time, this.icon, this.color);

  bool get isSunrise => id == 'sunrise';

  DateTime on(DateTime day) {
    final p = time.split(':');
    return DateTime(day.year, day.month, day.day, int.parse(p[0]), int.parse(p[1]));
  }
}

class _Countdown {
  final Duration remaining;
  final String nextId;
  final String nextName;
  final double progress;

  const _Countdown({
    required this.remaining,
    required this.nextId,
    required this.nextName,
    required this.progress,
  });

  static const empty = _Countdown(
    remaining: Duration.zero,
    nextId: '',
    nextName: '...',
    progress: 0,
  );
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // ⚙️ Config
  // ═══════════════════════════════════════════════════════════
  static const double _defaultLat = 34.6178;
  static const double _defaultLng = 45.3325;
  static const double _maxLocationDriftMeters = 30000;
  static const String _cacheKey = 'kalar_prayers_cache_v8';

  static const _ids = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const Map<String, String> _names = {
    'fajr': 'بەیانی',
    'sunrise': 'خۆرهەڵات',
    'dhuhr': 'نیوەڕۆ',
    'asr': 'عەسر',
    'maghrib': 'مەغریب',
    'isha': 'عیشا',
  };
  static const Map<String, IconData> _icons = {
    'fajr': Icons.nightlight_round,
    'sunrise': Icons.wb_twilight_rounded,
    'dhuhr': Icons.wb_sunny_rounded,
    'asr': Icons.wb_cloudy_rounded,
    'maghrib': Icons.nights_stay_rounded,
    'isha': Icons.bedtime_rounded,
  };
  static final Map<String, Color> _colors = {
    'fajr': AppColors.purple,
    'sunrise': AppColors.yellow,
    'dhuhr': AppColors.orange,
    'asr': AppColors.primary,
    'maghrib': AppColors.red,
    'isha': AppColors.purple,
  };


  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  List<_Prayer> _prayers = const [];
  final ValueNotifier<_Countdown> _countdown = ValueNotifier(_Countdown.empty);
  Timer? _ticker;
  DateTime _loadedDay = DateTime.now();
  int _passedCount = -1;

  bool _isLoading = true;
  bool _isOfficial = false;
  String? _errorMessage;
  String _hijriDate = '... هـ';
  String _gregorianDate = '';

  double _lat = _defaultLat;
  double _lng = _defaultLng;

  bool _notificationsEnabled = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerCompleteSub;
  bool _isPlayingAdhan = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  // ═══════════════════════════════════════════════════════════
  // 🔧 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _playerCompleteSub = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _audioPlayer.stop();
        if (mounted) setState(() => _isPlayingAdhan = false);
      }
    });

    _initAll();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _playerCompleteSub?.cancel();
    _audioPlayer.dispose();
    _countdown.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 Init
  // ═══════════════════════════════════════════════════════════
  Future<void> _initAll() async {
    await _loadSettings();
    await _load();
    if (mounted) _fadeCtrl.forward();

    // پاشەکی: شوێن و ئاگادارکردنەوە — چاوەڕێی ناکەین
    unawaited(_initNotif());
    unawaited(_refineLocation());
  }

  Future<void> _initNotif() async {
    try {
      await PrayerNotificationService.initialize();
      await PrayerNotificationService.requestPermissions();
    } catch (e) {
      debugPrint('⚠️ prayer notif init: $e');
    }
  }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = p.getBool('prayer_notif') ?? true;
    });
  }

  void _updateDates(DateTime now) {
    _gregorianDate =
        '${_two(now.day)}/${_two(now.month)}/${now.year}';
    final hijri = HijriCalendar.fromDate(now);
    _hijriDate = '${hijri.hDay} ${_hijriMonth(hijri.hMonth)} ${hijri.hYear} هـ';
  }

  String _hijriMonth(int month) {
    const ku = [
      'محەڕەم', 'سەفەر', 'ڕەبیع الأول', 'ڕەبیع الثانی',
      'جمادی الأولی', 'جمادی الآخر', 'ڕەجەب', 'شەعبان',
      'ڕەمەزان', 'شەوال', 'ذو القعدة', 'ذو الحجة',
    ];
    return (month >= 1 && month <= 12) ? ku[month - 1] : 'مانگ';
  }

  Future<void> _refineLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final dist = Geolocator.distanceBetween(
        _defaultLat,
        _defaultLng,
        pos.latitude,
        pos.longitude,
      );
      if (dist >= _maxLocationDriftMeters || !mounted) return;

      _lat = pos.latitude;
      _lng = pos.longitude;
      // کاتە فەرمییەکان پشت بە شوێن نابەستن
      if (!_isOfficial) await _load(silent: true);
    } catch (e) {
      debugPrint('⚠️ location: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🕌 Load
  // ═══════════════════════════════════════════════════════════
  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final now = DateTime.now();
    try {
      final day = KalarPrayerTimes.forDay(now, lat: _lat, lng: _lng);
      final times = day.times;

      if (!mounted) return;
      setState(() {
        _loadedDay = now;
        _updateDates(now);
        _isOfficial = day.isOfficial;
        _prayers = [
          for (final id in _ids)
            _Prayer(id, _names[id]!, times[id]!, _icons[id]!, _colors[id]!),
        ];
        _isLoading = false;
        _errorMessage = null;
      });

      _startTicker();
      unawaited(_saveCache());
      unawaited(_scheduleNotif());
    } catch (e) {
      debugPrint('❌ prayer load error: $e');
      final restored = await _restoreCache();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = restored ? 'بێ ئینتەرنێت - کاش' : 'هەڵە لە هەژمارکردن';
      });
      if (restored) _startTicker();
    }
  }


  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'date': _ymd(_loadedDay),
          'times': [
            for (final p in _prayers) {'id': p.id, 'name': p.name, 'time': p.time},
          ],
          'hijri': _hijriDate,
        }),
      );
    } catch (_) {}
  }

  Future<bool> _restoreCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['times'] as List).cast<Map<String, dynamic>>();
      final restored = <_Prayer>[];
      for (var i = 0; i < list.length && i < _ids.length; i++) {
        final id = (list[i]['id'] as String?) ?? _ids[i];
        restored.add(_Prayer(
          id,
          _names[id] ?? list[i]['name'].toString(),
          list[i]['time'].toString(),
          _icons[id] ?? Icons.access_time_rounded,
          _colors[id] ?? AppColors.orange,
        ));
      }
      if (restored.isEmpty || !mounted) return false;
      setState(() {
        _prayers = restored;
        _hijriDate = data['hijri']?.toString() ?? _hijriDate;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⏱️ Countdown
  // ═══════════════════════════════════════════════════════════
  void _startTicker() {
    _ticker?.cancel();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _prayers.isEmpty) return;
    final now = DateTime.now();

    // 🌙 ڕۆژ گۆڕا → کاتەکانی ڕۆژی نوێ بهێنە
    if (!_sameDay(now, _loadedDay)) {
      _ticker?.cancel();
      unawaited(_load(silent: true));
      return;
    }

    final salah = _prayers.where((p) => !p.isSunrise).toList();
    _Prayer? next;
    DateTime? nextAt;
    DateTime? prevAt;

    for (var i = 0; i < salah.length; i++) {
      final at = salah[i].on(now);
      if (at.isAfter(now)) {
        next = salah[i];
        nextAt = at;
        prevAt = i > 0
            ? salah[i - 1].on(now)
            // پێش بەیانی: عیشای دوێنێ (نزیکەیی)
            : salah.last.on(now).subtract(const Duration(days: 1));
        break;
      }
    }

    if (next == null) {
      // دوای عیشا → بەیانی سبەینێ
      next = salah.first;
      nextAt = next.on(now.add(const Duration(days: 1)));
      prevAt = salah.last.on(now);
    }

    final total = nextAt!.difference(prevAt!).inSeconds;
    final elapsed = now.difference(prevAt).inSeconds;
    final progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;

    final previousNext = _countdown.value.nextId;
    _countdown.value = _Countdown(
      remaining: nextAt.difference(now),
      nextId: next.id,
      nextName: next.name,
      progress: progress,
    );

    // تەنها کاتێک دۆخی لیستەکە دەگۆڕێت دووبارە دروستی دەکەینەوە
    final passed = _prayers.where((p) => p.on(now).isBefore(now)).length;
    if (previousNext != next.id || passed != _passedCount) {
      _passedCount = passed;
      setState(() {});
    }
  }

  bool _isPassed(_Prayer p) => p.on(DateTime.now()).isBefore(DateTime.now());

  // ═══════════════════════════════════════════════════════════
  // 🔔 Notifications / Audio
  // ═══════════════════════════════════════════════════════════
  Future<void> _scheduleNotif() async {
    if (!_notificationsEnabled || _prayers.isEmpty) return;
    try {
      await PrayerNotificationService.scheduleAllPrayers(
        prayerTimes: {for (final p in _prayers) p.name: p.time},
        is24Hour: true, // کاتەکان بە HH:mm دەنێردرێن
        enabled: _notificationsEnabled,
      );
    } catch (e) {
      debugPrint('⚠️ schedule notif: $e');
    }
  }

  Future<void> _toggleAdhan() async {
    HapticFeedback.mediumImpact();
    if (_isPlayingAdhan) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isPlayingAdhan = false);
      return;
    }
    try {
      setState(() => _isPlayingAdhan = true);
      await _audioPlayer.setAsset('assets/audio/adhan_default.mp3');
      unawaited(_audioPlayer.play());
    } catch (e) {
      debugPrint('⚠️ adhan play: $e');
      if (mounted) setState(() => _isPlayingAdhan = false);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdhanSettingsScreen()),
    );
    // ڕێکخستنەکان لەوانەیە گۆڕابن
    await _loadSettings();
    unawaited(_scheduleNotif());
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Helpers
  // ═══════════════════════════════════════════════════════════
  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDisplay(String time) => KalarPrayerTimes.format12(time);

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_isLoading && _prayers.isEmpty) {
      body = _buildLoading();
    } else if (_prayers.isEmpty) {
      body = _buildError();
    } else {
      body = FadeTransition(
        opacity: _fadeAnim,
        child: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          color: AppColors.orange,
          backgroundColor: AppColors.darkCard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
            children: [
              if (_errorMessage != null) ...[
                _buildOfflineBanner(),
                const SizedBox(height: 10),
              ],
              _buildDateCard(),
              const SizedBox(height: 14),
              _buildCountdownCard(),
              const SizedBox(height: 14),
              const SizedBox(height: 6),
              _buildSectionHeader(),
              const SizedBox(height: 12),
              for (final p in _prayers) _buildPrayerTile(p),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.darkBackground,
                  AppColors.darkBackground.withValues(alpha: 0.9),
                  AppColors.darkSurface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
