import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../widgets/common/auto_translate.dart';
import 'store_details_dialog.dart';

/// 🗺️ شاشەی نەخشەی تەواو
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

  String _searchQuery = '';
  String _selectedCategory = 'هەموو';
  final TextEditingController _searchCtrl = TextEditingController();

  Position? _currentPosition;
  gmaps.Marker? _selectedMarker;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchStores();
    _fetchCategories();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    final pos = await LocationService.getCurrentPosition();
    if (mounted) setState(() => _currentPosition = pos);
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی کاتێگۆرییەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('main_categories')
          .select();

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

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی شوێنەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchStores() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('dukan').select();
      final stores = List<Map<String, dynamic>>.from(res);

      debugPrint('📊 کۆی شوێنەکان: ${stores.length}');

      if (mounted) {
        setState(() {
          _allStores = stores;
          _isLoading = false;
        });
        _updateMarkers(_filteredStores);
      }
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 فلتەرکردن
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
  // 📍 دروستکردنی پینەکان
  // ═══════════════════════════════════════════════════════════
  void _updateMarkers(List<Map<String, dynamic>> stores) {
    Set<gmaps.Marker> markers = {};
    int validCount = 0;

    for (var store in stores) {
      final id = store['id'];
      if (id == null || id.toString().isEmpty) continue;

      double? lat;
      double? lng;

      try {
        final latRaw = store['latitude'];
        final lngRaw = store['longitude'];

        if (latRaw is num) {
          lat = latRaw.toDouble();
        } else {
          lat = double.tryParse(latRaw?.toString() ?? '');
        }

        if (lngRaw is num) {
          lng = lngRaw.toDouble();
        } else {
          lng = double.tryParse(lngRaw?.toString() ?? '');
        }
      } catch (_) {
        continue;
      }

      if (lat == null ||
          lng == null ||
          lat == 0.0 ||
          lng == 0.0 ||
          lat.isNaN ||
          lng.isNaN ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        continue;
      }

      validCount++;

      // 🎨 ڕەنگی پین
      double markerHue = gmaps.BitmapDescriptor.hueAzure;
      String type = (store['type'] ?? '').toString().trim();
      String category = (store['category'] ?? '').toString();

      if (type == 'حکومی') {
        markerHue = gmaps.BitmapDescriptor.hueGreen;
      } else if (category.contains('خواردن') ||
          category.contains('ڕێستۆرانت')) {
        markerHue = gmaps.BitmapDescriptor.hueOrange;
      } else if (category.contains('تەندروستی')) {
        markerHue = gmaps.BitmapDescriptor.hueRed;
      } else if (category.contains('پەروەردە')) {
        markerHue = gmaps.BitmapDescriptor.hueViolet;
      } else if (category.contains('بازاڕ') || category.contains('دوکان')) {
        markerHue = gmaps.BitmapDescriptor.hueYellow;
      }

      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId(id.toString()),
          position: gmaps.LatLng(lat, lng),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(markerHue),
          infoWindow: gmaps.InfoWindow(
            title: store['name']?.toString() ?? 'شوێن',
            snippet: store['address']?.toString() ?? 'کەلار',
          ),
          onTap: () {
            StoreDetailsDialog.show(context, store);
          },
        ),
      );
    }

    debugPrint('✅ دروست: $validCount لە کۆی ${stores.length}');

    if (mounted) {
      setState(() => _markers = markers);

      // ✅ گواستنەوە بۆ ناوچەی مارکەرەکان
      if (markers.isNotEmpty && _mapReady && _mapController != null) {
        final positions = markers.map((m) => m.position).toList();
        final avgLat =
            positions.map((p) => p.latitude).reduce((a, b) => a + b) /
                positions.length;
        final avgLng =
            positions.map((p) => p.longitude).reduce((a, b) => a + b) /
                positions.length;

        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(avgLat, avgLng),
            11,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 دوگمەکان
  // ═══════════════════════════════════════════════════════════
  void _goToCurrentLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      setState(() => _currentPosition = pos);
      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(pos.latitude, pos.longitude),
          16,
        ),
      );
    }
  }

  Future<void> _goToStore(Map<String, dynamic> store) async {
    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');

    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
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

    _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), 17.0),
    );

    setState(() {
      _selectedMarker = gmaps.Marker(
        markerId: const gmaps.MarkerId('selected_store'),
        position: gmaps.LatLng(lat, lng),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueRed,
        ),
        infoWindow: gmaps.InfoWindow(
          title: store['name'] ?? 'شوێن',
          snippet: store['address'] ?? 'کەلار',
        ),
        zIndex: 10,
      );
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      StoreDetailsDialog.show(context, store);
    }
  }

  Future<void> _showStoreListSheet() async {
    final selectedStore = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StoreListSheet(stores: _filteredStores),
    );

    if (selectedStore == null) return;
    await _goToStore(selectedStore);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // 🗺️ نەخشە
            _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
                : gmaps.GoogleMap(
              initialCameraPosition: const gmaps.CameraPosition(
                target: gmaps.LatLng(34.6189, 45.3156),
                zoom: 12,
              ),
              mapType: _currentMapType,
              markers: {
                ..._markers,
                if (_selectedMarker != null) _selectedMarker!,
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                _mapReady = true;

                Future.delayed(
                  const Duration(milliseconds: 500),
                      () {
                    if (_mapController != null && mounted) {
                      _mapController!.animateCamera(
                        gmaps.CameraUpdate.newLatLngZoom(
                          const gmaps.LatLng(34.6189, 45.3156),
                          11,
                        ),
                      );
                    }
                  },
                );
              },
            ),

            // 🔍 بەشی سەرەوە
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                          _updateMarkers(_filteredStores);
                        },
                        decoration: InputDecoration(
                          hintText: "گەڕان بەدوای شوێنەکان...",
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                              _updateMarkers(_filteredStores);
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🏷️ فلتەری کاتێگۆری
            Positioned(
              top: 105,
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
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color:
                          isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        elevation: isSelected ? 3 : 1,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                          _updateMarkers(_filteredStores);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // 📍 دوگمەی شوێنی ئێستا
            Positioned(
              bottom: 100,
              right: 16,
              child: _buildMapButton(
                icon: Icons.my_location_rounded,
                color: AppColors.primary,
                onTap: _goToCurrentLocation,
              ),
            ),

            // 🛰️ دوگمەی ساتەلایت
            Positioned(
              bottom: 160,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentMapType =
                    _currentMapType == gmaps.MapType.satellite
                        ? gmaps.MapType.normal
                        : gmaps.MapType.satellite;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _currentMapType == gmaps.MapType.satellite
                        ? Colors.blueGrey.shade700
                        : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentMapType == gmaps.MapType.satellite
                            ? Icons.map_rounded
                            : Icons.satellite_rounded,
                        color: _currentMapType == gmaps.MapType.satellite
                            ? Colors.white
                            : Colors.blueGrey,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentMapType == gmaps.MapType.satellite
                            ? "ئاسایی"
                            : "ساتەلایت",
                        style: TextStyle(
                          color:
                          _currentMapType == gmaps.MapType.satellite
                              ? Colors.white
                              : Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 📊 کارتی ئاماری شوێنەکان
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: _showStoreListSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "شوێنەکانی نەخشە",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  "${_filteredStores.length} شوێن",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_markers.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${_markers.length} پین",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.list_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

/// 📋 لیستی شوێنەکان (Bottom Sheet)
class _StoreListSheet extends StatelessWidget {
  final List<Map<String, dynamic>> stores;

  const _StoreListSheet({required this.stores});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.6,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 20),
                SizedBox(width: 6),
                Text(
                  "شوێنەکانی نەخشە",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: stores.isEmpty
                  ? const Center(
                child: Text(
                  "هیچ شوێنێک نەدۆزرایەوە",
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: stores.length,
                itemBuilder: (context, index) {
                  var store = stores[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: OptimizedNetworkImage(
                          imageUrl: store['image'] ?? '',
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: AutoTranslate(
                        text: store['name']?.toString() ?? '',
                        lang: lang,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                      ),
                      subtitle: AutoTranslate(
                        text: store['address']?.toString() ?? 'کەلار',
                        lang: lang,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.grey,
                      ),
                      onTap: () => Navigator.pop(context, store),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}