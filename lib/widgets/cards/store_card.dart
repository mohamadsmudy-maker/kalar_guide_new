import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../common/optimized_network_image.dart';
import '../common/auto_translate.dart';   // ✅ ویجێتی نوێ

/// 🏪 کارتی شوێن — بە پشتگیری فرەزمان
class StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final double? distance;
  final VoidCallback? onTap;

  const StoreCard({
    super.key,
    required this.store,
    this.distance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    final name = store['name']?.toString() ?? 'شوێن';
    final address = store['address']?.toString() ?? 'کەلار';
    final category = store['category']?.toString() ?? '';
    final image = store['image']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🖼️ وێنە
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: image.isNotEmpty
                  ? OptimizedNetworkImage(
                imageUrl: image,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              )
                  : Container(
                width: 90,
                height: 90,
                color: isDark
                    ? const Color(0xFF2A2A35)
                    : AppColors.backgroundGrey,
                child: const Icon(Icons.storefront_rounded),
              ),
            ),
            const SizedBox(width: 12),

            // 📝 زانیاری
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ ناوی شوێن
                  AutoTranslate(
                    text: name,
                    lang: lang,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),

                  // ✅ ناونیشان
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: AutoTranslate(
                          text: address,
                          lang: lang,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ✅ کەرت + دووری
                  Row(
                    children: [
                      if (category.isNotEmpty)
                        AutoTranslate(
                          text: category,
                          lang: lang,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      if (distance != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${distance!.toStringAsFixed(1)} کم',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_left_rounded,
              color: isDark ? Colors.white54 : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}