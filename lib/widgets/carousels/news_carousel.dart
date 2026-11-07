import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';

/// 📰 کاروسێلی هەواڵەکان — Full Ultra Pro Max V2
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

class _NewsCarouselState extends State<NewsCarousel>
    with WidgetsBindingObserver {
  static const Duration _autoScrollEvery = Duration(seconds: 5);
  static const int _maxStoreCache = 50;
  static const int _maxDots = 8;

  final PageController _controller = PageController(viewportFraction: 0.88);
  int _currentIndex = 0;

  Timer? _autoScrollTimer;
  bool _userDragging = false;
  bool _inForeground = true;
  bool _reduceMotion = false;

  /// storeId → store row (null = looked up, nothing found)
  final Map<String, Map<String, dynamic>?> _storeCache = {};

  // ═══════════════════════════════════════════════════════════
  // 🔁 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefetchStores();
    _scheduleNext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ♿ Moving content is a problem for some users → honour "reduce motion"
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _scheduleNext();
    }
  }

  @override
  void didUpdateWidget(NewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Compare the actual items, not just the length
    String signature(List<Map<String, dynamic>> l) =>
        l.map((n) => n['id']?.toString() ?? n['title']?.toString() ?? '').join(',');

    if (signature(oldWidget.newsList) != signature(widget.newsList)) {
      // The list may have shrunk below the page we were on
      if (_currentIndex >= widget.newsList.length) {
        _currentIndex = 0;
        if (_controller.hasClients) _controller.jumpToPage(0);
      }
      _prefetchStores();
      _scheduleNext();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (_inForeground) {
      _scheduleNext();
    } else {
      _autoScrollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ⏱ Auto scroll (one-shot, re-armed after every page change so each
  // card gets its full time; paused while the user drags)
  // ═══════════════════════════════════════════════════════════
  bool get _canAutoScroll =>
      widget.newsList.length > 1 &&
          !_userDragging &&
          _inForeground &&
          !_reduceMotion;

  void _scheduleNext() {
    _autoScrollTimer?.cancel();
    if (!_canAutoScroll) return;

    _autoScrollTimer = Timer(_autoScrollEvery, () {
      if (!mounted || !_canAutoScroll || !_controller.hasClients) return;

      // Hidden tab / covered by another screen → don't animate, check later
      if (!TickerMode.of(context)) {
        _scheduleNext();
        return;
      }

      final next = (_currentIndex + 1) % widget.newsList.length;
      _controller
          .animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .whenComplete(() {
        // onPageChanged re-arms the timer; this covers an interrupted animation
        if (mounted && (_autoScrollTimer?.isActive ?? false) == false) {
          _scheduleNext();
        }
      });
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userDragging = true;
      _autoScrollTimer?.cancel();
    } else if (n is ScrollEndNotification && _userDragging) {
      _userDragging = false;
      _scheduleNext();
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 Store badges — one batched query instead of one per card, and the
  // result is cached so scrolling never flickers
  // ═══════════════════════════════════════════════════════════
  Future<void> _prefetchStores() async {
    final ids = <String>{};
    for (final news in widget.newsList) {
      if (news['dukan'] is Map) continue; // already joined
      final id = news['store_id']?.toString() ?? '';
      if (id.isNotEmpty && !_storeCache.containsKey(id)) ids.add(id);
    }
    if (ids.isEmpty) return;

    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select('id, name, logo, image')
          .inFilter('id', ids.toList());

      final byId = <String, Map<String, dynamic>>{
        for (final r in (res as List))
          r['id'].toString(): Map<String, dynamic>.from(r as Map),
      };

      if (!mounted) return;
      setState(() {
        for (final id in ids) {
          _storeCache[id] = byId[id];
        }
        // keep the cache bounded
        while (_storeCache.length > _maxStoreCache) {
          _storeCache.remove(_storeCache.keys.first);
        }
      });
    } catch (e) {
      // Not cached on failure → will retry on the next list change
      debugPrint('⚠️ news store prefetch error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧰 Helpers
  // ═══════════════════════════════════════════════════════════
  String _ku(Object n) => n.toString().replaceAllMapped(
    RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

  /// 1234 → ١٫٢k
  String _compact(dynamic value) {
    final n = value is num ? value.toInt() : (int.tryParse('$value') ?? 0);
    if (n < 1000) return _ku(n);
    final k = (n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1);
    return '${_ku(k.replaceAll('.', '٫'))}k';
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

  Color _getTypeColor(String type) {
    switch (type) {
      case 'ئاگاداری':
        return const Color(0xFFFFA000);
      case 'هۆشداری':
        return const Color(0xFFE53935);
      case 'ڕووداو':
        return const Color(0xFF8E24AA);
      case 'خزمەتگوزاری':
        return const Color(0xFF1E88E5);
      case 'هەواڵ':
      default:
        return const Color(0xFF43A047);
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
      case 'هەواڵ':
      default:
        return Icons.article_rounded;
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
          height: 240,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.newsList.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _scheduleNext();
              },
              itemBuilder: (context, index) {
                // The card is built once and only scaled per frame
                final card = _buildNewsCard(widget.newsList[index], isDark);

                return AnimatedBuilder(
                  animation: _controller,
                  child: card,
                  builder: (context, child) {
                    var scale = 1.0;
                    if (_controller.hasClients &&
                        _controller.position.haveDimensions) {
                      final page =
                          _controller.page ?? _currentIndex.toDouble();
                      scale = (1 - ((page - index).abs() * 0.15))
                          .clamp(0.85, 1.0);
                    }
                    return Center(
                      child: Transform.scale(
                        scale: Curves.easeOut.transform(scale),
                        child: child,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildIndicator(isDark),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> news, bool isDark) {
    final imageUrl = _extractImage(news);
    final title = news['title']?.toString() ?? '';
    final newsType = news['news_type']?.toString() ?? 'هەواڵ';
    final views = news['views'] ?? 0;
    final likes = news['likes'] ?? 0;

    // Store: from the join if present, otherwise from the prefetched cache
    Map<String, dynamic>? store;
    if (news['dukan'] is Map) {
      store = Map<String, dynamic>.from(news['dukan'] as Map);
    } else {
      final id = news['store_id']?.toString() ?? '';
      if (id.isNotEmpty) store = _storeCache[id];
    }

    return Semantics(
      button: true,
      label: '$newsType: $title',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap(news);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (context, url) => Container(
                      color: isDark
                          ? const Color(0xFF2A2A35)
                          : AppColors.backgroundGrey,
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildPlaceholder(),
                  )
                else
                  _buildPlaceholder(),

                // Soft gradient so text stays readable
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Top row: store badge + type chip
                Positioned(
                  top: 14,
                  right: 14,
                  left: 14,
                  child: Row(
                    children: [
                      if (store != null)
                        Flexible(child: _buildStoreBadge(store)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getTypeColor(newsType),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _getTypeColor(newsType)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getTypeIcon(newsType),
                                color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              newsType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Rabar',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats first, title above them → they can never overlap
                Positioned(
                  bottom: 14,
                  right: 16,
                  left: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.3,
                          fontFamily: 'Rabar',
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 6,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatChip(
                              Icons.visibility_rounded, _compact(views)),
                          const SizedBox(width: 6),
                          _buildStatChip(
                              Icons.thumb_up_rounded, _compact(likes)),
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
    );
  }

  Widget _buildStoreBadge(Map<String, dynamic> store) {
    final name = store['name']?.toString() ?? '';
    final logo =
        store['logo']?.toString() ?? store['image']?.toString() ?? '';
    if (name.isEmpty && logo.isEmpty) return const SizedBox.shrink();
    return _buildBadge(name: name, logo: logo);
  }

  Widget _buildBadge({required String name, required String logo}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logo.isNotEmpty)
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: logo,
                  fit: BoxFit.cover,
                  memCacheWidth: 100,
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
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Rabar',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
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
        child: Icon(Icons.newspaper_rounded,
            color: AppColors.primary, size: 36),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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

  // ═══════════════════════════════════════════════════════════
  // ● Indicator — dots for a few items, a compact counter for many
  // (the old row of dots overflowed the screen with 20+ news)
  // ═══════════════════════════════════════════════════════════
  Widget _buildIndicator(bool isDark) {
    final total = widget.newsList.length;
    if (total <= 1) return const SizedBox.shrink();

    if (total > _maxDots) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${_ku(_currentIndex + 1)} / ${_ku(total)}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final active = _currentIndex == index;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_controller.hasClients) {
              HapticFeedback.selectionClick();
              _controller.animateToPage(
                index,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Padding(
            // larger tap target than the 6px dot itself
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              width: active ? 24 : 6,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : (isDark ? Colors.white24 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}