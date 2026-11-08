import 'package:flutter/material.dart';
import '../../services/currency_service.dart';
import '../../services/currency_pdf_service.dart';
import '../../widgets/currency_chart_widget.dart';
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../utils/date_picker_helper.dart';
import '../../l10n/tr.dart';
/// 📜 شاشەی مێژووی نرخی دراو
class CurrencyHistoryScreen extends StatefulWidget {
  final int stationId;
  final String stationName;
  final String? currencyType;

  const CurrencyHistoryScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    this.currencyType,
  });

  @override
  State<CurrencyHistoryScreen> createState() => _CurrencyHistoryScreenState();
}

class _CurrencyHistoryScreenState extends State<CurrencyHistoryScreen> {
  bool _loading = true;
  bool _generatingPdf = false;
  List<Map<String, dynamic>> _history = [];

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
      final history = await CurrencyService.getStationPriceHistory(
        stationId: widget.stationId,
        currencyType: widget.currencyType,
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

  Future<void> _pickDateRange() async {
    // ✅ وەرگرتنی زمانی ئێستا
    final lang = context.read<SettingsProvider>().languageId;

    final picked = await DatePickerHelper.showRangePicker(
      context: context,
      languageId: lang,
      initialFrom: _fromDate,
      initialTo: _toDate,
      primaryColor: const Color(0xFF10B981),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 PDF — ✅ چارەسەرکرا
  // ═══════════════════════════════════════════════════════════
  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final filtered = _filteredHistory;
      if (filtered.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('هیچ داتایەک نییە بۆ ڕاپۆرت')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ✅ generateSingleReport (نەک generateDateRangeReport)
      await CurrencyPdfService.generateSingleReport(
        context: context,
        currencyName: widget.currencyType != null
            ? '${widget.stationName} • ${CurrencyService.getNameKu(widget.currencyType!)}'
            : widget.stationName,
        currencyCode: widget.currencyType ?? 'mix',
        history: filtered,
      );
    } catch (e) {
      debugPrint('❌ PDF error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trf('هەڵە: {0}', [e])),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

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
                tr(widget.currencyType != null
                    ? '${widget.stationName} • ${CurrencyService.getNameKu(widget.currencyType!)}'
                    : widget.stationName),
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          actions: [
            IconButton(
              icon: _generatingPdf
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF10B981),
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
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        )
            : _history.isEmpty
            ? _buildEmptyState(isDark)
            : RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDateRangeButton(isDark),
              const SizedBox(height: 16),
              if (widget.currencyType != null &&
                  filtered.length >= 2) ...[
                CurrencyChartWidget(
                  history: filtered,
                  // ✅ currencyCode (نەک currencyType)
                  currencyCode: widget.currencyType!,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
              ],
              _buildSectionTitle(
                tr('📋 لیستی گۆڕانکارییەکان'),
                isDark,
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                _buildNoDataForRange(isDark)
              else
                ...filtered.asMap().entries.map((entry) {
                  return _buildHistoryCard(
                    entry.value,
                    entry.key == 0,
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

  Widget _buildDateRangeButton(bool isDark) {
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
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

  Widget _buildHistoryCard(
      Map<String, dynamic> item,
      bool isLatest,
      bool isDark,
      ) {
    final currencyType = item['currency_type']?.toString() ?? '';
    final oldBuy = (item['old_buy_price'] as num?)?.toDouble();
    final newBuy = (item['new_buy_price'] as num?)?.toDouble() ?? 0;
    final oldSell = (item['old_sell_price'] as num?)?.toDouble();
    final newSell = (item['new_sell_price'] as num?)?.toDouble() ?? 0;
    final updatedBy = item['updated_by_name']?.toString() ?? 'نەناسراو';
    final notes = item['notes']?.toString() ?? '';
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'].toString())
        : null;

    final color = _hexToColor(CurrencyService.getColorForType(currencyType));

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
                    Icons.attach_money_rounded,
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
                            tr(CurrencyService.getNameKu(currencyType)),
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
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                Expanded(
                  child: _buildPriceChange('کڕین', oldBuy, newBuy, isDark),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade300,
                ),
                Expanded(
                  child: _buildPriceChange('فرۆشتن', oldSell, newSell, isDark),
                ),
              ],
            ),
          ),
          if (notes.isNotEmpty || updatedBy.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
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
                          color:
                          isDark ? Colors.white70 : Colors.grey.shade700,
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

  Widget _buildPriceChange(
      String label,
      double? oldPrice,
      double newPrice,
      bool isDark,
      ) {
    final isIncrease = oldPrice != null && newPrice > oldPrice;
    final isDecrease = oldPrice != null && newPrice < oldPrice;
    final color = isIncrease
        ? const Color(0xFFEF4444)
        : isDecrease
        ? const Color(0xFF10B981)
        : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(label),
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          newPrice.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (oldPrice != null && oldPrice != newPrice) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                isIncrease
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 10,
                color: color,
              ),
              const SizedBox(width: 2),
              Text(
                '${isIncrease ? "+" : ""}${(newPrice - oldPrice).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
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
      return const Color(0xFF10B981);
    }
  }
}