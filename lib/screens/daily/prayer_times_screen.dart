import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import 'qibla_finder_screen.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  // ⏳ داتای کاتەکان (دەگۆڕدرێت دوای هێنانەوە لە API)
  List<Map<String, dynamic>> _prayerTimes = [];

  // ⏳ کۆنتداونی ڕاستەقینە
  Map<String, dynamic> _countdown = {
    'hours': '00',
    'minutes': '00',
    'seconds': '00',
    'nextPrayer': '...',
  };

  Timer? _countdownTimer;
  bool _isLoading = true;
  String? _errorMessage;

  // 📍 شوێنی ئێستا (بۆ Aladhan API)
  double _lat = 34.633; // شاری کەلار (default)
  double _lng = 45.296;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 🚀 دەستپێکردن: شوێن بدۆزەرەوە + کاتەکان بهێنە
  Future<void> _initialize() async {
    await _getLocation();
    await _fetchPrayerTimes();
  }

  // 📍 شوێنی ئێستا
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
      // بەکاری کەلار بەکاردەهێنین ئەگەر شوێن نەدۆزرایەوە
      debugPrint('Location error: $e');
    }
  }

  // 🌐 هێنانی کاتەکان لە Aladhan API
  Future<void> _fetchPrayerTimes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final dateStr = '${now.day}-${now.month}-${now.year}';

      // method=3 (Muslim World League) گونجاوە بۆ عێراق
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings/$dateStr'
            '?latitude=$_lat&longitude=$_lng'
            '&method=3&school=0',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final timings = json['data']['timings'];

        setState(() {
          _prayerTimes = [
            _buildPrayer('بەیانی', timings['Fajr'], Icons.nights_stay,
                const Color(0xFF5E5CE6)),
            _buildPrayer('خۆرهەڵات', timings['Sunrise'], Icons.wb_twilight,
                const Color(0xFFFFB300)),
            _buildPrayer('نیوەڕۆ', timings['Dhuhr'], Icons.wb_sunny,
                const Color(0xFFFF8F00)),
            _buildPrayer('عەسر', timings['Asr'], Icons.wb_sunny_outlined,
                const Color(0xFF29B6F6)),
            _buildPrayer('مەغریب', timings['Maghrib'], Icons.wb_twilight,
                const Color(0xFFEF5350)),
            _buildPrayer('عیشا', timings['Isha'], Icons.nightlight_round,
                const Color(0xFF7986CB)),
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

  // ⏳ دەستپێکردنی کۆنتداون
  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateCountdown();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  // ⏳ نوێکردنەوەی کۆنتداون
  void _updateCountdown() {
    if (_prayerTimes.isEmpty) return;

    final now = DateTime.now();

    // 🕌 دۆزینەوەی نوێژی داهاتوو
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

    // ئەگەر هەموو نوێژەکانی ئەمڕۆ تێپەڕیبوون، بۆ بەیانی سبەینێ
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

  // ✅ ئایا ئەم نوێژە تێپەڕیوە؟
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

  // ✅ ئایا ئەم نوێژە نوێژی داهاتووە؟
  bool _isNext(String name) => _countdown['nextPrayer'] == name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1421),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1421),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'کاتەکانی نوێژ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD700), size: 24),
            tooltip: 'نوێکردنەوە',
            onPressed: _fetchPrayerTimes,
          ),
          IconButton(
            icon: const Icon(Icons.explore, color: Color(0xFFFFD700), size: 26),
            tooltip: 'قیبلە',
            onPressed: () => _openQiblaScreen(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _errorMessage != null
          ? _buildError()
          : SafeArea(
        child: SingleChildScrollView(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openQiblaScreen(context),
        icon: const Icon(Icons.explore, size: 22),
        label: const Text(
          'قیبلە',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: const Color(0xFF0F1421),
        elevation: 6,
      ),
    );
  }

  // 🧭 شاشەی قیبلە
  void _openQiblaScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QiblaFinderScreen()),
    );
  }

  // 🚨 شاشەی هەڵە
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'هەڵەیەک ڕوویدا',
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchPrayerTimes,
            icon: const Icon(Icons.refresh),
            label: const Text('دووبارە هەوڵ بدە'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF0F1421),
            ),
          ),
        ],
      ),
    );
  }

  // 📅 کارتی بەروار
  Widget _buildDateCard() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3244), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 8),
              Text(
                '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            'کەلار',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ⏳ کارتی کۆنتداون
  Widget _buildCountdownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1B4E), Color(0xFF1A2030)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_filled,
                  color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 8),
              Text(
                'نوێژی داهاتوو: ${_countdown['nextPrayer']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeBox(_countdown['seconds']!, 'چرکە'),
              _buildTimeBox(_countdown['minutes']!, 'خولەک'),
              _buildTimeBox(_countdown['hours']!, 'سەعات'),
            ],
          ),
        ],
      ),
    );
  }

  // 🟨 خانەی کات
  Widget _buildTimeBox(String value, String label) {
    return Container(
      width: 80,
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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F1421),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F1421),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 🏷️ ناوی بەش
  Widget _buildSectionTitle() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'کاتەکانی نوێژ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 🕌 کارتی هەر نوێژێک
  Widget _buildPrayerTile(Map<String, dynamic> prayer) {
    final bool isNext = _isNext(prayer['name'] as String);
    final bool isPassed = _isPassed(prayer['time'] as String);

    // 🎨 ڕەنگی نوێژە تێپەڕیوەکان کاڵ دەکەین
    Color textColor = isPassed
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white;
    Color iconColor = isPassed
        ? (prayer['color'] as Color).withValues(alpha: 0.35)
        : prayer['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isNext ? const Color(0xFF1E4A6E) : const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(14),
        border: isNext
            ? Border.all(color: const Color(0xFF29B6F6), width: 2)
            : Border.all(color: const Color(0xFF2A3244), width: 1),
        boxShadow: isNext
            ? [
          BoxShadow(
            color: const Color(0xFF29B6F6).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(prayer['icon'] as IconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  prayer['name'] as String,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF29B6F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text(
                          'داهاتوو',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            prayer['time'] as String,
            style: TextStyle(
              color: isNext ? const Color(0xFFFFD700) : textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}