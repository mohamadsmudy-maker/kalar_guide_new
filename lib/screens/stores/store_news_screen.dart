import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../news/news_details.dart';
import '../admin/admin_news.dart';

class StoreNewsScreen extends StatefulWidget {
  final Map<String, dynamic> store;
  const StoreNewsScreen({super.key, required this.store});

  @override
  State<StoreNewsScreen> createState() => _StoreNewsScreenState();
}

class _StoreNewsScreenState extends State<StoreNewsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _storeNews = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStoreNews();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStoreNews() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('news')
          .select()
          .eq('store_id', widget.store['id'])
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _storeNews = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    final store = widget.store;
    String rawName = (store['name'] ?? 'شوێن').toString().trim();
    if (rawName.startsWith('فرۆشگای')) {
      rawName = rawName.replaceFirst('فرۆشگای', '').trim();
    } else if (rawName.startsWith('فرۆشگا')) {
      rawName = rawName.replaceFirst('فرۆشگا', '').trim();
    }

    final user = AuthSessionManager.currentUser;
    final isVendorForThisStore = user != null &&
        user['role'] == 'vendor' &&
        user['store_id']?.toString() == store['id']?.toString();

    var filteredNews = _storeNews.where((news) {
      final title = (news['title'] ?? '').toString().toLowerCase();
      final desc = (news['description'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return _searchQuery.isEmpty || title.contains(q) || desc.contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    OptimizedNetworkImage(
                      imageUrl: store['image'] ?? '',
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 16,
                      left: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  rawName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Colors.white, size: 16),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.white70, size: 13),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  store['address'] ?? 'کەلار',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: const InputDecoration(
                          hintText: 'گەڕان بەدوای هەواڵەکاندا...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'هەواڵ و ئاگادارییەکان 📰',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                        if (isVendorForThisStore)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'زیادکردنی هەواڵ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddNewsScreen(forcedStoreId: store['id'].toString()),
                                ),
                              ).then((_) => _fetchStoreNews());
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            filteredNews.isEmpty
                ? const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.article_outlined, size: 60, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'هیچ هەواڵێک بۆ ئەم شوێنە نەدۆزرایەوە 📰',
                      style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  var news = filteredNews[index];
                  String firstImg = _extractFirstImage(news['images'] ?? news['img']);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      title: Text(
                        news['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          news['description'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewsDetailsScreen(newsItem: news),
                          ),
                        );
                      },
                    ),
                  );
                },
                childCount: filteredNews.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}