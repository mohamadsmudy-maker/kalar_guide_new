import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../common/optimized_network_image.dart';
import '../common/auto_translate.dart';

/// 🏪 کارتی شوێن — ULTRA PRO
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
    final isGov = (store['type']?.toString() ?? '') == 'حکومی';

    final accentColor = isGov ? const Color(0xFF10B981) : const Color(0xFFE91E63);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A1A22), const Color(0xFF1F1F2A)]
                  : [Colors.white, const Color(0xFFFAFBFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Row(
            children: [
              // 🖼️ Image with ring
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: image.isNotEmpty
                      ? OptimizedNetworkImage(
                    imageUrl: image,
                    width: 86,
                    height: 86,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: accentColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: accentColor,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 📝 Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoTranslate(
                      text: name,
                      lang: lang,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimary,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: AutoTranslate(
                            text: address,
                            lang: lang,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
                    Row(
                      children: [
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: AutoTranslate(
                              text: category,
                              lang: lang,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                              ),
                            ),
                          ),
                        if (distance != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 9,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${distance!.toStringAsFixed(1)} کم',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.15),
                      accentColor.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}