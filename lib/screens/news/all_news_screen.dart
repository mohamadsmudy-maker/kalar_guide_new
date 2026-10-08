import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/news_service.dart';
import '../../utils/pagination_helper.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'news_details.dart';

class AllNewsScreen extends StatefulWidget {
  const AllNewsScreen({super.key});

  @override
  State<AllNewsScreen> createState() => _AllNewsScreenState();
}

class _AllNewsScreenState extends State<AllNewsScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  final _pagination = PaginationHelper<Map<String, dynamic>>(pageSize: 20);

  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 هێنانی داتا
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    _pagination.reset();

    await _pagination.loadFirstPage((from, to) =>
    _searchQuery.isEmpty
        ? NewsService.getNews(from: from, to: to)
        : NewsService.searchNews(
        query: _searchQuery, from: from, to: to),
    );

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_pagination.isLoadingMore || !_pagination.hasMore) return;

    setState(() {});

    await _pagination.loadMore((from, to) =>
    _searchQuery.isEmpty
        ? NewsService.getNews(from: from, to: to)
        : NewsService.searchNews(
        query: _searchQuery, from: from, to: to),
    );

    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Scroll Listener
  // ═══════════════════════════════════════════════════════════
  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newsList = _pagination.items;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text(
            'هەموو هەواڵەکان',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: Column(
          children: [
            // 🔍 گەڕان
            _buildSearchBar(isDark),

            // 📋 لیست
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
                  : newsList.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadInitial,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: newsList.length +
                      (_pagination.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // ⏳ Loading Indicator لە کۆتایی
                    if (index == newsList.length) {
                      return _buildLoadingMore();
                    }

                    final news = newsList[index];
                    return _buildNewsCard(news, isDark);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Widgets
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (val) {
            _searchQuery = val.trim().toLowerCase();
            // ✅ Debounce ی سادە
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchQuery == val.trim().toLowerCase()) {
                _loadInitial();
              }
            });
          },
          decoration: InputDecoration(
            hintText: 'گەڕان بەدوای هەواڵەکان...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                _searchCtrl.clear();
                _searchQuery = '';
                _loadInitial();
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

  // ⏳ Loading Indicator
  Widget _buildLoadingMore() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  // 📭 بەتاڵ
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 60,
            color: isDark ? Colors.white24 : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            'هیچ هەواڵێک نەدۆزرایەوە',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 🎴 کارتی هەواڵ
  Widget _buildNewsCard(Map<String, dynamic> news, bool isDark) {
    final firstImg = _extractFirstImage(news['images']);
    final store = news['dukan'];
    final storeName = store?['name']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailsScreen(newsItem: news),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
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
                    news['title'] ?? '',
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
                  if (storeName.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            storeName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ],
        ),
      ),
    );
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
}