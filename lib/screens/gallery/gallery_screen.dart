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
import 'gallery_category_screen.dart';

/// 🖼️ گەلەری بەکارهێنەر — ULTRA PRO MAX V4
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('گەلەری کەلار',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            GalleryCategoryChips(
              isDark: isDark,
              selectedId: _selectedCategory,
              counts: _counts,
              onSelected: (id) => setState(() => _selectedCategory = id),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) return GalleryShimmerGrid(isDark: isDark);
    if (_error != null) {
      return GalleryErrorState(
        isDark: isDark,
        message: _error!,
        onRetry: _load,
      );
    }
    if (_visible.isEmpty) {
      return GalleryEmptyState(isDark: isDark, onRefresh: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 600,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _visible.length,
        itemBuilder: (_, i) => GalleryImageCard(
          image: _visible[i],
          isDark: isDark,
          onTap: () => _onTap(_visible[i]),
        ),
      ),
    );
  }
}