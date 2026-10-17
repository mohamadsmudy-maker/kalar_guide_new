import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/cache_service.dart';
import '../../services/location_service.dart';
import '../../widgets/cards/store_card.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'full_map_screen.dart';
import 'store_details_dialog.dart';

/// 🏪 شاشەی شوێنەکان — ULTRA PRO V3
class StoresScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const StoresScreen({super.key, this.onMenuTap});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  static const String _cacheKey = 'stores_list_v3';
  static const Duration _cacheDuration = Duration(minutes: 30);

  String _searchQuery = '';
  String _selectedCategory = 'هەموو';
  String _selectedType = 'هەموو';
  String _sortBy = 'default';
  String _viewMode = 'list'; // 'list', 'grid'
  bool _showOnlyVerified = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Position? _currentPosition;
  bool _loadingStores = true;
  List<Map<String, dynamic>> _allStores = [];
  List<Map<String, dynamic>> _filteredStores = [];

  // ⭐ Categories
  List<Map<String, dynamic>> _allCategories = [];
  bool _loadingCategories = true;

  // ⭐ Favorites
  final Set<String> _favorites = {};

  // ⭐ Pagination
  static const int _pageSize = 10;
  int _displayCount = _pageSize;

  // ✨ Animation
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _entryAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

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

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _scrollController.addListener(_onScroll);

    _determinePosition();
    _fetchStores();
    _fetchCategories();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (_displayCount < _filteredStores.length) {
        setState(() {
          _displayCount = (_displayCount + _pageSize)
              .clamp(0, _filteredStores.length);
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 GPS
  // ═══════════════════════════════════════════════════════════
  Future<void> _determinePosition() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = position);
        _applyFilters();
      }
    } catch (e) {
      debugPrint('⚠️ Position error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 Fetch Stores
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchStores({bool forceRefresh = false}) async {
    if (mounted) setState(() => _loadingStores = true);

    try {
      if (!forceRefresh) {
        final cached = await CacheService.get(_cacheKey);
        if (cached != null && cached is List) {
          final stores = List<Map<String, dynamic>>.from(cached);
          debugPrint('✅ Stores from cache: ${stores.length}');
          if (mounted) {
            setState(() {
              _allStores = stores;
              _loadingStores = false;
            });
            _applyFilters();
          }
          return;
        }
      }

      debugPrint('🔄 Fetching stores from Supabase...');
      final res = await Supabase.instance.client
          .from('dukan')
          .select()
          .order('name');

      final stores = List<Map<String, dynamic>>.from(res as List);
      debugPrint('✅ Stores fetched: ${stores.length}');

      if (stores.isNotEmpty) {
        await CacheService.save(
          _cacheKey,
          stores,
          duration: _cacheDuration,
        );
      }

      if (mounted) {
        setState(() {
          _allStores = stores;
          _loadingStores = false;
        });
        _applyFilters();
        _entryController.forward(from: 0);
      }
    } catch (e, st) {
      debugPrint('❌ StoresScreen error: $e');
      debugPrint('Stack: $st');
      if (mounted) {
        setState(() {
          _allStores = [];
          _loadingStores = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗂️ Fetch Categories
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchCategories() async {
    if (mounted) setState(() => _loadingCategories = true);

    try {
      const key = 'main_categories_v3';
      final cached = await CacheService.get(key);

      if (cached != null && cached is List) {
        final list = List<Map<String, dynamic>>.from(cached);
        if (mounted) {
          setState(() {
            _allCategories = list;
            _loadingCategories = false;
          });
        }
        return;
      }

      final res = await Supabase.instance.client
          .from('main_categories')
          .select()
          .order('name');

      final list = List<Map<String, dynamic>>.from(res as List);

      await CacheService.save(
        key,
        list,
        duration: const Duration(hours: 1),
      );

      if (mounted) {
        setState(() {
          _allCategories = list;
          _loadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Categories error: $e');
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ❤️ Favorites
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadFavorites() async {
    try {
      final prefs = await CacheService.get('store_favorites');
      if (prefs != null && prefs is List) {
        if (mounted) {
          setState(() {
            _favorites
              ..clear()
              ..addAll(prefs.map((e) => e.toString()));
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String storeId) async {
    HapticFeedback.selectionClick();
    setState(() {
      if (_favorites.contains(storeId)) {
        _favorites.remove(storeId);
      } else {
        _favorites.add(storeId);
      }
    });
    await CacheService.save(
      'store_favorites',
      _favorites.toList(),
      duration: const Duration(days: 365),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Filtering
  // ═══════════════════════════════════════════════════════════
  void _applyFilters() {
    var list = _allStores.where((store) {
      final name = (store['name'] ?? '').toString().toLowerCase();
      final storeCategory =
      (store['category'] ?? '').toString().toLowerCase();
      final subCategory =
      (store['sub_category'] ?? '').toString().toLowerCase();
      final address = (store['address'] ?? '').toString().toLowerCase();
      final storeType = (store['type'] ?? '').toString().trim();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(q) ||
          storeCategory.contains(q) ||
          subCategory.contains(q) ||
          address.contains(q);

      final matchesCategory = _selectedCategory == 'هەموو' ||
          storeCategory.contains(_selectedCategory.toLowerCase());

      bool matchesType = true;
      if (_selectedType == 'حکومی') {
        matchesType = storeType == 'حکومی';
      } else if (_selectedType == 'ناحکومی') {
        matchesType = storeType == 'ناحکومی';
      }

      // ⭐ Verified Filter
      if (_showOnlyVerified) {
        final isVerified = store['is_verified'] == true;
        if (!isVerified) return false;
      }

      return matchesSearch && matchesCategory && matchesType;
    }).toList();

    // ⭐ Sort
    switch (_sortBy) {
      case 'distance':
        list.sort((a, b) {
          final latA = double.tryParse(a['latitude']?.toString() ?? '');
          final lngA = double.tryParse(a['longitude']?.toString() ?? '');
          final latB = double.tryParse(b['latitude']?.toString() ?? '');
          final lngB = double.tryParse(b['longitude']?.toString() ?? '');
          return _calculateDistance(latA, lngA)
              .compareTo(_calculateDistance(latB, lngB));
        });
        break;
      case 'name':
        list.sort((a, b) => (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString()));
        break;
      case 'category':
        list.sort((a, b) => (a['category'] ?? '')
            .toString()
            .compareTo((b['category'] ?? '').toString()));
        break;
      default:
        list.sort((a, b) {
          final latA = double.tryParse(a['latitude']?.toString() ?? '');
          final lngA = double.tryParse(a['longitude']?.toString() ?? '');
          final latB = double.tryParse(b['latitude']?.toString() ?? '');
          final lngB = double.tryParse(b['longitude']?.toString() ?? '');
          return _calculateDistance(latA, lngA)
              .compareTo(_calculateDistance(latB, lngB));
        });
    }

    setState(() {
      _filteredStores = list;
      _displayCount = _pageSize;
    });
  }

  double _calculateDistance(double? lat, double? lng) {
    if (_currentPosition == null || lat == null || lng == null) {
      return 99999.0;
    }
    return LocationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await _fetchStores(forceRefresh: true);
            await _fetchCategories();
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildPremiumAppBar(isDark, lang),
              SliverToBoxAdapter(child: _buildSearchBar(isDark, lang)),
              SliverToBoxAdapter(child: _buildTypeFilters(isDark, lang)),
              SliverToBoxAdapter(child: _buildCategoriesFilter(isDark, lang)),
              SliverToBoxAdapter(child: _buildActionBar(isDark, lang)),
              SliverToBoxAdapter(child: _buildStatsCard(isDark, lang)),
              _buildStoresList(isDark, lang),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildPremiumAppBar(bool isDark, String lang) {
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
            _viewMode == 'grid'
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded,
            color: isDark ? Colors.white : AppColors.primary,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _viewMode = _viewMode == 'grid' ? 'list' : 'grid';
            });
          },
          tooltip: _viewMode == 'grid' ? 'لیست' : 'گرید',
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
                AppColors.primary.withValues(alpha: 0.08),
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
                          AppColors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale:
                            1.0 + (_pulseAnimation.value - 1.0) * 0.4,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    Color.lerp(
                                        AppColors.primary, Colors.white, 0.2)!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.45),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
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
                            AutoTranslate(
                              text: 'شوێنەکان',
                              lang: lang,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            AutoTranslate(
                              text: _allStores.isEmpty
                                  ? 'خەریکی هێنان...'
                                  : '${_allStores.length} شوێن لە شاری کەلار',
                              lang: lang,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
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
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark, String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _searchQuery.isNotEmpty
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                        _applyFilters();
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: lang == 'ar'
                            ? 'ابحث عن الأماكن...'
                            : (lang == 'en'
                            ? 'Search places...'
                            : 'گەڕان بەدوای شوێنەکان...'),
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FullMapScreen(),
                ),
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.map_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏛️ Type Filters
  // ═══════════════════════════════════════════════════════════
  Widget _buildTypeFilters(bool isDark, String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeFilter(
              icon: Icons.account_balance_rounded,
              label: 'حکومی',
              isSelected: _selectedType == 'حکومی',
              color: const Color(0xFF2E7D32),
              isDark: isDark,
              lang: lang,
              onTap: () {
                setState(() => _selectedType =
                _selectedType == 'حکومی' ? 'هەموو' : 'حکومی');
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildTypeFilter(
              icon: Icons.storefront_rounded,
              label: 'ناحکومی',
              isSelected: _selectedType == 'ناحکومی',
              color: const Color(0xFFE91E63),
              isDark: isDark,
              lang: lang,
              onTap: () {
                setState(() => _selectedType =
                _selectedType == 'ناحکومی' ? 'هەموو' : 'ناحکومی');
                _applyFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required bool isDark,
    required String lang,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [color, Color.lerp(color, Colors.white, 0.2)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF1A1A22) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AutoTranslate(
                text: label,
                lang: lang,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
                maxLines: 1,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 15,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗂️ Categories Filter
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoriesFilter(bool isDark, String lang) {
    if (_loadingCategories) {
      return const SizedBox(
        height: 42,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    final uniqueNames = <String>{};
    final categories = <Map<String, dynamic>>[];

    for (final cat in _allCategories) {
      final name = cat['name']?.toString() ?? '';
      if (name.isNotEmpty && uniqueNames.add(name)) {
        categories.add(cat);
      }
    }

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final catName = isAll
              ? 'هەموو'
              : (categories[index - 1]['name']?.toString() ?? '');
          final isSelected = _selectedCategory == catName;

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = catName);
                _applyFilters();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      AppColors.primary,
                      Color.lerp(
                          AppColors.primary, Colors.white, 0.2)!,
                    ],
                  )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark
                      ? const Color(0xFF1A1A22)
                      : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                        ? Colors.white12
                        : Colors.grey.shade200),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                    ],
                    AutoTranslate(
                      text: catName,
                      lang: lang,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                            ? Colors.white70
                            : Colors.black87),
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Action Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildActionBar(bool isDark, String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // ⭐ Sort
          _buildChip(
            icon: Icons.sort_rounded,
            label: _getSortLabel(),
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: _showSortSheet,
          ),
          const SizedBox(width: 8),
          // ⭐ Verified Filter
          _buildChip(
            icon: Icons.verified_rounded,
            label: 'پارێزراو',
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            isActive: _showOnlyVerified,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showOnlyVerified = !_showOnlyVerified);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)])
              : null,
          color: isActive
              ? null
              : (isDark ? const Color(0xFF1A1A22) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'distance':
        return 'نزیکترین';
      case 'name':
        return 'ناو';
      case 'category':
        return 'کەرت';
      default:
        return 'ڕیزکردن';
    }
  }

  void _showSortSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ڕیزکردن',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              _buildSortOption('default', 'ئاسایی', Icons.sort_rounded),
              _buildSortOption('distance', 'نزیکترین', Icons.near_me_rounded),
              _buildSortOption('name', 'ناو', Icons.abc_rounded),
              _buildSortOption('category', 'کەرت', Icons.category_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.primary : Colors.grey.shade600,
          size: 18,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          color: isSelected ? AppColors.primary : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(
        Icons.check_circle_rounded,
        color: AppColors.primary,
        size: 20,
      )
          : null,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _sortBy = value);
        _applyFilters();
        Navigator.pop(context);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsCard(bool isDark, String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_filteredStores.length} شوێن',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    _currentPosition != null
                        ? 'ڕیزکراوە بەپێی نزیکی'
                        : 'چاوەڕوانی GPS...',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? Colors.white54
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (_currentPosition != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      color: Colors.green,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'نزیک',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
                      ),
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
  // 🏪 Stores List
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoresList(bool isDark, String lang) {
    if (_loadingStores) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, i) => _buildSkeletonCard(isDark),
            childCount: 5,
          ),
        ),
      );
    }

    if (_filteredStores.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState(isDark, lang));
    }

    final displayList =
    _filteredStores.take(_displayCount).toList();
    final hasMore = _displayCount < _filteredStores.length;

    if (_viewMode == 'grid') {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          delegate: SliverChildBuilderDelegate(
                (context, i) => _buildGridCard(displayList[i], isDark, i),
            childCount: displayList.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, i) {
            if (i == displayList.length) {
              if (!hasMore) return const SizedBox.shrink();
              return _buildLoadMoreButton(isDark);
            }

            final card = _buildStoreCard(displayList[i], isDark);

            // ⭐ Animation بۆ ٨ ی یەکەم
            if (i >= 8) return card;

            return AnimatedBuilder(
              animation: _entryAnimation,
              builder: (context, child) {
                final delay = (i * 0.06).clamp(0.0, 0.5);
                final progress = ((_entryAnimation.value - delay) / 0.4)
                    .clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - progress)),
                  child: Opacity(
                    opacity: progress,
                    child: child,
                  ),
                );
              },
              child: card,
            );
          },
          childCount: displayList.length + (hasMore ? 1 : 0),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Store Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoreCard(Map<String, dynamic> store, bool isDark) {
    final storeId = store['id']?.toString() ?? '';
    final name = store['name']?.toString() ?? 'شوێن';
    final address = store['address']?.toString() ?? 'کەلار';
    final category = store['category']?.toString() ?? '';
    final image = store['image']?.toString() ?? '';
    final isGov = (store['type']?.toString() ?? '') == 'حکومی';
    final isVerified = store['is_verified'] == true;
    final isFav = _favorites.contains(storeId);

    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');
    final distance = _calculateDistance(lat, lng);
    final hasDistance = distance < 99999.0;

    final accentColor =
    isGov ? const Color(0xFF10B981) : const Color(0xFFE91E63);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            StoreDetailsDialog.show(context, store);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 🖼️ Image
                Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: image.isNotEmpty
                            ? OptimizedNetworkImage(
                          imageUrl: image,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          color:
                          accentColor.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: accentColor,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    // ⭐ Verified Badge
                    if (isVerified)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // ⭐ Favorite Badge
                    if (isFav)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.pink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // 📝 Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
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
                          ),
                          // ⭐ Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                              accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isGov ? 'حکومی' : 'ناحکومی',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          if (hasDistance) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.near_me_rounded,
                                    size: 9,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${distance.toStringAsFixed(1)} کم',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ⭐ Actions
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⭐ Favorite Button
                    GestureDetector(
                      onTap: () => _toggleFavorite(storeId),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFav
                              ? Colors.pink.withValues(alpha: 0.15)
                              : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color:
                          isFav ? Colors.pink : Colors.grey.shade500,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ⭐ Arrow
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.15),
                            accentColor.withValues(alpha: 0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: accentColor,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Grid Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildGridCard(Map<String, dynamic> store, bool isDark, int index) {
    final storeId = store['id']?.toString() ?? '';
    final name = store['name']?.toString() ?? 'شوێن';
    final image = store['image']?.toString() ?? '';
    final isGov = (store['type']?.toString() ?? '') == 'حکومی';
    final isFav = _favorites.contains(storeId);

    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');
    final distance = _calculateDistance(lat, lng);

    final accentColor =
    isGov ? const Color(0xFF10B981) : const Color(0xFFE91E63);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        StoreDetailsDialog.show(context, store);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: image.isNotEmpty
                        ? OptimizedNetworkImage(
                      imageUrl: image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      color: accentColor.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: accentColor,
                        size: 40,
                      ),
                    ),
                  ),
                  if (isFav)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.pink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (distance < 99999.0)
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 10,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${distance.toStringAsFixed(1)} کم',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💀 Skeleton Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildSkeletonCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A35)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A35)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 150,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A35)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 100,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A35)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Load More Button
  // ═══════════════════════════════════════════════════════════
  Widget _buildLoadMoreButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _displayCount = (_displayCount + _pageSize)
                  .clamp(0, _filteredStores.length);
            });
          },
          icon: const Icon(
            Icons.expand_more_rounded,
            color: AppColors.primary,
          ),
          label: Text(
            'بینینی زیاتر (${_filteredStores.length - _displayCount} تر)',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark, String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.location_off_rounded,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            AutoTranslate(
              text: _allStores.isEmpty
                  ? 'هیچ شوێنێک نییە'
                  : 'هیچ شوێنێک نەدۆزرایەوە',
              lang: lang,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            AutoTranslate(
              text: _allStores.isEmpty
                  ? 'داتابەیسەکە بەتاڵە — تکایە داتا زیاد بکە'
                  : 'گەڕانەکەت هیچ ئەنجامێکی نەبوو',
              lang: lang,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _fetchStores(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'دووبارە هەوڵ بدە',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}