import 'package:flutter/material.dart';

/// 🎬 ویجێتەکانی ئەنیمەیشن — بۆ هەموو شوێنێک
class AppAnimations {
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

  /// 💫 Shimmer Effect
  static Widget shimmer({
    required Widget child,
    required AnimationController controller,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.3),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 - (2 * controller.value), 0),
              end: Alignment(1.0 - (2 * controller.value), 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// 🎯 کارتێکی ئەنیمەیشن‌دار
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.child,
      ),
    );
  }
}

/// 🌊 Page Transition ی نوێ
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadePageRoute({required this.page})
      : super(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}