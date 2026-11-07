import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/fuel_service.dart';
import '../../l10n/tr.dart';

/// 📊 شاشەی بەراوردکردنی ٢ جۆر — ULTRA PRO
class FuelComparisonScreen extends StatefulWidget {
  final List<Map<String, String>> fuelTypes;

  const FuelComparisonScreen({
    super.key,
    required this.fuelTypes,
  });

  @override
  State<FuelComparisonScreen> createState() => _FuelComparisonScreenState();
}

class _FuelComparisonScreenState extends State<FuelComparisonScreen>
    with TickerProviderStateMixin {
  Map<String, Map<String, dynamic>> _prices = {};
  String? _selectedType1;
  String? _selectedType2;
  bool _loading = true;

  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    // ⭐ هەڵبژاردنی دوو جۆری سەرەتا
    if (widget.fuelTypes.length >= 2) {
      _selectedType1 = widget.fuelTypes[0]['key'];
      _selectedType2 = widget.fuelTypes[1]['key'];
    }

    _loadData();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final allPrices = await FuelService.getCurrentPrices();

      final Map<String, Map<String, dynamic>> prices = {};
      for (final p in allPrices) {
        final type = p['fuel_type']?.toString() ?? '';
        final price = (p['price'] as num?)?.toDouble() ?? 0;
        if (type.isEmpty || price <= 0) continue;

        final current = prices[type];
        final currentPrice =
            (current?['cheapest_price'] as num?)?.toDouble() ?? double.infinity;

        if (current == null || price < currentPrice) {
          prices[type] = {
            'cheapest_price': price,
            'cheapest_station': p['station_name']?.toString() ?? '',
            'cheapest_address': p['station_address']?.toString() ?? '',
            'total_count': ((current?['total_count'] as int?) ?? 0) + 1,
          };
        } else {
          current['total_count'] = (current['total_count'] as int) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _prices = prices;
          _loading = false;
        });
        _entryController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('❌ Comparison load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFD700),
                    ),
                  ),
                )
                    : Column(
                  children: [
                    _buildSelectors(isDark),
                    const SizedBox(height: 20),
                    if (_selectedType1 != null &&
                        _selectedType2 != null)
                      _buildComparison(isDark),
                    const SizedBox(height: 20),
                    if (_selectedType1 != null &&
                        _selectedType2 != null)
                      _buildChartComparison(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF1A1B2E),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1B2E), Color(0xFF2D1B4E)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.compare_arrows_rounded,
                      color: Color(0xFFFFD700),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('بەراوردکردنی نرخ'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('دوو جۆری سووتەمەنی بەراورد بکە'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectors(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSelector(
            isDark: isDark,
            label: tr('جۆری یەکەم'),
            value: _selectedType1,
            color: const Color(0xFF3B82F6),
            onChanged: (v) {
              setState(() => _selectedType1 = v);
              _entryController.forward(from: 0);
            },
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.compare_arrows_rounded,
            color: Color(0xFFFFD700),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSelector(
            isDark: isDark,
            label: tr('جۆری دووەم'),
            value: _selectedType2,
            color: const Color(0xFFEF4444),
            onChanged: (v) {
              setState(() => _selectedType2 = v);
              _entryController.forward(from: 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelector({
    required bool isDark,
    required String label,
    required String? value,
    required Color color,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              tr(label),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor:
              isDark ? const Color(0xFF1A1B2E) : Colors.white,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: color,
                size: 18,
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              items: widget.fuelTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['key'],
                  child: Text(tr(type['name'] ?? '')),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparison(bool isDark) {
    final type1 = _prices[_selectedType1];
    final type2 = _prices[_selectedType2];

    final price1 = (type1?['cheapest_price'] as num?)?.toDouble() ?? 0;
    final price2 = (type2?['cheapest_price'] as num?)?.toDouble() ?? 0;

    final name1 = widget.fuelTypes
        .firstWhere((t) => t['key'] == _selectedType1)['name']!;
    final name2 = widget.fuelTypes
        .firstWhere((t) => t['key'] == _selectedType2)['name']!;

    final color1 = _hexToColor(
      widget.fuelTypes
          .firstWhere((t) => t['key'] == _selectedType1)['color']!,
    );
    final color2 = _hexToColor(
      widget.fuelTypes
          .firstWhere((t) => t['key'] == _selectedType2)['color']!,
    );

    final diff = price1 - price2;
    final percent = price2 > 0 ? (diff / price2) * 100 : 0.0;

    return AnimatedBuilder(
      animation: _entryAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _entryAnimation.value)),
          child: Opacity(
            opacity: _entryAnimation.value,
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          // ⭐ Cards
          Row(
            children: [
              Expanded(
                child: _buildComparisonCard(
                  isDark: isDark,
                  name: name1,
                  price: price1,
                  color: color1,
                  station: type1?['cheapest_station'] ?? '',
                  address: type1?['cheapest_address'] ?? '',
                  isCheaper: price1 < price2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildComparisonCard(
                  isDark: isDark,
                  name: name2,
                  price: price2,
                  color: color2,
                  station: type2?['cheapest_station'] ?? '',
                  address: type2?['cheapest_address'] ?? '',
                  isCheaper: price2 < price1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ⭐ Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: diff > 0
                    ? [
                  const Color(0xFFEF4444).withValues(alpha: 0.2),
                  const Color(0xFFEF4444).withValues(alpha: 0.05),
                ]
                    : diff < 0
                    ? [
                  const Color(0xFF10B981).withValues(alpha: 0.2),
                  const Color(0xFF10B981).withValues(alpha: 0.05),
                ]
                    : [
                  Colors.grey.withValues(alpha: 0.2),
                  Colors.grey.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: diff > 0
                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                    : diff < 0
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  diff > 0
                      ? Icons.trending_up_rounded
                      : diff < 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_flat_rounded,
                  color: diff > 0
                      ? const Color(0xFFEF4444)
                      : diff < 0
                      ? const Color(0xFF10B981)
                      : Colors.grey,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  tr(diff > 0
                      ? trf('{0} هەرزانترە', [name2])
                      : diff < 0
                      ? trf('{0} هەرزانترە', [name1])
                      : 'هەردووکیان وەک یەکن'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: diff > 0
                        ? const Color(0xFFEF4444)
                        : diff < 0
                        ? const Color(0xFF10B981)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trf('جیاوازی: {0} د.ع ({1}%)', [diff.abs().toStringAsFixed(0), percent.abs().toStringAsFixed(1)]),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required bool isDark,
    required String name,
    required double price,
    required Color color,
    required String station,
    required String address,
    required bool isCheaper,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: isCheaper ? 2 : 1.5,
        ),
        boxShadow: isCheaper
            ? [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ]
            : null,
      ),
      child: Column(
        children: [
          if (isCheaper)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    tr('هەرزانتر'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_gas_station_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(name),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            price.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            tr('د.ع / لیتر'),
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (station.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            Text(
              tr(station),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (address.isNotEmpty)
              Text(
                tr(address),
                style: TextStyle(
                  fontSize: 9,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartComparison(bool isDark) {
    final type1 = _prices[_selectedType1];
    final type2 = _prices[_selectedType2];

    final price1 = (type1?['cheapest_price'] as num?)?.toDouble() ?? 0;
    final price2 = (type2?['cheapest_price'] as num?)?.toDouble() ?? 0;

    if (price1 == 0 && price2 == 0) return const SizedBox.shrink();

    final name1 = widget.fuelTypes
        .firstWhere((t) => t['key'] == _selectedType1)['name']!;
    final name2 = widget.fuelTypes
        .firstWhere((t) => t['key'] == _selectedType2)['name']!;

    final color1 = _hexToColor(
      widget.fuelTypes
          .firstWhere((t) => t['key'] == _selectedType1)['color']!,
    );
    final color2 = _hexToColor(
      widget.fuelTypes
          .firstWhere((t) => t['key'] == _selectedType2)['color']!,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: Color(0xFFFFD700),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                tr('بەراوردکردنی گرافیکی'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (price1 > price2 ? price1 : price2) * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                    isDark ? const Color(0xFF0F1421) : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(0)} د.ع',
                        TextStyle(
                          color: rodIndex == 0 ? color1 : color2,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      );
                    },
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
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            tr(value == 0 ? name1 : name2),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: value == 0 ? color1 : color2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.1),
                    strokeWidth: 1,
                    dashArray: const [5, 5],
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: price1,
                        color: color1,
                        width: 40,
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [color1, color1.withValues(alpha: 0.7)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: price2,
                        color: color2,
                        width: 40,
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [color2, color2.withValues(alpha: 0.7)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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