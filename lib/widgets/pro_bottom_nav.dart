import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/tr.dart';

/// 💎 ناڤیگەیشنی ژێرەوە — FULL PRO EDITION v2
///
///  • StatelessWidget (state ی پێویست نەبوو)
///  • Semantics: screen reader «هەڵبژێردراو» و ژمارەی tab دەخوێنێتەوە
///  • badge ی ئارەزوومەندانە بۆ هەر tab (`ProNavItem.badge`)
///  • `onReselect`: کاتێک بەکارهێنەر tab ی چالاک دووبارە دەگرێت (بۆ scroll-to-top)
///  • ئایکۆنی چالاک بە ئەنیمەیشنی scale، ڕەنگی ئایکۆنی نەچالاک لە تیمەوە
///  • بەرزی بە پێی text scale دەگۆڕێت (فۆنتی گەورە نابڕێت)
class ProBottomNav extends StatelessWidget {
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

  static const double _baseBarHeight = 78;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final active = activeColor ??
        (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF1E88E5));
    final barColor = isDark ? const Color(0xFF16161E) : Colors.white;
    final inactive =
    isDark ? const Color(0xFF7A7A8C) : const Color(0xFF9E9EA8);

    // text scale گەورە = بارەکە کەمێک بەرزتر دەبێت
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    final barHeight = _baseBarHeight + (scale - 1) * 24;

    return Container(
      height: barHeight + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
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
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: _NavTile(
                  item: items[i],
                  index: i,
                  total: items.length,
                  isActive: i == currentIndex,
                  activeColor: active,
                  inactiveColor: inactive,
                  isDark: isDark,
                  onTap: () {
                    if (enableHaptics) HapticFeedback.selectionClick();
                    if (i == currentIndex) {
                      onReselect?.call(i);
                    } else {
                      onTap(i);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final ProNavItem item;
  final int index;
  final int total;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.index,
    required this.total,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: '${item.label}, ${index + 1}/$total',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─── ئایکۆن + باکگراوندی نەرم ───
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  width: 54,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isActive
                        ? activeColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: isActive
                          ? activeColor.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: AnimatedScale(
                    scale: isActive ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      isActive ? item.activeIcon : item.icon,
                      color: isActive ? activeColor : inactiveColor,
                      size: 22,
                    ),
                  ),
                ),
                if (item.badge > 0)
                  PositionedDirectional(
                    top: -3,
                    end: 4,
                    child: Container(
                      constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF16161E)
                              : Colors.white,
                          width: 1.5,
                        ),
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
            const SizedBox(height: 3),

            // ─── ناو ───
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                color: isActive ? activeColor : inactiveColor,
                height: 1.0,
                letterSpacing: 0.1,
              ),
              child: Text(
                tr(item.label),
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

  /// ژمارەی badge (0 = شاراوە)
  final int badge;

  const ProNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
  });
}