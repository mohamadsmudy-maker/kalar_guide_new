import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../services/location_service.dart';

/// 🗺️ شاشەی هەڵبژاردنی شوێن لەسەر نەخشە (Pro Version)
class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // ═══════════════════════════════════════════════════════════
  // 🔐 API Key — لە .env یان --dart-define
  // ═══════════════════════════════════════════════════════════
  static String get _apiKey {
    // ✅ ١. لە .env هەوڵ بدە
    final envKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (envKey.isNotEmpty) return envKey;

    // ✅ ٢. لە --dart-define هەوڵ بدە (بۆ Release)
    const dartDefineKey = String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: '',
    );
    return dartDefineKey;
  }

  gmaps.LatLng? _selectedLocation;
  gmaps.MapType _currentMapType = gmaps.MapType.normal;
  gmaps.GoogleMapController? _mapController;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  // ✅ زانیاری شوێنی هەڵبژێردراو
  Map<String, dynamic>? _selectedPOI;
  bool _loadingPOI = false;

  // ═══════════════════════════════════════════════════════════
  // 🚀 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = gmaps.LatLng(
        widget.initialLat!,
        widget.initialLng!,
      );
    } else {
      _selectedLocation = const gmaps.LatLng(
        AppConstants.kalarLatitude,
        AppConstants.kalarLongitude,
      );
    }

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showResults = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 گەڕان بۆ نزیکترین شوێن لە خاڵێکی دیاریکراو
  // ═══════════════════════════════════════════════════════════
  Future<void> _findNearestPlace(double lat, double lng) async {
    try {
      if (_apiKey.isEmpty) {
        _showError('Google Maps API Key دانەنراوە');
        if (mounted) setState(() => _loadingPOI = false);
        return;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=$lat,$lng'
            '&radius=50'
            '&language=ku'
            '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final result = data['results'][0];
          final placeId = result['place_id'];
          await _getPlaceDetails(placeId);
          return;
        }
      }

      // ✅ ئەگەر هیچ POI نەدۆزرایەوە، تەنها کۆئۆردینەت پیشان بدە
      _showCoordinateOnly(lat, lng);
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      _showCoordinateOnly(lat, lng);
    }
  }

  /// ✅ پیشاندانی تەنها کۆئۆردینەت
  void _showCoordinateOnly(double lat, double lng) {
    if (!mounted) return;
    setState(() {
      _loadingPOI = false;
      _selectedPOI = {
        'name': 'شوێنی هەڵبژێردراو',
        'address':
        'کۆئۆردینەت: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
        'phone': '',
        'lat': lat,
        'lng': lng,
        'rating': 0,
        'types': [],
        'photo': null,
        'place_id': '',
      };
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 وەرگرتنی زانیاری شوێن بە Place ID
  // ═══════════════════════════════════════════════════════════
  Future<void> _getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=$placeId'
            '&language=ku'
            '&fields=name,formatted_address,geometry,formatted_phone_number,rating,types,photos'
            '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];

          String? photoUrl;
          if (result['photos'] != null && result['photos'].isNotEmpty) {
            final photoRef = result['photos'][0]['photo_reference'];
            photoUrl =
            'https://maps.googleapis.com/maps/api/place/photo'
                '?maxwidth=800'
                '&photo_reference=$photoRef'
                '&key=$_apiKey';
          }

          final poiData = {
            'name': result['name'] ?? '',
            'address': result['formatted_address'] ?? '',
            'phone': result['formatted_phone_number'] ?? '',
            'lat': result['geometry']['location']['lat'],
            'lng': result['geometry']['location']['lng'],
            'rating': result['rating'] ?? 0,
            'types': result['types'] ?? [],
            'photo': photoUrl,
            'place_id': placeId,
          };

          if (mounted) {
            setState(() {
              _selectedPOI = poiData;
              _loadingPOI = false;
              _selectedLocation = gmaps.LatLng(
                (poiData['lat'] as num).toDouble(),
                (poiData['lng'] as num).toDouble(),
              );
            });
          }
          return;
        }
      }

      if (mounted) setState(() => _loadingPOI = false);
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      if (mounted) setState(() => _loadingPOI = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 سێرچکردن بە Google Places API
  // ═══════════════════════════════════════════════════════════
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showResults = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
        _showResults = true;
      });
    }

    try {
      if (_apiKey.isEmpty) {
        _showError('Google Maps API Key دانەنراوە');
        if (mounted) setState(() => _isSearching = false);
        return;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
            '?query=${Uri.encodeComponent(query)}'
            '&location=${AppConstants.kalarLatitude},${AppConstants.kalarLongitude}'
            '&radius=30000'
            '&language=ku'
            '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'];

        if (status == 'OK') {
          final results = List<Map<String, dynamic>>.from(
            (data['results'] as List).map((e) => {
              'name': e['name'] ?? '',
              'address': e['formatted_address'] ?? '',
              'lat': e['geometry']['location']['lat'],
              'lng': e['geometry']['location']['lng'],
              'place_id': e['place_id'] ?? '',
              'rating': e['rating'] ?? 0,
              'types': e['types'] ?? [],
            }),
          );

          if (mounted) {
            setState(() {
              _searchResults = results;
              _isSearching = false;
            });
          }
        } else if (status == 'ZERO_RESULTS') {
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isSearching = false;
            });
          }
        } else {
          _showError('هەڵەی API: $status');
          if (mounted) setState(() => _isSearching = false);
        }
      } else {
        _showError('کێشەی پەیوەندی: ${response.statusCode}');
        if (mounted) setState(() => _isSearching = false);
      }
    } catch (e) {
      _showError('هەڵە: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 چوونە سەر ئەنجامەکە
  // ═══════════════════════════════════════════════════════════
  Future<void> _goToResult(Map<String, dynamic> result) async {
    final lat = (result['lat'] as num).toDouble();
    final lng = (result['lng'] as num).toDouble();
    final newPos = gmaps.LatLng(lat, lng);

    if (mounted) {
      setState(() {
        _selectedLocation = newPos;
        _searchCtrl.text = result['name'] ?? '';
        _showResults = false;
        _searchResults = [];
        _loadingPOI = true;
      });
    }

    _searchFocus.unfocus();

    _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(newPos, 17),
    );

    await _getPlaceDetails(result['place_id']);
  }

  // ═══════════════════════════════════════════════════════════
  // 🏠 چوونە شوێنی ئێستا
  // ═══════════════════════════════════════════════════════════
  Future<void> _goToCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final currentPos = gmaps.LatLng(
          position.latitude,
          position.longitude,
        );
        if (mounted) {
          setState(() {
            _selectedLocation = currentPos;
            _selectedPOI = null;
          });
        }
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(currentPos, 17),
        );
      } else {
        _showError('نەتوانرا شوێنی ئێستا بدۆزرێتەوە');
      }
    } catch (e) {
      _showError('هەڵە: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔔 SnackBar Helper
  // ═══════════════════════════════════════════════════════════
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
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
            _buildMap(),

            // 🔍 سەرەوە
            _buildSearchBar(),

            // 📍 دوگمەی شوێنی ئێستا
            Positioned(
              bottom: 100,
              left: 20,
              child: _buildMapButton(
                icon: Icons.my_location_rounded,
                color: AppColors.primary,
                onTap: _goToCurrentLocation,
              ),
            ),

            // 🛰️ دوگمەی ساتەلایت
            Positioned(
              bottom: 160,
              left: 20,
              child: _buildMapButton(
                icon: _currentMapType == gmaps.MapType.satellite
                    ? Icons.map_rounded
                    : Icons.satellite_rounded,
                color: Colors.blueGrey,
                onTap: () {
                  setState(() {
                    _currentMapType =
                    _currentMapType == gmaps.MapType.satellite
                        ? gmaps.MapType.normal
                        : gmaps.MapType.satellite;
                  });
                },
              ),
            ),

            // ⏳ لۆدینگ POI
            if (_loadingPOI) _buildLoadingOverlay(),

            // 📋 زانیاری POI (Bottom Sheet)
            if (_selectedPOI != null && !_loadingPOI)
              _buildPOIBottomSheet(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Map Widget
  // ═══════════════════════════════════════════════════════════
  Widget _buildMap() {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _selectedLocation ??
            const gmaps.LatLng(
              AppConstants.kalarLatitude,
              AppConstants.kalarLongitude,
            ),
        zoom: 16,
      ),
      mapType: _currentMapType,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      compassEnabled: true,
      markers: _selectedLocation == null
          ? {}
          : {
        gmaps.Marker(
          markerId: const gmaps.MarkerId('picked'),
          position: _selectedLocation!,
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueRed,
          ),
        ),
      },
      onMapCreated: (controller) => _mapController = controller,
      onTap: (pos) async {
        setState(() {
          _selectedLocation = pos;
          _selectedPOI = null;
          _loadingPOI = true;
        });
        await _findNearestPlace(pos.latitude, pos.longitude);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      right: 12,
      child: Column(
        children: [
          Row(
            children: [
              // دوگمەی گەڕانەوە
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // خانەی گەڕان
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                    focusNode: _searchFocus,
                    onSubmitted: _searchLocation,
                    onChanged: (val) {
                      if (val.length >= 2) {
                        _searchLocation(val);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "گەڕان (بە ئینگلیزی: bakery، cafe)",
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchResults = [];
                            _showResults = false;
                          });
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 📋 ئەنجامەکان
          if (_showResults && _searchResults.isNotEmpty)
            _buildSearchResults(),

          // ⏳ لۆدینگ
          if (_isSearching) _buildSearchingIndicator(),

          // 📭 هیچ نییە
          if (_showResults &&
              !_isSearching &&
              _searchResults.isEmpty &&
              _searchCtrl.text.isNotEmpty)
            _buildNoResults(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 ئەنجامەکانی گەڕان
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          color: Color(0xFFEEEEEE),
        ),
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return ListTile(
            onTap: () => _goToResult(result),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            title: Text(
              result['name'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              result['address'] ?? '',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ لۆدینگی گەڕان
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchingIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'خەریکی گەڕان...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 هیچ ئەنجامێک نییە
  // ═══════════════════════════════════════════════════════════
  Widget _buildNoResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Colors.grey,
            size: 32,
          ),
          SizedBox(height: 6),
          Text(
            'هیچ شوێنێک نەدۆزرایەوە',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔵 دوگمەی نەخشە
  // ═══════════════════════════════════════════════════════════
  Widget _buildMapButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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

  // ═══════════════════════════════════════════════════════════
  // ⏳ لۆدینگی POI
  // ═══════════════════════════════════════════════════════════
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'خەریکی هێنانی زانیاری...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Bottom Sheet ی POI
  // ═══════════════════════════════════════════════════════════
  Widget _buildPOIBottomSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // زانیاری
            Row(
              children: [
                _buildPOIImage(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPOI!['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (_selectedPOI!['address']
                          .toString()
                          .isNotEmpty)
                        Text(
                          "📍 ${_selectedPOI!['address']}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_selectedPOI!['phone']
                          .toString()
                          .isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          "📞 ${_selectedPOI!['phone']}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // دوگمەی هەڵبژاردن
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, {
                    'location': _selectedLocation,
                    'name': _selectedPOI!['name'],
                    'address': _selectedPOI!['address'],
                    'phone': _selectedPOI!['phone'],
                  });
                },
                icon: const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                ),
                label: const Text(
                  "هەڵبژاردنی ئەم شوێنە",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🖼️ وێنەی POI
  // ═══════════════════════════════════════════════════════════
  Widget _buildPOIImage() {
    if (_selectedPOI!['photo'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _selectedPOI!['photo'],
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 70,
            height: 70,
            color: Colors.grey.shade200,
            child: const Icon(
              Icons.image,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.location_on_rounded,
        color: AppColors.primary,
        size: 32,
      ),
    );
  }
}