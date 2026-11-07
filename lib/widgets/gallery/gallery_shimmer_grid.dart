import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/app_colors.dart';

class GalleryShimmerGrid extends StatelessWidget {
  final bool isDark;
  final int count;
  const GalleryShimmerGrid({
    super.key,
    required this.isDark,
    this.count = 6,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: count,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: isDark ? AppColors.darkBorder : Colors.grey.shade300,
        highlightColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}