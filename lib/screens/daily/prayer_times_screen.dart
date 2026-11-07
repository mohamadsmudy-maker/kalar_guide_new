// lib/screens/daily/prayer_times_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_colors.dart';
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
  // 🕌 OFFICIAL AMOZHGARY.TV DATA — KALAR
  // بۆ زیادکردنی مانگی نوێ، تەنها ڕیزی نوێ لێرە زیاد بکە (dd-MM-yyyy)
  // ═══════════════════════════════════════════════════════════
  static const Map<String, Map<String, String>> _officialTimes = {
    '01-11-2026': {'fajr': '04:59', 'sunrise': '06:25', 'dhuhr': '11:45', 'asr': '14:43', 'maghrib': '17:06', 'isha': '18:29'},
    '02-11-2026': {'fajr': '05:00', 'sunrise': '06:26', 'dhuhr': '11:45', 'asr': '14:42', 'maghrib': '17:05', 'isha': '18:28'},
    '03-11-2026': {'fajr': '05:01', 'sunrise': '06:27', 'dhuhr': '11:45', 'asr': '14:41', 'maghrib': '17:04', 'isha': '18:27'},
    '04-11-2026': {'fajr': '05:02', 'sunrise': '06:27', 'dhuhr': '11:45', 'asr': '14:40', 'maghrib': '17:03', 'isha': '18:26'},
    '05-11-2026': {'fajr': '05:03', 'sunrise': '06:28', 'dhuhr': '11:45', 'asr': '14:40', 'maghrib': '17:02', 'isha': '18:25'},
    '06-11-2026': {'fajr': '05:04', 'sunrise': '06:29', 'dhuhr': '11:45', 'asr': '14:39', 'maghrib': '17:01', 'isha': '18:25'},
    '07-11-2026': {'fajr': '05:05', 'sunrise': '06:30', 'dhuhr': '11:45', 'asr': '14:38', 'maghrib': '17:00', 'isha': '18:24'},
    '08-11-2026': {'fajr': '05:06', 'sunrise': '06:31', 'dhuhr': '11:45', 'asr': '14:38', 'maghrib': '16:59', 'isha': '18:23'},
    '09-11-2026': {'fajr': '05:07', 'sunrise': '06:32', 'dhuhr': '11:45', 'asr': '14:37', 'maghrib': '16:58', 'isha': '18:23'},
    '10-11-2026': {'fajr': '05:08', 'sunrise': '06:33', 'dhuhr': '11:45', 'asr': '14:36', 'maghrib': '16:58', 'isha': '18:22'},
    '11-11-2026': {'fajr': '05:09', 'sunrise': '06:34', 'dhuhr': '11:45', 'asr': '14:36', 'maghrib': '16:57', 'isha': '18:21'},
    '12-11-2026': {'fajr': '05:10', 'sunrise': '06:35', 'dhuhr': '11:45', 'asr': '14:35', 'maghrib': '16:56', 'isha': '18:21'},
    '13-11-2026': {'fajr': '05:11', 'sunrise': '06:36', 'dhuhr': '11:45', 'asr': '14:35', 'maghrib': '16:55', 'isha': '18:20'},
    '14-11-2026': {'fajr': '05:12', 'sunrise': '06:37', 'dhuhr': '11:45', 'asr': '14:34', 'maghrib': '16:55', 'isha': '18:20'},
    '15-11-2026': {'fajr': '05:13', 'sunrise': '06:38', 'dhuhr': '11:46', 'asr': '14:34', 'maghrib': '16:54', 'isha': '18:19'},
    '16-11-2026': {'fajr': '05:14', 'sunrise': '06:39', 'dhuhr': '11:46', 'asr': '14:33', 'maghrib': '16:53', 'isha': '18:19'},
    '17-11-2026': {'fajr': '05:15', 'sunrise': '06:40', 'dhuhr': '11:46', 'asr': '14:33', 'maghrib': '16:53', 'isha': '18:18'},
    '18-11-2026': {'fajr': '05:16', 'sunrise': '06:41', 'dhuhr': '11:46', 'asr': '14:32', 'maghrib': '16:52', 'isha': '18:18'},
    '19-11-2026': {'fajr': '05:17', 'sunrise': '06:42', 'dhuhr': '11:46', 'asr': '14:32', 'maghrib': '16:52', 'isha': '18:17'},
    '20-11-2026': {'fajr': '05:18', 'sunrise': '06:43', 'dhuhr': '11:47', 'asr': '14:31', 'maghrib': '16:51', 'isha': '18:17'},
    '21-11-2026': {'fajr': '05:19', 'sunrise': '06:44', 'dhuhr': '11:47', 'asr': '14:31', 'maghrib': '16:51', 'isha': '18:16'},
    '22-11-2026': {'fajr': '05:20', 'sunrise': '06:45', 'dhuhr': '11:47', 'asr': '14:31', 'maghrib': '16:50', 'isha': '18:16'},
    '23-11-2026': {'fajr': '05:20', 'sunrise': '06:46', 'dhuhr': '11:47', 'asr': '14:30', 'maghrib': '16:50', 'isha': '18:16'},
    '24-11-2026': {'fajr': '05:21', 'sunrise': '06:47', 'dhuhr': '11:48', 'asr': '14:30', 'maghrib': '16:49', 'isha': '18:16'},
    '25-11-2026': {'fajr': '05:22', 'sunrise': '06:48', 'dhuhr': '11:48', 'asr': '14:30', 'maghrib': '16:49', 'isha': '18:15'},
    '26-11-2026': {'fajr': '05:23', 'sunrise': '06:49', 'dhuhr': '11:48', 'asr': '14:30', 'maghrib': '16:49', 'isha': '18:15'},
    '27-11-2026': {'fajr': '05:23', 'sunrise': '06:50', 'dhuhr': '11:49', 'asr': '14:29', 'maghrib': '16:49', 'isha': '18:15'},
    '28-11-2026': {'fajr': '05:24', 'sunrise': '06:51', 'dhuhr': '11:49', 'asr': '14:29', 'maghrib': '16:48', 'isha': '18:15'},
    '29-11-2026': {'fajr': '05:24', 'sunrise': '06:52', 'dhuhr': '11:49', 'asr': '14:29', 'maghrib': '16:48', 'isha': '18:15'},
    '30-11-2026': {'fajr': '05:25', 'sunrise': '06:53', 'dhuhr': '11:50', 'asr': '14:29', 'maghrib': '16:48', 'isha': '18:15'},
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

  bool _is24Hour = true;
  bool _notificationsEnabled = true;

  int _streakDays = 0;
  final Set<String> _prayedToday = {};

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
    await Future.wait([_loadSettings(), _loadStreak()]);
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
      _is24Hour = p.getBool('prayer_24h') ?? true;
      _notificationsEnabled = p.getBool('prayer_notif') ?? true;
    });
  }

  Future<void> _loadStreak() async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _ymd(now);
    final yesterday = _ymd(now.subtract(const Duration(days: 1)));

    var streak = p.getInt('streak_days') ?? 0;
    final lastCompleted = p.getString('last_streak_date');
    // ئەگەر دوێنێ و ئەمڕۆ تەواو نەکرابێت → ستریک دەپچڕێت
    if (streak > 0 &&
        lastCompleted != null &&
        lastCompleted != today &&
        lastCompleted != yesterday) {
      streak = 0;
      await p.setInt('streak_days', 0);
    }

    final savedDay = p.getString('streak_date') ?? '';
    final prayed = savedDay == today
        ? (p.getStringList('prayed_today') ?? const <String>[])
        : const <String>[];

    if (!mounted) return;
    setState(() {
      _streakDays = streak;
      _prayedToday
        ..clear()
        ..addAll(prayed);
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
      final official = _officialTimes[_dmy(now)];
      final Map<String, String> times;
      if (official != null) {
        times = official;
      } else {
        times = _calculate(now);
      }

      if (!mounted) return;
      setState(() {
        _loadedDay = now;
        _updateDates(now);
        _isOfficial = official != null;
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

  Map<String, String> _calculate(DateTime day) {
    final params = CalculationMethod.muslim_world_league.getParameters()
      ..madhab = Madhab.shafi
      ..adjustments = PrayerAdjustments(
        fajr: -1,
        sunrise: 0,
        dhuhr: 3,
        asr: 2,
        maghrib: 2,
        isha: 1,
      );
    final t = PrayerTimes(
      Coordinates(_lat, _lng),
      DateComponents.from(day),
      params,
    );
    return {
      'fajr': _hm(t.fajr),
      'sunrise': _hm(t.sunrise),
      'dhuhr': _hm(t.dhuhr),
      'asr': _hm(t.asr),
      'maghrib': _hm(t.maghrib),
      'isha': _hm(t.isha),
    };
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
      unawaited(_loadStreak());
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
  // 🔔 Notifications / Audio / Streak
  // ═══════════════════════════════════════════════════════════
  Future<void> _scheduleNotif() async {
    if (!_notificationsEnabled || _prayers.isEmpty) return;
    try {
      await PrayerNotificationService.scheduleAllPrayers(
        prayerTimes: {for (final p in _prayers) p.name: p.time},
        is24Hour: _is24Hour,
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

  Future<void> _togglePrayed(_Prayer prayer) async {
    if (prayer.isSunrise) return;
    HapticFeedback.selectionClick();

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _ymd(now);
    final yesterday = _ymd(now.subtract(const Duration(days: 1)));
    final lastCompleted = prefs.getString('last_streak_date');
    if (!mounted) return;

    final wasComplete = _prayedToday.length == 5;
    setState(() {
      if (!_prayedToday.remove(prayer.name)) _prayedToday.add(prayer.name);
    });
    final isComplete = _prayedToday.length == 5;

    if (!wasComplete && isComplete && lastCompleted != today) {
      setState(() => _streakDays++);
      HapticFeedback.heavyImpact();
      await prefs.setString('last_streak_date', today);
    } else if (wasComplete && !isComplete && lastCompleted == today) {
      // پاشگەزبوونەوە → ستریکی ئەمڕۆ هەڵدەوەشێتەوە
      setState(() => _streakDays = (_streakDays - 1).clamp(0, 1 << 30));
      await prefs.setString('last_streak_date', yesterday);
    }

    await prefs.setInt('streak_days', _streakDays);
    await prefs.setString('streak_date', today);
    await prefs.setStringList('prayed_today', _prayedToday.toList());
  }

  Future<void> _toggle24h() async {
    HapticFeedback.selectionClick();
    setState(() => _is24Hour = !_is24Hour);
    final p = await SharedPreferences.getInstance();
    await p.setBool('prayer_24h', _is24Hour);
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
  static String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
  static String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _dmy(DateTime d) => '${_two(d.day)}-${_two(d.month)}-${d.year}';
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDisplay(String time) {
    if (_is24Hour) return time;
    try {
      final p = time.split(':');
      var h = int.parse(p[0]);
      final suffix = h < 12 ? 'پ.ن' : 'د.ن';
      h %= 12;
      if (h == 0) h = 12;
      return '$h:${p[1]} $suffix';
    } catch (_) {
      return time;
    }
  }

  String _toLocalDigits(String input) {
    const en = '0123456789';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in input.split('')) {
      final i = en.indexOf(ch);
      b.write(i >= 0 ? ar[i] : ch);
    }
    return b.toString();
  }

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
              _buildStreakCard(),
              const SizedBox(height: 20),
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
