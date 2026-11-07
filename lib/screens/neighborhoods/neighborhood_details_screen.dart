import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';
import '../../utils/app_logger.dart';
import '../stores/store_details_dialog.dart';
import '../../l10n/tr.dart';

/// 🏘️ شاشەی وردەکاری گەڕەک — ULTRA PRO MAX V2
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

      if (!mounted) return;
      setState(() {
        _stores = stores;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e, st) {
      AppLogger.e('❌ _loadStores error', e, st);
      if (!mounted) return;
      setState(() {
        _stores = [];
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final n = widget.neighborhood;
    final color = _color;

    final bgColor =
    isDark ? AppColors.darkBackground : AppColors.background;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: RefreshIndicator(
          color: color,
          onRefresh: _loadStores,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeader(n, color, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(n, isDark),
                      if (n.descriptionKu != null &&
                          n.descriptionKu!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildDescription(n.descriptionKu!, isDark),
                      ],
                      const SizedBox(height: 16),
                      _buildStatsCard(n, color, isDark),
                      if (n.hasCenter) ...[
                        const SizedBox(height: 20),
                        _buildMapSection(n, color, isDark),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _buildStoresSectionHeader(color, isDark),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: _buildErrorState(isDark, _errorMessage!, color),
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
                            (ctx, i) => _buildStoreCard(_stores[i], isDark, color),
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

  // ═══════════════════════════════════════════════════════════
  // 🎨 Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(Neighborhood n, Color color, bool isDark) {
    return SliverAppBar(
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 Title + Description
  // ═══════════════════════════════════════════════════════════
  Widget _buildTitle(Neighborhood n, bool isDark) {
    return Text(
      tr(n.nameKu),
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : AppColors.textPrimary,
        height: 1.2,
      ),
    );
  }

  Widget _buildDescription(String description, bool isDark) {
    return Text(
      tr(description),
      style: TextStyle(
        fontSize: 13,
        height: 1.7,
        color: isDark ? Colors.white70 : AppColors.textSecondary,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsCard(Neighborhood n, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
              AppColors.green,
              isDark,
            ),
          if (n.areaKm2 > 0)
            _buildStatItem(
              Icons.landscape_rounded,
              n.areaKm2.toStringAsFixed(1),
              'کم²',
              AppColors.orange,
              isDark,
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Map Section
  // ═══════════════════════════════════════════════════════════
  Widget _buildMapSection(Neighborhood n, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.map_rounded, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              tr('شوێن لەسەر نەخشە'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimary,
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
                  infoWindow: gmaps.InfoWindow(title: n.nameKu),
                ),
              },
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Stores Section Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoresSectionHeader(Color color, bool isDark) {
    return SliverToBoxAdapter(
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
              tr('شوێنەکانی ئەم گەڕەک'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimary,
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Store Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoreCard(
      Map<String, dynamic> store,
      bool isDark,
      Color color,
      ) {
    final name = store['name']?.toString() ?? '';
    final address = store['address']?.toString() ?? '';
    final image = store['image']?.toString() ?? '';

    return GestureDetector(
      onTap: () => StoreDetailsDialog.show(context, store),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
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
                errorBuilder: (_, __, ___) => _buildStorePlaceholder(
                  color,
                ),
              )
                  : _buildStorePlaceholder(color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(name),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
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
                          color: isDark
                              ? Colors.white54
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            tr(address),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary,
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
            Icon(Icons.chevron_left_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStorePlaceholder(Color color) {
    return Container(
      width: 60,
      height: 60,
      color: color.withValues(alpha: 0.15),
      child: Icon(Icons.storefront_rounded, color: color),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Empty / Error
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark, String name) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 60,
              color: isDark
                  ? Colors.white24
                  : AppColors.backgroundGrey,
            ),
            const SizedBox(height: 12),
            Text(
              tr('هیچ شوێنێک لەم گەڕەک نییە'),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trf('گەڕەک: {0}', [name]),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error, Color color) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: AppColors.red.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              tr('هەڵە لە هێنانی شوێنەکان'),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(error.length > 100
                  ? '${error.substring(0, 100)}...'
                  : error),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadStores,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(tr('دووبارە هەوڵ بدە')),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
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

  // ═══════════════════════════════════════════════════════════
  // 🔢 Helpers
  // ═══════════════════════════════════════════════════════════
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
            tr(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tr(label),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
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