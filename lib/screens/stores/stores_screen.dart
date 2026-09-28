import 'package:flutter/material.dart';
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

/// 🏪 شاشەی شوێنەکان — PRO EDITION + Cache
class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  static const String _cacheKey = 'stores_list';
  static const Duration _cacheDuration = Duration(minutes: 30);

  String _searchQuery = '';
  String _selectedCategory = 'هەموو';
  String _selectedType = 'هەموو';
  final TextEditingController _searchCtrl = TextEditingController();

  Position? _currentPosition;
  bool _loadingStores = true;
  List<Map<String, dynamic>> _allStores = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchStores();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
      // ✅ ئەگەر forceRefresh نەبوو، لە کاش بهێنە
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

      // ❌ لە Supabase بهێنە
      final res = await Supabase.instance.client.from('dukan').select();
      final stores = List<Map<String, dynamic>>.from(res);

      int withLoc = 0;
      for (var s in stores) {
        final lat = double.tryParse(s['latitude']?.toString() ?? '');
        final lng = double.tryParse(s['longitude']?.toString() ?? '');
        if (lat != null && lng != null && lat != 0 && lng != 0) {
          withLoc++;
        }
      }
      debugPrint('📊 StoresScreen: ${stores.length} کۆی، $withLoc بە لۆکەیشن');

      // ✅ پاشەکەوت لە کاش
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

  // ═══════════════════════════════════════════════════════════
  // 🔄 Pull-to-Refresh — کاش بسڕەوە
  // ═══════════════════════════════════════════════════════════
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
  // 🎯 فلتەرکردنی شوێنەکان
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredStores {
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

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            // 🔍 بەشی سەرەوە
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: AppTranslations.t(
                            'stores_search_hint',
                            lang,
                          ),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 🗺️ دوگمەی ماپ
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FullMapScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3)
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ فلتەری جۆر
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeFilter(
                      icon: Icons.account_balance_rounded,
                      labelKey: 'stores_government',
                      fallbackLabel: 'حکومی',
                      isSelected: _selectedType == 'حکومی',
                      color: const Color(0xFF2E7D32),
                      onTap: () => setState(
                            () => _selectedType = _selectedType == 'حکومی'
                            ? 'هەموو'
                            : 'حکومی',
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
                      onTap: () => setState(
                            () => _selectedType = _selectedType == 'ناحکومی'
                            ? 'هەموو'
                            : 'ناحکومی',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 🏷️ فلتەری بەشەکان
            FutureBuilder<List<Map<String, dynamic>>>(
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
                  height: 45,
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
                        child: ChoiceChip(
                          label: Text(displayCat),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 12,
                          ),
                          backgroundColor: isDark
                              ? const Color(0xFF1A1A22)
                              : Colors.white,
                          elevation: isSelected ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // 📊 ئاماری ئەنجامەکان
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        AppText(
                          'stores_count',
                          fallback: '${_filteredStores.length} شوێن',
                          params: {'count': '${_filteredStores.length}'},
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
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
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 📋 لیستی شوێنەکان
            Expanded(
              child: _loadingStores
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : _filteredStores.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      size: 70,
                      color: isDark
                          ? Colors.white24
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      'no_results',
                      fallback: 'هیچ شوێنێک نەدۆزرایەوە 📍',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _onRefresh,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _filteredStores.length,
                  itemBuilder: (context, index) {
                    var store = _filteredStores[index];
                    double? lat = double.tryParse(
                      store['latitude']?.toString() ?? '',
                    );
                    double? lng = double.tryParse(
                      store['longitude']?.toString() ?? '',
                    );
                    double distance = _calculateDistance(lat, lng);

                    return StoreCard(
                      store: store,
                      distance: distance,
                      onTap: () => StoreDetailsDialog.show(
                        context,
                        store,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 کاشکردنی کەتێگۆرییەکان
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _fetchCategoriesCached() async {
    const key = 'main_categories';
    final cached = await CacheService.get(key);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached as List);
    }

    final res = await Supabase.instance.client.from('main_categories').select();
    final list = List<Map<String, dynamic>>.from(res);
    await CacheService.save(key, list, duration: const Duration(hours: 1));
    return list;
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ دوگمەی فلتەری جۆر
  // ═══════════════════════════════════════════════════════════
  Widget _buildTypeFilter({
    required IconData icon,
    required String labelKey,
    required String fallbackLabel,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
            const SizedBox(width: 6),
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
              const SizedBox(width: 4),
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}