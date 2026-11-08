import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../models/review.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';
import '../../widgets/reviews/rating_stars.dart';
import 'add_review_screen.dart';
import '../../l10n/tr.dart';

/// ⭐ شاشەی کۆمێنت و هەڵسەنگاندنەکان
class StoreReviewsScreen extends StatefulWidget {
  final int storeId;
  final String storeName;

  const StoreReviewsScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreReviewsScreen> createState() => _StoreReviewsScreenState();
}

class _StoreReviewsScreenState extends State<StoreReviewsScreen> {
  bool _loading = true;
  List<Review> _reviews = [];
  StoreRating? _rating;
  Review? _userReview;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final user = AuthSessionManager.currentUser;

    final results = await Future.wait([
      ReviewService.getStoreReviews(storeId: widget.storeId),
      ReviewService.getStoreRating(widget.storeId),
      ReviewService.getUserReview(
        storeId: widget.storeId,
        userId: user?['id']?.toString(),
      ),
    ]);

    if (mounted) {
      setState(() {
        _reviews = results[0] as List<Review>;
        _rating = results[1] as StoreRating?;
        _userReview = results[2] as Review?;
        _loading = false;
      });
    }
  }

  Future<void> _openAddReview() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تکایە سەرەتا بچۆ ژوورەوە ⚠')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReviewScreen(
          storeId: widget.storeId,
          storeName: widget.storeName,
          existingReview: _userReview,
        ),
      ),
    );

    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            tr('کۆمێنت و هەڵسەنگاندن'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          backgroundColor: isDark
              ? const Color(0xFF1A1A22)
              : const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        )
            : RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ═══════════════════════════════════
              // 📊 کارتی ئامار
              // ═══════════════════════════════════
              _buildStatsCard(isDark),

              const SizedBox(height: 16),

              // ═══════════════════════════════════
              // ✍️ دوگمەی نووسینی کۆمێنت
              // ═══════════════════════════════════
              _buildAddReviewButton(isDark),

              const SizedBox(height: 20),

              // ═══════════════════════════════════
              // 📋 لیستی کۆمێنتەکان
              // ═══════════════════════════════════
              if (_reviews.isEmpty)
                _buildEmptyState(isDark)
              else ...[
                Text(
                  trf('کۆمێنتەکان ({0})', [_reviews.length]),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                ..._reviews.map((r) => _buildReviewCard(r, isDark)),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
        floatingActionButton: _userReview != null
            ? FloatingActionButton.extended(
          onPressed: _openAddReview,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.edit_rounded),
          label: Text(
            tr('دەستکاری کۆمێنت'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        )
            : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 کارتی ئامار
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsCard(bool isDark) {
    final rating = _rating;
    final avg = rating?.averageRating ?? 0.0;
    final total = rating?.totalReviews ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, Colors.white, 0.3)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🎯 ناوەندی
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              RatingStars(
                rating: avg,
                size: 18,
                color: const Color(0xFFFFC107),
              ),
              const SizedBox(height: 6),
              Text(
                trf('{0} کۆمێنت', [total]),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // 📊 ڕێژەکان
          Expanded(
            child: Column(
              children: [
                _buildRatingBar(5, rating?.percentFor(5) ?? 0, rating?.count5 ?? 0, isDark),
                _buildRatingBar(4, rating?.percentFor(4) ?? 0, rating?.count4 ?? 0, isDark),
                _buildRatingBar(3, rating?.percentFor(3) ?? 0, rating?.count3 ?? 0, isDark),
                _buildRatingBar(2, rating?.percentFor(2) ?? 0, rating?.count2 ?? 0, isDark),
                _buildRatingBar(1, rating?.percentFor(1) ?? 0, rating?.count1 ?? 0, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, double percent, int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$stars',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.star_rounded,
            color: Color(0xFFFFC107),
            size: 12,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFC107)),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✍️ دوگمەی نووسینی کۆمێنت
  // ═══════════════════════════════════════════════════════════
  Widget _buildAddReviewButton(bool isDark) {
    return GestureDetector(
      onTap: _openAddReview,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rate_review_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(_userReview != null
                        ? 'دەستکاری کۆمێنتی خۆت'
                        : 'هەڵسەنگاندنی ئەم شوێنە'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr(_userReview != null
                        ? 'کۆمێنتەکەت نوێ بکەرەوە'
                        : 'ئەزموونی خۆت لەگەڵ ئەم شوێنە باس بکە'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی کۆمێنت
  // ═══════════════════════════════════════════════════════════
  Widget _buildReviewCard(Review review, bool isDark) {
    final isMine = _userReview?.id == review.id;
    final currentUserId = AuthSessionManager.currentUser?['id']?.toString();
    final isOwner = currentUserId != null && review.userId == currentUserId;
    final isAdmin = AuthSessionManager.isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMine
            ? Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👤 سەرەتا — ناو + ئەستێرە
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  tr(review.userName.isNotEmpty
                      ? review.userName[0].toUpperCase()
                      : '?'),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tr(review.userName),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tr('تۆ'),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        RatingStars(
                          rating: review.rating.toDouble(),
                          size: 13,
                          color: const Color(0xFFFFC107),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr(review.getTimeAgo()),
                          style: TextStyle(
                            fontSize: 10,
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
              // 🗑️ دوگمەی سڕینەوە (تەنها بۆ خۆی یان ئەدمین)
              if (isOwner || isAdmin)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Colors.red.shade400,
                  ),
                  onPressed: () => _confirmDelete(review),
                ),
            ],
          ),

          // 💬 کۆمێنت
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F0F14)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tr(review.comment!),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Review review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(tr('سڕینەوەی کۆمێنت')),
          content: Text(tr('ئایا دڵنیایت لە سڕینەوەی ئەم کۆمێنتە؟')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final success = await ReviewService.deleteReview(review.id!);
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('✅ کۆمێنت سڕایەوە')),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 حاڵەتی بەتاڵ
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('هیچ کۆمێنتێک نییە هێشتا'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('ببە یەکەم کەس کە هەڵسەنگاندنی دەکات'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}