import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

/// 🆘 شاشەی SOS
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Position? _position;
  bool _loadingLocation = true;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _getLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _position = pos;
          _loadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() => _triggered = true);

    // 📞 پەیوەندی بە ١٢٢ (ئەمبولانس)
    final uri = Uri(scheme: 'tel', path: '122');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _triggered = false);
    });
  }

  Future<void> _shareLocation() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شوێن نەدۆزرایەوە، تکایە GPS هەڵبکە'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final lat = _position!.latitude;
    final lng = _position!.longitude;
    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final text = '🆘 یارمەتی! شوێنی من: $mapUrl';

    await Share.share(text, subject: '🆘 یارمەتی');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F14),
        appBar: AppBar(
          title: const Text(
            '🆘 فریاکەوتنی خێرا',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),

                // 🆘 دوگمەی SOS ی گەورە
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // دەوری گەورە بوو
                        Container(
                          width: 260 + (_pulseController.value * 30),
                          height: 260 + (_pulseController.value * 30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.1 * (1 - _pulseController.value)),
                          ),
                        ),
                        // دەوری ناوەوە
                        Container(
                          width: 230 + (_pulseController.value * 15),
                          height: 230 + (_pulseController.value * 15),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.15 * (1 - _pulseController.value)),
                          ),
                        ),
                        // دوگمە
                        GestureDetector(
                          onTap: _triggerSOS,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _triggered
                                    ? [
                                  const Color(0xFFB71C1C),
                                  const Color(0xFF7F0000),
                                ]
                                    : [
                                  const Color(0xFFEF4444),
                                  const Color(0xFFB71C1C),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.6),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _triggered
                                      ? Icons.phone_in_talk_rounded
                                      : Icons.emergency_share_rounded,
                                  color: Colors.white,
                                  size: 60,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'کرتە بکە بۆ پەیوەندی',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const Spacer(),

                // 📍 دۆخی شوێن
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _position != null
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFFF9800).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_loadingLocation)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF10B981),
                          ),
                        )
                      else
                        Icon(
                          _position != null
                              ? Icons.location_on_rounded
                              : Icons.location_off_rounded,
                          color: _position != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFF9800),
                          size: 24,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _loadingLocation
                                  ? 'خەریکی دۆزینەوەی شوێن...'
                                  : _position != null
                                  ? 'شوێنەکەت دۆزرایەوە'
                                  : 'شوێن نەدۆزرایەوە',
                              style: TextStyle(
                                color: _position != null
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFFF9800),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (_position != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 📤 دوگمەی هاوبەشکردن
                GestureDetector(
                  onTap: _shareLocation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.share_location_rounded,
                          color: Color(0xFF1E88E5),
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'هاوبەشکردنی شوێن بۆ خێزان',
                          style: TextStyle(
                            color: Color(0xFF1E88E5),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ⚠️ تێبینی
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SOS دەبەستێتەوە بە ١٢٢ (ئەمبولانس)',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}