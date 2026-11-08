import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../stores/store_details_dialog.dart';
import '../../l10n/tr.dart';

/// 📰 وردەکاری هەواڵ — ULTRA PRO MAX V2
class NewsDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> newsItem;

  const NewsDetailsScreen({super.key, required this.newsItem});

  @override
  State<NewsDetailsScreen> createState() => _NewsDetailsScreenState();
}

class _NewsDetailsScreenState extends State<NewsDetailsScreen> {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  late int likes;
  late int views;
  bool isLiked = false;
  bool isFavorite = false;
  bool _loading = true;
  int _currentImageIndex = 0;
  Map<String, dynamic>? _storeInfo;

  bool _isLiking = false;
  bool _isFavoriting = false;

  String? get _newsId => widget.newsItem['id']?.toString();

  // ═══════════════════════════════════════════════════════════
  // 🔧 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    likes = (widget.newsItem['likes'] as num?)?.toInt() ?? 0;
    views = (widget.newsItem['views'] as num?)?.toInt() ?? 0;
    _checkUserStatus();
    _fetchStoreInfo();
    _incrementViews();
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats
  // ═══════════════════════════════════════════════════════════
  Future<void> _incrementViews() async {
    final newsId = _newsId;
    if (newsId == null || newsId.isEmpty) return;

    try {
      await Supabase.instance.client.rpc(
        'increment_views',
        params: {'news_id': newsId},
      );
      if (!mounted) return;
      setState(() => views++);
    } catch (e) {
      debugPrint('❌ View increment error: $e');
    }
  }

  Future<void> _fetchStoreInfo() async {
    final storeId = widget.newsItem['store_id'];
    if (storeId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select('id, name, logo, image, address, type')
          .eq('id', storeId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() => _storeInfo = res);
      }
    } catch (e) {
      debugPrint('❌ Store info error: $e');
    }
  }

  Future<void> _checkUserStatus() async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final newsId = _newsId;

    if (supabaseUser == null || newsId == null || newsId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final userId = supabaseUser.id;

      final results = await Future.wait([
        Supabase.instance.client
            .from('news_likes')
            .select()
            .eq('user_id', userId)
            .eq('news_id', newsId)
            .maybeSingle(),
        Supabase.instance.client
            .from('news_favorites')
            .select()
            .eq('user_id', userId)
            .eq('news_id', newsId)
            .maybeSingle(),
      ]);

      if (!mounted) return;
      setState(() {
        isLiked = results[0] != null;
        isFavorite = results[1] != null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ User status error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ❤️ Like / Favorite
  // ═══════════════════════════════════════════════════════════
  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) {
      _showLoginRequired();
      return;
    }

    final newsId = _newsId;
    if (newsId == null || newsId.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _isLiking = true);

    final userId = supabaseUser.id;
    final wasLiked = isLiked;
    final oldLikes = likes;

    setState(() {
      if (wasLiked) {
        likes = likes > 0 ? likes - 1 : 0;
        isLiked = false;
      } else {
        likes++;
        isLiked = true;
      }
    });

    try {
      if (wasLiked) {
        await Supabase.instance.client
            .from('news_likes')
            .delete()
            .eq('user_id', userId)
            .eq('news_id', newsId);
        await Supabase.instance.client.rpc(
          'decrement_likes',
          params: {'news_id': newsId},
        );
      } else {
        await Supabase.instance.client
            .from('news_likes')
            .insert({'user_id': userId, 'news_id': newsId});
        await Supabase.instance.client.rpc(
          'increment_likes',
          params: {'news_id': newsId},
        );
      }
    } catch (e) {
      debugPrint('❌ Like error: $e');
      if (!mounted) return;
      setState(() {
        isLiked = wasLiked;
        likes = oldLikes;
      });
      _showError(tr('هەڵە لە لایککردن'));
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriting) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) {
      _showLoginRequired();
      return;
    }

    final newsId = _newsId;
    if (newsId == null || newsId.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _isFavoriting = true);

    final userId = supabaseUser.id;
    final wasFavorite = isFavorite;
    setState(() => isFavorite = !isFavorite);

    try {
      if (wasFavorite) {
        await Supabase.instance.client
            .from('news_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('news_id', newsId);
      } else {
        await Supabase.instance.client
            .from('news_favorites')
            .insert({'user_id': userId, 'news_id': newsId});
      }
    } catch (e) {
      debugPrint('❌ Favorite error: $e');
      if (!mounted) return;
      setState(() => isFavorite = wasFavorite);
      _showError(tr('هەڵە لە دڵخوازکردن'));
    } finally {
      if (mounted) setState(() => _isFavoriting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💬 SnackBar helpers
  // ═══════════════════════════════════════════════════════════
  void _showLoginRequired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr('تکایە سەرەتا بچۆ ژوورەوە ⚠'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(message),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  Color _getTypeColor(String type) {
    switch (type) {
      case 'ئاگاداری':
        return AppColors.orange;
      case 'هۆشداری':
        return AppColors.red;
      case 'ڕووداو':
        return AppColors.purple;
      case 'خزمەتگوزاری':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'ئاگاداری':
        return Icons.info_rounded;
      case 'هۆشداری':
        return Icons.warning_rounded;
      case 'ڕووداو':
        return Icons.event_rounded;
      case 'خزمەتگوزاری':
        return Icons.build_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  List<String> _extractAllImages(dynamic rawImages) {
    if (rawImages == null) return [];
    if (rawImages is List) {
      return rawImages
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (rawImages is String) {
      var s = rawImages.trim();
      if (s.isEmpty) return [];
      s = s.replaceAll(RegExp(r'^\[|\]$'), '');
      if (s.contains(',')) {
        return s
            .split(',')
            .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [s.replaceAll('"', '').replaceAll("'", '').trim()];
    }
    return [];
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'ئەمڕۆ';
    final s = raw.toString();
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.surface;

    final title = widget.newsItem['title']?.toString() ?? '';
    final description = widget.newsItem['description']?.toString() ?? '';
    final newsType =
        widget.newsItem['news_type']?.toString() ?? 'هەواڵ';
    final date = _formatDate(widget.newsItem['created_at']);
    final imagesList = _extractAllImages(
      widget.newsItem['images'] ?? widget.newsItem['img'],
    );

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            tr('وردەکاری هەواڵ'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          backgroundColor:
          isDark ? AppColors.darkCard : AppColors.surface,
          foregroundColor:
          isDark ? Colors.white : AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🏪 Store Info
              if (_storeInfo != null) _buildStoreCard(isDark),

              // 🎯 Type Badge + Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTypeBadge(newsType),
                    const SizedBox(height: 10),
                    Text(
                      tr(title),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 📊 Stats Row
              _buildStatsRow(isDark, date),

              const SizedBox(height: 16),

              // 🖼️ Images
              if (imagesList.isNotEmpty) ...[
                _buildImageCarousel(imagesList),
                const SizedBox(height: 20),
              ],

              // 📄 Description
              _buildDescription(description, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 Store Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoreCard(bool isDark) {
    final store = _storeInfo!;
    String? profileImg = store['logo']?.toString();
    if (profileImg == null || profileImg.isEmpty) {
      profileImg = store['image']?.toString();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => StoreDetailsDialog.show(context, store),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: (profileImg != null && profileImg.isNotEmpty)
                        ? OptimizedNetworkImage(
                      imageUrl: profileImg,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      color: AppColors.primarySoft,
                      child: const Icon(
                        Icons.storefront,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tr(store['name']?.toString() ?? 'شوێن'),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: isDark
                                ? Colors.white54
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              tr(store['address']?.toString() ?? 'کەلار'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: isDark ? Colors.white54 : Colors.grey,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Type Badge
  // ═══════════════════════════════════════════════════════════
  Widget _buildTypeBadge(String newsType) {
    final color = _getTypeColor(newsType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getTypeIcon(newsType), color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            tr(newsType),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Row
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsRow(bool isDark, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr(date),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: [
                _buildStatItem(
                  icon: Icons.visibility_rounded,
                  value: '$views',
                  color: isDark
                      ? Colors.white70
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 16),
                _loading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : GestureDetector(
                  onTap: _isLiking ? null : _toggleLike,
                  child: _buildStatItem(
                    icon: isLiked
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_off_alt_rounded,
                    value: '$likes',
                    color: isLiked
                        ? AppColors.primary
                        : (isDark
                        ? Colors.white70
                        : AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 16),
                _loading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : GestureDetector(
                  onTap: _isFavoriting ? null : _toggleFavorite,
                  child: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: isFavorite
                        ? AppColors.pink
                        : (isDark
                        ? Colors.white70
                        : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          tr(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🖼️ Image Carousel
  // ═══════════════════════════════════════════════════════════
  Widget _buildImageCarousel(List<String> imagesList) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          SizedBox(
            height: 250,
            child: PageView.builder(
              itemCount: imagesList.length,
              onPageChanged: (index) {
                setState(() => _currentImageIndex = index);
              },
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _openFullScreen(imagesList[index], index),
                  child: Hero(
                    tag: 'news_img_$index',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: OptimizedNetworkImage(
                          imageUrl: imagesList[index],
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (imagesList.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_currentImageIndex + 1} / ${imagesList.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullScreen(String imageUrl, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _buildFullScreenImage(imageUrl, index),
      ),
    );
  }

  Widget _buildFullScreenImage(String imageUrl, int index) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Hero(
                tag: 'news_img_$index',
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: OptimizedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 Description
  // ═══════════════════════════════════════════════════════════
  Widget _buildDescription(String description, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
          isDark ? AppColors.darkCard : AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.border,
          ),
        ),
        child: Text(
          tr(description),
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white70 : AppColors.textPrimary,
            height: 1.7,
          ),
        ),
      ),
    );
  }
}