import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../widgets/ultra_pro/ultra_pro_components.dart';
import '../stores/store_details_dialog.dart';
import '../news/news_details.dart';

/// ❤️ شاشەی دڵخوازەکان — ULTRA PRO
class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const FavoritesScreen({super.key, this.onMenuTap});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchFavStores() async {
    final user = AuthSessionManager.currentUser;
    if (user == null || user['id'] == null) return [];

    try {
      final favRes = await Supabase.instance.client
          .from('favorite_stores')
          .select('id, store_id')
          .eq('user_id', user['id']);

      final favList = List<Map<String, dynamic>>.from(favRes as List);
      if (favList.isEmpty) return [];

      final storeIds = favList.map((f) => f['store_id']).toList();

      final storesRes = await Supabase.instance.client
          .from('dukan')
          .select('*')
          .inFilter('id', storeIds);

      final storesList = List<Map<String, dynamic>>.from(storesRes as List);

      List<Map<String, dynamic>> combined = [];
      for (var fav in favList) {
        var store = storesList.firstWhere(
              (s) => s['id'].toString() == fav['store_id'].toString(),
          orElse: () => {},
        );
        if (store.isNotEmpty) {
          combined.add({'id': fav['id'], 'dukan': store});
        }
      }
      return combined;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFavNews() async {
    final user = AuthSessionManager.currentUser;
    if (user == null || user['id'] == null) return [];

    try {
      final favRes = await Supabase.instance.client
          .from('news_favorites')
          .select('id, news_id')
          .eq('user_id', user['id']);

      final favList = List<Map<String, dynamic>>.from(favRes as List);
      if (favList.isEmpty) return [];

      final newsIds = favList.map((f) => f['news_id']).toList();

      final newsRes = await Supabase.instance.client
          .from('news')
          .select('*')
          .inFilter('id', newsIds);

      final newsList = List<Map<String, dynamic>>.from(newsRes as List);

      List<Map<String, dynamic>> combined = [];
      for (var fav in favList) {
        var news = newsList.firstWhere(
              (n) => n['id'].toString() == fav['news_id'].toString(),
          orElse: () => {},
        );
        if (news.isNotEmpty) {
          combined.add({'favorite_id': fav['id'], 'news': news});
        }
      }
      return combined;
    } catch (_) {
      return [];
    }
  }

  String _extractFirstImage(dynamic rawImages) {
    if (rawImages == null) return '';
    if (rawImages is List) {
      if (rawImages.isEmpty) return '';
      return rawImages.first.toString().trim();
    }
    if (rawImages is String) {
      var s = rawImages.trim();
      if (s.isEmpty) return '';
      s = s.replaceAll(RegExp(r'^\[|\]$'), '');
      s = s.replaceAll('"', '').replaceAll("'", '');
      if (s.contains(',')) s = s.split(',').first;
      return s.trim();
    }
    return rawImages.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSessionManager.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🚪 ئەگەر نەچووە ژوورەوە
    if (user == null || user['id'] == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor:
          isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
          appBar: AppBar(
            title: const Text(
              'دڵخوازەکان',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
            foregroundColor: isDark ? Colors.white : AppColors.primary,
            centerTitle: true,
            elevation: 0,
          ),
          body: ProEmptyState(
            icon: Icons.favorite_rounded,
            title: 'پێویستە بچیتە ژوورەوە',
            subtitle: 'بۆ بینینی دڵخوازەکانت سەرەتا بچۆ ژوورەوە',
            color: Colors.pink,
            isDark: isDark,
            actionLabel: 'چوونەژوورەوە',
            onAction: () {
              Navigator.pushNamed(context, '/auth').then((_) {
                if (mounted) setState(() {});
              });
            },
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════════
            // 🎨 هێدەری پریمیۆم
            // ═══════════════════════════════════════════
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: widget.onMenuTap != null
                  ? IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
                onPressed: widget.onMenuTap,
              )
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                        const Color(0xFF1A1A22),
                        const Color(0xFF252530),
                      ]
                          : [
                        Colors.white,
                        const Color(0xFFE91E63)
                            .withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE91E63),
                                  Color(0xFF9C27B0),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE91E63)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'دڵخوازەکانم',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'هەموو شتە دڵخوازەکانت',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F0F14)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE91E63),
                          Color(0xFF9C27B0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE91E63)
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? Colors.white60
                        : Colors.grey.shade700,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.place_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('شوێنەکان'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('هەواڵەکان'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════
            // 📋 Tab Content
            // ═══════════════════════════════════════════
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFavStoresTab(isDark),
                  _buildFavNewsTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavStoresTab(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchFavStores(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE91E63)),
          );
        }

        final favStores = snapshot.data ?? [];

        if (favStores.isEmpty) {
          return ProEmptyState(
            icon: Icons.place_outlined,
            title: 'هیچ شوێنێکی دڵخوازت نییە',
            subtitle: 'شوێنەکان بپشکنە و ئەوانەی حەزت لێیە\nزیاد بکە بۆ دڵخوازەکان',
            color: const Color(0xFFE91E63),
            isDark: isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favStores.length,
          itemBuilder: (context, index) {
            final favS = favStores[index];
            final store = favS['dukan'] ?? {};

            return _buildFavStoreCard(favS, store, isDark);
          },
        );
      },
    );
  }

  Widget _buildFavStoreCard(
      Map<String, dynamic> favS,
      Map<String, dynamic> store,
      bool isDark,
      ) {
    return ProCard(
      isDark: isDark,
      glowColor: const Color(0xFFE91E63),
      padding: EdgeInsets.zero,
      radius: 22,
      onTap: () => StoreDetailsDialog.show(context, store),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 🖼️ وێنە
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE91E63)
                          .withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: OptimizedNetworkImage(
                      imageUrl: store['image'] ?? '',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 📝 زانیاری
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        store['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: Color(0xFFE91E63),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              store['address'] ?? 'کەلار',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (store['category'] != null) ...[
                        const SizedBox(height: 6),
                        ProBadge(
                          label: store['category'].toString(),
                          icon: Icons.category_rounded,
                          color: const Color(0xFFE91E63),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ⚡ دوگمەکان
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F0F14)
                  : const Color(0xFFF9F9FB),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.visibility_rounded,
                    label: 'بینین',
                    color: AppColors.primary,
                    isDark: isDark,
                    onTap: () => StoreDetailsDialog.show(context, store),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade300,
                ),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete_rounded,
                    label: 'لابردن',
                    color: Colors.redAccent,
                    isDark: isDark,
                    onTap: () async {
                      await Supabase.instance.client
                          .from('favorite_stores')
                          .delete()
                          .eq('id', favS['id']);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavNewsTab(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchFavNews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE91E63)),
          );
        }

        final favItems = snapshot.data ?? [];

        if (favItems.isEmpty) {
          return ProEmptyState(
            icon: Icons.article_outlined,
            title: 'هیچ هەواڵێکی دڵخوازت نییە',
            subtitle: 'هەواڵەکان بپشکنە و ئەوانەی حەزت لێیە\nزیاد بکە بۆ دڵخوازەکان',
            color: const Color(0xFF9C27B0),
            isDark: isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favItems.length,
          itemBuilder: (context, index) {
            final fav = favItems[index];
            final item = fav['news'] ?? {};
            final firstImg = _extractFirstImage(item['images'] ?? item['img']);

            return ProCard(
              isDark: isDark,
              glowColor: const Color(0xFF9C27B0),
              padding: EdgeInsets.zero,
              radius: 22,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewsDetailsScreen(newsItem: item),
                  ),
                );
              },
              child: Column(
                children: [
                  // 🖼️ وێنە
                  if (firstImg.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: OptimizedNetworkImage(
                        imageUrl: firstImg,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ناونیشان
                        Text(
                          item['title'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // وەسف
                        Text(
                          item['description'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.visibility_rounded,
                                label: 'بینین',
                                color: AppColors.primary,
                                isDark: isDark,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewsDetailsScreen(
                                        newsItem: item,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.delete_rounded,
                                label: 'لابردن',
                                color: Colors.redAccent,
                                isDark: isDark,
                                onTap: () async {
                                  await Supabase.instance.client
                                      .from('news_favorites')
                                      .delete()
                                      .eq('id', fav['favorite_id']);
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}