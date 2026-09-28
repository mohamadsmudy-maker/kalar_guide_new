import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../stores/store_details_dialog.dart';

/// 📰 شاشەی وردەکاری هەواڵ
class NewsDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> newsItem;

  const NewsDetailsScreen({super.key, required this.newsItem});

  @override
  State<NewsDetailsScreen> createState() => _NewsDetailsScreenState();
}

class _NewsDetailsScreenState extends State<NewsDetailsScreen> {
  late int likes;
  bool isLiked = false;
  bool isFavorite = false;
  bool _loading = true;
  int _currentImageIndex = 0;
  Map<String, dynamic>? _storeInfo;

  @override
  void initState() {
    super.initState();
    likes = widget.newsItem['likes'] ?? 0;
    _checkUserStatus();
    _fetchStoreInfo();
  }

  Future<void> _fetchStoreInfo() async {
    try {
      final storeId = widget.newsItem['store_id'];
      if (storeId != null) {
        final res = await Supabase.instance.client
            .from('dukan')
            .select('id, name, logo, image, address, type')
            .eq('id', storeId)
            .maybeSingle();

        if (res != null && mounted) {
          setState(() => _storeInfo = res);
        }
      }
    } catch (_) {}
  }

  Future<void> _checkUserStatus() async {
    final user = AuthSessionManager.currentUser;
    if (user == null || user['id'] == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      String userId = user['id'].toString();
      int newsId = widget.newsItem['id'];

      final likeRes = await Supabase.instance.client
          .from('news_likes')
          .select()
          .eq('user_id', userId)
          .eq('news_id', newsId)
          .maybeSingle();

      final favRes = await Supabase.instance.client
          .from('news_favorites')
          .select()
          .eq('user_id', userId)
          .eq('news_id', newsId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          isLiked = likeRes != null;
          isFavorite = favRes != null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) return;

    String userId = user['id'].toString();
    int newsId = widget.newsItem['id'];

    setState(() {
      if (isLiked) {
        likes = (likes > 0) ? likes - 1 : 0;
        isLiked = false;
      } else {
        likes++;
        isLiked = true;
      }
    });

    try {
      if (!isLiked) {
        await Supabase.instance.client
            .from('news_likes')
            .delete()
            .eq('user_id', userId)
            .eq('news_id', newsId);
      } else {
        await Supabase.instance.client.from('news_likes').insert({
          'user_id': userId,
          'news_id': newsId,
        });
      }

      await Supabase.instance.client
          .from('news')
          .update({'likes': likes})
          .eq('id', newsId);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) return;

    String userId = user['id'].toString();
    int newsId = widget.newsItem['id'];

    setState(() => isFavorite = !isFavorite);

    try {
      if (!isFavorite) {
        await Supabase.instance.client
            .from('news_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('news_id', newsId);
      } else {
        await Supabase.instance.client.from('news_favorites').insert({
          'user_id': userId,
          'news_id': newsId,
        });
      }
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    String title = widget.newsItem['title'] ?? '';
    String description = widget.newsItem['description'] ?? '';
    String date = widget.newsItem['created_at'] != null
        ? widget.newsItem['created_at'].toString().substring(0, 10)
        : 'ئەمڕۆ';
    int views = widget.newsItem['views'] ?? 0;

    List<String> imagesList = _extractAllImages(
      widget.newsItem['images'] ?? widget.newsItem['img'],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "وردەکاری هەواڵ",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🏛️ بەشی شوێن
              if (_storeInfo != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => StoreDetailsDialog.show(
                        context,
                        _storeInfo!,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: (() {
                                String? profileImg = _storeInfo!['logo'];
                                if (profileImg == null ||
                                    profileImg.toString().isEmpty) {
                                  profileImg = _storeInfo!['image'];
                                }
                                return profileImg != null &&
                                    profileImg.toString().isNotEmpty
                                    ? OptimizedNetworkImage(
                                  imageUrl: profileImg,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                                    : Container(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.storefront,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                );
                              }()),
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
                                        _storeInfo!['name'] ?? 'شوێن',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: Color(0xFF1A1A2E),
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
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 12,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        _storeInfo!['address'] ?? 'کەلار',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
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
                          const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 📰 ناونیشان
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFF1A1A2E),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 📊 ئامارەکان
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          _buildStatItem(
                            icon: Icons.visibility_rounded,
                            value: "$views",
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 16),
                          _loading
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : GestureDetector(
                            onTap: _toggleLike,
                            child: _buildStatItem(
                              icon: isLiked
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_off_alt_rounded,
                              value: "$likes",
                              color: isLiked
                                  ? AppColors.primary
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _loading
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : GestureDetector(
                            onTap: _toggleFavorite,
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color: isFavorite
                                  ? Colors.redAccent
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🖼️ وێنەکان
              if (imagesList.isNotEmpty)
                Padding(
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
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: OptimizedNetworkImage(
                                  imageUrl: imagesList[index],
                                  width: double.infinity,
                                  height: 250,
                                  fit: BoxFit.cover,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
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
                                  "${_currentImageIndex + 1} / ${imagesList.length}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // 📄 وەسف
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}