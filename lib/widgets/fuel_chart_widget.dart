import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/fuel_service.dart';
import '../screens/fuel/fuel_chart_screen.dart';
import '../l10n/tr.dart';

class _Pt {
  final DateTime t;
  final double price;
  const _Pt(this.t, this.price);
}

/// 📈 چارتی پرۆفیشناڵی نرخی سووتەمەنی — Preview Widget — ULTRA PRO MAX V2
class FuelChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String fuelType;
  final bool isDark;

  /// How many of the newest points the small preview shows
  static const int _previewPoints = 8;

  const FuelChartWidget({
    super.key,
    required this.history,
    required this.fuelType,
    required this.isDark,
  });

  // ═══════════════════════════════════════════════════════════
  // 🧰 Helpers
  // ═══════════════════════════════════════════════════════════
  String _ku(Object n) => n.toString().replaceAllMapped(
    RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

  /// 1450 → ١٬٤٥٠   |  12.5 → ١٢٫٥   |  +30 → +٣٠
  String _fmt(double v, {bool sign = false}) {
    final neg = v < 0;
    final abs = v.abs();

    String body;
    if (abs >= 100) {
      final s = abs.round().toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write('٬');
        buf.write(s[i]);
      }
      body = _ku(buf.toString());
    } else {
      var s = abs.toStringAsFixed(1);
      if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
      body = _ku(s.replaceAll('.', '٫'));
    }

    if (neg) return '-$body';
    return sign && v > 0 ? '+$body' : body;
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').trim());
  }

  /// Valid + sorted. Rows without a date or with a zero / missing price used
  /// to be drawn as 0 and flattened the whole chart.
  List<_Pt> _points() {
    final list = <_Pt>[];
    for (final h in history) {
      final t = DateTime.tryParse(h['created_at']?.toString() ?? '')?.toLocal();
      final p = _num(h['new_price']);
      if (t == null || p == null || p <= 0) continue;
      list.add(_Pt(t, p));
    }
    list.sort((a, b) => a.t.compareTo(b.t));
    return list;
  }

  Color _color() {
    try {
      return _hexToColor(FuelService.getColorForType(fuelType));
    } catch (_) {
      return const Color(0xFFFFD700);
    }
  }

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FuelChartScreen(history: history, fuelType: fuelType),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final all = _points();
    if (all.length < 2) return _buildEmptyState();

    final color = _color();
    final data =
    all.length > _previewPoints ? all.sublist(all.length - _previewPoints) : all;

    final spots = [
      for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].price),
    ];
    final prices = data.map((p) => p.price).toList();

    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    final avgPrice = prices.reduce((a, b) => a + b) / prices.length;

    // all prices equal → min == max → chart would divide by zero
    var chartMin = minPrice;
    var chartMax = maxPrice;
    if (chartMax - chartMin <= 0) {
      final half = math.max(1.0, chartMax * 0.01);
      chartMin -= half;
      chartMax += half;
    }
    final padding = (chartMax - chartMin) * 0.2;

    final firstPrice = prices.first;
    final lastPrice = prices.last;
    final diff = lastPrice - firstPrice;
    final isUp = diff > 0;
    final isDown = diff < 0;
    // a price going UP is bad news for the driver → red, DOWN → green
    final changeColor = isUp
        ? const Color(0xFFEF4444)
        : (isDown ? const Color(0xFF10B981) : Colors.grey);

    final last = data.last.t;
    final updated = _ku('${last.day}/${last.month}/${last.year}');

    final summary =
        trf('نرخی سووتەمەنی {0} دینار، لە {1} هەتا {2}', [_fmt(lastPrice), _fmt(minPrice), _fmt(maxPrice)]);

    // Big system fonts must not overflow the fixed-size chart card
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.3,
      child: Semantics(
        button: true,
        label: trf('{0}. بۆ بینینی تەواو بیکەرەوە', [summary]),
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _open(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF1A1B2E), Color(0xFF232D3F)]
                        : const [Colors.white, Color(0xFFF8F9FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(color, updated, lastPrice),
                    const SizedBox(height: 10),
                    _buildChange(diff, firstPrice, changeColor, isUp, isDown),
                    const SizedBox(height: 10),
                    _buildChart(spots, color, chartMin, chartMax, padding),
                    const SizedBox(height: 8),
                    _buildMiniStats(color, minPrice, avgPrice, maxPrice),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Pieces
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(Color color, String updated, double lastPrice) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.show_chart_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('گۆڕانکاری نرخ'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  trf('دوایین نوێکردنەوە: {0}', [updated]),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(_fmt(lastPrice)),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                tr('د.ع'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // tappable hint
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? Colors.white38 : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  /// The change since the first preview point (this value was computed in
  /// the old code but never shown).
  Widget _buildChange(
      double diff, double first, Color color, bool isUp, bool isDown) {
    final pct = first == 0 ? 0.0 : diff / first * 100;
    final icon = isUp
        ? Icons.trending_up_rounded
        : (isDown ? Icons.trending_down_rounded : Icons.trending_flat_rounded);

    final text = diff == 0
        ? 'بێ گۆڕانکاری'
        : '${_fmt(diff, sign: true)} (${isUp ? "+" : "-"}'
        '${_ku(pct.abs().toStringAsFixed(1).replaceAll('.', '٫'))}٪)';

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              tr(text),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<FlSpot> spots, Color color, double minY, double maxY,
      double padding) {
    final lastX = (spots.length - 1).toDouble();

    return SizedBox(
      height: 100,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: lastX,
          minY: minY - padding,
          maxY: maxY + padding,
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                // only the first and the last point get a dot
                checkToShowDot: (spot, barData) =>
                spot.x == 0 || spot.x == lastX,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: color,
                      strokeWidth: 2,
                      strokeColor:
                      isDark ? const Color(0xFF1A1B2E) : Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.4),
                    color.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStats(Color color, double min, double avg, double max) {
    final divider = Container(
      width: 1,
      height: 20,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey.shade200,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniStatItem(
                'نزمترین', min, const Color(0xFF10B981)),
          ),
          divider,
          Expanded(
            child: _buildMiniStatItem('تێکڕا', avg, const Color(0xFF1E88E5)),
          ),
          divider,
          Expanded(
            child: _buildMiniStatItem(
                'بەرزترین', max, const Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatItem(String label, double value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          tr(label),
          style: TextStyle(
            fontSize: 8,
            color: isDark ? Colors.white54 : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          tr(_fmt(value)),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 40,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 10),
          Text(
            tr('پێویست بە لانیکەم ٢ گۆڕانکاری هەیە'),
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