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
import '../../utils/place_display.dart';

/// 🏘️ شاشەی وردەکاری گەڕەک — ULTRA PRO MAX V2
class NeighborhoodDetailsScreen extends StatefulWidget {
  final Neighborhood neighborhood;

  const NeighborhoodDetailsScreen({
    super.key,
    required this.neighborhood,
  });

  @override
  State<NeighborhoodDetailsScreen> createState() => _NeighborhoodDetailsScreenState();
}

class _NeighborhoodDetailsScreenState extends State<NeighborhoodDetailsScreen> {
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

    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

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
                      _buildStatsCard(n, color, isDark),
                      if (n.descriptionKu != null && n.descriptionKu!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDescription(n.descriptionKu!, isDark),
                      ],
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
    final hasCover = n.coverUrl != null && n.coverUrl!.isNotEmpty;
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      stretch: true,
      backgroundColor: color,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        expandedTitleScale: 1.5,
        titlePadding: const EdgeInsetsDirectional.only(start: 56, end: 56, bottom: 16),
        title: Text(
          tr(n.nameKu),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(offset: Offset(0, 1), blurRadius: 8, color: Colors.black38)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasCover)
              Image.network(
                n.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildGradientBg(color),
              )
            else
              _buildGradientBg(color),
            if (hasCover)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
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
  Widget _buildDescription(String description, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEEF1F6)),
      ),
      child: Text(
        tr(description),
        style: TextStyle(
          fontSize: 13.5,
          height: 1.8,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsCard(Neighborhood n, Color color, bool isDark) {
    final items = <Widget>[
      _buildStatItem(
        Icons.storefront_rounded,
        _loading ? '…' : PlaceDisplay.digits(_stores.length),
        'شوێن',
        color,
        isDark,
      ),
      if (n.population > 0)
        _buildStatItem(
          Icons.people_rounded,
          PlaceDisplay.digits(n.population),
          'دانیشتوو',
          AppColors.toneTeal,
          isDark,
        ),
      if (n.areaKm2 > 0)
        _buildStatItem(
          Icons.landscape_rounded,
          PlaceDisplay.digits(n.areaKm2.toStringAsFixed(2)),
          'کم²',
          AppColors.toneAmber,
          isDark,
        ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : color.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  indent: 6,
                  endIndent: 6,
                  color: isDark ? Colors.white10 : const Color(0xFFEEF1F6),
                ),
              items[i],
            ],
          ],
        ),
      ),
    );
  }

  /// ناونیشانی بەش: ئایکۆنی ڕەنگاوڕەنگ + ناو + (ژمارە)
  Widget _sectionTitle(IconData icon, String title, Color color, bool isDark, {String? count}) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.18)!,
                Color.lerp(color, Colors.black, 0.10)!
              ],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tr(title),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Map Section
  // ═══════════════════════════════════════════════════════════
  Widget _buildMapSection(Neighborhood n, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.map_rounded, 'شوێن لەسەر نەخشە', color, isDark),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : color.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
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
        child: _sectionTitle(
          Icons.storefront_rounded,
          'شوێنەکانی ئەم گەڕەک',
          color,
          isDark,
          count: _loading ? null : PlaceDisplay.digits(_stores.length),
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
    final rawAddress = store['address']?.toString().trim() ?? '';
    final address = rawAddress.isEmpty ? '' : PlaceDisplay.address(rawAddress);
    final category = store['category']?.toString().trim() ?? '';
    final image = store['image']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : color.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: isDark ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => StoreDetailsDialog.show(context, store),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFEEF1F6),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: image.isNotEmpty
                          ? Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildStorePlaceholder(color),
                            )
                          : _buildStorePlaceholder(color),
                    ),
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (category.isNotEmpty) ...[
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: isDark ? 0.20 : 0.09),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tr(category),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (address.isNotEmpty) ...[
                              Icon(
                                Icons.location_on_rounded,
                                size: 12,
                                color: isDark ? Colors.white54 : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  tr(address),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.22 : 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStorePlaceholder(Color color) {
    return Center(child: Icon(Icons.storefront_rounded, color: color, size: 26));
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
              color: isDark ? Colors.white24 : AppColors.backgroundGrey,
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
              tr(error.length > 100 ? '${error.substring(0, 100)}...' : error),
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(label),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBg(Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(color, Colors.black, 0.22)!,
            color,
            Color.lerp(color, Colors.white, 0.18)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -40, child: _bubble(190, 0.10)),
          Positioned(bottom: -60, left: -30, child: _bubble(170, 0.08)),
          Align(
            alignment: const Alignment(0, -0.15),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.5),
              ),
              child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 42),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bubble(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );

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
