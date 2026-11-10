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
import 'full_map_screen.dart';
import 'store_details_dialog.dart';
import '../../l10n/tr.dart';
import '../categories/categories_screen.dart';
import '../../utils/place_display.dart';
import '../../services/app_settings_service.dart';
import 'suggest_place_screen.dart';

/// 🏪 شاشەی شوێنەکان — FULL ULTRA PRO MAX
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
  String _viewMode = 'list';
  bool _showOnlyVerified = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Position? _currentPosition;
  bool _loadingStores = true;
  List<Map<String, dynamic>> _allStores = [];
  List<Map<String, dynamic>> _filteredStores = [];

  List<Map<String, dynamic>> _allCategories = [];

  final Set<String> _favorites = {};

  static const int _pageSize = 10;
  int _displayCount = _pageSize;

  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _entryAnimation;
  late Animation<double> _pulseAnimation;

  /// پێشنیاری شوێن لەلایەن هاوڵاتیانەوە (ئەدمین چالاک/ناچالاکی دەکات)
  bool _suggestionsOn = false;

  @override
  void initState() {
    super.initState();
    AppSettingsService.isOn(AppSettingsService.placeSuggestions, refresh: true).then((on) {
      if (mounted && on != _suggestionsOn) setState(() => _suggestionsOn = on);
    });

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
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (_displayCount < _filteredStores.length) {
        setState(() {
          _displayCount =
              (_displayCount + _pageSize).clamp(0, _filteredStores.length);
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

      final res =
          await Supabase.instance.client.from('dukan').select().order('name');

      final stores = List<Map<String, dynamic>>.from(res as List);

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
    } catch (e) {
      debugPrint('❌ StoresScreen error: $e');
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
    try {
      const key = 'main_categories_v3';
      final cached = await CacheService.get(key);

      if (cached != null && cached is List) {
        final list = List<Map<String, dynamic>>.from(cached);
        if (mounted) {
          setState(() => _allCategories = list);
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
        setState(() => _allCategories = list);
      }
    } catch (e) {
      debugPrint('❌ Categories error: $e');
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

  // ═══════════════════════════════════════════════════════════
  // 🔍 Filtering
  // ═══════════════════════════════════════════════════════════
  void _applyFilters() {
    var list = _allStores.where((store) {
      final name = (store['name'] ?? '').toString().toLowerCase();
      final storeCategory = (store['category'] ?? '').toString().toLowerCase();
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

      if (_showOnlyVerified) {
        final isVerified = store['is_verified'] == true;
        if (!isVerified) return false;
      }

      return matchesSearch && matchesCategory && matchesType;
    }).toList();

    // بێ GPS «نزیکترین» مانای نییە → بەپێی ناو
    final sortBy = _currentPosition == null ? 'name' : _sortBy;
    switch (sortBy) {
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
              SliverToBoxAdapter(child: _buildQuickCategories(isDark)),
              SliverToBoxAdapter(child: _buildResultBar(isDark)),
              _buildStoresList(isDark, lang),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar (بچووکتر و پاکتر)
  // ═══════════════════════════════════════════════════════════
  Widget _buildPremiumAppBar(bool isDark, String lang) {
    return SliverAppBar(
      expandedHeight: 140, // ✅ بچووکتر کراوە
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
        if (_suggestionsOn)
          IconButton(
            icon: Icon(
              Icons.add_location_alt_rounded,
              color: isDark ? Colors.white : AppColors.primary,
            ),
            tooltip: tr('پێشنیاری شوێنی نوێ'),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuggestPlaceScreen()),
              );
            },
          ),
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
          tooltip: _viewMode == 'grid' ? tr('لیست') : tr('گرید'),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A1A22), const Color(0xFF252530)]
                  : [Colors.white, AppColors.primary.withValues(alpha: 0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          Color.lerp(AppColors.primary, Colors.white, 0.2)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AutoTranslate(
                          text: tr('شوێنەکان'),
                          lang: lang,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        AutoTranslate(
                          text: _allStores.isEmpty
                              ? tr('خەریکی هێنان...')
                              : _activeFilterCount == 0
                                  ? trf('{0} شوێن لە شاری کەلار',
                                      [PlaceDisplay.digits(_allStores.length)])
                                  : trf('{0} لە {1} شوێن', [
                                      PlaceDisplay.digits(_filteredStores.length),
                                      PlaceDisplay.digits(_allStores.length)
                                    ]),
                          lang: lang,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white54 : Colors.grey.shade600,
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
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search Bar (بچووکتر)
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark, String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48, // ✅ بچووکتر
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _searchQuery.isNotEmpty
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                        _applyFilters();
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: lang == 'ar'
                            ? tr('ابحث عن الأماكن...')
                            : (lang == 'en'
                                ? 'Search places...'
                                : 'گەڕان بەدوای شوێنەکان...'),
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 16,
                          color: isDark ? Colors.white54 : Colors.grey),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(isDark),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FullMapScreen()),
              );
            },
            child: Container(
              width: 48, // ✅ بچووکتر
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1E88E5)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.map_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎛️ فلتەر — ژمارەی فلتەرە چالاکەکان
  // ═══════════════════════════════════════════════════════════
  int get _activeFilterCount =>
      (_selectedCategory != 'هەموو' ? 1 : 0) +
      (_selectedType != 'هەموو' ? 1 : 0) +
      (_searchQuery.isNotEmpty ? 1 : 0);

  void _clearFilters() {
    HapticFeedback.selectionClick();
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'هەموو';
      _selectedType = 'هەموو';
    });
    _applyFilters();
  }

  int _countFor(String category) => category == 'هەموو'
      ? _allStores.length
      : _allStores
          .where((s) => (s['category'] ?? '')
              .toString()
              .toLowerCase()
              .contains(category.toLowerCase()))
          .length;

  Widget _buildFilterButton(bool isDark) {
    final n = (_selectedType != 'هەموو' ? 1 : 0) +
        (_selectedCategory != 'هەموو' ? 1 : 0);
    return Tooltip(
      message: tr('فلتەرکردن و ڕیزکردن'),
      child: GestureDetector(
        onTap: _showFilterSheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: n > 0
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.tune_rounded,
                  size: 22, color: n > 0 ? Colors.white : AppColors.primary),
            ),
            if (n > 0)
              PositionedDirectional(
                top: -4,
                end: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2557A),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isDark ? const Color(0xFF0F0F14) : Colors.white,
                        width: 2),
                  ),
                  child: Text('$n',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ بەشەکان — ڕیزی ئاسۆیی، یەک کرتە بۆ فلتەرکردن
  // ═══════════════════════════════════════════════════════════
  Widget _buildQuickCategories(bool isDark) {
    // هەموو بەشەکان (بەتاڵەکان لە کۆتایی و کاڵتر) — لەبری تابی «بەشەکان»
    final cats = <String>[
      for (final c in _allCategories)
        if ((c['name'] ?? '').toString().trim().isNotEmpty) c['name'].toString(),
    ]..sort((a, b) => (_countFor(a) == 0 ? 1 : 0).compareTo(_countFor(b) == 0 ? 1 : 0));
    if (cats.isEmpty) return const SizedBox(height: 4);
    final names = ['هەموو', ...cats];
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: names.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          // کۆتا: بینینی هەموو بەشەکان بە شێوەی گرید
          if (i == names.length) {
            return _categoryTile(
              isDark: isDark,
              icon: Icons.grid_view_rounded,
              label: tr('هەموو بەشەکان'),
              color: AppColors.toneSlate,
              count: null,
              selected: false,
              dim: false,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
              },
            );
          }
          final name = names[i];
          final selected = _selectedCategory == name;
          final count = _countFor(name);
          return _categoryTile(
            isDark: isDark,
            icon: name == 'هەموو' ? Icons.apps_rounded : PlaceDisplay.icon(name),
            label: name,
            color: name == 'هەموو' ? AppColors.primary : PlaceDisplay.color(name),
            count: count,
            selected: selected,
            dim: count == 0 && name != 'هەموو',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = selected && name != 'هەموو' ? 'هەموو' : name);
              _applyFilters();
            },
          );
        },
      ),
    );
  }

  Widget _categoryTile({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
    required int? count,
    required bool selected,
    required bool dim,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 92,
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          decoration: BoxDecoration(
            color: selected ? color : (isDark ? const Color(0xFF1A1A22) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: selected ? color.withValues(alpha: 0.35) : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.22) : null,
                  gradient: selected
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color.lerp(color, Colors.white, 0.2)!, Color.lerp(color, Colors.black, 0.08)!],
                        ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: AutoTranslate(
                  text: tr(label),
                  lang: AppLang.code,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                ),
              ),
              if (count != null)
                Text(
                  PlaceDisplay.digits(count),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ئەنجام + ڕیزکردن + لابردنی فلتەر
  // ═══════════════════════════════════════════════════════════
  Widget _buildResultBar(bool isDark) {
    final sub = isDark ? Colors.white60 : const Color(0xFF64748B);
    final byName = _sortBy == 'name';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
      child: Row(
        children: [
          Text(
            trf('{0} ئەنجام', [PlaceDisplay.digits(_filteredStores.length)]),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: sub),
          ),
          if (_activeFilterCount > 0) ...[
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _clearFilters,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: const Color(0xFFC2557A),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.close_rounded, size: 14),
              label: Text(tr('سڕینەوەی فلتەرەکان'),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
          const Spacer(),
          if (_currentPosition != null)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _sortBy = byName ? 'distance' : 'name');
                _applyFilters();
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: Icon(
                  byName ? Icons.sort_by_alpha_rounded : Icons.near_me_rounded,
                  size: 15),
              label: Text(
                byName ? tr('بەپێی ناو') : tr('نزیکترین'),
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 Stores List (وەک خۆی)
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

    final displayList = _filteredStores.take(_displayCount).toList();
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

            final card = StoreCard(
              store: displayList[i],
              distance: _calculateDistance(
                double.tryParse(displayList[i]['latitude']?.toString() ?? ''),
                double.tryParse(displayList[i]['longitude']?.toString() ?? ''),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                StoreDetailsDialog.show(context, displayList[i]);
              },
            );

            if (i >= 8) return card;

            return AnimatedBuilder(
              animation: _entryAnimation,
              builder: (context, child) {
                final delay = (i * 0.06).clamp(0.0, 0.5);
                final progress =
                    ((_entryAnimation.value - delay) / 0.4).clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - progress)),
                  child: Opacity(opacity: progress, child: child),
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
  // 🎴 Grid Card (بۆ شێوازی گرید)
  // ═══════════════════════════════════════════════════════════
  Widget _buildGridCard(Map<String, dynamic> store, bool isDark, int index) {
    final name = store['name']?.toString() ?? 'شوێن';
    final image = store['image']?.toString() ?? '';
    final isGov = (store['type']?.toString() ?? '') == 'حکومی';

    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');
    final distance = _calculateDistance(lat, lng);

    final accentColor =
        isGov ? const Color(0xFF0F9D7A) : const Color(0xFFC2557A);

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
              color: accentColor.withValues(alpha: 0.15), width: 1.5),
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
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: image.isNotEmpty
                        ? Image.network(image,
                            width: double.infinity, fit: BoxFit.cover)
                        : Container(
                            color: accentColor.withValues(alpha: 0.1),
                            child: Icon(Icons.storefront_rounded,
                                color: accentColor, size: 40),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr(name),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (distance < 99999.0)
                      Row(
                        children: [
                          const Icon(Icons.near_me_rounded,
                              size: 10, color: Color(0xFF0F9D7A)),
                          const SizedBox(width: 3),
                          Text(
                            trf('{0} کم', [PlaceDisplay.digits(distance.toStringAsFixed(1))]),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF0F9D7A),
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
              color: isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
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
                    color:
                        isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 150,
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
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
              _displayCount =
                  (_displayCount + _pageSize).clamp(0, _filteredStores.length);
            });
          },
          icon: const Icon(Icons.expand_more_rounded, color: AppColors.primary),
          label: Text(
            trf('بینینی زیاتر ({0} تر)',
                [PlaceDisplay.digits(_filteredStores.length - _displayCount)]),
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w900),
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
                          AppColors.primary.withValues(alpha: 0.02)
                        ],
                      ),
                    ),
                    child: const Icon(Icons.location_off_rounded,
                        size: 60, color: AppColors.primary),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            AutoTranslate(
              text: _allStores.isEmpty
                  ? tr('هیچ شوێنێک نییە')
                  : tr('هیچ شوێنێک نەدۆزرایەوە'),
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
                  ? tr('داتابەیسەکە بەتاڵە — تکایە داتا زیاد بکە')
                  : tr('گەڕانەکەت هیچ ئەنجامێکی نەبوو'),
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
              label: Text(tr('دووبارە هەوڵ بدە'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Filter Sheet (لیستی فلتەرەکان)
  // ═══════════════════════════════════════════════════════════
  void _showFilterSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF16161D)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        // پەنجەرەکە خۆی نوێ دەبێتەوە کاتێک شتێک هەڵدەبژێردرێت
        builder: (ctx, setSheet) {
          void update(VoidCallback change) {
            HapticFeedback.selectionClick();
            setState(change);
            setSheet(() {});
            _applyFilters();
          }

          Widget title(String t) => Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 18),
                child: Text(tr(t),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
              );

          return Directionality(
            textDirection: AppLang.direction,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(tr('فلتەرکردن و ڕیزکردن'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                      if (_selectedType != 'هەموو' ||
                          _selectedCategory != 'هەموو')
                        TextButton(
                          onPressed: () => update(() {
                            _selectedType = 'هەموو';
                            _selectedCategory = 'هەموو';
                          }),
                          child: Text(tr('پاککردنەوە')),
                        ),
                    ],
                  ),
                  if (_currentPosition != null) ...[
                    title('ڕیزکردن'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('نزیکترین', _sortBy != 'name',
                            () => update(() => _sortBy = 'distance'),
                            icon: Icons.near_me_rounded),
                        _buildFilterChip('بەپێی ناو', _sortBy == 'name',
                            () => update(() => _sortBy = 'name'),
                            icon: Icons.sort_by_alpha_rounded),
                      ],
                    ),
                  ],
                  title('جۆری شوێن'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in ['هەموو', 'حکومی', 'ناحکومی'])
                        _buildFilterChip(t, _selectedType == t,
                            () => update(() => _selectedType = t),
                            icon: t == 'حکومی'
                                ? Icons.account_balance_rounded
                                : t == 'ناحکومی'
                                    ? Icons.storefront_rounded
                                    : Icons.apps_rounded),
                    ],
                  ),
                  title('بەشەکان'),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                              'هەموو',
                              _selectedCategory == 'هەموو',
                              () => update(() => _selectedCategory = 'هەموو'),
                              icon: Icons.apps_rounded,
                              count: _allStores.length),
                          for (final cat in _allCategories)
                            if ((cat['name'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                              _buildFilterChip(
                                cat['name'].toString(),
                                _selectedCategory == cat['name'].toString(),
                                () => update(() =>
                                    _selectedCategory = cat['name'].toString()),
                                icon: PlaceDisplay.icon(cat['name'].toString()),
                                count: _countFor(cat['name'].toString()),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        trf('پیشاندانی {0} ئەنجام', [PlaceDisplay.digits(_filteredStores.length)]),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap,
      {IconData? icon, int? count}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isSelected
        ? Colors.white
        : (isDark ? Colors.white70 : const Color(0xFF334155));
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: AutoTranslate(
                text: tr(label),
                lang: AppLang.code,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                PlaceDisplay.digits(count),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: fg.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
