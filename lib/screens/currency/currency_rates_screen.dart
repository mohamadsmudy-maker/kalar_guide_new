import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/currency_service.dart';
import '../../services/currency_pdf_service.dart';
import '../../widgets/multi_currency_chart_widget.dart';
import 'currency_stations_by_type_screen.dart';

/// 💱 شاشەی جۆرەکانی دراو — FULL PRO EDITION
class CurrencyRatesScreen extends StatefulWidget {
  const CurrencyRatesScreen({super.key});

  @override
  State<CurrencyRatesScreen> createState() => _CurrencyRatesScreenState();
}

class _CurrencyRatesScreenState extends State<CurrencyRatesScreen> {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  bool _loading = true;
  bool _generatingPdf = false;
  List<Map<String, dynamic>> _allHistory = [];
  final Map<String, Map<String, dynamic>> _cheapest = {};

  // ✅ ڕەنگەکان
  static const Color _primaryDark = Color(0xFF1A1B2E);
  static const Color _primaryGreen = Color(0xFF10B981);
  static const Color _primaryGreenDark = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی داتا
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // ١. هەرزانترین نرخ
      final allPrices = await CurrencyService.getCurrentPrices();

      final Map<String, Map<String, dynamic>> cheapest = {};
      for (final p in allPrices) {
        final currencyType = p['currency_type']?.toString() ?? '';
        final sellPrice = (p['sell_price'] as num?)?.toDouble() ?? 0;

        if (currencyType.isEmpty || sellPrice <= 0) continue;

        final current = cheapest[currencyType];
        final currentPrice =
            (current?['sell_price'] as num?)?.toDouble() ?? double.infinity;

        if (current == null || sellPrice < currentPrice) {
          cheapest[currencyType] = p;
        }
      }

      // ٢. مێژوو بۆ چارت
      final history = await CurrencyService.getMonthlyHistory(monthsBack: 6);

      if (mounted) {
        setState(() {
          _cheapest
            ..clear()
            ..addAll(cheapest);
          _allHistory = history;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ CurrencyRates error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 ڕاپۆرتی گشتی PDF
  // ═══════════════════════════════════════════════════════════
  Future<void> _generateGlobalPdf() async {
    setState(() => _generatingPdf = true);
    try {
      if (_allHistory.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هیچ مێژوویەک نییە'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await CurrencyPdfService.generateMultiReport(
        context: context,
        allHistory: _allHistory,
      );
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    final currencyTypes = CurrencyService.getCurrencyTypesForLang(lang);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'نرخی دراوەکان',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          backgroundColor: _primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: _primaryGreen),
        )
            : RefreshIndicator(
          color: _primaryGreen,
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ═══════════════════════════════════════
              // 🎨 هێدەر
              // ═══════════════════════════════════════
              _buildHeader(),
              const SizedBox(height: 16),

              // ═══════════════════════════════════════
              // 🎯 دوو دوگمە: PDF + Chart
              // ═══════════════════════════════════════
              _buildActionsRow(),
              const SizedBox(height: 20),

              // ═══════════════════════════════════════
              // 📈 چارتی گشتی
              // ═══════════════════════════════════════
              if (_allHistory.isNotEmpty) ...[
                MultiCurrencyChartWidget(
                  history: _allHistory,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
              ] else
                _buildEmptyChart(isDark),

              // ═══════════════════════════════════════
              // 📝 ناونیشانی بەش
              // ═══════════════════════════════════════
              _buildSectionTitle('جۆرەکانی دراو', isDark),
              const SizedBox(height: 12),

              // ═══════════════════════════════════════
              // 🎴 کارتەکان
              // ═══════════════════════════════════════
              ...currencyTypes.map(
                    (type) => _buildTypeCard(type, isDark),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 هێدەر
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryDark, Color(0xFF1B3D2F)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _primaryGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryGreen, _primaryGreenDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withValues(alpha: 0.4),
                  blurRadius: 15,
                ),
              ],
            ),
            child: const Icon(
              Icons.attach_money_rounded,
              color: Color(0xFF0F1421),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'هەرزانترین نرخەکان',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'کرتە لە هەر جۆرێک بکە بۆ بینینی نوسینگەکان',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 دوو دوگمەکە — PDF + Chart
  // ═══════════════════════════════════════════════════════════
  Widget _buildActionsRow() {
    return Row(
      children: [
        // 📄 دوگمەی PDF
        Expanded(
          child: GestureDetector(
            onTap: _generatingPdf || _allHistory.isEmpty
                ? null
                : _generateGlobalPdf,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _allHistory.isEmpty
                      ? [Colors.grey.shade400, Colors.grey.shade500]
                      : [const Color(0xFFE91E63), const Color(0xFFAD1457)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _allHistory.isEmpty
                    ? null
                    : [
                  BoxShadow(
                    color: const Color(0xFFE91E63)
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _generatingPdf
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ڕاپۆرتی PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'مێژووی گشتی',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 📈 دوگمەی Chart
        Expanded(
          child: GestureDetector(
            onTap: () {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryGreen, _primaryGreenDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x33FFFFFF),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.show_chart_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'چارت ی گشتی',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'گۆڕانکاری هەموو دراوەکان',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 چارتی بەتاڵ
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyChart(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? _primaryDark : Colors.white,
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
            'هیچ داتایەک نییە بۆ چارت',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'دوای یەکەم نوێکردنەوەی نرخ، چارت لێرە دەردەکەوێت',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 ناونیشانی بەش
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryGreen, _primaryGreenDark],
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

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی جۆر
  // ═══════════════════════════════════════════════════════════
  Widget _buildTypeCard(Map<String, String> type, bool isDark) {
    final key = type['key']!;
    final name = type['name']!;
    final colorStr = type['color']!;
    final color = _hexToColor(colorStr);

    final cheapest = _cheapest[key];
    final cheapestBuy = (cheapest?['buy_price'] as num?)?.toDouble();
    final cheapestSell = (cheapest?['sell_price'] as num?)?.toDouble();
    final cheapestStationName = cheapest?['station_name']?.toString() ?? '';
    final cheapestAddress = cheapest?['station_address']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CurrencyStationsByTypeScreen(currencyType: key),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? _primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // 🎨 ئایکۆن
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.attach_money_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // 📝 ناو + زانیاری
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (cheapestStationName.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFF10B981),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cheapestStationName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (cheapestAddress.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 10,
                                color: isDark ? Colors.white38 : Colors.grey,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  cheapestAddress,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else
                        Text(
                          'هیچ نرخێک نییە',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),

                // 💰 نرخ
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cheapestBuy != null && cheapestBuy > 0)
                      Text(
                        'کڕین: ${cheapestBuy.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      cheapestSell != null
                          ? cheapestSell.toStringAsFixed(0)
                          : '--',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      'د.ع / فرۆشتن',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ✅ دوگمەی خوارەوە
            if (cheapestSell != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade200,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.arrow_upward_rounded,
                    color: Color(0xFF10B981),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'لە هەرزان بۆ گران',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: isDark ? Colors.white38 : Colors.grey,
                    size: 18,
                  ),
                ],
              ),
            ],
          ],
        ),
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
      return AppColors.primary;
    }
  }
}