import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/currency_service.dart';

/// 📈 Chart ی گۆڕانکاری نرخی دراو
class CurrencyChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String currencyCode;
  final bool isDark;

  const CurrencyChartWidget({
    super.key,
    required this.history,
    required this.currencyCode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty || history.length < 2) {
      return _buildEmptyState();
    }

    // ✅ ڕیزبەندکردن بەپێی کات (کۆنترین بۆ نوێترین)
    final sorted = List<Map<String, dynamic>>.from(history)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

    // ✅ دروستکردنی Spot
    final buySpots = <FlSpot>[];
    final sellSpots = <FlSpot>[];

    for (var i = 0; i < sorted.length; i++) {
      final buy = (sorted[i]['new_buy_price'] as num?)?.toDouble() ?? 0;
      final sell = (sorted[i]['new_sell_price'] as num?)?.toDouble() ?? 0;
      buySpots.add(FlSpot(i.toDouble(), buy));
      sellSpots.add(FlSpot(i.toDouble(), sell));
    }

    // ✅ بەرزترین و نزمترین
    final allPrices = [
      ...buySpots.map((s) => s.y),
      ...sellSpots.map((s) => s.y),
    ];
    final minY = allPrices.reduce((a, b) => a < b ? a : b);
    final maxY = allPrices.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;

    // ✅ چاککراو — getColorForType لە جیاتی getColorForCurrency
    final color = _hexToColor(
      CurrencyService.getColorForType(currencyCode),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ Header ═══
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'گۆڕانکاری نرخ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // Legend
              _buildLegendDot(color, 'کڕین'),
              const SizedBox(width: 8),
              _buildLegendDot(const Color(0xFFEF4444), 'فرۆشتن'),
            ],
          ),
          const SizedBox(height: 20),

          // ═══ Chart ═══
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.15),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: (maxY - minY) / 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (sorted.length / 4).clamp(1, 10),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.tryParse(
                          sorted[idx]['created_at']?.toString() ?? '',
                        );
                        if (date == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${date.day}/${date.month}',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white54 : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (sorted.length - 1).toDouble(),
                minY: minY - padding,
                maxY: maxY + padding,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) =>
                    isDark ? const Color(0xFF1A1B2E) : Colors.white,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isBuy = spot.barIndex == 0;
                        final idx = spot.x.toInt();
                        final date = idx < sorted.length
                            ? DateTime.tryParse(
                          sorted[idx]['created_at']?.toString() ?? '',
                        )
                            : null;
                        return LineTooltipItem(
                          '${isBuy ? "کڕین" : "فرۆشتن"}: ${spot.y.toStringAsFixed(0)}\n'
                              '${date != null ? "${date.day}/${date.month}/${date.year}" : ""}',
                          TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // خطی کڕین
                  LineChartBarData(
                    spots: buySpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: color,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? const Color(0xFF1A1B2E)
                              : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.3),
                          color.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // خطی فرۆشتن
                  LineChartBarData(
                    spots: sellSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: const Color(0xFFEF4444),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFFEF4444),
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? const Color(0xFF1A1B2E)
                              : Colors.white,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ ئاماری کورت ═══
          _buildStats(sorted, color),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStats(List<Map<String, dynamic>> sorted, Color color) {
    if (sorted.isEmpty) return const SizedBox.shrink();

    final firstBuy =
        (sorted.first['new_buy_price'] as num?)?.toDouble() ?? 0;
    final lastBuy =
        (sorted.last['new_buy_price'] as num?)?.toDouble() ?? 0;
    final diff = lastBuy - firstBuy;
    final isUp = diff > 0;
    final isDown = diff < 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'نرخی یەکەم',
            firstBuy.toStringAsFixed(0),
            Colors.grey,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'گۆڕانکاری',
            '${isUp ? "+" : ""}${diff.toStringAsFixed(0)}',
            isUp
                ? const Color(0xFFEF4444)
                : (isDown ? const Color(0xFF10B981) : Colors.grey),
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'نرخی کۆتایی',
            lastBuy.toStringAsFixed(0),
            color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 50,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'پێویست بە لانیکەم ٢ گۆڕانکاری هەیە',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFFFD700);
    }
  }
}