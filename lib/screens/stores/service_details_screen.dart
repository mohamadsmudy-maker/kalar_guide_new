import 'package:flutter/material.dart';
import '../../models/store_service.dart';
import '../../widgets/common/service_details_widgets.dart';
import '../../l10n/tr.dart';

/// 📋 شاشەی پێداویستی و تێچووی مامەڵەیەک — ULTRA PRO
///
/// ✅ چاکسازی: بەکارهێنانی `ServiceDetailWidgets` ی هاوبەش
class ServiceDetailsScreen extends StatelessWidget {
  final StoreService service;

  const ServiceDetailsScreen({super.key, required this.service});

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  Color get _color => ServiceDetailWidgets.hexToColor(
    service.color,
    fallback: const Color(0xFF1E88E5),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════════════════
            // 🎨 هێدەر
            // ═══════════════════════════════════════════════════
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        Color.lerp(color, Colors.black, 0.3)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                  Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  ServiceDetailWidgets.getIconData(
                                    service.icon,
                                  ),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tr(service.titleKu),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════
            // 📊 ناوەڕۆک
            // ═══════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══ 📄 وەسف ═══
                    if (service.description != null &&
                        service.description!.isNotEmpty) ...[
                      ServiceDetailWidgets.buildSectionTitle(
                        title: tr('📄 وەسف'),
                        isDark: isDark,
                        color: color,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoBox(
                        isDark: isDark,
                        child: Text(
                          tr(service.description!),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.7,
                            color: isDark
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ═══ 📄 پێداویستییەکان ═══
                    if (service.requirements.isNotEmpty) ...[
                      ServiceDetailWidgets.buildSectionTitle(
                        title: tr('📄 پێداویستییەکان'),
                        isDark: isDark,
                        color: const Color(0xFF4F5BD5),
                        badge: '${service.requirements.length}',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A22)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF4F5BD5)
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: service.requirements
                              .asMap()
                              .entries
                              .map(
                                (entry) =>
                                ServiceDetailWidgets
                                    .buildRequirementItem(
                                  index: entry.key + 1,
                                  text: entry.value,
                                  isDark: isDark,
                                ),
                          )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ═══ 💰 تێچووەکان ═══
                    if (service.fees.isNotEmpty) ...[
                      ServiceDetailWidgets.buildSectionTitle(
                        title: tr('💰 تێچووەکان'),
                        isDark: isDark,
                        color: const Color(0xFF0F9D7A),
                        badge: '${service.fees.length}',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0F9D7A)
                                  .withValues(alpha: 0.1),
                              const Color(0xFF0F9D7A)
                                  .withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF0F9D7A)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: service.fees
                              .asMap()
                              .entries
                              .map(
                                (entry) =>
                                ServiceDetailWidgets.buildFeeItem(
                                  text: entry.value,
                                  isDark: isDark,
                                ),
                          )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ═══ ℹ️ ماوە و شوێن ═══
                    if (_hasExtraInfo) ...[
                      ServiceDetailWidgets.buildSectionTitle(
                        title: tr('ℹ️ زانیاری زیاتر'),
                        isDark: isDark,
                        color: const Color(0xFFD9822B),
                      ),
                      const SizedBox(height: 10),
                      if (_hasDuration)
                        ServiceDetailWidgets.buildInfoRow(
                          icon: Icons.schedule_rounded,
                          label: tr('ماوەی مامەڵە'),
                          value: service.duration!,
                          color: const Color(0xFFD9822B),
                          isDark: isDark,
                        ),
                      if (_hasDuration && _hasLocation)
                        const SizedBox(height: 8),
                      if (_hasLocation)
                        ServiceDetailWidgets.buildInfoRow(
                          icon: Icons.location_on_rounded,
                          label: tr('شوێنی مامەڵە'),
                          value: service.location!,
                          color: const Color(0xFFDC3545),
                          isDark: isDark,
                        ),
                      const SizedBox(height: 20),
                    ],

                    // ═══ 📝 تێبینی ═══
                    if (_hasNotes) ...[
                      _buildNotesBox(isDark: isDark),
                    ],

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════════════
  bool get _hasDuration =>
      service.duration != null && service.duration!.isNotEmpty;
  bool get _hasLocation =>
      service.location != null && service.location!.isNotEmpty;
  bool get _hasNotes =>
      service.notes != null && service.notes!.isNotEmpty;
  bool get _hasExtraInfo => _hasDuration || _hasLocation;

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helper Widgets
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoBox({
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _buildNotesBox({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD9822B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD9822B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFD9822B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(service.notes!),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFD9822B),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}