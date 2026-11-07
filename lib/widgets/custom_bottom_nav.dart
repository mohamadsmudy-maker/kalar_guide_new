import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 🎨 ناڤیگەیشنی ژێرەوە — Modern FAB Style — ULTRA PRO MAX V3
///
/// ✅ TalkBack/VoiceOver دەتوانێت تابەکان بکاتەوە (پێشتر onTap لە semantics دا نەبوو)
/// ✅ بادج لە RTL لە لای دروست دەردەکەوێت
/// ✅ ژمارەکان بەپێی زمان (ئینگلیزی ← 123، کوردی/عەرەبی ← ١٢٣)
/// ✅ ئیفێکتی ink لە کاتی دەستلێدان
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
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dur = reduceMotion ? Duration.zero : const Duration(milliseconds: 300);

    // A bad index from the parent must never crash the bar
    final safeIndex = math.min(math.max(currentIndex, 0), items.length - 1);
    final useLatinDigits = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121218) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: -5,
          ),
        ],
      ),
      // Big system font sizes must not break the bar's layout
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.2,
        // Material شەفاف بۆ ئەوەی ink splash لەسەر باکگراوندی بارەکە دەربکەوێت
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              return Expanded(
                child: _NavButton(
                  item: items[index],
                  isSelected: safeIndex == index,
                  isDark: isDark,
                  activeColor: activeColor,
                  duration: dur,
                  latinDigits: useLatinDigits,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(index); // also fires for the selected tab (scroll-to-top etc.)
                  },
                ),
              );
            }),
          ),
        ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final bool isDark;
  final Color activeColor;
  final Duration duration;
  final VoidCallback onTap;
  final bool latinDigits;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.activeColor,
    required this.duration,
    required this.onTap,
    required this.latinDigits,
  });

  String _num(Object n) => latinDigits
      ? n.toString()
      : n.toString().replaceAllMapped(
          RegExp(r'\d'),
          (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
        );

  @override
  Widget build(BuildContext context) {
    final count = item.badge ?? 0;
    final hasBadge = count > 0;
    final idleColor = isDark ? Colors.white60 : Colors.grey.shade700;

    final separator = latinDigits ? ', ' : '، ';
    final badgeText = count > 99 ? '${_num(99)}+' : _num(count);

    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      label: hasBadge ? '${item.label}$separator$badgeText' : item.label,
      // ✅ بەبێ ئەمە screen reader نەیدەتوانی تابەکە بکاتەوە
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          containedInkWell: false,
          highlightShape: BoxShape.circle,
          radius: 36,
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ═══ Icon slot — fixed 52×52 so the bar never changes
                // height / jitters while the circle grows ═══
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: duration,
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
                            ),
                          ]
                              : null,
                        ),
                        child: Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? Colors.white : idleColor,
                          size: isSelected ? 26 : 22,
                        ),
                      ),

                      // ═══ Badge ═══
                      if (hasBadge)
                        PositionedDirectional(
                          top: isSelected ? 0 : 3,
                          end: isSelected ? 0 : 3,
                          child: Container(
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF121218)
                                    : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ═══ Label ═══
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  style: TextStyle(
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? activeColor : idleColor,
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
          ),
        ),
      ),
    );
  }
}

/// 📦 مۆدێلی بۆ هەر ئایتمێکی ناڤیگەیشن
class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Optional red counter on the icon (null or 0 = hidden)
  final int? badge;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge,
  });
}