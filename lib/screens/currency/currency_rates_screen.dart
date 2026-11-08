import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/settings_provider.dart';
import '../../services/currency_pdf_service.dart';
import '../../services/currency_service.dart';
import '../../widgets/currency_converter_card.dart';
import '../../widgets/multi_currency_chart_widget.dart';
import 'currency_stations_by_type_screen.dart';
import 'currency_strings.dart';
import 'global_currency_chart_screen.dart';
import '../../l10n/tr.dart';

/// 💱 شاشەی سەرەکی دراو — ULTRA PRO MAX
///   • نرخی ڕاستەوخۆ (Realtime) • باشترین کڕین و فرۆشتن • گۆڕینەوەی خێرا
///   • فلتەری دراو/زێڕ • چارت • PDF • سێ زمان
class CurrencyRatesScreen extends StatefulWidget {
  const CurrencyRatesScreen({super.key});

  @override
  State<CurrencyRatesScreen> createState() => _CurrencyRatesScreenState();
}

class _CurrencyRatesScreenState extends State<CurrencyRatesScreen> {
  CurrencySnapshot? _snapshot;
  bool _loading = true;
  bool _refreshing = false;
  bool _generatingPdf = false;
  String _group = 'all'; // all | fiat | gold

  RealtimeChannel? _channel;
  Timer? _debounce;
  Timer? _ticker;
  bool _liveFlash = false;

  static const Color _dark = Color(0xFF0F172A);
  static const Color _green = Color(0xFF0F9D7A);

  @override
  void initState() {
    super.initState();
    _load();
    _channel = CurrencyService.subscribeToPriceChanges('currency-rates-live', _onRealtime);
    // «٥ خولەک لەمەوبەر» نوێ دەکاتەوە
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ticker?.cancel();
    CurrencyService.unsubscribe(_channel);
    super.dispose();
  }

  void _onRealtime() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      await _load(silent: true);
      if (!mounted) return;
      setState(() => _liveFlash = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _liveFlash = false);
      });
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        if (_snapshot == null) {
          _loading = true;
        } else {
          _refreshing = true;
        }
      });
    }
    try {
      final snap = await CurrencyService.getMarketSnapshot(monthsBack: 6);
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      debugPrint('❌ CurrencyRates error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _generatePdf(String lang) async {
    final history = _snapshot?.history ?? const [];
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(CurrencyStrings.of(lang, 'no_history'))), backgroundColor: const Color(0xFFD9822B)),
      );
      return;
    }
    setState(() => _generatingPdf = true);
    try {
      await CurrencyPdfService.generateMultiReport(context: context, allHistory: history);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${CurrencyStrings.of(lang, 'error')}: $e'), backgroundColor: const Color(0xFFDC3545)),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
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
        backgroundColor: isDark ? _dark : const Color(0xFFF1F5F9),
        body: RefreshIndicator(
          color: _green,
          onRefresh: () => _load(silent: true),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildAppBar(isDark, lang),
              if (_loading)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: List.generate(5, (_) => _Skeleton(isDark: isDark)),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: CurrencyConverterCard(
                      markets: _snapshot?.markets ?? const {},
                      lang: lang,
                      isDark: isDark,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildSectionHeader(t('markets'), isDark, trailing: _buildGroupFilter(isDark, lang))),
                ..._buildMarketList(isDark, lang),
                SliverToBoxAdapter(child: _buildSectionHeader(t('chart'), isDark)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: (_snapshot?.history.isNotEmpty ?? false)
                        ? MultiCurrencyChartWidget(
                            key: ValueKey(_snapshot!.fetchedAt),
                            history: _snapshot!.history,
                            isDark: isDark,
                          )
                        : _buildEmpty(isDark, Icons.show_chart_rounded, t('no_history')),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🦸 Hero — دۆلار لە سەرەوە
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isDark, String lang) {
    String t(String k) => CurrencyStrings.of(lang, k);
    final usd = _snapshot?.markets['usd'];
    final updated = _snapshot?.lastUpdated;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 285,
      backgroundColor: _dark,
      foregroundColor: Colors.white,
      centerTitle: true,
      title: Text(t('title'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      actions: [
        IconButton(
          tooltip: t('global_chart'),
          icon: const Icon(Icons.insights_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GlobalCurrencyChartScreen()),
          ),
        ),
        IconButton(
          tooltip: t('pdf'),
          icon: _generatingPdf
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_rounded),
          onPressed: _generatingPdf ? null : () => _generatePdf(lang),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF064E3B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text('🇺🇸  ${CurrencyService.getNameByLang('usd', lang)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      _LiveBadge(label: t('live'), flash: _liveFlash || _refreshing),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              tr(CurrencyService.formatPrice(usd?.bestSellPrice, lang)),
                              key: ValueKey(usd?.bestSellPrice),
                              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (usd?.lastChange != null) _ChangeChip(change: usd!.lastChange!, lang: lang, onDark: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${t('best_sell')} • ${t('per')} ${CurrencyService.localizeDigits('${CurrencyService.getQuoteUnit('usd')}', lang)} ${CurrencyService.getUnitName('usd', lang)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _heroStat(t('best_buy'), CurrencyService.formatPrice(usd?.bestBuyPrice, lang)),
                      _heroStat(t('avg'), CurrencyService.formatPrice(usd?.avgSell, lang)),
                      _heroStat(t('stations'), CurrencyService.localizeDigits('${usd?.stationCount ?? 0}', lang)),
                    ],
                  ),
                  if (updated != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text('${t('updated')} ${CurrencyStrings.timeAgo(updated, lang)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(label), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(tr(value), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 لیستی بازاڕ
  // ═══════════════════════════════════════════════════════════
  Widget _buildGroupFilter(bool isDark, String lang) {
    Widget chip(String key) {
      final active = _group == key;
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _group = key);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? _green : (isDark ? Colors.white10 : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? _green : (isDark ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: Text(
              tr(CurrencyStrings.of(lang, key)),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [chip('all'), chip('fiat'), chip('gold')]);
  }

  List<Widget> _buildMarketList(bool isDark, String lang) {
    final types = CurrencyService.getCurrencyTypesForLang(lang).where((t) {
      if (_group == 'all') return true;
      return t['group'] == _group;
    }).toList();

    // ئەوانەی نرخیان هەیە سەرەتا
    final markets = _snapshot?.markets ?? const <String, CurrencyMarket>{};
    types.sort((a, b) {
      final ha = markets[a['key']]?.hasData ?? false;
      final hb = markets[b['key']]?.hasData ?? false;
      if (ha != hb) return ha ? -1 : 1;
      return CurrencyService.getOrder(a['key']!).compareTo(CurrencyService.getOrder(b['key']!));
    });

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: types.length,
          itemBuilder: (_, i) => _MarketCard(
            type: types[i],
            market: markets[types[i]['key']],
            lang: lang,
            isDark: isDark,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CurrencyStationsByTypeScreen(currencyType: types[i]['key']!)),
              );
              if (mounted) _load(silent: true);
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildSectionHeader(String title, bool isDark, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr(title),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(tr(text), style: TextStyle(color: isDark ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎴 کارتی هەر دراوێک
// ═══════════════════════════════════════════════════════════
class _MarketCard extends StatelessWidget {
  final Map<String, String> type;
  final CurrencyMarket? market;
  final String lang;
  final bool isDark;
  final VoidCallback onTap;

  const _MarketCard({
    required this.type,
    required this.market,
    required this.lang,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String t(String k) => CurrencyStrings.of(lang, k);
    final key = type['key']!;
    final color = CurrencyService.hexToColor(type['color']!);
    final m = market;
    final hasData = m?.hasData ?? false;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final sub = isDark ? Colors.white60 : Colors.grey.shade600;
    final stale = CurrencyStrings.isStale(m?.lastUpdated);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: hasData ? 0.25 : 0.1), width: 1.4),
            ),
            child: Opacity(
              opacity: hasData ? 1 : 0.55,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(tr(CurrencyService.getSymbol(key)),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${type['flag']} ${type['name']}',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(
                              tr(hasData
                                  ? '${CurrencyService.localizeDigits('${m!.stationCount}', lang)} ${t('stations')}'
                                      '${m.lastUpdated != null ? ' • ${CurrencyStrings.timeAgo(m.lastUpdated, lang)}' : ''}'
                                  : t('no_prices')),
                              style: TextStyle(fontSize: 11, color: stale ? const Color(0xFFD9822B) : sub, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (m?.lastChange != null) _ChangeChip(change: m!.lastChange!, lang: lang),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          color: isDark ? Colors.white38 : Colors.grey.shade400),
                    ],
                  ),
                  if (hasData) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PriceBox(
                            label: t('best_sell'),
                            value: CurrencyService.formatPrice(m!.bestSellPrice, lang),
                            station: m.bestSell?['station_name']?.toString(),
                            color: const Color(0xFF0F9D7A),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PriceBox(
                            label: t('best_buy'),
                            value: CurrencyService.formatPrice(m.bestBuyPrice, lang),
                            station: m.bestBuy?['station_name']?.toString(),
                            color: const Color(0xFF1E88E5),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${t('per')} ${CurrencyService.localizeDigits('${CurrencyService.getQuoteUnit(key)}', lang)} ${type['unit']}',
                          style: TextStyle(fontSize: 10, color: sub, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (m.spread != null)
                          Text(
                            '${t('spread')}: ${CurrencyService.formatPrice(m.spread, lang)}',
                            style: TextStyle(fontSize: 10, color: sub, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final String value;
  final String? station;
  final Color color;
  final bool isDark;

  const _PriceBox({
    required this.label,
    required this.value,
    required this.station,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(label), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(tr(value), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ),
          if (station != null && station!.isNotEmpty)
            Text(
              tr(station!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

/// ▲ / ▼ دوایین گۆڕانکاری
class _ChangeChip extends StatelessWidget {
  final double change;
  final String lang;
  final bool onDark;

  const _ChangeChip({required this.change, required this.lang, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    if (change == 0) return const SizedBox.shrink();
    final up = change > 0;
    final color = up ? const Color(0xFFDC3545) : const Color(0xFF0F9D7A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: onDark ? Colors.white : color),
          const SizedBox(width: 2),
          Text(
            tr(CurrencyService.formatPrice(change.abs(), lang)),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: onDark ? Colors.white : color),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final String label;
  final bool flash;

  const _LiveBadge({required this.label, required this.flash});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: flash ? const Color(0xFF0F9D7A) : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: flash ? Colors.white : const Color(0xFF0F9D7A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(tr(label), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final bool isDark;
  const _Skeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.white10 : Colors.grey.shade200;
    return Container(
      height: 130,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(15))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 140, color: base),
                const SizedBox(height: 8),
                Container(height: 10, width: 90, color: base),
                const Spacer(),
                Container(height: 36, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
