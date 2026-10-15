// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ═══════════════════════════════════════════════════════════
// 📦 Imports — پاککراوە لە دووبارە
// ═══════════════════════════════════════════════════════════
import 'package:kalar_guide_new/config/app_colors.dart';
import 'package:kalar_guide_new/config/settings_provider.dart';
import 'package:kalar_guide_new/config/translations.dart';
import 'package:kalar_guide_new/providers/news_providers.dart';
import 'package:kalar_guide_new/services/analytics_service.dart';
import 'package:kalar_guide_new/widgets/common/optimized_network_image.dart';
import 'package:kalar_guide_new/widgets/carousels/news_carousel.dart';
import 'package:kalar_guide_new/screens/complaints/complaint_instruction_dialog.dart';
import 'package:kalar_guide_new/screens/emergency/emergency_main_screen.dart';
import 'package:kalar_guide_new/screens/events/events_screen.dart';
import 'package:kalar_guide_new/screens/neighborhoods/neighborhoods_screen.dart';
import 'package:kalar_guide_new/screens/map_screen.dart'; // ⭐ نەخشە
import 'package:kalar_guide_new/screens/news/news_details.dart';
import 'package:kalar_guide_new/screens/news/all_news_screen.dart';

/// 🏠 شاشەی سەرەکی
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMenuTap;

  const HomeScreen({super.key, this.onMenuTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  final Map<String, bool> _imageCacheStatus = {};

  static const Map<String, String> _categoryTranslationMap = {
    'تەندروستی': 'cat_health',
    'پەروەردە': 'cat_education',
    'خوێندنی باڵا': 'cat_higher_ed',
    'بەڕێوەبەرایەتی': 'cat_government',
    'خواردن': 'cat_food',
    'بازاڕگەری': 'cat_shopping',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategories();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🖼️ Precaching
  // ═══════════════════════════════════════════════════════════
  Future<void> _precacheImages() async {
    try {
      final newsState = ref.read(newsProvider);
      if (!mounted) return;

      for (final item in newsState.news.take(3)) {
        if (!mounted) return;
        final img = item.primaryImage ?? '';
        if (img.isNotEmpty && !_imageCacheStatus.containsKey(img)) {
          try {
            await precacheImage(
              CachedNetworkImageProvider(img),
              context,
            );
            _imageCacheStatus[img] = true;
          } catch (e) {
            _imageCacheStatus[img] = false;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ _precacheImages error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Refresh
  // ═══════════════════════════════════════════════════════════
  Future<void> _onRefresh() async {
    await ref.read(newsProvider.notifier).refresh();
    if (mounted) {
      setState(() {
        _categoriesFuture = _fetchCategories();
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settings = context.watch<SettingsProvider>();
    final lang = settings.languageId;

    final newsState = ref.watch(newsProvider);

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════
            // 🎨 Header
            // ═══════════════════════════════════════
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor:
              isDark ? const Color(0xFF1A1A22) : Colors.white,
              elevation: 0,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(
                    Icons.menu_rounded,
                    color: isDark ? Colors.white : AppColors.primary,
                  ),
                  onPressed: () {
                    if (widget.onMenuTap != null) {
                      widget.onMenuTap!();
                    } else {
                      Scaffold.of(ctx).openDrawer();
                    }
                  },
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.newsGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.explore_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.t('app_name', lang) == 'app_name'
                        ? 'ڕێبەری کەلار'
                        : AppTranslations.t('app_name', lang),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white : AppColors.primary,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/search');
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),

            // ═══════════════════════════════════════
            // 📰 News Carousel
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: newsState.news.isEmpty
                    ? const SizedBox.shrink()
                    : NewsCarousel(
                  newsList: newsState.news
                      .take(5)
                      .map((n) => n.toJson())
                      .toList(),
                  onTap: (news) => _openNewsDetails(news),
                ),
              ),
            ),

            // ═══════════════════════════════════════
            // 🆘 دوگمەی فریاکەوتن
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: _buildEmergencyButton(),
              ),
            ),

            // ═══════════════════════════════════════
            // 📅 دوگمەی ڕووداوەکان
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildEventsButton(),
              ),
            ),

            // ═══════════════════════════════════════
            // 🏘️ دوگمەی گەڕەکەکان (لیست)
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildNeighborhoodsButton(),
              ),
            ),

            // ═══════════════════════════════════════
            // 🗺️ دوگمەی نەخشەی گەڕەکان (نوێ) ⭐
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildMapButton(),
              ),
            ),

            // ═══════════════════════════════════════
            // 📢 دوگمەی سکاڵا
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildComplaintButton(lang),
              ),
            ),

            // ═══════════════════════════════════════
            // 🗂️ Categories
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: _buildSectionHeader(
                  title: 'بەشە سەرەکییەکان',
                  icon: Icons.grid_view_rounded,
                  iconColor: AppColors.primary,
                  isDark: isDark,
                  onMoreTap: () {
                    Navigator.pushNamed(context, '/category');
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildCategoriesSection(isDark, lang),
            ),

            // ═══════════════════════════════════════
            // 📰 News List
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: _buildSectionHeader(
                  title: 'هەواڵەکانی تر',
                  icon: Icons.newspaper_rounded,
                  iconColor: Colors.blue,
                  isDark: isDark,
                  onMoreTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllNewsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildNewsListSliver(isDark, lang),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🆘 دوگمەی فریاکەوتن
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmergencyButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        AnalyticsService.logScreenView('emergency');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EmergencyScreen(),
          ),
        );
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFFF7043)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚑 ژمارەکانی فریاکەوتن',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'پۆلیس • ئاگرکوژێنەوە • ئەمبولانس',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 دوگمەی ڕووداوەکان
  // ═══════════════════════════════════════════════════════════
  Widget _buildEventsButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EventsScreen(),
          ),
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '📅 ڕووداوەکانی کەلار',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏘️ دوگمەی گەڕەکەکان (لیست)
  // ═══════════════════════════════════════════════════════════
  Widget _buildNeighborhoodsButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NeighborhoodsScreen(),
          ),
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E88E5), Color(0xFF00BCD4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_city_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '🏘️ گەڕەکانی کەلار',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ دوگمەی نەخشەی گەڕەکان (نوێ) ⭐
  // ═══════════════════════════════════════════════════════════
  Widget _buildMapButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MapScreen(),
          ),
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF00BCD4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.map_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '🗺️ نەخشەی گەڕەکان',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📢 دوگمەی سکاڵا
  // ═══════════════════════════════════════════════════════════
  Widget _buildComplaintButton(String lang) {
    return GestureDetector(
      onTap: () => ComplaintInstructionDialog.show(context),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFE91E63)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ناردنی سکاڵا',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Section Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    VoidCallback? onMoreTap,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                iconColor.withValues(alpha: 0.15),
                iconColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (onMoreTap != null)
          GestureDetector(
            onTap: onMoreTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'بینینی هەموو',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 10,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗂️ بەشەکان
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoriesSection(bool isDark, String lang) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardSize = (screenWidth * 0.19).clamp(64.0, 80.0);
    final sectionHeight = (screenWidth * 0.31).clamp(105.0, 130.0);

    return SizedBox(
      height: sectionHeight,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildCategoriesShimmer(isDark, cardSize);
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "هیچ بەشێک نییە",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final uniqueMap = <String, Map<String, dynamic>>{};
          for (var cat in snapshot.data!) {
            uniqueMap[cat['name']] = cat;
          }
          final mainCats = uniqueMap.values.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mainCats.length,
            itemBuilder: (context, index) {
              final cat = mainCats[index];
              final catName = cat['name']?.toString() ?? '';
              final catImage = cat['image']?.toString();
              final catColor = _getCategoryColor(catName);
              final displayName = _translateCategory(catName, lang);

              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: _buildCategoryItem(
                  catName: catName,
                  catImage: catImage,
                  catColor: catColor,
                  displayName: displayName,
                  isDark: isDark,
                  cardSize: cardSize,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryItem({
    required String catName,
    required String? catImage,
    required Color catColor,
    required String displayName,
    required bool isDark,
    required double cardSize,
  }) {
    final hasValidImage = catImage != null &&
        catImage.isNotEmpty &&
        catImage.startsWith('http');

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/category',
          arguments: catName,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cardSize,
            height: cardSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  catColor.withValues(alpha: isDark ? 0.25 : 0.15),
                  catColor.withValues(alpha: isDark ? 0.10 : 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: catColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: catColor.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: hasValidImage
                  ? OptimizedNetworkImage(
                imageUrl: catImage,
                width: cardSize,
                height: cardSize,
                fit: BoxFit.cover,
              )
                  : Icon(
                _getCategoryIcon(catName),
                color: catColor,
                size: cardSize * 0.42,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: cardSize + 12,
            child: Text(
              displayName,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: isDark ? Colors.white : AppColors.textPrimary,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesShimmer(bool isDark, double cardSize) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: cardSize,
                height: cardSize,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A22)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: cardSize * 0.75,
                height: 11,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A22)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📰 لیستی هەواڵ
  // ═══════════════════════════════════════════════════════════
  Widget _buildNewsListSliver(bool isDark, String lang) {
    final newsState = ref.watch(newsProvider);

    if (newsState.isLoading && newsState.news.isEmpty) {
      return SliverToBoxAdapter(child: _buildNewsShimmer(isDark));
    }

    if (newsState.news.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyNews(isDark));
    }

    final allNews = newsState.news;

    List<dynamic> displayList;
    if (allNews.length <= 5) {
      displayList = allNews;
    } else {
      displayList = allNews.skip(5).take(5).toList();
      if (displayList.isEmpty) {
        displayList = allNews.take(5).toList();
      }
    }

    if (displayList.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyNews(isDark));
    }

    final hasMore = allNews.length > displayList.length;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == displayList.length) {
            if (!hasMore) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildViewAllNewsButton(isDark, lang),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildNewsListItem(
              displayList[index],
              isDark,
              lang,
            ),
          );
        },
        childCount: displayList.length + (hasMore ? 1 : 0),
      ),
    );
  }

  Widget _buildViewAllNewsButton(bool isDark, String lang) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AllNewsScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.newspaper_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            SizedBox(width: 10),
            Text(
              'بینینی هەموو هەواڵەکان',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsShimmer(bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 90,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2A35)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A35)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A35)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyNews(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A1A22)
                    : AppColors.backgroundGrey,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.article_outlined,
                size: 40,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "هیچ هەواڵێکی تر نییە",
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 Data Fetching
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('main_categories')
          .select('id, name, image')
          .order('name');

      return List<Map<String, dynamic>>.from(res as List);
    } on PostgrestException catch (e) {
      debugPrint('❌ Postgrest error fetching categories: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('❌ Unexpected error fetching categories: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📰 کارتی هەواڵ
  // ═══════════════════════════════════════════════════════════
  Widget _buildNewsListItem(
      dynamic news,
      bool isDark,
      String lang,
      ) {
    final Map<String, dynamic> newsMap;

    if (news is Map<String, dynamic>) {
      newsMap = news;
    } else {
      try {
        newsMap = news.toJson();
      } catch (e) {
        debugPrint('⚠️ _buildNewsListItem conversion error: $e');
        return const SizedBox.shrink();
      }
    }

    final firstImg = _extractFirstImage(
      newsMap['images'] ?? newsMap['img'],
    );
    final title = newsMap['title']?.toString() ?? '';
    final views = (newsMap['views'] as num?)?.toInt() ?? 0;
    final likes = (newsMap['likes'] as num?)?.toInt() ?? 0;
    final timeAgo = _getTimeAgo(newsMap['created_at']?.toString());

    final store = newsMap['dukan'];
    final storeName = store?['name']?.toString() ?? '';
    final storeLogo = store?['logo']?.toString() ??
        store?['image']?.toString() ??
        '';

    return GestureDetector(
      onTap: () => _openNewsDetails(newsMap),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: firstImg.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: firstImg,
                    width: 100,
                    height: 90,
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    placeholder: (_, __) => Container(
                      width: 100,
                      height: 90,
                      color: isDark
                          ? const Color(0xFF2A2A35)
                          : Colors.grey.shade200,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 100,
                      height: 90,
                      color: isDark
                          ? const Color(0xFF2A2A35)
                          : Colors.grey.shade200,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : Container(
                    width: 100,
                    height: 90,
                    color: isDark
                        ? const Color(0xFF2A2A35)
                        : AppColors.backgroundGrey,
                    child: const Icon(
                      Icons.image,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                if (storeLogo.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: storeLogo,
                          fit: BoxFit.cover,
                          memCacheWidth: 100,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (storeName.isNotEmpty) ...[
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.storefront_rounded,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      storeName,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildStatItem(
                          icon: Icons.visibility_rounded,
                          value: _toLocalDigits('$views'),
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        _buildStatItem(
                          icon: Icons.thumb_up_rounded,
                          value: _toLocalDigits('$likes'),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔧 Helpers
  // ═══════════════════════════════════════════════════════════
  Future<void> _openNewsDetails(Map<String, dynamic> news) async {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailsScreen(newsItem: news),
      ),
    );
  }

  String _toLocalDigits(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < en.length; i++) {
      input = input.replaceAll(en[i], ar[i]);
    }
    return input;
  }

  String _extractFirstImage(dynamic rawImages) {
    if (rawImages == null) return '';
    if (rawImages is List) {
      if (rawImages.isEmpty) return '';
      return rawImages.first.toString().trim();
    }
    if (rawImages is String) {
      var s = rawImages.trim();
      if (s.isEmpty) return '';
      s = s.replaceAll(RegExp(r'^\[|\]$'), '');
      s = s.replaceAll('"', '').replaceAll("'", '');
      if (s.contains(',')) s = s.split(',').first;
      return s.trim();
    }
    return rawImages.toString().trim();
  }

  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return 'کەمێک پێش ئێستا';
    }
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final diff = DateTime.now().difference(dateTime);

      if (diff.inSeconds < 60) return 'چەند چرکەیەک پێش ئێستا';
      if (diff.inMinutes < 60) {
        return '${_toLocalDigits('${diff.inMinutes}')} دەقیقە لەمەوبەر';
      }
      if (diff.inHours < 24) {
        return '${_toLocalDigits('${diff.inHours}')} سەعات لەمەوبەر';
      }
      if (diff.inDays < 30) {
        return '${_toLocalDigits('${diff.inDays}')} ڕۆژ لەمەوبەر';
      }
      return '${_toLocalDigits('${(diff.inDays / 30).floor()}')} مانگ لەمەوبەر';
    } catch (_) {
      return dateTimeStr.length > 10
          ? dateTimeStr.substring(0, 10)
          : dateTimeStr;
    }
  }

  String _translateCategory(String name, String lang) {
    final key = _categoryTranslationMap[name];
    if (key == null) return name;
    final translated = AppTranslations.t(key, lang);
    return translated == key ? name : translated;
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
    return Icons.category_rounded;
  }

  Color _getCategoryColor(String name) {
    final n = name.trim();
    if (n.contains('تەندروستی') || n.contains('نەخۆشخانە')) {
      return AppColors.catHealth;
    }
    if (n.contains('پەروەردە') || n.contains('قوتابخانە')) {
      return AppColors.catEducation;
    }
    if (n.contains('بەڕێوەبەرایەتی') || n.contains('شارەوانی')) {
      return AppColors.catGovernment;
    }
    if (n.contains('خوێندنی باڵا') || n.contains('زانکۆ')) {
      return AppColors.catHigherEd;
    }
    if (n.contains('خواردن') || n.contains('شیرینی')) {
      return AppColors.catFood;
    }
    if (n.contains('بازاڕ') || n.contains('شوێن')) {
      return AppColors.catShopping;
    }
    return AppColors.primary;
  }
}