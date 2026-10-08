import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';
import '../../services/neighborhood_service.dart';
import '../../widgets/neighborhoods/neighborhood_card.dart';
import 'neighborhood_details_screen.dart';

/// 🏘️ شاشەی گەڕەکەکانی کەلار
class NeighborhoodsScreen extends StatefulWidget {
  const NeighborhoodsScreen({super.key});

  @override
  State<NeighborhoodsScreen> createState() => _NeighborhoodsScreenState();
}

class _NeighborhoodsScreenState extends State<NeighborhoodsScreen> {
  bool _loading = true;
  List<Neighborhood> _neighborhoods = [];
  List<Neighborhood> _filtered = [];
  Map<String, dynamic> _stats = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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
          slivers: [
            // ═══════════════════════════════════════
            // 🎨 هێدەر
            // ═══════════════════════════════════════
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              elevation: 0,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
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
                                    const Text(
                                      'گەڕەکانی کەلار 🏘️',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_neighborhoods.length} گەڕەک',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
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

            // ═══════════════════════════════════════
            // 📊 کارتی ئامار
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildStatsCard(isDark),
              ),
            ),

            // ═══════════════════════════════════════
            // 🔍 گەڕان
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
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
                      hintText: 'گەڕان بۆ گەڕەک...',
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
                ),
              ),
            ),

            // ═══════════════════════════════════════
            // 📋 لیستی گەڕەکەکان
            // ═══════════════════════════════════════
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1E88E5),
                  ),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(isDark))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => NeighborhoodCard(
                      neighborhood: _filtered[i],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NeighborhoodDetailsScreen(
                              neighborhood: _filtered[i],
                            ),
                          ),
                        );
                      },
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

  Widget _buildStatsCard(bool isDark) {
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
            label: 'گەڕەک',
            color: const Color(0xFF1E88E5),
            isDark: isDark,
          ),
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
          ),
          _buildStatItem(
            icon: Icons.storefront_rounded,
            value: '$totalStores',
            label: 'شوێن',
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
          ),
          _buildStatItem(
            icon: Icons.landscape_rounded,
            value: totalArea.toStringAsFixed(1),
            label: 'کم²',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
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

  Widget _buildEmptyState(bool isDark) {
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
          Text(
            _searchQuery.isEmpty
                ? 'هیچ گەڕەکێک نییە'
                : 'هیچ گەڕەکێک نەدۆزرایەوە',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}