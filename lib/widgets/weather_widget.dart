import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🌤️ ویجێتی کەشوهەوا — HYBRID EDITION
/// ✅ سەرەتا لە Supabase دەخوێنێت (کۆنترۆڵی ئەدمین)، ئەگەر نەبوو لە Open-Meteo
class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget>
    with TickerProviderStateMixin {
  Map<String, dynamic> _weather = {
    'temperature': '--',
    'condition_text': 'چاوەڕوانبە...',
    'icon_emoji': '🌤️',
    'humidity': '--',
    'wind_speed': '--',
    'updated_at': '--:--',
    'feels_like': '--',
    'pressure': '--',
  };
  bool _loading = true;
  bool _isRefreshing = false;
  String _source = '';

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
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

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _fetchHybridWeather();

    _refreshTimer = Timer.periodic(
      const Duration(minutes: 15),
          (_) => _fetchHybridWeather(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🌐 هێنانی کەشوهەوا — Hybrid
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchHybridWeather() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      final adminData = await _fetchFromSupabase();
      if (adminData != null) {
        _applyWeatherData(adminData, 'admin');
        return;
      }

      final liveData = await _fetchFromOpenMeteo();
      if (liveData != null) {
        _applyWeatherData(liveData, 'auto');
        return;
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Weather error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchFromSupabase() async {
    try {
      final res = await Supabase.instance.client
          .from('weather')
          .select()
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;

      final updatedAt = res['updated_at'] != null
          ? DateTime.tryParse(res['updated_at'].toString())
          : null;

      if (updatedAt != null) {
        final hoursOld = DateTime.now().difference(updatedAt).inHours;
        if (hoursOld > 3) {
          debugPrint('⚠️ Weather لە Supabase کۆنە ($hoursOld سەعات)');
          return null;
        }
      }

      final temp = res['temperature']?.toString() ?? '--';
      final condition = res['condition_text']?.toString() ?? 'نەزانراو';
      final humidity = res['humidity']?.toString() ?? '--';
      final wind = res['wind_speed']?.toString() ?? '--';
      final emoji = res['icon_emoji']?.toString() ?? '🌤️';

      String timeStr = '--:--';
      if (updatedAt != null) {
        timeStr = intl.DateFormat('HH:mm').format(updatedAt);
      }

      return {
        'temperature': temp,
        'condition_text': condition,
        'icon_emoji': emoji,
        'humidity': humidity,
        'wind_speed': wind,
        'updated_at': timeStr,
        'feels_like': temp,
        'pressure': '--',
      };
    } catch (e) {
      debugPrint('⚠️ Supabase weather error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchFromOpenMeteo() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
            '?latitude=34.6189&longitude=45.3156'
            '&current=temperature_2m,relative_humidity_2m,weather_code,'
            'wind_speed_10m,apparent_temperature,surface_pressure',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final current = data['current'];

      int temp = (current['temperature_2m'] as num).round();
      int feelsLike = (current['apparent_temperature'] as num).round();
      int humidity = (current['relative_humidity_2m'] as num).round();
      int windSpeed = (current['wind_speed_10m'] as num).round();
      int pressure = (current['surface_pressure'] as num).round();
      int wCode = current['weather_code'];

      final conditionData = _getWeatherCondition(wCode);

      String nowTime = intl.DateFormat('HH:mm').format(DateTime.now());

      return {
        'temperature': temp.toString(),
        'condition_text': conditionData['text']!,
        'humidity': humidity.toString(),
        'wind_speed': windSpeed.toString(),
        'icon_emoji': conditionData['emoji']!,
        'updated_at': nowTime,
        'feels_like': feelsLike.toString(),
        'pressure': pressure.toString(),
      };
    } catch (e) {
      debugPrint('⚠️ Open-Meteo error: $e');
      return null;
    }
  }

  void _applyWeatherData(Map<String, dynamic> data, String source) {
    if (!mounted) return;
    setState(() {
      _weather = data;
      _source = source;
      _loading = false;
      _isRefreshing = false;
    });
    _fadeController.forward(from: 0);
  }

  Map<String, String> _getWeatherCondition(int code) {
    if (code == 0) return {'text': 'ساماڵ', 'emoji': '☀️'};
    if (code >= 1 && code <= 3) return {'text': 'کەمێک هەور', 'emoji': '🌤️'};
    if (code == 45 || code == 48) return {'text': 'تەم', 'emoji': '🌫️'};
    if (code >= 51 && code <= 55) return {'text': 'نم نم', 'emoji': '🌦️'};
    if (code >= 61 && code <= 65) return {'text': 'باران', 'emoji': '🌧️'};
    if (code >= 71 && code <= 77) return {'text': 'بەفر', 'emoji': '❄️'};
    if (code >= 80 && code <= 82) return {'text': 'بارانی بەخوڕ', 'emoji': '⛈️'};
    if (code >= 95) return {'text': 'هەورەبروسکە', 'emoji': '⛈️'};
    return {'text': 'نەزانراو', 'emoji': '🌤️'};
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingState();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: _isRefreshing ? null : _fetchHybridWeather,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4FC3F7),
                Color(0xFF0288D1),
                Color(0xFF01579B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0288D1).withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: const Color(0xFF01579B).withValues(alpha: 0.25),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _floatAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: -30 + _floatAnimation.value,
                    right: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _floatAnimation,
                builder: (context, child) {
                  return Positioned(
                    bottom: -25 - _floatAnimation.value,
                    left: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'کەلار',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (_source.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _source == 'admin'
                                ? Colors.amber.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _source == 'admin' ? '🏛️ فەرمی' : '🌐 Live',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _weather['updated_at'],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _isRefreshing ? 1 : 0,
                        duration: const Duration(milliseconds: 800),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 70,
                              height: 70,
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
                                child: Text(
                                  _weather['icon_emoji'],
                                  style: const TextStyle(fontSize: 42),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _weather['temperature'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    '°C',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _weather['condition_text'],
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.thermostat_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 11,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'هەست پێکراو: ${_weather['feels_like']}°',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildDetailItem(
                          icon: Icons.water_drop_rounded,
                          label: 'شێداری',
                          value: '${_weather['humidity']}%',
                        ),
                        _buildDivider(),
                        _buildDetailItem(
                          icon: Icons.air_rounded,
                          label: 'با',
                          value: '${_weather['wind_speed']} کم/س',
                        ),
                        _buildDivider(),
                        _buildDetailItem(
                          icon: Icons.speed_rounded,
                          label: 'پەستان',
                          value: '${_weather['pressure']} hPa',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.85),
            size: 16,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0288D1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'خەریکی هێنانی کەشوهەوا...',
              style: TextStyle(
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
}