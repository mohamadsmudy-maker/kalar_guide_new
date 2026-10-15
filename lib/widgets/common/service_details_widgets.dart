// 📁 widgets/common/service_details_widgets.dart
import 'package:flutter/material.dart';

/// 🎨 ویدجێتەکانی هاوبەش بۆ وردەکاری مامەڵە
class ServiceDetailWidgets {
  ServiceDetailWidgets._();

  /// 📄 ناونیشانی بەش
  static Widget buildSectionTitle({
    required String title,
    required bool isDark,
    required Color color,
    String? badge,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        if (badge != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 📄 ئایتمی پێداویستی
  static Widget buildRequirementItem({
    required int index,
    required String text,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                  isDark ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 💰 ئایتمی تێچوو
  static Widget buildFeeItem({
    required String text,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.attach_money_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color:
                isDark ? Colors.white : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ℹ️ ڕیزی زانیاری
  static Widget buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 ئایکۆن بەپێی key
  static IconData getIconData(String icon) {
    switch (icon) {
      case 'car':
        return Icons.directions_car_rounded;
      case 'description':
        return Icons.description_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'health':
        return Icons.local_hospital_rounded;
      case 'money':
        return Icons.attach_money_rounded;
      case 'id_card':
        return Icons.badge_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  /// 🎨 ڕەنگ لە hex
  static Color hexToColor(String hex, {Color fallback = const Color(0xFF1E88E5)}) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}