import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../services/fuel_service.dart';
import '../../l10n/tr.dart';

/// 🗺️ نەخشەی وێستگەکانی سووتەمەنی
class FuelStationsMapScreen extends StatefulWidget {
  final String? fuelType;

  const FuelStationsMapScreen({super.key, this.fuelType});

  @override
  State<FuelStationsMapScreen> createState() =>
      _FuelStationsMapScreenState();
}

class _FuelStationsMapScreenState extends State<FuelStationsMapScreen> {
  gmaps.GoogleMapController? _mapController;
  Set<gmaps.Marker> _markers = {};
  bool _loading = true;
  List<Map<String, dynamic>> _stations = [];

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _loading = true);
    try {
      final stations = await FuelService.getCurrentPrices(
        fuelType: widget.fuelType,
      );

      final markers = <gmaps.Marker>{};
      for (final station in stations) {
        final lat = double.tryParse(station['latitude']?.toString() ?? '');
        final lng = double.tryParse(station['longitude']?.toString() ?? '');

        if (lat == null || lng == null || lat == 0 || lng == 0) continue;

        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId('station_${station['station_id']}'),
            position: gmaps.LatLng(lat, lng),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueOrange,
            ),
            infoWindow: gmaps.InfoWindow(
              title: station['station_name']?.toString() ?? tr('وێستگە'),
              snippet:
              '${(station['price'] as num?)?.toStringAsFixed(0) ?? '--'} د.ع',
            ),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _stations = stations;
          _markers = markers;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load stations error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          title: Text(
            tr('🗺️ نەخشەی وێستگەکان'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        )
            : Stack(
          children: [
            gmaps.GoogleMap(
              initialCameraPosition: const gmaps.CameraPosition(
                target: gmaps.LatLng(34.6189, 45.3156),
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) => _mapController = controller,
            ),
            // ⭐ Info Card
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1B2E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFD700),
                            Color(0xFFFFB300),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_gas_station_rounded,
                        color: Color(0xFF0F1421),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trf('{0} وێستگە', [_stations.length]),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr('لەسەر نەخشە نیشان دراون'),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFFFFD700),
                      ),
                      onPressed: () {
                        _mapController?.animateCamera(
                          gmaps.CameraUpdate.newLatLngZoom(
                            const gmaps.LatLng(34.6189, 45.3156),
                            14,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}