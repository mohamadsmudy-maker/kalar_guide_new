import 'dart:async';
import 'dart:math' as math;
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
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';

part 'full_map_screen_ui.dart';

// ═══════════════════════════════════════════════════════════════
// 🧰 Top-level helpers
// ═══════════════════════════════════════════════════════════════
const gmaps.LatLng _kKalarCenter = gmaps.LatLng(34.6189, 45.3156);
const String _kAll = 'هەموو';

String _ku(Object n) => n.toString().replaceAllMapped(
  RegExp(r'\d'),
      (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
);

/// Makes Arabic / Kurdish letter variants match each other in search.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll('ي', 'ی')
    .replaceAll('ى', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('ہ', 'ە')
    .replaceAll('ۀ', 'ە')
    .replaceAll(RegExp(r'[\u064B-\u065F]'), '');

/// Distance in metres (haversine)
double _distanceM(gmaps.LatLng a, gmaps.LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h.toDouble()));
}

String _distanceText(double m) {
  if (m < 1000) return '${_ku(m.round())} م';
  return '${_ku((m / 1000).toStringAsFixed(1).replaceAll('.', '٫'))} کم';
}

/// A store prepared once (coordinates parsed, search text normalised) so
/// filtering / clustering never re-parses strings.
class _StorePoint {
  final Map<String, dynamic> store;
  final gmaps.LatLng? pos;
  final String search;
  final String category;
  final double hue;

  const _StorePoint({
    required this.store,
    required this.pos,
    required this.search,
    required this.category,
    required this.hue,
  });

  factory _StorePoint.from(Map<String, dynamic> store) {
    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');

    gmaps.LatLng? pos;
    if (lat != null &&
        lng != null &&
        lat != 0 &&
        lng != 0 &&
        !lat.isNaN &&
        !lng.isNaN &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      pos = gmaps.LatLng(lat, lng);
    }

    final category = (store['category'] ?? '').toString();
    final type = (store['type'] ?? '').toString().trim();

    var hue = gmaps.BitmapDescriptor.hueAzure;
    if (type == 'حکومی') {
      hue = gmaps.BitmapDescriptor.hueGreen;
    } else if (category.contains('خواردن') || category.contains('ڕێستۆرانت')) {
      hue = gmaps.BitmapDescriptor.hueOrange;
    } else if (category.contains('تەندروستی')) {
      hue = gmaps.BitmapDescriptor.hueRed;
    } else if (category.contains('پەروەردە')) {
      hue = gmaps.BitmapDescriptor.hueViolet;
    } else if (category.contains('بازاڕ') || category.contains('دوکان')) {
      hue = gmaps.BitmapDescriptor.hueYellow;
    }

    return _StorePoint(
      store: store,
      pos: pos,
      search: _norm(
          '${store['name'] ?? ''} ${store['address'] ?? ''} $category'),
      category: _norm(category),
      hue: hue,
    );
  }
}

/// 🗺️ شاشەی نەخشەی تەواو — ULTRA PRO MAX V4
class FullMapScreen extends StatefulWidget {
  const FullMapScreen({super.key});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  static const double _clusterPixelRadius = 56; // > قەبارەی بازنە، بۆ ئەوەی بەسەر یەکدا نەکەون

  gmaps.GoogleMapController? _mapController;
  gmaps.MapType _currentMapType = gmaps.MapType.normal;
  Set<gmaps.Marker> _markers = {};
  Set<gmaps.Circle> _circles = {};

  List<_StorePoint> _allPoints = [];
  List<_StorePoint> _filteredPoints = [];
  List<String> _categories = [_kAll];

  bool _isLoading = true;
  bool _loadFailed = false;
  double _currentZoom = 12.0;

  String _searchQuery = '';
  String _selectedCategory = _kAll;
  final TextEditingController _searchCtrl = TextEditingController();

  final Map<int, gmaps.BitmapDescriptor> _clusterIconCache = {};
  Timer? _reclusterTimer;
  Timer? _searchDebounce;
  Timer? _highlightTimer;
  int _markerGen = 0;

  gmaps.LatLng? _myPos;
  bool _showLegend = false;

  int get _mappableCount =>
      _filteredPoints.where((p) => p.pos != null).length;

  // ═══════════════════════════════════════════════════════════
  // 🔁 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchStores();
  }

  @override
  void dispose() {
    _reclusterTimer?.cancel();
    _searchDebounce?.cancel();
    _highlightTimer?.cancel();
    _searchCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Cluster icon (exact count — the old code showed "5" for a
  // cluster of 7 because it snapped to the nearest preset)
  // ═══════════════════════════════════════════════════════════
  Future<gmaps.BitmapDescriptor> _clusterIcon(int count) async {
    final cached = _clusterIconCache[count];
    if (cached != null) return cached;

    // قەبارەی لۆجیکی (dp) — پێشتر وێنەکە ١٢٠ پیکسڵ بوو و وەک ١٢٠dp
    // پیشان دەدرا، بۆیە بازنەکان زۆر گەورە بوون و بەسەر یەکدا دەکەوتن.
    final logical = count < 10 ? 38.0 : (count < 100 ? 44.0 : 50.0);
    const scale = 3.0; // وێنەی ڕوون لەسەر هەموو شاشەیەک
    final size = logical * scale;
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 3 * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // سێبەری نەرم
    canvas.drawCircle(
      center.translate(0, 1.5 * scale),
      radius + 1.5 * scale,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // ئەڵقەی سپی
    canvas.drawCircle(center, radius + 2 * scale, Paint()..color = Colors.white);

    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size, size),
      [const Color(0xFF1E88E5), const Color(0xFF6C5CE7)],
    );
    canvas.drawCircle(center, radius, Paint()..shader = gradient);

    final text = count >= 1000
        ? '${(count / 1000).toStringAsFixed(1)}k'
        : PlaceDisplay.digits(count);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: (text.length >= 3 ? 14.0 : 16.0) * scale,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    gmaps.BitmapDescriptor descriptor;
    try {
      final image =
          await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      descriptor = gmaps.BitmapDescriptor.bytes(
        bytes!.buffer.asUint8List(),
        width: logical,
        height: logical,
      );
    } catch (e) {
      debugPrint('⚠️ cluster icon error: $e');
      descriptor = gmaps.BitmapDescriptor.defaultMarker;
    }

    _clusterIconCache[count] = descriptor;
    return descriptor;
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 Data
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('main_categories')
          .select('name')
          .order('name');

      final names = <String>[];
      for (final cat in (res as List)) {
        final n = cat['name']?.toString().trim() ?? '';
        if (n.isNotEmpty && !names.contains(n)) names.add(n);
      }

      if (mounted) setState(() => _categories = [_kAll, ...names]);
    } catch (e) {
      debugPrint('❌ Categories error: $e');
    }
  }

  Future<void> _fetchStores() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select()
          .order('name');

      final points = (res as List)
          .map((e) => _StorePoint.from(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (!mounted) return;
      setState(() {
        _allPoints = points;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Filter + clustering
  // ═══════════════════════════════════════════════════════════
  void _applyFilter() {
    final q = _norm(_searchQuery.trim());
    final cat = _selectedCategory == _kAll ? '' : _norm(_selectedCategory);

    final list = _allPoints.where((p) {
      if (q.isNotEmpty && !p.search.contains(q)) return false;
      if (cat.isNotEmpty && !p.category.contains(cat)) return false;
      return true;
    }).toList();

    if (mounted) setState(() => _filteredPoints = list);
    _updateMarkers();
  }

  void _scheduleRecluster() {
    _reclusterTimer?.cancel();
    _reclusterTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _updateMarkers();
    });
  }

  Future<void> _updateMarkers() async {
    if (!mounted) return;
    final gen = ++_markerGen; // drop results of older, slower runs

    final pts = _filteredPoints.where((p) => p.pos != null).toList();

    // Radius in degrees that equals ~48 screen pixels at this zoom, so
    // clusters always look the same size and fully split at high zoom.
    final r = _clusterPixelRadius * 360 / (256 * math.pow(2, _currentZoom));

    // Grid buckets → neighbour lookup instead of O(n²)
    int cellKey(int cx, int cy) => cx * 4000037 + cy;
    final grid = <int, List<int>>{};
    final cells = List<List<int>>.generate(pts.length, (i) {
      final cx = (pts[i].pos!.latitude / r).floor();
      final cy = (pts[i].pos!.longitude / r).floor();
      grid.putIfAbsent(cellKey(cx, cy), () => []).add(i);
      return [cx, cy];
    });

    final processed = List<bool>.filled(pts.length, false);
    final clusters = <List<int>>[];

    for (var i = 0; i < pts.length; i++) {
      if (processed[i]) continue;
      processed[i] = true;
      final cluster = [i];
      final a = pts[i].pos!;

      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final bucket = grid[cellKey(cells[i][0] + dx, cells[i][1] + dy)];
          if (bucket == null) continue;
          for (final j in bucket) {
            if (processed[j]) continue;
            final b = pts[j].pos!;
            if ((a.latitude - b.latitude).abs() < r &&
                (a.longitude - b.longitude).abs() < r) {
              processed[j] = true;
              cluster.add(j);
            }
          }
        }
      }
      clusters.add(cluster);
    }

    final markers = <gmaps.Marker>{};

    for (final cluster in clusters) {
      if (cluster.length == 1) {
        final p = pts[cluster.first];
        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId('store_${p.store['id']}'),
            position: p.pos!,
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(p.hue),
            infoWindow: gmaps.InfoWindow.noText,
            onTap: () => _showStoreDetails(p.store),
          ),
        );
      } else {
        final members = cluster.map((i) => pts[i]).toList();
        var sumLat = 0.0, sumLng = 0.0;
        for (final m in members) {
          sumLat += m.pos!.latitude;
          sumLng += m.pos!.longitude;
        }
        final center = gmaps.LatLng(
          sumLat / members.length,
          sumLng / members.length,
        );

        final icon = await _clusterIcon(members.length);
        if (gen != _markerGen || !mounted) return;

        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(
                'cluster_${members.first.store['id']}_${members.length}'),
            position: center,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            onTap: () => _onClusterTap(members),
          ),
        );
      }
    }

    if (gen != _markerGen || !mounted) return;
    setState(() => _markers = markers);
  }

  Future<void> _onClusterTap(List<_StorePoint> members) async {
    HapticFeedback.selectionClick();

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final m in members) {
      minLat = math.min(minLat, m.pos!.latitude);
      maxLat = math.max(maxLat, m.pos!.latitude);
      minLng = math.min(minLng, m.pos!.longitude);
      maxLng = math.max(maxLng, m.pos!.longitude);
    }

    final spread = math.max(maxLat - minLat, maxLng - minLng);
    final c = _mapController;

    // Same spot (or already fully zoomed in) → zooming can't separate them,
    // so list them instead of leaving the user stuck on a cluster.
    if (c == null || spread < 0.00005 || _currentZoom >= 18.5) {
      await _showStoreListSheet(
        points: members,
        title: trf('{0} شوێن لێرە', [_ku(members.length)]),
      );
      return;
    }

    try {
      await c.animateCamera(gmaps.CameraUpdate.newLatLngBounds(
        gmaps.LatLngBounds(
          southwest: gmaps.LatLng(minLat, minLng),
          northeast: gmaps.LatLng(maxLat, maxLng),
        ),
        80,
      ));
    } catch (_) {
      c.animateCamera(gmaps.CameraUpdate.zoomTo(
          (_currentZoom + 2).clamp(10.0, 20.0)));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧭 Camera / actions
  // ═══════════════════════════════════════════════════════════
  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _goToCurrentLocation() async {
    HapticFeedback.mediumImpact();
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        _snack(tr('نەتوانرا شوێنی تۆ بدۆزرێتەوە — GPS و مۆڵەتەکان بپشکنە'),
            Colors.orange);
        return;
      }
      final here = gmaps.LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = here); // used for "distance" in the list
      _mapController?.animateCamera(gmaps.CameraUpdate.newLatLngZoom(here, 16));
    } catch (e) {
      debugPrint('❌ location error: $e');
      _snack(tr('هەڵە لە وەرگرتنی شوێن'), Colors.red);
    }
  }

  Future<void> _fitAll() async {
    HapticFeedback.lightImpact();
    final c = _mapController;
    final pts = _filteredPoints.where((p) => p.pos != null).toList();
    if (c == null || pts.isEmpty) return;

    if (pts.length == 1) {
      c.animateCamera(gmaps.CameraUpdate.newLatLngZoom(pts.first.pos!, 16));
      return;
    }

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in pts) {
      minLat = math.min(minLat, p.pos!.latitude);
      maxLat = math.max(maxLat, p.pos!.latitude);
      minLng = math.min(minLng, p.pos!.longitude);
      maxLng = math.max(maxLng, p.pos!.longitude);
    }
    try {
      await c.animateCamera(gmaps.CameraUpdate.newLatLngBounds(
        gmaps.LatLngBounds(
          southwest: gmaps.LatLng(minLat, minLng),
          northeast: gmaps.LatLng(maxLat, maxLng),
        ),
        90,
      ));
    } catch (_) {
      c.animateCamera(gmaps.CameraUpdate.newLatLngZoom(_kKalarCenter, 12));
    }
  }

  void _showStoreDetails(Map<String, dynamic> store) {
    HapticFeedback.lightImpact();
    StoreDetailsDialog.show(context, store);
  }

  Future<void> _showStoreListSheet({
    List<_StorePoint>? points,
    String? title,
  }) async {
    HapticFeedback.mediumImpact();
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoreListSheet(
        points: points ?? _filteredPoints,
        userPos: _myPos,
        title: title ?? tr('شوێنەکانی نەخشە'),
      ),
    );

    if (selected == null || !mounted) return;
    await _goToStore(selected);
  }

  void _pulseAt(gmaps.LatLng pos) {
    _highlightTimer?.cancel();
    setState(() {
      _circles = {
        gmaps.Circle(
          circleId: const gmaps.CircleId('highlight'),
          center: pos,
          radius: 40,
          fillColor: AppColors.primary.withValues(alpha: 0.18),
          strokeColor: AppColors.primary,
          strokeWidth: 2,
        ),
      };
    });
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _circles = {});
    });
  }

  Future<void> _goToStore(Map<String, dynamic> store) async {
    final p = _StorePoint.from(store);
    if (p.pos == null) {
      _snack(tr('ئەم شوێنە لۆکەیشنی نییە'), Colors.orange);
      return;
    }

    final c = _mapController;
    if (c == null) return;

    _pulseAt(p.pos!);
    await c.animateCamera(gmaps.CameraUpdate.newLatLngZoom(p.pos!, 17));
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _showStoreDetails(store);
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pad = MediaQuery.paddingOf(context);
    final bottomInset = pad.bottom;

    return PopScope(
      // Back first closes the legend, then leaves the screen
      canPop: !_showLegend,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showLegend) setState(() => _showLegend = false);
      },
      child: Directionality(
        textDirection: AppLang.direction,
        child: Scaffold(
          backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
          body: Stack(
            children: [
              // ═══ Map (always mounted — no more destroy/recreate) ═══
              gmaps.GoogleMap(
                initialCameraPosition: const gmaps.CameraPosition(
                  target: _kKalarCenter,
                  zoom: 12,
                ),
                mapType: _currentMapType,
                markers: _markers,
                circles: _circles,
                padding: EdgeInsets.only(bottom: 90 + bottomInset),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (controller) => _mapController = controller,
                onCameraMove: (position) => _currentZoom = position.zoom,
                onCameraIdle: _scheduleRecluster,
                onTap: (_) {
                  FocusScope.of(context).unfocus();
                  if (_showLegend) setState(() => _showLegend = false);
                },
              ),

              if (_isLoading)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: (isDark ? Colors.black : Colors.white)
                          .withValues(alpha: 0.35),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    ),
                  ),
                ),

              _buildSearchBar(isDark, pad.top),
              _buildCategoriesFilter(isDark, pad.top),

              if (_loadFailed) _buildErrorBanner(isDark, pad.top),
              if (!_isLoading &&
                  !_loadFailed &&
                  _filteredPoints.isEmpty &&
                  _allPoints.isNotEmpty)
                _buildNoResults(isDark, pad.top),

              if (_showLegend) _buildLegendPanel(isDark, bottomInset),

              // ═══ Floating buttons ═══
              Positioned(
                bottom: 96 + bottomInset,
                right: 16,
                child: Column(
                  children: [
                    _buildMapButton(
                      icon: _currentMapType == gmaps.MapType.satellite
                          ? Icons.map_rounded
                          : Icons.satellite_rounded,
                      tooltip: tr('جۆری نەخشە'),
                      color: _currentMapType == gmaps.MapType.satellite
                          ? AppColors.primary
                          : const Color(0xFF455A64),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _currentMapType =
                          _currentMapType == gmaps.MapType.satellite
                              ? gmaps.MapType.normal
                              : gmaps.MapType.satellite;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildMapButton(
                      icon: Icons.center_focus_strong_rounded,
                      tooltip: tr('نیشاندانی هەموو شوێنەکان'),
                      color: const Color(0xFF10B981),
                      onTap: _fitAll,
                    ),
                    const SizedBox(height: 10),
                    _buildMapButton(
                      icon: Icons.my_location_rounded,
                      tooltip: tr('شوێنی من'),
                      color: const Color(0xFF1E88E5),
                      onTap: _goToCurrentLocation,
                    ),
                    const SizedBox(height: 10),
                    _buildMapButton(
                      icon: Icons.info_outline_rounded,
                      tooltip: tr('ڕەنگی پینەکان'),
                      color: const Color(0xFF6C5CE7),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showLegend = !_showLegend);
                      },
                    ),
                  ],
                ),
              ),

              // ═══ Bottom stats card ═══
              Positioned(
                bottom: 16 + bottomInset,
                left: 16,
                right: 16,
                child: _buildStatsCard(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _floatDecoration(bool isDark, {double radius = 16}) =>
      BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      );

  Widget _buildSearchBar(bool isDark, double topPad) {
    return Positioned(
      top: topPad + 12,
      left: 16,
      right: 16,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: tr('گەڕانەوە'),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: _floatDecoration(isDark),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 50,
              decoration: _floatDecoration(isDark),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (val) {
                  setState(() => _searchQuery = val); // clear button
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 250),
                    _applyFilter,
                  );
                },
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: tr('گەڕان بەدوای شوێنەکان...'),
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(right: 8, left: 4),
                    child: Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    tooltip: tr('سڕینەوە'),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                    onPressed: () {
                      _searchDebounce?.cancel();
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                      _applyFilter();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesFilter(bool isDark, double topPad) {
    return Positioned(
      top: topPad + 72,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory == cat;

            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: cat,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat);
                    _applyFilter();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF6C5CE7)])
                          : null,
                      color: isSelected
                          ? null
                          : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
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
                          blurRadius: isSelected ? 12 : 6,
                          offset: const Offset(0, 3),
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tr(cat),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoResults(bool isDark, double topPad) {
    return Positioned(
      top: topPad + 122,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _floatDecoration(isDark),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded,
                color: isDark ? Colors.white54 : Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('هیچ شوێنێک نەدۆزرایەوە'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = _kAll;
                });
                _applyFilter();
              },
              child: Text(tr('سڕینەوەی فلتەر'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════
// 📋 Store List Bottom Sheet — ULTRA PRO MAX
// ═══════════════════════════════════════════════════════════════
class _StoreListSheet extends StatefulWidget {
  final List<_StorePoint> points;
  final gmaps.LatLng? userPos;
  final String title;

  const _StoreListSheet({
    required this.points,
    required this.userPos,
    required this.title,
  });

  @override
  State<_StoreListSheet> createState() => _StoreListSheetState();
}

class _StoreListSheetState extends State<_StoreListSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  late final List<_StorePoint> _sorted;
  final Map<_StorePoint, double> _dist = {};

  @override
  void initState() {
    super.initState();
    final list = List<_StorePoint>.of(widget.points);
    final me = widget.userPos;
    if (me != null) {
      for (final p in list) {
        if (p.pos != null) _dist[p] = _distanceM(me, p.pos!);
      }
      // nearest first, stores without coordinates last
      list.sort((a, b) {
        final da = _dist[a], db = _dist[b];
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }
    _sorted = list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_StorePoint> get _filtered {
    final q = _norm(_query.trim());
    if (q.isEmpty) return _sorted;
    return _sorted.where((p) => p.search.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final list = _filtered;

    return Directionality(
      textDirection: AppLang.direction,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
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
                        child: const Icon(Icons.location_on_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr(widget.title),
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
                              tr(widget.userPos != null
                                  ? trf('{0} شوێن • نزیکترین یەکەم', [_ku(list.length)])
                                  : trf('{0} شوێن', [_ku(list.length)])),
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
                        color: _query.isNotEmpty
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: tr('گەڕان بەدوای شوێن...'),
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.primary, size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 50,
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          tr('هیچ شوێنێک نەدۆزرایەوە'),
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
                    itemCount: list.length,
                    itemBuilder: (context, index) =>
                        _buildStoreTile(list[index], isDark, lang),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreTile(_StorePoint p, bool isDark, String lang) {
    final store = p.store;
    final name = store['name']?.toString() ?? '';
    final address = PlaceDisplay.address(store['address']);
    final image = store['image']?.toString() ?? '';
    final isGov = (store['type']?.toString() ?? '') == 'حکومی';
    final accent = isGov ? const Color(0xFF10B981) : AppColors.primary;
    final dist = _dist[p];

    return Semantics(
      button: true,
      label: name,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context, store);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFFAFBFF),
            borderRadius: BorderRadius.circular(18),
            border:
            Border.all(color: accent.withValues(alpha: 0.15), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.25), width: 1.5),
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
                    color: accent.withValues(alpha: 0.1),
                    child: Icon(Icons.storefront_rounded,
                        color: accent, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                        Icon(Icons.location_on_rounded,
                            size: 12, color: accent),
                        const SizedBox(width: 3),
                        Expanded(
                          child: AutoTranslate(
                            text: address,
                            lang: lang,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                              isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    if (dist != null || p.pos == null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (dist != null)
                            _tag(_distanceText(dist), Icons.near_me_rounded,
                                const Color(0xFF1E88E5)),
                          if (p.pos == null)
                            _tag(tr('بێ لۆکەیشن'), Icons.location_off_rounded,
                                Colors.orange),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right_rounded, color: accent, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(tr(text),
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}