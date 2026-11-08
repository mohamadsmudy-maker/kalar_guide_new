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
import '../../utils/place_display.dart';

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

  /// ژمارەی شوێن بۆ هەر بەشێک (ناوی بەش → ژمارە)
  Map<String, int> _counts = {};
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
    _fetchCounts();
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

  Future<void> _fetchCounts() async {
    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select('category, sub_category');
      final stores = List<Map<String, dynamic>>.from(res as List);
      final cached = await _categoriesFuture;
      if (!mounted) return;
      setState(() {
        _counts = {
          for (final c in cached)
            '${c['name']}': stores
                .where((st) => PlaceDisplay.inCategory(st, '${c['name']}'))
                .length,
        };
      });
    } catch (e) {
      debugPrint('⚠️ category counts: $e');
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
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.92,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tile = _buildCategoryTile(filteredCats[index], isDark, lang);
                        if (index >= 8) return tile;
                        return AnimatedBuilder(
                          animation: _entryAnimation,
                          builder: (context, child) {
                            final progress =
                                ((_entryAnimation.value - index * 0.06) / 0.4).clamp(0.0, 1.0);
                            return Transform.scale(
                              scale: 0.9 + 0.1 * progress,
                              child: Opacity(opacity: progress, child: child),
                            );
                          },
                          child: tile,
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
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
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

  // ═══════════════════════════════════════════════════════════
  // 🧩 تایلی بەش — وێنە یان ئایکۆن، ناو، ژمارەی شوێن
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoryTile(Map<String, dynamic> cat, bool isDark, String lang) {
    final name = '${cat['name'] ?? ''}';
    final image = '${cat['image'] ?? ''}';
    final hasImage = image.startsWith('http');
    final color = PlaceDisplay.color(name);
    final count = _counts[name];

    Widget iconBubble({double size = 54}) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hasImage ? Colors.white.withValues(alpha: 0.22) : color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: hasImage ? Border.all(color: Colors.white54) : null,
          ),
          child: Icon(PlaceDisplay.icon(name), color: hasImage ? Colors.white : color, size: size * 0.5),
        );

    final fg = hasImage ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A1A2E));
    final sub = hasImage ? Colors.white70 : (isDark ? Colors.white54 : const Color(0xFF64748B));

    return Semantics(
      button: true,
      label: count == null ? name : '$name، ${trf('{0} شوێن', [count])}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CategoryDetailsScreen(categoryName: name)),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8EDF3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.045),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage) ...[
                    OptimizedNetworkImage(imageUrl: image, fit: BoxFit.cover, fallback: Container(color: color)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x14000000), Color(0xB3000000)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        iconBubble(),
                        const Spacer(),
                        AutoTranslate(
                          text: name,
                          lang: lang,
                          maxLines: 2,
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: fg, height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                count == null
                                    ? ''
                                    : count == 0
                                        ? tr('هێشتا شوێنی تێدا نییە')
                                        : trf('{0} شوێن', [PlaceDisplay.digits(count)]),
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sub),
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: hasImage ? Colors.white.withValues(alpha: 0.25) : color,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_forward_rounded,
                                size: 15,
                                color: Colors.white,
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

}