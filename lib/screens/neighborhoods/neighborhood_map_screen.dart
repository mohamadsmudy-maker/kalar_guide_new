import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../l10n/tr.dart';
import '../../models/neighborhood.dart';
import '../../utils/place_display.dart';
import '../stores/store_details_dialog.dart';

/// 🗺️ نەخشەی تەواوی یەک گەڕەک: سنوور، ناوەند و شوێنەکانی تەنها ئەم گەڕەکە.
class NeighborhoodMapScreen extends StatefulWidget {
  final Neighborhood neighborhood;

  /// شوێنەکانی ئەم گەڕەک (هەمان لیستی شاشەی وردەکاری)
  final List<Map<String, dynamic>> stores;

  const NeighborhoodMapScreen({
    super.key,
    required this.neighborhood,
    this.stores = const [],
  });

  @override
  State<NeighborhoodMapScreen> createState() => _NeighborhoodMapScreenState();
}

class _NeighborhoodMapScreenState extends State<NeighborhoodMapScreen> {
  gmaps.GoogleMapController? _controller;
  gmaps.MapType _type = gmaps.MapType.normal;

  Neighborhood get _n => widget.neighborhood;

  List<(Map<String, dynamic>, gmaps.LatLng)> get _mapped {
    final out = <(Map<String, dynamic>, gmaps.LatLng)>[];
    for (final s in widget.stores) {
      final lat = double.tryParse(s['latitude']?.toString() ?? '');
      final lng = double.tryParse(s['longitude']?.toString() ?? '');
      if (lat == null || lng == null || lat == 0 || lng == 0) continue;
      out.add((s, gmaps.LatLng(lat, lng)));
    }
    return out;
  }

  gmaps.LatLng? get _center {
    if (_n.hasCenter) return gmaps.LatLng(_n.centerLatitude!, _n.centerLongitude!);
    final m = _mapped;
    return m.isEmpty ? null : m.first.$2;
  }

  /// هەموو خاڵەکان بۆ ئەوەی کامێرا هەموویان نیشان بدات
  List<gmaps.LatLng> get _points => [
        if (_n.hasBoundary) ..._n.boundaryPoints,
        if (_n.hasCenter) gmaps.LatLng(_n.centerLatitude!, _n.centerLongitude!),
        ..._mapped.map((e) => e.$2),
      ];

  void _fit() {
    final c = _controller;
    final pts = _points;
    if (c == null || pts.isEmpty) return;
    if (pts.length == 1) {
      c.animateCamera(gmaps.CameraUpdate.newLatLngZoom(pts.first, 16));
      return;
    }
    var minLat = pts.first.latitude, maxLat = minLat;
    var minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    c.animateCamera(gmaps.CameraUpdate.newLatLngBounds(
      gmaps.LatLngBounds(
        southwest: gmaps.LatLng(minLat, minLng),
        northeast: gmaps.LatLng(maxLat, maxLng),
      ),
      64,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = _n.displayColor;
    final center = _center ?? const gmaps.LatLng(34.6189, 45.3156);
    final mapped = _mapped;
    final top = MediaQuery.paddingOf(context).top;

    final markers = <gmaps.Marker>{
      if (_n.hasCenter)
        gmaps.Marker(
          markerId: const gmaps.MarkerId('center'),
          position: center,
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueGreen),
          infoWindow: gmaps.InfoWindow(title: tr(_n.nameKu)),
        ),
      for (final (store, pos) in mapped)
        gmaps.Marker(
          markerId: gmaps.MarkerId('s${store['id']}'),
          position: pos,
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueAzure),
          infoWindow: gmaps.InfoWindow(
            title: tr(store['name']?.toString() ?? ''),
            snippet: tr('کرتە بکە بۆ وردەکاری'),
            onTap: () => StoreDetailsDialog.show(context, store),
          ),
        ),
    };

    final polygons = <gmaps.Polygon>{
      if (_n.hasBoundary)
        gmaps.Polygon(
          polygonId: const gmaps.PolygonId('boundary'),
          points: _n.boundaryPoints,
          fillColor: color.withValues(alpha: 0.18),
          strokeColor: color,
          strokeWidth: 3,
        ),
    };

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        body: Stack(
          children: [
            gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(target: center, zoom: 15),
              mapType: _type,
              markers: markers,
              polygons: polygons,
              onMapCreated: (c) {
                _controller = c;
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _fit();
                });
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              padding: EdgeInsets.only(top: top + 70, bottom: 24),
            ),

            // سەرەوە: گەڕانەوە + ناوی گەڕەک + جۆری نەخشە
            Positioned(
              top: top + 10,
              left: 12,
              right: 12,
              child: Material(
                elevation: 6,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: tr('گەڕانەوە'),
                        icon: Icon(
                          AppLang.isRtl
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_back_rounded,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr(_n.nameKu),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              trf('{0} شوێن', [PlaceDisplay.digits(mapped.length)]),
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: tr('جۆری نەخشە'),
                        icon: Icon(_type == gmaps.MapType.normal
                            ? Icons.satellite_alt_rounded
                            : Icons.map_rounded),
                        onPressed: () => setState(() {
                          _type = _type == gmaps.MapType.normal
                              ? gmaps.MapType.hybrid
                              : gmaps.MapType.normal;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // خوارەوە: گەڕانەوە بۆ دیمەنی تەواوی گەڕەک
            PositionedDirectional(
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              end: 16,
              child: FloatingActionButton.small(
                heroTag: 'nb_map_fit',
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: color,
                onPressed: _fit,
                child: const Icon(Icons.center_focus_strong_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
