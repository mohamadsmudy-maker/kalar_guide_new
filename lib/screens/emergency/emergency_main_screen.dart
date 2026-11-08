// 📁 presentation/screens/emergency/emergency_main_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/providers.dart';
import '../../models/emergency_categories.dart';
import '../../models/emergency_service.dart';
import '../../services/emergency_repository.dart';
import '../../services/location_service.dart';
import '../../l10n/tr.dart';

part 'emergency_main_screen_ui.dart';

// ═══════════════════════════════════════════════════════════
// 🧠 Providers
// ═══════════════════════════════════════════════════════════

/// Raw list from the backend (cached, refreshable).
final emergencyServicesProvider =
FutureProvider.autoDispose<List<EmergencyService>>((ref) async {
  final logger = ref.read(appLoggerProvider);
  try {
    final data = await EmergencyServiceRepository.getAll();
    logger.d('EmergencyServices', 'loaded ${data.length}');
    return data;
  } catch (e, st) {
    logger.e('EmergencyServices', 'load failed', e, st);
    rethrow;
  }
});

/// Current GPS position (nullable → not yet known / denied).
final currentPositionProvider = FutureProvider.autoDispose<Position?>((ref) async {
  final logger = ref.read(appLoggerProvider);
  try {
    return await LocationService.getCurrentPosition();
  } catch (e, st) {
    logger.w('Location', 'position failed', e, st);
    return null;
  }
});

/// Filter UI state — search, category, sort.
class EmergencyFilter {
  final String search;
  final String category;
  final EmergencySort sort;

  const EmergencyFilter({
    this.search = '',
    this.category = 'all',
    this.sort = EmergencySort.def,
  });

  EmergencyFilter copyWith({
    String? search,
    String? category,
    EmergencySort? sort,
  }) {
    return EmergencyFilter(
      search: search ?? this.search,
      category: category ?? this.category,
      sort: sort ?? this.sort,
    );
  }
}

enum EmergencySort {
  def('default', 'ئاسایی', Icons.sort_rounded),
  distance('distance', 'نزیکترین', Icons.near_me_rounded),
  name('name', 'ناو', Icons.abc_rounded);

  final String key;
  final String label;
  final IconData icon;
  const EmergencySort(this.key, this.label, this.icon);
}

class EmergencyFilterNotifier extends StateNotifier<EmergencyFilter> {
  EmergencyFilterNotifier() : super(const EmergencyFilter());

  void setSearch(String v) => state = state.copyWith(search: v.trim());
  void setCategory(String v) => state = state.copyWith(category: v);
  void setSort(EmergencySort v) => state = state.copyWith(sort: v);
  void reset() => state = const EmergencyFilter();
}

final emergencyFilterProvider =
StateNotifierProvider.autoDispose<EmergencyFilterNotifier, EmergencyFilter>(
      (ref) => EmergencyFilterNotifier(),
);

/// 🔎 Filtered + sorted list — derived provider. Cheap because
/// `_hexToColor`, distance, and name lookups are precomputed per item.
class EmergencyRow {
  final EmergencyService service;
  final double? distanceKm; // null → unknown
  final int sortKey; // used only for tie-break

  EmergencyRow({
    required this.service,
    required this.distanceKm,
    this.sortKey = 0,
  });
}

final filteredEmergencyProvider =
Provider.autoDispose<List<EmergencyRow>>((ref) {
  final servicesAsync = ref.watch(emergencyServicesProvider);
  final posAsync = ref.watch(currentPositionProvider);
  final filter = ref.watch(emergencyFilterProvider);

  return servicesAsync.maybeWhen(
    data: (services) {
      final pos = posAsync.valueOrNull;

      // 1️⃣ Category
      var list = services;
      if (filter.category != 'all') {
        list = list.where((s) => s.category == filter.category).toList();
      }

      // 2️⃣ Search (localized + phone + alt phone + address + notes)
      if (filter.search.isNotEmpty) {
        final q = filter.search.toLowerCase();
        list = list.where((s) {
          final haystack = [
            s.nameKu,
            s.nameAr ?? '',
            s.nameEn ?? '',
            s.phone,
            s.phoneAlt ?? '',
            s.address ?? '',
            s.notes ?? '',
            s.authorityName ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(q);
        }).toList();
      }

      // 3️⃣ Distance (precompute once)
      final rows = list.map((s) {
        double? d;
        if (pos != null && s.hasLocation) {
          d = LocationService.calculateDistance(
            pos.latitude,
            pos.longitude,
            s.latitude!,
            s.longitude!,
          );
        }
        return EmergencyRow(service: s, distanceKm: d);
      }).toList();

      // 4️⃣ Sort
      switch (filter.sort) {
        case EmergencySort.distance:
          rows.sort((a, b) {
            final da = a.distanceKm ?? double.infinity;
            final db = b.distanceKm ?? double.infinity;
            return da.compareTo(db);
          });
        case EmergencySort.name:
          rows.sort(
                (a, b) => a.service.nameKu.compareTo(b.service.nameKu),
          );
        case EmergencySort.def:
          rows.sort(
                (a, b) => a.service.displayOrder.compareTo(b.service.displayOrder),
          );
      }

      return rows;
    },
    orElse: () => const [],
  );
});

// ═══════════════════════════════════════════════════════════
// 🖥️ Screen
// ═══════════════════════════════════════════════════════════
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  late final AnimationController _entryController;
  late final AnimationController _pulseController;
  late final Animation<double> _entryAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────
  // 🔄 Refresh
  // ───────────────────────────────────────────────────────
  Future<void> _refresh() async {
    ref.invalidate(emergencyServicesProvider);
    ref.invalidate(currentPositionProvider);
    await ref.read(emergencyServicesProvider.future);
  }

  // ───────────────────────────────────────────────────────
  // 📞 Call
  // ───────────────────────────────────────────────────────
  Future<void> _call(String phone) async {
    HapticFeedback.selectionClick();
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        await _copyAndToast(phone, 'ژمارە کۆپی کرا');
        return;
      }
      await launchUrl(uri);
    } catch (e) {
      ref.read(appLoggerProvider).e('Call', 'failed', e);
      await _copyAndToast(phone, 'نەتوانرا پەیوەندی بکرێت');
    }
  }

  Future<void> _copyAndToast(String value, String msg) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr(msg)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ───────────────────────────────────────────────────────
  // 🗺️ Directions
  // ───────────────────────────────────────────────────────
  Future<void> _openDirections(EmergencyService s) async {
    if (!s.hasLocation) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${s.latitude},${s.longitude}',
    );
    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        await _copyAndToast('${s.latitude},${s.longitude}', 'کۆردینات کۆپی کرا');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ref.read(appLoggerProvider).e('Directions', 'failed', e);
    }
  }

  // ───────────────────────────────────────────────────────
  // 📤 Share (stub — replace with share_plus later)
  // ───────────────────────────────────────────────────────
  Future<void> _share(EmergencyService s) async {
    final text = '${s.nameKu}\n${s.phone}'
        '${s.phoneAlt != null ? '\n${s.phoneAlt}' : ''}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr('زانیاری کۆپی کرا — ئێستا هاوبەشی بکە')),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ───────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final servicesAsync = ref.watch(emergencyServicesProvider);
    final rows = ref.watch(filteredEmergencyProvider);
    final filter = ref.watch(emergencyFilterProvider);
    final position = ref.watch(currentPositionProvider).valueOrNull;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF0F4F9),
      body: RefreshIndicator(
        color: const Color(0xFFDC3545),
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(isDark, servicesAsync, filter),
            SliverToBoxAdapter(child: _buildSearchBar(isDark, filter)),
            SliverToBoxAdapter(child: _buildFilters(isDark, filter)),
            SliverToBoxAdapter(child: _buildSortBar(isDark, filter)),
            if (rows.isNotEmpty || servicesAsync.hasValue)
              SliverToBoxAdapter(
                child: _buildStatsCard(isDark, filter, rows.length, position),
              ),
            _buildBody(isDark, servicesAsync, rows, filter),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  // Search
  // ───────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark, EmergencyFilter filter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: filter.search.isNotEmpty
                ? const Color(0xFFDC3545).withValues(alpha: 0.5)
                : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (val) {
            // ✅ debounced — no double setState
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 180), () {
              ref.read(emergencyFilterProvider.notifier).setSearch(val);
            });
          },
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: tr('گەڕان بەدوای ژمارە...'),
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFFDC3545),
              size: 22,
            ),
            suffixIcon: filter.search.isNotEmpty
                ? IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              onPressed: () {
                _searchCtrl.clear();
                ref.read(emergencyFilterProvider.notifier).setSearch('');
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════
// 🧱 Card (own widget → fewer rebuilds)
// ═══════════════════════════════════════════════════════════
class _EmergencyCard extends ConsumerWidget {
  final EmergencyRow row;
  final bool isDark;
  final AnimationController pulse;
  final Animation<double> pulseValue;
  final Animation<double> entry;
  final int index;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final VoidCallback onShare;
  final void Function(String msg) onCopied;

  const _EmergencyCard({
    super.key,
    required this.row,
    required this.isDark,
    required this.pulse,
    required this.pulseValue,
    required this.entry,
    required this.index,
    required this.onCall,
    required this.onDirections,
    required this.onShare,
    required this.onCopied,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = row.service;
    final color = service.displayColor;
    final icon = service.categoryInfo.iconData;
    final favoriteIds = ref.watch(_favoritesProvider);
    final isFavorite = service.id != null && favoriteIds.contains(service.id);

    final distance = row.distanceKm;
    final hasDistance = distance != null;

    // Entry animation — computed once per frame during entry, then static
    final t = entry.value;
    final delay = (index * 0.08).clamp(0.0, 0.5);
    final progress = ((t - delay) / 0.4).clamp(0.0, 1.0);
    final animated = index < 6 && progress < 1.0;

    Widget content = _buildContent(
      context,
      service,
      color,
      icon,
      isFavorite,
      hasDistance,
      distance,
      ref,
    );

    if (animated) {
      content = AnimatedBuilder(
        animation: entry,
        builder: (_, child) {
          final tt = entry.value;
          final p = ((tt - delay) / 0.4).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, 20 * (1 - p)),
            child: Opacity(opacity: p, child: child),
          );
        },
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: content,
    );
  }

  Widget _buildContent(
      BuildContext context,
      EmergencyService service,
      Color color,
      IconData icon,
      bool isFavorite,
      bool hasDistance,
      double? distance,
      WidgetRef ref,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onCall,
          onLongPress: () => _showContextSheet(context, service, ref),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icon circle
                    service.isImportant
                        ? AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => Transform.scale(
                        scale:
                        1.0 + (pulseValue.value - 1.0) * 0.3,
                        child: _iconCircle(color, icon),
                      ),
                    )
                        : _iconCircle(color, icon),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr(service.getName('ku')),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A2E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (service.isImportant)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC3545),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tr('گرنگ'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone_rounded, size: 13, color: color),
                              const SizedBox(width: 4),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  tr(service.phone),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (service.is24h) ...[
                                const SizedBox(width: 8),
                                _badge('٢٤/٧', const Color(0xFF0F9D7A)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if ((service.authorityName ?? '').isNotEmpty) ...[
                                Icon(Icons.business_rounded,
                                    size: 10,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    tr(service.authorityName!),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (hasDistance) ...[
                                if ((service.authorityName ?? '').isNotEmpty)
                                  const SizedBox(width: 8),
                                const Icon(Icons.near_me_rounded,
                                    size: 10, color: Color(0xFF0F9D7A)),
                                const SizedBox(width: 3),
                                Text(
                                  trf('{0} کم', [distance!.toStringAsFixed(1)]),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF0F9D7A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onCall,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.8)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade200,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _actionBtn(
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: isFavorite ? tr('دڵخواز') : tr('زیادکردن'),
                      color: isFavorite ? const Color(0xFFC2557A) : Colors.grey,
                      onTap: () {
                        if (service.id == null) {
                          onCopied('ژمارە کۆپی کرا');
                          return;
                        }
                        HapticFeedback.selectionClick();
                        ref
                            .read(_favoritesProvider.notifier)
                            .toggle(service.id!);
                      },
                    ),
                    _actionBtn(
                      icon: Icons.share_rounded,
                      label: tr('هاوبەشکردن'),
                      color: const Color(0xFF1E88E5),
                      onTap: onShare,
                    ),
                    if (service.hasLocation)
                      _actionBtn(
                        icon: Icons.directions_rounded,
                        label: tr('ئاراستە'),
                        color: const Color(0xFF0F9D7A),
                        onTap: onDirections,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconCircle(Color color, IconData icon) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_filled_rounded, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            tr(text),
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                tr(label),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextSheet(
      BuildContext context,
      EmergencyService service,
      WidgetRef ref,
      ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call_rounded),
              title: Text(tr('پەیوەندی')),
              onTap: () {
                Navigator.pop(ctx);
                onCall();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(tr('کۆپیکردنی ژمارە')),
              onTap: () {
                Navigator.pop(ctx);
                onCopied(service.phone);
              },
            ),
            if (service.hasLocation)
              ListTile(
                leading: const Icon(Icons.directions_rounded),
                title: Text(tr('ئاراستە')),
                onTap: () {
                  Navigator.pop(ctx);
                  onDirections();
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(tr('هاوبەشکردن')),
              onTap: () {
                Navigator.pop(ctx);
                onShare();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ⭐ Favorites (persisted)
// ═══════════════════════════════════════════════════════════
class FavoritesNotifier extends StateNotifier<Set<String>> {
  static const _key = 'emergency_favorites_v1';
  FavoritesNotifier(this._ref) : super(const {}) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final prefs = await _ref.read(sharedPreferencesAsyncProvider.future);
      state = (prefs.getStringList(_key) ?? const []).toSet();
    } catch (_) {
      // ignore — empty set is fine
    }
  }

  Future<void> toggle(String id) async {
    final next = {...state};
    if (!next.add(id)) next.remove(id);
    state = next;
    try {
      final prefs = await _ref.read(sharedPreferencesAsyncProvider.future);
      await prefs.setStringList(_key, next.toList());
    } catch (_) {}
  }
}

final _favoritesProvider =
StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier(ref);
});