import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../stores/store_details_dialog.dart';
import '../news/news_details.dart';

/// ❤️ شاشەی دڵخوازەکان
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
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
          combined.add({
            'id': fav['id'],
            'dukan': store,
          });
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
          combined.add({
            'favorite_id': fav['id'],
            'news': news,
          });
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

    // 🚪 ئەگەر بەکارهێنەر نەچووەتە ژوورەوە
    if (user == null || user['id'] == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: AppBar(
            title: const Text(
              "دڵخوازەکانم",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.pink.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 60,
                      color: Colors.pink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "بۆ بینینی دڵخوازەکانت، سەرەتا پێویستە بچیتە ژوورەوە",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/auth')
                          .then((_) => setState(() {}));
                    },
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text(
                      "چوونەژوورەوە",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            toolbarHeight: 10,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: "شوێنی دڵخواز 📍"),
                    Tab(text: "هەواڵی دڵخواز 📰"),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            children: [
              // 🏪 تبەی 1: شوێنەکان
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchFavStores(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  var favStores = snapshot.data ?? [];
                  if (favStores.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.place_outlined,
                      message: "هیچ شوێنێکی دڵخوازت نییە 📍",
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: favStores.length,
                    itemBuilder: (context, index) {
                      var favS = favStores[index];
                      var store = favS['dukan'] ?? {};

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () =>
                                StoreDetailsDialog.show(context, store),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: OptimizedNetworkImage(
                                      imageUrl: store['image'] ?? '',
                                      width: 65,
                                      height: 65,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          store['name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_rounded,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                store['address'] ?? 'کەلار',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black54,
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
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                    tooltip: "سڕینەوە لە دڵخواز",
                                    onPressed: () async {
                                      await Supabase.instance.client
                                          .from('favorite_stores')
                                          .delete()
                                          .eq('id', favS['id']);
                                      if (context.mounted) setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // 📰 تبەی 2: هەواڵەکان
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchFavNews(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  var favItems = snapshot.data ?? [];

                  if (favItems.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.article_outlined,
                      message: "هیچ هەواڵێکی دڵخوازت نییە 📰",
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: favItems.length,
                    itemBuilder: (context, index) {
                      var fav = favItems[index];
                      var item = fav['news'] ?? {};
                      String firstImg = _extractFirstImage(
                        item['images'] ?? item['img'],
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      NewsDetailsScreen(newsItem: item),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: firstImg.isNotEmpty
                                        ? OptimizedNetworkImage(
                                      imageUrl: firstImg,
                                      width: 65,
                                      height: 65,
                                      fit: BoxFit.cover,
                                    )
                                        : Container(
                                      width: 65,
                                      height: 65,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.article_rounded,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item['description'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                    tooltip: "سڕینەوە لە دڵخواز",
                                    onPressed: () async {
                                      await Supabase.instance.client
                                          .from('news_favorites')
                                          .delete()
                                          .eq('id', fav['favorite_id']);
                                      if (context.mounted) setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📭 حاڵەتی بەتاڵ
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 55, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}