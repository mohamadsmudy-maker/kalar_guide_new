import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;

/// 🌤️ ویجێتی کەشوهەوا (Compact Pro)
class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  Map<String, dynamic> _weather = {
    'temperature': '--',
    'condition_text': 'چاوەڕوانبە...',
    'icon_emoji': '🌤️',
    'humidity': '--',
    'wind_speed': '--',
    'updated_at': '--:--',
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLiveWeather();
  }

  Future<void> _fetchLiveWeather() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=34.6189&longitude=45.3156&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];

        int temp = (current['temperature_2m'] as num).round();
        int humidity = (current['relative_humidity_2m'] as num).round();
        int windSpeed = (current['wind_speed_10m'] as num).round();
        int wCode = current['weather_code'];

        String conditionText = "ساماڵ";
        String emoji = "🌤️";
        if (wCode > 3 && wCode < 50) {
          conditionText = "هەور";
          emoji = "☁️";
        } else if (wCode >= 50) {
          conditionText = "باراناوی";
          emoji = "🌧️";
        }

        String nowTime = intl.DateFormat('HH:mm').format(DateTime.now());

        if (mounted) {
          setState(() {
            _weather = {
              'temperature': temp.toString(),
              'condition_text': conditionText,
              'humidity': humidity.toString(),
              'wind_speed': windSpeed.toString(),
              'icon_emoji': emoji,
              'updated_at': nowTime,
            };
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final temp = _weather['temperature'];
    final condition = _weather['condition_text'];
    final icon = _weather['icon_emoji'];
    final humidity = _weather['humidity'];
    final windSpeed = _weather['wind_speed'];
    final timeStr = _weather['updated_at'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0288D1).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🌤️ ئیمۆجی کەشوهەوا
          Text(icon, style: const TextStyle(fontSize: 50)),
          const SizedBox(width: 12),

          // 🌡️ زانیاری کەشوهەوا
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'کەلار',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$temp°C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  condition,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 📊 شێداری و با
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.water_drop,
                      color: Colors.white70,
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$humidity%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.air, color: Colors.white70, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '$windSpeed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}