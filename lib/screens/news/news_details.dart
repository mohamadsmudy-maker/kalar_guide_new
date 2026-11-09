import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../stores/store_details_dialog.dart';
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';
import '../../widgets/common/auto_translate.dart';
import 'package:share_plus/share_plus.dart';

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

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  /// «ئەمڕۆ» / «دوێنێ» / «٢٠٢٦/١١/٠٨»
  String _niceDate(dynamic raw) {
    final d = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (d == null) return tr('ئەمڕۆ');
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return tr('ئەمڕۆ');
    if (diff == 1) return tr('دوێنێ');
    String two(int n) => n.toString().padLeft(2, '0');
    return PlaceDisplay.digits('${d.year}/${two(d.month)}/${two(d.day)}');
  }

  Future<void> _share(String title, String description) async {
    HapticFeedback.selectionClick();
    final snippet = description.length > 280
        ? '${description.substring(0, 280)}…'
        : description;
    await Share.share(
        '${tr(title)}\n\n$snippet\n\n— ${tr('ئەپی ڕێبەری کەلار')}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFF6F8FB);
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final sub = isDark ? Colors.white60 : const Color(0xFF64748B);

    final title = widget.newsItem['title']?.toString() ?? '';
    final description = widget.newsItem['description']?.toString() ?? '';
    final newsType = widget.newsItem['news_type']?.toString() ?? 'هەواڵ';
    final date = _niceDate(widget.newsItem['created_at']);
    final images =
        _extractAllImages(widget.newsItem['images'] ?? widget.newsItem['img']);
    final lang = AppLang.code;
    final topPad = MediaQuery.paddingOf(context).top;
    final heroHeight = images.isEmpty ? 150.0 + topPad : 360.0;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        extendBodyBehindAppBar: true,
        bottomNavigationBar: _buildActionBar(isDark, card, title, description),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 🖼️ وێنە (بچووک دەبێتەوە لە کاتی سکرۆڵدا) ──
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: heroHeight,
              backgroundColor:
                  isDark ? const Color(0xFF0F172A) : AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: _GlassButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: tr('گەڕانەوە'),
                  onTap: () => Navigator.maybePop(context),
                ),
              ),
              actions: [
                _GlassButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: tr('هاوبەشکردن'),
                  onTap: () => _share(title, description),
                ),
                const SizedBox(width: 8),
                _GlassButton(
                  icon: isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  tooltip: tr('دڵخواز'),
                  active: isFavorite,
                  onTap: _isFavoriting ? null : _toggleFavorite,
                ),
                const SizedBox(width: 12),
              ],
              // گۆشەی خڕی بەشی ناوەڕۆک بەسەر وێنەکەدا
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: images.isEmpty
                    ? _buildNoImageHeader(newsType)
                    : _buildHeroGallery(images),
              ),
            ),

            // ── 📄 ناوەڕۆک ──
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // جۆر + بەروار
                      Row(
                        children: [
                          _Pill(
                            icon: _getTypeIcon(newsType),
                            label: tr(newsType),
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          _Pill(
                              icon: Icons.schedule_rounded,
                              label: date,
                              color: AppColors.toneSlate),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // ناونیشان
                      AutoTranslate(
                        text: title,
                        lang: lang,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 25,
                          height: 1.35,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ئامار
                      Row(
                        children: [
                          _Stat(
                              icon: Icons.visibility_rounded,
                              value: PlaceDisplay.digits(views),
                              color: sub),
                          const SizedBox(width: 16),
                          _Stat(
                            icon: Icons.thumb_up_alt_rounded,
                            value: PlaceDisplay.digits(likes),
                            color: isLiked ? AppColors.primary : sub,
                          ),
                          if (images.length > 1) ...[
                            const SizedBox(width: 16),
                            _Stat(
                              icon: Icons.photo_library_rounded,
                              value: PlaceDisplay.digits(images.length),
                              color: sub,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      // 🏪 بڵاوکەرەوە
                      if (_storeInfo != null) _buildStoreCard(isDark),
                      if (_storeInfo != null) const SizedBox(height: 18),
                      // دەق
                      if (description.trim().isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFE8EDF3),
                            ),
                          ),
                          child: AutoTranslate(
                            text: description,
                            lang: lang,
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.9,
                                color: ink.withValues(alpha: 0.88)),
                          ),
                        ),
                      // وێنەکانی تر
                      if (images.length > 1) ...[
                        const SizedBox(height: 22),
                        Text(
                          tr('وێنەکان'),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: ink),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => _openFullScreen(images[i], i),
                              child: OptimizedNetworkImage(
                                imageUrl: images[i],
                                width: 120,
                                height: 92,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// وێنەکان: PageView + ڕەنگی تاریک لە خوارەوە + ژمارەی وێنە
  Widget _buildHeroGallery(List<String> images) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _openFullScreen(images[i], i),
            child: Hero(
              tag: 'news_img_$i',
              child:
                  OptimizedNetworkImage(imageUrl: images[i], fit: BoxFit.cover),
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.25, 0.6, 1],
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x80000000)
                ],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentImageIndex ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                          alpha: i == _currentImageIndex ? 1 : 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNoImageHeader(String newsType) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(_getTypeIcon(newsType),
          size: 56, color: Colors.white.withValues(alpha: 0.35)),
    );
  }

  /// خوارەوە: لایک (گەورە) + هاوبەشکردن
  Widget _buildActionBar(
      bool isDark, Color card, String title, String description) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: card,
          border: Border(
            top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE8EDF3)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: isLiked
                      ? AppColors.primary
                      : AppColors.primary
                          .withValues(alpha: isDark ? 0.18 : 0.10),
                  foregroundColor: isLiked ? Colors.white : AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLiking || _loading ? null : _toggleLike,
                icon: Icon(isLiked
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_off_alt_rounded),
                label: Text(
                  '${tr(isLiked ? 'بەدڵم بوو' : 'بەدڵمە')}  ${PlaceDisplay.digits(likes)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              width: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(
                      color: isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _share(title, description),
                child: Icon(Icons.ios_share_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimary),
              ),
            ),
          ],
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
      padding: EdgeInsets.zero,
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                              maxLines: 2,
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
                              tr(PlaceDisplay.address(store['address'])),
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
                  Icons.chevron_right_rounded,
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
  void _openFullScreen(String imageUrl, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _buildFullScreenImage(imageUrl, index),
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
}

/// دوگمەی شووشەیی سەر وێنە
class _GlassButton extends StatelessWidget {
  const _GlassButton(
      {required this.icon,
      required this.onTap,
      this.tooltip,
      this.active = false});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.black.withValues(alpha: 0.32),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon,
                color: active ? const Color(0xFFFFD54F) : Colors.white,
                size: 21),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.color});
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 5),
      Text(value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}
