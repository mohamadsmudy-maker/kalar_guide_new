import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/review_service.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../widgets/reviews/rating_stars.dart';
import '../stores/store_details_dialog.dart';

/// 🏆 بەشی باشترین شوێنەکان
class TopRatedSection extends StatefulWidget {
  const TopRatedSection({super.key});

  @override
  State<TopRatedSection> createState() => _TopRatedSectionState();
}

class _TopRatedSectionState extends State<TopRatedSection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadTopRated();
  }

  Future<List<Map<String, dynamic>>> _loadTopRated() async {
    return await ReviewService.getTopRatedStores(
      limit: 5,
      minRating: 3.5, // ✅ کەمتر — چونکە هێشتا داتا کەمە
      minReviews: 1,  // ✅ تەنها ١ کۆمێنت پێویستە
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadTopRated();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        // ⏳ Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TopRatedSkeleton();
        }

        // ❌ Error یان بەتاڵ
        final stores = snapshot.data ?? [];
        if (stores.isEmpty) {
          return const SizedBox.shrink(); // ✅ بەتاڵ — هیچ پیشان مەدە
        }

        // ✅ پیشاندان
        return _buildSection(context, stores);
      },
    );
  }

  Widget _buildSection(
      BuildContext context,
      List<Map<String, dynamic>> stores,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══════════════════════════════════════════
        // 🏆 ناونیشان
        // ═══════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              // 🏆 ئایکۆن
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFF8F00),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // 📝 ناو
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'باشترین شوێنەکان',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '⭐',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'بەپێی هەڵسەنگاندنی بەکارهێنەران',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // 🔄 Refresh
              GestureDetector(
                onTap: _refresh,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A22)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ═══════════════════════════════════════════
        // 📋 لیستی کارتەکان
        // ═══════════════════════════════════════════
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              return _buildStoreCard(
                context,
                stores[index],
                index,
                isDark,
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی شوێن
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoreCard(
      BuildContext context,
      Map<String, dynamic> store,
      int index,
      bool isDark,
      ) {
    final lang = context.watch<SettingsProvider>().languageId;

    final name = store['name']?.toString() ?? 'شوێن';
    final image = store['image']?.toString() ?? '';
    final address = store['address']?.toString() ?? 'کەلار';
    final avg = (store['average_rating'] as num?)?.toDouble() ?? 0.0;
    final total = (store['total_reviews'] as num?)?.toInt() ?? 0;

    // 🥇 ڕەنگی کارت بەپێی ڕیزبەندی
    final medalColor = _getMedalColor(index);
    final medalIcon = _getMedalIcon(index);

    return GestureDetector(
      onTap: () {
        StoreDetailsDialog.show(context, store);
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: medalColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: medalColor.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: -3,
            ),
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.3 : 0.05,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════
            // 🖼️ وێنە + Medal
            // ═══════════════════════════════════════
            Stack(
              children: [
                // وێنە
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: image.isNotEmpty
                        ? OptimizedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      color: AppColors.primary
                          .withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                  ),
                ),

                // 🌈 گرادیێنت
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 🏆 Medal Badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          medalColor,
                          Color.lerp(medalColor, Colors.white, 0.3)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: medalColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        medalIcon,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

                // ⭐ Rating Badge لە خوارەوە
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFC107)
                            .withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFC107),
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ═══════════════════════════════════════
            // 📝 زانیاری
            // ═══════════════════════════════════════
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ناوی شوێن
                    AutoTranslate(
                      text: name,
                      lang: lang,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                        height: 1.3,
                      ),
                      maxLines: 2,
                    ),

                    // 📍 ناونیشان
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: AutoTranslate(
                            text: address,
                            lang: lang,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),

                    // ⭐ ئەستێرەکان + ژمارەی کۆمێنت
                    Row(
                      children: [
                        RatingStars(
                          rating: avg,
                          size: 11,
                          color: const Color(0xFFFFC107),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($total)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگ و ئایکۆنی Medal
  // ═══════════════════════════════════════════════════════════
  Color _getMedalColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFFFD700); // 🥇 زێڕین
      case 1:
        return const Color(0xFFC0C0C0); // 🥈 زیوین
      case 2:
        return const Color(0xFFCD7F32); // 🥉 برۆنز
      default:
        return AppColors.primary; // 🔵 شین
    }
  }

  IconData _getMedalIcon(int index) {
    switch (index) {
      case 0:
        return Icons.emoji_events_rounded;
      case 1:
        return Icons.emoji_events_rounded;
      case 2:
        return Icons.emoji_events_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// ⏳ Skeleton
// ═══════════════════════════════════════════════════════════
class _TopRatedSkeleton extends StatelessWidget {
  const _TopRatedSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ناونیشان
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A22)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 140,
                height: 16,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A22)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        // کارتەکان
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: 200,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A22)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}