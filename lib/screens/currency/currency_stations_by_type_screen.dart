import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/settings_provider.dart';
import '../../services/currency_service.dart';
import '../admin/admin_currency_prices.dart';
import 'currency_station_details_screen.dart';
import 'currency_strings.dart';

/// 💱 نوسینگەکانی یەک دراو — ULTRA PRO MAX
///   ڕیزکردن (بۆ کڕین / بۆ فرۆشتن / نوێترین) • گەڕان • جیاوازی لە باشترین نرخ
///   • Realtime • پەیوەندی و هاوبەشکردن • دەستکاری تەنها بۆ خاوەن/ئەدمین
class CurrencyStationsByTypeScreen extends StatefulWidget {
  final String currencyType;

  const CurrencyStationsByTypeScreen({super.key, required this.currencyType});

  @override
  State<CurrencyStationsByTypeScreen> createState() => _CurrencyStationsByTypeScreenState();
}

enum _Sort { sell, buy, recent }

class _CurrencyStationsByTypeScreenState extends State<CurrencyStationsByTypeScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _stations = [];
  _Sort _sort = _Sort.sell;
  String _query = '';

  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = CurrencyService.subscribeToPriceChanges(
      'currency-type-${widget.currencyType}-live',
      () {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) _load(silent: true);
        });
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    CurrencyService.unsubscribe(_channel);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final stations = await CurrencyService.getStationsForType(widget.currencyType);
    if (!mounted) return;
    setState(() {
      _stations = stations;
      _loading = false;
    });
  }

  // ── ڕیزکردن و فلتەر ──
  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    final list = _stations.where((s) {
      if (q.isEmpty) return true;
      return (s['station_name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['station_address'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    double sell(Map m) => (m['sell_price'] as num?)?.toDouble() ?? 0;
    double buy(Map m) => (m['buy_price'] as num?)?.toDouble() ?? 0;
    DateTime at(Map m) => DateTime.tryParse(m['updated_at']?.toString() ?? '') ?? DateTime(2000);

    switch (_sort) {
      case _Sort.sell:
        list.sort((a, b) {
          final sa = sell(a) > 0 ? sell(a) : double.infinity;
          final sb = sell(b) > 0 ? sell(b) : double.infinity;
          return sa.compareTo(sb);
        });
      case _Sort.buy:
        list.sort((a, b) => buy(b).compareTo(buy(a)));
      case _Sort.recent:
        list.sort((a, b) => at(b).compareTo(at(a)));
    }
    return list;
  }

  double? get _bestSell {
    final v = _stations.map((s) => (s['sell_price'] as num?)?.toDouble() ?? 0).where((v) => v > 0);
    return v.isEmpty ? null : v.reduce((a, b) => a < b ? a : b);
  }

  double? get _bestBuy {
    final v = _stations.map((s) => (s['buy_price'] as num?)?.toDouble() ?? 0).where((v) => v > 0);
    return v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
  }

  // ── کردارەکان ──
  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _share(Map<String, dynamic> s, String lang) async {
    String t(String k) => CurrencyStrings.of(lang, k);
    final name = CurrencyService.getNameByLang(widget.currencyType, lang);
    final per = CurrencyService.getQuoteUnit(widget.currencyType);
    final text = StringBuffer()
      ..writeln('💱 $name — ${s['station_name'] ?? ''}')
      ..writeln('${t('sell')}: ${CurrencyService.formatPrice(s['sell_price'] as num?, lang)} ${t('iqd')}')
      ..writeln('${t('buy')}: ${CurrencyService.formatPrice(s['buy_price'] as num?, lang)} ${t('iqd')}')
      ..writeln('${t('per')} $per ${CurrencyService.getUnitName(widget.currencyType, lang)}');
    if ((s['station_phone'] ?? '').toString().isNotEmpty) text.writeln('📞 ${s['station_phone']}');
    text.write('— Kalar Guide');
    await Share.share(text.toString());
  }

  Future<void> _edit(Map<String, dynamic> s) async {
    final id = s['station_id'];
    if (id is! int) return;
    // ✅ ستەیشنی تەواو (لەگەڵ currency_prices) دەنێرین — پێشتر بەتاڵ دەچوو
    final full = await CurrencyService.getStationPrices(id);
    if (!mounted || full == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminCurrencyPricesScreen(station: full)),
    );
    if (mounted) _load(silent: true);
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    String t(String k) => CurrencyStrings.of(lang, k);
    final typeName = CurrencyService.getNameByLang(widget.currencyType, lang);
    final color = CurrencyService.hexToColor(CurrencyService.getColorForType(widget.currencyType));
    final visible = _visible;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text('${CurrencyService.getFlag(widget.currencyType)} ${t('offices_of')} $typeName',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildTopPanel(isDark, lang, color),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: color))
                  : RefreshIndicator(
                      color: color,
                      onRefresh: () => _load(silent: true),
                      child: visible.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [_buildEmpty(isDark, '${t('no_offices')} $typeName')],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: visible.length,
                              itemBuilder: (_, i) => _buildStationCard(visible[i], i, isDark, lang, color),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPanel(bool isDark, String lang, Color color) {
    String t(String k) => CurrencyStrings.of(lang, k);

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
            decoration: BoxDecoration(
              color: active ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: active ? Colors.white : Colors.white60),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

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
              _summaryTile(t('best_sell'), CurrencyService.formatPrice(_bestSell, lang), const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _summaryTile(t('best_buy'), CurrencyService.formatPrice(_bestBuy, lang), const Color(0xFF60A5FA)),
              const SizedBox(width: 8),
              _summaryTile(t('stations'), CurrencyService.localizeDigits('${_stations.length}', lang), Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: t('search'),
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
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                sortChip(_Sort.sell, t('sort_sell'), Icons.shopping_cart_rounded),
                sortChip(_Sort.buy, t('sort_buy'), Icons.sell_rounded),
                sortChip(_Sort.recent, t('sort_recent'), Icons.schedule_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی نوسینگە
  // ═══════════════════════════════════════════════════════════
  Widget _buildStationCard(Map<String, dynamic> s, int index, bool isDark, String lang, Color color) {
    String t(String k) => CurrencyStrings.of(lang, k);
    final name = s['station_name']?.toString() ?? '';
    final address = s['station_address']?.toString() ?? '';
    final logo = s['station_logo']?.toString() ?? '';
    final image = s['station_image']?.toString() ?? '';
    final phone = s['station_phone']?.toString() ?? '';
    final buy = (s['buy_price'] as num?)?.toDouble() ?? 0;
    final sell = (s['sell_price'] as num?)?.toDouble() ?? 0;
    final updatedAt = DateTime.tryParse(s['updated_at']?.toString() ?? '');
    final stale = CurrencyStrings.isStale(updatedAt);
    final canEdit = CurrencyService.canEditStation(stationId: s['station_id'], stationPhone: phone);

    final isBest = _query.isEmpty &&
        _sort != _Sort.recent &&
        index == 0 &&
        ((_sort == _Sort.sell && sell > 0) || (_sort == _Sort.buy && buy > 0));

    // جیاوازی لە باشترین نرخ
    double? diff;
    if (_sort == _Sort.sell && _bestSell != null && sell > 0) diff = sell - _bestSell!;
    if (_sort == _Sort.buy && _bestBuy != null && buy > 0) diff = _bestBuy! - buy;

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
                    MaterialPageRoute(builder: (_) => CurrencyStationDetailsScreen(stationId: s['station_id'] as int)),
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isBest ? best.withValues(alpha: 0.6) : color.withValues(alpha: 0.15),
                width: isBest ? 2 : 1,
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
                                child: Text(name,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (isBest) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: best, borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 11),
                                      const SizedBox(width: 2),
                                      Text(t('best'),
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
                                  child: Text(address,
                                      style: TextStyle(fontSize: 11, color: sub),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
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
                                Text(
                                  CurrencyStrings.timeAgo(updatedAt, lang),
                                  style: TextStyle(fontSize: 10, color: stale ? Colors.orange : sub, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _priceCell(t('sell'), sell, best, lang, highlight: _sort == _Sort.sell)),
                    const SizedBox(width: 8),
                    Expanded(child: _priceCell(t('buy'), buy, const Color(0xFF3B82F6), lang, highlight: _sort == _Sort.buy)),
                  ],
                ),
                if (diff != null && diff > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${CurrencyService.formatPrice(diff, lang)} ${t('iqd')} ${lang == 'en' ? 'from best' : (lang == 'ar' ? 'عن الأفضل' : 'جیاوازی لە باشترین')}',
                      style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (phone.isNotEmpty)
                      Expanded(child: _actionBtn(Icons.call_rounded, t('call'), Colors.green, () => _call(phone))),
                    if (phone.isNotEmpty) const SizedBox(width: 8),
                    Expanded(child: _actionBtn(Icons.share_rounded, t('share'), const Color(0xFF6366F1), () => _share(s, lang))),
                    if (canEdit) ...[
                      const SizedBox(width: 8),
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

  Widget _priceCell(String label, double value, Color c, String lang, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: highlight ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: highlight ? Border.all(color: c.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w800)),
          const Spacer(),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(CurrencyService.formatPrice(value, lang),
                  style: TextStyle(fontSize: 16, color: c, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
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
              child: Text(label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
      child: const Icon(Icons.currency_exchange_rounded, color: Colors.white, size: 24),
    );
  }

  Widget _buildEmpty(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.currency_exchange_outlined, size: 72, color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
