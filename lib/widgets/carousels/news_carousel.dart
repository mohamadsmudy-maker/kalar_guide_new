import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';

/// 📰 Carousel ی هەواڵەکان — بە Auto-Scroll + لۆگۆی شوێن
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
  final PageController _controller = PageController(viewportFraction: 0.78);
  int _currentIndex = 0;
  Timer? _autoScrollTimer;

  // 🏢 Cache بۆ زانیاری شوێنەکان
  final Map<String, Map<String, dynamic>?> _storeCache = {};

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Auto-Scroll
  // ═══════════════════════════════════════════════════════════
  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || widget.newsList.isEmpty) return;

      final nextPage = (_currentIndex + 1) % widget.newsList.length;
      if (_controller.hasClients) {
        _controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🖼️ Helper: Extract First Image
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // 📡 Helper: هێنانی زانیاری شوێن (بە Cache)
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> _getStoreInfo(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return null;

    // پشکنینی Cache
    if (_storeCache.containsKey(storeId)) {
      return _storeCache[storeId];
    }

    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select('name, logo, image')
          .eq('id', storeId)
          .maybeSingle();

      _storeCache[storeId] = res;
      return res;
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی شوێن: $e');
      _storeCache[storeId] = null;
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.newsList.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 340, // ✅ زیادکرا لە 290
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.newsList.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double value = 1.0;
                  if (_controller.position.haveDimensions) {
                    value = _controller.page! - index;
                    value = (1 - (value.abs() * 0.25)).clamp(0.75, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 340,
                      width: Curves.easeOut.transform(value) * 320,
                      child: Transform.scale(
                        scale: Curves.easeOut.transform(value),
                        child: _buildNewsCard(
                          widget.newsList[index],
                          index,
                          isDark,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildIndicator(isDark),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 News Card — بە لۆگۆی شوێن
  // ═══════════════════════════════════════════════════════════
  Widget _buildNewsCard(Map<String, dynamic> news, int index, bool isDark) {
    final imageUrl = _extractImage(news);
    final title = news['title']?.toString() ??
        news['description']?.toString() ??
        '';
    final isImportant = index == 0;
    final views = news['views'] ?? 0;
    final likes = news['likes'] ?? 0;

    // 🏢 زانیاری شوێن لە join ەکەوە
    final storeFromJoin = news['dukan'];
    final storeId = news['store_id']?.toString();

    return GestureDetector(
      onTap: () => widget.onTap(news),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════
              // 🖼️ وێنەی گەورە
              // ═══════════════════════════════════════════════
              Expanded(
                flex: 4, // ✅ زیادکرا لە 3 بۆ 4
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // وێنەکە
                    imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark
                            ? const Color(0xFF2A2A35)
                            : AppColors.backgroundGrey,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildPlaceholder(),
                    )
                        : _buildPlaceholder(),

                    // 🌈 Gradient بۆ خوێندنەوە
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ═══════════════════════════════════════════════
                    // 🏢 لۆگۆی شوێن + ناو (PRO)
                    // ═══════════════════════════════════════════════
                    if (storeFromJoin != null || storeId != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        left: 12,
                        child: _buildStoreBadge(
                          storeFromJoin: storeFromJoin,
                          storeId: storeId,
                        ),
                      ),

                    // 🔴 Badge گرنگ
                    if (isImportant)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'گرنگ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 📊 ئامار
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Row(
                        children: [
                          _buildStatChip(
                            Icons.visibility_rounded,
                            '$views',
                          ),
                          const SizedBox(width: 6),
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

              // ═══════════════════════════════════════════════
              // 📝 ناونیشانی هەواڵ
              // ═══════════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏢 لۆگۆی شوێن (PRO)
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoreBadge({
    Map<String, dynamic>? storeFromJoin,
    String? storeId,
  }) {
    // ئەگەر زانیاری لە join هەبوو، بەکاری بهێنە
    if (storeFromJoin != null) {
      final name = storeFromJoin['name']?.toString() ?? '';
      final logo = storeFromJoin['logo']?.toString() ??
          storeFromJoin['image']?.toString() ??
          '';
      return _buildBadge(name: name, logo: logo);
    }

    // ئەگەر نەبوو، لە DB بهێنە
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
        // لۆگۆ
        if (logo.isNotEmpty)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
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
                  size: 20,
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        // ناوی شوێن
        if (name.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
          size: 48,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
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
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: _currentIndex == index ? 24 : 6,
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