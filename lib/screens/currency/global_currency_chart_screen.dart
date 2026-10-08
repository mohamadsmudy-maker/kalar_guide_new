import 'package:flutter/material.dart';
import '../../services/currency_service.dart';
import '../../services/currency_pdf_service.dart';
import '../../widgets/multi_currency_chart_widget.dart';

/// 📈 شاشەی Chart ی هەموو دراوەکان
class GlobalCurrencyChartScreen extends StatefulWidget {
  const GlobalCurrencyChartScreen({super.key});

  @override
  State<GlobalCurrencyChartScreen> createState() =>
      _GlobalCurrencyChartScreenState();
}

class _GlobalCurrencyChartScreenState
    extends State<GlobalCurrencyChartScreen> {
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
      final history = await CurrencyService.getAllHistory();
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
      await CurrencyPdfService.generateMultiReport(
        context: context,
        allHistory: _allHistory,
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'Chart ی گشتی 📈',
            style: TextStyle(
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
              MultiCurrencyChartWidget(
                history: _allHistory,
                isDark: isDark,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
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
            'هیچ داتایەک نییە',
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
}