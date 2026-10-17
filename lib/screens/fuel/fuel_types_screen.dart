import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_pdf_service.dart';
import '../../widgets/multi_fuel_chart_widget.dart';
import 'fuel_stations_by_type_screen.dart';

/// 🛢️ شاشەی جۆرەکانی سووتەمەنی — ULTRA PRO V2
class FuelTypesScreen extends StatefulWidget {
  const FuelTypesScreen({super.key});

  @override
  State<FuelTypesScreen> createState() => _FuelTypesScreenState();
}

class _FuelTypesScreenState extends State<FuelTypesScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  bool _loading = true;
  bool _refreshing = false;
  bool _generatingPdf = false;
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _allStations = [];
  final Map<String, Map<String, dynamic>> _cheapest = {};
  final Map<String, Map<String, dynamic>> _mostExpensive = {};
  final Map<String, List<double>> _priceHistory = {};

  String _searchQuery = '';
  String _sortBy = 'cheapest';
  final TextEditingController _searchCtrl = TextEditingController();

  // ⭐ Animation Controllers
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _refreshController;
  late Animation<double> _entryAnimation;
  late Animation<double> _pulseAnimation;

  static const Color _primaryDark = Color(0xFF1A1B2E);
  static const Color _primaryGold = Color(0xFFFFD700);
  static const Color _primaryGoldDark = Color(0xFFFFB300);

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _loadData();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _refreshController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی داتا
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);

    try {
      // ⭐ ١. هەموو نرخەکان
      final allPrices = await FuelService.getCurrentPrices();
      debugPrint('📊 Loaded prices: ${allPrices.length}');

      // ⭐ ٢. هەرزانترین و گرانترین
      final Map<String, Map<String, dynamic>> cheapest = {};
      final Map<String, Map<String, dynamic>> mostExpensive = {};
      final Map<String, List<double>> priceHistory = {};

      for (final p in allPrices) {
        final fuelType = p['fuel_type']?.toString() ?? '';
        final price = (p['price'] as num?)?.toDouble() ?? 0;

        if (fuelType.isEmpty || price <= 0) continue;

        // ⭐ هەرزانترین
        final currentCheapest = cheapest[fuelType];
        final currentCheapestPrice =
            (currentCheapest?['price'] as num?)?.toDouble() ?? double.infinity;

        if (currentCheapest == null || price < currentCheapestPrice) {
          cheapest[fuelType] = p;
        }

        // ⭐ گرانترین
        final currentExpensive = mostExpensive[fuelType];
        final currentExpensivePrice =
            (currentExpensive?['price'] as num?)?.toDouble() ?? 0;

        if (currentExpensive == null || price > currentExpensivePrice) {
          mostExpensive[fuelType] = p;
        }

        // ⭐ تاریخ
        priceHistory.putIfAbsent(fuelType, () => []).add(price);
      }

      // ⭐ ٣. مێژوو بۆ چارت
      final history = await FuelService.getMonthlyHistory(monthsBack: 6);
      debugPrint('📊 Loaded history: ${history.length}');

      if (mounted) {
        setState(() {
          _allStations = allPrices;
          _cheapest
            ..clear()
            ..addAll(cheapest);
          _mostExpensive
            ..clear()
            ..addAll(mostExpensive);
          _priceHistory
            ..clear()
            ..addAll(priceHistory);
          _allHistory = history;
          _loading = false;
          _refreshing = false;
        });

        _entryController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('❌ FuelTypes error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Refresh
  // ═══════════════════════════════════════════════════════════
  Future<void> _onRefresh() async {
    if (mounted) setState(() => _refreshing = true);
    HapticFeedback.mediumImpact();
    _refreshController.forward(from: 0);
    await _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 PDF
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

      await FuelPdfService.generateDateRangeReport(
        context: context,
        fromDate: DateTime.now().subtract(const Duration(days: 90)),
        toDate: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e'),
            backgroundColor: Colors.red,
          ),
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

    // ⭐ Filter + Sort
    var fuelTypes = FuelService.getFuelTypesForLang(lang);

    if (_searchQuery.isNotEmpty) {
      fuelTypes = fuelTypes.where((type) {
        return type['name']!
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // ⭐ Sort
    fuelTypes = List<Map<String, String>>.from(fuelTypes);
    if (_sortBy == 'cheapest') {
      fuelTypes.sort((a, b) {
        final aPrice = (_cheapest[a['key']]?['price'] as num?)?.toDouble() ?? 999999;
        final bPrice = (_cheapest[b['key']]?['price'] as num?)?.toDouble() ?? 999999;
        return aPrice.compareTo(bPrice);
      });
    } else if (_sortBy == 'expensive') {
      fuelTypes.sort((a, b) {
        final aPrice = (_cheapest[a['key']]?['price'] as num?)?.toDouble() ?? 0;
        final bPrice = (_cheapest[b['key']]?['price'] as num?)?.toDouble() ?? 0;
        return bPrice.compareTo(aPrice);
      });
    } else if (_sortBy == 'name') {
      fuelTypes.sort((a, b) => a['name']!.compareTo(b['name']!));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        body: RefreshIndicator(
          color: _primaryGold,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ═══════════════════════════════════════
              // 🎨 AppBar
              // ═══════════════════════════════════════
              _buildAppBar(isDark),

              // ═══════════════════════════════════════
              // 🔍 Search + Sort
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      _buildSearchBar(isDark),
                      const SizedBox(height: 10),
                      _buildSortBar(isDark),
                    ],
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // 📊 ئامارەکان
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildStatsCard(isDark),
                ),
              ),

              // ═══════════════════════════════════════
              // 🎯 Actions
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildActionsRow(),
                ),
              ),

              // ═══════════════════════════════════════
              // 📈 چارت
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _allHistory.isNotEmpty
                      ? MultiFuelChartWidget(
                    history: _allHistory,
                    isDark: isDark,
                  )
                      : _buildEmptyChart(isDark),
                ),
              ),

              // ═══════════════════════════════════════
              // 📝 ناونیشانی بەش
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primaryGold, _primaryGoldDark],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'جۆرەکانی سووتەمەنی',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${fuelTypes.length} جۆر',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _primaryGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // 🎴 Cards — بە Animation
              // ═══════════════════════════════════════
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _primaryGold,
                      ),
                    ),
                  ),
                )
              else if (fuelTypes.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState(isDark))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) {
                        final card = _buildTypeCard(
                          fuelTypes[i],
                          isDark,
                          i,
                        );

                        // ⭐ Animation بۆ ٨ کارتی یەکەم
                        if (i >= 8) return card;

                        return AnimatedBuilder(
                          animation: _entryAnimation,
                          builder: (context, child) {
                            final delay = (i * 0.06).clamp(0.0, 0.5);
                            final progress =
                            ((_entryAnimation.value - delay) / 0.4)
                                .clamp(0.0, 1.0);
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - progress)),
                              child: Opacity(
                                opacity: progress,
                                child: child,
                              ),
                            );
                          },
                          child: card,
                        );
                      },
                      childCount: fuelTypes.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        IconButton(
          icon: AnimatedRotation(
            turns: _refreshController.value,
            duration: const Duration(milliseconds: 1000),
            child: const Icon(Icons.refresh_rounded),
          ),
          onPressed: _refreshing ? null : _onRefresh,
          tooltip: 'نوێکردنەوە',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryDark, Color(0xFF2D1B4E)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            children: [
              // ⭐ Animated circles
              Positioned(
                top: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _primaryGold.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _primaryGold.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // ⭐ Header Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.3,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    _primaryGold,
                                    _primaryGoldDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryGold
                                        .withValues(alpha: 0.5),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_gas_station_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'نرخی سووتەمەنی',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: _primaryGold,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'نرخی ڕاستەقینە • ٢٤/٧',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? _primaryGold.withValues(alpha: 0.5)
              : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'گەڕان بەدوای جۆری سووتەمەنی...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _primaryGold,
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔀 Sort Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSortBar(bool isDark) {
    final sorts = [
      {'key': 'cheapest', 'label': 'هەرزانترین', 'icon': Icons.arrow_downward_rounded},
      {'key': 'expensive', 'label': 'گرانترین', 'icon': Icons.arrow_upward_rounded},
      {'key': 'name', 'label': 'ناو', 'icon': Icons.sort_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sorts.map((sort) {
          final isSelected = _sortBy == sort['key'];
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _sortBy = sort['key'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: [_primaryGold, _primaryGoldDark],
                  )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark
                      ? const Color(0xFF1A1B2E)
                      : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sort['icon'] as IconData,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      sort['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsCard(bool isDark) {
    final totalTypes = _cheapest.length;
    final totalStations = _allStations.map((s) => s['station_id']).toSet().length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryGold.withValues(alpha: 0.15),
            _primaryGold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _primaryGold.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.local_gas_station_rounded,
            '$totalTypes',
            'جۆر',
            _primaryGold,
            isDark,
          ),
          Container(
            width: 1,
            height: 40,
            color: _primaryGold.withValues(alpha: 0.2),
          ),
          _buildStatItem(
            Icons.storefront_rounded,
            '$totalStations',
            'وێستگە',
            const Color(0xFF10B981),
            isDark,
          ),
          Container(
            width: 1,
            height: 40,
            color: _primaryGold.withValues(alpha: 0.2),
          ),
          _buildStatItem(
            Icons.trending_down_rounded,
            _getCheapestPrice().toStringAsFixed(0),
            'هەرزانترین',
            const Color(0xFF3B82F6),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon,
      String value,
      String label,
      Color color,
      bool isDark,
      ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  double _getCheapestPrice() {
    if (_cheapest.isEmpty) return 0;
    final prices = _cheapest.values
        .map((s) => (s['price'] as num?)?.toDouble() ?? 0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return 0;
    return prices.reduce((a, b) => a < b ? a : b);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Actions Row
  // ═══════════════════════════════════════════════════════════
  Widget _buildActionsRow() {
    return Row(
      children: [
        // 📄 PDF
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
                      : [
                    const Color(0xFFE91E63),
                    const Color(0xFFAD1457),
                  ],
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

        // 📈 Chart
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
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
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
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
                          'گۆڕانکاری هەموو جۆرەکان',
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
  // 📈 Empty Chart
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
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Icon(
                  Icons.show_chart_rounded,
                  size: 50,
                  color: isDark
                      ? Colors.white24
                      : Colors.grey.shade300,
                ),
              );
            },
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
  // 🎴 Type Card — ULTRA PRO
  // ═══════════════════════════════════════════════════════════
  Widget _buildTypeCard(
      Map<String, String> type,
      bool isDark,
      int index,
      ) {
    final key = type['key']!;
    final name = type['name']!;
    final colorStr = type['color']!;
    final color = _hexToColor(colorStr);

    final cheapest = _cheapest[key];
    final cheapestPrice = (cheapest?['price'] as num?)?.toDouble();
    final cheapestStationName = cheapest?['station_name']?.toString() ?? '';
    final cheapestAddress = cheapest?['station_address']?.toString() ?? '';

    final mostExpensive = _mostExpensive[key];
    final mostExpensivePrice =
        (mostExpensive?['price'] as num?)?.toDouble() ?? 0;

    final history = _priceHistory[key] ?? [];
    final avgPrice = history.isNotEmpty
        ? history.reduce((a, b) => a + b) / history.length
        : 0;

    // ⭐ Trend
    final trend = _calculateTrend(history);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FuelStationsByTypeScreen(fuelType: key),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
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
                    // 🎨 Icon
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
                        Icons.local_gas_station_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // 📝 Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                ),
                              ),
                              if (trend['icon'] != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: trend['color']
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        trend['icon'],
                                        size: 10,
                                        color: trend['color'],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        trend['label'],
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: trend['color'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
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
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey,
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
                                color:
                                isDark ? Colors.white38 : Colors.grey,
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
                        Text(
                          cheapestPrice != null
                              ? cheapestPrice.toStringAsFixed(0)
                              : '--',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        Text(
                          'د.ع / لیتر',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ⭐ Details Row
                if (cheapestPrice != null) ...[
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
                      _buildMiniInfo(
                        Icons.trending_down_rounded,
                        cheapestPrice.toStringAsFixed(0),
                        'هەرزانترین',
                        const Color(0xFF10B981),
                        isDark,
                      ),
                      _buildMiniInfo(
                        Icons.trending_up_rounded,
                        mostExpensivePrice.toStringAsFixed(0),
                        'گرانترین',
                        const Color(0xFFEF4444),
                        isDark,
                      ),
                      _buildMiniInfo(
                        Icons.calculate_rounded,
                        avgPrice.toStringAsFixed(0),
                        'تێکڕا',
                        const Color(0xFF3B82F6),
                        isDark,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_back_ios_rounded,
                        color: isDark ? Colors.white38 : Colors.grey,
                        size: 12,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ⭐ Shimmer
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, _) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment(
                          -1.0 + _shimmerController.value * 3,
                          -1.0,
                        ),
                        end: Alignment(
                          1.0 + _shimmerController.value * 3,
                          1.0,
                        ),
                        colors: [
                          Colors.transparent,
                          color.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(
      IconData icon,
      String value,
      String label,
      Color color,
      bool isDark,
      ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Trend Calculation
  // ═══════════════════════════════════════════════════════════
  Map<String, dynamic> _calculateTrend(List<double> history) {
    if (history.length < 2) {
      return {'icon': null, 'color': Colors.grey, 'label': ''};
    }

    final first = history.first;
    final last = history.last;
    final diff = last - first;
    final percent = first > 0 ? (diff / first) * 100 : 0.0;

    if (percent > 2) {
      return {
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFFEF4444),
        'label': '+${percent.toStringAsFixed(0)}%',
      };
    } else if (percent < -2) {
      return {
        'icon': Icons.trending_down_rounded,
        'color': const Color(0xFF10B981),
        'label': '${percent.toStringAsFixed(0)}%',
      };
    } else {
      return {
        'icon': Icons.trending_flat_rounded,
        'color': Colors.grey,
        'label': '0%',
      };
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _primaryGold.withValues(alpha: 0.2),
                        _primaryGold.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_outlined,
                    size: 60,
                    color: _primaryGold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'هیچ جۆرێک نەدۆزرایەوە',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'گەڕانەکەت هیچ ئەنجامێکی نەبوو',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
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
      return AppColors.primary;
    }
  }
}