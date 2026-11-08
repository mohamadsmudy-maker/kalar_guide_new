import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/emergency_service.dart';
import '../../l10n/tr.dart';

/// 🚑 کارتی خزمەتگوزاری فریاکەوتن
class EmergencyCard extends StatelessWidget {
  final EmergencyService service;

  const EmergencyCard({super.key, required this.service});

  Color get _color {
    try {
      String hex = service.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFEF4444);
    }
  }

  IconData get _icon {
    switch (service.icon) {
      case 'local_police':
        return Icons.local_police_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      default:
        return Icons.emergency_rounded;
    }
  }

  Future<void> _call() async {
    HapticFeedback.heavyImpact();
    final uri = Uri(scheme: 'tel', path: service.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color;

    return GestureDetector(
      onTap: _call,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: isDark ? 0.25 : 0.12),
              color.withValues(alpha: isDark ? 0.10 : 0.04),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: service.isImportant
              ? [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            // 🎨 ئایکۆن
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(_icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),

            // 📝 زانیاری
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(service.nameKu),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(service.phone),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (service.is24h) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 10,
                          color: color.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          tr('٢٤ سەعات'),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ☎️ دوگمەی پەیوەندی
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.call_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}