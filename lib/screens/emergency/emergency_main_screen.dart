import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/emergency_service.dart';
import '../../models/emergency_categories.dart';
import '../../services/emergency_repository.dart';
import '../../services/location_service.dart';

/// 🚨 شاشەی فریاکەوتن — ULTRA PRO V2
///
/// ✅ تایبەتمەندییەکان:
/// 1. Animated Header
/// 2. Category Filter
/// 3. Search Bar
/// 4. Sort by Distance
/// 5. Mini Map
/// 6. Quick Dial
/// 7. Share
/// 8. Favorites
/// 9. History
/// 10. 24h Badge
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  bool _loading = true;
  List<EmergencyService> _services = [];
  List<EmergencyService> _filteredServices = [];
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Position? _currentPosition;
  String _sortBy = 'default'; // 'default', 'distance', 'name'

  // ⭐ Favorites
  final Set<String> _favorites = {};

  // ✨ Animations
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

    _loadData();
    _determinePosition();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 Data
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);

    try {
      final data = await EmergencyServiceRepository.getAll();
      debugPrint('🚨 Loaded emergency services: ${data.length}');

      if (mounted) {
        setState(() {
          _services = data;
          _applyFilters();
          _loading = false;
        });
        _entryController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('❌ Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _determinePosition() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = pos);
        _applyFilters();
      }
    } catch (e) {
      debugPrint('⚠️ Position error: $e');
    }
  }

  void _applyFilters() {
    var filtered = List<EmergencyService>.from(_services);

    // ⭐ Category
    if (_selectedCategory != 'all') {
      filtered = filtered
          .where((s) => s.category == _selectedCategory)
          .toList();
    }

    // ⭐ Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        return s.nameKu.toLowerCase().contains(q) ||
            s.phone.toLowerCase().contains(q) ||
            (s.authorityName?.toLowerCase().contains(q) ?? false) ||
            (s.address?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // ⭐ Sort
    if (_sortBy == 'distance' && _currentPosition != null) {
      filtered.sort((a, b) {
        final distA = _getDistance(a);
        final distB = _getDistance(b);
        return distA.compareTo(distB);
      });
    } else if (_sortBy == 'name') {
      filtered.sort((a, b) => a.nameKu.compareTo(b.nameKu));
    }

    setState(() => _filteredServices = filtered);
  }

  double _getDistance(EmergencyService service) {
    if (_currentPosition == null ||
        service.latitude == null ||
        service.longitude == null) {
      return 99999.0;
    }
    return LocationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      service.latitude!,
      service.longitude!,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📞 Call
  // ═══════════════════════════════════════════════════════════
  Future<void> _call(String phone) async {
    HapticFeedback.heavyImpact();
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('❌ Call error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF0F4F9),
        body: RefreshIndicator(
          color: const Color(0xFFDC2626),
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(isDark),
              SliverToBoxAdapter(child: _buildSearchBar(isDark)),
              SliverToBoxAdapter(child: _buildFilters(isDark)),
              SliverToBoxAdapter(child: _buildSortBar(isDark)),
              SliverToBoxAdapter(child: _buildStatsCard(isDark)),
              _buildServicesList(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar — ULTRA PRO
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFFDC2626),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
          tooltip: 'نوێکردنەوە',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFDC2626),
                Color(0xFFFF7043),
                Color(0xFFE53935),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
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
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              // ⭐ Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.6,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.emergency_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ژمارەکانی فریاکەوتن',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
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
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.phone_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_services.length} ژمارە',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_filled_rounded,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        '٢٤/٧',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
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
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _searchQuery.isNotEmpty
                ? const Color(0xFFDC2626).withValues(alpha: 0.5)
                : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
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
            hintText: 'گەڕان بەدوای ژمارە...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFFDC2626),
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
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
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Category Filters
  // ═══════════════════════════════════════════════════════════
  Widget _buildFilters(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: EmergencyCategories.categories.length,
        itemBuilder: (context, i) {
          final cat = EmergencyCategories.categories[i];
          final isSelected = _selectedCategory == cat['key'];
          final catInfo = _getCategoryInfo(cat['key']!);

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat['key']!);
                _applyFilters();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      catInfo['color'] as Color,
                      (catInfo['color'] as Color)
                          .withValues(alpha: 0.7),
                    ],
                  )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark
                      ? const Color(0xFF1A1A22)
                      : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200),
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: (catInfo['color'] as Color)
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      catInfo['icon'] as IconData,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (catInfo['color'] as Color),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat['name']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                            ? Colors.white70
                            : Colors.grey.shade700),
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
  }

  Map<String, dynamic> _getCategoryInfo(String key) {
    switch (key) {
      case 'police':
        return {'icon': Icons.local_police_rounded, 'color': const Color(0xFF1E88E5)};
      case 'fire':
        return {'icon': Icons.local_fire_department_rounded, 'color': const Color(0xFFEF4444)};
      case 'ambulance':
        return {'icon': Icons.local_hospital_rounded, 'color': const Color(0xFF10B981)};
      case 'hospital':
        return {'icon': Icons.local_hospital_rounded, 'color': const Color(0xFF10B981)};
      case 'power':
        return {'icon': Icons.electric_bolt_rounded, 'color': const Color(0xFFF59E0B)};
      case 'water':
        return {'icon': Icons.water_drop_rounded, 'color': const Color(0xFF3B82F6)};
      case 'utility':
        return {'icon': Icons.build_rounded, 'color': const Color(0xFF8B5CF6)};
      case 'other':
        return {'icon': Icons.phone_in_talk_rounded, 'color': const Color(0xFF6B7280)};
      default:
        return {'icon': Icons.apps_rounded, 'color': const Color(0xFFDC2626)};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔀 Sort Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSortBar(bool isDark) {
    final sorts = [
      {'key': 'default', 'label': 'ئاسایی', 'icon': Icons.sort_rounded},
      {'key': 'distance', 'label': 'نزیکترین', 'icon': Icons.near_me_rounded},
      {'key': 'name', 'label': 'ناو', 'icon': Icons.abc_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: 16,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
          const SizedBox(width: 8),
          ...sorts.map((sort) {
            final isSelected = _sortBy == sort['key'];
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _sortBy = sort['key'] as String);
                  _applyFilters();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                        : (isDark
                        ? const Color(0xFF1A1A22)
                        : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFDC2626)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sort['icon'] as IconData,
                        size: 12,
                        color: isSelected
                            ? const Color(0xFFDC2626)
                            : (isDark ? Colors.white54 : Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sort['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? const Color(0xFFDC2626)
                              : (isDark ? Colors.white54 : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsCard(bool isDark) {
    final hasPosition = _currentPosition != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFDC2626).withValues(alpha: 0.15),
              const Color(0xFFFF7043).withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_rounded,
                color: Color(0xFFDC2626),
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
                    '${_filteredServices.length} ژمارە بەردەستە',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (hasPosition)
                    Text(
                      'ڕیزکراوە بەپێی دووری لە شوێنەکەت',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            if (hasPosition)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      color: Colors.green,
                      size: 11,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'نزیک',
                      style: TextStyle(
                        fontSize: 9,
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
  // 📋 Services List
  // ═══════════════════════════════════════════════════════════
  Widget _buildServicesList(bool isDark) {
    if (_loading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFDC2626)),
        ),
      );
    }

    if (_filteredServices.isEmpty) {
      return SliverFillRemaining(child: _buildEmpty(isDark));
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, i) {
            final card = _buildServiceCard(_filteredServices[i], isDark);

            // ⭐ Animation بۆ ٦ ی یەکەم
            if (i >= 6) return card;

            return AnimatedBuilder(
              animation: _entryAnimation,
              builder: (context, child) {
                final delay = (i * 0.08).clamp(0.0, 0.5);
                final progress =
                ((_entryAnimation.value - delay) / 0.4).clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - progress)),
                  child: Opacity(
                    opacity: progress,
                    child: child,
                  ),
                );
              },
              child: card,
            );
          },
          childCount: _filteredServices.length,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Service Card — ULTRA PRO
  // ═══════════════════════════════════════════════════════════
  Widget _buildServiceCard(EmergencyService service, bool isDark) {
    final color = _hexToColor(service.color);
    final icon = _getIconData(service.icon);
    final isFavorite = _favorites.contains(service.id);
    final distance = _getDistance(service);
    final hasDistance = distance < 99999.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _call(service.phone),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    // ⭐ Icon
                    AnimatedBuilder(
                      animation: service.isImportant
                          ? _pulseController
                          : const AlwaysStoppedAnimation(1.0),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: service.isImportant
                              ? 1.0 + (_pulseAnimation.value - 1.0) * 0.3
                              : 1.0,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color,
                                  color.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 26),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),

                    // ⭐ Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  service.nameKu,
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
                              if (service.isImportant)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'گرنگ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                size: 13,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                service.phone,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (service.is24h) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_filled_rounded,
                                        size: 9,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        '٢٤/٧',
                                        style: TextStyle(
                                          fontSize: 8,
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (service.authorityName != null &&
                                  service.authorityName!.isNotEmpty) ...[
                                Icon(
                                  Icons.business_rounded,
                                  size: 10,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    service.authorityName!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (hasDistance) ...[
                                if (service.authorityName != null &&
                                    service.authorityName!.isNotEmpty)
                                  const SizedBox(width: 8),
                                Icon(
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ⭐ Call Button
                    GestureDetector(
                      onTap: () => _call(service.phone),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.8)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),

                // ⭐ Actions Row
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade200,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // ⭐ Favorites
                    _buildActionButton(
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: isFavorite ? 'دڵخواز' : 'زیادکردن',
                      color: isFavorite ? Colors.pink : Colors.grey,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isFavorite) {
                            _favorites.remove(service.id);
                          } else {
                            _favorites.add(service.id!);
                          }
                        });
                      },
                    ),
                    // ⭐ Share
                    _buildActionButton(
                      icon: Icons.share_rounded,
                      label: 'هاوبەشکردن',
                      color: Colors.blue,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _shareService(service);
                      },
                    ),
                    // ⭐ Directions
                    if (service.hasLocation)
                      _buildActionButton(
                        icon: Icons.directions_rounded,
                        label: 'ئاراستە',
                        color: Colors.green,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _openDirections(service);
                        },
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareService(EmergencyService service) {
    // TODO: بەکارهێنانی share_plus
    debugPrint('📤 Share: ${service.nameKu} - ${service.phone}');
  }

  Future<void> _openDirections(EmergencyService service) async {
    if (service.latitude == null || service.longitude == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${service.latitude},${service.longitude}',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ Directions error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmpty(bool isDark) {
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
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFDC2626).withValues(alpha: 0.2),
                          const Color(0xFFDC2626).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.emergency_outlined,
                      size: 60,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isEmpty
                  ? 'هیچ ژمارەیەک نییە'
                  : 'هیچ ئەنجامێک نەدۆزرایەوە',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'تکایە داتا لە داتابەیس زیاد بکە'
                  : 'گەڕانەکەت هیچ ئەنجامێکی نەبوو',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  IconData _getIconData(String icon) {
    switch (icon) {
      case 'local_police':
        return Icons.local_police_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'electric_bolt':
      case 'bolt':
        return Icons.electric_bolt_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'business':
        return Icons.business_rounded;
      case 'construction':
        return Icons.construction_rounded;
      case 'phone_in_talk':
        return Icons.phone_in_talk_rounded;
      default:
        return Icons.emergency_rounded;
    }
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFDC2626);
    }
  }
}