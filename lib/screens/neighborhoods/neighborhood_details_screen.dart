import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';
import '../../utils/app_logger.dart';

import '../stores/store_details_dialog.dart';

/// 🏘️ شاشەی وردەکاری گەڕەک — ULTRA PRO
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
  String? _errorMessage;

  Color get _color => widget.neighborhood.displayColor;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔢 پارسکردنی پارێزراوی ID
  // ═══════════════════════════════════════════════════════════
  int? _parseNeighborhoodId(dynamic id) {
    if (id == null) return null;
    if (id is int) return id;
    if (id is double) return id.toInt();

    if (id is String) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) return null;

      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;

      final asDouble = double.tryParse(trimmed);
      if (asDouble != null) return asDouble.toInt();
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 هێنانی شوێنەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadStores() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final n = widget.neighborhood;
      final neighborhoodId = _parseNeighborhoodId(n.id);

      AppLogger.i('🏘️ Loading stores for: ${n.nameKu}');
      AppLogger.i('   ID (raw): ${n.id}');
      AppLogger.i('   ID (parsed): $neighborhoodId');

      List<Map<String, dynamic>> stores = [];

      // ─── ڕێگای ١: بە ID ───
      if (neighborhoodId != null && neighborhoodId > 0) {
        try {
          final res = await Supabase.instance.client
              .from('dukan')
              .select()
              .eq('neighborhood_id', neighborhoodId)
              .order('name');

          stores = List<Map<String, dynamic>>.from(res as List);
          AppLogger.i('   ✅ ID query: ${stores.length} stores');
        } catch (e) {
          AppLogger.w('   ⚠️ ID query error: $e');
        }
      }

      // ─── ڕێگای ٢: Fallback بە name_ku ───
      if (stores.isEmpty && n.nameKu.isNotEmpty) {
        try {
          AppLogger.i('   🔄 Fallback: by name_ku = "${n.nameKu}"');

          String cleanName = n.nameKu.trim();
          if (cleanName.startsWith('گەڕەکی ')) {
            cleanName = cleanName.replaceFirst('گەڕەکی ', '').trim();
          } else if (cleanName.startsWith('گەڕەک ')) {
            cleanName = cleanName.replaceFirst('گەڕەک ', '').trim();
          }

          final res = await Supabase.instance.client
              .from('dukan')
              .select()
              .ilike('address', '%$cleanName%')
              .order('name');

          stores = List<Map<String, dynamic>>.from(res as List);
          AppLogger.i('   ✅ Name fallback: ${stores.length} stores');
        } catch (e) {
          AppLogger.w('   ⚠️ Name fallback error: $e');
        }
      }

      if (mounted) {
        setState(() {
          _stores = stores;
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e, st) {
      AppLogger.e('❌ _loadStores error', e, st);
      if (mounted) {
        setState(() {
          _stores = [];
          _loading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
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
        body: RefreshIndicator(
          color: color,
          onRefresh: _loadStores,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ═══ 🎨 هێدەری گەڕەک ═══
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
                          errorBuilder: (_, __, ___) =>
                              _buildGradientBg(color),
                        )
                      else
                        _buildGradientBg(color),
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

              // ═══ 📊 ناوەڕۆک ═══
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
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
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
                          color: isDark
                              ? const Color(0xFF1A1A22)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildStatItem(
                              Icons.storefront_rounded,
                              '${_stores.length}',
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
                                  markerId:
                                  const gmaps.MarkerId('center'),
                                  position: gmaps.LatLng(
                                    n.centerLatitude!,
                                    n.centerLongitude!,
                                  ),
                                  icon: gmaps.BitmapDescriptor
                                      .defaultMarkerWithHue(
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

              // ═══ 📋 بەشی شوێنەکان ═══
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
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_stores.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══ 📋 لیستی شوێنەکان ═══
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
              else if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: _buildErrorState(isDark, _errorMessage!),
                )
              else if (_stores.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(isDark, n.nameKu),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildStoreCard(_stores[i], isDark),
                        childCount: _stores.length,
                      ),
                    ),
                  ),
            ],
          ),
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
                      color:
                      isDark ? Colors.white : const Color(0xFF1A1A2E),
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

  Widget _buildEmptyState(bool isDark, String name) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 60,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'هیچ شوێنێک لەم گەڕەک نییە',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'گەڕەک: $name',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'هەڵە لە هێنانی شوێنەکان',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadStores,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('دووبارە هەوڵ بدە'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
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