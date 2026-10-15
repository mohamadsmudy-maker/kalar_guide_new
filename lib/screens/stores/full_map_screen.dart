import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../widgets/common/auto_translate.dart';
import 'store_details_dialog.dart';

/// 🗺️ شاشەی نەخشەی تەواو — ULTRA PRO V2
/// ✅ Marker Clustering — کۆکردنەوەی پینە نزیکەکان
class FullMapScreen extends StatefulWidget {
  const FullMapScreen({super.key});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  gmaps.GoogleMapController? _mapController;
  gmaps.MapType _currentMapType = gmaps.MapType.normal;
  Set<gmaps.Marker> _markers = {};
  List<Map<String, dynamic>> _allStores = [];
  List<String> _categories = ['هەموو'];
  bool _isLoading = true;
  bool _mapReady = false;
  double _currentZoom = 12.0;

  String _searchQuery = '';
  String _selectedCategory = 'هەموو';
  final TextEditingController _searchCtrl = TextEditingController();

  gmaps.Marker? _selectedMarker;
  final Map<int, gmaps.BitmapDescriptor> _clusterIconCache = {};
  Timer? _reclusterTimer;

  // ═══ Animation ═══
  bool _showLegend = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchStores();
    _preloadClusterIcons();
  }

  @override
  void dispose() {
    _reclusterTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Pre-load Cluster Icons (async)
  // ═══════════════════════════════════════════════════════════
  Future<void> _preloadClusterIcons() async {
    for (final count in [2, 5, 10, 20, 50, 100, 200, 500]) {
      await _createClusterIcon(count);
    }
  }

  Future<gmaps.BitmapDescriptor> _createClusterIcon(int count) async {
    if (_clusterIconCache.containsKey(count)) {
      return _clusterIconCache[count]!;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 140.0;
    const radius = 58.0;
    final center = const Offset(size / 2, size / 2);

    // Outer ring (white)
    canvas.drawCircle(
      center,
      radius + 5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // Gradient circle
    final gradient = ui.Gradient.linear(
      Offset.zero,
      const Offset(size, size),
      [const Color(0xFF1E88E5), const Color(0xFF6C5CE7)],
    );
    canvas.drawCircle(center, radius, Paint()..shader = gradient);

    // Inner highlight
    canvas.drawCircle(
      Offset(size / 2 - 15, size / 2 - 15),
      20,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // Count text
    final text = count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: count >= 100 ? 32 : 40,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2 - 2),
    );

    final image =
    await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = gmaps.BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());

    _clusterIconCache[count] = descriptor;
    return descriptor;
  }

  gmaps.BitmapDescriptor _getNearestClusterIcon(int count) {
    int nearest = 2;
    for (final key in [2, 5, 10, 20, 50, 100, 200, 500]) {
      if (key <= count) nearest = key;
    }
    return _clusterIconCache[nearest] ?? gmaps.BitmapDescriptor.defaultMarker;
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 Data Fetching
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('main_categories')
          .select()
          .order('name');

      Map<String, Map<String, dynamic>> uniqueMap = {};
      for (var cat in res) {
        uniqueMap[cat['name']] = cat;
      }

      if (mounted) {
        setState(() {
          _categories = [
            'هەموو',
            ...uniqueMap.values.map((c) => c['name'].toString()),
          ];
        });
      }
    } catch (e) {
      debugPrint('❌ Categories error: $e');
    }
  }

  Future<void> _fetchStores() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select()
          .order('name');

      final stores = List<Map<String, dynamic>>.from(res);

      if (mounted) {
        setState(() {
          _allStores = stores;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateMarkers();
        });
      }
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Filtering
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredStores {
    return _allStores.where((store) {
      final name = (store['name'] ?? '').toString().toLowerCase();
      final category = (store['category'] ?? '').toString().toLowerCase();
      final address = (store['address'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(q) ||
          address.contains(q) ||
          category.contains(q);

      final matchesCategory = _selectedCategory == 'هەموو' ||
          category.contains(_selectedCategory.toLowerCase());

      return matchesSearch && matchesCategory;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 Marker Clustering
  // ═══════════════════════════════════════════════════════════
  void _updateMarkers() async {
    if (!mounted) return;

    final stores = _filteredStores;
    final markers = <gmaps.Marker>{};

    // Cluster radius based on zoom — higher zoom = smaller radius
    // At zoom 10: ~500m, at zoom 18: ~5m
    final clusterRadius = 0.02 / (_currentZoom - 8).clamp(1, 20);

    final processed = <int>{};
    final clusters = <List<int>>[];

    // Extract valid coordinates once
    final coords = <int, gmaps.LatLng>{};
    for (int i = 0; i < stores.length; i++) {
      final lat = double.tryParse(stores[i]['latitude']?.toString() ?? '');
      final lng = double.tryParse(stores[i]['longitude']?.toString() ?? '');

      if (lat == null || lng == null || lat == 0 || lng == 0) continue;
      if (lat.isNaN || lng.isNaN) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;

      coords[i] = gmaps.LatLng(lat, lng);
    }

    // Cluster by proximity
    final indices = coords.keys.toList();
    for (int a = 0; a < indices.length; a++) {
      final i = indices[a];
      if (processed.contains(i)) continue;

      final cluster = [i];
      processed.add(i);

      final latI = coords[i]!.latitude;
      final lngI = coords[i]!.longitude;

      for (int b = a + 1; b < indices.length; b++) {
        final j = indices[b];
        if (processed.contains(j)) continue;

        final latJ = coords[j]!.latitude;
        final lngJ = coords[j]!.longitude;

        if ((latI - latJ).abs() < clusterRadius &&
            (lngI - lngJ).abs() < clusterRadius) {
          cluster.add(j);
          processed.add(j);
        }
      }

      clusters.add(cluster);
    }

    // Build markers
    for (final cluster in clusters) {
      if (cluster.length == 1) {
        // ═══ Single Marker ═══
        final store = stores[cluster[0]];
        final pos = coords[cluster[0]]!;

        double hue = gmaps.BitmapDescriptor.hueAzure;
        final type = (store['type'] ?? '').toString().trim();
        final category = (store['category'] ?? '').toString();

        if (type == 'حکومی') {
          hue = gmaps.BitmapDescriptor.hueGreen;
        } else if (category.contains('خواردن') ||
            category.contains('ڕێستۆرانت')) {
          hue = gmaps.BitmapDescriptor.hueOrange;
        } else if (category.contains('تەندروستی')) {
          hue = gmaps.BitmapDescriptor.hueRed;
        } else if (category.contains('پەروەردە')) {
          hue = gmaps.BitmapDescriptor.hueViolet;
        } else if (category.contains('بازاڕ') || category.contains('دوکان')) {
          hue = gmaps.BitmapDescriptor.hueYellow;
        }

        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId('store_${store['id']}'),
            position: pos,
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(hue),
            onTap: () {
              setState(() => _selectedMarker = null);
              _showStoreDetails(store);
            },
          ),
        );
      } else {
        // ═══ Cluster Marker ═══
        double sumLat = 0, sumLng = 0;
        for (final idx in cluster) {
          sumLat += coords[idx]!.latitude;
          sumLng += coords[idx]!.longitude;
        }
        final center = gmaps.LatLng(
          sumLat / cluster.length,
          sumLng / cluster.length,
        );

        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId('cluster_${cluster.first}_${cluster.length}'),
            position: center,
            icon: _getNearestClusterIcon(cluster.length),
            onTap: () {
              // Zoom in to expand cluster
              if (_mapController != null) {
                final newZoom = (_currentZoom + 2).clamp(10.0, 20.0);
                _mapController!.animateCamera(
                  gmaps.CameraUpdate.newLatLngZoom(center, newZoom),
                );
              }
            },
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _markers = markers);
    }
  }

  void _scheduleRecluster() {
    _reclusterTimer?.cancel();
    _reclusterTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _updateMarkers();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 Actions
  // ═══════════════════════════════════════════════════════════
  Future<void> _goToCurrentLocation() async {
    HapticFeedback.mediumImpact();
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && _mapController != null && mounted) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(pos.latitude, pos.longitude),
          16,
        ),
      );
    }
  }

  void _showStoreDetails(Map<String, dynamic> store) {
    HapticFeedback.lightImpact();
    StoreDetailsDialog.show(context, store);
  }

  Future<void> _showStoreListSheet() async {
    HapticFeedback.mediumImpact();
    final selectedStore = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoreListSheet(
        stores: _filteredStores,
        onStoreTap: (store) {
          Navigator.pop(context, store);
        },
      ),
    );

    if (selectedStore == null) return;
    await _goToStore(selectedStore);
  }

  Future<void> _goToStore(Map<String, dynamic> store) async {
    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');

    if (lat == null || lng == null || lat == 0 || lng == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ئەم شوێنە لۆکەیشنی نییە'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_mapController == null) return;

    _mapController!.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), 17),
    );

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _showStoreDetails(store);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;  // ⭐ زیادکرا
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        body: Stack(
          children: [
            // ═══ Map ═══
            _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
                : gmaps.GoogleMap(
              initialCameraPosition: const gmaps.CameraPosition(
                target: gmaps.LatLng(34.6189, 45.3156),
                zoom: 12,
              ),
              mapType: _currentMapType,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                _mapReady = true;
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_mapController != null && mounted) {
                    _mapController!.animateCamera(
                      gmaps.CameraUpdate.newLatLngZoom(
                        const gmaps.LatLng(34.6189, 45.3156),
                        12,
                      ),
                    );
                  }
                });
              },
              onCameraMove: (position) {
                _currentZoom = position.zoom;
              },
              onCameraIdle: _scheduleRecluster,
            ),

            // ═══ Top Search Bar ═══
            _buildSearchBar(isDark),

            // ═══ Filter Chips ═══
            _buildCategoriesFilter(isDark),

            // ═══ Legend (Toggle) ═══
            if (_showLegend) _buildLegendPanel(isDark),

            // ═══ Floating Buttons ═══
            Positioned(
              bottom: 240,
              right: 16,
              child: Column(
                children: [
                  _buildMapButton(
                    icon: _currentMapType == gmaps.MapType.satellite
                        ? Icons.map_rounded
                        : Icons.satellite_rounded,
                    color: _currentMapType == gmaps.MapType.satellite
                        ? AppColors.primary
                        : const Color(0xFF455A64),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _currentMapType = _currentMapType == gmaps.MapType.satellite
                            ? gmaps.MapType.normal
                            : gmaps.MapType.satellite;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMapButton(
                    icon: Icons.my_location_rounded,
                    color: const Color(0xFF1E88E5),
                    onTap: _goToCurrentLocation,
                  ),
                  const SizedBox(height: 12),
                  _buildMapButton(
                    icon: Icons.info_outline_rounded,
                    color: const Color(0xFF6C5CE7),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showLegend = !_showLegend);
                    },
                  ),
                ],
              ),
            ),

            // ═══ Bottom Stats Card ═══
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: _buildStatsCard(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Premium Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Search field
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
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
                  _scheduleRecluster();
                },
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'گەڕان بەدوای شوێنەکان...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(right: 8, left: 4),
                    child: Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
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
                      _scheduleRecluster();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ Categories Filter
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoriesFilter(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: SizedBox(
        height: 42,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory == cat;

            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat);
                  _scheduleRecluster();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF6C5CE7)],
                    )
                        : null,
                    color: isSelected
                        ? null
                        : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade200),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: isSelected ? 14 : 8,
                        offset: const Offset(0, 4),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Legend Panel
  // ═══════════════════════════════════════════════════════════
  Widget _buildLegendPanel(bool isDark) {
    return Positioned(
      bottom: 240,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ڕەنگی پینەکان',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            _legendItem(const Color(0xFF10B981), 'حکومی'),
            _legendItem(const Color(0xFF1E88E5), 'ناحکومی'),
            _legendItem(const Color(0xFFF59E0B), 'خواردن'),
            _legendItem(const Color(0xFFEF4444), 'تەندروستی'),
            _legendItem(const Color(0xFF8B5CF6), 'پەروەردە'),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Map Button
  // ═══════════════════════════════════════════════════════════
  Widget _buildMapButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 5),
              spreadRadius: -3,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsCard(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showStoreListSheet,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF6C5CE7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'شوێنەکانی نەخشە',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${_filteredStores.length} شوێن',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_markers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF10B981).withValues(alpha: 0.15),
                                  const Color(0xFF10B981).withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 10,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${_markers.length} پین',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981),
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

              // Arrow
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.list_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 📋 Store List Bottom Sheet — ULTRA PRO
// ═══════════════════════════════════════════════════════════════
class _StoreListSheet extends StatefulWidget {
  final List<Map<String, dynamic>> stores;
  final Function(Map<String, dynamic>) onStoreTap;

  const _StoreListSheet({
    required this.stores,
    required this.onStoreTap,
  });

  @override
  State<_StoreListSheet> createState() => _StoreListSheetState();
}

class _StoreListSheetState extends State<_StoreListSheet> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return widget.stores;
    final q = _searchQuery.toLowerCase();
    return widget.stores.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final address = (s['address'] ?? '').toString().toLowerCase();
      return name.contains(q) || address.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // ═══ Drag Handle ═══
                const SizedBox(height: 10),
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),

                // ═══ Header ═══
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF6C5CE7)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'شوێنەکانی نەخشە',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.stores.length} شوێن',
                              style: TextStyle(
                                fontSize: 11,
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

                const SizedBox(height: 16),

                // ═══ Search ═══
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F0F14)
                          : const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'گەڕان بەدوای شوێن...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ═══ List ═══
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 50,
                          color: isDark
                              ? Colors.white24
                              : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'هیچ شوێنێک نەدۆزرایەوە',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      return _buildStoreTile(_filtered[index], isDark, lang);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreTile(Map<String, dynamic> store, bool isDark, String lang) {
    final name = store['name']?.toString() ?? '';
    final address = store['address']?.toString() ?? 'کەلار';
    final image = store['image']?.toString() ?? '';
    final isGov = (store['type']?.toString() ?? '') == 'حکومی';
    final accentColor = isGov ? const Color(0xFF10B981) : AppColors.primary;

    return GestureDetector(
      onTap: () => widget.onStoreTap(store),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFFAFBFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(2),   // ⭐ لێرە، نەک لە BoxDecoration
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image.isNotEmpty
                    ? OptimizedNetworkImage(
                  imageUrl: image,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                )
                    : Container(
                  color: accentColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: accentColor,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AutoTranslate(
                    text: name,
                    lang: lang,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: accentColor,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: AutoTranslate(
                          text: address,
                          lang: lang,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: accentColor,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}