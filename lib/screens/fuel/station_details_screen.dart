import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/settings_provider.dart';
import '../../services/currency_service.dart';
import '../../services/fuel_service.dart';
import '../admin/admin_fuel_prices.dart';
import '../currency/currency_strings.dart';
import 'fuel_history_screen.dart';
import 'fuel_strings.dart';
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';

/// 🏢 وردەکاری بەنزینخانە — ULTRA PRO MAX
class StationDetailsScreen extends StatefulWidget {
  final int stationId;

  const StationDetailsScreen({super.key, required this.stationId});

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  Map<String, dynamic>? _station;
  Map<String, dynamic> _prices = {};
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  bool get _canEdit => FuelService.canEditStation(
        stationId: _station?['id'] ?? widget.stationId,
        stationPhone: _station?['phone']?.toString(),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = _station == null);
    final results = await Future.wait([
      FuelService.getStationPrices(widget.stationId),
      FuelService.getStationPriceHistory(stationId: widget.stationId),
    ]);
    if (!mounted) return;
    final station = results[0] as Map<String, dynamic>?;
    setState(() {
      _station = station;
      _prices = station?['fuel_prices'] is Map
          ? Map<String, dynamic>.from(station!['fuel_prices'] as Map)
          : <String, dynamic>{};
      _history = results[1] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  List<String> get _types => _prices.entries
      .where((e) => e.value is num && (e.value as num) > 0)
      .map((e) => e.key)
      .toList()
    ..sort((a, b) => FuelService.getOrder(a).compareTo(FuelService.getOrder(b)));

  DateTime? _updatedAt(String type) {
    for (final h in _history) {
      if (h['fuel_type'] == type) return DateTime.tryParse(h['created_at']?.toString() ?? '');
    }
    return null;
  }

  (double, double)? get _latLng {
    final lat = double.tryParse(_station?['latitude']?.toString() ?? '');
    final lng = double.tryParse(_station?['longitude']?.toString() ?? '');
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return (lat, lng);
  }

  Future<void> _share(String lang) async {
    String t(String k) => FuelStrings.of(lang, k);
    final b = StringBuffer('⛽ ${_station?['name'] ?? ''}\n');
    for (final type in _types) {
      b.writeln('${FuelService.getEmoji(type)} ${FuelService.getNameByLang(type, lang)}: '
          '${CurrencyService.formatPrice(_prices[type] as num?, lang)} ${t('iqd')} / ${FuelService.getUnitName(type, lang)}');
    }
    final phone = _station?['phone']?.toString() ?? '';
    if (phone.isNotEmpty) b.writeln('📞 $phone');
    final ll = _latLng;
    if (ll != null) b.writeln('🗺️ https://maps.google.com/?q=${ll.$1},${ll.$2}');
    b.write('— Kalar Guide');
    await Share.share(b.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    String t(String k) => FuelStrings.of(lang, k);

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text(tr(_station?['name']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (_canEdit && _station != null)
              IconButton(
                tooltip: t('edit_price'),
                icon: const Icon(Icons.edit_rounded),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminFuelPricesScreen(station: _station!)),
                  );
                  if (mounted) _load();
                },
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9822B)))
            : _station == null
                ? Center(child: Text(t('not_found'), style: const TextStyle(color: Colors.grey)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      children: [
                        _buildInfoCard(lang),
                        const SizedBox(height: 22),
                        _sectionTitle(t('current_prices'), isDark),
                        const SizedBox(height: 12),
                        if (_types.isEmpty)
                          _empty(isDark, Icons.money_off_rounded, t('no_prices'))
                        else
                          ..._types.map((type) => _buildPriceTile(type, isDark, lang)),
                        const SizedBox(height: 22),
                        _sectionTitle(
                          t('history'),
                          isDark,
                          trailing: _history.isEmpty
                              ? null
                              : TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FuelHistoryScreen(
                                        stationId: widget.stationId,
                                        stationName: _station?['name']?.toString() ?? '',
                                      ),
                                    ),
                                  ),
                                  child: Text(t('see_all'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                        ),
                        const SizedBox(height: 8),
                        if (_history.isEmpty)
                          _empty(isDark, Icons.history_rounded, t('no_history'))
                        else
                          ..._history.take(10).map((h) => _buildHistoryTile(h, isDark, lang)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildInfoCard(String lang) {
    String t(String k) => FuelStrings.of(lang, k);
    final s = _station!;
    final name = s['name']?.toString() ?? '';
    final address = PlaceDisplay.address(s['address']);
    final phone = s['phone']?.toString() ?? '';
    final logoRaw = s['logo']?.toString() ?? '';
    final logo = logoRaw.isNotEmpty ? logoRaw : (s['image']?.toString() ?? '');
    final ll = _latLng;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD9822B), Color(0xFFD9822B)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFFD9822B).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: logo.isNotEmpty
                    ? Image.network(logo, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _stationIcon())
                    : _stationIcon(),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(tr(name), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(tr(address), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (phone.isNotEmpty) ...[
                Expanded(
                  child: _whiteBtn(Icons.call_rounded, t('call'), () async {
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  }),
                ),
                const SizedBox(width: 8),
              ],
              if (ll != null) ...[
                Expanded(
                  child: _whiteBtn(Icons.directions_rounded, t('directions'), () {
                    launchUrl(
                      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${ll.$1},${ll.$2}'),
                      mode: LaunchMode.externalApplication,
                    );
                  }),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: _whiteBtn(Icons.share_rounded, t('share'), () => _share(lang))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stationIcon() => Container(
        width: 56,
        height: 56,
        color: Colors.white.withValues(alpha: 0.2),
        child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 28),
      );

  Widget _whiteBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(tr(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark, {Widget? trailing}) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFFD9822B), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(tr(title),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildPriceTile(String type, bool isDark, String lang) {
    final price = (_prices[type] as num).toDouble();
    final color = CurrencyService.hexToColor(FuelService.getColorForType(type));
    final updated = _updatedAt(type);
    final stale = CurrencyStrings.isStale(updated);
    final sub = isDark ? Colors.white54 : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(tr(FuelService.getEmoji(type)), style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(FuelService.getNameByLang(type, lang)),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                if (updated != null)
                  Text(tr(CurrencyStrings.timeAgo(updated, lang)),
                      style: TextStyle(fontSize: 10, color: stale ? const Color(0xFFD9822B) : sub, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            tooltip: FuelStrings.of(lang, 'history'),
            icon: Icon(Icons.timeline_rounded, color: sub),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FuelHistoryScreen(
                  stationId: widget.stationId,
                  stationName: _station?['name']?.toString() ?? '',
                  fuelType: type,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tr(CurrencyService.formatPrice(price, lang)), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              Text('${FuelStrings.of(lang, 'iqd')} / ${FuelService.getUnitName(type, lang)}',
                  style: TextStyle(fontSize: 9, color: sub, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> h, bool isDark, String lang) {
    final type = h['fuel_type']?.toString() ?? '';
    final newPrice = (h['new_price'] as num?)?.toDouble() ?? 0;
    final oldPrice = (h['old_price'] as num?)?.toDouble();
    final at = DateTime.tryParse(h['created_at']?.toString() ?? '')?.toLocal();
    final color = CurrencyService.hexToColor(FuelService.getColorForType(type));
    final change = (oldPrice != null && oldPrice > 0 && newPrice > 0) ? newPrice - oldPrice : 0.0;
    final by = h['updated_by_name']?.toString() ?? '';
    String two(int n) => n.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(tr(FuelService.getNameByLang(type, lang)),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(oldPrice != null && oldPrice > 0
                      ? '${CurrencyService.formatPrice(oldPrice, lang)} ← ${CurrencyService.formatPrice(newPrice, lang)}'
                      : CurrencyService.formatPrice(newPrice, lang)),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  tr([
                    if (at != null)
                      CurrencyService.localizeDigits('${at.year}/${two(at.month)}/${two(at.day)}  ${two(at.hour)}:${two(at.minute)}', lang),
                    if (by.isNotEmpty) by,
                  ].join(' • ')),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (change != 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 14, color: change > 0 ? const Color(0xFFDC3545) : const Color(0xFF0F9D7A)),
                Text(tr(CurrencyService.formatPrice(change.abs(), lang)),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: change > 0 ? const Color(0xFFDC3545) : const Color(0xFF0F9D7A))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _empty(bool isDark, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(tr(text), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
