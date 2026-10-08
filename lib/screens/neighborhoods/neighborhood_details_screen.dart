import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';
import '../../services/neighborhood_service.dart';
import '../../widgets/neighborhoods/neighborhood_card.dart';
import '../stores/store_details_dialog.dart';

/// 🏘️ شاشەی وردەکاری گەڕەک
class NeighborhoodDetailsScreen extends StatefulWidget {
  final Neighborhood neighborhood;

  const NeighborhoodDetailsScreen({
    super.key,
    required this.neighborhood,
  });

  @override
  State<NeighborhoodDetailsScreen> createState() =>
      _NeighborhoodDetailsScreenState();
}

class _NeighborhoodDetailsScreenState
    extends State<NeighborhoodDetailsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _stores = [];

  Color get _color {
    try {
      String hex = widget.neighborhood.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    final stores = await NeighborhoodService.getStoresInNeighborhood(
      int.tryParse(widget.neighborhood.id ?? '0') ?? 0,
    );
    if (mounted) {
      setState(() {
        _stores = stores;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final n = widget.neighborhood;
    final color = _color;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          slivers: [
            // 🎨 هێدەری گەڕەک
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (n.coverUrl != null && n.coverUrl!.isNotEmpty)
                      Image.network(
                        n.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildGradientBg(color),
                      )
                    else
                      _buildGradientBg(color),
                    // 🌈 Gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 📊 ناوەڕۆک
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📌 ناوی گەڕەک
                    Text(
                      n.nameKu,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        height: 1.2,
                      ),
                    ),

                    // 📄 وەسف
                    if (n.descriptionKu != null &&
                        n.descriptionKu!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        n.descriptionKu!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: isDark
                              ? Colors.white70
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 📊 کارتی ئامار
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildStatItem(
                            Icons.storefront_rounded,
                            '${n.totalStores}',
                            'شوێن',
                            color,
                            isDark,
                          ),
                          if (n.population > 0)
                            _buildStatItem(
                              Icons.people_rounded,
                              '${n.population}',
                              'دانیشتوو',
                              const Color(0xFF10B981),
                              isDark,
                            ),
                          if (n.areaKm2 > 0)
                            _buildStatItem(
                              Icons.landscape_rounded,
                              n.areaKm2.toStringAsFixed(1),
                              'کم²',
                              const Color(0xFFF59E0B),
                              isDark,
                            ),
                        ],
                      ),
                    ),

                    // 🗺️ نەخشە
                    if (n.hasCenter) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.map_rounded,
                              color: color,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'شوێن لەسەر نەخشە',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: gmaps.GoogleMap(
                            initialCameraPosition: gmaps.CameraPosition(
                              target: gmaps.LatLng(
                                n.centerLatitude!,
                                n.centerLongitude!,
                              ),
                              zoom: 14,
                            ),
                            markers: {
                              gmaps.Marker(
                                markerId: const gmaps.MarkerId('center'),
                                position: gmaps.LatLng(
                                  n.centerLatitude!,
                                  n.centerLongitude!,
                                ),
                                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                                  _getHueFromColor(color),
                                ),
                                infoWindow: gmaps.InfoWindow(
                                  title: n.nameKu,
                                ),
                              ),
                            },
                            zoomControlsEnabled: false,
                            scrollGesturesEnabled: false,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 📋 بەشی شوێنەکان
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'شوێنەکانی ئەم گەڕەک',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_stores.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ),
              )
            else if (_stores.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 60,
                          color: isDark
                              ? Colors.white24
                              : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'هیچ شوێنێک لەم گەڕەک نییە',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                      final store = _stores[i];
                      return _buildStoreCard(store, isDark);
                    },
                    childCount: _stores.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store, bool isDark) {
    final name = store['name']?.toString() ?? '';
    final address = store['address']?.toString() ?? '';
    final image = store['image']?.toString() ?? '';
    final color = _color;

    return GestureDetector(
      onTap: () => StoreDetailsDialog.show(context, store),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image.isNotEmpty
                  ? Image.network(
                image,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: color.withValues(alpha: 0.15),
                  child: Icon(Icons.storefront_rounded, color: color),
                ),
              )
                  : Container(
                width: 60,
                height: 60,
                color: color.withValues(alpha: 0.15),
                child: Icon(Icons.storefront_rounded, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (address.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon,
      String value,
      String label,
      Color color,
      bool isDark,
      ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBg(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.location_city_rounded,
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }

  double _getHueFromColor(Color color) {
    final r = (color.r * 255).toInt();
    final g = (color.g * 255).toInt();
    final b = (color.b * 255).toInt();
    if (r > g && r > b) return gmaps.BitmapDescriptor.hueRed;
    if (g > r && g > b) return gmaps.BitmapDescriptor.hueGreen;
    if (b > r && b > g) return gmaps.BitmapDescriptor.hueAzure;
    return gmaps.BitmapDescriptor.hueViolet;
  }
}