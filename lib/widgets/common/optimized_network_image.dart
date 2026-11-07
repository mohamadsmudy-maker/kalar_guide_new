import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

/// 🖼️ وێنەی ئۆنلاین بە کاش — Memory ی کەم (v2)
///
///  • `memCacheWidth` ئێستا بە پێی قەبارەی ڕاستەقینەی widget و devicePixelRatio
///    حیساب دەکرێت. پێشتر هەمیشە ٤٠٠ بوو: وێنەی بچووک (٧٨px) ٤٠٠px لە مێمۆری
///    دەگرت، و وێنەی گەورە (پڕی شاشە) تێکچوو/blur دەبوو.
///  • وێنەی بێ URL یان URL ی نەگونجاو (http/https نییە) ڕاستەوخۆ placeholder
///  • placeholder/error بە تیمی تاریک
///  • spinner تەنها لە وێنە گەورەکان (لە لیستدا گران بوو)
///  • `borderRadius`، `semanticLabel`، `fadeInDuration` ی ئارەزوومەندانە
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;

  /// ئەگەر دیاری بکرێت وێنەکە بڕدەکرێت (ClipRRect)
  final BorderRadius? borderRadius;

  /// وەسفی وێنە بۆ screen reader (بێ ئەمە وێنەکە شاراوەیە)
  final String? semanticLabel;

  final Duration fadeInDuration;

  /// سنووری دیسک (پیکسڵ)
  final int maxDiskWidth;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.semanticLabel,
    this.fadeInDuration = const Duration(milliseconds: 180),
    this.maxDiskWidth = 1000,
  });

  /// کەمترین و زۆرترین قەبارە بۆ decode کردن
  static const int _minDecode = 96;
  static const int _maxDecode = 1200;
  static const int _unknownWidthDecode = 600;

  int _memWidth(BuildContext context) {
    final w = width;
    if (w == null || !w.isFinite || w <= 0) return _unknownWidthDecode;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (w * dpr).round().clamp(_minDecode, _maxDecode);
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF22222C) : Colors.grey.shade100;
    final iconColor = isDark ? Colors.white30 : Colors.grey;

    final lower = url.toLowerCase();
    final validUrl = lower.startsWith('http://') || lower.startsWith('https://');

    Widget box(IconData icon) => Container(
      width: width,
      height: height,
      color: bg,
      child: Center(child: Icon(icon, color: iconColor, size: 24)),
    );

    Widget image;
    if (!validUrl) {
      image = box(Icons.image_not_supported_rounded);
    } else {
      // spinner تەنها بۆ وێنە گەورەکان
      final showSpinner = (width ?? 0) >= 100 && (height ?? 0) >= 100;

      image = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        memCacheWidth: _memWidth(context),
        maxWidthDiskCache: maxDiskWidth,
        fadeInDuration: fadeInDuration,
        placeholder: (context, _) => Container(
          width: width,
          height: height,
          color: bg,
          child: showSpinner
              ? const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          )
              : null,
        ),
        errorWidget: (context, _, __) => box(Icons.broken_image_rounded),
      );
    }

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    if (semanticLabel != null) {
      return Semantics(image: true, label: semanticLabel, child: image);
    }
    return ExcludeSemantics(child: image);
  }
}