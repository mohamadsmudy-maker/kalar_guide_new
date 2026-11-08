// lib/widgets/neighborhoods/neighborhood_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';
import '../../l10n/tr.dart';

/// 🏘️ کارتی گەڕەک — Ultra Pro (Style ی بەشەکان)
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
    final name = neighborhood.nameKu;
    if (name.contains('پیشەسازی') || name.contains('کارگە')) {
      return Icons.factory_rounded;
    }
    if (name.contains('زانکۆ') || name.contains('قوتابخانە')) {
      return Icons.school_rounded;
    }
    if (name.contains('مامۆستا')) return Icons.school_rounded;
    if (name.contains('شەهید')) return Icons.military_tech_rounded;
    if (name.contains('باخ') || name.contains('پارک')) {
      return Icons.park_rounded;
    }
    if (name.contains('مۆڵ') || name.contains('بازاڕ')) {
      return Icons.shopping_bag_rounded;
    }
    if (name.contains('مەطار') || name.contains('وێستگە')) {
      return Icons.local_gas_station_rounded;
    }
    if (name.contains('شاری') || name.contains('سێتی')) {
      return Icons.apartment_rounded;
    }
    if (name.contains('ناوچە')) return Icons.location_city_rounded;
    return Icons.location_city_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final color = _color;

    if (compact) return _buildCompact(isDark, color, lang);
    return _buildFull(isDark, color, lang);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Ultra Pro Card — Style ی بەشەکان (باریک)
  // ═══════════════════════════════════════════════════════════
  Widget _buildFull(bool isDark, Color color, String lang) {
    // ✅ کورتکردنەوەی ژمارە دەییەکان بۆ 2 ژمارە
    final areaStr = neighborhood.areaKm2.toStringAsFixed(2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.15 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          children: [
            // ═══ Icon Box (لای ڕاست) ═══
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    Color.lerp(color, Colors.white, 0.25)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Icon(_icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),

            // ═══ Info (ناو + Stats) ═══
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ناوی گەڕەک
                  Text(
                    tr(neighborhood.nameKu),
                    style: TextStyle(
                      fontFamily: 'Rabar',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // ═══ Stats Row (بە شێوەیەکی ڕێکخراو) ═══
                  Row(
                    children: [
                      // 1. شوێنەکان
                      Flexible(
                        child: _buildMiniStat(
                          icon: Icons.storefront_rounded,
                          value: trf('{0} شوێن', [neighborhood.totalStores]),
                          color: color,
                          isDark: isDark,
                        ),
                      ),

                      // 2. ڕووبەر (ئەگەر هەبوو)
                      if (neighborhood.areaKm2 > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: _buildMiniStat(
                            icon: Icons.landscape_rounded,
                            value: trf('{0} کم²', [areaStr]), // ✅ ئێستا 2 ژمارەی دەییە
                            color: const Color(0xFFD9822B),
                            isDark: isDark,
                          ),
                        ),
                      ],

                      // 3. دانیشتووان (ئەگەر هەبوو)
                      if (neighborhood.population > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: _buildMiniStat(
                            icon: Icons.people_rounded,
                            value: '${neighborhood.population}',
                            color: const Color(0xFF0F9D7A),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ═══ Arrow ═══
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: color,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Mini Stat (بچووک)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            tr(value),
            style: TextStyle(
              fontFamily: 'Rabar',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Compact Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildCompact(bool isDark, Color color, String lang) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    Color.lerp(color, Colors.white, 0.25)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(neighborhood.nameKu),
                style: TextStyle(
                  fontFamily: 'Rabar',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color:
                  isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${neighborhood.totalStores}',
              style: TextStyle(
                fontFamily: 'Rabar',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: color,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}