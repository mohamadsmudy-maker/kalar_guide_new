import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';

/// 🕋 شاشەی قیبلە دۆزەرەوە — ULTRA PRO MAX V4
///
/// ✅ Kalman Filter ی بازنەیی — دەرزییەکە لە نزیک باکوور (٣٥٩° ↔ ٠°) ناپەڕێت
/// ✅ کوالیتی سێنسەر بە circular variance (هەڵەی Calibration ی ساختە نییە)
/// ✅ Ticker لە جیاتی Timer — تەنها کاتێک دەجوڵێت ڕیبیلد دەکات
/// ✅ قورسی باکوور/ڕۆژهەڵات... لەگەڵ مۆبایل دەسوڕێتەوە
/// ✅ GPS بە timeout + fallback (دوایین شوێن ← کەلار)
/// ✅ کۆمپاس لە باکگراوند دەوەستێت (پاتری)
/// ✅ لەرینەوە (haptic) کاتێک ڕوو لە قیبلە دەکەیت
class QiblaFinderScreen extends StatefulWidget {
  const QiblaFinderScreen({super.key});

  @override
  State<QiblaFinderScreen> createState() => _QiblaFinderScreenState();
}

enum _LocState { loading, ready, serviceOff, denied, deniedForever, error }

class _QiblaFinderScreenState extends State<QiblaFinderScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ═══════════════════════════════════════════════════════════
  // 📍 Constants
  // ═══════════════════════════════════════════════════════════
  static const double _kaabaLat = 21.4225;
  static const double _kaabaLng = 39.8262;
  static const double _fallbackLat = 34.6178; // کەلار
  static const double _fallbackLng = 45.3325;

  static const double _enterFacingDeg = 5; // hysteresis: بچۆ ناو
  static const double _exitFacingDeg = 8; //  بچۆ دەرەوە

  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  final _filter = _AngleKalman(q: 0.05, r: 0.8);
  final List<double> _recent = [];

  /// ئاراستەی پیشاندراو (smooth) — تەنها کۆمپاسەکە گوێی لێ دەگرێت
  final ValueNotifier<double?> _heading = ValueNotifier<double?>(null);
  double? _targetHeading;

  double? _qiblaAngle;
  double? _distanceKm;
  double? _lat;
  double? _lng;
  bool _usingFallback = false;
  _LocState _loc = _LocState.loading;

  bool _noSensor = false;
  bool _compassError = false;
  double _quality = 1;
  bool _needsCalibration = false;
  double _confidence = 0;
  bool _facing = false;

  StreamSubscription<CompassEvent>? _compassSub;
  late final Ticker _ticker;

  late final AnimationController _pulseController;
  late final AnimationController _successController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _successAnimation;

  // ═══════════════════════════════════════════════════════════
  // 🔧 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
      reverseCurve: Curves.easeIn,
    );

    _ticker = createTicker(_onTick)..start();
    _startCompass();
    _initLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCompass();
    _ticker.dispose();
    _heading.dispose();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startCompass();
        if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
        // ڕەنگە بەکارهێنەر لە ڕێکخستنەکان GPS/مۆڵەتی چالاک کردبێت
        if (_loc != _LocState.ready && _loc != _LocState.loading) _initLocation();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _stopCompass();
        _pulseController.stop();
      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ Smooth rotation — Ticker (vsync), نەک Timer
  // ═══════════════════════════════════════════════════════════
  void _onTick(Duration _) {
    final target = _targetHeading;
    if (target == null) return;

    final current = _heading.value;
    if (current == null) {
      _heading.value = target;
      _updateFacing(target);
      return;
    }

    final diff = _shortestDiff(current, target);
    if (diff.abs() < 0.05) return; // هیچ نەگۆڕاوە → ڕیبیلد نییە

    final next = _norm(current + diff * 0.15);
    _heading.value = next;
    _updateFacing(next);
  }

  void _updateFacing(double heading) {
    final q = _qiblaAngle;
    if (q == null) return;
    final off = _shortestDiff(heading, q).abs();
    final facing = _facing ? off < _exitFacingDeg : off < _enterFacingDeg;
    if (facing == _facing) return;

    setState(() => _facing = facing);
    if (facing) {
      HapticFeedback.mediumImpact();
      _successController.forward(from: 0);
    } else {
      _successController.reverse();
    }
  }

  static double _norm(double a) => ((a % 360) + 360) % 360;

  static double _shortestDiff(double from, double to) {
    var d = (to - from) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  // ═══════════════════════════════════════════════════════════
  // 🧭 Compass
  // ═══════════════════════════════════════════════════════════
  void _startCompass() {
    if (_compassSub != null) return;
    final stream = FlutterCompass.events;
    if (stream == null) {
      if (mounted) setState(() => _noSensor = true);
      return;
    }
    _compassSub = stream.listen(
      _onCompass,
      onError: (Object error) {
        debugPrint('❌ Compass error: $error');
        if (mounted) setState(() => _compassError = true);
      },
    );
  }

  void _stopCompass() {
    _compassSub?.cancel();
    _compassSub = null;
  }

  void _onCompass(CompassEvent event) {
    final raw = event.heading;
    if (raw == null || !mounted) return;
    final heading = _norm(raw);

    _recent.add(heading);
    if (_recent.length > 12) _recent.removeAt(0);

    final isFirst = _targetHeading == null;
    _targetHeading = _filter.filter(heading);

    final quality = _circularQuality(_recent);
    final needsCalib = quality < 0.6;
    final confidence = _computeConfidence(quality, needsCalib);

    // تەنها کاتێک گۆڕانکاری دیار هەیە setState
    if (isFirst ||
        _compassError ||
        needsCalib != _needsCalibration ||
        (confidence - _confidence).abs() >= 0.03) {
      setState(() {
        _compassError = false;
        _quality = quality;
        _needsCalibration = needsCalib;
        _confidence = confidence;
      });
    }
  }

  /// کوالیتی بە circular standard deviation — ٣٥٩° و ١° بە نزیک دادەنێت
  static double _circularQuality(List<double> readings) {
    if (readings.length < 5) return 1;
    double s = 0, c = 0;
    for (final r in readings) {
      final rad = r * math.pi / 180;
      s += math.sin(rad);
      c += math.cos(rad);
    }
    final rLen = math.sqrt(s * s + c * c) / readings.length;
    if (rLen <= 0) return 0;
    final stdDeg = math.sqrt(-2 * math.log(rLen.clamp(1e-9, 1.0))) * 180 / math.pi;
    return (1 - stdDeg / 30).clamp(0.0, 1.0);
  }

  double _computeConfidence(double quality, bool needsCalib) {
    if (_qiblaAngle == null) return 0;
    var c = quality;
    if (needsCalib) c *= 0.5;
    if (_usingFallback) c *= 0.85;
    return c.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 GPS — timeout + fallback
  // ═══════════════════════════════════════════════════════════
  Future<void> _initLocation() async {
    if (mounted) setState(() => _loc = _LocState.loading);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _useFallback(_LocState.serviceOff);
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return _useFallback(_LocState.deniedForever);
      }
      if (perm == LocationPermission.denied) {
        return _useFallback(_LocState.denied);
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (e) {
        debugPrint('⚠️ GPS timeout/error, trying last known: $e');
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) return _useFallback(_LocState.error);
      _setPosition(pos.latitude, pos.longitude, fallback: false);
    } catch (e) {
      debugPrint('❌ Location error: $e');
      _useFallback(_LocState.error);
    }
  }

  void _useFallback(_LocState reason) {
    _setPosition(_fallbackLat, _fallbackLng, fallback: true, state: reason);
  }

  void _setPosition(
    double lat,
    double lng, {
    required bool fallback,
    _LocState state = _LocState.ready,
  }) {
    if (!mounted) return;
    setState(() {
      _lat = lat;
      _lng = lng;
      _usingFallback = fallback;
      _loc = state;
      _qiblaAngle = _calculateQiblaAngle(lat, lng);
      _distanceKm = Geolocator.distanceBetween(lat, lng, _kaabaLat, _kaabaLng) / 1000;
      _confidence = _computeConfidence(_quality, _needsCalibration);
    });
  }

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();
    if (_loc == _LocState.serviceOff) {
      await Geolocator.openLocationSettings();
    } else if (_loc == _LocState.deniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await _initLocation();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📐 Calculations
  // ═══════════════════════════════════════════════════════════
  static double _calculateQiblaAngle(double lat, double lng) {
    final latRad = lat * math.pi / 180;
    const kaabaLatRad = _kaabaLat * math.pi / 180;
    final dLng = (_kaabaLng - lng) * math.pi / 180;

    final y = math.sin(dLng);
    final x = math.cos(latRad) * math.tan(kaabaLatRad) -
        math.sin(latRad) * math.cos(dLng);
    return _norm(math.atan2(y, x) * 180 / math.pi);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Text(
            tr('قیبلە دۆزەرەوە'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            // 🌌 Background
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.darkBackground,
                      AppColors.darkSurface,
                      AppColors.darkBackground,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ✨ Success Glow
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _successAnimation,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.2,
                        colors: [
                          AppColors.green.withValues(
                            alpha: (0.15 * _successAnimation.value).clamp(0.0, 1.0),
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 📱 Content — هەرگیز overflow ناکات (scroll لە شاشەی بچووک)
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  final compassSize = math
                      .min(c.maxWidth - 48, c.maxHeight * 0.52)
                      .clamp(200.0, 420.0);
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        _buildStatusBar(),
                        if (_usingFallback && _loc != _LocState.loading) ...[
                          const SizedBox(height: 8),
                          _buildFallbackNotice(),
                        ],
                        const SizedBox(height: 20),
                        RepaintBoundary(
                          child: SizedBox.square(
                            dimension: compassSize,
                            child: _buildCompass(compassSize),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildInfoCard(),
                        const SizedBox(height: 12),
                        _buildTipCard(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Status
  // ═══════════════════════════════════════════════════════════
  String _statusText() {
    if (_noSensor) return 'مۆبایلەکەت هەستیاری کۆمپاسی نییە';
    if (_compassError) return 'هەڵە لە کۆمپاس';
    if (_facing) return '✅ ئاراستەی قیبلە دروستە!';
    if (_loc == _LocState.loading) return 'خەریکی دۆزینەوەی شوێن...';
    if (_heading.value == null) return 'چاوەڕێی کۆمپاس...';
    if (_needsCalibration) return '⚠️ مۆبایلەکە بە شێوەی ٨ بجوڵێنە (Calibration)';
    if (_confidence > 0.7) return 'مۆبایلەکە بسوڕێنە تا تیرەکە سەوز دەبێت';
    if (_confidence > 0.4) return '⚠️ هەستیاری کەمە — بجوڵێنە';
    return '🔴 سێنسەر ناجێگیرە — لە کەرەستەی ئاسنین دوور بکەوە';
  }

  Color _statusColor() {
    if (_noSensor || _compassError) return AppColors.red;
    if (_facing) return AppColors.green;
    if (_loc == _LocState.loading || _heading.value == null) return AppColors.primary;
    return _confidenceColor();
  }

  Widget _buildStatusBar() {
    final color = _statusColor();
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loc == _LocState.loading)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              AnimatedScale(
                scale: _facing ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _facing ? Icons.check_circle_rounded : _confidenceIcon(),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                tr(_statusText()),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackNotice() {
    final reason = switch (_loc) {
      _LocState.serviceOff => 'GPS کوژاوەتەوە',
      _LocState.denied => 'مۆڵەتی شوێن نەدرا',
      _LocState.deniedForever => 'مۆڵەتی شوێن بە تەواوی ڕەتکراوەتەوە',
      _ => 'شوێن نەدۆزرایەوە',
    };
    final action = switch (_loc) {
      _LocState.serviceOff => 'هەڵکردنی GPS',
      _LocState.deniedForever => 'ڕێکخستنەکان',
      _ => 'دووبارە',
    };

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trf('{0} — ئاراستە بەپێی کەلار هەژمارکراوە', [reason]),
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: _openSettings,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orange,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(tr(action), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🧭 Compass
  // ═══════════════════════════════════════════════════════════
  Widget _buildCompass(double size) {
    return ValueListenableBuilder<double?>(
      valueListenable: _heading,
      builder: (context, heading, _) {
        final h = heading ?? 0;
        final ringColor = _facing
            ? AppColors.green
            : (_confidence > 0.4 ? AppColors.orange : AppColors.red);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 🌟 Outer Glow
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                final s = size * (1 + _pulseAnimation.value * 0.05);
                return Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [ringColor.withValues(alpha: 0.15), Colors.transparent],
                    ),
                  ),
                );
              },
            ),

            // ⭕ Ring
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.darkCard, AppColors.darkSurface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: ringColor, width: _facing ? 4 : 3),
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),

            // 🧭 Dial — لەگەڵ مۆبایل دەسوڕێتەوە بۆ ئەوەی N ڕاستەوخۆ باکوور پیشان بدات
            Transform.rotate(
              angle: -h * math.pi / 180,
              child: CustomPaint(
                size: Size.square(size),
                painter: _DialPainter(
                  tickColor: ringColor,
                  qiblaAngle: _qiblaAngle,
                ),
              ),
            ),

            // 📍 نیشانەی سەرەوەی مۆبایل
            Positioned(
              top: size * 0.02,
              child: Container(
                width: 4,
                height: size * 0.06,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 🕋 Kaaba Center
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) => Container(
                width: size * 0.24,
                height: size * 0.24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.orange.withValues(alpha: 0.4), AppColors.darkCard],
                  ),
                  border: Border.all(color: AppColors.orange, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.4 + _pulseAnimation.value * 0.3),
                      blurRadius: 20 + _pulseAnimation.value * 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text('🕋', style: TextStyle(fontSize: size * 0.1)),
                ),
              ),
            ),

            // ➡️ Qibla Arrow — بە دەوری ناوەڕاستدا دەسوڕێتەوە (هەمیشە کورتترین ڕێگا)
            if (_qiblaAngle != null && heading != null)
              Transform.rotate(
                angle: _shortestDiff(h, _qiblaAngle!) * math.pi / 180,
                child: SizedBox.square(
                  dimension: size,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: size * 0.1),
                      child: _buildArrow(),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildArrow() {
    final color = _facing ? AppColors.green : AppColors.orange;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _facing
                  ? [AppColors.green, const Color(0xFF34D399)]
                  : [AppColors.orange, AppColors.yellow],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 25, spreadRadius: 4),
            ],
          ),
          child: Icon(
            _facing ? Icons.check_rounded : Icons.navigation_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            tr(_facing ? 'دروست ✅' : 'قیبلە'),
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Info Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoCard() {
    final confColor = _confidenceColor();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkCard, AppColors.darkSurface],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3), width: 1.2),
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
                    colors: [AppColors.orange, AppColors.yellow],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('زانیاری ورد'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: confColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: confColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_confidenceIcon(), size: 11, color: confColor),
                    const SizedBox(width: 3),
                    Text(
                      trf('{0}٪', [_toLocalDigits((_confidence * 100).toStringAsFixed(0))]),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: confColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_qiblaAngle != null)
            _infoRow(
              Icons.explore_rounded,
              'گۆشەی قیبلە (لە باکوورەوە)',
              '${_toLocalDigits(_qiblaAngle!.toStringAsFixed(1))}°',
              AppColors.orange,
            ),
          ValueListenableBuilder<double?>(
            valueListenable: _heading,
            builder: (context, h, _) => h == null
                ? const SizedBox.shrink()
                : _infoRow(
                    Icons.phone_android_rounded,
                    'ئاراستەی مۆبایل',
                    '${_toLocalDigits(h.toStringAsFixed(0))}°',
                    confColor,
                  ),
          ),
          if (_distanceKm != null)
            _infoRow(
              Icons.location_on_rounded,
              'دووری بۆ کەعبە',
              trf('{0} کم', [_toLocalDigits(_groupThousands(_distanceKm!.round()))]),
              AppColors.green,
            ),
          if (_lat != null && _lng != null)
            _infoRow(
              Icons.public_rounded,
              _usingFallback ? 'شوێن (گریمانەیی: کەلار)' : 'شوێنی ئێستا',
              '${_lat!.toStringAsFixed(3)}, ${_lng!.toStringAsFixed(3)}',
              AppColors.primary,
              isLast: true,
              ltr: true,
            ),
        ],
      ),
    );
  }

  Color _confidenceColor() {
    if (_confidence > 0.7) return AppColors.green;
    if (_confidence > 0.4) return AppColors.orange;
    return AppColors.red;
  }

  IconData _confidenceIcon() {
    if (_confidence > 0.7) return Icons.check_circle_rounded;
    if (_confidence > 0.4) return Icons.warning_amber_rounded;
    return Icons.error_outline_rounded;
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    bool isLast = false,
    bool ltr = false,
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
              tr(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              tr(value),
              textDirection: ltr ? TextDirection.ltr : null,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
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
    final String tip;
    final Color tipColor;
    if (_needsCalibration) {
      tip = '⚠️ مۆبایلەکەت چەند جارێک بە شێوەی ژمارە ٨ لە هەوادا بجوڵێنە بۆ ڕێکخستنی کۆمپاس';
      tipColor = AppColors.orange;
    } else if (_confidence < 0.4 && _heading.value != null) {
      tip = '🔴 لە ئۆتۆمبێل، ئامێری کارەبایی و کەرەستەی ئاسنین دوور بکەوە';
      tipColor = AppColors.red;
    } else {
      tip = '💡 مۆبایلەکەت بە ڕاستی (تەخت) بگرە و لە کەرەستەی ئاسنین دوور بکەوە بۆ وردبینی باشتر';
      tipColor = AppColors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tipColor.withValues(alpha: 0.08), tipColor.withValues(alpha: 0.02)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tipColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tipColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_rounded, color: tipColor, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(tip),
              style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔢 Helpers
  // ═══════════════════════════════════════════════════════════
  static String _groupThousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String _toLocalDigits(String input) {
    const en = '0123456789';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in input.split('')) {
      final i = en.indexOf(ch);
      b.write(i >= 0 ? ar[i] : (ch == ',' ? '٬' : ch));
    }
    return b.toString();
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 Dial painter — یەک CustomPaint لە جیاتی ٦٤ ویجێت
// ═══════════════════════════════════════════════════════════
class _DialPainter extends CustomPainter {
  final Color tickColor;
  final double? qiblaAngle;

  _DialPainter({required this.tickColor, required this.qiblaAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    // Inner ring
    canvas.drawCircle(
      center,
      r * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tickColor.withValues(alpha: 0.15),
    );

    // Ticks (هەر ٦°)
    final minor = Paint()
      ..color = tickColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = tickColor.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final isMajor = i % 5 == 0;
      final a = (i * 6 - 90) * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      final outer = r * 0.84;
      final inner = outer - (isMajor ? r * 0.06 : r * 0.03);
      canvas.drawLine(center + dir * inner, center + dir * outer, isMajor ? major : minor);
    }

    // 🕋 نیشانەی قیبلە لەسەر قورسەکە
    final q = qiblaAngle;
    if (q != null) {
      final a = (q - 90) * math.pi / 180;
      final p = center + Offset(math.cos(a), math.sin(a)) * (r * 0.84);
      canvas.drawCircle(p, r * 0.025, Paint()..color = const Color(0xFF34D399));
    }

    // N E S W
    const labels = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final a = (i * 90 - 90) * math.pi / 180;
      final p = center + Offset(math.cos(a), math.sin(a)) * (r * 0.68);
      final isNorth = i == 0;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: isNorth ? const Color(0xFFEF4444) : Colors.white54,
            fontSize: r * (isNorth ? 0.11 : 0.085),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.tickColor != tickColor || old.qiblaAngle != qiblaAngle;
}

// ═══════════════════════════════════════════════════════════
// 🎯 Kalman Filter بۆ گۆشە — wraparound ی ٣٦٠° بە دروستی مامەڵە دەکات
// ═══════════════════════════════════════════════════════════
class _AngleKalman {
  final double q; // Process noise
  final double r; // Measurement noise
  double _x = 0;
  double _p = 1;
  bool _initialized = false;

  _AngleKalman({this.q = 0.1, this.r = 0.5});

  double filter(double measurement) {
    if (!_initialized) {
      _x = measurement;
      _initialized = true;
      return _x;
    }
    _p += q;
    final k = _p / (_p + r);

    // innovation بە کورتترین ڕێگا: 359 → 1 = +2 ، نەک -358
    var innovation = (measurement - _x) % 360;
    if (innovation > 180) innovation -= 360;
    if (innovation < -180) innovation += 360;

    _x = ((_x + k * innovation) % 360 + 360) % 360;
    _p = (1 - k) * _p;
    return _x;
  }

  void reset() {
    _x = 0;
    _p = 1;
    _initialized = false;
  }
}
