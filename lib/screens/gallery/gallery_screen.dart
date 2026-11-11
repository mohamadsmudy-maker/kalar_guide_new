import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../models/gallery/gallery_image.dart';
import '../../services/gallery/gallery_service.dart';
import '../../services/gallery/gallery_view_tracker.dart';
import '../../widgets/gallery/gallery_category_chips.dart';
import '../../widgets/gallery/gallery_empty_state.dart';
import '../../widgets/gallery/gallery_error_state.dart';
import '../../widgets/gallery/gallery_image_card.dart';
import '../../widgets/gallery/gallery_shimmer_grid.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../utils/gallery_helpers.dart';
import '../../l10n/tr.dart';
import '../../models/gallery/gallery_category_registry.dart';

/// 🖼️ گەلەری بەکارهێنەر — FULL ULTRA PRO MAX
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _service = GalleryService();
  final _tracker = GalleryViewTracker();

  List<GalleryImage> _images = [];
  Map<String, int> _counts = {};
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final images = await _service.fetchAll();
      final counts = await _service.countByCategory();
      if (!mounted) return;
      setState(() {
        _images = images;
        _counts = counts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'هەڵە لە هێنانی وێنەکان';
      });
    }
  }

  List<GalleryImage> get _visible {
    if (_selectedCategory == null) return _images;
    return _images.where((i) => i.categoryId == _selectedCategory).toList();
  }

  /// بەرچاوترین وێنە: زۆرترین بینین لەناو فلتەری ئێستادا
  GalleryImage? get _featured {
    final v = _visible;
    if (v.length < 3) return null;
    return v.reduce((a, b) => b.views > a.views ? b : a);
  }

  int get _totalViews => _images.fold(0, (a, i) => a + i.views);

  Future<void> _onTap(GalleryImage img) async {
    HapticFeedback.selectionClick();
    // ئەپدەیتی لۆکاڵی + DB
    final updated = img.copyWith(views: img.views + 1);
    setState(() {
      final i = _images.indexWhere((e) => e.id == img.id);
      if (i != -1) _images[i] = updated;
    });
    _tracker.increment(img.id);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: img.imageUrl,
          imageTitle: img.title,
          category: GalleryCategoryRegistry.byId(img.categoryId).label,
          categoryIcon: GalleryCategoryRegistry.byId(img.categoryId).icon,
          views: updated.views,
          date: img.createdAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF4F6FA);

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bg,
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          edgeOffset: 140,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              _buildHeader(isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: GalleryCategoryChips(
                    isDark: isDark,
                    selectedId: _selectedCategory,
                    counts: _counts,
                    hideEmpty: true,
                    onSelected: (id) => setState(() => _selectedCategory = id),
                  ),
                ),
              ),
              ..._buildBody(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// سەرپەڕە: ناونیشان + ئامار لەسەر گرادیێنت
  Widget _buildHeader(bool isDark) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 148,
      collapsedHeight: 60,
      backgroundColor: isDark ? const Color(0xFF1A1A22) : AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        tr('گەلەری کەلار'),
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xFF1A1A22), Color(0xFF232334)]
                  : const [Color(0xFF1E88E5), Color(0xFF42A5F5)],
            ),
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stat(Icons.photo_library_rounded,
                        toLocalDigits('${_images.length}'), tr('وێنە')),
                    const SizedBox(width: 10),
                    _stat(Icons.visibility_rounded,
                        toLocalDigits('$_totalViews'), ''),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label.isEmpty ? value : '$value $label',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBody(bool isDark) {
    if (_isLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: true,
          child: GalleryShimmerGrid(isDark: isDark),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GalleryErrorState(
            isDark: isDark,
            message: _error!,
            onRetry: _load,
          ),
        ),
      ];
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GalleryEmptyState(isDark: isDark, onRefresh: _load),
        ),
      ];
    }

    final featured = _featured;
    final rest = featured == null
        ? visible
        : visible.where((i) => i.id != featured.id).toList();

    return [
      if (featured != null)
        SliverToBoxAdapter(child: _buildFeatured(featured, isDark)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) => GalleryImageCard(
              image: rest[i],
              isDark: isDark,
              onTap: () => _onTap(rest[i]),
            ),
            childCount: rest.length,
          ),
        ),
      ),
    ];
  }

  /// ⭐ وێنەی بەرچاو — زۆرترین بینین، بە پانی تەواو
  Widget _buildFeatured(GalleryImage img, bool isDark) {
    final cat = GalleryCategoryRegistry.byId(img.categoryId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Semantics(
        button: true,
        label: img.title,
        child: GestureDetector(
          onTap: () => _onTap(img),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: img.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 1000,
                    placeholder: (_, __) => Container(
                      color: isDark
                          ? const Color(0xFF2A2A35)
                          : AppColors.backgroundGrey,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.photo_rounded,
                          size: 48, color: AppColors.primary),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x33000000),
                          Colors.transparent,
                          Color(0xB3000000),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  // 🔥 بەرچاوترین
                  PositionedDirectional(
                    top: 12,
                    start: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD9822B), Color(0xFFF2A65A)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 8),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            tr('بەرچاوترین'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 14,
                    end: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(img.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black87),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(cat.icon,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 13),
                            const SizedBox(width: 4),
                            Text(
                              tr(cat.label),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.visibility_rounded,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              toLocalDigits('${img.views}'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
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
}
