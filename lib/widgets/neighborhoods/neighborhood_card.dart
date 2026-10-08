import 'package:flutter/material.dart';
import '../../models/neighborhood.dart';

/// 🏘️ کارتی گەڕەک
class NeighborhoodCard extends StatelessWidget {
  final Neighborhood neighborhood;
  final VoidCallback? onTap;
  final bool compact;

  const NeighborhoodCard({
    super.key,
    required this.neighborhood,
    this.onTap,
    this.compact = false,
  });

  Color get _color {
    try {
      String hex = neighborhood.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }

  IconData get _icon {
    switch (neighborhood.icon) {
      case 'apartment':
        return Icons.apartment_rounded;
      case 'home_work':
        return Icons.home_work_rounded;
      case 'location_on':
        return Icons.location_on_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'flag':
        return Icons.flag_rounded;
      case 'celebration':
        return Icons.celebration_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'location_city':
      default:
        return Icons.location_city_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color;

    if (compact) {
      return _buildCompact(isDark, color);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // 🖼️ وێنە یان Icon
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: neighborhood.coverUrl != null &&
                      neighborhood.coverUrl!.isNotEmpty
                      ? Image.network(
                    neighborhood.coverUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildGradientBg(color),
                  )
                      : _buildGradientBg(color),
                ),
                // 🌈 Gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // 🎯 ئایکۆن
                Positioned(
                  bottom: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(_icon, color: color, size: 20),
                  ),
                ),
              ],
            ),

            // 📝 ناوەڕۆک
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          neighborhood.nameKu,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 📊 ژمارەی شوێن
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 12,
                              color: color,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${neighborhood.totalStores}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (neighborhood.descriptionKu != null &&
                      neighborhood.descriptionKu!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      neighborhood.descriptionKu!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(bool isDark, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    neighborhood.nameKu,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.storefront_rounded,
                        size: 11,
                        color: color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${neighborhood.totalStores} شوێن',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBg(Color color) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.7),
            color.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _icon,
          color: Colors.white.withValues(alpha: 0.5),
          size: 60,
        ),
      ),
    );
  }
}