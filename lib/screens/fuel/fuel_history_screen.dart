import 'package:flutter/material.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_pdf_service.dart';
import '../../widgets/fuel_chart_widget.dart';
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../utils/date_picker_helper.dart';
import '../../l10n/tr.dart';
/// 📜 شاشەی مێژووی نرخی سووتەمەنی — لەگەڵ چارت و PDF
class FuelHistoryScreen extends StatefulWidget {
  final int stationId;
  final String stationName;
  final String? fuelType;

  const FuelHistoryScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    this.fuelType,
  });

  @override
  State<FuelHistoryScreen> createState() => _FuelHistoryScreenState();
}

class _FuelHistoryScreenState extends State<FuelHistoryScreen> {
  bool _loading = true;
  bool _generatingPdf = false;
  List<Map<String, dynamic>> _history = [];

  // ✅ بەرواری دیاریکراو
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final history = await FuelService.getStationPriceHistory(
        stationId: widget.stationId,
        fuelType: widget.fuelType,
      );

      if (mounted) {
        setState(() {
          _history = history;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 هەڵبژاردنی بەروار
  // ═══════════════════════════════════════════════════════════
  Future<void> _pickDateRange() async {
    final lang = context.read<SettingsProvider>().languageId;

    final picked = await DatePickerHelper.showRangePicker(
      context: context,
      languageId: lang,
      initialFrom: _fromDate,
      initialTo: _toDate,
      primaryColor: const Color(0xFFFFD700),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 PDF بە بەرواری دیاریکراو
  // ═══════════════════════════════════════════════════════════
  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      await FuelPdfService.generateDateRangeReport(
        context: context,
        fromDate: _fromDate,
        toDate: _toDate,
        fuelType: widget.fuelType,
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  // ✅ فلتەرکردنی مێژوو بەپێی بەروار
  List<Map<String, dynamic>> get _filteredHistory {
    return _history.where((item) {
      final createdAt = DateTime.tryParse(
        item['created_at']?.toString() ?? '',
      );
      if (createdAt == null) return false;

      return createdAt.isAfter(_fromDate.subtract(const Duration(days: 1))) &&
          createdAt.isBefore(_toDate.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredHistory;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('مێژووی نرخەکان'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              Text(
                tr(widget.fuelType != null
                    ? '${widget.stationName} • ${FuelService.getNameKu(widget.fuelType!)}'
                    : widget.stationName),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          actions: [
            // ✅ دوگمەی PDF
            IconButton(
              icon: _generatingPdf
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFFD700),
                ),
              )
                  : const Icon(Icons.picture_as_pdf_rounded),
              tooltip: tr('ڕاپۆرتی PDF'),
              onPressed:
              _generatingPdf || filtered.isEmpty ? null : _generatePdf,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadHistory,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        )
            : _history.isEmpty
            ? _buildEmptyState(isDark)
            : RefreshIndicator(
          color: const Color(0xFFFFD700),
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ✅ دوگمەی هەڵبژاردنی بەروار
              _buildDateRangeButton(isDark),
              const SizedBox(height: 16),

              // ✅ چارت
              if (widget.fuelType != null && filtered.length >= 2) ...[
                FuelChartWidget(
                  history: filtered,
                  fuelType: widget.fuelType!,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
              ],

              // ✅ ئاماری کورت
              _buildSectionTitle(tr('📊 ئاماری کورت'), isDark),
              const SizedBox(height: 12),
              _buildStats(filtered, isDark),
              const SizedBox(height: 20),

              // ✅ لیستی گۆڕانکارییەکان
              _buildSectionTitle(tr('📋 لیستی گۆڕانکارییەکان'), isDark),
              const SizedBox(height: 12),

              if (filtered.isEmpty)
                _buildNoDataForRange(isDark)
              else
                ...filtered.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _buildHistoryCard(
                    item,
                    index == 0, // isLatest
                    isDark,
                  );
                }),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 دوگمەی هەڵبژاردنی بەروار
  // ═══════════════════════════════════════════════════════════
  Widget _buildDateRangeButton(bool isDark) {
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1421).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.date_range_rounded,
                color: Color(0xFF0F1421),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('ماوەی بەروار'),
                    style: const TextStyle(
                      color: Color(0xFF0F1421),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trf('{0} بۆ {1}', [_formatDate(_fromDate), _formatDate(_toDate)]),
                    style: const TextStyle(
                      color: Color(0xFF0F1421),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar_rounded,
              color: Color(0xFF0F1421),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ئاماری کورت
  // ═══════════════════════════════════════════════════════════
  Widget _buildStats(List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            tr('هیچ داتایەک نییە'),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final prices = items
        .map((h) => (h['new_price'] as num?)?.toDouble() ?? 0)
        .toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final avgPrice = prices.reduce((a, b) => a + b) / prices.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            'نزمترین',
            minPrice.toStringAsFixed(0),
            const Color(0xFF10B981),
            Icons.arrow_downward_rounded,
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatBox(
            'تێکڕا',
            avgPrice.toStringAsFixed(0),
            const Color(0xFF1E88E5),
            Icons.show_chart_rounded,
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatBox(
            'بەرزترین',
            maxPrice.toStringAsFixed(0),
            const Color(0xFFEF4444),
            Icons.arrow_upward_rounded,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(
      String label,
      String value,
      Color color,
      IconData icon,
      bool isDark,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            tr(label),
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(value),
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
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی مێژوو
  // ═══════════════════════════════════════════════════════════
  Widget _buildHistoryCard(
      Map<String, dynamic> item,
      bool isLatest,
      bool isDark,
      ) {
    final fuelType = item['fuel_type']?.toString() ?? '';
    final oldPrice = (item['old_price'] as num?)?.toDouble();
    final newPrice = (item['new_price'] as num?)?.toDouble() ?? 0;
    final updatedBy = item['updated_by_name']?.toString() ?? 'نەناسراو';
    final notes = item['notes']?.toString() ?? '';
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'].toString())
        : null;

    final color = _hexToColor(FuelService.getColorForType(fuelType));

    final isIncrease = oldPrice != null && newPrice > oldPrice;
    final isDecrease = oldPrice != null && newPrice < oldPrice;

    Color changeColor;
    IconData changeIcon;
    if (isIncrease) {
      changeColor = const Color(0xFFEF4444);
      changeIcon = Icons.arrow_upward_rounded;
    } else if (isDecrease) {
      changeColor = const Color(0xFF10B981);
      changeIcon = Icons.arrow_downward_rounded;
    } else {
      changeColor = Colors.grey;
      changeIcon = Icons.remove_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest
              ? color.withValues(alpha: 0.4)
              : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200),
          width: isLatest ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLatest
                ? color.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: isLatest ? 15 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tr(FuelService.getNameKu(fuelType)),
                            style: TextStyle(
                              fontSize: 14,
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
                              child: Text(
                                tr('نوێترین'),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          tr(_formatFullDate(createdAt)),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        newPrice.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('د.ع'),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (oldPrice != null && oldPrice != newPrice)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.08),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(changeIcon, color: changeColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    tr('گۆڕانکاری:'),
                    style: TextStyle(
                      fontSize: 11,
                      color: changeColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${oldPrice.toStringAsFixed(0)} → ${newPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: changeColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${isIncrease ? '+' : '-'}${(newPrice - oldPrice).abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1421)
                  : const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
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
                  tr(updatedBy),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '• $notes',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ═══════════════════════════════════════════════════════════
  // 📝 ناونیشانی بەش — ✅ چاککراو
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          tr(title),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataForRange(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 50,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            tr('هیچ گۆڕانکارییەک نییە لەم ماوەیەدا'),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            tr('هیچ مێژوویەک نییە'),
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  String _formatFullDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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