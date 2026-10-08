import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_pdf_service.dart';

/// 📊 شاشەی چارتی سووتەمەنی — Full Pro Edition
class FuelChartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final String fuelType;

  const FuelChartScreen({
    super.key,
    required this.history,
    required this.fuelType,
  });

  @override
  State<FuelChartScreen> createState() => _FuelChartScreenState();
}

class _FuelChartScreenState extends State<FuelChartScreen>
    with TickerProviderStateMixin {
  String _chartType = 'new_price';
  String _viewMode = 'chart';

  double _minX = 0;
  double _maxX = 10;
  double _minY = 0;
  double _maxY = 100;
  bool _isZoomed = false;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  late Color _primaryColor;

  @override
  void initState() {
    super.initState();
    _primaryColor = _hexToColor(
      FuelService.getColorForType(widget.fuelType),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _resetZoom();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _sortedHistory {
    final sorted = List<Map<String, dynamic>>.from(widget.history)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });
    return sorted;
  }

  List<FlSpot> get _spots {
    final sorted = _sortedHistory;
    return List.generate(sorted.length, (i) {
      final price = (sorted[i][_chartType] as num?)?.toDouble() ?? 0;
      return FlSpot(i.toDouble(), price);
    });
  }

  void _resetZoom() {
    final spots = _spots;
    if (spots.isEmpty) return;

    final values = spots.map((s) => s.y).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxV - minV) * 0.15;

    setState(() {
      _isZoomed = false;
      _minX = 0;
      _maxX = (spots.length - 1).toDouble().clamp(1, double.infinity);
      _minY = minV - padding;
      _maxY = maxV + padding;
    });
  }

  void _zoomIn() {
    final rangeX = _maxX - _minX;
    final newRangeX = rangeX * 0.7;
    final centerX = (_minX + _maxX) / 2;
    final rangeY = _maxY - _minY;
    final newRangeY = rangeY * 0.7;
    final centerY = (_minY + _maxY) / 2;

    setState(() {
      _isZoomed = true;
      _minX = (centerX - newRangeX / 2).clamp(0, _spots.length - 1.0);
      _maxX = (centerX + newRangeX / 2).clamp(0, _spots.length - 1.0);
      _minY = centerY - newRangeY / 2;
      _maxY = centerY + newRangeY / 2;
    });
  }

  void _zoomOut() {
    final rangeX = _maxX - _minX;
    final newRangeX = rangeX * 1.3;
    final centerX = (_minX + _maxX) / 2;
    final rangeY = _maxY - _minY;
    final newRangeY = rangeY * 1.3;
    final centerY = (_minY + _maxY) / 2;

    setState(() {
      _minX = (centerX - newRangeX / 2).clamp(0, _spots.length - 1.0);
      _maxX = (centerX + newRangeX / 2).clamp(0, _spots.length - 1.0);
      _minY = centerY - newRangeY / 2;
      _maxY = centerY + newRangeY / 2;
      if (_minX <= 0 && _maxX >= _spots.length - 1) _isZoomed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = _sortedHistory;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF1A1B2E),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: 'ڕاپۆرتی PDF',
                onPressed: _generatePdf,
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() => _resetZoom()),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A1B2E),
                      _primaryColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                      BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.local_gas_station_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    FuelService.getNameKu(widget.fuelType),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${sorted.length} تۆمار',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (_isZoomed) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber
                                                .withValues(alpha: 0.3),
                                            borderRadius:
                                            BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.zoom_in_rounded,
                                                color: Colors.amber,
                                                size: 11,
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'Zoom',
                                                style: TextStyle(
                                                  color: Colors.amber,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildViewModeTabs(isDark),
            ),
          ),

          if (sorted.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'هیچ داتایەک نییە',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_viewMode == 'chart') ...[
                    _buildChartTypeTabs(isDark),
                    const SizedBox(height: 12),
                    _buildZoomControls(isDark),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildMainChart(isDark),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsSection(sorted, isDark),
                  ],
                  if (_viewMode == 'stats') ...[
                    _buildBigStatsSection(sorted, isDark),
                  ],
                  if (_viewMode == 'list') ...[
                    _buildSectionTitle('📋 لیستی گۆڕانکارییەکان', isDark),
                    const SizedBox(height: 12),
                    ...sorted.reversed.toList().asMap().entries.map(
                          (entry) => _buildHistoryCard(
                        entry.value,
                        entry.key == 0,
                        isDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewModeTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildViewTab(
              label: 'چارت',
              icon: Icons.show_chart_rounded,
              value: 'chart',
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildViewTab(
              label: 'ئامار',
              icon: Icons.bar_chart_rounded,
              value: 'stats',
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildViewTab(
              label: 'لیست',
              icon: Icons.list_alt_rounded,
              value: 'list',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab({
    required String label,
    required IconData icon,
    required String value,
    required bool isDark,
  }) {
    final isSelected = _viewMode == value;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
          )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTypeTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeTab(
              label: 'نرخی نوێ',
              icon: Icons.trending_up_rounded,
              value: 'new_price',
              color: _primaryColor,
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildTypeTab(
              label: 'نرخی کۆن',
              icon: Icons.history_rounded,
              value: 'old_price',
              color: Colors.orange,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required IconData icon,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _chartType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _chartType = value;
          _resetZoom();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
          )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _isZoomed ? Icons.zoom_in_rounded : Icons.zoom_out_map_rounded,
            size: 18,
            color: _isZoomed ? _primaryColor : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isZoomed ? 'Zoom کراوە' : 'دۆخی ئاسایی',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _isZoomed
                    ? _primaryColor
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ),
          _buildZoomButton(Icons.add_rounded, _zoomIn, _primaryColor),
          const SizedBox(width: 6),
          _buildZoomButton(Icons.remove_rounded, _zoomOut, _primaryColor),
          if (_isZoomed) ...[
            const SizedBox(width: 6),
            _buildZoomButton(
              Icons.refresh_rounded,
              _resetZoom,
              const Color(0xFFEF4444),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomButton(
      IconData icon,
      VoidCallback onPressed,
      Color color,
      ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildMainChart(bool isDark) {
    final sorted = _sortedHistory;
    final spots = _spots;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor,
                      _primaryColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'گۆڕانکاری نرخ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 340,
            child: GestureDetector(
              onDoubleTap: _resetZoom,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: (_maxY - _minY) / 4,
                    verticalInterval: (_maxX - _minX) / 5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.1),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.grey.withValues(alpha: 0.08),
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
                        reservedSize: 60,
                        interval: (_maxY - _minY) / 4,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: (_maxX - _minX) / 4,
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
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: _minX,
                  maxX: _maxX,
                  minY: _minY,
                  maxY: _maxY,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => isDark
                          ? const Color(0xFF0F1421)
                          : Colors.white,
                      tooltipRoundedRadius: 14,
                      tooltipPadding: const EdgeInsets.all(14),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.toInt();
                          final date = idx < sorted.length
                              ? DateTime.tryParse(
                            sorted[idx]['created_at']?.toString() ?? '',
                          )
                              : null;
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(0)} د.ع\n',
                            TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            children: [
                              TextSpan(
                                text: date != null
                                    ? DateFormat('dd/MM/yyyy • HH:mm')
                                    .format(date)
                                    : '',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: _primaryColor,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) {
                          final step = (spots.length / 10).clamp(1, 100);
                          return spot.x.toInt() % step == 0 ||
                              spot.x == 0 ||
                              spot.x == spots.length - 1.0;
                        },
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: _primaryColor,
                            strokeWidth: 2.5,
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
                            _primaryColor.withValues(alpha: 0.4),
                            _primaryColor.withValues(alpha: 0.15),
                            _primaryColor.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.5, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
      List<Map<String, dynamic>> sorted,
      bool isDark,
      ) {
    final prices = _spots.map((s) => s.y).toList();
    if (prices.isEmpty) return const SizedBox.shrink();

    final firstPrice = prices.first;
    final lastPrice = prices.last;
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final avgPrice = prices.reduce((a, b) => a + b) / prices.length;
    final diff = lastPrice - firstPrice;
    final percentChange =
    firstPrice > 0 ? (diff / firstPrice) * 100 : 0.0;
    final isUp = diff > 0;
    final isDown = diff < 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isUp
                  ? [
                const Color(0xFFEF4444).withValues(alpha: 0.15),
                const Color(0xFFEF4444).withValues(alpha: 0.05),
              ]
                  : isDown
                  ? [
                const Color(0xFF10B981).withValues(alpha: 0.15),
                const Color(0xFF10B981).withValues(alpha: 0.05),
              ]
                  : [
                Colors.grey.withValues(alpha: 0.15),
                Colors.grey.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUp
                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                  : isDown
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUp
                      ? const Color(0xFFEF4444)
                      : isDown
                      ? const Color(0xFF10B981)
                      : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUp
                      ? Icons.trending_up_rounded
                      : isDown
                      ? Icons.trending_down_rounded
                      : Icons.trending_flat_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUp
                          ? 'زیادبوونی گشتی'
                          : isDown
                          ? 'کەمبوونەوەی گشتی'
                          : 'بێ گۆڕانکاری',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isUp
                            ? const Color(0xFFEF4444)
                            : isDown
                            ? const Color(0xFF10B981)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percentChange.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isUp ? "+" : ""}${diff.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isUp
                          ? const Color(0xFFEF4444)
                          : isDown
                          ? const Color(0xFF10B981)
                          : Colors.grey,
                    ),
                  ),
                  Text(
                    'د.ع',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                'نزمترین',
                minPrice,
                const Color(0xFF10B981),
                isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStat(
                'تێکڕا',
                avgPrice,
                const Color(0xFF1E88E5),
                isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStat(
                'بەرزترین',
                maxPrice,
                const Color(0xFFEF4444),
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBigStatsSection(
      List<Map<String, dynamic>> sorted,
      bool isDark,
      ) {
    final prices = _spots.map((s) => s.y).toList();
    if (prices.isEmpty) return const SizedBox.shrink();

    final firstPrice = prices.first;
    final lastPrice = prices.last;
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final avgPrice = prices.reduce((a, b) => a + b) / prices.length;
    final diff = lastPrice - firstPrice;
    final percentChange =
    firstPrice > 0 ? (diff / firstPrice) * 100 : 0.0;
    final isUp = diff > 0;
    final isDown = diff < 0;

    return Column(
      children: [
        _buildBigStatCard(
          'نرخی ئێستا',
          lastPrice,
          _primaryColor,
          Icons.attach_money_rounded,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildBigStatCard(
          'نزمترین نرخ',
          minPrice,
          const Color(0xFF10B981),
          Icons.arrow_downward_rounded,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildBigStatCard(
          'بەرزترین نرخ',
          maxPrice,
          const Color(0xFFEF4444),
          Icons.arrow_upward_rounded,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildBigStatCard(
          'تێکڕای نرخ',
          avgPrice,
          const Color(0xFF1E88E5),
          Icons.show_chart_rounded,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildBigStatCard(
          'گۆڕانکاری گشتی',
          diff,
          isUp
              ? const Color(0xFFEF4444)
              : isDown
              ? const Color(0xFF10B981)
              : Colors.grey,
          isUp
              ? Icons.trending_up_rounded
              : isDown
              ? Icons.trending_down_rounded
              : Icons.trending_flat_rounded,
          isDark,
          suffix: isUp ? '+' : '',
          subtitle: '${percentChange.toStringAsFixed(1)}%',
        ),
      ],
    );
  }

  Widget _buildBigStatCard(
      String title,
      double value,
      Color color,
      IconData icon,
      bool isDark, {
        String suffix = '',
        String? subtitle,
      }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$suffix${value.toStringAsFixed(0)} د.ع',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      String label,
      double value,
      Color color,
      bool isDark,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            'د.ع',
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(4),
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
      ],
    );
  }

  Widget _buildHistoryCard(
      Map<String, dynamic> item,
      bool isLatest,
      bool isDark,
      ) {
    final oldPrice = (item['old_price'] as num?)?.toDouble();
    final newPrice = (item['new_price'] as num?)?.toDouble() ?? 0;
    final updatedBy = item['updated_by_name']?.toString() ?? 'نەناسراو';
    final notes = item['notes']?.toString() ?? '';
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'].toString())
        : null;

    final isIncrease = oldPrice != null && newPrice > oldPrice;
    final isDecrease = oldPrice != null && newPrice < oldPrice;

    final changeColor = isIncrease
        ? const Color(0xFFEF4444)
        : isDecrease
        ? const Color(0xFF10B981)
        : Colors.grey;
    final changeIcon = isIncrease
        ? Icons.arrow_upward_rounded
        : isDecrease
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLatest
              ? _primaryColor.withValues(alpha: 0.4)
              : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200),
          width: isLatest ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(changeIcon, color: changeColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${newPrice.toStringAsFixed(0)} د.ع',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                            ),
                          ),
                          if (isLatest) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'نوێترین',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (oldPrice != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'لە ${oldPrice.toStringAsFixed(0)} د.ع',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (oldPrice != null && oldPrice != newPrice)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${isIncrease ? "+" : ""}${(newPrice - oldPrice).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: changeColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color:
                isDark ? const Color(0xFF0F1421) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 12,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    updatedBy,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    createdAt != null
                        ? DateFormat('dd/MM/yyyy • HH:mm').format(createdAt)
                        : '-',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F1421)
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.note_rounded,
                      size: 12,
                      color: isDark
                          ? const Color(0xFFFFD700)
                          : const Color(0xFFB8860B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF5D4037),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    await FuelPdfService.generateDateRangeReport(
      context: context,
      fromDate: DateTime.now().subtract(const Duration(days: 90)),
      toDate: DateTime.now(),
      fuelType: widget.fuelType,
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