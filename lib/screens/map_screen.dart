// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../config/settings_provider.dart';
import '../models/neighborhood.dart';
import '../services/neighborhood_service.dart';
import '../widgets/neighborhood_info_sheet.dart';
import '../widgets/neighborhoods_drawer.dart';
import '../widgets/search_bar_widget.dart';
import '../l10n/tr.dart';

part 'map_screen_ui.dart';

/// 🗺️ شاشەی نەخشەی گەڕەکان — v2
///
/// نوێکارییەکان:
///  • تایبەتمەندی: شوێنی زیندوو، دووری بۆ گەڕەک، 3D، دڵخوازەکان، compass، zoom،
///    ٤ جۆری نەخشە، دۆزینەوەی گەڕەک بە شێوەی ناوخۆیی (بێ ئینتەرنێت)
///  • جوانکاری: ئەنیمەیشنی هەڵبژاردن، کەمکردنەوەی ڕەنگی گەڕەکەکانی تر،
///    مارکەری ناوی ڕوون (devicePixelRatio)، شێوازی شەوی باشتر
///  • خێرایی: دروستکردنی مارکەر بە batch، cache ی زیرەک، بێ setState ی زیادە
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.onMenuTap});

  /// کاتێک وەک تابی ناڤیگەیشن دەکرێتەوە: دوگمەی مێنیو لەبری «گەڕانەوە»
  final VoidCallback? onMenuTap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 دۆخ
  // ═══════════════════════════════════════════════════════════
  static const _kalarCenter = LatLng(34.628, 45.318);
  static const _blue = Color(0xFF1E88E5);
  static const double _sheetHeight = 340;
  static const double _labelsMinZoom = 11;

  GoogleMapController? _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  List<Neighborhood> _all = [];
  final Map<String, Color> _colors = {};
  Neighborhood? _selected;
  bool _loading = true;
  bool _loadFailed = false;

  // نمایش
  MapType _mapType = MapType.normal;
  bool? _darkOverride; // null = بەپێی تیمی ئەپ
  bool _showLabels = true;
  bool _labelsZoomOk = true;
  bool _isMenuOpen = false;
  bool _favoritesOnly = false;
  bool _showRoute = true;
  final Set<String> _favorites = {}; // لە مێموری (بڕوانە تێبینی کۆتایی)

  // شوێنی بەکارهێنەر
  LatLng? _userLatLng;
  double? _userAccuracy;
  StreamSubscription<Position>? _posSub;
  bool get _tracking => _posSub != null;

  // کامێرا
  final ValueNotifier<CameraPosition> _cam = ValueNotifier(
    const CameraPosition(target: _kalarCenter, zoom: 13),
  );

  // کاش
  int _markersVersion = 0;
  int _labelRun = 0;
  final Map<String, BitmapDescriptor> _labelIcons = {};

  // 🧩 دژە-تێکچوون (declutter): کام ناو جێی دەبێتەوە بەبێ تێکچوون
  final Map<String, Size> _labelSizes = {}; // قەبارەی لۆجیکی هەر ناوێک
  final Map<int, BitmapDescriptor> _dotIcons = {}; // خاڵی ڕەنگاوڕەنگ
  final Map<String, double> _areas = {}; // ڕووبەر بۆ ڕیزبەندی گرنگی
  Set<String> _labelVisible = {};
  String? _declutterKey;
  Set<Polygon>? _polygonCache;
  String? _polygonCacheKey;
  Set<Marker>? _markerCache;
  String? _markerCacheKey;

  bool _en = false;
  String _t(String ku, String en) => _en ? en : ku;

  // ═══════════════════════════════════════════════════════════
  // 🎬 ئەنیمەیشن
  // ═══════════════════════════════════════════════════════════
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final AnimationController _selectController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _pulseAnimation;
  int _selectStep = 10; // 0..10

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگ و شێواز
  // ═══════════════════════════════════════════════════════════
  static const List<Color> _vibrantPalette = [
    Color(0xFFDC3545), Color(0xFFC2557A), Color(0xFF4F5BD5), Color(0xFF4F5BD5),
    Color(0xFF4F5BD5), Color(0xFF1E88E5), Color(0xFF1E88E5), Color(0xFF1E88E5),
    Color(0xFF0F9D7A), Color(0xFF0F9D7A), Color(0xFF0F9D7A), Color(0xFF0F9D7A),
    Color(0xFFD9822B), Color(0xFFD9822B), Color(0xFFD9822B), Color(0xFFD9822B),
    Color(0xFF6D4C41), Color(0xFF546E7A), Color(0xFF0F9D7A), Color(0xFF0F9D7A),
    Color(0xFF4F5BD5), Color(0xFFC2557A), Color(0xFF1E88E5), Color(0xFFD9822B),
    Color(0xFF0F9D7A),
  ];

  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#1d2433"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#8e9bb0"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#1d2433"}]},
    {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#3a4660"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#7d8aa3"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#1f3a34"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2f3b52"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1d2433"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#44547a"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2a3550"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f1a2e"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6a94"}]}
  ]
  ''';

  // ═══════════════════════════════════════════════════════════
  // 🔄 ژیانی widget
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _selectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1,
    )..addListener(() {
      final step = (_selectController.value * 10).round();
      if (step != _selectStep && mounted) {
        setState(() => _selectStep = step);
      }
    });

    _init();
  }

  @override
  void dispose() {
    _labelRun++; // وەستاندنی هەر کارێکی مارکەر
    _posSub?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    _selectController.dispose();
    _cam.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final data = await NeighborhoodService.getAll()
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;

      _all = data;
      _colors
        ..clear()
        ..addEntries([
          for (int i = 0; i < data.length; i++)
            MapEntry(_keyOf(data[i]), _colorFor(data[i], i)),
        ]);
      _polygonCacheKey = null;
      _markerCacheKey = null;
      _declutterKey = null;
      _areas
        ..clear()
        ..addEntries([
          for (final n in data)
            if (n.hasBoundary && n.boundaryPoints.length >= 3)
              MapEntry(_keyOf(n), _polygonArea(n.boundaryPoints)),
        ]);

      setState(() => _loading = false);
      _fadeController.forward(from: 0);

      // ئەگەر نەخشە پێشتر دروست بووبێت (دووبارە هەوڵدانەوە)
      if (_controller != null && _selected == null) {
        _fitAll(animate: false);
      }
      await _prepareLabelMarkers();
    } catch (e) {
      debugPrint('❌ هەڵە لە دەستپێکردن: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧰 یارمەتیدەرەکان
  // ═══════════════════════════════════════════════════════════
  String _keyOf(Neighborhood n) => n.id ?? n.nameKu;

  bool _isSelected(Neighborhood n) =>
      _selected != null && _keyOf(_selected!) == _keyOf(n);

  bool _isFav(Neighborhood n) => _favorites.contains(_keyOf(n));

  List<Neighborhood> get _visibleNeighborhoods => _favoritesOnly
      ? _all.where(_isFav).toList(growable: false)
      : _all;

  Color _colorFor(Neighborhood n, int index) {
    final name = n.nameKu;
    if (name.contains('زانکۆ')) return const Color(0xFF1E88E5);
    if (name.contains('شاری') || name.contains('سیتی')) {
      return const Color(0xFFDC3545);
    }
    if (name.contains('زۆنی') || name.contains('دریم لاند')) {
      return const Color(0xFF4F5BD5);
    }
    if (name.contains('گەڕەکی')) return const Color(0xFF0F9D7A);
    if (name.contains('شارەوانی')) return const Color(0xFFD9822B);
    if (name.contains('پارک') || name.contains('باخ')) {
      return const Color(0xFF0F9D7A);
    }
    if (name.contains('مەطار') || name.contains('وێستگە')) {
      return const Color(0xFF0F9D7A);
    }
    return _vibrantPalette[index % _vibrantPalette.length];
  }

  Color _color(Neighborhood n) => _colors[_keyOf(n)] ?? _blue;

  LatLng? _centerOf(Neighborhood n) {
    if (n.hasCenter) return LatLng(n.centerLatitude!, n.centerLongitude!);
    if (n.hasBoundary && n.boundaryPoints.length >= 3) {
      return _centroid(n.boundaryPoints);
    }
    return null;
  }

  LatLng _centroid(List<LatLng> pts) {
    double lat = 0, lon = 0;
    for (final p in pts) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / pts.length, lon / pts.length);
  }

  LatLngBounds? _boundsOf(Iterable<LatLng> pts) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = minLat == null ? p.latitude : math.min(minLat, p.latitude);
      maxLat = maxLat == null ? p.latitude : math.max(maxLat, p.latitude);
      minLng = minLng == null ? p.longitude : math.min(minLng, p.longitude);
      maxLng = maxLng == null ? p.longitude : math.max(maxLng, p.longitude);
    }
    if (minLat == null) return null;
    return LatLngBounds(
      southwest: LatLng(minLat, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  /// ray-casting: ئایا خاڵەکە لەناو پۆلیگۆنەکەدایە؟ (بێ ئینتەرنێت)
  bool _contains(List<LatLng> poly, LatLng p) {
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      final crosses = (a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude <
              (b.longitude - a.longitude) *
                  (p.latitude - a.latitude) /
                  (b.latitude - a.latitude) +
                  a.longitude;
      if (crosses) inside = !inside;
    }
    return inside;
  }

  Neighborhood? _findContaining(LatLng p) {
    for (final n in _all) {
      if (n.hasBoundary &&
          n.boundaryPoints.length >= 3 &&
          _contains(n.boundaryPoints, p)) {
        return n;
      }
    }
    return null;
  }

  double? _distanceToSelected() {
    final u = _userLatLng;
    final c = _selected == null ? null : _centerOf(_selected!);
    if (u == null || c == null) return null;
    return Geolocator.distanceBetween(
        u.latitude, u.longitude, c.latitude, c.longitude);
  }

  String _formatDistance(double m) => m < 1000
      ? '${m.round()} ${_t('مەتر', 'm')}'
      : '${(m / 1000).toStringAsFixed(1)} ${_t('کم', 'km')}';

  // ═══════════════════════════════════════════════════════════
  // 🏷️ مارکەری ناو
  // ═══════════════════════════════════════════════════════════
  Future<void> _prepareLabelMarkers() async {
    final run = ++_labelRun;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    final pending = _all
        .where((n) =>
    (n.hasCenter || n.hasBoundary) &&
        !_labelIcons.containsKey(_keyOf(n)))
        .toList();
    if (pending.isEmpty) return;

    // خاڵەکان (یەک دانە بۆ هەر ڕەنگێک)
    final colors = {for (final n in pending) _color(n).toARGB32()};
    for (final c in colors) {
      if (_dotIcons.containsKey(c)) continue;
      try {
        _dotIcons[c] = await _createDotMarker(Color(c), dpr);
      } catch (e) {
        debugPrint('❌ dot marker: $e');
      }
      if (!mounted || run != _labelRun) return;
    }

    const batchSize = 8;
    for (int i = 0; i < pending.length; i += batchSize) {
      final chunk = pending.skip(i).take(batchSize);
      final results = await Future.wait(
        chunk.map<Future<(String, BitmapDescriptor, Size)?>>((n) async {
          try {
            final r = await _createLabelMarker(n.nameKu, _color(n), dpr);
            return (_keyOf(n), r.icon, r.size);
          } catch (e) {
            debugPrint('❌ مارکەری ${n.nameKu}: $e');
            return null;
          }
        }),
      );
      if (!mounted || run != _labelRun) return;
      for (final r in results) {
        if (r == null) continue;
        _labelIcons[r.$1] = r.$2;
        _labelSizes[r.$1] = r.$3;
      }
      _declutterKey = null;
      _declutter(force: true);
    }
  }

  /// خاڵێکی بچووکی ڕەنگاوڕەنگ بۆ ئەو گەڕەکانەی ناوەکەیان جێی نابێتەوە.
  Future<BitmapDescriptor> _createDotMarker(Color color, double dpr) async {
    const size = 14.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr, dpr);
    const c = Offset(size / 2, size / 2);
    canvas.drawCircle(c, size / 2, Paint()..color = Colors.white);
    canvas.drawCircle(c, size / 2 - 2.2, Paint()..color = color);

    final picture = recorder.endRecording();
    final img = await picture.toImage((size * dpr).ceil(), (size * dpr).ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    picture.dispose();
    return BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🧩 دژە-تێکچوونی ناوەکان (Label collision / declutter)
  // ═══════════════════════════════════════════════════════════
  /// ڕووبەری پۆلیگۆن (shoelace) — تەنها بۆ بەراوردکردن.
  double _polygonArea(List<LatLng> pts) {
    double a = 0;
    for (int i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      a += (pts[j].longitude + pts[i].longitude) *
          (pts[j].latitude - pts[i].latitude);
    }
    return a.abs() / 2;
  }

  /// Web-Mercator → پیکسڵی لۆجیکی لە زوومی [zoom] (هەمان سیستەمی Google Maps).
  Offset _project(LatLng p, double zoom) {
    final scale = 256.0 * math.pow(2, zoom);
    final x = (p.longitude + 180) / 360 * scale;
    final s = math.sin(p.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
    final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale;
    return Offset(x, y);
  }

  /// بڕیار دەدات کام ناو پیشان بدرێت بەبێ ئەوەی بکەوێتە سەر یەکتر.
  /// ڕیزبەندی گرنگی: هەڵبژێردراو ← دڵخواز ← گەورەترین گەڕەک.
  void _declutter({bool force = false}) {
    final cam = _cam.value;
    // زووم بە 0.1 و بیرینگ بە 5° گرد دەکرێتەوە تا بێهودە دووبارە نەبێتەوە
    final zq = (cam.zoom * 10).round();
    final bq = (cam.bearing / 5).round();
    final key = '$zq|$bq|${_selected == null ? '-' : _keyOf(_selected!)}|'
        '${_favorites.length}|$_favoritesOnly|${_labelSizes.length}';
    if (!force && key == _declutterKey) return;
    _declutterKey = key;

    final zoom = zq / 10.0;
    final angle = -cam.bearing * math.pi / 180;
    final cosA = math.cos(angle), sinA = math.sin(angle);

    final candidates = <(Neighborhood, Offset)>[];
    for (final n in _visibleNeighborhoods) {
      final c = _centerOf(n);
      if (c == null || !_labelSizes.containsKey(_keyOf(n))) continue;
      final p = _project(c, zoom);
      // سووڕاندن بەپێی bearing (ناوەکان هەمیشە ڕاستن لەسەر شاشە)
      candidates.add((n, Offset(p.dx * cosA - p.dy * sinA, p.dx * sinA + p.dy * cosA)));
    }

    int rank(Neighborhood n) => _isSelected(n) ? 0 : (_isFav(n) ? 1 : 2);
    candidates.sort((a, b) {
      final r = rank(a.$1).compareTo(rank(b.$1));
      if (r != 0) return r;
      return (_areas[_keyOf(b.$1)] ?? 0).compareTo(_areas[_keyOf(a.$1)] ?? 0);
    });

    // سێبەری ناو مارکەرەکە (6px) لادەبرێت و 2px بۆشایی زیاد دەکرێت
    const shrink = 6.0 - 2.0;
    final placed = <Rect>[];
    final visible = <String>{};
    for (final (n, p) in candidates) {
      final k = _keyOf(n);
      final s = _labelSizes[k]!;
      final r = Rect.fromCenter(
        center: p,
        width: s.width - shrink * 2,
        height: s.height - shrink * 2,
      );
      if (_isSelected(n) || !placed.any(r.overlaps)) {
        placed.add(r);
        visible.add(k);
      }
    }

    if (!mounted) return;
    final changed = visible.length != _labelVisible.length ||
        !visible.containsAll(_labelVisible);
    if (changed || force) {
      setState(() {
        _labelVisible = visible;
        _markersVersion++;
      });
    }
  }

  Future<({BitmapDescriptor icon, Size size})> _createLabelMarker(
      String name,
      Color color,
      double dpr,
      ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr, dpr);

    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontFamily: 'Rabar',
          height: 1.2,
        ),
      ),
      textDirection: ui.TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 180);

    const padH = 10.0, padV = 6.0, shadow = 6.0;
    final w = math.max(tp.width + padH * 2, 28.0);
    final h = math.max(tp.height + padV * 2, 24.0);
    final totalW = w + shadow * 2;
    final totalH = h + shadow * 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(shadow, shadow, w, h),
      const Radius.circular(14),
    );

    canvas.drawShadow(
        Path()..addRRect(rrect), Colors.black.withValues(alpha: 0.45), 4, true);
    canvas.drawRRect(rrect, Paint()..color = color);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    tp.paint(canvas, const Offset(shadow + padH, shadow + padV));

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (totalW * dpr).ceil(),
      (totalH * dpr).ceil(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    picture.dispose();

    return (
    icon: BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    ),
    size: Size(totalW, totalH),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ polygon / marker / polyline / circle
  // ═══════════════════════════════════════════════════════════
  Set<Polygon> get _visiblePolygons {
    final key = '${_selected == null ? '-' : _keyOf(_selected!)}|$_selectStep|'
        '$_favoritesOnly|${_favorites.length}|${_all.length}';
    if (_polygonCache != null && _polygonCacheKey == key) {
      return _polygonCache!;
    }

    final t = _selectStep / 10.0;
    final hasSel = _selected != null;
    final polygons = <Polygon>{};

    for (final n in _visibleNeighborhoods) {
      if (!n.hasBoundary) continue;
      final sel = _isSelected(n);
      final dim = hasSel && !sel;
      final base = _color(n);

      polygons.add(Polygon(
        polygonId: PolygonId(_keyOf(n)),
        points: n.boundaryPoints,
        strokeColor: base.withValues(alpha: sel ? 1.0 : (dim ? 0.35 : 0.6)),
        strokeWidth: sel ? (2 + 3 * t).round() : (_isFav(n) ? 3 : 2),
        fillColor: base.withValues(
            alpha: sel ? 0.15 + 0.35 * t : (dim ? 0.07 : 0.15)),
        consumeTapEvents: true,
        geodesic: true,
        zIndex: sel ? 2 : (_isFav(n) ? 1 : 0),
        onTap: () {
          HapticFeedback.selectionClick();
          _selectNeighborhood(n);
        },
      ));
    }

    _polygonCacheKey = key;
    return _polygonCache = polygons;
  }

  Set<Marker> get _visibleMarkers {
    final key = '$_showLabels|$_labelsZoomOk|$_markersVersion|$_userLatLng|'
        '$_favoritesOnly|${_all.length}|'
        '${_selected == null ? '-' : _keyOf(_selected!)}';
    if (_markerCache != null && _markerCacheKey == key) return _markerCache!;

    final markers = <Marker>{};

    if (_showLabels && _labelsZoomOk) {
      for (final n in _visibleNeighborhoods) {
        final k = _keyOf(n);
        final center = _centerOf(n);
        if (center == null) continue;

        // ناو ئەگەر جێی دەبێتەوە، دەنا خاڵێکی بچووک
        final showLabel = _labelVisible.contains(k);
        final icon = showLabel
            ? _labelIcons[k]
            : _dotIcons[_color(n).toARGB32()];
        if (icon == null) continue;

        markers.add(Marker(
          markerId: MarkerId('label_$k'),
          position: center,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: _isSelected(n) ? 3 : (showLabel ? 2 : 1),
          consumeTapEvents: true,
          onTap: () {
            HapticFeedback.selectionClick();
            _selectNeighborhood(n);
          },
        ));
      }
    }

    final u = _userLatLng;
    if (u != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: u,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        zIndexInt: 10,
        infoWindow: InfoWindow(
          title: _t('تۆ', 'You'),
          snippet: _t('شوێنی ئێستا', 'Current location'),
        ),
      ));
    }

    _markerCacheKey = key;
    return _markerCache = markers;
  }

  Set<Circle> get _userCircles {
    final pos = _userLatLng, acc = _userAccuracy;
    if (pos == null || acc == null) return const {};
    return {
      Circle(
        circleId: const CircleId('user_accuracy'),
        center: pos,
        radius: acc.clamp(5.0, 500.0),
        fillColor: _blue.withValues(alpha: 0.12),
        strokeColor: _blue.withValues(alpha: 0.5),
        strokeWidth: 1,
      ),
    };
  }

  Set<Polyline> get _routeLines {
    final u = _userLatLng;
    final c = _selected == null ? null : _centerOf(_selected!);
    if (!_showRoute || u == null || c == null) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('to_selected'),
        points: [u, c],
        color: _color(_selected!),
        width: 4,
        geodesic: true,
        patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        zIndex: 5,
      ),
    };
  }

  // ═══════════════════════════════════════════════════════════
  // 🎥 کامێرا
  // ═══════════════════════════════════════════════════════════
  Future<void> _safeAnimate(CameraUpdate u, {bool animate = true}) async {
    final c = _controller;
    if (c == null) return;
    try {
      animate ? await c.animateCamera(u) : await c.moveCamera(u);
    } catch (e) {
      debugPrint('⚠️ camera: $e');
    }
  }

  Future<void> _fitAll({bool animate = true}) async {
    final pts = <LatLng>[];
    for (final n in _visibleNeighborhoods) {
      if (n.hasBoundary) {
        pts.addAll(n.boundaryPoints);
      } else {
        final c = _centerOf(n);
        if (c != null) pts.add(c);
      }
    }
    final b = _boundsOf(pts);
    if (b == null) {
      await _safeAnimate(CameraUpdate.newLatLngZoom(_kalarCenter, 13),
          animate: animate);
      return;
    }
    final extraNorth = (b.northeast.latitude - b.southwest.latitude) * 0.12;
    await _safeAnimate(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: b.southwest,
          northeast:
          LatLng(b.northeast.latitude + extraNorth, b.northeast.longitude),
        ),
        40,
      ),
      animate: animate,
    );
  }

  Future<void> _focusOn(Neighborhood n) async {
    if (n.hasBoundary && n.boundaryPoints.length >= 3) {
      final b = _boundsOf(n.boundaryPoints)!;
      final extraSouth = (b.northeast.latitude - b.southwest.latitude) * 0.8;
      await _safeAnimate(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest:
          LatLng(b.southwest.latitude - extraSouth, b.southwest.longitude),
          northeast: b.northeast,
        ),
        48,
      ));
      return;
    }
    final c = _centerOf(n);
    if (c != null) await _safeAnimate(CameraUpdate.newLatLngZoom(c, 15));
  }

  void _selectNeighborhood(Neighborhood n) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = n;
      _isMenuOpen = false;
      _selectStep = 0;
    });
    _selectController.forward(from: 0);
    _declutter();
    _focusOn(n);
  }

  void _clearSelection() {
    if (_selected == null) return;
    setState(() {
      _selected = null;
      _isMenuOpen = false;
      _selectStep = 10;
    });
    _declutter();
  }

  void _toggleTilt() {
    final c = _cam.value;
    final to3d = c.tilt < 1;
    _safeAnimate(CameraUpdate.newCameraPosition(CameraPosition(
      target: c.target,
      zoom: to3d ? math.max(c.zoom, 15.5) : c.zoom,
      bearing: c.bearing,
      tilt: to3d ? 55 : 0,
    )));
  }

  void _resetNorth() {
    final c = _cam.value;
    _safeAnimate(CameraUpdate.newCameraPosition(
      CameraPosition(target: c.target, zoom: c.zoom),
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 شوێنی بەکارهێنەر
  // ═══════════════════════════════════════════════════════════
  Future<bool> _ensureLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showSnackBar(_t('GPS ی مۆبایلەکەت بکەرەوە', 'Please turn on GPS'),
          Colors.orange.shade800, Icons.location_off_rounded);
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _showSnackBar(
        perm == LocationPermission.deniedForever
            ? _t('مۆڵەتی شوێن لە ڕێکخستنەکانی مۆبایل بکەرەوە',
            'Enable location permission in settings')
            : _t('مۆڵەتی شوێن نەدرا', 'Location permission denied'),
        const Color(0xFFDC3545),
        Icons.location_disabled_rounded,
      );
      return false;
    }
    return true;
  }

  void _applyPosition(Position p) {
    if (!mounted) return;
    setState(() {
      _userLatLng = LatLng(p.latitude, p.longitude);
      _userAccuracy = p.accuracy;
    });
  }

  Future<void> _locateUser() async {
    HapticFeedback.mediumImpact();
    setState(() => _isMenuOpen = false);
    try {
      if (!await _ensureLocation()) return;

      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _applyPosition(pos);

      final ll = LatLng(pos.latitude, pos.longitude);
      _safeAnimate(CameraUpdate.newLatLngZoom(ll, 16));

      // سەرەتا ناوخۆیی، ئەگەر نەبوو سێرڤەر
      final nearest = _findContaining(ll) ??
          await NeighborhoodService.findNeighborhoodByLocation(
            lat: pos.latitude,
            lng: pos.longitude,
          );
      if (!mounted) return;
      if (nearest != null) {
        _selectNeighborhood(nearest);
        _showSnackBar(
          '${_t('نزیکترین گەڕەک', 'Nearest neighborhood')}: ${nearest.nameKu}',
          Colors.green.shade700,
          Icons.location_on_rounded,
        );
      }
    } catch (e) {
      debugPrint('❌ شوێن: $e');
      _showSnackBar(_t('نەتوانرا شوێن بدۆزرێتەوە', 'Could not get location'),
          const Color(0xFFDC3545), Icons.error_outline_rounded);
    }
  }

  Future<void> _toggleTracking() async {
    HapticFeedback.selectionClick();
    setState(() => _isMenuOpen = false);

    if (_tracking) {
      await _posSub?.cancel();
      if (!mounted) return;
      setState(() => _posSub = null);
      _showSnackBar(_t('شوێنی زیندوو کوژایەوە', 'Live location off'),
          Colors.blueGrey, Icons.gps_off_rounded);
      return;
    }

    try {
      if (!await _ensureLocation()) return;
      final sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen(
        _applyPosition,
        onError: (e) => debugPrint('⚠️ position stream: $e'),
      );
      if (!mounted) {
        sub.cancel();
        return;
      }
      setState(() => _posSub = sub);
      _showSnackBar(_t('شوێنی زیندوو چالاک بوو', 'Live location on'),
          Colors.green.shade700, Icons.gps_fixed_rounded);
    } catch (e) {
      debugPrint('❌ tracking: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⚙️ کردارەکان
  // ═══════════════════════════════════════════════════════════
  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(message),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _cycleMapType() {
    HapticFeedback.selectionClick();
    const order = [
      MapType.normal,
      MapType.hybrid,
      MapType.satellite,
      MapType.terrain,
    ];
    setState(() {
      _mapType = order[(order.indexOf(_mapType) + 1) % order.length];
    });
  }

  String _mapTypeLabel(MapType t) {
    switch (t) {
      case MapType.normal:
        return _t('ئاسایی', 'Normal');
      case MapType.hybrid:
        return _t('هایبرید', 'Hybrid');
      case MapType.satellite:
        return 'Satellite';
      case MapType.terrain:
        return _t('شاخ', 'Terrain');
      default:
        return '';
    }
  }

  void _toggleFavorite(Neighborhood n) {
    HapticFeedback.mediumImpact();
    final k = _keyOf(n);
    final added = _favorites.add(k);
    if (!added) _favorites.remove(k);
    setState(() {
      if (_favorites.isEmpty) _favoritesOnly = false;
    });
    _declutter();
    _showSnackBar(
      added
          ? _t('زیادکرا بۆ دڵخوازەکان', 'Added to favorites')
          : _t('لە دڵخوازەکان لابرا', 'Removed from favorites'),
      added ? Colors.pink.shade600 : Colors.blueGrey,
      added ? Icons.favorite_rounded : Icons.favorite_border_rounded,
    );
  }

  void _zoomBy(double delta) {
    HapticFeedback.selectionClick();
    _safeAnimate(CameraUpdate.zoomBy(delta));
  }

  // ═══════════════════════════════════════════════════════════
  // 🧱 UI
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().languageId;
    _en = lang == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapDark = _darkOverride ?? isDark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Directionality(
      textDirection: _en ? TextDirection.ltr : TextDirection.rtl,
      child: PopScope(
        canPop: _selected == null && !_isMenuOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() {
            _selected = null;
            _isMenuOpen = false;
            _selectStep = 10;
          });
          _declutter();
        },
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: widget.onMenuTap != null
                ? IconButton(
                    icon: Icon(Icons.menu_rounded, color: fg),
                    onPressed: widget.onMenuTap,
                    tooltip: tr('مێنیو'),
                  )
                : IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: fg),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop();
                    },
                    tooltip: _t('گەڕانەوە', 'Back'),
                  ),
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                tr(_selected?.nameKu ?? _t('نەخشەی گەڕەکان 🗺️', 'Neighborhoods 🗺️')),
                key: ValueKey(_selected?.nameKu),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: fg),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showLabels ? Icons.label_rounded : Icons.label_off_rounded,
                  color: _showLabels
                      ? const Color(0xFF0F9D7A)
                      : (isDark ? Colors.white54 : Colors.grey),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showLabels = !_showLabels);
                },
                tooltip: _showLabels
                    ? _t('شاردنەوەی ناوەکان', 'Hide labels')
                    : _t('پیشاندانی ناوەکان', 'Show labels'),
              ),
              IconButton(
                icon: Icon(Icons.menu_rounded,
                    color: isDark ? Colors.white : _blue),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                tooltip: _t('لیستی گەڕەکان', 'Neighborhoods'),
              ),
            ],
          ),
          drawer: NeighborhoodsDrawer(
            neighborhoods: _all,
            current: _selected,
            onSelected: _selectNeighborhood,
            favoriteKeys: _favorites,
          ),
          body: Stack(
            children: [
              if (_loading)
                _buildLoadingScreen(isDark)
              else
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: GoogleMap(
                    initialCameraPosition:
                    const CameraPosition(target: _kalarCenter, zoom: 13),
                    mapType: _mapType,
                    style: (_mapType == MapType.normal && mapDark)
                        ? _darkMapStyle
                        : null,
                    polygons: _visiblePolygons,
                    markers: _visibleMarkers,
                    circles: _userCircles,
                    polylines: _routeLines,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false, // compass ی خۆمان هەیە
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    buildingsEnabled: true,
                    indoorViewEnabled: false,
                    trafficEnabled: false,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    onMapCreated: (c) {
                      _controller = c;
                      Future.delayed(const Duration(milliseconds: 350), () {
                        if (mounted && _selected == null) {
                          _fitAll(animate: false);
                        }
                      });
                    },
                    onCameraIdle: _declutter,
                    onCameraMove: (pos) {
                      _cam.value = pos;
                      final ok = pos.zoom >= _labelsMinZoom;
                      if (ok != _labelsZoomOk) {
                        setState(() => _labelsZoomOk = ok);
                      }
                    },
                    onTap: (_) {
                      if (_selected != null || _isMenuOpen) {
                        setState(() {
                          _selected = null;
                          _isMenuOpen = false;
                          _selectStep = 10;
                        });
                        _declutter();
                      }
                    },
                  ),
                ),
              if (!_loading) _buildSearchBar(isDark),
              if (!_loading) _buildDistanceChip(isDark),
              if (!_loading) _buildLeftControls(isDark),
              if (!_loading) _buildRightSideMenu(isDark),
              if (_selected != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: NeighborhoodInfoSheet(
                    neighborhood: _selected!,
                    onClose: _clearSelection,
                    distanceMeters: _distanceToSelected(),
                    isFavorite: _isFav(_selected!),
                    onToggleFavorite: () => _toggleFavorite(_selected!),
                  ),
                ),
              if (!_loading && (_all.isEmpty || _loadFailed))
                _buildEmptyState(isDark),
            ],
          ),
        ),
      ),
    );
  }

  double get _bottomOffset => _selected != null ? _sheetHeight : 30.0;

  List<_MenuAction> _menuActions() {
    final sel = _selected;
    final is3d = _cam.value.tilt > 1;
    return [
      _MenuAction(
        icon: Icons.my_location_rounded,
        label: _t('شوێنی من', 'My location'),
        color: _blue,
        pulsing: true,
        onTap: _locateUser,
      ),
      _MenuAction(
        icon: _tracking ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
        label: _tracking
            ? _t('وەستاندنی شوێنی زیندوو', 'Stop live location')
            : _t('شوێنی زیندوو', 'Live location'),
        color: const Color(0xFF0F9D7A),
        active: _tracking,
        onTap: _toggleTracking,
      ),
      _MenuAction(
        icon: Icons.layers_rounded,
        label: '${_t('جۆری نەخشە', 'Map type')}: ${_mapTypeLabel(_mapType)}',
        color: const Color(0xFFD9822B),
        onTap: _cycleMapType,
      ),
      _MenuAction(
        icon: (_darkOverride ?? Theme.of(context).brightness == Brightness.dark)
            ? Icons.light_mode_rounded
            : Icons.dark_mode_rounded,
        label: (_darkOverride ?? Theme.of(context).brightness == Brightness.dark)
            ? _t('شێوازی ڕۆژ', 'Day style')
            : _t('شێوازی شەو', 'Night style'),
        color: const Color(0xFF4F5BD5),
        onTap: () {
          final cur =
              _darkOverride ?? Theme.of(context).brightness == Brightness.dark;
          setState(() => _darkOverride = !cur);
        },
      ),
      _MenuAction(
        icon: Icons.view_in_ar_rounded,
        label: is3d ? _t('دوو ڕەهەند', '2D view') : _t('سێ ڕەهەند (3D)', '3D view'),
        color: const Color(0xFF1E88E5),
        active: is3d,
        onTap: _toggleTilt,
      ),
      if (sel != null && _userLatLng != null)
        _MenuAction(
          icon: Icons.timeline_rounded,
          label: _showRoute
              ? _t('شاردنەوەی هێڵی دووری', 'Hide distance line')
              : _t('پیشاندانی هێڵی دووری', 'Show distance line'),
          color: const Color(0xFF1E88E5),
          active: _showRoute,
          onTap: () => setState(() => _showRoute = !_showRoute),
        ),
      if (sel != null)
        _MenuAction(
          icon: _isFav(sel)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: _isFav(sel)
              ? _t('لابردن لە دڵخواز', 'Remove favorite')
              : _t('زیادکردن بۆ دڵخواز', 'Add to favorites'),
          color: const Color(0xFFC2557A),
          active: _isFav(sel),
          onTap: () => _toggleFavorite(sel),
        ),
      if (_favorites.isNotEmpty)
        _MenuAction(
          icon: Icons.star_rounded,
          label: _favoritesOnly
              ? _t('هەموو گەڕەکەکان', 'Show all')
              : _t('تەنها دڵخوازەکان', 'Favorites only'),
          color: const Color(0xFFD9822B),
          active: _favoritesOnly,
          onTap: () {
            setState(() => _favoritesOnly = !_favoritesOnly);
            _declutter();
            _fitAll();
          },
        ),
      _MenuAction(
        icon: Icons.zoom_out_map_rounded,
        label: _t('هەموو گەڕەکەکان', 'Fit all'),
        color: const Color(0xFFC2557A),
        onTap: () {
          _clearSelection();
          _fitAll();
        },
      ),
      if (sel != null)
        _MenuAction(
          icon: Icons.close_rounded,
          label: _t('لابردنی هەڵبژاردن', 'Clear selection'),
          color: const Color(0xFFDC3545),
          onTap: _clearSelection,
        ),
    ];
  }

  Widget _buildRightSideMenu(bool isDark) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // بەرزی بەردەست = بەرزی نەخشە - ژێرەوە - FAB - خانەی گەڕان
          final maxMenuHeight = math.max(
              0.0, constraints.maxHeight - _bottomOffset - 40 - 130);

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                right: 16,
                bottom: _bottomOffset,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedOpacity(
                          opacity: _isMenuOpen ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: AnimatedSlide(
                            offset: _isMenuOpen
                                ? Offset.zero
                                : const Offset(0, 0.2),
                            duration: const Duration(milliseconds: 300),
                            child: IgnorePointer(
                              ignoring: !_isMenuOpen,
                              child: ConstrainedBox(
                                constraints:
                                BoxConstraints(maxHeight: maxMenuHeight),
                                child: SingleChildScrollView(
                                  reverse: true,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (final a in _menuActions()) ...[
                                        _buildActionButton(a, isDark),
                                        const SizedBox(height: 12),
                                      ],
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        FloatingActionButton(
                          heroTag: null,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isMenuOpen = !_isMenuOpen);
                          },
                          backgroundColor:
                          isDark ? const Color(0xFF1A1A22) : Colors.white,
                          elevation: 6,
                          mini: true,
                          shape: const CircleBorder(),
                          child: AnimatedRotation(
                            turns: _isMenuOpen ? 0.125 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.add_rounded,
                              color: _isMenuOpen
                                  ? const Color(0xFFDC3545)
                                  : _blue,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(_MenuAction a, bool isDark) {
    final icon = Icon(a.icon, color: a.color, size: 22);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A35) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            tr(a.label),
            // مێنیوەکە LTR ـە، بەڵام دەقەکە کوردییە → RTL تا «3D» تێک نەچێت
            textDirection: _en ? TextDirection.ltr : TextDirection.rtl,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: a.active
              ? Color.alphaBlend(a.color.withValues(alpha: 0.16),
              isDark ? const Color(0xFF1A1A22) : Colors.white)
              : (isDark ? const Color(0xFF1A1A22) : Colors.white),
          elevation: 4,
          shadowColor: a.color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isMenuOpen = false);
              a.onTap();
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: a.color.withValues(alpha: a.active ? 0.6 : 0.25),
                  width: 1.5,
                ),
              ),
              child: a.pulsing
                  ? AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: icon,
              )
                  : icon,
            ),
          ),
        ),
      ],
    );
  }

}

/// داتای یەک دوگمەی مێنیو
class _MenuAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool pulsing;
  final bool active;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.pulsing = false,
    this.active = false,
  });
}