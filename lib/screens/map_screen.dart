// lib/screens/map_screen.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/settings_provider.dart';
import '../models/neighborhood.dart';
import '../services/neighborhood_service.dart';
import '../widgets/neighborhood_info_sheet.dart';
import '../widgets/neighborhoods_drawer.dart';
import '../widgets/search_bar_widget.dart';

/// 🗺️ شاشەی نەخشەی گەڕەکان — ULTRA PRO V8
/// ✅ ناوی هەموو گەڕەکەکان + فلتەرکردنی دووری (1 کم)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  GoogleMapController? _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  List<Neighborhood> _all = [];
  Neighborhood? _selected;
  bool _loading = true;
  bool _satellite = false;
  bool _darkStyle = false;
  bool _showLabels = true;

  // ⭐ دووری — بگۆڕە بۆ 0.5، 1، 2، هتد
  static const double _maxDistanceKm = 1.0;

  LatLng? _userLatLng;

  // ⭐ Cache ی Label Markers
  final Map<String, BitmapDescriptor> _labelMarkers = {};

  static const _kalarCenter = LatLng(34.628, 45.318);

  // ═══════════════════════════════════════════════════════════
  // 🎬 Animations
  // ═══════════════════════════════════════════════════════════
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  // ═══════════════════════════════════════════════════════════
  // 🎨 Palette — 25 ڕەنگی جیاواز
  // ═══════════════════════════════════════════════════════════
  static const List<Color> _vibrantPalette = [
    Color(0xFFE53935), // 🔴 سوور
    Color(0xFFD81B60), // 🩷 پینکی
    Color(0xFF8E24AA), // 🟣 مۆر
    Color(0xFF5E35B1), // 🟪 مۆری تۆخ
    Color(0xFF3949AB), // 🔵 شینی تۆخ
    Color(0xFF1E88E5), // 🔵 شین
    Color(0xFF039BE5), // 🌊 شینی ئاسمانی
    Color(0xFF00ACC1), // 🩵 سیانی
    Color(0xFF00897B), // 💚 سەوزی تۆخ
    Color(0xFF43A047), // 🟢 سەوز
    Color(0xFF7CB342), // 🟩 سەوزی ڕووناک
    Color(0xFFC0CA33), // 💛 زەردی تۆخ
    Color(0xFFFDD835), // 🟡 زەرد
    Color(0xFFFFB300), // 🟠 زەردی پرتەقاڵی
    Color(0xFFFB8C00), // 🟧 پرتەقاڵی
    Color(0xFFF4511E), // 🧡 پرتەقاڵی سوور
    Color(0xFF6D4C41), // 🟤 قاوەیی
    Color(0xFF546E7A), // 🩶 خۆڵەمێشی شین
    Color(0xFF00BFA5), // 💎 تورکوازی
    Color(0xFF64DD17), // 🍀 سەوزی لایم
    Color(0xFFAA00FF), // 💜 مۆری درەوشاوە
    Color(0xFFFF4081), // 🌸 پینکی درەوشاوە
    Color(0xFF2962FF), // 💙 شینی درەوشاوە
    Color(0xFFFF6D00), // 🔥 نارنجی درەوشاوە
    Color(0xFF00C853), // 💚 سەوزی درەوشاوە
  ];

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Map Styles
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

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _init();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _all = await NeighborhoodService.getAll();
      if (mounted) {
        setState(() => _loading = false);
        _fadeController.forward();
      }

      // ⭐ دروستکردنی Label Markers
      await _prepareLabelMarkers();
    } catch (e) {
      debugPrint('❌ init error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📏 حسابکردنی دووری نێوان دوو خاڵ (Haversine — بە کم)
  // ═══════════════════════════════════════════════════════════
  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371.0; // کم
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(from.latitude)) *
            math.cos(_toRadians(to.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  // ═══════════════════════════════════════════════════════════
  // 🎯 وەرگرتنی ناوەندی گەڕەک
  // ═══════════════════════════════════════════════════════════
  LatLng? _getNeighborhoodCenter(Neighborhood n) {
    if (n.hasCenter) {
      return LatLng(n.centerLatitude!, n.centerLongitude!);
    } else if (n.hasBoundary && n.boundaryPoints.length >= 3) {
      return _centroid(n.boundaryPoints);
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 لیستی گەڕەکەکانی دیار (فلتەرکراو بەپێی دووری)
  // ═══════════════════════════════════════════════════════════
  List<Neighborhood> get _visibleNeighborhoods {
    // ⭐ کاتێک هیچ گەڕەکێک هەڵنەبژێردراوە → هەموو پیشان بدە
    if (_selected == null) return _all;

    // ⭐ کاتێک گەڕەکێک هەڵبژێردراوە → تەنها گەڕەکەکانی نزیک
    final selectedCenter = _getNeighborhoodCenter(_selected!);
    if (selectedCenter == null) return [_selected!];

    return _all.where((n) {
      // گەڕەکی هەڵبژێردراو هەمیشە پیشان بدە
      if (n.id == _selected!.id) return true;

      // پشکنینی دووری
      final center = _getNeighborhoodCenter(n);
      if (center == null) return false;

      final distance = _calculateDistance(selectedCenter, center);
      return distance <= _maxDistanceKm;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگی گەڕەک
  // ═══════════════════════════════════════════════════════════
  Color _getColorForNeighborhood(Neighborhood n, int index) {
    final name = n.nameKu;

    if (name.contains('زانکۆ')) return const Color(0xFF1E88E5);
    if (name.contains('شاری') || name.contains('سیتی')) {
      return const Color(0xFFE53935);
    }
    if (name.contains('زۆنی') || name.contains('دریم لاند')) {
      return const Color(0xFF8E24AA);
    }
    if (name.contains('گەڕەکی')) return const Color(0xFF43A047);
    if (name.contains('شارەوانی')) return const Color(0xFFFF6D00);
    if (name.contains('پارک') || name.contains('باخ')) {
      return const Color(0xFF00C853);
    }
    if (name.contains('مەطار') || name.contains('وێستگە')) {
      return const Color(0xFF00BFA5);
    }

    return _vibrantPalette[index % _vibrantPalette.length];
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ دروستکردنی Label Markers
  // ═══════════════════════════════════════════════════════════
  Future<void> _prepareLabelMarkers() async {
    for (int i = 0; i < _all.length; i++) {
      final n = _all[i];
      if (!n.hasCenter && !n.hasBoundary) continue;

      final color = _getColorForNeighborhood(n, i);
      final key = '${n.id}_${n.nameKu}';

      if (!_labelMarkers.containsKey(key)) {
        try {
          final marker = await _createLabelMarker(
            name: n.nameKu,
            color: color,
          );
          _labelMarkers[key] = marker;
        } catch (e) {
          debugPrint('❌ Label error for ${n.nameKu}: $e');
        }
      }
    }

    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createLabelMarker({
    required String name,
    required Color color,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontFamily: 'Rabar',
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );

    textPainter.layout(maxWidth: 300);

    const padding = 14.0;
    final width = textPainter.width + (padding * 2);
    final height = textPainter.height + (padding * 2);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(18),
    );

    canvas.drawShadow(
      Path()..addRRect(rrect),
      Colors.black.withValues(alpha: 0.4),
      6,
      true,
    );

    canvas.drawRRect(
      rrect,
      Paint()..color = color,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    textPainter.paint(
      canvas,
      const Offset(padding, padding),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      width.toInt(),
      height.toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Polygons — فلتەرکراو بەپێی دووری
  // ═══════════════════════════════════════════════════════════
  Set<Polygon> get _visiblePolygons {
    final visible = _visibleNeighborhoods
        .where((n) => n.hasBoundary)
        .toList();

    if (visible.isEmpty) return {};

    return visible
        .asMap()
        .entries
        .map((entry) {
      final n = entry.value;
      final globalIdx = _all.indexOf(n);
      final isSelected = _selected?.id == n.id;

      final baseColor = _getColorForNeighborhood(n, globalIdx);

      return Polygon(
        polygonId: PolygonId(n.id ?? n.nameKu),
        points: n.boundaryPoints,
        strokeColor: isSelected
            ? const Color(0xFFFF6F00)
            : baseColor,
        strokeWidth: isSelected ? 5 : 2,
        fillColor: isSelected
            ? const Color(0xFFFFC107).withValues(alpha: 0.40)
            : baseColor.withValues(alpha: 0.20),
        consumeTapEvents: true,
        geodesic: true,
        onTap: () {
          HapticFeedback.selectionClick();
          _selectNeighborhood(n);
        },
      );
    }).toSet();
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ Markers — ناوی گەڕەکەکانی دیار
  // ═══════════════════════════════════════════════════════════
  Set<Marker> get _visibleMarkers {
    final markers = <Marker>{};

    // ⭐ ناوی گەڕەکەکانی دیار
    if (_showLabels) {
      for (final n in _visibleNeighborhoods) {
        final center = _getNeighborhoodCenter(n);
        if (center == null) continue;

        final key = '${n.id}_${n.nameKu}';
        final labelIcon = _labelMarkers[key];
        if (labelIcon == null) continue;

        markers.add(Marker(
          markerId: MarkerId('label_${n.id ?? n.nameKu}'),
          position: center,
          icon: labelIcon,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
          onTap: () {
            HapticFeedback.selectionClick();
            _selectNeighborhood(n);
          },
        ));
      }
    }

    // ⭐ Marker ی شوێنی بەکارهێنەر
    if (_userLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: _userLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
        infoWindow: const InfoWindow(title: 'تۆ', snippet: 'شوێنی ئێستا'),
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
  // 🎯 Select Neighborhood
  // ═══════════════════════════════════════════════════════════
  void _selectNeighborhood(Neighborhood n) {
    setState(() => _selected = n);

    final center = _getNeighborhoodCenter(n);
    if (center != null) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(center, 15),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 Locate User
  // ═══════════════════════════════════════════════════════════
  Future<void> _locateUser() async {
    HapticFeedback.mediumImpact();
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
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
        _showSnackBar(
          'نزیکترین گەڕەک: ${nearest.nameKu}',
          Colors.green.shade700,
          Icons.location_on_rounded,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        'نەتوانرا شوێن بدۆزرێتەوە',
        Colors.red,
        Icons.error_outline_rounded,
      );
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Toggles
  // ═══════════════════════════════════════════════════════════
  void _toggleSatellite() {
    HapticFeedback.selectionClick();
    setState(() => _satellite = !_satellite);
  }

  void _toggleDarkStyle() {
    HapticFeedback.selectionClick();
    setState(() => _darkStyle = !_darkStyle);
  }

  void _toggleLabels() {
    HapticFeedback.selectionClick();
    setState(() => _showLabels = !_showLabels);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 UI
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().languageId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: isDark
              ? const Color(0xFF1A1A22)
              : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop();
            },
            tooltip: 'گەڕانەوە',
          ),
          title: Text(
            _selected != null
                ? 'گەڕەکانی نزیک ${_selected!.nameKu}'
                : 'نەخشەی گەڕەکان 🗺️',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _showLabels
                    ? Icons.label_rounded
                    : Icons.label_off_rounded,
                color: _showLabels
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white54 : Colors.grey),
              ),
              onPressed: _toggleLabels,
              tooltip: _showLabels
                  ? 'شاردنەوەی ناوەکان'
                  : 'پیشاندانی ناوەکان',
            ),
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: isDark ? Colors.white : const Color(0xFF1E88E5),
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'لیستی گەڕەکان',
            ),
          ],
        ),
        drawer: NeighborhoodsDrawer(
          neighborhoods: _all,
          current: _selected,
          onSelected: _selectNeighborhood,
        ),
        body: Stack(
          children: [
            // ═══ Map ═══
            _loading
                ? _buildLoadingScreen(isDark)
                : FadeTransition(
              opacity: _fadeAnimation,
              child: GoogleMap(
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
                buildingsEnabled: true,
                indoorViewEnabled: false,
                trafficEnabled: false,
                onMapCreated: (c) => _controller = c,
                onTap: (_) {
                  if (_selected != null) {
                    setState(() => _selected = null);
                  }
                },
              ),
            ),

            // ═══ Search Bar ═══
            if (!_loading) _buildSearchBar(isDark),

            // ═══ Right Controls ═══
            if (!_loading) _buildRightControls(isDark),

            // ═══ Bottom Info Sheet ═══
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

            // ═══ Empty State ═══
            if (!_loading && _all.isEmpty)
              _buildEmptyState(isDark),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Loading Screen
  // ═══════════════════════════════════════════════════════════
  Widget _buildLoadingScreen(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E88E5), Color(0xFF6C5CE7)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E88E5)
                              .withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'خەریکی بارکردنی گەڕەکان...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'کەمێک چاوەڕوان بە',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutCubic,
          )),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: isDark ? 0.3 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: SearchBarWidget(
              neighborhoods: _all,
              onSelected: _selectNeighborhood,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Right Controls
  // ═══════════════════════════════════════════════════════════
  Widget _buildRightControls(bool isDark) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      right: 16,
      bottom: _selected != null ? 340 : 100,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildGlassButton(
              icon: Icons.my_location_rounded,
              color: const Color(0xFF1E88E5),
              tooltip: 'شوێنی من',
              onTap: _locateUser,
              isDark: isDark,
              isPulsing: true,
            ),
            const SizedBox(height: 10),
            _buildGlassButton(
              icon: _satellite
                  ? Icons.map_rounded
                  : Icons.satellite_alt_rounded,
              color: _satellite
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF64748B),
              tooltip: _satellite ? 'نەخشەی ئاسایی' : 'Satellite',
              onTap: _toggleSatellite,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            if (_selected != null) ...[
              _buildGlassButton(
                icon: Icons.close_rounded,
                color: const Color(0xFFEF4444),
                tooltip: 'لابردنی هەڵبژاردن',
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selected = null);
                },
                isDark: isDark,
              ),
              const SizedBox(height: 10),
            ],
            _buildGlassButton(
              icon: _darkStyle
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: _darkStyle
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF64748B),
              tooltip: _darkStyle ? 'شێوازی ڕۆژ' : 'شێوازی شەو',
              onTap: _toggleDarkStyle,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildGlassButton(
              icon: Icons.gps_fixed_rounded,
              color: const Color(0xFFE91E63),
              tooltip: 'کەلار',
              onTap: () {
                HapticFeedback.lightImpact();
                _controller?.animateCamera(
                  CameraUpdate.newLatLngZoom(_kalarCenter, 13),
                );
                setState(() => _selected = null);
              },
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Glass Button
  // ═══════════════════════════════════════════════════════════
  Widget _buildGlassButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    String? tooltip,
    bool isPulsing = false,
  }) {
    final button = Material(
      color: isDark ? const Color(0xFF1A1A22) : Colors.white,
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: isPulsing
              ? AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Icon(icon, color: color, size: 24),
              );
            },
          )
              : Icon(icon, color: color, size: 24),
        ),
      ),
    );

    return tooltip != null
        ? Tooltip(
      message: tooltip,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A35) : Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      child: button,
    )
        : button;
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A22).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 60,
                  color: const Color(0xFF1E88E5)
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'هیچ گەڕەکێک نەدۆزرایەوە',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'داتای گەڕەکان لە Supabase نەهاتووە',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}