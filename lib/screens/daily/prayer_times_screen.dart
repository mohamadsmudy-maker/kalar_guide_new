import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'qibla_finder_screen.dart';

/// 🕌 شاشەی کاتەکانی نوێژ — FULL PRO EDITION
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
  };
  Timer? _countdownTimer;
  bool _isLoading = true;
  String? _errorMessage;
  String _hijriDate = '';
  String _gregorianDate = '';

  double _lat = 34.633;
  double _lng = 45.296;

  // ✨ Animations
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 Initialize
  // ═══════════════════════════════════════════════════════════
  Future<void> _initialize() async {
    _updateDates();
    await _getLocation();
    await _fetchPrayerTimes();
    _fadeController.forward();
    _slideController.forward();
  }

  void _updateDates() {
    final now = DateTime.now();
    _gregorianDate =
    '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    // Hijri — تەنها نزیکەیی
    _hijriDate = _getApproxHijri(now);
  }

  String _getApproxHijri(DateTime d) {
    // حسابکردنی نزیکەیی (نەک ورد)
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
    };
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

    for (final prayer in _prayerTimes) {
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

    setState(() {
      _countdown = {
        'hours': hours,
        'minutes': minutes,
        'seconds': seconds,
        'nextPrayer': nextPrayer!['name'] as String,
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
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1421),
        body: Stack(
          children: [
            // 🌌 Background
            _buildBackground(),

            // 📜 Content
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

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F1421),
            Color(0xFF1A1B2E),
            Color(0xFF0F1421),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
              const SizedBox(height: 24),
              _buildSectionTitle(),
              const SizedBox(height: 12),
              ..._prayerTimes.map((p) => _buildPrayerTile(p)),
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
    return Container(
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
                Text(
                  _hijriDate,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _gregorianDate,
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
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Column(
      children: [
        Container(
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
      child: Text(
        ':',
        style: TextStyle(
          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
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
  // 🕌 Prayer Tile — PREMIUM
  // ═══════════════════════════════════════════════════════════
  Widget _buildPrayerTile(Map<String, dynamic> prayer) {
    final bool isNext = _isNext(prayer['name'] as String);
    final bool isPassed = _isPassed(prayer['time'] as String);

    final Color prayerColor = prayer['color'] as Color;
    Color iconColor =
    isPassed ? prayerColor.withValues(alpha: 0.35) : prayerColor;
    Color textColor =
    isPassed ? Colors.white.withValues(alpha: 0.35) : Colors.white;

    return Container(
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
        color: isNext ? null : const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(16),
        border: isNext
            ? Border.all(color: prayerColor, width: 2)
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
          // 🎨 Icon
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

          // 📝 Name
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

          // ⏰ Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              prayer['time'] as String,
              style: TextStyle(
                color: isNext ? Colors.white : iconColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ Loading
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // 🚨 Error
  // ═══════════════════════════════════════════════════════════
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