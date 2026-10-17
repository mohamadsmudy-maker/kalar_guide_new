import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../widgets/ultra_pro/ultra_pro_components.dart';
import '../stores/store_details_dialog.dart';
import '../news/news_details.dart';

/// ❤️ شاشەی دڵخوازەکان — ULTRA PRO V2
class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const FavoritesScreen({super.key, this.onMenuTap});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  late TabController _tabController;
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _entryAnimation;
  late Animation<double> _pulseAnimation;

  // ⭐ Search
  String _storeSearchQuery = '';
  String _newsSearchQuery = '';

  // ⭐ Sort
  String _storeSortBy = 'recent';
  String _newsSortBy = 'recent';

  // ⭐ Batch
  bool _batchMode = false;
  final Set<String> _selectedStoreIds = {};
  final Set<String> _selectedNewsIds = {};

  // ⭐ Data
  List<Map<String, dynamic>> _favStores = [];
  List<Map<String, dynamic>> _favNews = [];
  bool _loadingStores = true;
  bool _loadingNews = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 Data Loading
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadAll() async {
    await Future.wait([
      _loadFavStores(),
      _loadFavNews(),
    ]);
    if (mounted) _entryController.forward(from: 0);
  }

  Future<void> _loadFavStores() async {
    if (mounted) setState(() => _loadingStores = true);

    try {
      final user = AuthSessionManager.currentUser;
      if (user == null || user['id'] == null) {
        if (mounted) {
          setState(() {
            _favStores = [];
            _loadingStores = false;
          });
        }
        return;
      }

      final favRes = await Supabase.instance.client
          .from('favorite_stores')
          .select('id, store_id, created_at')
          .eq('user_id', user['id'])
          .order('created_at', ascending: false);

      final favList = List<Map<String, dynamic>>.from(favRes as List);
      if (favList.isEmpty) {
        if (mounted) {
          setState(() {
            _favStores = [];
            _loadingStores = false;
          });
        }
        return;
      }

      final storeIds = favList.map((f) => f['store_id']).toList();

      final storesRes = await Supabase.instance.client
          .from('dukan')
          .select('*')
          .inFilter('id', storeIds);

      final storesList = List<Map<String, dynamic>>.from(storesRes as List);

      final combined = <Map<String, dynamic>>[];
      for (var fav in favList) {
        final store = storesList.firstWhere(
              (s) => s['id'].toString() == fav['store_id'].toString(),
          orElse: () => {},
        );
        if (store.isNotEmpty) {
          combined.add({
            'id': fav['id'],
            'created_at': fav['created_at'],
            'dukan': store,
          });
        }
      }

      if (mounted) {
        setState(() {
          _favStores = combined;
          _loadingStores = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load fav stores error: $e');
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  Future<void> _loadFavNews() async {
    if (mounted) setState(() => _loadingNews = true);

    try {
      final user = AuthSessionManager.currentUser;
      if (user == null || user['id'] == null) {
        if (mounted) {
          setState(() {
            _favNews = [];
            _loadingNews = false;
          });
        }
        return;
      }

      final favRes = await Supabase.instance.client
          .from('news_favorites')
          .select('id, news_id, created_at')
          .eq('user_id', user['id'])
          .order('created_at', ascending: false);

      final favList = List<Map<String, dynamic>>.from(favRes as List);
      if (favList.isEmpty) {
        if (mounted) {
          setState(() {
            _favNews = [];
            _loadingNews = false;
          });
        }
        return;
      }

      final newsIds = favList.map((f) => f['news_id']).toList();

      final newsRes = await Supabase.instance.client
          .from('news')
          .select('*')
          .inFilter('id', newsIds);

      final newsList = List<Map<String, dynamic>>.from(newsRes as List);

      final combined = <Map<String, dynamic>>[];
      for (var fav in favList) {
        final news = newsList.firstWhere(
              (n) => n['id'].toString() == fav['news_id'].toString(),
          orElse: () => {},
        );
        if (news.isNotEmpty) {
          combined.add({
            'favorite_id': fav['id'],
            'created_at': fav['created_at'],
            'news': news,
          });
        }
      }

      if (mounted) {
        setState(() {
          _favNews = combined;
          _loadingNews = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load fav news error: $e');
      if (mounted) setState(() => _loadingNews = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Filter + Sort
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredStores {
    var list = List<Map<String, dynamic>>.from(_favStores);

    if (_storeSearchQuery.isNotEmpty) {
      final q = _storeSearchQuery.toLowerCase();
      list = list.where((item) {
        final store = item['dukan'] ?? {};
        final name = (store['name'] ?? '').toString().toLowerCase();
        final address = (store['address'] ?? '').toString().toLowerCase();
        return name.contains(q) || address.contains(q);
      }).toList();
    }

    if (_storeSortBy == 'name') {
      list.sort((a, b) {
        final aName = (a['dukan']?['name'] ?? '').toString();
        final bName = (b['dukan']?['name'] ?? '').toString();
        return aName.compareTo(bName);
      });
    }

    return list;
  }

  List<Map<String, dynamic>> get _filteredNews {
    var list = List<Map<String, dynamic>>.from(_favNews);

    if (_newsSearchQuery.isNotEmpty) {
      final q = _newsSearchQuery.toLowerCase();
      list = list.where((item) {
        final news = item['news'] ?? {};
        final title = (news['title'] ?? '').toString().toLowerCase();
        final desc = (news['description'] ?? '').toString().toLowerCase();
        return title.contains(q) || desc.contains(q);
      }).toList();
    }

    if (_newsSortBy == 'title') {
      list.sort((a, b) {
        final aTitle = (a['news']?['title'] ?? '').toString();
        final bTitle = (b['news']?['title'] ?? '').toString();
        return aTitle.compareTo(bTitle);
      });
    }

    return list;
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ Delete Actions
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteStoreFavorite(String id) async {
    try {
      await Supabase.instance.client
          .from('favorite_stores')
          .delete()
          .eq('id', id);
      HapticFeedback.mediumImpact();
      await _loadFavStores();
    } catch (e) {
      debugPrint('❌ Delete error: $e');
    }
  }

  Future<void> _deleteNewsFavorite(String id) async {
    try {
      await Supabase.instance.client
          .from('news_favorites')
          .delete()
          .eq('id', id);
      HapticFeedback.mediumImpact();
      await _loadFavNews();
    } catch (e) {
      debugPrint('❌ Delete error: $e');
    }
  }

  Future<void> _deleteBatchStores() async {
    if (_selectedStoreIds.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('favorite_stores')
          .delete()
          .inFilter('id', _selectedStoreIds.toList());
      HapticFeedback.heavyImpact();
      setState(() {
        _batchMode = false;
        _selectedStoreIds.clear();
      });
      await _loadFavStores();
    } catch (e) {
      debugPrint('❌ Batch delete error: $e');
    }
  }

  Future<void> _deleteBatchNews() async {
    if (_selectedNewsIds.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('news_favorites')
          .delete()
          .inFilter('id', _selectedNewsIds.toList());
      HapticFeedback.heavyImpact();
      setState(() {
        _batchMode = false;
        _selectedNewsIds.clear();
      });
      await _loadFavNews();
    } catch (e) {
      debugPrint('❌ Batch delete error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
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
                if (mounted) {
                  setState(() {});
                  _loadAll();
                }
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
            _buildAppBar(isDark),
            SliverToBoxAdapter(child: _buildTabBar(isDark)),
            _buildTabContent(isDark),
          ],
        ),
        floatingActionButton: _batchMode
            ? FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _batchMode = false;
              _selectedStoreIds.clear();
              _selectedNewsIds.clear();
            });
          },
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.close_rounded),
          label: const Text(
            'هەڵوەشاندنەوە',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        )
            : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isDark) {
    final totalCount = _favStores.length + _favNews.length;

    return SliverAppBar(
      expandedHeight: 180,
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
      actions: [
        IconButton(
          icon: Icon(
            _batchMode ? Icons.close_rounded : Icons.checklist_rounded,
            color: isDark ? Colors.white : AppColors.primary,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _batchMode = !_batchMode;
              _selectedStoreIds.clear();
              _selectedNewsIds.clear();
            });
          },
          tooltip: _batchMode ? 'هەڵوەشاندنەوە' : 'هەڵبژاردنی چەند',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A1A22), const Color(0xFF252530)]
                  : [
                Colors.white,
                const Color(0xFFE91E63).withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // ⭐ Animated circles
              Positioned(
                top: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                          const Color(0xFFE91E63).withValues(alpha: 0.08),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 70, 20, 12),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.4,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE91E63),
                                    Color(0xFF9C27B0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91E63)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'دڵخوازەکان',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE91E63)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.favorite_rounded,
                                        color: Color(0xFFE91E63),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$totalCount دڵخواز',
                                        style: const TextStyle(
                                          color: Color(0xFFE91E63),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
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
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Tab Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor:
          isDark ? Colors.white60 : Colors.grey.shade700,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            Tab(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.place_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('شوێنەکان'),
                  if (_favStores.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_favStores.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.article_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('هەواڵەکان'),
                  if (_favNews.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_favNews.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Tab Content
  // ═══════════════════════════════════════════════════════════
  Widget _buildTabContent(bool isDark) {
    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildFavStoresTab(isDark),
          _buildFavNewsTab(isDark),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 Fav Stores Tab
  // ═══════════════════════════════════════════════════════════
  Widget _buildFavStoresTab(bool isDark) {
    if (_loadingStores) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    final stores = _filteredStores;

    if (stores.isEmpty) {
      return _buildEmptyState(
        isDark: isDark,
        icon: Icons.place_outlined,
        title: _storeSearchQuery.isNotEmpty
            ? 'هیچ ئەنجامێک نەدۆزرایەوە'
            : 'هیچ شوێنێکی دڵخوازت نییە',
        subtitle: _storeSearchQuery.isNotEmpty
            ? 'گەڕانەکەت هیچ ئەنجامێکی نەبوو'
            : 'شوێنەکان بپشکنە و ئەوانەی حەزت لێیە\nزیاد بکە بۆ دڵخوازەکان',
        color: const Color(0xFFE91E63),
      );
    }

    return Column(
      children: [
        _buildSearchBar(
          isDark: isDark,
          hint: 'گەڕان بەدوای شوێنەکان...',
          value: _storeSearchQuery,
          onChanged: (v) => setState(() => _storeSearchQuery = v),
          color: const Color(0xFFE91E63),
        ),
        _buildSortBar(
          isDark: isDark,
          currentSort: _storeSortBy,
          options: [
            {'key': 'recent', 'label': 'نوێترین', 'icon': Icons.schedule_rounded},
            {'key': 'name', 'label': 'ناو', 'icon': Icons.abc_rounded},
          ],
          color: const Color(0xFFE91E63),
          onChanged: (v) => setState(() => _storeSortBy = v),
        ),
        if (_batchMode)
          _buildBatchBar(
            isDark: isDark,
            selectedCount: _selectedStoreIds.length,
            totalCount: stores.length,
            color: const Color(0xFFE91E63),
            onSelectAll: () {
              setState(() {
                if (_selectedStoreIds.length == stores.length) {
                  _selectedStoreIds.clear();
                } else {
                  _selectedStoreIds.clear();
                  _selectedStoreIds.addAll(
                    stores.map((s) => s['id'].toString()),
                  );
                }
              });
            },
            onDelete: _deleteBatchStores,
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final favS = stores[index];
              final store = favS['dukan'] ?? {};
              final storeId = favS['id'].toString();
              final isSelected = _selectedStoreIds.contains(storeId);

              final card = _buildFavStoreCard(
                favS,
                store,
                isDark,
                isSelected: isSelected,
                onSelect: () {
                  if (_batchMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedStoreIds.remove(storeId);
                      } else {
                        _selectedStoreIds.add(storeId);
                      }
                    });
                  }
                },
              );

              // ⭐ Animation
              if (index >= 6) return card;

              return AnimatedBuilder(
                animation: _entryAnimation,
                builder: (context, child) {
                  final delay = (index * 0.08).clamp(0.0, 0.5);
                  final progress = ((_entryAnimation.value - delay) / 0.4)
                      .clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - progress)),
                    child: Opacity(opacity: progress, child: child),
                  );
                },
                child: card,
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📰 Fav News Tab
  // ═══════════════════════════════════════════════════════════
  Widget _buildFavNewsTab(bool isDark) {
    if (_loadingNews) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    final newsItems = _filteredNews;

    if (newsItems.isEmpty) {
      return _buildEmptyState(
        isDark: isDark,
        icon: Icons.article_outlined,
        title: _newsSearchQuery.isNotEmpty
            ? 'هیچ ئەنجامێک نەدۆزرایەوە'
            : 'هیچ هەواڵێکی دڵخوازت نییە',
        subtitle: _newsSearchQuery.isNotEmpty
            ? 'گەڕانەکەت هیچ ئەنجامێکی نەبوو'
            : 'هەواڵەکان بپشکنە و ئەوانەی حەزت لێیە\nزیاد بکە بۆ دڵخوازەکان',
        color: const Color(0xFF9C27B0),
      );
    }

    return Column(
      children: [
        _buildSearchBar(
          isDark: isDark,
          hint: 'گەڕان بەدوای هەواڵەکان...',
          value: _newsSearchQuery,
          onChanged: (v) => setState(() => _newsSearchQuery = v),
          color: const Color(0xFF9C27B0),
        ),
        _buildSortBar(
          isDark: isDark,
          currentSort: _newsSortBy,
          options: [
            {'key': 'recent', 'label': 'نوێترین', 'icon': Icons.schedule_rounded},
            {'key': 'title', 'label': 'ناونیشان', 'icon': Icons.abc_rounded},
          ],
          color: const Color(0xFF9C27B0),
          onChanged: (v) => setState(() => _newsSortBy = v),
        ),
        if (_batchMode)
          _buildBatchBar(
            isDark: isDark,
            selectedCount: _selectedNewsIds.length,
            totalCount: newsItems.length,
            color: const Color(0xFF9C27B0),
            onSelectAll: () {
              setState(() {
                if (_selectedNewsIds.length == newsItems.length) {
                  _selectedNewsIds.clear();
                } else {
                  _selectedNewsIds.clear();
                  _selectedNewsIds.addAll(
                    newsItems.map((n) => n['favorite_id'].toString()),
                  );
                }
              });
            },
            onDelete: _deleteBatchNews,
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: newsItems.length,
            itemBuilder: (context, index) {
              final fav = newsItems[index];
              final item = fav['news'] ?? {};
              final firstImg = _extractFirstImage(item['images'] ?? item['img']);
              final favId = fav['favorite_id'].toString();
              final isSelected = _selectedNewsIds.contains(favId);

              final card = _buildFavNewsCard(
                fav: fav,
                item: item,
                firstImg: firstImg,
                isDark: isDark,
                isSelected: isSelected,
                onSelect: () {
                  if (_batchMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedNewsIds.remove(favId);
                      } else {
                        _selectedNewsIds.add(favId);
                      }
                    });
                  }
                },
              );

              // ⭐ Animation
              if (index >= 6) return card;

              return AnimatedBuilder(
                animation: _entryAnimation,
                builder: (context, child) {
                  final delay = (index * 0.08).clamp(0.0, 0.5);
                  final progress = ((_entryAnimation.value - delay) / 0.4)
                      .clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - progress)),
                    child: Opacity(opacity: progress, child: child),
                  );
                },
                child: card,
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar({
    required bool isDark,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value.isNotEmpty
                ? color.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: onChanged,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (value.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
                onPressed: () => onChanged(''),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔀 Sort Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSortBar({
    required bool isDark,
    required String currentSort,
    required List<Map<String, dynamic>> options,
    required Color color,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: 14,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
          const SizedBox(width: 8),
          ...options.map((opt) {
            final isSelected = currentSort == opt['key'];
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(opt['key'] as String);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : (isDark
                        ? const Color(0xFF1A1A22)
                        : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                      isSelected ? color : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        opt['icon'] as IconData,
                        size: 11,
                        color: isSelected
                            ? color
                            : (isDark ? Colors.white54 : Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? color
                              : (isDark ? Colors.white54 : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Text(
            '${currentSort == "recent" ? options[0]["label"] : options[1]["label"]}',
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Batch Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildBatchBar({
    required bool isDark,
    required int selectedCount,
    required int totalCount,
    required Color color,
    required VoidCallback onSelectAll,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            '$selectedCount / $totalCount هەڵبژێردراو',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelectAll();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedCount == totalCount ? 'هەڵوەشاندنەوە' : 'هەموو',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (selectedCount > 0)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'سڕینەوە',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
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

  // ═══════════════════════════════════════════════════════════
  // 🎴 Fav Store Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildFavStoreCard(
      Map<String, dynamic> favS,
      Map<String, dynamic> store,
      bool isDark, {
        required bool isSelected,
        required VoidCallback onSelect,
      }) {
    return GestureDetector(
      onTap: () {
        if (_batchMode) {
          onSelect();
        } else {
          StoreDetailsDialog.show(context, store);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE91E63)
                : const Color(0xFFE91E63).withValues(alpha: 0.15),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ⭐ Checkbox (بە Batch Mode)
              if (_batchMode) ...[
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE91E63)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE91E63),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  )
                      : null,
                ),
              ],
              // 🖼️ Image
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: OptimizedNetworkImage(
                    imageUrl: store['image'] ?? '',
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 📝 Info
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
              // ⭐ Arrow
              if (!_batchMode)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFFE91E63),
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Fav News Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildFavNewsCard({
    required Map<String, dynamic> fav,
    required Map<String, dynamic> item,
    required String firstImg,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return GestureDetector(
      onTap: () {
        if (_batchMode) {
          onSelect();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewsDetailsScreen(newsItem: item),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9C27B0)
                : const Color(0xFF9C27B0).withValues(alpha: 0.15),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ⭐ Checkbox (بە Batch Mode)
            if (_batchMode)
              Positioned(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, left: 8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF9C27B0)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF9C27B0),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                          : null,
                    ),
                  ),
                ),
              ),
            // 🖼️ Image
            if (firstImg.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Stack(
                  children: [
                    OptimizedNetworkImage(
                      imageUrl: firstImg,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                    if (!_batchMode)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                color: Colors.pink,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'دڵخواز',
                                style: TextStyle(
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
              ),
            // 📝 Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    child: Icon(icon, size: 60, color: color),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔧 Helpers
  // ═══════════════════════════════════════════════════════════
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
}