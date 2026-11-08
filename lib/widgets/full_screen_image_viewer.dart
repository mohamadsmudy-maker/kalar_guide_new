import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:kalar_guide_new/config/app_colors.dart';
import '../l10n/tr.dart';

/// 🖼️ بینەری وێنەی تەواو — بۆ گەلەری و هەموو شوێنەکان
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String imageTitle;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.imageTitle,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // 🔆 خۆکارانە دوگمەکان بشارەوە دوای ٣ چرکە
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🖼️ وێنە بە PhotoView (zoom + pan)
          Center(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showControls = !_showControls);
              },
              child: PhotoViewGallery.builder(
                itemCount: 1,
                builder: (context, index) => PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(widget.imageUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: PhotoViewHeroAttributes(
                    tag: 'gallery_${widget.imageUrl}',
                  ),
                ),
                backgroundDecoration: const BoxDecoration(
                  color: Colors.black,
                ),
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                scrollPhysics: const BouncingScrollPhysics(),
              ),
            ),
          ),

          // 🔙 دوگمەی گەڕانەوە + ناونیشان
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                          tooltip: tr('گەڕانەوە'),
                        ),
                        Expanded(
                          child: Text(
                            tr(widget.imageTitle),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}