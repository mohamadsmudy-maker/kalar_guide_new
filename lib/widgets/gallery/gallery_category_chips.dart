import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/gallery/gallery_category_registry.dart';
import '../../l10n/tr.dart';
import '../../utils/gallery_helpers.dart';

class GalleryCategoryChips extends StatelessWidget {
  final bool isDark;
  final String? selectedId;
  final Map<String, int> counts;
  final ValueChanged<String?> onSelected;

  /// بۆ بەکارهێنەر: بەشی بێ وێنە پیشان مەدە
  final bool hideEmpty;

  const GalleryCategoryChips({
    super.key,
    required this.isDark,
    required this.selectedId,
    required this.counts,
    required this.onSelected,
    this.hideEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final cats = [
      for (final c in GalleryCategoryRegistry.all)
        if (!hideEmpty || (counts[c.id] ?? 0) > 0 || selectedId == c.id) c,
    ];
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cats.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _chip(
              label: tr('هەموو'),
              icon: Icons.apps_rounded,
              color: AppColors.primary,
              count: total,
              selected: selectedId == null,
              onTap: () => onSelected(null),
            );
          }
          final c = cats[i - 1];
          return _chip(
            label: tr(c.label),
            icon: c.icon,
            color: c.color,
            count: counts[c.id] ?? 0,
            selected: selectedId == c.id,
            onTap: () => onSelected(c.id),
          );
        },
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isDark ? AppColors.darkCard : AppColors.surface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.textPrimary),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppLang.isRtl ? toLocalDigits('$count') : '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}