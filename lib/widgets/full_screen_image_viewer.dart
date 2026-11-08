import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:kalar_guide_new/config/app_colors.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/tr.dart';
import '../utils/gallery_helpers.dart';

/// 🖼️ بینەری وێنەی تەواو — بۆ گەلەری و هەموو شوێنەکان
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String imageTitle;

  /// زانیاری ئارەزوومەندانە بۆ پانێڵی خوارەوە
  final String? category;
  final IconData? categoryIcon;
  final int? views;
  final DateTime? date;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.imageTitle,
    this.category,
    this.categoryIcon,
    this.views,
    this.date,
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

  bool get _hasInfo => widget.category != null || widget.views != null || widget.date != null;

  String _digits(String s) => AppLang.isRtl ? toLocalDigits(s) : s;

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _buildInfo() {
    final d = widget.date?.toLocal();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (widget.category != null)
            _pill(widget.categoryIcon ?? Icons.photo_library_rounded, tr(widget.category!)),
          if (widget.views != null)
            _pill(Icons.visibility_rounded, trf('{0} بینین', [_digits('${widget.views}')])),
          if (d != null)
            _pill(Icons.calendar_today_rounded,
                _digits('${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}')),
        ],
      ),
    );
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
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Colors.white),
                          tooltip: tr('هاوبەشکردن'),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Share.share('${tr(widget.imageTitle)}\n${widget.imageUrl}\n\n${tr('گەلەری کەلار')} • ${tr('ئەپی ڕێبەری کەلار')}');
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_hasInfo) _buildInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}