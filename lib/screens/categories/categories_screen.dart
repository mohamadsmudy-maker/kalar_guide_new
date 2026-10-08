import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'category_details.dart';

/// 🗂️ شاشەی بەشە سەرەکییەکان — ULTRA PRO EDITION
class CategoriesScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const CategoriesScreen({super.key, this.onMenuTap});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // ✨ Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ✅ Future وەک State Variable
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _categoriesFuture = _fetchCategories();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی بەشەکان
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('main_categories')
          .select()
          .order('name');

      final rawList = List<Map<String, dynamic>>.from(res);
      return _deduplicate(rawList);
    } catch (e) {
      debugPrint('❌ Categories error: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _deduplicate(
      List<Map<String, dynamic>> rawList) {
    return rawList
        .fold<Map<String, Map<String, dynamic>>>({}, (map, item) {
      map[item['name']] = item;
      return map;
    }).values.toList();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _categoriesFuture = _fetchCategories();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════════════
            // 🎨 هێدەری پریمیۆم
            // ═══════════════════════════════════════════════
            _buildPremiumAppBar(isDark),

            // ═══════════════════════════════════════════════
            // 🔍 گەڕان
            // ═══════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSearchBar(isDark),
              ),
            ),

            // ═══════════════════════════════════════════════
            // 📋 لیستی بەشەکان
            // ═══════════════════════════════════════════════
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                final mainCats = snapshot.data ?? [];
                final filteredCats = mainCats.where((cat) {
                  final name = (cat['name'] ?? '').toString().toLowerCase();
                  return _searchQuery.isEmpty ||
                      name.contains(_searchQuery);
                }).toList();

                if (filteredCats.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(isDark),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildCategoryCard(
                          filteredCats[index],
                          isDark,
                          index,
                        ),
                      ),
                      childCount: filteredCats.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 هێدەری پریمیۆم
  // ═══════════════════════════════════════════════════════════
  Widget _buildPremiumAppBar(bool isDark) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 160,
      backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: widget.onMenuTap != null
          ? IconButton(
        icon: Icon(
          Icons.menu_rounded,
          color: isDark ? Colors.white : AppColors.primary,
        ),
        onPressed: widget.onMenuTap,
      )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                const Color(0xFF1A1A22),
                const Color(0xFF252530),
              ]
                  : [
                Colors.white,
                AppColors.primary.withValues(alpha: 0.06),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          Color.lerp(AppColors.primary, Colors.white, 0.2)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                          AppColors.primary.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'بەشە سەرەکییەکان',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'هەموو بەشەکانی شاری کەلار',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
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

  // ═══════════════════════════════════════════════════════════
  // 🔍 بارێکی گەڕانی پریمیۆم
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(
                    () => _searchQuery = val.trim().toLowerCase(),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'گەڕان بەدوای بەشەکان...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی بەش — ULTRA PRO
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoryCard(
      Map<String, dynamic> cat,
      bool isDark,
      int index,
      ) {
    final String catName = cat['name'] ?? '';
    final String? catImage = cat['image'];
    final hasImage = catImage != null &&
        catImage.isNotEmpty &&
        catImage.startsWith('http');

    // ڕەنگی جیاواز بۆ هەر بەشێک
    final colors = [
      const Color(0xFF1E88E5),
      const Color(0xFFE91E63),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
    ];
    final catColor = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CategoryDetailsScreen(categoryName: catName),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: catColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.3 : 0.04,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: catColor.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // 🖼️ وێنە
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          catColor.withValues(alpha: 0.2),
                          catColor.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: catColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: catColor.withValues(alpha: 0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                          spreadRadius: -3,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? OptimizedNetworkImage(
                        imageUrl: catImage,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      )
                          : Icon(
                        _getCategoryIcon(catName),
                        color: catColor,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 📝 ناو و وەسف
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          catName,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: catColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.storefront_rounded,
                                    size: 11,
                                    color: catColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'بینینی گشت',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: catColor,
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

                  // ➡️ Arrow
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          catColor.withValues(alpha: 0.15),
                          catColor.withValues(alpha: 0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: catColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: catColor,
                      size: 20,
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

  // ═══════════════════════════════════════════════════════════
  // 📭 حاڵەتی بەتاڵ
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: const Icon(
                Icons.category_outlined,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isEmpty
                  ? 'هیچ بەشێک نییە'
                  : 'هیچ بەشێک نەدۆزرایەوە',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'بەشی نوێ دەتوانرێت زیاد بکرێت لە پانێڵی ئەدمین'
                  : 'گەڕانەکەت هیچ ئەنجامێکی نەبوو',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Helpers
  // ═══════════════════════════════════════════════════════════
  IconData _getCategoryIcon(String name) {
    final n = name.trim();
    if (n.contains('تەندروستی') || n.contains('نەخۆشخانە')) {
      return Icons.local_hospital_rounded;
    }
    if (n.contains('پەروەردە') || n.contains('قوتابخانە')) {
      return Icons.school_rounded;
    }
    if (n.contains('بەڕێوەبەرایەتی') || n.contains('شارەوانی')) {
      return Icons.account_balance_rounded;
    }
    if (n.contains('خوێندنی باڵا') || n.contains('زانکۆ')) {
      return Icons.school_rounded;
    }
    if (n.contains('خواردن') || n.contains('شیرینی')) {
      return Icons.restaurant_rounded;
    }
    if (n.contains('بازاڕ') || n.contains('شوێن')) {
      return Icons.shopping_bag_rounded;
    }
    if (n.contains('سەرۆکایەتی') || n.contains('قایمقامیەت')) {
      return Icons.business_rounded;
    }
    if (n.contains('بەنزینخانە') || n.contains('سووتەمەنی')) {
      return Icons.local_gas_station_rounded;
    }
    if (n.contains('ئاینی') || n.contains('مزگەوت')) {
      return Icons.mosque_rounded;
    }
    return Icons.category_rounded;
  }
}