import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/event.dart';
import '../../l10n/tr.dart';

class EventCard extends StatelessWidget {
  final AppEvent event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  Color get _color {
    try {
      String hex = event.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF6C5CE7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: event.isFeatured
              ? Border.all(color: color.withValues(alpha: 0.4), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    // ✅ Image.network → CachedNetworkImage
                    CachedNetworkImage(
                      imageUrl: event.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: isDark
                            ? const Color(0xFF2A2A35)
                            : Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6C5CE7),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _buildPlaceholder(color),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    if (event.isFeatured)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                tr('تایبەت'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              _buildPlaceholder(color),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tr(_getCategoryLabel(event.category)),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (event.isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tr('🔥 ئەمڕۆ'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else
                        Text(
                          tr(_getDaysLabel(event.daysUntil)),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr(event.titleKu),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${event.getFormattedDate()} • ${event.getFormattedTime()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                            isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (event.locationName != null &&
                      event.locationName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tr(event.locationName!),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildPlaceholder(Color color) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Icon(Icons.event_rounded, color: color, size: 48),
      ),
    );
  }

  String _getCategoryLabel(String cat) {
    switch (cat) {
      case 'national':
        return '🇮🇶 نیشتمانی';
      case 'religious':
        return '🕌 ئاینی';
      case 'sports':
        return '⚽ وەرزشی';
      case 'cultural':
        return '📚 کلتوری';
      default:
        return '📅 ڕووداو';
    }
  }

  String _getDaysLabel(int days) {
    if (days == 0) return 'ئەمڕۆ';
    if (days == 1) return 'سبەی';
    if (days < 7) return trf('دوای {0} ڕۆژ', [days]);
    if (days < 30) return trf('دوای {0} هەفتە', [(days / 7).floor()]);
    return trf('دوای {0} مانگ', [(days / 30).floor()]);
  }
}