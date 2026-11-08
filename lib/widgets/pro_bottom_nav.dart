import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/tr.dart';

/// 💎 ناڤیگەیشنی ژێرەوە — شێوازی «بازنەی بەرزبووەوە»
///
///  • بەشی چالاک لە بازنەیەکی ڕەنگاوڕەنگدایە کە بە چەماوەیەکی نەرم لە
///    شریتەکە بەرز دەبێتەوە؛ بازنە و چەماوەکە پێکەوە دەجووڵێن
///  • ناوی بەشی چالاک لە ژێر بازنەکەدا دەمێنێت
///  • RTL/LTR، دۆخی تاریک، badge، `onReselect`، Semantics
///  • ناوچە ڕوونەکەی سەرەوەی شریتەکە دەستلێدان ناگرێت (ناوەڕۆکی خوارەوە کار دەکات)
class ProBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ProNavItem> items;
  final Color? activeColor;
  final bool enableHaptics;

  /// بانگ دەکرێت کاتێک tab ی هەڵبژێردراو دووبارە دەگیرێت
  final ValueChanged<int>? onReselect;

  const ProBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor,
    this.enableHaptics = true,
    this.onReselect,
  }) : assert(items.length >= 2, 'ProBottomNav needs at least 2 items');

  /// بەرزی بەشی سەرەوە کە بازنەکەی تێدا بەرز دەبێتەوە
  static const double bumpHeight = 28;
  static const double _baseBarHeight = 62;
  static const double _circle = 50;

  @override
  State<ProBottomNav> createState() => _ProBottomNavState();
}

class _ProBottomNavState extends State<ProBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late double _from = widget.currentIndex.toDouble();
  late double _to = _from;

  double get _pos =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_c.value);

  @override
  void didUpdateWidget(ProBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _from = _pos;
      _to = widget.currentIndex.toDouble();
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap(int i) {
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    if (i == widget.currentIndex) {
      widget.onReselect?.call(i);
    } else {
      widget.onTap(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final active = widget.activeColor ??
        (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF1E88E5));
    final barColor = isDark ? const Color(0xFF16161E) : Colors.white;
    final inactive = isDark ? const Color(0xFF7A7A8C) : const Color(0xFF9E9EA8);

    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    final barHeight = ProBottomNav._baseBarHeight + (scale - 1) * 24;
    const bump = ProBottomNav.bumpHeight;
    const d = ProBottomNav._circle;
    final n = widget.items.length;
    final current = widget.items[widget.currentIndex];

    return SizedBox(
      height: bump + barHeight + bottomPadding,
      child: LayoutBuilder(builder: (context, box) {
        final slot = box.maxWidth / n;
        double xOf(double i) =>
            rtl ? box.maxWidth - (i + 0.5) * slot : (i + 0.5) * slot;

        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final cx = xOf(_pos);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ─── شریت + چەماوە ───
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BarPainter(
                      cx: cx,
                      top: bump,
                      color: barColor,
                      shadow: Colors.black.withValues(alpha: isDark ? 0.55 : 0.10),
                      border: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                ),

                // ─── بەشەکان ───
                Positioned(
                  top: bump,
                  left: 0,
                  right: 0,
                  height: barHeight,
                  child: Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: _NavTile(
                            item: widget.items[i],
                            index: i,
                            total: n,
                            // ئایکۆن کاڵ دەبێتەوە کاتێک بازنەکە لێی نزیک دەبێتەوە
                            closeness:
                                (1 - (_pos - i).abs()).clamp(0.0, 1.0).toDouble(),
                            isActive: i == widget.currentIndex,
                            activeColor: active,
                            inactiveColor: inactive,
                            barColor: barColor,
                            onTap: () => _tap(i),
                          ),
                        ),
                    ],
                  ),
                ),

                // ─── بازنەی چالاک ───
                Positioned(
                  left: cx - d / 2,
                  top: bump - d / 2 + 6,
                  width: d,
                  height: d,
                  child: GestureDetector(
                    onTap: () => _tap(widget.currentIndex),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(active, Colors.white, 0.18)!,
                            active,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: active.withValues(alpha: 0.40),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, a) =>
                            ScaleTransition(scale: a, child: child),
                        child: Icon(
                          current.activeIcon,
                          key: ValueKey(widget.currentIndex),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}

/// شریتی ژێرەوە بە چەماوەیەکی نەرم لە دەوری بازنەکە
class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.cx,
    required this.top,
    required this.color,
    required this.shadow,
    required this.border,
  });

  final double cx;
  final double top;
  final Color color;
  final Color shadow;
  final Color border;

  Size _size = Size.zero;

  static const double _halfWidth = 62; // نیوەی پانی چەماوە

  Path _path(Size size) {
    final w = size.width;
    const h = _halfWidth;
    // چەماوەکە دەتوانێت لە لێوارەکان دەربچێت؛ پڕکردنەوە خۆی دەیبڕێت،
    // بۆیە بازنە و چەماوە هەمیشە ڕێک لەسەر یەکن
    return Path()
      ..moveTo(math.min(0, cx - h), top)
      ..lineTo(cx - h, top)
      ..cubicTo(cx - h * 0.50, top, cx - h * 0.60, 0, cx, 0)
      ..cubicTo(cx + h * 0.60, 0, cx + h * 0.50, top, cx + h, top)
      ..lineTo(math.max(w, cx + h), top)
      ..lineTo(math.max(w, cx + h), size.height)
      ..lineTo(math.min(0, cx - h), size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    final path = _path(size);
    canvas.drawShadow(path.shift(const Offset(0, -2)), shadow, 10, true);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// تەنها ناو شریتەکە دەستلێدان دەگرێت
  @override
  bool hitTest(Offset position) => _path(_size).contains(position);

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.cx != cx || old.color != color || old.top != top;
}

class _NavTile extends StatelessWidget {
  final ProNavItem item;
  final int index;
  final int total;
  final double closeness;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final Color barColor;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.index,
    required this.total,
    required this.closeness,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.barColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: '${tr(item.label)}, ${index + 1}/$total',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // ئایکۆن — لە ژێر بازنەکەدا ون دەبێت
            Opacity(
              opacity: 1 - closeness,
              child: Transform.translate(
                offset: Offset(0, -10 * closeness),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(item.icon, color: inactiveColor, size: 23),
                    if (item.badge > 0)
                      PositionedDirectional(
                        top: -4,
                        end: -8,
                        child: Container(
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: barColor, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              tr(item.badge > 99 ? '99+' : '${item.badge}'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: (Theme.of(context).textTheme.labelSmall ??
                      const TextStyle())
                  .copyWith(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                color: isActive ? activeColor : inactiveColor,
                height: 1.0,
                letterSpacing: 0,
              ),
              child: Text(
                tr(item.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📦 مۆدێلی ئایتم
// ═══════════════════════════════════════════════════════════
class ProNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// ژمارەی badge (0 = شاراوە)
  final int badge;

  const ProNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
  });
}
