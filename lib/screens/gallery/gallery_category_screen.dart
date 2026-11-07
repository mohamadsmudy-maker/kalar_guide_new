import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/gallery/gallery_category.dart';
import '../../models/gallery/gallery_image.dart';
import '../../services/gallery/gallery_service.dart';
import '../../widgets/gallery/gallery_empty_state.dart';
import '../../widgets/gallery/gallery_image_card.dart';
import '../../widgets/gallery/gallery_shimmer_grid.dart';
import '../../widgets/full_screen_image_viewer.dart';

class GalleryCategoryScreen extends StatefulWidget {
  final GalleryCategory category;
  const GalleryCategoryScreen({super.key, required this.category});

  @override
  State<GalleryCategoryScreen> createState() => _GalleryCategoryScreenState();
}

class _GalleryCategoryScreenState extends State<GalleryCategoryScreen> {
  final _service = GalleryService();
  List<GalleryImage> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.fetchAll(categoryId: widget.category.id);
    if (!mounted) return;
    setState(() {
      _images = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: Text(widget.category.label),
          backgroundColor: widget.category.color,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? GalleryShimmerGrid(isDark: isDark)
            : _images.isEmpty
            ? GalleryEmptyState(isDark: isDark)
            : GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: _images.length,
          itemBuilder: (_, i) => GalleryImageCard(
            image: _images[i],
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenImageViewer(
                  imageUrl: _images[i].imageUrl,
                  imageTitle: _images[i].title,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}