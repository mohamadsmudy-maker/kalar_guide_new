import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../config/settings_provider.dart';
import '../models/neighborhood.dart';
import '../screens/neighborhoods/neighborhood_details_screen.dart';
import '../l10n/tr.dart';

/// 🏘️ کارتی زانیاری گەڕەک لەسەر نەخشە — v2
///
///  • ناو بە پێی زمان (کوردی / عەرەبی / ئینگلیزی)
///  • ئامارەکان وەک chip (کورتتر، خوێندنەوەی ئاسانتر)
///  • دووری، دوگمەی دڵخواز (ئارەزوومەندانە — لە map_screen ەوە دەدرێت)
///  • سوکە-خوارەوە بۆ داخستن، ئەنیمەیشنی هاتنە ژوورەوە، safe-area ی ژێرەوە
///  • ژمارەی ناوخۆیی و جیاکەرەوەی هەزار
class NeighborhoodInfoSheet extends StatelessWidget {
  final Neighborhood neighborhood;
  final VoidCallback onClose;

  /// دووری لە بەکارهێنەرەوە بە مەتر (ئەگەر شوێنی بەکارهێنەر زانرا بێت)
  final double? distanceMeters;

  final bool isFavorite;

  /// ئەگەر null بێت دوگمەی دڵخواز پیشان نادرێت
  final VoidCallback? onToggleFavorite;

  const NeighborhoodInfoSheet({
    super.key,
    required this.neighborhood,
    required this.onClose,
    this.distanceMeters,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  static const Map<String, Map<String, String>> _tr = {
    'stores': {'ku': 'شوێن', 'ar': 'موقع', 'en': 'Places'},
    'population': {'ku': 'دانیشتوو', 'ar': 'السكان', 'en': 'Residents'},
    'area': {'ku': 'ڕووبەر', 'ar': 'المساحة', 'en': 'Area'},
    'more': {'ku': 'زانیاری زیاتر', 'ar': 'مزيد من المعلومات', 'en': 'More info'},
    'away': {'ku': 'دوورە', 'ar': 'بعيد', 'en': 'away'},
    'm': {'ku': 'مەتر', 'ar': 'م', 'en': 'm'},
    'km': {'ku': 'کم', 'ar': 'كم', 'en': 'km'},
    'close': {'ku': 'داخستن', 'ar': 'إغلاق', 'en': 'Close'},
    'fav_add': {
      'ku': 'زیادکردن بۆ دڵخواز',
      'ar': 'إضافة للمفضلة',
      'en': 'Add to favorites'
    },
    'fav_remove': {
      'ku': 'لابردن لە دڵخواز',
      'ar': 'إزالة من المفضلة',
      'en': 'Remove from favorites'
    },
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    String t(String k) => _tr[k]?[lang] ?? _tr[k]?['en'] ?? k;

    final n = neighborhood;
    final color = n.displayColor;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);

    String digits(String s) {
      if (lang == 'en') return s;
      const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < en.length; i++) {
        s = s.replaceAll(en[i], ar[i]);
      }
      return s;
    }

    String number(num v) => digits(intl.NumberFormat.decimalPattern().format(v));

    String distance(double m) => m < 1000
        ? '${digits('${m.round()}')} ${t('m')}'
        : '${digits((m / 1000).toStringAsFixed(1))} ${t('km')}';

    final name = () {
      final ar = n.nameAr?.trim() ?? '';
      final en = n.nameEn?.trim() ?? '';
      if (lang == 'ar' && ar.isNotEmpty) return ar;
      if (lang == 'en' && en.isNotEmpty) return en;
      return n.nameKu;
    }();

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(n.id ?? n.nameKu),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Transform.translate(
          offset: Offset(0, 40 * (1 - v)),
          child: Opacity(opacity: v, child: child),
        ),
        child: GestureDetector(
          // سوکە بۆ خوارەوە = داخستن
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 300) {
              HapticFeedback.selectionClick();
              onClose();
            }
          },
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Drag handle ───
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ─── Header ───
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.location_city_rounded,
                          color: color, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr(name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: fg,
                            ),
                          ),
                          if (distanceMeters != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.near_me_rounded,
                                    size: 12, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  '${distance(distanceMeters!)} ${t('away')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t('close'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onClose();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── Stats ───
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Icons.storefront_rounded,
                        value: number(n.totalStores),
                        label: t('stores'),
                        color: color,
                        isDark: isDark,
                      ),
                    ),
                    if (n.population > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.people_rounded,
                          value: number(n.population),
                          label: t('population'),
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                    ],
                    if (n.areaKm2 > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.square_foot_rounded,
                          value:
                          '${digits(n.areaKm2.toStringAsFixed(n.areaKm2 < 1 ? 3 : 1))} ${lang == 'en' ? 'km²' : 'کم²'}',
                          label: t('area'),
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // ─── Actions ───
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.info_outline_rounded),
                        label: Text(
                          t('more'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NeighborhoodDetailsScreen(neighborhood: n),
                            ),
                          );
                        },
                      ),
                    ),
                    if (onToggleFavorite != null) ...[
                      const SizedBox(width: 10),
                      Tooltip(
                        message:
                        isFavorite ? t('fav_remove') : t('fav_add'),
                        child: Material(
                          color: isFavorite
                              ? const Color(0xFFEC4899).withValues(alpha: 0.15)
                              : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: onToggleFavorite,
                            child: SizedBox(
                              width: 52,
                              height: 50,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (c, a) =>
                                    ScaleTransition(scale: a, child: c),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  key: ValueKey(isFavorite),
                                  color: isFavorite
                                      ? const Color(0xFFEC4899)
                                      : (isDark
                                      ? Colors.white70
                                      : Colors.grey[700]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tr(value),
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            tr(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}