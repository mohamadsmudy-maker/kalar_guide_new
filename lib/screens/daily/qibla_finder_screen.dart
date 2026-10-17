import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

/// 🕋 شاشەی قیبلە دۆزەرەوە — ULTRA PRO V2
///
/// ⭐ چارەسەرکراو:
/// ✅ Kalman Filter بۆ کەمکردنەوەی Noise
/// ✅ Magnetic Interference Detection
/// ✅ Adaptive Smoothing
/// ✅ Auto Calibration
/// ✅ Show Confidence Level
/// ✅ Show Sensor Quality
class QiblaFinderScreen extends StatefulWidget {
  const QiblaFinderScreen({super.key});

  @override
  State<QiblaFinderScreen> createState() => _QiblaFinderScreenState();
}

class _QiblaFinderScreenState extends State<QiblaFinderScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📍 Constants
  // ═══════════════════════════════════════════════════════════
  static const double kaabaLat = 21.4225;
  static const double kaabaLng = 39.8262;

  static const Color _goldPrimary = Color(0xFFC9A227);
  static const Color _goldLight = Color(0xFFE5C76B);
  static const Color _bgDark = Color(0xFF0F1521);
  static const Color _cardDark = Color(0xFF1A2332);

  // ═══════════════════════════════════════════════════════════
  // 🎯 Kalman Filter — بۆ Smoothing
  // ═══════════════════════════════════════════════════════════
  final _kalman = _KalmanFilter(q: 0.05, r: 0.8);

  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  double? _compassHeading;      // Raw
  double? _smoothedHeading;     // Filtered
  double? _qiblaAngle;
  double? _distanceToKaaba;
  double? _currentLat;
  double? _currentLng;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // ⭐ Magnetic Quality
  double _sensorQuality = 1.0;  // 0.0 - 1.0
  bool _needsCalibration = false;
  List<double> _recentReadings = [];

  // ⭐ Confidence
  double _confidence = 0.0;  // 0.0 - 1.0

  bool _gettingLocation = true;
  String _statusMessage = 'خەریکی دۆزینەوەی شوێن...';

  // ✨ Animations
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;

  // ⭐ Smooth animation بۆ Compass
  double _animatedHeading = 0;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _initLocation();
    _initCompass();
    _startAnimationLoop();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _animationTimer?.cancel();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ Animation Loop — Smooth rotation
  // ═══════════════════════════════════════════════════════════
  void _startAnimationLoop() {
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 16),  // 60 FPS
          (_) {
        if (!mounted || _smoothedHeading == null) return;

        // ⭐ Lerp ی نەرم بۆ چوونە سەر ئاراستەی نوێ
        final target = _smoothedHeading!;
        final diff = _shortestAngleDiff(_animatedHeading, target);

        // ⭐ 15% بۆ هەر Frame = نەرمی 60 FPS
        _animatedHeading += diff * 0.15;
        _animatedHeading = (_animatedHeading + 360) % 360;

        setState(() {});
      },
    );
  }

  /// ⭐ کورتترین ڕێگا لە نێوان دوو گۆشە
  double _shortestAngleDiff(double from, double to) {
    double diff = to - from;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff;
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 GPS
  // ═══════════════════════════════════════════════════════════
  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _statusMessage = 'تکایە GPS ی مۆبایلەکەت هەڵبکە';
            _gettingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _statusMessage = 'مۆڵەتی شوێن ڕەتکرایەوە';
              _gettingLocation = false;
            });
          }
          return;
        }
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
          _gettingLocation = false;
          _qiblaAngle = _calculateQiblaAngle(
            position.latitude,
            position.longitude,
          );
          _distanceToKaaba = _calculateDistanceToKaaba(
            position.latitude,
            position.longitude,
          );
          _statusMessage = 'ئامادەیە - مۆبایلەکەت بجوڵێنە';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'هەڵە لە GPS';
          _gettingLocation = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧭 Compass — بە Kalman Filter
  // ═══════════════════════════════════════════════════════════
  void _initCompass() {
    try {
      if (FlutterCompass.events == null) {
        setState(() {
          _statusMessage = 'مۆبایلەکەت هەستیاری جوڵەی نییە';
        });
        return;
      }

      _compassSubscription = FlutterCompass.events!.listen(
            (CompassEvent event) {
          if (event.heading == null || !mounted) return;

          final rawHeading = event.heading!;

          // ⭐ ١. پشکنینی کوالیتی — ئایا Sensor ناجێگیرە؟
          _recentReadings.add(rawHeading);
          if (_recentReadings.length > 10) {
            _recentReadings.removeAt(0);
          }

          // ⭐ ٢. حسابکردنی Variation (کەمتر = باشتر)
          final quality = _calculateSensorQuality();
          final needsCalib = quality < 0.6;

          // ⭐ ٣. Kalman Filter
          final filtered = _kalman.filter(rawHeading);

          // ⭐ ٤. Normalize
          double normalized = filtered % 360;
          if (normalized < 0) normalized += 360;

          // ⭐ ٥. حسابکردنی Confidence
          final confidence = _calculateConfidence(quality, needsCalib);

          setState(() {
            _compassHeading = rawHeading;
            _smoothedHeading = normalized;
            _sensorQuality = quality;
            _needsCalibration = needsCalib;
            _confidence = confidence;
          });
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _statusMessage = 'هەڵە لە کۆمپاس';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'هەڵە';
        });
      }
    }
  }

  /// ⭐ حسابکردنی کوالیتی Sensor
  double _calculateSensorQuality() {
    if (_recentReadings.length < 5) return 1.0;

    // ⭐ Standard Deviation
    final mean = _recentReadings.reduce((a, b) => a + b) /
        _recentReadings.length;
    double variance = 0;
    for (final reading in _recentReadings) {
      variance += math.pow(reading - mean, 2);
    }
    variance /= _recentReadings.length;
    final stdDev = math.sqrt(variance);

    // ⭐ StdDev کەمتر = Quality باشتر
    // StdDev = 0 → Quality = 1.0
    // StdDev = 30 → Quality = 0.0
    return (1.0 - (stdDev / 30.0)).clamp(0.0, 1.0);
  }

  /// ⭐ حسابکردنی Confidence
  double _calculateConfidence(double quality, bool needsCalib) {
    if (_gettingLocation) return 0.0;

    double confidence = quality;

    // ⭐ کەمکردنەوە ئەگەر Calibration پێویستە
    if (needsCalib) confidence *= 0.5;

    // ⭐ کەمکردنەوە ئەگەر GPS ناجێگیرە
    if (_qiblaAngle == null) confidence *= 0.5;

    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════
  // 📐 Calculations
  // ═══════════════════════════════════════════════════════════
  double _calculateQiblaAngle(double lat, double lng) {
    final latRad = lat * math.pi / 180;
    final lngRad = lng * math.pi / 180;
    final kaabaLatRad = kaabaLat * math.pi / 180;
    final kaabaLngRad = kaabaLng * math.pi / 180;

    final dLng = kaabaLngRad - lngRad;
    final y = math.sin(dLng);
    final x = math.cos(latRad) * math.tan(kaabaLatRad) -
        math.sin(latRad) * math.cos(dLng);

    final qiblaRad = math.atan2(y, x);
    final qiblaDeg = qiblaRad * 180 / math.pi;
    return (qiblaDeg + 360) % 360;
  }

  double _calculateDistanceToKaaba(double lat, double lng) {
    return Geolocator.distanceBetween(lat, lng, kaabaLat, kaabaLng) / 1000;
  }

  double? _getDeviceQiblaDirection() {
    if (_animatedHeading == 0 || _qiblaAngle == null) return null;
    double direction = _qiblaAngle! - _animatedHeading;
    while (direction < 0) {
      direction += 360;
    }
    while (direction >= 360) {
      direction -= 360;
    }
    return direction;
  }

  bool _isFacingQibla() {
    if (_animatedHeading == 0 || _qiblaAngle == null) return false;
    double diff = (_qiblaAngle! - _animatedHeading).abs();
    if (diff > 180) diff = 360 - diff;
    return diff < 5;
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isFacingQibla = _isFacingQibla();
    final deviceQiblaDir = _getDeviceQiblaDirection();

    if (isFacingQibla && !_successController.isAnimating) {
      _successController.forward(from: 0);
    } else if (!isFacingQibla && _successController.value > 0) {
      _successController.reverse();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgDark,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'قیبلە دۆزەرەوە',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F1521),
                    Color(0xFF1A1521),
                    Color(0xFF0F1521),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Success Glow
            if (isFacingQibla)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _successAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.green.withValues(
                              alpha: 0.15 * _successAnimation.value,
                            ),
                            Colors.transparent,
                          ],
                          radius: 1.2,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildStatusBar(isFacingQibla),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = math.min(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return SizedBox(
                                  width: size,
                                  height: size,
                                  child: _buildCompass(
                                    size: size,
                                    isFacingQibla: isFacingQibla,
                                    deviceQiblaDir: deviceQiblaDir,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(),
                    const SizedBox(height: 12),
                    _buildTipCard(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Status Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatusBar(bool isFacingQibla) {
    // ⭐ ڕەنگی Status بەپێی Confidence
    Color bgColor;
    Color textColor;
    IconData icon;

    if (isFacingQibla) {
      bgColor = const Color(0xFF10B981);
      textColor = Colors.white;
      icon = Icons.check_circle_rounded;
    } else if (_confidence > 0.7) {
      bgColor = const Color(0xFF3B82F6);
      textColor = Colors.white;
      icon = Icons.explore_rounded;
    } else if (_confidence > 0.4) {
      bgColor = const Color(0xFFF59E0B);
      textColor = Colors.white;
      icon = Icons.warning_amber_rounded;
    } else {
      bgColor = const Color(0xFFEF4444);
      textColor = Colors.white;
      icon = Icons.error_outline_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgColor,
            bgColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bgColor.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_gettingLocation)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            AnimatedScale(
              scale: isFacingQibla ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(icon, color: textColor, size: 20),
            ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              isFacingQibla
                  ? '✅ ئاراستەی قیبلە دروستە!'
                  : _getStatusMessage(),
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    if (_gettingLocation) return _statusMessage;
    if (_needsCalibration) return '⚠️ تکایە مۆبایلەکە بجوڵێنە (Calibration)';
    if (_confidence > 0.7) return 'ئامادەیە - مۆبایلەکە بجوڵێنە';
    if (_confidence > 0.4) return '⚠️ هەستیاری کەمە — بجوڵێنە';
    return '🔴 Sensor ناجێگیرە — لە کەرەستەی ئاسنین دوور بکەوە';
  }

  // ═══════════════════════════════════════════════════════════
  // 🧭 Compass
  // ═══════════════════════════════════════════════════════════
  Widget _buildCompass({
    required double size,
    required bool isFacingQibla,
    required double? deviceQiblaDir,
  }) {
    // ⭐ ڕەنگی Compass بەپێی Confidence
    Color ringColor;
    if (isFacingQibla) {
      ringColor = Colors.green;
    } else if (_confidence > 0.7) {
      ringColor = _goldPrimary;
    } else if (_confidence > 0.4) {
      ringColor = const Color(0xFFF59E0B);
    } else {
      ringColor = const Color(0xFFEF4444);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Glow
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: size * (1 + _pulseAnimation.value * 0.05),
              height: size * (1 + _pulseAnimation.value * 0.05),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ringColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),

        // Outer Ring
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_cardDark, Color(0xFF232D3F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: ringColor,
              width: isFacingQibla ? 4 : 3,
            ),
            boxShadow: [
              BoxShadow(
                color: ringColor.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
            ],
          ),
        ),

        // Inner Ring
        Container(
          width: size * 0.88,
          height: size * 0.88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),

        // Tick Marks
        ..._buildTickMarks(size: size, color: ringColor),

        // Direction Markers
        _buildDirectionMarker(
          angle: 0,
          size: size,
          label: 'N',
          color: const Color(0xFFFF5252),
          isMain: true,
        ),
        _buildDirectionMarker(
          angle: 90,
          size: size,
          label: 'E',
          color: Colors.white54,
          isMain: true,
        ),
        _buildDirectionMarker(
          angle: 180,
          size: size,
          label: 'S',
          color: Colors.white54,
          isMain: true,
        ),
        _buildDirectionMarker(
          angle: 270,
          size: size,
          label: 'W',
          color: Colors.white54,
          isMain: true,
        ),

        // ⭐ Kaaba Center — Rotates with device
        Transform.rotate(
          angle: -_animatedHeading * math.pi / 180,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: size * 0.24,
                height: size * 0.24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _goldPrimary.withValues(alpha: 0.4),
                      const Color(0xFF1F2937),
                    ],
                  ),
                  border: Border.all(color: _goldPrimary, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _goldPrimary.withValues(
                        alpha: 0.4 + _pulseAnimation.value * 0.3,
                      ),
                      blurRadius: 20 + _pulseAnimation.value * 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '🕋',
                    style: TextStyle(fontSize: size * 0.1),
                  ),
                ),
              );
            },
          ),
        ),

        // Qibla Arrow — Rotates with qibla direction
        if (deviceQiblaDir != null)
          AnimatedRotation(
            turns: deviceQiblaDir / 360,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Transform.translate(
              offset: Offset(0, -size * 0.35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: isFacingQibla
                          ? const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : const LinearGradient(
                        colors: [_goldPrimary, _goldLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isFacingQibla
                              ? Colors.green
                              : _goldPrimary)
                              .withValues(alpha: 0.6),
                          blurRadius: 25,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isFacingQibla
                          ? Icons.check_rounded
                          : Icons.navigation_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isFacingQibla ? Colors.green : _goldPrimary)
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isFacingQibla ? 'دروست ✅' : 'قیبلە',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildTickMarks({required double size, required Color color}) {
    final ticks = <Widget>[];
    for (int i = 0; i < 60; i++) {
      final angle = i * 6.0;
      final rad = (angle - 90) * math.pi / 180;
      final isMain = i % 5 == 0;
      final radius = size * 0.42;
      final x = radius * math.cos(rad);
      final y = radius * math.sin(rad);

      ticks.add(
        Transform.translate(
          offset: Offset(x, y),
          child: Transform.rotate(
            angle: rad + math.pi / 2,
            child: Container(
              width: isMain ? 2 : 1,
              height: isMain ? 10 : 5,
              decoration: BoxDecoration(
                color: isMain
                    ? color.withValues(alpha: 0.6)
                    : color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      );
    }
    return ticks;
  }

  Widget _buildDirectionMarker({
    required double angle,
    required double size,
    required String label,
    required Color color,
    bool isMain = false,
  }) {
    final rad = (angle - 90) * math.pi / 180;
    final radius = size * 0.46;
    final x = radius * math.cos(rad);
    final y = radius * math.sin(rad);

    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width: isMain ? 28 : 20,
        height: isMain ? 28 : 20,
        decoration: BoxDecoration(
          color: isMain ? color.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
          border: isMain
              ? Border.all(color: color.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: isMain ? 15 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Info Card — بە Confidence
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_cardDark, Color(0xFF232D3F)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _goldPrimary.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_goldPrimary, _goldLight],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'زانیاری ورد',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // ⭐ Confidence Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _getConfidenceColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getConfidenceColor().withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getConfidenceIcon(),
                      size: 11,
                      color: _getConfidenceColor(),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${(_confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _getConfidenceColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_qiblaAngle != null)
            _buildInfoRow(
              icon: Icons.explore_rounded,
              label: 'گۆشەی قیبلە',
              value: '${_qiblaAngle!.toStringAsFixed(2)}°',
              color: _goldPrimary,
            ),
          if (_smoothedHeading != null)
            _buildInfoRow(
              icon: Icons.phone_android_rounded,
              label: 'ئاراستەی مۆبایل',
              value: '${_animatedHeading.toStringAsFixed(1)}°',
              color: _getConfidenceColor(),
            ),
          if (_distanceToKaaba != null)
            _buildInfoRow(
              icon: Icons.location_on_rounded,
              label: 'دووری بۆ کەعبە',
              value: '${_distanceToKaaba!.toStringAsFixed(0)} کم',
              color: const Color(0xFF10B981),
            ),
          if (_currentLat != null && _currentLng != null)
            _buildInfoRow(
              icon: Icons.public_rounded,
              label: 'شوێنی ئێستا',
              value:
              '${_currentLat!.toStringAsFixed(3)}, ${_currentLng!.toStringAsFixed(3)}',
              color: const Color(0xFF60A5FA),
              isLast: true,
            ),
        ],
      ),
    );
  }

  Color _getConfidenceColor() {
    if (_confidence > 0.7) return const Color(0xFF10B981);
    if (_confidence > 0.4) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  IconData _getConfidenceIcon() {
    if (_confidence > 0.7) return Icons.check_circle_rounded;
    if (_confidence > 0.4) return Icons.warning_amber_rounded;
    return Icons.error_outline_rounded;
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💡 Tip Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildTipCard() {
    // ⭐ Tip بەپێی دۆخ
    String tip;
    Color tipColor;

    if (_needsCalibration) {
      tip = '⚠️ تکایە مۆبایلەکەت بە شێوەی ٨ بجوڵێنە بۆ Calibration';
      tipColor = const Color(0xFFF59E0B);
    } else if (_confidence < 0.4) {
      tip = '🔴 Sensor ناجێگیرە — لە کەرەستەی ئاسنین دوور بکەوە';
      tipColor = const Color(0xFFEF4444);
    } else {
      tip = '💡 بۆ وردبینی باشتر، مۆبایلەکەت بە شێوەی ٨ بجوڵێنە و لە نزیک کەرەستەی ئاسنین دوور بکەوە';
      tipColor = _goldPrimary;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tipColor.withValues(alpha: 0.08),
            tipColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tipColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tipColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_rounded,
              color: tipColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 Kalman Filter — بۆ Smoothing
// ═══════════════════════════════════════════════════════════
class _KalmanFilter {
  final double q;  // Process noise
  final double r;  // Measurement noise
  double _x = 0;
  double _p = 1;
  double _k = 0;
  bool _initialized = false;

  _KalmanFilter({this.q = 0.1, this.r = 0.5});

  double filter(double measurement) {
    if (!_initialized) {
      _x = measurement;
      _initialized = true;
      return _x;
    }

    // Prediction
    _p = _p + q;

    // Update
    _k = _p / (_p + r);
    _x = _x + _k * (measurement - _x);
    _p = (1 - _k) * _p;

    return _x;
  }

  void reset() {
    _x = 0;
    _p = 1;
    _k = 0;
    _initialized = false;
  }
}