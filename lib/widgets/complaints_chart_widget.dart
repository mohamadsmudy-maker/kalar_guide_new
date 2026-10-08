import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// 📊 چارت بۆ نیشاندانی دۆخی سکاڵاکان
class ComplaintsChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> complaints;
  final bool isDark;

  const ComplaintsChartWidget({
    super.key,
    required this.complaints,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (complaints.isEmpty) {
      return const SizedBox.shrink();
    }

    // حسابی ژمارەی هەر دۆخێک
    final statusCount = <String, int>{};
    for (final c in complaints) {
      final status = c['status']?.toString() ?? 'pending';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    final total = complaints.length;

    final statusLabels = {
      'pending': 'چاوەڕوان',
      'approved': 'پەسەندکراو',
      'in_progress': 'لە ئارادایە',
      'completed': 'جێبەجێکرا',
      'rejected': 'ڕەتکراو',
    };

    final statusColors = {
      'pending': const Color(0xFFFF9800),
      'approved': const Color(0xFF2ECC71),
      'in_progress': const Color(0xFF2ECC71),
      'completed': const Color(0xFF3498DB),
      'rejected': const Color(0xFFE74C3C),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFFE91E63),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ئاماری سکاڵاکان',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              Text(
                '$total کۆی',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🍩 Pie Chart
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 45,
                sections: statusCount.entries.map((entry) {
                  final status = entry.key;
                  final count = entry.value;
                  final percent = (count / total) * 100;
                  final color = statusColors[status] ?? Colors.grey;
                  final label = statusLabels[status] ?? status;

                  return PieChartSectionData(
                    value: count.toDouble(),
                    color: color,
                    radius: 55,
                    title: '${percent.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                    badgePositionPercentageOffset: 1.3,
                    badgeWidget: _buildBadge(label, color),
                    // ❌ badgeTitle لابرا — پارامەتەرێکی نادروستە
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 📋 Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: statusCount.entries.map((entry) {
              final status = entry.key;
              final count = entry.value;
              final color = statusColors[status] ?? Colors.grey;
              final label = statusLabels[status] ?? status;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$label ($count)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}