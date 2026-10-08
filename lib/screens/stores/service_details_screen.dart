import 'package:flutter/material.dart';
import '../../models/store_service.dart';

/// 📋 شاشەی پێداویستی و تێچووی مامەڵەیەک
class ServiceDetailsScreen extends StatelessWidget {
  final StoreService service;

  const ServiceDetailsScreen({super.key, required this.service});

  Color get _color {
    try {
      String hex = service.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          slivers: [
            // 🎨 هێدەر
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
                      colors: [color, color.withValues(alpha: 0.7)],
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
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _getIconData(service.icon),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  service.titleKu,
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

            // 📊 ناوەڕۆک
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📄 وەسف
                    if (service.description != null &&
                        service.description!.isNotEmpty) ...[
                      _buildSectionTitle('📄 وەسف', isDark),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                          isDark ? const Color(0xFF1A1A22) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          service.description!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.7,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 📄 پێداویستییەکان
                    if (service.requirements.isNotEmpty) ...[
                      _buildSectionTitle(
                        '📄 پێداویستییەکان',
                        isDark,
                        badge: '${service.requirements.length}',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                          isDark ? const Color(0xFF1A1A22) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: service.requirements
                              .asMap()
                              .entries
                              .map((entry) => _buildRequirementItem(
                            entry.key + 1,
                            entry.value,
                            isDark,
                          ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 💰 تێچووەکان
                    if (service.fees.isNotEmpty) ...[
                      _buildSectionTitle(
                        '💰 تێچووەکان',
                        isDark,
                        badge: '${service.fees.length}',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withValues(alpha: 0.1),
                              const Color(0xFF10B981).withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: service.fees
                              .asMap()
                              .entries
                              .map((entry) => _buildFeeItem(
                            entry.value,
                            isDark,
                          ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ⏱️ ماوە و شوێن
                    if ((service.duration != null &&
                        service.duration!.isNotEmpty) ||
                        (service.location != null &&
                            service.location!.isNotEmpty)) ...[
                      _buildSectionTitle('ℹ️ زانیاری زیاتر', isDark),
                      const SizedBox(height: 10),
                      if (service.duration != null &&
                          service.duration!.isNotEmpty)
                        _buildInfoRow(
                          Icons.schedule_rounded,
                          'ماوەی مامەڵە',
                          service.duration!,
                          const Color(0xFFF59E0B),
                          isDark,
                        ),
                      if (service.duration != null &&
                          service.duration!.isNotEmpty &&
                          service.location != null &&
                          service.location!.isNotEmpty)
                        const SizedBox(height: 8),
                      if (service.location != null &&
                          service.location!.isNotEmpty)
                        _buildInfoRow(
                          Icons.location_on_rounded,
                          'شوێنی مامەڵە',
                          service.location!,
                          const Color(0xFFEF4444),
                          isDark,
                        ),
                      const SizedBox(height: 20),
                    ],

                    // 📝 تێبینی
                    if (service.notes != null &&
                        service.notes!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                service.notes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildSectionTitle(String title, bool isDark, {String? badge}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _color,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRequirementItem(int index, String text, bool isDark) {
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
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeItem(String text, bool isDark) {
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
                color: isDark ? Colors.white : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon,
      String label,
      String value,
      Color color,
      bool isDark,
      ) {
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
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String icon) {
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
}