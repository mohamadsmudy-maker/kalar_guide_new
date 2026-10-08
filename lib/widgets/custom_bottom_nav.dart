import 'package:flutter/material.dart';

/// 🎨 ناڤیگەیشنی ژێرەوە — Modern FAB Style (وەک Handy Hive)
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;
  final Color activeColor;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor = const Color(0xFF1E88E5),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121218) : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = currentIndex == index;

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: _buildNavItem(
                  item: item,
                  isSelected: isSelected,
                  isDark: isDark,
                  activeColor: activeColor,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required NavItem item,
    required bool isSelected,
    required bool isDark,
    required Color activeColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ═══════════════════════════════════════════════
          // 🎯 ئایکۆن (FAB ئەگەر چالاک بێت)
          // ═══════════════════════════════════════════════
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: isSelected ? 52 : 40,
            height: isSelected ? 52 : 40,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                colors: [
                  activeColor,
                  activeColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isSelected ? null : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ]
                  : null,
            ),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.grey.shade700),
              size: isSelected ? 26 : 22,
            ),
          ),

          // ═══════════════════════════════════════════════
          // 📝 ناو
          // ═══════════════════════════════════════════════
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: isSelected ? 11 : 10,
              fontWeight:
              isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white60 : Colors.grey.shade700),
            ),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 📦 مۆدێلی بۆ هەر ئایتمێکی ناڤیگەیشن
class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}