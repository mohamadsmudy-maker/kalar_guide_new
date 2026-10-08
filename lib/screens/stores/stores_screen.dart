import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../config/translations.dart';
import '../../services/cache_service.dart';
import '../../services/location_service.dart';
import '../../widgets/cards/store_card.dart';
import '../../widgets/common/app_text.dart';
import 'full_map_screen.dart';
import 'store_details_dialog.dart';

/// 🏪 شاشەی شوێنەکان — ULTRA PRO EDITION
class StoresScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const StoresScreen({super.key, this.onMenuTap});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen>
    with TickerProviderStateMixin {
  static const String _cacheKey = 'stores_list';
  static const Duration _cacheDuration = Duration(minutes: 30);

  String _searchQuery = '';
  String _selectedCategory = 'هەموو';
  String _selectedType = 'هەموو';
  final TextEditingController _searchCtrl = TextEditingController();

  Position? _currentPosition;
  bool _loadingStores = true;
  List<Map<String, dynamic>> _allStores = [];

  // ✨ Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _determinePosition();
    _fetchStores();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 شوێنی ئێستا
  // ═══════════════════════════════════════════════════════════
  Future<void> _determinePosition() async {
    final position = await LocationService.getCurrentPosition();
    if (mounted) {
      setState(() => _currentPosition = position);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی شوێنەکان — بە کاش
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchStores({bool forceRefresh = false}) async {
    setState(() => _loadingStores = true);

    try {
      if (!forceRefresh) {
        final cached = await CacheService.get(_cacheKey);
        if (cached != null) {
          final stores = List<Map<String, dynamic>>.from(cached as List);
          if (mounted) {
            setState(() {
              _allStores = stores;
              _loadingStores = false;
            });
          }
          debugPrint('✅ StoresScreen: لە کاش هێنرا (${stores.length})');
          return;
        }
      }

      final res = await Supabase.instance.client.from('dukan').select();
      final stores = List<Map<String, dynamic>>.from(res);

      await CacheService.save(
        _cacheKey,
        stores,
        duration: _cacheDuration,
      );

      if (mounted) {
        setState(() {
          _allStores = stores;
          _loadingStores = false;
        });
      }
    } catch (e) {
      debugPrint('❌ StoresScreen error: $e');
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  Future<void> _onRefresh() async {
    await CacheService.remove(_cacheKey);
    await _fetchStores(forceRefresh: true);
  }

  // ═══════════════════════════════════════════════════════════
  // 📏 دووری
  // ═══════════════════════════════════════════════════════════
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
  // 🎯 فلتەرکردن
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredStores {
    var list = _allStores.where((store) {
      final name = (store['name'] ?? '').toString().toLowerCase();
      final storeCategory =
      (store['category'] ?? '').toString().toLowerCase();
      final address = (store['address'] ?? '').toString().toLowerCase();
      final storeType = (store['type'] ?? '').toString().trim();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(q) ||
          storeCategory.contains(q) ||
          address.contains(q);

      final matchesCategory = _selectedCategory == 'هەموو' ||
          storeCategory.contains(_selectedCategory.toLowerCase());

      bool matchesType = true;
      if (_selectedType == 'حکومی') {
        matchesType = storeType == 'حکومی';
      } else if (_selectedType == 'ناحکومی') {
        matchesType = storeType == 'ناحکومی';
      }

      return matchesSearch && matchesCategory && matchesType;
    }).toList();

    list.sort((a, b) {
      double? latA = double.tryParse(a['latitude']?.toString() ?? '');
      double? lngA = double.tryParse(a['longitude']?.toString() ?? '');
      double? latB = double.tryParse(b['latitude']?.toString() ?? '');
      double? lngB = double.tryParse(b['longitude']?.toString() ?? '');

      return _calculateDistance(latA, lngA)
          .compareTo(_calculateDistance(latB, lngB));
    });

    return list;
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════════
            // 🎯 هێدەری پریمیۆم
            // ═══════════════════════════════════════════
            _buildPremiumAppBar(isDark),

            // ═══════════════════════════════════════════
            // 🔍 گەڕان + Map
            // ═══════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSearchRow(isDark, lang),
              ),
            ),

            // ═══════════════════════════════════════════
            // 🎯 فلتەری جۆر (حکومی / ناحکومی)
            // ═══════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTypeFilters(isDark, lang),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // ═══════════════════════════════════════════
            // 🏷️ فلتەری بەشەکان
            // ═══════════════════════════════════════════
            SliverToBoxAdapter(
              child: _buildCategoriesFilter(isDark, lang),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ═══════════════════════════════════════════
            // 📊 ئاماری ئەنجام
            // ═══════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildResultStats(isDark, lang),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ═══════════════════════════════════════════
            // 📋 لیستی شوێنەکان
            // ═══════════════════════════════════════════
            _buildStoresList(isDark, lang),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 هێدەری پریمیۆم
  // ═══════════════════════════════════════════════════════════
  Widget _buildPremiumAppBar(bool isDark) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 140,
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
                AppColors.primary.withValues(alpha: 0.06),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          Color.lerp(
                              AppColors.primary, Colors.white, 0.2)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'شوێنەکان',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_allStores.length} شوێن لە شاری کەلار',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 گەڕان + Map
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchRow(bool isDark, String lang) {
    return Row(
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
                  color:
                  Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: AppTranslations.t(
                        'stores_search_hint',
                        lang,
                      ),
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
                    },
                  ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 🗺️ دوگمەی Map
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 فلتەری جۆر
  // ═══════════════════════════════════════════════════════════
  Widget _buildTypeFilters(bool isDark, String lang) {
    return Row(
      children: [
        Expanded(
          child: _buildTypeFilter(
            icon: Icons.account_balance_rounded,
            labelKey: 'stores_government',
            fallbackLabel: 'حکومی',
            isSelected: _selectedType == 'حکومی',
            color: const Color(0xFF2E7D32),
            isDark: isDark,
            onTap: () => setState(
                  () => _selectedType =
              _selectedType == 'حکومی' ? 'هەموو' : 'حکومی',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTypeFilter(
            icon: Icons.storefront_rounded,
            labelKey: 'stores_non_government',
            fallbackLabel: 'ناحکومی',
            isSelected: _selectedType == 'ناحکومی',
            color: const Color(0xFFE91E63),
            isDark: isDark,
            onTap: () => setState(
                  () => _selectedType =
              _selectedType == 'ناحکومی' ? 'هەموو' : 'ناحکومی',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeFilter({
    required IconData icon,
    required String labelKey,
    required String fallbackLabel,
    required bool isSelected,
    required Color color,
    required bool isDark,
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
            colors: [
              color,
              Color.lerp(color, Colors.white, 0.2)!,
            ],
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
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 5),
              spreadRadius: -3,
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
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
            AppText(
              labelKey,
              fallback: fallbackLabel,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
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
  // 🏷️ فلتەری بەشەکان
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoriesFilter(bool isDark, String lang) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchCategoriesCached(),
      builder: (context, snapshot) {
        List<String> categories = ['هەموو'];
        if (snapshot.hasData) {
          Map<String, Map<String, dynamic>> uniqueMap = {};
          for (var cat in snapshot.data!) {
            uniqueMap[cat['name']] = cat;
          }
          categories.addAll(
            uniqueMap.values.map((c) => c['name'].toString()),
          );
        }

        return SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategory == cat;

              String displayCat = cat;
              if (cat == 'هەموو') {
                displayCat = AppTranslations.t('stores_all', lang);
              } else {
                final keyMap = {
                  'تەندروستی': 'cat_health',
                  'پەروەردە': 'cat_education',
                  'خوێندنی باڵا': 'cat_higher_ed',
                  'بەڕێوەبەرایەتی': 'cat_government',
                  'خواردن': 'cat_food',
                  'بازاڕگەری': 'cat_shopping',
                };
                final key = keyMap[cat];
                if (key != null) {
                  displayCat = AppTranslations.t(key, lang);
                }
              }

              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat);
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
                          Color.lerp(AppColors.primary,
                              Colors.white, 0.2)!,
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
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: -3,
                        ),
                      ]
                          : null,
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
                        Text(
                          displayCat,
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
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ئاماری ئەنجام
  // ═══════════════════════════════════════════════════════════
  Widget _buildResultStats(bool isDark, String lang) {
    final stores = _filteredStores;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                '${stores.length} شوێن',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (_currentPosition != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  color: Colors.green,
                  size: 12,
                ),
                const SizedBox(width: 4),
                AppText(
                  'stores_nearest',
                  fallback: 'نزیکترین',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 لیستی شوێنەکان
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoresList(bool isDark, String lang) {
    if (_loadingStores) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final stores = _filteredStores;

    if (stores.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState(isDark, lang));
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final store = stores[index];
            final lat = double.tryParse(
              store['latitude']?.toString() ?? '',
            );
            final lng = double.tryParse(
              store['longitude']?.toString() ?? '',
            );
            final distance = _calculateDistance(lat, lng);

            return FadeTransition(
              opacity: _fadeAnimation,
              child: StoreCard(
                store: store,
                distance: distance,
                onTap: () {
                  HapticFeedback.lightImpact();
                  StoreDetailsDialog.show(context, store);
                },
              ),
            );
          },
          childCount: stores.length,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 کاشکردنی بەشەکان
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _fetchCategoriesCached() async {
    const key = 'main_categories';
    final cached = await CacheService.get(key);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached as List);
    }

    final res =
    await Supabase.instance.client.from('main_categories').select();
    final list = List<Map<String, dynamic>>.from(res);
    await CacheService.save(
      key,
      list,
      duration: const Duration(hours: 1),
    );
    return list;
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 حاڵەتی بەتاڵ
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
              animation: _pulseAnimation,
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
            Text(
              'هیچ شوێنێک نەدۆزرایەوە',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'گەڕانەکەت هیچ ئەنجامێکی نەبوو',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}