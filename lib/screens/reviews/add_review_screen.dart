import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../models/review.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';
import '../../widgets/reviews/rating_stars.dart';
import '../../l10n/tr.dart';

/// ✍️ شاشەی نووسین / دەستکاریکردنی کۆمێنت
class AddReviewScreen extends StatefulWidget {
  final int storeId;
  final String storeName;
  final Review? existingReview;

  const AddReviewScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    this.existingReview,
  });

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _commentCtrl = TextEditingController();
  final _focusNode = FocusNode();

  int _rating = 5;
  bool _loading = false;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating;
      _commentCtrl.text = widget.existingReview!.comment ?? '';
      _charCount = _commentCtrl.text.length;
    }

    _commentCtrl.addListener(() {
      if (mounted) {
        setState(() => _charCount = _commentCtrl.text.length);
      }
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 ناردن
  // ═══════════════════════════════════════════════════════════
  Future<void> _submit() async {
    // ✅ پشکنینی چوونەژوورەوە
    final user = AuthSessionManager.currentUser;
    if (user == null) {
      _showSnack(tr('تکایە سەرەتا بچۆ ژوورەوە ⚠'), const Color(0xFFD9822B));
      return;
    }

    // ✅ پشکنینی Rating
    if (_rating < 1 || _rating > 5) {
      _showSnack(tr('تکایە ئەستێرەیەک هەڵبژێرە ⭐'), const Color(0xFFD9822B));
      return;
    }

    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    try {
      final comment = _commentCtrl.text.trim();
      final result = await ReviewService.addReview(
        storeId: widget.storeId,
        userId: user['id']?.toString(),
        userName: user['name']?.toString() ?? 'بەکارهێنەر',
        userPhone: user['phone']?.toString(),
        rating: _rating,
        comment: comment.isEmpty ? null : comment,
      );

      if (!mounted) return;

      if (result != null) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  tr(widget.existingReview != null
                      ? '✅ کۆمێنتەکەت نوێکرایەوە'
                      : '✅ سوپاس بۆ هەڵسەنگاندنەکەت!'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F9D7A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        throw Exception('نەتوانرا پاشەکەوت بکرێت');
      }
    } catch (e) {
      debugPrint('❌ submit review error: $e');
      if (mounted) {
        _showSnack(trf('هەڵە: {0}', [e]), const Color(0xFFDC3545));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(msg),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final isEditing = widget.existingReview != null;

    return Directionality(
      textDirection:
      lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            tr(isEditing ? 'دەستکاری کۆمێنت' : 'نووسینی کۆمێنت'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          backgroundColor:
          isDark ? const Color(0xFF1A1A22) : const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          actions: [
            if (isEditing)
              IconButton(
                tooltip: tr('سڕینەوە'),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _loading ? null : _confirmDelete,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════════════════════════
              // 🏪 ناوی شوێن
              // ═══════════════════════════════════════
              _buildStoreHeader(isDark),

              const SizedBox(height: 30),

              // ═══════════════════════════════════════
              // ⭐ هەڵبژاردنی ئەستێرە
              // ═══════════════════════════════════════
              _buildRatingSelector(isDark),

              const SizedBox(height: 30),

              // ═══════════════════════════════════════
              // 💬 کۆمێنت
              // ═══════════════════════════════════════
              _buildCommentField(isDark),

              const SizedBox(height: 24),

              // ═══════════════════════════════════════
              // ✅ دوگمەی ناردن
              // ═══════════════════════════════════════
              _buildSubmitButton(isEditing),

              const SizedBox(height: 16),

              // ═══════════════════════════════════════
              // 💡 تێبینی
              // ═══════════════════════════════════════
              _buildTip(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 سەرەتای شوێن
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoreHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  Color.lerp(AppColors.primary, Colors.white, 0.2)!,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('تۆ هەڵسەنگاندن دەکەیت بۆ:'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(widget.storeName),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ هەڵبژاردنی ئەستێرە
  // ═══════════════════════════════════════════════════════════
  Widget _buildRatingSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            tr('چەند ئەستێرە دەدەیت؟'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),

          // ⭐ ئەستێرەکان
          RatingInput(
            value: _rating,
            onChanged: (v) {
              setState(() => _rating = v);
              HapticFeedback.selectionClick();
            },
          ),

          const SizedBox(height: 14),

          // 🏷️ لیبڵی Rating
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _getRatingColor(_rating).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getRatingColor(_rating).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              tr(_getRatingLabel(_rating)),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _getRatingColor(_rating),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💬 خانەی کۆمێنت
  // ═══════════════════════════════════════════════════════════
  Widget _buildCommentField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.comment_rounded,
              size: 16,
              color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
            ),
            const SizedBox(width: 6),
            Text(
              tr('کۆمێنت'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              tr('(ئارەزوومەندانە)'),
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
            const Spacer(),
            Text(
              '$_charCount/500',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _charCount > 450
                    ? const Color(0xFFDC3545)
                    : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _commentCtrl,
          focusNode: _focusNode,
          maxLines: 5,
          maxLength: 500,
          minLines: 3,
          textInputAction: TextInputAction.newline,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
            height: 1.6,
          ),
          decoration: InputDecoration(
            hintText:
            tr('ئەزموونی خۆت لەگەڵ ئەم شوێنە باس بکە...\nچی باش بوو؟ چی خراپ بوو؟'),
            hintStyle: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
              height: 1.6,
            ),
            counterText: '',
            filled: true,
            fillColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ دوگمەی ناردن
  // ═══════════════════════════════════════════════════════════
  Widget _buildSubmitButton(bool isEditing) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _submit,
        icon: _loading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : Icon(
          isEditing
              ? Icons.save_rounded
              : Icons.check_circle_rounded,
          size: 22,
        ),
        label: Text(
          tr(_loading
              ? 'خەریکی ناردن...'
              : (isEditing ? 'نوێکردنەوە' : 'ناردنی کۆمێنت')),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
          AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💡 تێبینی
  // ═══════════════════════════════════════════════════════════
  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD9822B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD9822B).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFD9822B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Color(0xFFD9822B),
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('کۆمێنتی ڕاستەقینە و بەسوود یارمەتی بەکارهێنەرانی تر دەدات بۆ هەڵبژاردنی باشترین شوێن.'),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFD9822B),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوەی کۆمێنت
  // ═══════════════════════════════════════════════════════════
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC3545)),
              const SizedBox(width: 8),
              Text(
                tr('سڕینەوەی کۆمێنت'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Text(
            tr('ئایا دڵنیایت لە سڕینەوەی کۆمێنتەکەت؟\nئەم کارە ناگەڕێتەوە.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: Text(
                tr('بەڵێ، بیسڕەوە'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final id = widget.existingReview?.id;
      if (id == null) return;

      final success = await ReviewService.deleteReview(id);

      if (mounted && success) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('✅ کۆمێنت سڕایەوە')),
            backgroundColor: const Color(0xFF0F9D7A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  String _getRatingLabel(int rating) {
    switch (rating) {
      case 5:
        return '⭐ زۆر باش';
      case 4:
        return '😊 باش';
      case 3:
        return '😐 ئاسایی';
      case 2:
        return '😕 خراپ';
      case 1:
        return '😡 زۆر خراپ';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return const Color(0xFF0F9D7A);
    if (rating == 3) return const Color(0xFFD9822B);
    return const Color(0xFFDC3545);
  }
}