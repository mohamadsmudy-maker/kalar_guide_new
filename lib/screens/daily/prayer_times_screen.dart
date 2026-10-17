import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

// ✅ import ـەکانی دروست
import '../daily/qibla_finder_screen.dart';       // ✅
import '../../services/prayer_notification_service.dart';
import '../../services/adhan_service.dart';
import '../prayer/adhan_settings_screen.dart';               // ✅
import '../prayer/prayer_weekly_view.dart';                  // ✅

/// 🕌 شاشەی کاتەکانی نوێژ — ULTRA PRO V3
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _prayerTimes = [];
  Map<String, dynamic> _countdown = {
    'hours': '00',
    'minutes': '00',
    'seconds': '00',
    'nextPrayer': '...',
    'progress': 0.0,
  };
  Timer? _countdownTimer;
  bool _isLoading = true;
  String? _errorMessage;
  String _hijriDate = '';
  String _gregorianDate = '';
  bool _showHijri = true;

  double _lat = 34.633;
  double _lng = 45.296;

  // ⭐ Settings
  bool _is24Hour = true;
  bool _adhanEnabled = true;
  bool _notificationsEnabled = true;

  // ⭐ Streak
  int _streakDays = 0;
  final Set<String> _prayedToday = {};

  // ⭐ Audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ✨ Animations
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _shimmerController;

  // ⭐ Dynamic Background
  Color _bgColor1 = const Color(0xFF0F1421);
  Color _bgColor2 = const Color(0xFF1A1B2E);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 Initialize
  // ═══════════════════════════════════════════════════════════
  Future<void> _initialize() async {
    _updateDates();
    await _loadSettings();
    await _loadStreak();
    await _getLocation();
    await _fetchPrayerTimes();
    await PrayerNotificationService.initialize();
    await PrayerNotificationService.requestPermissions();
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _is24Hour = prefs.getBool('prayer_24h') ?? true;
        _adhanEnabled = prefs.getBool('adhan_enabled') ?? true;
        _notificationsEnabled = prefs.getBool('prayer_notif') ?? true;
        _showHijri = prefs.getBool('show_hijri') ?? true;
      });
    } catch (e) {
      debugPrint('⚠️ Load settings error: $e');
    }
  }

  Future<void> _loadStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _streakDays = prefs.getInt('streak_days') ?? 0;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = prefs.getString('streak_date') ?? '';

      if (savedDate == today) {
        final prayed = prefs.getStringList('prayed_today') ?? [];
        _prayedToday.addAll(prayed);
      }
    } catch (e) {
      debugPrint('⚠️ Load streak error: $e');
    }
  }

  Future<void> _saveStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await prefs.setInt('streak_days', _streakDays);
      await prefs.setString('streak_date', today);
      await prefs.setStringList('prayed_today', _prayedToday.toList());
    } catch (e) {
      debugPrint('⚠️ Save streak error: $e');
    }
  }

  void _updateDates() {
    final now = DateTime.now();
    _gregorianDate =
    '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _hijriDate = _getApproxHijri(now);
  }

  String _getApproxHijri(DateTime d) {
    final days = d.difference(DateTime(622, 7, 16)).inDays;
    final years = (days / 354.36).floor();
    final months = ((days % 354.36) / 29.53).floor() + 1;
    return '${years} هـ / ${months}';
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        _lat = position.latitude;
        _lng = position.longitude;
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 API
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchPrayerTimes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final dateStr = '${now.day}-${now.month}-${now.year}';

      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings/$dateStr'
            '?latitude=$_lat&longitude=$_lng'
            '&method=3&school=0',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final timings = json['data']['timings'];
        final hijri = json['data']['date']['hijri'];

        setState(() {
          _hijriDate =
          '${hijri['day']} ${hijri['month']['ar']} ${hijri['year']} هـ';
          _prayerTimes = [
            _buildPrayer('بەیانی', timings['Fajr'], Icons.nights_stay_rounded,
                const Color(0xFF5E5CE6)),
            _buildPrayer('خۆرهەڵات', timings['Sunrise'],
                Icons.wb_twilight_rounded, const Color(0xFFFFB300)),
            _buildPrayer('نیوەڕۆ', timings['Dhuhr'], Icons.wb_sunny_rounded,
                const Color(0xFFFF8F00)),
            _buildPrayer('عەسر', timings['Asr'],
                Icons.wb_sunny_outlined, const Color(0xFF29B6F6)),
            _buildPrayer('مەغریب', timings['Maghrib'],
                Icons.wb_twilight_rounded, const Color(0xFFEF5350)),
            _buildPrayer('عیشا', timings['Isha'],
                Icons.nightlight_round, const Color(0xFF7986CB)),
          ];
          _isLoading = false;
        });

        _startCountdown();
        _scheduleNotifications();
        _updateBackground();
      } else {
        setState(() {
          _errorMessage = 'هەڵە لە هێنانی کاتەکان (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'پەیوەندی ئینتەرنێت نییە';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _buildPrayer(
      String name,
      String time,
      IconData icon,
      Color color,
      ) {
    return {
      'name': name,
      'time': time,
      'icon': icon,
      'color': color,
      'isPassed': _isPassed(time),
      'isPrayed': _prayedToday.contains(name),
    };
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Dynamic Background
  // ═══════════════════════════════════════════════════════════
  void _updateBackground() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 8) {
      _bgColor1 = const Color(0xFF0F1421);
      _bgColor2 = const Color(0xFF4A3B5E);
    } else if (hour >= 8 && hour < 17) {
      _bgColor1 = const Color(0xFF0F1421);
      _bgColor2 = const Color(0xFF1A3A5E);
    } else if (hour >= 17 && hour < 20) {
      _bgColor1 = const Color(0xFF0F1421);
      _bgColor2 = const Color(0xFF5E3A4A);
    } else {
      _bgColor1 = const Color(0xFF0A0A14);
      _bgColor2 = const Color(0xFF1A1B2E);
    }

    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ Countdown
  // ═══════════════════════════════════════════════════════════
  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateCountdown();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    if (_prayerTimes.isEmpty) return;

    final now = DateTime.now();
    Map<String, dynamic>? nextPrayer;
    DateTime? nextTime;
    Map<String, dynamic>? currentPrayer;
    DateTime? currentTime;

    for (int i = 0; i < _prayerTimes.length; i++) {
      final prayer = _prayerTimes[i];
      final parts = (prayer['time'] as String).split(':');
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      if (prayerTime.isAfter(now)) {
        nextPrayer = prayer;
        nextTime = prayerTime;
        if (i > 0) {
          currentPrayer = _prayerTimes[i - 1];
          final prevParts = (currentPrayer['time'] as String).split(':');
          currentTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(prevParts[0]),
            int.parse(prevParts[1]),
          );
        }
        break;
      }
    }

    if (nextPrayer == null) {
      final fajrTime = _prayerTimes.first['time'] as String;
      final parts = fajrTime.split(':');
      nextPrayer = _prayerTimes.first;
      nextTime = DateTime(
        now.year,
        now.month,
        now.day + 1,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    final diff = nextTime!.difference(now);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    double progress = 0.0;
    if (currentTime != null && nextTime != null) {
      final total = nextTime.difference(currentTime).inSeconds;
      final elapsed = now.difference(currentTime).inSeconds;
      progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
    }

    setState(() {
      _countdown = {
        'hours': hours,
        'minutes': minutes,
        'seconds': seconds,
        'nextPrayer': nextPrayer!['name'] as String,
        'progress': progress,
      };
    });
  }

  bool _isPassed(String time) {
    final now = DateTime.now();
    final parts = time.split(':');
    final prayerTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return prayerTime.isBefore(now);
  }

  bool _isNext(String name) => _countdown['nextPrayer'] == name;

  // ═══════════════════════════════════════════════════════════
  // 🔔 Notifications
  // ═══════════════════════════════════════════════════════════
  Future<void> _scheduleNotifications() async {
    if (!_notificationsEnabled) return;

    try {
      final prayerMap = <String, String>{};
      for (final prayer in _prayerTimes) {
        prayerMap[prayer['name'] as String] = prayer['time'] as String;
      }

      await PrayerNotificationService.scheduleAllPrayers(
        prayerTimes: prayerMap,
        is24Hour: _is24Hour,
        enabled: _notificationsEnabled,
      );
    } catch (e) {
      debugPrint('⚠️ Schedule notifications error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎵 Adhan
  // ═══════════════════════════════════════════════════════════
  Future<void> _playAdhan() async {
    try {
      if (_adhanEnabled) {
        HapticFeedback.mediumImpact();
        // ⭐ دەنگی Adhan لە assets/audio/
        await _audioPlayer.play(AssetSource('audio/adhan_default.mp3'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎵 ئەدان دەژەنرێت...'),
              backgroundColor: Color(0xFFFFB300),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Adhan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ دەنگی ئەدان نەدۆزرایەوە'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _stopAdhan() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('⚠️ Stop error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Prayer Tracker
  // ═══════════════════════════════════════════════════════════
  void _togglePrayed(String name) {
    HapticFeedback.selectionClick();

    setState(() {
      if (_prayedToday.contains(name)) {
        _prayedToday.remove(name);
      } else {
        _prayedToday.add(name);
      }

      for (int i = 0; i < _prayerTimes.length; i++) {
        if (_prayerTimes[i]['name'] == name) {
          _prayerTimes[i]['isPrayed'] = _prayedToday.contains(name);
        }
      }

      if (_prayedToday.length == 5) {
        _streakDays++;
      }
    });

    _saveStreak();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgColor1,
        body: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(seconds: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_bgColor1, _bgColor2, _bgColor1],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: _isLoading
                        ? _buildLoading()
                        : _errorMessage != null
                        ? _buildError()
                        : _buildContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'کاتەکانی نوێژ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'ئەپی ڕێبەری کەلار',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFFFFD700)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdhanSettingsScreen(),
              ),
            ),
            tooltip: 'ڕێکخستن',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color(0xFFFFD700)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrayerWeeklyView(lat: _lat, lng: _lng),
              ),
            ),
            tooltip: 'بینینی هەفتانە',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD700)),
            onPressed: _fetchPrayerTimes,
            tooltip: 'نوێکردنەوە',
          ),
          IconButton(
            icon: const Icon(Icons.explore, color: Color(0xFFFFD700)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const QiblaFinderScreen(),
              ),
            ),
            tooltip: 'قیبلە',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateCard(),
              const SizedBox(height: 16),
              _buildCountdownCard(),
              const SizedBox(height: 16),
              _buildStreakCard(),
              const SizedBox(height: 24),
              _buildSectionTitle(),
              const SizedBox(height: 12),
              ..._prayerTimes.asMap().entries.map((entry) {
                return _buildPrayerTile(entry.value, entry.key);
              }),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 Date Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildDateCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _showHijri = !_showHijri);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFD700).withValues(alpha: 0.15),
              const Color(0xFFFFB300).withValues(alpha: 0.05),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: Color(0xFF0F1421),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _showHijri ? _hijriDate : _gregorianDate,
                      key: ValueKey(_showHijri),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _showHijri ? _gregorianDate : _hijriDate,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'کەلار',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.location_on_rounded,
              color: Color(0xFFFFD700),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ Countdown Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildCountdownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1B4E), Color(0xFF1A2030)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.access_time_filled_rounded,
                        color: Color(0xFFFFD700),
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                'نوێژی داهاتوو: ${_countdown['nextPrayer']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeBox(_countdown['hours']!, 'سەعات'),
              _buildColon(),
              _buildTimeBox(_countdown['minutes']!, 'خولەک'),
              _buildColon(),
              _buildTimeBox(_countdown['seconds']!, 'چرکە'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: (_countdown['progress'] as double).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F1421),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildColon() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _pulseAnimation.value,
            child: Text(
              ':',
              style: TextStyle(
                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏆 Streak Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.2),
            const Color(0xFF059669).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ڕۆژانەی نوێژکردن',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$_streakDays',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'ڕۆژ',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    ..._prayerTimes
                        .where((p) => p['name'] != 'خۆرهەڵات')
                        .map((p) {
                      final prayed = _prayedToday.contains(p['name']);
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: prayed
                                ? const Color(0xFF10B981)
                                : Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 Section Title
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'کاتەکانی نوێژ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${_prayerTimes.length} کات',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🕌 Prayer Tile
  // ═══════════════════════════════════════════════════════════
  Widget _buildPrayerTile(Map<String, dynamic> prayer, int index) {
    final bool isNext = _isNext(prayer['name'] as String);
    final bool isPassed = _isPassed(prayer['time'] as String);
    final bool isPrayed = _prayedToday.contains(prayer['name']);
    final bool isSunrise = prayer['name'] == 'خۆرهەڵات';

    final Color prayerColor = prayer['color'] as Color;
    Color iconColor =
    isPassed ? prayerColor.withValues(alpha: 0.35) : prayerColor;
    Color textColor =
    isPassed ? Colors.white.withValues(alpha: 0.35) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: isNext
            ? LinearGradient(
          colors: [
            prayerColor.withValues(alpha: 0.25),
            prayerColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        )
            : null,
        color: isNext
            ? null
            : (isPrayed
            ? const Color(0xFF10B981).withValues(alpha: 0.08)
            : const Color(0xFF1A2030)),
        borderRadius: BorderRadius.circular(16),
        border: isNext
            ? Border.all(color: prayerColor, width: 2)
            : isPrayed
            ? Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1.5,
        )
            : Border.all(color: const Color(0xFF2A3244), width: 1),
        boxShadow: isNext
            ? [
          BoxShadow(
            color: prayerColor.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ]
            : null,
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: isNext
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              return Transform.scale(
                scale: isNext ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: isNext
                        ? LinearGradient(
                      colors: [
                        prayerColor,
                        prayerColor.withValues(alpha: 0.7),
                      ],
                    )
                        : null,
                    color: isNext
                        ? null
                        : prayerColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: isNext
                        ? [
                      BoxShadow(
                        color: prayerColor.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ]
                        : null,
                  ),
                  child: Icon(
                    prayer['icon'] as IconData,
                    color: isNext ? Colors.white : iconColor,
                    size: 22,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      prayer['name'] as String,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight:
                        isNext ? FontWeight.w900 : FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              prayerColor,
                              prayerColor.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: prayerColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              'داهاتوو',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isPrayed && !isSunrise) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981), size: 10),
                            SizedBox(width: 2),
                            Text(
                              'نوێژکراو',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (isNext) ...[
                  const SizedBox(height: 2),
                  Text(
                    'بە ${_countdown['hours']}:${_countdown['minutes']}:${_countdown['seconds']} ماوە',
                    style: TextStyle(
                      color: prayerColor.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _playAdhan();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isNext
                        ? prayerColor
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: isNext
                        ? null
                        : Border.all(
                      color: prayerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _formatTime(prayer['time'] as String),
                    style: TextStyle(
                      color: isNext ? Colors.white : iconColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (!isSunrise && isPassed) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _togglePrayed(prayer['name'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPrayed
                          ? const Color(0xFF10B981)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPrayed
                            ? const Color(0xFF10B981)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPrayed
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 10,
                          color: isPrayed
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isPrayed ? 'نوێژکراو' : 'نوێژم کرد',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: isPrayed
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    if (_is24Hour) return time;

    final parts = time.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;

    return '$hour:$minute $period';
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'خەریکی هێنانی کاتەکانی نوێژ...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'هەڵەیەک ڕوویدا',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchPrayerTimes,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('دووبارە هەوڵ بدە'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF0F1421),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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