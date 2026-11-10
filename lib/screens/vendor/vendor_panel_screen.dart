// lib/screens/vendor/vendor_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/auth_service.dart';
import '../../services/fuel_service.dart';
import '../../utils/place_display.dart';
import '../admin/admin_dashboard.dart';
import '../currency/currency_station_details_screen.dart';
import '../fuel/station_details_screen.dart';

/// 🏪 «پانێڵەکەم» — ڤێندەری بەنزینخانە یان نوسینگەی دراو
///
/// شوێنەکانی خۆی (بە store_id یان ژمارەی تەلەفۆن) پیشان دەدات و بە یەک
/// کرتە دەچێتە شاشەی شوێنەکە، کە گۆڕینی نرخ و مێژووی نرخەکانی تێدایە.
/// هەمان یاسای مۆڵەتی Supabase بەکاردێت ([AuthSessionManager.canEditStation]).
class VendorPanelScreen extends StatefulWidget {
  const VendorPanelScreen({super.key});

  @override
  State<VendorPanelScreen> createState() => _VendorPanelScreenState();
}

enum _Kind { fuel, currency, other }

class _VendorPanelScreenState extends State<VendorPanelScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _places = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sid = AuthSessionManager.storeId?.toString() ?? '';
      final key = AuthSessionManager.phoneKey(AuthSessionManager.currentUser?['phone']);
      final filters = <String>[
        if (int.tryParse(sid) != null) 'id.eq.$sid',
        // ٩ ژمارەی کۆتایی — دواتر بە phoneKey ڕێک بەراورد دەکرێت
        if (key.length == 10) 'phone.ilike.*${key.substring(1)}*',
      ];
      var rows = <Map<String, dynamic>>[];
      if (filters.isNotEmpty) {
        final res = await Supabase.instance.client
            .from('dukan')
            .select('id, name, phone, address, logo, image, category, sub_category, '
                'fuel_prices, currency_prices')
            .or(filters.join(','))
            .order('name');
        rows = List<Map<String, dynamic>>.from(res as List)
            .where((r) => AuthSessionManager.canEditStation(stationId: r['id'], stationPhone: r['phone']))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _places = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  static _Kind _kindOf(Map<String, dynamic> p) {
    final cat = '${p['category'] ?? ''} ${p['sub_category'] ?? ''}';
    final cur = p['currency_prices'];
    final fuel = p['fuel_prices'];
    if ((cur is Map && cur.isNotEmpty) || cat.contains('دراو') || cat.contains('سەرافی')) {
      return _Kind.currency;
    }
    if ((fuel is Map && fuel.isNotEmpty) || FuelService.isStation(p)) return _Kind.fuel;
    return _Kind.other;
  }

  int _priceCount(Map<String, dynamic> p, _Kind k) {
    final m = k == _Kind.fuel ? p['fuel_prices'] : p['currency_prices'];
    return m is Map ? m.length : 0;
  }

  Future<void> _open(Map<String, dynamic> p, _Kind k) async {
    HapticFeedback.selectionClick();
    final id = int.tryParse('${p['id']}');
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => k == _Kind.currency
            ? CurrencyStationDetailsScreen(stationId: id)
            : StationDetailsScreen(stationId: id),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF2F5FA);
    final name = AuthSessionManager.userName ?? '';

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(tr('پانێڵەکەم'), style: const TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: tr('نوێکردنەوە'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _welcome(name),
              const SizedBox(height: 18),
              Text(
                tr('شوێنەکانم'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _note(isDark, Icons.wifi_off_rounded, tr('هەڵە لە هێنانی زانیاری'), AppColors.toneRed)
              else if (_places.isEmpty)
                _note(
                  isDark,
                  Icons.link_off_rounded,
                  tr('هیچ شوێنێک بە ئەکاونتەکەتەوە نەبەستراوە. ژمارەی تەلەفۆنی شوێنەکەت دەبێت وەک ژمارەی ئەکاونتەکەت بێت، یان پەیوەندی بە ئەدمینەوە بکە.'),
                  AppColors.toneAmber,
                )
              else
                for (final p in _places) _placeCard(p, isDark),
              const SizedBox(height: 18),
              _moreTile(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome(String name) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF1E3A5F)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? tr('بەخێربێیت') : trf('بەخێربێیت، {0}', [name]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('نرخەکانت بگۆڕە و مێژووی نرخەکانت ببینە'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _placeCard(Map<String, dynamic> p, bool isDark) {
    final k = _kindOf(p);
    final color = switch (k) {
      _Kind.fuel => AppColors.toneAmber,
      _Kind.currency => AppColors.toneTeal,
      _Kind.other => AppColors.toneBlue,
    };
    final icon = switch (k) {
      _Kind.fuel => Icons.local_gas_station_rounded,
      _Kind.currency => Icons.currency_exchange_rounded,
      _Kind.other => Icons.storefront_rounded,
    };
    final kindLabel = switch (k) {
      _Kind.fuel => tr('بەنزینخانە'),
      _Kind.currency => tr('نوسینگەی دراو'),
      _Kind.other => tr('شوێن'),
    };
    final count = _priceCount(p, k);
    final canPrice = k != _Kind.other;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(p['name']?.toString() ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$kindLabel • ${tr(PlaceDisplay.address(p['address']))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (canPrice)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trf('{0} نرخ', [PlaceDisplay.digits(count)]),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                  ),
                ),
            ],
          ),
          if (canPrice) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _open(p, k),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(tr('گۆڕینی نرخ'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _open(p, k),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: Text(tr('مێژووی نرخەکان'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _note(bool isDark, IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  /// هەواڵ و ئەوانی تر — پانێڵی بەڕێوەبردنی پێشوو
  Widget _moreTile(bool isDark) => Material(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const Icon(Icons.dashboard_customize_rounded, color: AppColors.toneSlate),
          title: Text(tr('بەڕێوەبردنی زیاتر'), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(tr('هەواڵ و زانیاری شوێنەکەت')),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          ),
        ),
      );
}
