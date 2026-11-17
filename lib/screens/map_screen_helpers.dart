// lib/screens/map_screen_helpers.dart
// بەشێک لە ڕووکاری _MapScreenState — لە map_screen.dart جیاکراوەتەوە

part of 'map_screen.dart';

extension _MapScreenStateHelpers on _MapScreenState {
  String _t(String ku, String en) => _en ? en : ku;

  String? _mapStyle(bool mapDark) {
    if (_mapType != MapType.normal) return null;
    final base = mapDark ? _MapScreenState._darkMapStyle : null;
    if (!_hideGooglePois) return base;
    if (base == null)
      return '[${_MapScreenState._poiOffRules}]'.replaceFirst(',]', ']');
    return base.replaceFirst('[', '[${_MapScreenState._poiOffRules}');
  }

  /// مارکەری شوێن: بازنەی سپی + ڕەنگی بەش + ئایکۆنی سپی
  Future<BitmapDescriptor> _createPlaceMarker(
      IconData icon, Color color, double dpr) async {
    const size = 30.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr, dpr);
    const c = Offset(size / 2, size / 2);
    canvas.drawCircle(c + const Offset(0, 1), size / 2 - 0.5,
        Paint()..color = const Color(0x33000000));
    canvas.drawCircle(c, size / 2 - 1, Paint()..color = Colors.white);
    canvas.drawCircle(c, size / 2 - 3.2, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 15,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    final picture = recorder.endRecording();
    final img = await picture.toImage((size * dpr).ceil(), (size * dpr).ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    picture.dispose();
    return BitmapDescriptor.bytes(data!.buffer.asUint8List(),
        imagePixelRatio: dpr);
  }

  // ═══════════════════════════════════════════════════════════
  // 🧰 یارمەتیدەرەکان
  // ═══════════════════════════════════════════════════════════
  String _keyOf(Neighborhood n) => n.id ?? n.nameKu;

  bool _isSelected(Neighborhood n) =>
      _selected != null && _keyOf(_selected!) == _keyOf(n);

  bool _isFav(Neighborhood n) => _favorites.contains(_keyOf(n));

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
    return _MapScreenState
        ._vibrantPalette[index % _MapScreenState._vibrantPalette.length];
  }

  Color _color(Neighborhood n) => _colors[_keyOf(n)] ?? _MapScreenState._blue;

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

  /// [ناو، ژمارە] ڕیزکراو بەپێی ژمارە
  List<MapEntry<String, int>> _groupCounts(
      Iterable<Map<String, dynamic>> rows, String field) {
    final m = <String, int>{};
    for (final p in rows) {
      final v = _MapScreenState._catOf(p, field);
      if (v.isNotEmpty) m[v] = (m[v] ?? 0) + 1;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Future<void> _fitPlaces(List<Map<String, dynamic>> rows) async {
    final pts = <LatLng>[];
    for (final p in rows) {
      final lat = double.tryParse('${p['latitude']}');
      final lng = double.tryParse('${p['longitude']}');
      if (lat != null && lng != null) pts.add(LatLng(lat, lng));
    }
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      await _safeAnimate(CameraUpdate.newLatLngZoom(pts.first, 16));
      return;
    }
    final b = _boundsOf(pts);
    if (b != null) await _safeAnimate(CameraUpdate.newLatLngBounds(b, 70));
  }

  /// ڕیزی چیپەکانی فلتەر لە ژێر گەڕان
  Widget _buildPlaceFilter(bool isDark) {
    final cats = _groupCounts(_places, 'category');
    final sel = _placeCategory;
    final subs = sel == null
        ? const <MapEntry<String, int>>[]
        : _groupCounts(
            _places.where((p) => _MapScreenState._catOf(p, 'category') == sel),
            'sub_category');

    Widget row(List<Widget> chips) => SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: chips,
          ),
        );

    return Positioned(
      top: 74,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([
            _PlaceChip(
              label: tr('هەموو'),
              count: _places.length,
              icon: Icons.apps_rounded,
              color: _MapScreenState._blue,
              selected: sel == null,
              isDark: isDark,
              onTap: () => _setPlaceFilter(null, null),
            ),
            for (final e in cats)
              _PlaceChip(
                label: tr(e.key),
                count: e.value,
                icon: PlaceDisplay.icon(e.key),
                color: PlaceDisplay.color(e.key),
                selected: sel == e.key,
                isDark: isDark,
                onTap: () => _setPlaceFilter(sel == e.key ? null : e.key, null),
              ),
          ]),
          if (sel != null && subs.isNotEmpty) ...[
            const SizedBox(height: 4),
            row([
              _PlaceChip(
                label: tr('هەمووی'),
                count: subs.fold<int>(0, (a, e) => a + e.value),
                icon: Icons.done_all_rounded,
                color: PlaceDisplay.color(sel),
                selected: _placeSubCategory == null,
                small: true,
                isDark: isDark,
                onTap: () => _setPlaceFilter(sel, null),
              ),
              for (final e in subs)
                _PlaceChip(
                  label: tr(e.key),
                  count: e.value,
                  icon: PlaceDisplay.icon(e.key),
                  color: PlaceDisplay.color(sel),
                  selected: _placeSubCategory == e.key,
                  small: true,
                  isDark: isDark,
                  onTap: () => _setPlaceFilter(
                      sel, _placeSubCategory == e.key ? null : e.key),
                ),
            ]),
          ],
        ],
      ),
    );
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
      await _safeAnimate(
          CameraUpdate.newLatLngZoom(_MapScreenState._kalarCenter, 13),
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

  void _zoomBy(double delta) {
    HapticFeedback.selectionClick();
    _safeAnimate(CameraUpdate.zoomBy(delta));
  }
}
