import 'package:flutter/material.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_pdf_service.dart';
import '../../widgets/multi_fuel_chart_widget.dart';
import '../../l10n/tr.dart';

/// 📈 شاشەی Chart ی هەموو جۆرەکانی سووتەمەنی
class GlobalFuelChartScreen extends StatefulWidget {
  const GlobalFuelChartScreen({super.key});

  @override
  State<GlobalFuelChartScreen> createState() => _GlobalFuelChartScreenState();
}

class _GlobalFuelChartScreenState extends State<GlobalFuelChartScreen> {
  bool _loading = true;
  bool _generatingPdf = false;
  List<Map<String, dynamic>> _allHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final history = await FuelService.getMonthlyHistory(monthsBack: 6);
      if (mounted) {
        setState(() {
          _allHistory = history;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      await FuelPdfService.generateDateRangeReport(
        context: context,
        fromDate: DateTime.now().subtract(const Duration(days: 90)),
        toDate: DateTime.now(),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
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
        appBar: AppBar(
          title: Text(
            tr('چارت ی گشتی سووتەمەنی 📈'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
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
              onPressed: _generatingPdf || _allHistory.isEmpty
                  ? null
                  : _generatePdf,
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
            : _allHistory.isEmpty
            ? _buildEmptyState(isDark)
            : RefreshIndicator(
          color: const Color(0xFFFFD700),
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MultiFuelChartWidget(
                history: _allHistory,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(tr('📊 ئاماری گشتی'), isDark),
              const SizedBox(height: 12),
              _buildGlobalStats(isDark),
              const SizedBox(height: 30),
            ],
          ),
        ),
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

  Widget _buildGlobalStats(bool isDark) {
    final Map<String, int> countByType = {};

    for (final item in _allHistory) {
      final type = item['fuel_type']?.toString() ?? '';
      if (type.isEmpty) continue;
      countByType[type] = (countByType[type] ?? 0) + 1;
    }

    final sorted = countByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.map((entry) {
        final type = entry.key;
        final count = entry.value;
        final name = FuelService.getNameKu(type);
        final color = _hexToColor(FuelService.getColorForType(type));

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_gas_station_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr(name),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trf('{0} گۆڕانکاری', [count]),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            tr('هیچ داتایەک نییە'),
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