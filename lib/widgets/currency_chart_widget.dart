import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/currency_service.dart';

enum _Range { week, month, all }

class _Pt {
  final DateTime t;
  final double buy;
  final double? sell;
  const _Pt(this.t, this.buy, this.sell);
}

/// 📈 Chart ی گۆڕانکاری نرخی دراو — ULTRA PRO MAX V2
class CurrencyChartWidget extends StatefulWidget {
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
  State<CurrencyChartWidget> createState() => _CurrencyChartWidgetState();
}

class _CurrencyChartWidgetState extends State<CurrencyChartWidget> {
  static const Color _sellColor = Color(0xFFEF4444);

  _Range _range = _Range.all;

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
      body = _ku(buf.toString()); // '٬' is not a digit, so it stays
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

  /// Valid, sorted points. Rows with a missing date or a zero / missing
  /// buy price used to be plotted as 0 and wrecked the whole scale.
  List<_Pt> _points() {
    final list = <_Pt>[];
    for (final h in widget.history) {
      final t = DateTime.tryParse(h['created_at']?.toString() ?? '')?.toLocal();
      final buy = _num(h['new_buy_price']);
      final sell = _num(h['new_sell_price']);
      if (t == null || buy == null || buy <= 0) continue;
      list.add(_Pt(t, buy, (sell != null && sell > 0) ? sell : null));
    }
    list.sort((a, b) => a.t.compareTo(b.t));
    return list;
  }

  List<_Pt> _applyRange(List<_Pt> pts) {
    if (pts.isEmpty || _range == _Range.all) return pts;
    final days = _range == _Range.week ? 7 : 30;
    // relative to the newest point (not "now") so a currency that hasn't
    // updated recently still shows something
    final cutoff = pts.last.t.subtract(Duration(days: days));
    return pts.where((p) => !p.t.isBefore(cutoff)).toList();
  }

  Color _color() {
    try {
      return _hexToColor(CurrencyService.getColorForType(widget.currencyCode));
    } catch (_) {
      return const Color(0xFFFFD700);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final color = _color();

    final all = _points();
    if (all.length < 2) return _buildEmptyState('پێویست بە لانیکەم ٢ گۆڕانکاری هەیە');

    final pts = _applyRange(all);
    if (pts.length < 2) {
      return _buildShell(
        color: color,
        isDark: isDark,
        child: _buildEmptyInline('لەم ماوەیەدا کەمتر لە ٢ گۆڕانکاری هەیە'),
      );
    }

    // ── X axis = real time (days since first point), not the index, so
    //    uneven update times are drawn honestly ──
    final first = pts.first.t;
    double xOf(DateTime t) => t.difference(first).inSeconds / 86400;

    final buySpots = <FlSpot>[];
    final sellSpots = <FlSpot>[];
    for (final p in pts) {
      final x = xOf(p.t);
      buySpots.add(FlSpot(x, p.buy));
      if (p.sell != null) sellSpots.add(FlSpot(x, p.sell!));
    }

    final spanDays = math.max(xOf(pts.last.t), 1 / 24); // never 0
    final showTime = spanDays <= 2;

    // ── Y axis (all equal prices used to give interval 0 → crash) ──
    final prices = [...buySpots.map((s) => s.y), ...sellSpots.map((s) => s.y)];
    var minY = prices.reduce(math.min);
    var maxY = prices.reduce(math.max);
    if (maxY - minY <= 0) {
      final half = math.max(1.0, maxY * 0.01);
      minY -= half;
      maxY += half;
    }
    final yPad = (maxY - minY) * 0.15;
    final yInterval = (maxY - minY) / 4;
    final xInterval = spanDays / 4;

    final bg = isDark ? const Color(0xFF1A1B2E) : Colors.white;
    final dotsOn = pts.length <= 40;

    String dateText(double x, {bool full = false}) {
      final d = first.add(Duration(seconds: (x * 86400).round()));
      if (showTime && !full) {
        return _ku('${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}');
      }
      final base = full
          ? '${d.day}/${d.month}/${d.year}'
          : '${d.day}/${d.month}';
      return _ku(base);
    }

    return _buildShell(
      color: color,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(color, isDark, hasSell: sellSpots.isNotEmpty),
          const SizedBox(height: 12),
          _buildRangeChips(color, isDark),
          const SizedBox(height: 16),

          // ═══ Chart ═══
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
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
                      reservedSize: 56,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) => Text(
                        _fmt(value),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: xInterval,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          dateText(value),
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.white54 : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spanDays,
                minY: minY - yPad,
                maxY: maxY + yPad,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is FlTapDownEvent) HapticFeedback.selectionClick();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => bg,
                    getTooltipItems: (touched) {
                      return touched.map((spot) {
                        // bar 0 is always "buy"; "sell" only exists if drawn
                        final isBuy = spot.barIndex == 0;
                        // date once, on the first line only
                        final dateLine = (touched.first == spot)
                            ? '\n${dateText(spot.x, full: true)}'
                            : '';
                        return LineTooltipItem(
                          '${isBuy ? "کڕین" : "فرۆشتن"}: ${_fmt(spot.y)}$dateLine',
                          TextStyle(
                            color: isBuy ? color : _sellColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  _bar(buySpots, color, isDark, dotsOn, fill: true),
                  if (sellSpots.isNotEmpty)
                    _bar(sellSpots, _sellColor, isDark, dotsOn),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ Quick stats ═══
          _buildStats(pts, color, isDark),
        ],
      ),
    );
  }

  LineChartBarData _bar(
      List<FlSpot> spots,
      Color color,
      bool isDark,
      bool dotsOn, {
        bool fill = false,
      }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      preventCurveOverShooting: true, // curve never dips below real prices
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: dotsOn, // hundreds of dots look like a smear
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        ),
      ),
      belowBarData: fill
          ? BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      )
          : BarAreaData(show: false),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Pieces
  // ═══════════════════════════════════════════════════════════
  Widget _buildShell({
    required Color color,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeader(Color color, bool isDark, {required bool hasSell}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.show_chart_rounded, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'گۆڕانکاری نرخ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
        ),
        _buildLegendDot(color, 'کڕین', isDark),
        if (hasSell) ...[
          const SizedBox(width: 8),
          _buildLegendDot(_sellColor, 'فرۆشتن', isDark),
        ],
      ],
    );
  }

  Widget _buildRangeChips(Color color, bool isDark) {
    Widget chip(_Range r, String label) {
      final selected = _range == r;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: () {
            if (_range == r) return;
            HapticFeedback.selectionClick();
            setState(() => _range = r);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.18)
                  : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? color : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: selected
                    ? color
                    : (isDark ? Colors.white60 : Colors.grey.shade700),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_Range.week, '٧ ڕۆژ'),
        const SizedBox(width: 8),
        chip(_Range.month, '٣٠ ڕۆژ'),
        const SizedBox(width: 8),
        chip(_Range.all, 'هەموو'),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

  Widget _buildStats(List<_Pt> pts, Color color, bool isDark) {
    final firstBuy = pts.first.buy;
    final lastBuy = pts.last.buy;
    final diff = lastBuy - firstBuy;
    final pct = firstBuy == 0 ? 0.0 : diff / firstBuy * 100;
    final isUp = diff > 0;
    final isDown = diff < 0;

    final changeColor = isUp
        ? const Color(0xFFEF4444)
        : (isDown ? const Color(0xFF10B981) : Colors.grey);

    final pctText = diff == 0
        ? ''
        : '${isUp ? "+" : "-"}${_ku(pct.abs().toStringAsFixed(1).replaceAll('.', '٫'))}٪';

    return Row(
      children: [
        Expanded(
          child: _buildStatItem('نرخی یەکەم', _fmt(firstBuy), Colors.grey, isDark),
        ),
        Expanded(
          child: _buildStatItem(
            'گۆڕانکاری',
            _fmt(diff, sign: true),
            changeColor,
            isDark,
            sub: pctText,
          ),
        ),
        Expanded(
          child: _buildStatItem('نرخی کۆتایی', _fmt(lastBuy), color, isDark),
        ),
      ],
    );
  }

  Widget _buildStatItem(
      String label,
      String value,
      Color color,
      bool isDark, {
        String sub = '',
      }) {
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
        if (sub.isNotEmpty)
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyInline(String text) {
    final isDark = widget.isDark;
    return Column(
      children: [
        _buildHeader(_color(), isDark, hasSell: false),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _buildRangeChips(_color(), isDark),
        ),
        const SizedBox(height: 24),
        Icon(Icons.show_chart_rounded,
            size: 44, color: isDark ? Colors.white24 : Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEmptyState(String text) {
    final isDark = widget.isDark;
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
            text,
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