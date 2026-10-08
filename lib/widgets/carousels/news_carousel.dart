import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';

/// 📰 کاروسێلی هەواڵەکان — Compact Edition (220px)
class NewsCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> newsList;
  final Function(Map<String, dynamic>) onTap;

  const NewsCarousel({
    super.key,
    required this.newsList,
    required this.onTap,
  });

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _currentIndex = 0;
  Timer? _autoScrollTimer;

  // ✅ سنووری _storeCache
  final Map<String, Map<String, dynamic>?> _storeCache = {};
  static const int _maxCacheSize = 20;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(NewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ ئەگەر newsList گۆڕا، دەستپێکردنەوە
    if (oldWidget.newsList.length != widget.newsList.length) {
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    // ✅ ئەگەر 1 یان کەمتر هەواڵ هەیە، هیچ Timer پێویست نییە
    if (widget.newsList.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || widget.newsList.isEmpty) return;
      final nextPage = (_currentIndex + 1) % widget.newsList.length;
      if (_controller.hasClients) {
        _controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  String _extractImage(Map<String, dynamic> news) {
    final raw = news['images'] ?? news['img'] ?? news['image'];
    if (raw == null) return '';
    if (raw is List) {
      if (raw.isEmpty) return '';
      return raw.first.toString().trim();
    }
    if (raw is String) {
      var s = raw.trim();
      if (s.isEmpty) return '';
      s = s.replaceAll(RegExp(r'^\[|\]$'), '');
      s = s.replaceAll('"', '').replaceAll("'", '');
      if (s.contains(',')) s = s.split(',').first;
      return s.trim();
    }
    return raw.toString().trim();
  }

  // ✅ سنووردانان بۆ _storeCache
  Future<Map<String, dynamic>?> _getStoreInfo(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return null;
    if (_storeCache.containsKey(storeId)) return _storeCache[storeId];

    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select('name, logo, image')
          .eq('id', storeId)
          .maybeSingle();

      // ✅ سنووردانان — ئەگەر زۆر بوو، کۆنترین بسڕەوە
      if (_storeCache.length >= _maxCacheSize) {
        _storeCache.remove(_storeCache.keys.first);
      }
      _storeCache[storeId] = res;
      return res;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.newsList.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // ✅ بەرزی ٢٢٠px — Compact
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.newsList.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _startAutoScroll();
            },
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double value = 1.0;
                  if (_controller.position.haveDimensions) {
                    value = _controller.page! - index;
                    value = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
                  }
                  return Center(
                    child: Transform.scale(
                      scale: Curves.easeOut.transform(value),
                      child: _buildNewsCard(
                        widget.newsList[index],
                        index,
                        isDark,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildIndicator(isDark),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> news, int index, bool isDark) {
    final imageUrl = _extractImage(news);
    final title = news['title']?.toString() ??
        news['description']?.toString() ??
        '';
    final isImportant = index == 0;
    final views = news['views'] ?? 0;
    final likes = news['likes'] ?? 0;

    final storeFromJoin = news['dukan'];
    final storeId = news['store_id']?.toString();

    return GestureDetector(
      onTap: () => widget.onTap(news),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════
              // 🖼️ وێنە — flex: 4 (کەمتر)
              // ═══════════════════════════════════════
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark
                            ? const Color(0xFF2A2A35)
                            : AppColors.backgroundGrey,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildPlaceholder(),
                    )
                        : _buildPlaceholder(),

                    // 🌈 گرادیێنت
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 🏢 لۆگۆی شوێن
                    if (storeFromJoin != null || storeId != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        left: 8,
                        child: _buildStoreBadge(
                          storeFromJoin: storeFromJoin,
                          storeId: storeId,
                        ),
                      ),

                    // 🔴 باجی گرنگ
                    if (isImportant)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'گرنگ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 📊 ئامارەکان
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Row(
                        children: [
                          _buildStatChip(
                            Icons.visibility_rounded,
                            '$views',
                          ),
                          const SizedBox(width: 4),
                          _buildStatChip(
                            Icons.thumb_up_rounded,
                            '$likes',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════
              // 📝 ناونیشان — flex: 2
              // ═══════════════════════════════════════
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
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

  Widget _buildStoreBadge({
    Map<String, dynamic>? storeFromJoin,
    String? storeId,
  }) {
    if (storeFromJoin != null) {
      final name = storeFromJoin['name']?.toString() ?? '';
      final logo = storeFromJoin['logo']?.toString() ??
          storeFromJoin['image']?.toString() ??
          '';
      return _buildBadge(name: name, logo: logo);
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getStoreInfo(storeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final store = snapshot.data;
        final name = store?['name']?.toString() ?? '';
        final logo = store?['logo']?.toString() ??
            store?['image']?.toString() ??
            '';
        if (name.isEmpty && logo.isEmpty) return const SizedBox.shrink();
        return _buildBadge(name: name, logo: logo);
      },
    );
  }

  Widget _buildBadge({required String name, required String logo}) {
    return Row(
      children: [
        if (logo.isNotEmpty)
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 14,
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 14,
                ),
              ),
            ),
          ),
        if (name.isNotEmpty) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
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
        ],
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.newspaper_rounded,
          color: AppColors.primary,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.newsList.length,
            (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 5,
          width: _currentIndex == index ? 22 : 5,
          decoration: BoxDecoration(
            color: _currentIndex == index
                ? AppColors.primary
                : (isDark ? Colors.white24 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}