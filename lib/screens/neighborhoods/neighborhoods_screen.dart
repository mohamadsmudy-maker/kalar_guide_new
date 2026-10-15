import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';
import '../../services/neighborhood_service.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/neighborhoods/neighborhood_card.dart';
import 'neighborhood_details_screen.dart';

/// 🏘️ شاشەی گەڕەکەکانی کەلار — ULTRA PRO
class NeighborhoodsScreen extends StatefulWidget {
  const NeighborhoodsScreen({super.key});

  @override
  State<NeighborhoodsScreen> createState() => _NeighborhoodsScreenState();
}

class _NeighborhoodsScreenState extends State<NeighborhoodsScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  List<Neighborhood> _neighborhoods = [];
  List<Neighborhood> _filtered = [];
  Map<String, dynamic> _stats = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

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
    _loadData();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      NeighborhoodService.getAll(),
      NeighborhoodService.getStats(),
    ]);

    if (mounted) {
      setState(() {
        _neighborhoods = results[0] as List<Neighborhood>;
        _filtered = _neighborhoods;
        _stats = results[1] as Map<String, dynamic>;
        _loading = false;
      });
      _entryController.forward(from: 0);
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
      if (_searchQuery.isEmpty) {
        _filtered = _neighborhoods;
      } else {
        _filtered = _neighborhoods.where((n) {
          return n.nameKu.toLowerCase().contains(_searchQuery) ||
              (n.nameAr?.toLowerCase().contains(_searchQuery) ?? false) ||
              (n.nameEn?.toLowerCase().contains(_searchQuery) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark, lang),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildStatsCard(isDark, lang),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _buildSearchBar(isDark, lang),
              ),
            ),
            _loading
                ? const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1E88E5),
                ),
              ),
            )
                : _filtered.isEmpty
                ? SliverFillRemaining(
              child: _buildEmptyState(isDark, lang),
            )
                : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) => AnimatedBuilder(
                    animation: _entryAnimation,
                    builder: (context, child) {
                      final delay = (i * 0.06).clamp(0.0, 1.0);
                      final progress =
                      ((_entryAnimation.value - delay) / 0.5)
                          .clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - progress)),
                        child:
                        Opacity(opacity: progress, child: child),
                      );
                    },
                    child: NeighborhoodCard(
                      neighborhood: _filtered[i],
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NeighborhoodDetailsScreen(
                                  neighborhood: _filtered[i],
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                  childCount: _filtered.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, String lang) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF1E88E5),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          lang == 'en'
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E88E5),
                Color(0xFF00BCD4),
                Color(0xFF10B981),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.location_city_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AutoTranslate(
                          text: 'گەڕەکانی کەلار 🏘️',
                          lang: lang,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        AutoTranslate(
                          text: '${_neighborhoods.length} گەڕەک',
                          lang: lang,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isDark, String lang) {
    final totalStores = _stats['total_stores'] ?? 0;
    final totalArea = (_stats['total_area_km2'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E88E5).withValues(alpha: 0.15),
            const Color(0xFF10B981).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.location_city_rounded,
            value: '${_neighborhoods.length}',
            labelKey: 'گەڕەک',
            color: const Color(0xFF1E88E5),
            isDark: isDark,
            lang: lang,
          ),
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
          ),
          _buildStatItem(
            icon: Icons.storefront_rounded,
            value: '$totalStores',
            labelKey: 'شوێن',
            color: const Color(0xFF10B981),
            isDark: isDark,
            lang: lang,
          ),
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
          ),
          _buildStatItem(
            icon: Icons.landscape_rounded,
            value: totalArea.toStringAsFixed(1),
            labelKey: 'کم²',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            lang: lang,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String labelKey,
    required Color color,
    required bool isDark,
    required String lang,
  }) {
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
          AutoTranslate(
            text: labelKey,
            lang: lang,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, String lang) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? const Color(0xFF1E88E5).withValues(alpha: 0.4)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: lang == 'ar'
              ? 'ابحث عن حي...'
              : (lang == 'en'
              ? 'Search neighborhood...'
              : 'گەڕان بۆ گەڕەک...'),
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF1E88E5),
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              _searchCtrl.clear();
              _onSearch('');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_city_outlined,
              size: 60,
              color: Color(0xFF1E88E5),
            ),
          ),
          const SizedBox(height: 16),
          AutoTranslate(
            text: _searchQuery.isEmpty
                ? 'هیچ گەڕەکێک نییە'
                : 'هیچ گەڕەکێک نەدۆزرایەوە',
            lang: lang,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}