import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../complaints/complaint_instruction_dialog.dart';
import '../../emergency/emergency_screen.dart';
import '../../events/events_screen.dart';
import '../../neighborhoods/neighborhoods_screen.dart';

/// 🎯 دوگمەکانی شاشەی سەرەکی
class HomeButtons {
  HomeButtons._();

  /// 🆘 دوگمەی فریاکەوتن
  static Widget emergency(BuildContext context) {
    return _buildGradientButton(
      context: context,
      icon: Icons.emergency_rounded,
      title: '🚑 ژمارەکانی فریاکەوتن',
      subtitle: 'پۆلیس • ئاگرکوژێنەوە • ئەمبولانس',
      colors: const [Color(0xFFE53935), Color(0xFFFF7043)],
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyScreen()),
        );
      },
    );
  }

  /// 📅 دوگمەی ڕووداوەکان
  static Widget events(BuildContext context) {
    return _buildGradientButton(
      context: context,
      icon: Icons.event_rounded,
      title: '📅 ڕووداوەکانی کەلار',
      subtitle: 'نیشتمانی • ئاینی • وەرزشی',
      colors: const [Color(0xFF6C5CE7), Color(0xFFE91E63)],
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventsScreen()),
        );
      },
    );
  }

  /// 🏘️ دوگمەی گەڕەکەکان
  static Widget neighborhoods(BuildContext context) {
    return _buildGradientButton(
      context: context,
      icon: Icons.location_city_rounded,
      title: '🏘️ گەڕەکانی کەلار',
      subtitle: 'بینینی گەڕەک و شوێنەکان',
      colors: const [Color(0xFF1E88E5), Color(0xFF00BCD4)],
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NeighborhoodsScreen()),
        );
      },
    );
  }

  /// 📢 دوگمەی سکاڵا
  static Widget complaint(BuildContext context) {
    return _buildGradientButton(
      context: context,
      icon: Icons.campaign_rounded,
      title: '📢 ناردنی سکاڵا',
      subtitle: 'کێشە یان گرفتێک بنێرە',
      colors: const [Color(0xFF8B5CF6), Color(0xFFE91E63)],
      onTap: () => ComplaintInstructionDialog.show(context),
    );
  }

  /// 🎨 Builder ی گشتی
  static Widget _buildGradientButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
    double height = 60,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}