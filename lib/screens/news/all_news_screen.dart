import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_colors.dart';
import '../../models/news.dart';
import '../../providers/news_providers.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'news_details.dart';
import '../../l10n/tr.dart';

/// 📰 شاشەی هەموو هەواڵەکان — ULTRA PRO MAX V2
class AllNewsScreen extends ConsumerStatefulWidget {
  const AllNewsScreen({super.key});

  @override
  ConsumerState<AllNewsScreen> createState() => _AllNewsScreenState();
}

class _AllNewsScreenState extends ConsumerState<AllNewsScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 300) {
        ref.read(newsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  Color _getTypeColor(String type) {
    switch (type) {
      case 'ئاگاداری':
        return AppColors.orange;
      case 'هۆشداری':
        return AppColors.red;
      case 'ڕووداو':
        return AppColors.purple;
      case 'خزمەتگوزاری':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'ئاگاداری':
        return Icons.info_rounded;
      case 'هۆشداری':
        return Icons.warning_rounded;
      case 'ڕووداو':
        return Icons.event_rounded;
      case 'خزمەتگوزاری':
        return Icons.build_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    final newsState = ref.watch(newsProvider);
    final filteredNews = _searchQuery.isEmpty
        ? newsState.news
        : newsState.news.where((n) {
      final q = _searchQuery.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          n.description.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            tr('هەموو هەواڵەکان'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildSearchBar(isDark),
            Expanded(
              child: _buildBody(newsState, filteredNews, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.border,
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: tr('گەڕان بەدوای هەواڵەکان...'),
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : AppColors.textTertiary,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
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
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Body
  // ═══════════════════════════════════════════════════════════
  Widget _buildBody(
      NewsState state,
      List<News> filteredNews,
      bool isDark,
      ) {
    if (state.isLoading && state.news.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null && state.news.isEmpty) {
      return Center(
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
              const SizedBox(height: 12),
              Text(
                tr(state.error!),
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(newsProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('دووبارە هەوڵبدە')),
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
      );
    }

    if (filteredNews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.backgroundGrey,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.article_outlined,
                  size: 60,
                  color: isDark
                      ? Colors.white54
                      : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr(_searchQuery.isEmpty
                    ? 'هیچ هەواڵێک نییە'
                    : 'هیچ هەواڵێک نەدۆزرایەوە'),
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(newsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredNews.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredNews.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            );
          }

          return _buildNewsCard(filteredNews[index], isDark);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 News Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildNewsCard(News news, bool isDark) {
    final firstImg = news.primaryImage ?? '';
    final newsType = news.newsType ?? 'هەواڵ';
    final typeColor = _getTypeColor(newsType);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(newsProvider.notifier).incrementViews(news.id ?? '');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailsScreen(newsItem: news.toDisplayMap()),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: firstImg.isNotEmpty
                  ? OptimizedNetworkImage(
                imageUrl: firstImg,
                width: 100,
                height: 90,
                fit: BoxFit.cover,
              )
                  : Container(
                width: 100,
                height: 90,
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.backgroundGrey,
                child: const Icon(
                  Icons.image,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getTypeIcon(newsType),
                                    size: 10,
                                    color: typeColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    tr(newsType),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: typeColor,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tr(news.getTimeAgo()),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textTertiary,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(news.title),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
}