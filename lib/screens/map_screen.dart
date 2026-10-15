import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/settings_provider.dart';
import '../models/neighborhood.dart';
import '../services/neighborhood_service.dart';
import '../widgets/neighborhood_info_sheet.dart';
import '../widgets/neighborhoods_drawer.dart';
import '../widgets/search_bar_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  // داتا
  List<Neighborhood> _all = [];
  List<Neighborhood> _filtered = [];

  // دۆخ
  Neighborhood? _selected;
  bool _loading = true;
  bool _satellite = false;
  bool _showAllBoundaries = false; // ⭐ پیشاندانی هەموو
  bool _darkStyle = false;

  // شوێن
  LatLng? _userLatLng;

  static const _kalarCenter = LatLng(34.628, 45.318);

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Google Map Style
  // ═══════════════════════════════════════════════════════════
  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]}
  ]
  ''';

  // ڕەنگەکان
  static const _colors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF009688),
    Color(0xFFE91E63),
    Color(0xFF3F51B5),
    Color(0xFFFFC107),
    Color(0xFF00BCD4),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _all = await NeighborhoodService.getAll();
      _filtered = _all;
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('❌ init error: $e');
      setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ دروستکردنی پۆلیگۆنەکان — تەنها گەڕەکی هەڵبژێردراو
  // ═══════════════════════════════════════════════════════════
  Set<Polygon> get _visiblePolygons {
    // ئەگەر "هەموو" چالاک بێت، هەموو پیشان بدە
    if (_showAllBoundaries) {
      return _all
          .where((n) => n.hasBoundary)
          .map((n) {
        final idx = _all.indexOf(n);
        final color = _colors[idx % _colors.length];
        return Polygon(
          polygonId: PolygonId(n.id ?? n.nameKu),
          points: n.boundaryPoints,
          strokeColor: color,
          strokeWidth: 2,
          fillColor: color.withValues(alpha: 0.15),
          consumeTapEvents: true,
          onTap: () => _selectNeighborhood(n),
        );
      }).toSet();
    }

    // ⭐ تەنها گەڕەکی هەڵبژێردراو
    if (_selected != null && _selected!.hasBoundary) {
      return {
        Polygon(
          polygonId: PolygonId(_selected!.id ?? _selected!.nameKu),
          points: _selected!.boundaryPoints,
          strokeColor: const Color(0xFF1E88E5),
          strokeWidth: 3,
          fillColor: const Color(0xFF1E88E5).withValues(alpha: 0.25),
          consumeTapEvents: false,
        ),
      };
    }

    return {};
  }

  Set<Marker> get _visibleMarkers {
    final markers = <Marker>{};

    // Marker ی گەڕەکی هەڵبژێردراو — هەمیشە پیشان بدە
    if (_selected != null) {
      LatLng? center;
      if (_selected!.hasCenter) {
        center = LatLng(
          _selected!.centerLatitude!,
          _selected!.centerLongitude!,
        );
      } else if (_selected!.hasBoundary) {
        center = _centroid(_selected!.boundaryPoints);
      }

      if (center != null) {
        markers.add(Marker(
          markerId: MarkerId('sel_${_selected!.id}'),
          position: center,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: _selected!.nameKu),
        ));
      }
    }

    // Marker ی شوێنی بەکارهێنەر
    if (_userLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: _userLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
        infoWindow: const InfoWindow(title: 'تۆ'),
      ));
    }

    return markers;
  }

  LatLng _centroid(List<LatLng> pts) {
    double lat = 0, lon = 0;
    for (final p in pts) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / pts.length, lon / pts.length);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 هەڵبژاردنی گەڕەک
  // ═══════════════════════════════════════════════════════════
  void _selectNeighborhood(Neighborhood n) {
    setState(() => _selected = n);

    // Zoom بۆ گەڕەکی هەڵبژێردراو
    LatLng? target;
    double zoom = 15;

    if (n.hasBoundary && n.boundaryPoints.length >= 3) {
      // Zoom بۆ ناوەندی پۆلیگۆن
      target = _centroid(n.boundaryPoints);
      zoom = 15;
    } else if (n.hasCenter) {
      target = LatLng(n.centerLatitude!, n.centerLongitude!);
      zoom = 16;
    }

    if (target != null) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(target, zoom),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 شوێنی بەکارهێنەر
  // ═══════════════════════════════════════════════════════════
  Future<void> _locateUser() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      setState(() => _userLatLng = latLng);

      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16),
      );

      final nearest = await NeighborhoodService.findNeighborhoodByLocation(
        lat: position.latitude,
        lng: position.longitude,
      );

      if (nearest != null && mounted) {
        _selectNeighborhood(nearest);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('نزیکترین گەڕەک: ${nearest.nameKu}'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('نەتوانرا شوێن بدۆزرێتەوە: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 دوگمەکان
  // ═══════════════════════════════════════════════════════════
  void _toggleSatellite() {
    setState(() => _satellite = !_satellite);
  }

  void _toggleAllBoundaries() {
    setState(() => _showAllBoundaries = !_showAllBoundaries);
  }

  void _toggleDarkStyle() {
    setState(() => _darkStyle = !_darkStyle);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 UI
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: NeighborhoodsDrawer(
          neighborhoods: _all,
          current: _selected,
          onSelected: _selectNeighborhood,
        ),
        body: Stack(
          children: [
            // نەخشە
            _loading
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _kalarCenter,
                zoom: 13,
              ),
              mapType:
              _satellite ? MapType.satellite : MapType.normal,
              style: _satellite
                  ? null
                  : (_darkStyle ? _darkMapStyle : null),
              polygons: _visiblePolygons,
              markers: _visibleMarkers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (c) => _controller = c,
              onTap: (_) {
                // کلیک لە سەر شوێنی بەتاڵ → لابردنی هەڵبژاردن
                if (_selected != null) {
                  setState(() => _selected = null);
                }
              },
            ),

            // ═════ Search Bar لە سەرەوە ═════
            if (!_loading)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.menu,
                      color: Colors.blue,
                      onPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SearchBarWidget(
                        neighborhoods: _all,
                        onSelected: _selectNeighborhood,
                      ),
                    ),
                  ],
                ),
              ),

            // ═════ دوگمەکانی لای ڕاست ═════
            Positioned(
              right: 16,
              bottom: _selected != null ? 320 : 100,
              child: Column(
                children: [
                  _RoundIconButton(
                    icon: Icons.my_location,
                    color: Colors.blue,
                    tooltip: 'شوێنی من',
                    onPressed: _locateUser,
                  ),
                  const SizedBox(height: 8),
                  _RoundIconButton(
                    icon: _satellite
                        ? Icons.map
                        : Icons.satellite_alt,
                    color: _satellite ? Colors.orange : Colors.blueGrey,
                    tooltip: _satellite ? 'نەخشەی ئاسایی' : 'Satellite',
                    onPressed: _toggleSatellite,
                  ),
                  const SizedBox(height: 8),
                  _RoundIconButton(
                    icon: _showAllBoundaries
                        ? Icons.layers
                        : Icons.layers_clear,
                    color: _showAllBoundaries ? Colors.green : Colors.grey,
                    tooltip: _showAllBoundaries
                        ? 'شاردنەوەی هەموو'
                        : 'پیشاندانی هەموو',
                    onPressed: _toggleAllBoundaries,
                  ),
                  const SizedBox(height: 8),
                  _RoundIconButton(
                    icon: Icons.dark_mode,
                    color: _darkStyle ? Colors.indigo : Colors.grey,
                    tooltip: _darkStyle ? 'شێوازی ڕۆژ' : 'شێوازی شەو',
                    onPressed: _toggleDarkStyle,
                  ),
                ],
              ),
            ),

            // ═════ کارتی زانیاری گەڕەک ═════
            if (_selected != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NeighborhoodInfoSheet(
                  neighborhood: _selected!,
                  onClose: () => setState(() => _selected = null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 دوگمەی خڕ
// ═══════════════════════════════════════════════════════════
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: color),
        ),
      ),
    );

    return tooltip != null
        ? Tooltip(message: tooltip!, child: btn)
        : btn;
  }
}