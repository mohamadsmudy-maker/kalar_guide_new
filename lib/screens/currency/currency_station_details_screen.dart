import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import 'currency_history_screen.dart';
import 'currency_strings.dart';
import '../../l10n/tr.dart';

/// 🏢 وردەکاری نوسینگەی دراو — ULTRA PRO MAX
///   🔐 دەستکاری تەنها بۆ ئەدمین یان خاوەنی نوسینگە (پێشتر هەموو کەسێک دەیتوانی)
class CurrencyStationDetailsScreen extends StatefulWidget {
  final int stationId;

  const CurrencyStationDetailsScreen({super.key, required this.stationId});

  @override
  State<CurrencyStationDetailsScreen> createState() => _CurrencyStationDetailsScreenState();
}

class _CurrencyStationDetailsScreenState extends State<CurrencyStationDetailsScreen> {
  Map<String, dynamic>? _station;
  Map<String, dynamic> _prices = {};
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _saving = false;

  bool get _canEdit => CurrencyService.canEditStation(
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
      CurrencyService.getStationPrices(widget.stationId),
      CurrencyService.getStationPriceHistory(stationId: widget.stationId),
    ]);
    if (!mounted) return;
    final station = results[0] as Map<String, dynamic>?;
    setState(() {
      _station = station;
      _prices = (station?['currency_prices'] is Map)
          ? Map<String, dynamic>.from(station!['currency_prices'] as Map)
          : <String, dynamic>{};
      _history = results[1] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  /// دوایین کاتی نوێکردنەوەی دراوێک
  DateTime? _updatedAt(String type) {
    final data = _prices[type];
    final fromJson = data is Map ? DateTime.tryParse(data['updated_at']?.toString() ?? '') : null;
    if (fromJson != null) return fromJson;
    for (final h in _history) {
      if (h['currency_type'] == type) return DateTime.tryParse(h['created_at']?.toString() ?? '');
    }
    return null;
  }

  List<String> get _sortedTypes {
    final keys = _prices.entries
        .where((e) => e.value is Map)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => CurrencyService.getOrder(a).compareTo(CurrencyService.getOrder(b)));
    return keys;
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    String t(String k) => CurrencyStrings.of(lang, k);

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text(tr(_station?['name']?.toString() ?? ''),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
          ],
        ),
        floatingActionButton: (_canEdit && !_loading && _station != null && _missingTypes.isNotEmpty)
            ? FloatingActionButton.extended(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(t('add_price'), style: const TextStyle(fontWeight: FontWeight.w800)),
          onPressed: () => _pickNewType(lang, isDark),
        )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : _station == null
            ? Center(child: Text(t('not_found'), style: const TextStyle(color: Colors.grey)))
            : RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              _buildInfoCard(_station!, lang),
              const SizedBox(height: 22),
              _sectionTitle(t('current_prices'), isDark),
              const SizedBox(height: 12),
              if (_sortedTypes.isEmpty)
                _empty(isDark, Icons.money_off_rounded, t('no_prices'))
              else
                ..._sortedTypes.map((type) => _buildPriceTile(type, isDark, lang)),
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
                      builder: (_) => CurrencyHistoryScreen(
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

  Widget _buildInfoCard(Map<String, dynamic> s, String lang) {
    String t(String k) => CurrencyStrings.of(lang, k);
    final name = s['name']?.toString() ?? '';
    final address = s['address']?.toString() ?? '';
    final phone = s['phone']?.toString() ?? '';
    final logo = (s['logo'] ?? s['image'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF10B981)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: logo.isNotEmpty
                    ? Image.network(logo, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _storeIcon())
                    : _storeIcon(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(tr(name), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              ),
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
              Expanded(child: _whiteBtn(Icons.share_rounded, t('share'), () => _shareAll(lang))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storeIcon() => Container(
    width: 56,
    height: 56,
    color: Colors.white.withValues(alpha: 0.2),
    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
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
              Text(tr(label), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAll(String lang) async {
    String t(String k) => CurrencyStrings.of(lang, k);
    final b = StringBuffer('💱 ${_station?['name'] ?? ''}\n');
    for (final type in _sortedTypes) {
      final d = _prices[type] as Map;
      b.writeln('${CurrencyService.getFlag(type)} ${CurrencyService.getNameByLang(type, lang)}: '
          '${t('sell')} ${CurrencyService.formatPrice(d['sell'] as num?, lang)} • '
          '${t('buy')} ${CurrencyService.formatPrice(d['buy'] as num?, lang)}');
    }
    final phone = _station?['phone']?.toString() ?? '';
    if (phone.isNotEmpty) b.writeln('📞 $phone');
    b.write('— Kalar Guide');
    await Share.share(b.toString());
  }

  Widget _sectionTitle(String title, bool isDark, {Widget? trailing}) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4))),
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
    String t(String k) => CurrencyStrings.of(lang, k);
    final data = _prices[type] as Map;
    final buy = (data['buy'] as num?)?.toDouble() ?? 0;
    final sell = (data['sell'] as num?)?.toDouble() ?? 0;
    final color = CurrencyService.hexToColor(CurrencyService.getColorForType(type));
    final updated = _updatedAt(type);
    final stale = CurrencyStrings.isStale(updated);
    final sub = isDark ? Colors.white54 : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Text(tr(CurrencyService.getSymbol(type)),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${CurrencyService.getFlag(type)} ${CurrencyService.getNameByLang(type, lang)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                    const SizedBox(height: 2),
                    Text(
                      '${t('per')} ${CurrencyService.localizeDigits('${CurrencyService.getQuoteUnit(type)}', lang)} ${CurrencyService.getUnitName(type, lang)}'
                          '${updated != null ? ' • ${CurrencyStrings.timeAgo(updated, lang)}' : ''}',
                      style: TextStyle(fontSize: 10, color: stale ? Colors.orange : sub, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t('history'),
                icon: Icon(Icons.timeline_rounded, color: sub),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CurrencyHistoryScreen(
                      stationId: widget.stationId,
                      stationName: _station?['name']?.toString() ?? '',
                      currencyType: type,
                    ),
                  ),
                ),
              ),
              if (_canEdit)
                IconButton(
                  tooltip: t('edit_price'),
                  icon: Icon(Icons.edit_rounded, color: color),
                  style: IconButton.styleFrom(backgroundColor: color.withValues(alpha: 0.1)),
                  onPressed: () => _showEditSheet(type, buy, sell, lang, isDark),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _priceBox(t('buy'), buy, const Color(0xFF3B82F6), lang)),
              const SizedBox(width: 8),
              Expanded(child: _priceBox(t('sell'), sell, const Color(0xFF10B981), lang)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceBox(String label, double v, Color c, String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(tr(label), style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(tr(CurrencyService.formatPrice(v, lang)), style: TextStyle(fontSize: 18, color: c, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> h, bool isDark, String lang) {
    final type = h['currency_type']?.toString() ?? '';
    final newSell = (h['new_sell_price'] as num?)?.toDouble() ?? 0;
    final newBuy = (h['new_buy_price'] as num?)?.toDouble() ?? 0;
    final oldSell = (h['old_sell_price'] as num?)?.toDouble();
    final at = DateTime.tryParse(h['created_at']?.toString() ?? '')?.toLocal();
    final color = CurrencyService.hexToColor(CurrencyService.getColorForType(type));
    final change = (oldSell != null && oldSell > 0 && newSell > 0) ? newSell - oldSell : 0.0;
    final by = h['updated_by_name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(tr(CurrencyService.getSymbol(type)), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${CurrencyStrings.of(lang, 'sell')} ${CurrencyService.formatPrice(newSell, lang)} • '
                      '${CurrencyStrings.of(lang, 'buy')} ${CurrencyService.formatPrice(newBuy, lang)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (at != null) CurrencyService.localizeDigits(DateFormat('yyyy/MM/dd  HH:mm').format(at), lang),
                    if (by.isNotEmpty) by,
                  ].join(' • '),
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
                    size: 14, color: change > 0 ? Colors.red : Colors.green),
                Text(tr(CurrencyService.formatPrice(change.abs(), lang)),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: change > 0 ? Colors.red : Colors.green)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _empty(bool isDark, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(tr(text), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✏️ دەستکاری
  // ═══════════════════════════════════════════════════════════
  List<String> get _missingTypes => CurrencyService.currencyTypes
      .map((e) => e['key'] as String)
      .where((k) => _prices[k] is! Map)
      .toList();

  Future<void> _pickNewType(String lang, bool isDark) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: _missingTypes
              .map((k) => ListTile(
            leading: Text(tr(CurrencyService.getFlag(k)), style: const TextStyle(fontSize: 22)),
            title: Text(tr(CurrencyService.getNameByLang(k, lang)), style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => Navigator.pop(ctx, k),
          ))
              .toList(),
        ),
      ),
    );
    if (type != null && mounted) _showEditSheet(type, 0, 0, lang, isDark);
  }

  Future<void> _showEditSheet(String type, double buy, double sell, String lang, bool isDark) async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(CurrencyStrings.of(lang, 'no_permission'))), backgroundColor: Colors.orange),
      );
      return;
    }
    String t(String k) => CurrencyStrings.of(lang, k);
    final buyCtrl = TextEditingController(text: buy > 0 ? buy.toStringAsFixed(0) : '');
    final sellCtrl = TextEditingController(text: sell > 0 ? sell.toStringAsFixed(0) : '');
    final notesCtrl = TextEditingController();
    final color = CurrencyService.hexToColor(CurrencyService.getColorForType(type));
    String? error;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          InputDecoration deco(String label, IconData icon, Color c) => InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: c),
            filled: true,
            fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          );

          return Directionality(
            textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${CurrencyService.getFlag(type)}  ${t('edit_price')} — ${CurrencyService.getNameByLang(type, lang)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    '${t('per')} ${CurrencyService.localizeDigits('${CurrencyService.getQuoteUnit(type)}', lang)} ${CurrencyService.getUnitName(type, lang)} (${t('iqd')})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: buyCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: deco(t('buy'), Icons.shopping_cart_rounded, Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sellCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: deco(t('sell'), Icons.sell_rounded, Colors.green),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLength: 120,
                    decoration: deco(t('notes'), Icons.notes_rounded, Colors.grey),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(tr(error!), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(t('cancel'), style: const TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(t('save'), style: const TextStyle(fontWeight: FontWeight.w900)),
                          onPressed: () {
                            final nb = double.tryParse(buyCtrl.text) ?? 0;
                            final ns = double.tryParse(sellCtrl.text) ?? 0;
                            if (nb <= 0 && ns <= 0) {
                              setSheet(() => error = t('invalid'));
                              return;
                            }
                            if (nb > 0 && ns > 0 && nb > ns) {
                              setSheet(() => error = t('buy_gt_sell'));
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final newBuy = double.tryParse(buyCtrl.text) ?? 0;
    final newSell = double.tryParse(sellCtrl.text) ?? 0;
    final notes = notesCtrl.text.trim();
    // دوای تەواوبوونی ئەنیمەیشنی داخستن dispose دەکرێن
    Future.delayed(const Duration(milliseconds: 400), () {
      buyCtrl.dispose();
      sellCtrl.dispose();
      notesCtrl.dispose();
    });
    if (saved != true || !mounted) return;

    setState(() => _saving = true);
    final ok = await CurrencyService.updatePrice(
      stationId: widget.stationId,
      currencyType: type,
      newBuyPrice: newBuy,
      newSellPrice: newSell,
      updatedByName: AuthSessionManager.userName,
      notes: notes.isEmpty ? null : notes,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(ok ? '✅ ${t('saved')}' : t('save_failed'))),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) {
      HapticFeedback.mediumImpact();
      _load();
    }
  }
}