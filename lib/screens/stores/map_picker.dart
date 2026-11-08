// lib/screens/stores/map_picker.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../services/location_service.dart';
import '../../services/places_service.dart';
import '../../l10n/tr.dart';

/// 🗺️ شاشەی هەڵبژاردنی شوێن لەسەر نەخشە (Secure Edition)
///
/// ✅ Google Places API ئێستا بە Edge Function دەڕوات
/// ✅ API Key لە client نابێت
class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  gmaps.LatLng? _selectedLocation;
  gmaps.MapType _currentMapType = gmaps.MapType.normal;
  gmaps.GoogleMapController? _mapController;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  Map<String, dynamic>? _selectedPOI;
  bool _loadingPOI = false;

  // ✅ Debounce بۆ گەڕان
  // ⚠️ گرنگ: بۆ پاراستنی لە API calls ی زۆر
  DateTime? _lastSearchTime;
  static const Duration _searchDebounce = Duration(milliseconds: 400);

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
  // 🎯 گەڕان بۆ نزیکترین شوێن
  // ═══════════════════════════════════════════════════════════
  Future<void> _findNearestPlace(double lat, double lng) async {
    final place = await PlacesService.findNearest(
      lat: lat,
      lng: lng,
      radius: 50,
    );

    if (!mounted) return;

    if (place != null) {
      setState(() {
        _loadingPOI = false;
        _selectedPOI = {
          'name': place['name'] ?? 'شوێنی هەڵبژێردراو',
          'address': place['address'] ?? '',
          'phone': place['phone'] ?? '',
          'lat': lat,
          'lng': lng,
          'rating': place['rating'] ?? 0,
          'types': place['types'] ?? [],
          'photo': place['photo'],
          'place_id': place['place_id'] ?? '',
        };
      });
    } else {
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
        trf('کۆئۆردینەت: {0}, {1}', [lat.toStringAsFixed(6), lng.toStringAsFixed(6)]),
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
  // 🔍 گەڕان بە Places API (بە Edge Function)
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

    // ✅ Debounce — پشکنینی کاتی گەڕانی کۆتایی
    final now = DateTime.now();
    if (_lastSearchTime != null &&
        now.difference(_lastSearchTime!) < _searchDebounce) {
      return;
    }
    _lastSearchTime = now;

    if (mounted) {
      setState(() {
        _isSearching = true;
        _showResults = true;
      });
    }

    final results = await PlacesService.searchPlaces(
      query: query,
      biasLat: AppConstants.kalarLatitude,
      biasLng: AppConstants.kalarLongitude,
      radius: 30000,
    );

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 چوونە سەر ئەنجامەکە
  // ═══════════════════════════════════════════════════════════
  Future<void> _goToResult(Map<String, dynamic> result) async {
    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();
    final placeId = result['place_id']?.toString() ?? '';

    if (lat == null || lng == null) return;

    final newPos = gmaps.LatLng(lat, lng);

    if (mounted) {
      setState(() {
        _selectedLocation = newPos;
        _searchCtrl.text = result['name']?.toString() ?? '';
        _showResults = false;
        _searchResults = [];
        _loadingPOI = true;
      });
    }

    _searchFocus.unfocus();
    _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(newPos, 17),
    );

    // ✅ وەرگرتنی زانیاری زیاتر
    if (placeId.isNotEmpty) {
      final details = await PlacesService.getPlaceDetails(placeId);
      if (mounted && details != null) {
        setState(() {
          _loadingPOI = false;
          _selectedPOI = {
            'name': details['name'] ?? result['name'],
            'address': details['address'] ?? result['address'],
            'phone': details['phone'] ?? '',
            'lat': lat,
            'lng': lng,
            'rating': details['rating'] ?? 0,
            'types': details['types'] ?? [],
            'photo': details['photo'],
            'place_id': placeId,
          };
        });
        return;
      }
    }

    // Fallback: تەنها کۆئۆردینەت
    if (mounted) {
      setState(() {
        _loadingPOI = false;
        _selectedPOI = {
          'name': result['name'] ?? '',
          'address': result['address'] ?? '',
          'phone': '',
          'lat': lat,
          'lng': lng,
          'rating': 0,
          'types': [],
          'photo': null,
          'place_id': placeId,
        };
      });
    }
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
        _showError(tr('نەتوانرا شوێنی ئێستا بدۆزرێتەوە'));
      }
    } catch (e) {
      _showError(trf('هەڵە: {0}', [e]));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔔 SnackBar Helper
  // ═══════════════════════════════════════════════════════════
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(message), style: const TextStyle(fontSize: 12)),
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
      textDirection: AppLang.direction,
      child: Scaffold(
        body: Stack(
          children: [
            _buildMap(),
            _buildSearchBar(),
            Positioned(
              bottom: 100,
              left: 20,
              child: _buildMapButton(
                icon: Icons.my_location_rounded,
                color: AppColors.primary,
                onTap: _goToCurrentLocation,
              ),
            ),
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
            if (_loadingPOI) _buildLoadingOverlay(),
            if (_selectedPOI != null && !_loadingPOI)
              _buildPOIBottomSheet(),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      right: 12,
      child: Column(
        children: [
          Row(
            children: [
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
                      if (val.length >= 2) _searchLocation(val);
                    },
                    decoration: InputDecoration(
                      hintText: tr("گەڕان (بە ئینگلیزی: bakery، cafe)"),
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
          if (_showResults && _searchResults.isNotEmpty)
            _buildSearchResults(),
          if (_isSearching) _buildSearchingIndicator(),
          if (_showResults &&
              !_isSearching &&
              _searchResults.isEmpty &&
              _searchCtrl.text.isNotEmpty)
            _buildNoResults(),
        ],
      ),
    );
  }

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
              tr(result['name']?.toString() ?? ''),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              tr(result['address']?.toString() ?? ''),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            tr('خەریکی گەڕان...'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

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
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: Colors.grey, size: 32),
          const SizedBox(height: 6),
          Text(
            tr('هیچ شوێنێک نەدۆزرایەوە'),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 12),
            Text(
              tr('خەریکی هێنانی زانیاری...'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            Row(
              children: [
                _buildPOIImage(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(_selectedPOI!['name']?.toString() ?? ''),
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
                label: Text(
                  tr("هەڵبژاردنی ئەم شوێنە"),
                  style: const TextStyle(
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

  Widget _buildPOIImage() {
    final photo = _selectedPOI!['photo']?.toString();
    if (photo != null && photo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          photo,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 70,
            height: 70,
            color: Colors.grey.shade200,
            child: const Icon(Icons.image, color: Colors.grey),
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