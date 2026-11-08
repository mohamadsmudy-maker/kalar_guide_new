import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_pdf_service.dart';
import '../../l10n/tr.dart';

part 'fuel_chart_screen_ui.dart';

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
                tooltip: tr('ڕاپۆرتی PDF'),
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
                                    tr(FuelService.getNameKu(widget.fuelType)),
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
                                          trf('{0} تۆمار', [sorted.length]),
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
            SliverFillRemaining(
              child: Center(
                child: Text(
                  tr('هیچ داتایەک نییە'),
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
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
                    _buildSectionTitle(tr('📋 لیستی گۆڕانکارییەکان'), isDark),
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
              tr(label),
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
              tr(label),
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