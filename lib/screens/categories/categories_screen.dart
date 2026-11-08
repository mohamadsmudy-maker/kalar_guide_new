import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'category_details.dart';
import '../../l10n/tr.dart';

/// 🗂️ شاشەی بەشە سەرەکییەکان — ULTRA PRO V2
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

  late AnimationController _entryController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _entryAnimation;
  late Animation<double> _pulseAnimation;

  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _categoriesFuture = _fetchCategories();
    _entryController.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _entryController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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
      List<Map<String, dynamic>> rawList,
      ) {
    return rawList
        .fold<Map<String, Map<String, dynamic>>>({}, (map, item) {
      map[item['name']] = item;
      return map;
    }).values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildUltraAppBar(isDark, lang),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _buildPremiumSearchBar(isDark, lang),
              ),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverFillRemaining(
                    child: _buildLoadingSkeleton(isDark),
                  );
                }
                final mainCats = snapshot.data ?? [];
                final filteredCats = mainCats.where((cat) {
                  final name = (cat['name'] ?? '').toString().toLowerCase();
                  return _searchQuery.isEmpty || name.contains(_searchQuery);
                }).toList();

                if (filteredCats.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(isDark, lang),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final card = _buildUltraCategoryCard(
                          filteredCats[index],
                          isDark,
                          index,
                          lang,
                        );

                        // ⭐ ئەنیمەیشن تەنها بۆ ٨ کارتی یەکەم
                        if (index >= 8) return card;

                        return AnimatedBuilder(
                          animation: _entryAnimation,
                          builder: (context, child) {
                            final delay = index * 0.06;
                            final progress =
                            ((_entryAnimation.value - delay) / 0.4)
                                .clamp(0.0, 1.0);
                            return Transform.translate(
                              offset: Offset(0, 40 * (1 - progress)),
                              child: Opacity(
                                opacity: progress,
                                child: child,
                              ),
                            );
                          },
                          child: card,
                        );
                      },
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

  Widget _buildUltraAppBar(bool isDark, String lang) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 170,
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: widget.onMenuTap != null
          ? IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white : AppColors.primary,
            size: 20,
          ),
        ),
        onPressed: widget.onMenuTap,
      )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0A0A0F), const Color(0xFF161620)]
                  : [const Color(0xFFF0F4F9), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary
                                  .withValues(alpha: isDark ? 0.15 : 0.08),
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
                        const Color(0xFFE91E63)
                            .withValues(alpha: isDark ? 0.12 : 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale:
                            1.0 + (_pulseAnimation.value - 1.0) * 0.3,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1E88E5),
                                    Color(0xFF6C5CE7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E88E5)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.grid_view_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AutoTranslate(
                              text: tr('بەشە سەرەکییەکان'),
                              lang: lang,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AutoTranslate(
                                  text: tr('هەموو بەشەکانی شاری کەلار'),
                                  lang: lang,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
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

  Widget _buildPremiumSearchBar(bool isDark, String lang) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1A22), const Color(0xFF1F1F2A)]
              : [Colors.white, const Color(0xFFFAFCFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppColors.primary.withValues(alpha: 0.5)
              : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(
                    () => _searchQuery = val.trim().toLowerCase(),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: lang == 'ar'
                    ? tr('ابحث عن الأقسام...')
                    : (lang == 'en'
                    ? 'Search for categories...'
                    : 'گەڕان بەدوای بەشەکان...'),
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
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildUltraCategoryCard(
      Map<String, dynamic> cat,
      bool isDark,
      int index,
      String lang,
      ) {
    final String catName = cat['name'] ?? '';
    final String? catImage = cat['image'];
    final hasImage = catImage != null &&
        catImage.isNotEmpty &&
        catImage.startsWith('http');

    final palettes = [
      [const Color(0xFF1E88E5), const Color(0xFF42A5F5)],
      [const Color(0xFFE91E63), const Color(0xFFF06292)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      [const Color(0xFF14B8A6), const Color(0xFF2DD4BF)],
      [const Color(0xFFEF4444), const Color(0xFFF87171)],
      [const Color(0xFF6366F1), const Color(0xFF818CF8)],
    ];
    final palette = palettes[index % palettes.length];
    final primaryColor = palette[0];
    final secondaryColor = palette[1];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryDetailsScreen(categoryName: catName),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1A1A22), const Color(0xFF1F1F2A)]
                        : [Colors.white, const Color(0xFFFAFBFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                    BoxShadow(
                      color: primaryColor
                          .withValues(alpha: isDark ? 0.25 : 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildImageRing(
                        catImage: catImage,
                        hasImage: hasImage,
                        catName: catName,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AutoTranslate(
                              text: catName,
                              lang: lang,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                                letterSpacing: 0.2,
                                height: 1.2,
                              ),
                              maxLines: 1,
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
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor
                                            .withValues(alpha: 0.15),
                                        secondaryColor
                                            .withValues(alpha: 0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: primaryColor
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.storefront_rounded,
                                        size: 12,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 5),
                                      AutoTranslate(
                                        text: tr('بینینی گشت'),
                                        lang: lang,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: primaryColor,
                                          letterSpacing: 0.3,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor,
                                        secondaryColor,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor
                                            .withValues(alpha: 0.45),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    lang == 'en'
                                        ? Icons.chevron_right_rounded
                                        : Icons.chevron_left_rounded,
                                    color: Colors.white,
                                    size: 20,
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
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, _) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
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
                              primaryColor.withValues(alpha: 0.06),
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
        ),
      ),
    );
  }

  Widget _buildImageRing({
    required String? catImage,
    required bool hasImage,
    required String catName,
    required Color primaryColor,
    required Color secondaryColor,
    required bool isDark,
  }) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.25),
            secondaryColor.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: hasImage
              ? OptimizedNetworkImage(
            imageUrl: catImage!,
            width: 74,
            height: 74,
            fit: BoxFit.cover,
          )
              : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.25),
                  secondaryColor.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: Icon(
              _getCategoryIcon(catName),
              color: primaryColor,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 116,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
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
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(32),
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
              );
            },
          ),
          const SizedBox(height: 20),
          AutoTranslate(
            text: _searchQuery.isEmpty
                ? tr('هیچ بەشێک نییە')
                : tr('هیچ بەشێک نەدۆزرایەوە'),
            lang: lang,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

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