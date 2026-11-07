import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/currency_service.dart';
import '../l10n/tr.dart';

/// 📈 Chart ی گۆڕانکاری هەموو دراوەکان — FULL PRO
class MultiCurrencyChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final bool isDark;

  const MultiCurrencyChartWidget({
    super.key,
    required this.history,
    required this.isDark,
  });

  @override
  State<MultiCurrencyChartWidget> createState() =>
      _MultiCurrencyChartWidgetState();
}

class _MultiCurrencyChartWidgetState extends State<MultiCurrencyChartWidget> {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  final Set<String> _selectedCodes = {};
  final Map<String, List<FlSpot>> _buySpots = {};
  final Map<String, List<FlSpot>> _sellSpots = {};
  final Map<String, Color> _colors = {};
  final Map<String, String> _names = {};
  final List<DateTime> _dates = [];

  String _rangeFilter = 'month';
  String _priceType = 'buy';

  double _minX = 0;
  double _maxX = 10;
  double _minY = 0;
  double _maxY = 100;
  bool _isZoomed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareData());
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ئامادەکردنی داتا
  // ═══════════════════════════════════════════════════════════
  void _prepareData() {
    _buySpots.clear();
    _sellSpots.clear();
    _colors.clear();
    _names.clear();
    _dates.clear();

    if (widget.history.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // ✅ ١. فلتەرکردن بەپێی ماوە
    final now = DateTime.now();
    Duration rangeDuration;
    switch (_rangeFilter) {
      case 'week':
        rangeDuration = const Duration(days: 7);
        break;
      case '3months':
        rangeDuration = const Duration(days: 90);
        break;
      case '6months':
        rangeDuration = const Duration(days: 180);
        break;
      case 'year':
        rangeDuration = const Duration(days: 365);
        break;
      case 'month':
      default:
        rangeDuration = const Duration(days: 30);
    }

    final cutoffDate = now.subtract(rangeDuration);

    final filtered = widget.history.where((item) {
      final date = DateTime.tryParse(item['created_at']?.toString() ?? '');
      return date != null && date.isAfter(cutoffDate);
    }).toList();

    if (filtered.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // ✅ ٢. ڕیزبەندکردن
    final sorted = List<Map<String, dynamic>>.from(filtered)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

    // ✅ ٣. گروپکردن بەپێی دراو + کۆکردنەوە بە ڕۆژ
    final Map<String, Map<String, List<Map<String, dynamic>>>> dailyByCode =
    {};

    for (final item in sorted) {
      final code = item['currency_type']?.toString() ?? '';
      if (code.isEmpty) continue;

      final date = DateTime.tryParse(item['created_at']?.toString() ?? '');
      if (date == null) continue;

      final dayKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      dailyByCode.putIfAbsent(code, () => {});
      dailyByCode[code]!.putIfAbsent(dayKey, () => []).add(item);
    }

    // ✅ ٤. کۆکردنەوەی هەموو بەروارەکان
    final allDayKeys = <String>{};
    for (final codeData in dailyByCode.values) {
      allDayKeys.addAll(codeData.keys);
    }

    final sortedDayKeys = allDayKeys.toList()..sort();

    // ✅ ٥. پڕکردنەوەی _dates
    for (final dayKey in sortedDayKeys) {
      final parts = dayKey.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        _dates.add(date);
      }
    }

    // ✅ ٦. دروستکردنی FlSpot
    for (final entry in dailyByCode.entries) {
      final code = entry.key;
      final dayData = entry.value;

      _colors[code] = _hexToColor(CurrencyService.getColorForType(code));
      _names[code] = CurrencyService.getNameKu(code);

      final buyList = <FlSpot>[];
      final sellList = <FlSpot>[];

      for (int i = 0; i < sortedDayKeys.length; i++) {
        final dayKey = sortedDayKeys[i];
        final itemsForDay = dayData[dayKey];

        if (itemsForDay == null || itemsForDay.isEmpty) {
          buyList.add(FlSpot(i.toDouble(), 0));
          sellList.add(FlSpot(i.toDouble(), 0));
        } else {
          double sumBuy = 0;
          double sumSell = 0;
          int countBuy = 0;
          int countSell = 0;

          for (final item in itemsForDay) {
            final buy = (item['new_buy_price'] as num?)?.toDouble() ?? 0.0;
            final sell = (item['new_sell_price'] as num?)?.toDouble() ?? 0.0;
            if (buy > 0) {
              sumBuy += buy;
              countBuy++;
            }
            if (sell > 0) {
              sumSell += sell;
              countSell++;
            }
          }

          final avgBuy = countBuy > 0 ? sumBuy / countBuy : 0.0;
          final avgSell = countSell > 0 ? sumSell / countSell : 0.0;

          buyList.add(FlSpot(i.toDouble(), avgBuy));
          sellList.add(FlSpot(i.toDouble(), avgSell));
        }
      }

      _buySpots[code] = buyList;
      _sellSpots[code] = sellList;
    }

    // ✅ ٧. هەڵبژاردنی سەرەتا (3 دراو)
    if (_selectedCodes.isEmpty) {
      _selectedCodes.addAll(dailyByCode.keys.take(3));
    }

    _resetZoom();
    setState(() => _isLoading = false);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Zoom
  // ═══════════════════════════════════════════════════════════
  void _resetZoom() {
    if (!mounted) return;

    setState(() {
      _isZoomed = false;
      _minX = 0;
      _maxX = (_dates.length - 1).toDouble().clamp(1.0, double.infinity);

      final allValues = <double>[];
      for (final code in _selectedCodes) {
        final spots =
        _priceType == 'buy' ? _buySpots[code] : _sellSpots[code];
        if (spots != null) {
          for (final spot in spots) {
            if (spot.y > 0) allValues.add(spot.y);
          }
        }
      }

      if (allValues.isNotEmpty) {
        // ✅ چارەسەرکرا: toDouble() بۆ هەموو بەهاکان
        final minV = allValues
            .reduce((double a, double b) => a < b ? a : b)
            .toDouble();
        final maxV = allValues
            .reduce((double a, double b) => a > b ? a : b)
            .toDouble();
        final padding = (maxV - minV) * 0.15;
        _minY = (minV - padding).clamp(0.0, double.infinity).toDouble();
        _maxY = (maxV + padding).toDouble();
      } else {
        _minY = 0.0;
        _maxY = 100.0;
      }
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
      _minX = (centerX - newRangeX / 2).clamp(0.0, _dates.length - 1.0);
      _maxX = (centerX + newRangeX / 2).clamp(0.0, _dates.length - 1.0);
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
      _minX = (centerX - newRangeX / 2).clamp(0.0, _dates.length - 1.0);
      _maxX = (centerX + newRangeX / 2).clamp(0.0, _dates.length - 1.0);
      _minY = centerY - newRangeY / 2;
      _maxY = centerY + newRangeY / 2;
      if (_minX <= 0 && _maxX >= _dates.length - 1) _isZoomed = false;
    });
  }

  void _toggleCode(String code) {
    setState(() {
      if (_selectedCodes.contains(code)) {
        if (_selectedCodes.length > 1) {
          _selectedCodes.remove(code);
          _resetZoom();
        }
      } else {
        if (_selectedCodes.length < 5) {
          _selectedCodes.add(code);
          _resetZoom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('تەنها ٥ دراو دەتوانرێت هەڵبژێردرێن')),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _changeRange(String range) {
    setState(() {
      _rangeFilter = range;
      _selectedCodes.clear();
      _isLoading = true;
    });
    _prepareData();
  }

  void _changePriceType(String type) {
    setState(() {
      _priceType = type;
    });
    _resetZoom();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoading();
    }

    if (_buySpots.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildRangeFilter(),
          const SizedBox(height: 8),
          _buildPriceTypeToggle(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 12),
          _buildZoomControls(),
          const SizedBox(height: 12),
          _buildChart(),
          const SizedBox(height: 16),
          _buildStats(),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.show_chart_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('گۆڕانکاری هەموو دراوەکان'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.pinch_rounded, size: 10, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text(
                    tr('Zoom بە دوو پەنجە'),
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_selectedCodes.length}/5',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 Range Filter
  // ═══════════════════════════════════════════════════════════
  Widget _buildRangeFilter() {
    final ranges = [
      {'key': 'week', 'label': '١ هەفتە'},
      {'key': 'month', 'label': '١ مانگ'},
      {'key': '3months', 'label': '٣ مانگ'},
      {'key': '6months', 'label': '٦ مانگ'},
      {'key': 'year', 'label': '١ ساڵ'},
    ];

    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ranges.length,
        itemBuilder: (context, index) {
          final range = ranges[index];
          final isSelected = _rangeFilter == range['key'];

          return GestureDetector(
            onTap: () => _changeRange(range['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : (widget.isDark
                    ? const Color(0xFF0F1421)
                    : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Text(
                  tr(range['label']!),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Colors.white
                        : (widget.isDark
                        ? Colors.white70
                        : Colors.grey.shade700),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 Price Type Toggle
  // ═══════════════════════════════════════════════════════════
  Widget _buildPriceTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF0F1421)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPriceTypeButton(
              label: tr('کڕین'),
              icon: Icons.shopping_cart_rounded,
              value: 'buy',
              color: const Color(0xFF1E88E5),
            ),
          ),
          Expanded(
            child: _buildPriceTypeButton(
              label: tr('فرۆشتن'),
              icon: Icons.sell_rounded,
              value: 'sell',
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTypeButton({
    required String label,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final isSelected = _priceType == value;
    return GestureDetector(
      onTap: () => _changePriceType(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
          )
              : null,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (widget.isDark ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(width: 6),
            Text(
              tr(label),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isSelected
                    ? Colors.white
                    : (widget.isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ Filter Chips
  // ═══════════════════════════════════════════════════════════
  Widget _buildFilterChips() {
    final allCodes = _buySpots.keys.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allCodes.map((code) {
        final isSelected = _selectedCodes.contains(code);
        final color = _colors[code] ?? Colors.grey;

        return GestureDetector(
          onTap: () => _toggleCode(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              )
                  : null,
              color: isSelected
                  ? null
                  : (widget.isDark
                  ? const Color(0xFF0F1421)
                  : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? color
                    : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  tr(code.toUpperCase()),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Colors.white
                        : (widget.isDark
                        ? Colors.white70
                        : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Zoom Controls
  // ═══════════════════════════════════════════════════════════
  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF0F1421)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isZoomed ? Icons.zoom_in_rounded : Icons.zoom_out_map_rounded,
            size: 16,
            color: _isZoomed
                ? const Color(0xFF10B981)
                : (widget.isDark ? Colors.white54 : Colors.grey),
          ),
          const SizedBox(width: 8),
          Text(
            tr(_isZoomed ? 'Zoom کراوە' : 'دۆخی ئاسایی'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _isZoomed
                  ? const Color(0xFF10B981)
                  : (widget.isDark ? Colors.white54 : Colors.grey),
            ),
          ),
          const Spacer(),
          _buildZoomButton(Icons.add_rounded, _zoomIn),
          const SizedBox(width: 6),
          _buildZoomButton(Icons.remove_rounded, _zoomOut),
          if (_isZoomed) ...[
            const SizedBox(width: 6),
            _buildZoomButton(
              Icons.refresh_rounded,
              _resetZoom,
              color: const Color(0xFFEF4444),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed,
      {Color? color}) {
    final c = color ?? const Color(0xFF10B981);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: c),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📈 Chart
  // ═══════════════════════════════════════════════════════════
  Widget _buildChart() {
    return SizedBox(
      height: 280,
      child: GestureDetector(
        onScaleUpdate: (details) {
          if (details.scale != 1.0) {
            final rangeX = _maxX - _minX;
            final rangeY = _maxY - _minY;
            final scaleFactor = 1.0 / details.scale;
            final newRangeX = rangeX * scaleFactor;
            final newRangeY = rangeY * scaleFactor;

            final focalX =
                _minX + (details.localFocalPoint.dx / 300) * rangeX;
            final focalY =
                _maxY - (details.localFocalPoint.dy / 280) * rangeY;

            setState(() {
              _isZoomed = true;
              _minX = (focalX - newRangeX / 2)
                  .clamp(0.0, _dates.length - 1.0);
              _maxX = (focalX + newRangeX / 2)
                  .clamp(0.0, _dates.length - 1.0);
              _minY = focalY - newRangeY / 2;
              _maxY = focalY + newRangeY / 2;
            });
          }

          if (details.focalPointDelta != Offset.zero &&
              details.scale == 1.0) {
            final rangeX = _maxX - _minX;
            final rangeY = _maxY - _minY;
            final dx = -details.focalPointDelta.dx / 300 * rangeX;
            final dy = details.focalPointDelta.dy / 280 * rangeY;

            setState(() {
              _minX = (_minX + dx).clamp(0.0, _dates.length - 1.0);
              _maxX = (_maxX + dx).clamp(0.0, _dates.length - 1.0);
              _minY = _minY + dy;
              _maxY = _maxY + dy;
            });
          }
        },
        onDoubleTap: _resetZoom,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (_maxY - _minY) / 4,
              getDrawingHorizontalLine: (value) => FlLine(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.15),
                strokeWidth: 1,
                dashArray: const [5, 5],
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
                  reservedSize: 55,
                  interval: (_maxY - _minY) / 4,
                  getTitlesWidget: (value, meta) {
                    if (value < 0) return const SizedBox.shrink();
                    return Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 9,
                        color:
                        widget.isDark ? Colors.white54 : Colors.grey,
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
                  interval:
                  ((_maxX - _minX) / 4).clamp(1, double.infinity),
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= _dates.length) {
                      return const SizedBox.shrink();
                    }
                    final date = _dates[idx];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${date.day}/${date.month}',
                        style: TextStyle(
                          fontSize: 9,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.grey,
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
            minY: _minY.clamp(0.0, double.infinity).toDouble(),
            maxY: _maxY,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => widget.isDark
                    ? const Color(0xFF0F1421)
                    : Colors.white,
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.all(10),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final codes = _selectedCodes.toList();
                    final code =
                    spot.barIndex < codes.length ? codes[spot.barIndex] : '';
                    final name = _names[code] ?? code.toUpperCase();
                    final color = _colors[code] ?? Colors.grey;

                    return LineTooltipItem(
                      '$name\n',
                      TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                      children: [
                        TextSpan(
                          text: trf('{0} د.ع', [spot.y.toStringAsFixed(0)]),
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: _selectedCodes.map((code) {
              final color = _colors[code] ?? Colors.grey;
              final spots = _priceType == 'buy'
                  ? (_buySpots[code] ?? [])
                  : (_sellSpots[code] ?? []);

              return LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                preventCurveOverShooting: true,
                color: color,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (spot, barData) {
                    if (spot.y <= 0) return false;
                    if (spot.x < _minX || spot.x > _maxX) return false;
                    return true;
                  },
                  getDotPainter: (spot, percent, bar, index) {
                    return FlDotCirclePainter(
                      radius: 3.5,
                      color: color,
                      strokeWidth: 2,
                      strokeColor: widget.isDark
                          ? const Color(0xFF1A1B2E)
                          : Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats
  // ═══════════════════════════════════════════════════════════
  Widget _buildStats() {
    return Column(
      children: _selectedCodes.map((code) {
        final spots = _priceType == 'buy'
            ? (_buySpots[code] ?? [])
            : (_sellSpots[code] ?? []);
        final validSpots = spots.where((s) => s.y > 0).toList();
        if (validSpots.isEmpty) return const SizedBox.shrink();

        final firstPrice = validSpots.first.y;
        final lastPrice = validSpots.last.y;
        final diff = lastPrice - firstPrice;
        final percent =
        firstPrice > 0 ? (diff / firstPrice) * 100 : 0.0;
        final isUp = diff > 0;
        final color = _colors[code] ?? Colors.grey;
        final name = _names[code] ?? code.toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              // Code Badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    tr(code.toUpperCase()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(name),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(_priceType == 'buy' ? 'نرخی کڕین' : 'نرخی فرۆشتن'),
                      style: TextStyle(
                        fontSize: 9,
                        color: widget.isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Price + Percent
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trf('{0} د.ع', [lastPrice.toStringAsFixed(0)]),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (diff != 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUp
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 11,
                          color: isUp
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${isUp ? "+" : ""}${percent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isUp
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      tr('بێ گۆڕانکاری'),
                      style: TextStyle(
                        fontSize: 9,
                        color:
                        widget.isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 50,
            color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            tr('هیچ داتایەک نییە لەم ماوەیەدا'),
            style: TextStyle(
              fontSize: 13,
              color: widget.isDark ? Colors.white54 : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('ماوەیەکی تر هەڵبژێرە'),
            style: TextStyle(
              fontSize: 11,
              color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }
}