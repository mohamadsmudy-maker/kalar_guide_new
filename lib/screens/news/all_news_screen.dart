import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_colors.dart';
import '../../models/news.dart';
import '../../providers/news_providers.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'news_details.dart';

/// 📰 شاشەی هەموو هەواڵەکان — Riverpod Version
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

    // ✅ Scroll Listener
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ وەرگرتنی State لە Provider
    final newsState = ref.watch(newsProvider);
    final filteredNews = _searchQuery.isEmpty
        ? newsState.news
        : newsState.news.where((n) {
      final q = _searchQuery.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          n.description.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text(
            'هەموو هەواڵەکان',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Column(
          children: [
            // 🔍 گەڕان
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(
                        () => _searchQuery = val.trim(),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'گەڕان بەدوای هەواڵەکان...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
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
            ),

            // 📋 لیست
            Expanded(
              child: _buildBody(newsState, filteredNews, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      NewsState state,
      List<News> filteredNews,
      bool isDark,
      ) {
    // Loading ی سەرەتا
    if (state.isLoading && state.news.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // هەڵە
    if (state.error != null && state.news.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 12),
            Text(state.error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(newsProvider.notifier).refresh(),
              child: const Text('دووبارە هەوڵبدە'),
            ),
          ],
        ),
      );
    }

    // بەتاڵ
    if (filteredNews.isEmpty) {
      return const Center(
        child: Text(
          'هیچ هەواڵێک نەدۆزرایەوە',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // لیست
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(newsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredNews.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredNews.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          final news = filteredNews[index];
          return _buildNewsCard(news, isDark);
        },
      ),
    );
  }

  Widget _buildNewsCard(News news, bool isDark) {
    final firstImg = news.primaryImage ?? '';

    return GestureDetector(
      onTap: () {
        ref.read(newsProvider.notifier).incrementViews(news.id ?? '');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailsScreen(newsItem: news.toJson()),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
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
                    ? const Color(0xFF2A2A35)
                    : Colors.grey.shade200,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    news.getTimeAgo(),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}