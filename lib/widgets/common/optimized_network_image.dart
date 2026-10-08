import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

/// 🖼️ وێنەی ئۆنلاین بە کاش — Memory ی کەم
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _placeholder();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      // ✅ کەمکردنەوەی Memory بۆ ئیمۆلاتۆر
      memCacheWidth: 400,
      maxWidthDiskCache: 600,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => _errorWidget(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  Widget _errorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}