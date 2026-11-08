// 📁 widgets/common/service_details_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/tr.dart';

/// 🎨 ویدجێتەکانی هاوبەش بۆ وردەکاری مامەڵە (v2)
///
/// هەموو واژووەکان وەک خۆیان ماونەتەوە؛ پارامەتری ئارەزوومەندانەی نوێ زیاد کراون.
///
///  • `buildSectionTitle`: ناونیشانی درێژ ئیتر لەگەڵ badge دا overflow ناکات
///  • `buildRequirementItem`: `lang` بۆ ژمارەی ناوخۆیی (٠-٩)
///  • `buildInfoRow`: `copyable` — بە ڕاگرتنی درێژ کۆپی دەکات (تەلەفۆن، ناونیشان…)
///  • `getIconData`: ئایکۆنی زیاتر، ناونەخراو بە پیتی گەورە/بچووک گرنگ نییە
///  • `hexToColor`: #RGB، #RRGGBB، #AARRGGBB، 0xAARRGGBB
class ServiceDetailWidgets {
  ServiceDetailWidgets._();

  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _green = Color(0xFF10B981);

  static Color _fg(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF1A1A2E);

  static String _digits(String s, String lang) {
    if (lang == 'en') return s;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < en.length; i++) {
      s = s.replaceAll(en[i], ar[i]);
    }
    return s;
  }

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
        Expanded(
          child: Text(
            tr(title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _fg(isDark),
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tr(badge),
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
    String lang = 'en',
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
              color: _purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                tr(_digits('$index', lang)),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _purple,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                tr(text),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _fg(isDark),
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
              color: _green,
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
              tr(text),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : _green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ℹ️ ڕیزی زانیاری
  ///
  /// [copyable] = true: بە ڕاگرتنی درێژ `value` کۆپی دەکرێت.
  /// [copiedMessage] دەقی SnackBar ی «کۆپی کرا» (ئارەزوومەندانە).
  static Widget buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    bool copyable = false,
    String copiedMessage = 'کۆپی کرا',
  }) {
    final content = Container(
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
                  tr(label),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(value),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _fg(isDark),
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
        ],
      ),
    );

    if (!copyable) return content;

    return Builder(
      builder: (context) => Semantics(
        label: '$label: $value',
        hint: copiedMessage,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onLongPress: () async {
              await Clipboard.setData(ClipboardData(text: value));
              HapticFeedback.mediumImpact();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(tr(copiedMessage)),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            child: content,
          ),
        ),
      ),
    );
  }

  /// 🎯 ئایکۆن بەپێی key (پیتی گەورە/بچووک گرنگ نییە)
  static IconData getIconData(String icon) {
    switch (icon.trim().toLowerCase()) {
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
    // ─── نوێ ───
      case 'passport':
        return Icons.card_travel_rounded;
      case 'phone':
        return Icons.phone_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'location':
        return Icons.location_on_rounded;
      case 'time':
      case 'clock':
        return Icons.access_time_rounded;
      case 'calendar':
        return Icons.calendar_month_rounded;
      case 'building':
      case 'government':
        return Icons.account_balance_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'tax':
        return Icons.receipt_long_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  /// 🎨 ڕەنگ لە hex — #RGB، #RRGGBB، #AARRGGBB، 0xAARRGGBB
  static Color hexToColor(
      String hex, {
        Color fallback = const Color(0xFF1E88E5),
      }) {
    try {
      var h = hex.trim().replaceAll('#', '');
      if (h.toLowerCase().startsWith('0x')) h = h.substring(2);

      if (h.length == 3) {
        h = h.split('').map((c) => '$c$c').join(); // RGB → RRGGBB
      }
      if (h.length == 6) h = 'FF$h';
      if (h.length != 8) return fallback;

      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}