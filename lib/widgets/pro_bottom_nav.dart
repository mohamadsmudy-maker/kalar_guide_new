import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 💎 ناڤیگەیشنی ژێرەوە — FULL PRO EDITION
/// 🔒 هەموو Tab ـەکان لە شوێنی خۆیان — بێ FAB، بێ جوڵە
class ProBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ProNavItem> items;
  final Color? activeColor;
  final bool enableHaptics;

  const ProBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor,
    this.enableHaptics = true,
  });

  @override
  State<ProBottomNav> createState() => _ProBottomNavState();
}

class _ProBottomNavState extends State<ProBottomNav> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // ═══ ڕەنگەکان ═══
    final activeColor = widget.activeColor ??
        (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF1E88E5));

    final barColor = isDark ? const Color(0xFF16161E) : Colors.white;

    final inactiveColor = isDark
        ? const Color(0xFF7A7A8C)
        : const Color(0xFF9E9EA8);

    const barHeight = 78.0;
    final totalHeight = barHeight + bottomPadding;

    return Container(
      height: totalHeight,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
            spreadRadius: -6,
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: List.generate(
            widget.items.length,
                (index) => Expanded(
              child: _buildNavItem(
                item: widget.items[index],
                isActive: widget.currentIndex == index,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                isDark: isDark,
                onTap: () {
                  if (widget.enableHaptics) {
                    HapticFeedback.selectionClick();
                  }
                  widget.onTap(index);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📝 ئایتمی ناڤیگەیشن — جێگیر، هیچ ناجوڵێت
  // ═══════════════════════════════════════════════════════
  Widget _buildNavItem({
    required ProNavItem item,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ═══════════════════════════════════════════════
            // 🎯 کانتەینەری ئایکۆن — باکگراوندی نەرم کاتێک چالاکە
            // ═══════════════════════════════════════════════
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: 54,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // ✅ باکگراوندی نەرم بۆ Tab ی چالاک
                color: isActive
                    ? activeColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                border: isActive
                    ? Border.all(
                  color: activeColor.withValues(alpha: 0.3),
                  width: 1,
                )
                    : null,
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),

            // ═══════════════════════════════════════════════
            // 📝 ناو — هەمیشە دەرکەوتوو، تەنها ڕەنگ دەگۆڕێت
            // ═══════════════════════════════════════════════
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                isActive ? FontWeight.w900 : FontWeight.w600,
                color: isActive ? activeColor : inactiveColor,
                height: 1.0,
                letterSpacing: 0.1,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

  const ProNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}