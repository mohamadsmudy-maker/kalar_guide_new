// lib/screens/neighborhoods/neighborhoods_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MapType;

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../l10n/tr.dart';

class NeighborhoodsMapScreen extends StatefulWidget {
  const NeighborhoodsMapScreen({super.key});

  @override
  State<NeighborhoodsMapScreen> createState() =>
      _NeighborhoodsMapScreenState();
}

class _NeighborhoodsMapScreenState extends State<NeighborhoodsMapScreen> {
  GoogleMapController? _mapController;
  bool _loading = true;
  String? _errorMessage;

  // ناوەندی شاری کەلار
  static const CameraPosition _kalarCenter = CameraPosition(
    target: LatLng(34.6167, 45.4167),
    zoom: 13.0,
  );

  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await Supabase.instance.client
          .from('neighborhoods')
          .select('id, name_ku, boundary, latitude, longitude');

      final List<Polygon> polygons = [];
      final List<Marker> markers = [];
      int colorIndex = 0;

      final colors = [
        AppColors.primary.withValues(alpha: 0.3),
        AppColors.green.withValues(alpha: 0.3),
        AppColors.orange.withValues(alpha: 0.3),
        AppColors.purple.withValues(alpha: 0.3),
        AppColors.red.withValues(alpha: 0.3),
      ];

      for (var item in res) {
        // ١. پۆلیگۆن
        if (item['boundary'] != null) {
          try {
            final List<dynamic> coords =
            item['boundary']['coordinates'][0];
            final points = coords
                .map((c) =>
                LatLng(c[1].toDouble(), c[0].toDouble()))
                .toList();

            polygons.add(
              Polygon(
                polygonId: PolygonId('neighborhood_${item['id']}'),
                points: points,
                fillColor: colors[colorIndex % colors.length],
                strokeColor: colors[colorIndex % colors.length]
                    .withValues(alpha: 1.0),
                strokeWidth: 2,
              ),
            );
            colorIndex++;
          } catch (e) {
            debugPrint('❌ Boundary parse error: $e');
          }
        }

        // ٢. مارکەر
        if (item['latitude'] != null && item['longitude'] != null) {
          final position = LatLng(
            (item['latitude'] as num).toDouble(),
            (item['longitude'] as num).toDouble(),
          );

          markers.add(
            Marker(
              markerId: MarkerId('marker_${item['id']}'),
              position: position,
              infoWindow: InfoWindow(
                title: item['name_ku']?.toString() ?? tr('گەڕەک'),
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _polygons.addAll(polygons);
        _markers.addAll(markers);
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading map data: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'هەڵە لە هێنانی داتا';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().languageId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = lang == 'ar'
        ? 'خريطة الأحياء'
        : (lang == 'en' ? 'Neighborhoods Map' : 'نەخشەی گەڕەکان');

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            tr(title),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        )
            : _errorMessage != null
            ? _buildErrorState()
            : Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _kalarCenter,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              polygons: _polygons,
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                heroTag: 'recenter_map',
                backgroundColor: isDark
                    ? AppColors.darkCard
                    : AppColors.surface,
                foregroundColor: AppColors.primary,
                onPressed: () {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      _kalarCenter,
                    ),
                  );
                },
                child: const Icon(
                  Icons.my_location_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: AppColors.red,
            ),
            const SizedBox(height: 16),
            Text(
              tr(_errorMessage ?? 'هەڵە'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMapData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('دووبارە هەوڵبدەرەوە')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}