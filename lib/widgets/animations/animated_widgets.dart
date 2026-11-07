import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 🎬 ویجێتەکانی ئەنیمەیشن — v2
///
/// API ی کۆن وەک خۆی ماوەتەوە (`AppAnimations.*`, `AnimatedCard`, `FadePageRoute`).
///
/// چاکسازی:
///  • `AnimatedCard.duration` پێشتر هیچ کاری نەدەکرد (کۆنتڕۆڵەرەکە ١٢٠ms ی چەسپاو بوو)
///  • `AnimatedCard` ئەگەر `onTap` نەبێت دەستکاری scale ناکات + Semantics
///  • shimmer: جوڵەکەی ڕاست دەبرێت (پێشتر نیوە-ڕێگا دەوەستا) و بە پێی ئاراستەی زمان
///  • هەموو شتێک ڕێز لە «Reduce motion» ی سیستەم دەگرێت
///
/// زیادکراو:
///  • `AppAnimations.stagger` — ئەنیمەیشنی پلەپلە بۆ لیست
///  • `FadeSlideIn` — بێ کۆنتڕۆڵەر (جێگەی `_Reveal` ە دووبارەکان)
///  • `Shimmer` + `SkeletonBox` — skeleton ی ئامادە
///  • `FadePageRoute(slide: true)` و `settings`

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

class AppAnimations {
  AppAnimations._();

  /// ✨ Fade + Slide بۆ هاتنە ژوورەوە
  static Widget fadeSlideIn({
    required Widget child,
    required AnimationController controller,
    double beginOffset = 0.15,
  }) {
    final fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: Offset(0, beginOffset),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  /// 🎯 Scale + Fade بۆ کارتەکان
  static Widget scaleFadeIn({
    required Widget child,
    required AnimationController controller,
  }) {
    final scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);

    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: child),
    );
  }

  /// 🪜 ئەنیمەیشنی پلەپلە: هەر ئایتمێک کەمێک دواتر دەست پێدەکات
  /// (بەکارهێنان: `stagger(index: i, total: items.length, ...)`)
  static Widget stagger({
    required Widget child,
    required AnimationController controller,
    required int index,
    int total = 8,
    double beginOffset = 0.15,
  }) {
    final count = total < 1 ? 1 : total;
    final start = (index.clamp(0, count) / count) * 0.6;
    final end = (start + 0.4).clamp(0.0, 1.0);
    final interval = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: interval,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, beginOffset),
          end: Offset.zero,
        ).animate(interval),
        child: child,
      ),
    );
  }

  /// 💫 Shimmer Effect — کۆنتڕۆڵەر لە دەرەوە دەدرێت (0 → 1، `repeat()` بکە)
  static Widget shimmer({
    required Widget child,
    required AnimationController controller,
  }) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final t = controller.value * 2 - 1; // -1 → 1
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.3),
                Colors.transparent,
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradientTransform(rtl ? -t : t),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 کارتێکی ئەنیمەیشن‌دار
// ═══════════════════════════════════════════════════════════
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// ماوەی scale کردنەوە و گەڕانەوە
  final Duration duration;

  /// بچووکبوونەوە کاتی گرتن (0.97 = ٣٪)
  final double pressedScale;

  /// haptic feedback ی سووک لەسەر tap
  final bool enableHaptics;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.duration = const Duration(milliseconds: 120),
    this.pressedScale = 0.97,
    this.enableHaptics = false,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnim = _buildScale();
  }

  Animation<double> _buildScale() =>
      Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );

  @override
  void didUpdateWidget(covariant AnimatedCard old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (old.pressedScale != widget.pressedScale) {
      _scaleAnim = _buildScale();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (widget.onTap == null || _reduceMotion(context)) return;
    _controller.forward();
  }

  void _release() {
    if (_controller.value > 0) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return Semantics(
      button: enabled,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _press() : null,
        onTapUp: enabled ? (_) => _release() : null,
        onTapCancel: enabled ? _release : null,
        onTap: enabled
            ? () {
          if (widget.enableHaptics) HapticFeedback.selectionClick();
          widget.onTap!();
        }
            : null,
        child: ScaleTransition(scale: _scaleAnim, child: widget.child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🌅 FadeSlideIn — بێ کۆنتڕۆڵەر، یەک جار کاتی دەرکەوتن
// ═══════════════════════════════════════════════════════════
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// دووری سەرەتایی بە پیکسڵ (ئەرێنی = لە خوارەوە دێت)
  final double dy;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.dy = 16,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    final delayFraction = widget.delay.inMilliseconds /
        (total.inMilliseconds == 0 ? 1 : total.inMilliseconds);
    _c = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _c,
      curve: Interval(delayFraction, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.dy * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 💀 Shimmer + SkeletonBox
// ═══════════════════════════════════════════════════════════
/// Shimmer ی خۆکار (کۆنتڕۆڵەری خۆی هەیە و لە dispose دا دەیکوژێنێتەوە)
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enabled;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
    this.enabled = true,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant Shimmer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.enabled && !_reduceMotion(context);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AppAnimations.shimmer(controller: _c, child: widget.child);
  }
}

/// بلۆکی skeleton بە ڕەنگی گونجاو لەگەڵ تیم
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A35) : const Color(0xFFE6E8EC),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🌊 Page Transition
// ═══════════════════════════════════════════════════════════
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  /// ئەگەر true بێت، لەگەڵ fade کەمێک لە خوارەوە سلاید دەکات
  final bool slide;

  FadePageRoute({
    required this.page,
    this.slide = false,
    super.settings,
    super.fullscreenDialog,
  }) : super(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      if (_reduceMotion(context)) return child;

      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final faded = FadeTransition(opacity: curved, child: child);
      if (!slide) return faded;

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: faded,
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
  );
}