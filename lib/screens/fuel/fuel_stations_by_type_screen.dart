import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/settings_provider.dart';
import '../../services/currency_service.dart';
import '../../services/fuel_service.dart';
import '../admin/admin_fuel_prices.dart';
import '../currency/currency_strings.dart';
import 'fuel_stations_map_screen.dart';
import 'fuel_strings.dart';
import 'station_details_screen.dart';
import '../../l10n/tr.dart';

/// ⛽ بەنزینخانەکانی یەک جۆر — ULTRA PRO MAX
///   ڕیزکردن (هەرزان / گران / نوێترین) • گەڕان • جیاوازی لە هەرزانترین
///   • Realtime • پەیوەندی، ڕێگا، هاوبەشکردن • دەستکاری تەنها بۆ خاوەن/ئەدمین
class FuelStationsByTypeScreen extends StatefulWidget {
  final String fuelType;

  const FuelStationsByTypeScreen({super.key, required this.fuelType});

  @override
  State<FuelStationsByTypeScreen> createState() => _FuelStationsByTypeScreenState();
}

enum _Sort { cheap, expensive, recent }

class _FuelStationsByTypeScreenState extends State<FuelStationsByTypeScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _stations = [];
  _Sort _sort = _Sort.cheap;
  String _query = '';

  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = FuelService.subscribeToPriceChanges('fuel-type-${widget.fuelType}-live', () {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) _load(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    FuelService.unsubscribe(_channel);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final stations = await FuelService.getStationsForType(widget.fuelType);
    if (!mounted) return;
    setState(() {
      _stations = stations;
      _loading = false;
    });
  }

  double _price(Map m) => (m['price'] as num?)?.toDouble() ?? 0;

  double? get _min {
    final v = _stations.map(_price).where((p) => p > 0);
    return v.isEmpty ? null : v.reduce((a, b) => a < b ? a : b);
  }

  double? get _max {
    final v = _stations.map(_price).where((p) => p > 0);
    return v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
  }

  double? get _avg {
    final v = _stations.map(_price).where((p) => p > 0).toList();
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    final list = _stations.where((s) {
      if (q.isEmpty) return true;
      return (s['station_name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['station_address'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    DateTime at(Map m) => DateTime.tryParse(m['updated_at']?.toString() ?? '') ?? DateTime(2000);

    switch (_sort) {
      case _Sort.cheap:
        list.sort((a, b) => _price(a).compareTo(_price(b)));
      case _Sort.expensive:
        list.sort((a, b) => _price(b).compareTo(_price(a)));
      case _Sort.recent:
        list.sort((a, b) => at(b).compareTo(at(a)));
    }
    return list;
  }

  bool get _hasLocations => _stations.any((s) => _latLng(s) != null);

  static (double, double)? _latLng(Map s) {
    final lat = double.tryParse(s['latitude']?.toString() ?? '');
    final lng = double.tryParse(s['longitude']?.toString() ?? '');
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return (lat, lng);
  }

  // ── کردارەکان ──
  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _directions(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _share(Map<String, dynamic> s, String lang) async {
    String t(String k) => FuelStrings.of(lang, k);
    final unit = FuelService.getUnitName(widget.fuelType, lang);
    final b = StringBuffer()
      ..writeln('⛽ ${FuelService.getNameByLang(widget.fuelType, lang)} — ${s['station_name'] ?? ''}')
      ..writeln('${CurrencyService.formatPrice(_price(s), lang)} ${t('iqd')} / $unit');
    if ((s['station_address'] ?? '').toString().isNotEmpty) b.writeln('📍 ${s['station_address']}');
    if ((s['station_phone'] ?? '').toString().isNotEmpty) b.writeln('📞 ${s['station_phone']}');
    final ll = _latLng(s);
    if (ll != null) b.writeln('🗺️ https://maps.google.com/?q=${ll.$1},${ll.$2}');
    b.write('— Kalar Guide');
    await Share.share(b.toString());
  }

  Future<void> _edit(Map<String, dynamic> s) async {
    final id = s['station_id'];
    if (id is! int) return;
    // ✅ ستەیشنی تەواو (لەگەڵ fuel_prices) — پێشتر بەتاڵ دەنێردرا
    final full = await FuelService.getStationPrices(id);
    if (!mounted || full == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminFuelPricesScreen(station: full)));
    if (mounted) _load(silent: true);
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    String t(String k) => FuelStrings.of(lang, k);
    final typeName = FuelService.getNameByLang(widget.fuelType, lang);
    final color = CurrencyService.hexToColor(FuelService.getColorForType(widget.fuelType));
    final visible = _visible;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text('${FuelService.getEmoji(widget.fuelType)} ${t('stations_of')} $typeName',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (_hasLocations)
              IconButton(
                tooltip: t('map'),
                icon: const Icon(Icons.map_rounded),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FuelStationsMapScreen(fuelType: widget.fuelType)),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            _buildTopPanel(lang, color),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: color))
                  : RefreshIndicator(
                      color: color,
                      onRefresh: () => _load(silent: true),
                      child: visible.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [_buildEmpty(isDark, '${t('no_stations')} $typeName')],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: visible.length,
                              itemBuilder: (_, i) => _buildCard(visible[i], i, isDark, lang, color),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPanel(String lang, Color color) {
    String t(String k) => FuelStrings.of(lang, k);
    String fmt(num? v) => CurrencyService.formatPrice(v, lang);

    Widget sortChip(_Sort s, String label, IconData icon) {
      final active = _sort == s;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _sort = s);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: active ? color : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: active ? Colors.white : Colors.white60),
                const SizedBox(width: 4),
                Text(tr(label),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    Widget tile(String label, String value, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsetsDirectional.only(end: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(label), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(tr(value), style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              tile(t('cheapest'), fmt(_min), const Color(0xFF10B981)),
              tile(t('expensive'), fmt(_max), const Color(0xFFF87171)),
              tile(t('avg'), fmt(_avg), Colors.white),
              tile(t('stations'), CurrencyService.localizeDigits('${_stations.length}', lang), Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: t('search_st'),
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                sortChip(_Sort.cheap, t('sort_cheap'), Icons.trending_down_rounded),
                sortChip(_Sort.expensive, t('sort_exp'), Icons.trending_up_rounded),
                sortChip(_Sort.recent, t('sort_recent'), Icons.schedule_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی بەنزینخانە
  // ═══════════════════════════════════════════════════════════
  Widget _buildCard(Map<String, dynamic> s, int index, bool isDark, String lang, Color color) {
    String t(String k) => FuelStrings.of(lang, k);
    final name = s['station_name']?.toString() ?? '';
    final address = s['station_address']?.toString() ?? '';
    final logo = s['station_logo']?.toString() ?? '';
    final image = s['station_image']?.toString() ?? '';
    final phone = s['station_phone']?.toString() ?? '';
    final price = _price(s);
    final updatedAt = DateTime.tryParse(s['updated_at']?.toString() ?? '');
    final stale = CurrencyStrings.isStale(updatedAt);
    final ll = _latLng(s);
    final canEdit = FuelService.canEditStation(stationId: s['station_id'], stationPhone: phone);
    final min = _min;
    final isCheapest = min != null && price == min;
    final diff = (min != null && price > min) ? price - min : null;
    final unit = FuelService.getUnitName(widget.fuelType, lang);

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final sub = isDark ? Colors.white54 : Colors.grey.shade600;
    const best = Color(0xFF10B981);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: s['station_id'] is int
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StationDetailsScreen(stationId: s['station_id'] as int)),
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCheapest ? best.withValues(alpha: 0.6) : color.withValues(alpha: 0.15),
                width: isCheapest ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (image.isNotEmpty || logo.isNotEmpty)
                          ? Image.network(
                              logo.isNotEmpty ? logo : image,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _defaultIcon(color),
                            )
                          : _defaultIcon(color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(tr(name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
                              ),
                              if (isCheapest) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: best, borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 11),
                                      const SizedBox(width: 2),
                                      Text(t('cheapest'),
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 12, color: sub),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(tr(address),
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: sub)),
                                ),
                              ],
                            ),
                          ],
                          if (updatedAt != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(stale ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                                    size: 12, color: stale ? Colors.orange : sub),
                                const SizedBox(width: 3),
                                Text(tr(CurrencyStrings.timeAgo(updatedAt, lang)),
                                    style: TextStyle(fontSize: 10, color: stale ? Colors.orange : sub, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCheapest ? [best, best.withValues(alpha: 0.8)] : [color, color.withValues(alpha: 0.8)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(tr(CurrencyService.formatPrice(price, lang)),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                        const SizedBox(height: 3),
                        Text('${t('iqd')} / $unit', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sub)),
                      ],
                    ),
                  ],
                ),
                if (diff != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('+${CurrencyService.formatPrice(diff, lang)} ${t('iqd')} ${t('more_than_best')}',
                        style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      Expanded(child: _actionBtn(Icons.call_rounded, t('call'), Colors.green, () => _call(phone))),
                      const SizedBox(width: 6),
                    ],
                    if (ll != null) ...[
                      Expanded(child: _actionBtn(Icons.directions_rounded, t('directions'), const Color(0xFF3B82F6), () => _directions(ll.$1, ll.$2))),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: _actionBtn(Icons.share_rounded, t('share'), const Color(0xFF6366F1), () => _share(s, lang))),
                    if (canEdit) ...[
                      const SizedBox(width: 6),
                      Expanded(child: _actionBtn(Icons.edit_rounded, t('edit_price'), color, () => _edit(s))),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultIcon(Color color) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 24),
    );
  }

  Widget _buildEmpty(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.local_gas_station_outlined, size: 72, color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(tr(text),
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
