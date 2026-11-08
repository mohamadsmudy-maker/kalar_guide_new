import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_colors.dart';
import '../../models/neighborhood.dart';
import 'neighborhood_details_screen.dart';
import '../../l10n/tr.dart';

/// 🏘️ شاشەی گەڕەکان — ULTRA PRO MAX V2
class NeighborhoodsScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const NeighborhoodsScreen({super.key, this.onMenuTap});

  @override
  State<NeighborhoodsScreen> createState() => _NeighborhoodsScreenState();
}

class _NeighborhoodsScreenState extends State<NeighborhoodsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _neighborhoods = [];
  List<Map<String, dynamic>> _filteredNeighborhoods = [];
  bool _isLoading = true;
  String? _errorMessage;

  double _totalArea = 0;
  int _totalStores = 0;

  @override
  void initState() {
    super.initState();
    _fetchNeighborhoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 Fetch
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchNeighborhoods() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _supabase
          .from('neighborhoods')
          .select()
          .order('name_ku', ascending: true);

      final data = List<Map<String, dynamic>>.from(response as List);

      double areaSum = 0;
      int storesSum = 0;
      for (var item in data) {
        areaSum +=
            double.tryParse(item['area_km2']?.toString() ?? '0') ?? 0;
        storesSum +=
            int.tryParse(item['total_stores']?.toString() ?? '0') ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _neighborhoods = data;
        _filteredNeighborhoods = _neighborhoods;
        _totalArea = areaSum;
        _totalStores = storesSum;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Fetch error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'هەڵە لە هێنانی داتا';
      });
      _showSnack(tr('هەڵە لە هێنانی داتا'), isError: true);
    }
  }

  void _filterNeighborhoods(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredNeighborhoods = _neighborhoods;
      } else {
        final q = query.toLowerCase();
        _filteredNeighborhoods = _neighborhoods.where((n) {
          final name = n['name_ku']?.toString().toLowerCase() ?? '';
          return name.contains(q);
        }).toList();
      }
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(message),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: isError ? AppColors.red : AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Card Colors
  // ═══════════════════════════════════════════════════════════
  static const List<Color> _cardColors = [
    AppColors.primary,
    AppColors.pink,
    AppColors.orange,
    AppColors.green,
    AppColors.purple,
  ];

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
    isDark ? AppColors.darkBackground : AppColors.background;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _fetchNeighborhoods,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(isDark),
              _buildStatsCard(isDark),
              _buildSearchBar(isDark),
              _buildListSliver(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.green,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(
          bottom: 20,
          left: 16,
          right: 16,
        ),
        title: Text(
          tr('گەڕەکانی کەلار'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 22,
            shadows: [
              Shadow(
                color: Colors.black45,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.green, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -10,
                child: Icon(
                  Icons.location_city_rounded,
                  size: 180,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_city_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          trf('{0} گەڕەک', [_neighborhoods.length]),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
  // 📊 Stats Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsCard(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                Icons.landscape_rounded,
                _totalArea.toStringAsFixed(1),
                'کم²',
                AppColors.orange,
                isDark,
              ),
              _buildVerticalDivider(isDark),
              _buildStatItem(
                Icons.storefront_rounded,
                '$_totalStores',
                'شوێن',
                AppColors.green,
                isDark,
              ),
              _buildVerticalDivider(isDark),
              _buildStatItem(
                Icons.location_city_rounded,
                '${_neighborhoods.length}',
                'گەڕەک',
                AppColors.primary,
                isDark,
              ),
            ],
          ),
        ),
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
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          tr(value),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tr(label),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      height: 40,
      width: 1,
      color: isDark ? Colors.white12 : AppColors.divider,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _filterNeighborhoods,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: tr('گەڕان بۆ گەڕەک...'),
              hintStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
                onPressed: () {
                  _searchController.clear();
                  _filterNeighborhoods('');
                },
              )
                  : null,
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 List Sliver
  // ═══════════════════════════════════════════════════════════
  Widget _buildListSliver(bool isDark) {
    if (_isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) => _buildShimmerCard(isDark),
          childCount: 6,
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 60,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  tr(_errorMessage!),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _fetchNeighborhoods,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('دووبارە هەوڵبدەرەوە')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_filteredNeighborhoods.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 60,
                color: isDark
                    ? Colors.white54
                    : AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                tr('هیچ گەڕەکێک نەدۆزرایەوە'),
                style: TextStyle(
                  color: isDark
                      ? Colors.white70
                      : AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final neighborhood = _filteredNeighborhoods[index];
            final color = _cardColors[index % _cardColors.length];
            return _buildNeighborhoodCard(neighborhood, color, isDark);
          },
          childCount: _filteredNeighborhoods.length,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Neighborhood Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildNeighborhoodCard(
      Map<String, dynamic> neighborhood,
      Color color,
      bool isDark,
      ) {
    final name = neighborhood['name_ku']?.toString() ?? 'بێ ناو';
    final areaDouble =
        double.tryParse(neighborhood['area_km2']?.toString() ?? '0') ??
            0;
    final areaStr = areaDouble.toStringAsFixed(2);
    final stores = neighborhood['total_stores']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NeighborhoodDetailsScreen(
                neighborhood: Neighborhood.fromJson(neighborhood),
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.1 : 0.08),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: color.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(name),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                trf('{0} شوێن', [stores]),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.landscape_rounded,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                trf('{0} کم²', [areaStr]),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.location_city_rounded,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Shimmer
  // ═══════════════════════════════════════════════════════════
  Widget _buildShimmerCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Shimmer.fromColors(
        baseColor: isDark ? AppColors.darkBorder : Colors.grey.shade300,
        highlightColor:
        isDark ? AppColors.darkCard : Colors.grey.shade100,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }
}