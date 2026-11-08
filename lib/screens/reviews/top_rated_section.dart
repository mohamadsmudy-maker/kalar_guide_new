import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/review_service.dart';
import '../../widgets/reviews/rating_stars.dart';
import '../stores/store_details_dialog.dart';
import '../../l10n/tr.dart';

/// ⭐ بەشی باشترین شوێنەکان لە Home
class TopRatedSection extends StatefulWidget {
  const TopRatedSection({super.key});

  @override
  State<TopRatedSection> createState() => _TopRatedSectionState();
}

class _TopRatedSectionState extends State<TopRatedSection> {
  bool _loading = true;
  List<Map<String, dynamic>> _stores = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ReviewService.getTopRatedStores(
      limit: 5,
      minRating: 4.0,
      minReviews: 1,
    );
    if (mounted) {
      setState(() {
        _stores = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _stores.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD9822B), Color(0xFFD9822B)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD9822B).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('باشترین شوێنەکان ⭐'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _stores.length,
              itemBuilder: (ctx, i) => _buildCard(_stores[i], i + 1, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> store, int rank, bool isDark) {
    final name = store['name']?.toString() ?? '';
    final image = store['image']?.toString() ?? '';
    final rating =
        double.tryParse(store['average_rating']?.toString() ?? '0') ?? 0.0;
    final totalReviews =
        int.tryParse(store['total_reviews']?.toString() ?? '0') ?? 0;

    final rankColor = rank == 1
        ? const Color(0xFFD9822B)
        : rank == 2
        ? const Color(0xFFB0BEC5)
        : rank == 3
        ? const Color(0xFFD9822B)
        : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: () => StoreDetailsDialog.show(context, store),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: rankColor.withValues(alpha: 0.4),
            width: rank <= 3 ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🖼️ وێنە + Rank
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    image,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 90,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                // 🏆 Rank
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: rankColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: rankColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 📝 ناو + Rating
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(name),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      RatingStars(
                        rating: rating,
                        size: 12,
                        color: const Color(0xFFD9822B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD9822B),
                        ),
                      ),
                      if (totalReviews > 0) ...[
                        const Spacer(),
                        Text(
                          '($totalReviews)',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}