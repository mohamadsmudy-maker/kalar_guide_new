import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/settings_provider.dart';
import '../../services/currency_service.dart';
import '../../services/fuel_pdf_service.dart';
import '../../services/fuel_service.dart';
import '../../widgets/fuel_cost_calculator_card.dart';
import '../../widgets/multi_fuel_chart_widget.dart';
import '../currency/currency_strings.dart';
import 'fuel_comparison_screen.dart';
import 'fuel_stations_by_type_screen.dart';
import 'fuel_stations_map_screen.dart';
import 'fuel_strings.dart';
import 'global_fuel_chart_screen.dart';
import '../../l10n/tr.dart';

/// 🛢️ شاشەی سەرەکی سووتەمەنی — ULTRA PRO MAX
///   • نرخی ڕاستەوخۆ (Realtime) • هەرزانترین/گرانترین/تێکڕا • حیسابکەری تێچوون
///   • نەخشە، بەراورد، چارت، PDF • فلتەری بەنزین/گاز • سێ زمان
class FuelTypesScreen extends StatefulWidget {
  const FuelTypesScreen({super.key});

  @override
  State<FuelTypesScreen> createState() => _FuelTypesScreenState();
}

class _FuelTypesScreenState extends State<FuelTypesScreen> {
  FuelSnapshot? _snapshot;
  bool _loading = true;
  bool _refreshing = false;
  bool _generatingPdf = false;
  String _group = 'all'; // all | fuel | gas

  RealtimeChannel? _channel;
  Timer? _debounce;
  Timer? _ticker;
  bool _liveFlash = false;

  static const Color _dark = Color(0xFF0F172A);
  static const Color _amber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _load();
    _channel = FuelService.subscribeToPriceChanges('fuel-types-live', _onRealtime);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ticker?.cancel();
    FuelService.unsubscribe(_channel);
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
      final snap = await FuelService.getMarketSnapshot(monthsBack: 6);
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      debugPrint('❌ FuelTypes error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _generatePdf(String lang) async {
    if (_snapshot?.history.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(FuelStrings.of(lang, 'no_history'))), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _generatingPdf = true);
    try {
      await FuelPdfService.generateDateRangeReport(
        context: context,
        fromDate: DateTime.now().subtract(const Duration(days: 90)),
        toDate: DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${FuelStrings.of(lang, 'error')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  void _open(Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    String t(String k) => FuelStrings.of(lang, k);

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? _dark : const Color(0xFFF1F5F9),
        body: RefreshIndicator(
          color: _amber,
          onRefresh: () => _load(silent: true),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildAppBar(lang),
              if (_loading)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(children: List.generate(5, (_) => _Skeleton(isDark: isDark))),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(child: _buildQuickActions(isDark, lang)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: FuelCostCalculatorCard(
                      markets: _snapshot?.markets ?? const {},
                      lang: lang,
                      isDark: isDark,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _sectionHeader(t('fuel_types'), isDark, trailing: _buildGroupFilter(isDark, lang)),
                ),
                ..._buildMarketList(isDark, lang),
                SliverToBoxAdapter(child: _sectionHeader(FuelStrings.of(lang, 'chart'), isDark)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: (_snapshot?.history.isNotEmpty ?? false)
                        ? MultiFuelChartWidget(
                            key: ValueKey(_snapshot!.fetchedAt),
                            history: _snapshot!.history,
                            isDark: isDark,
                          )
                        : _empty(isDark, Icons.show_chart_rounded, t('no_history')),
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
  // 🦸 Hero — بەنزینی ئاسایی
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(String lang) {
    String t(String k) => FuelStrings.of(lang, k);
    String fmt(num? v) => CurrencyService.formatPrice(v, lang);
    final m = _snapshot?.markets['normal'];
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
              colors: [Color(0xFF0F172A), Color(0xFF78350F)],
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
                      Text('⛽  ${FuelService.getNameByLang('normal', lang)}',
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
                              tr(fmt(m?.minPrice)),
                              key: ValueKey(m?.minPrice),
                              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (m?.lastChange != null) _ChangeChip(change: m!.lastChange!, lang: lang, onDark: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${t('cheapest')} • ${t('iqd')} / ${FuelService.getUnitName('normal', lang)}'
                    '${m?.cheapest != null ? ' • ${m!.cheapest!['station_name'] ?? ''}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _heroStat(t('expensive'), fmt(m?.maxPrice)),
                      _heroStat(t('avg'), fmt(m?.avg)),
                      _heroStat(t('stations'), CurrencyService.localizeDigits('${m?.stationCount ?? 0}', lang)),
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
  // ⚡ کردارە خێراکان — نەخشە / بەراورد / چارت
  //   (ئەم شاشانە پێشتر هەبوون بەڵام لە هیچ شوێنێکەوە نەدەکرانەوە)
  // ═══════════════════════════════════════════════════════════
  Widget _buildQuickActions(bool isDark, String lang) {
    String t(String k) => FuelStrings.of(lang, k);

    Widget action(IconData icon, String label, Color c, VoidCallback onTap) {
      return Expanded(
        child: Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(icon, color: c, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(tr(label),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(Icons.map_rounded, t('map'), const Color(0xFF10B981), () => _open(const FuelStationsMapScreen(fuelType: 'normal'))),
        const SizedBox(width: 8),
        action(Icons.compare_arrows_rounded, t('compare'), const Color(0xFF6366F1),
            () => _open(FuelComparisonScreen(fuelTypes: FuelService.getFuelTypesForLang(lang)))),
        const SizedBox(width: 8),
        action(Icons.insights_rounded, t('chart'), const Color(0xFF3B82F6), () => _open(const GlobalFuelChartScreen())),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 لیستی جۆرەکان
  // ═══════════════════════════════════════════════════════════
  Widget _buildGroupFilter(bool isDark, String lang) {
    Widget chip(String key, String label) {
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
              color: active ? _amber : (isDark ? Colors.white10 : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? _amber : (isDark ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: Text(tr(label),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                )),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      chip('all', FuelStrings.of(lang, 'all')),
      chip('fuel', FuelStrings.of(lang, 'fuel')),
      chip('gas', FuelStrings.of(lang, 'gas')),
    ]);
  }

  List<Widget> _buildMarketList(bool isDark, String lang) {
    final markets = _snapshot?.markets ?? const <String, FuelMarket>{};
    final types = FuelService.getFuelTypesForLang(lang).where((t) => _group == 'all' || t['group'] == _group).toList()
      ..sort((a, b) {
        final ha = markets[a['key']]?.hasData ?? false;
        final hb = markets[b['key']]?.hasData ?? false;
        if (ha != hb) return ha ? -1 : 1;
        return FuelService.getOrder(a['key']!).compareTo(FuelService.getOrder(b['key']!));
      });

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: types.length,
          itemBuilder: (_, i) => _FuelCard(
            type: types[i],
            market: markets[types[i]['key']],
            lang: lang,
            isDark: isDark,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FuelStationsByTypeScreen(fuelType: types[i]['key']!)),
              );
              if (mounted) _load(silent: true);
            },
          ),
        ),
      ),
    ];
  }

  Widget _sectionHeader(String title, bool isDark, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(4))),
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

  Widget _empty(bool isDark, IconData icon, String text) {
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
// 🎴 کارتی هەر جۆرێک
// ═══════════════════════════════════════════════════════════
class _FuelCard extends StatelessWidget {
  final Map<String, String> type;
  final FuelMarket? market;
  final String lang;
  final bool isDark;
  final VoidCallback onTap;

  const _FuelCard({
    required this.type,
    required this.market,
    required this.lang,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String t(String k) => FuelStrings.of(lang, k);
    String fmt(num? v) => CurrencyService.formatPrice(v, lang);
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
                        child: Text(tr(type['emoji']!), style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(type['name']!),
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
                            const SizedBox(height: 4),
                            Text(
                              tr(hasData
                                  ? '${CurrencyService.localizeDigits('${m!.stationCount}', lang)} ${t('stations')}'
                                      '${m.lastUpdated != null ? ' • ${CurrencyStrings.timeAgo(m.lastUpdated, lang)}' : ''}'
                                  : t('no_prices')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: stale ? Colors.orange : sub, fontWeight: FontWeight.w600),
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
                            label: t('cheapest'),
                            value: fmt(m!.minPrice),
                            station: m.cheapest?['station_name']?.toString(),
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PriceBox(
                            label: t('expensive'),
                            value: fmt(m.maxPrice),
                            station: m.mostExpensive?['station_name']?.toString(),
                            color: const Color(0xFFEF4444),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${t('iqd')} / ${type['unit']} • ${t('avg')} ${fmt(m.avg)}',
                            style: TextStyle(fontSize: 10, color: sub, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (m.saving != null)
                          Text('💰 ${t('saving')} ${fmt(m.saving)}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w800)),
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

  const _PriceBox({required this.label, required this.value, required this.station, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.15 : 0.08), borderRadius: BorderRadius.circular(12)),
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
            Text(tr(station!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  final double change;
  final String lang;
  final bool onDark;

  const _ChangeChip({required this.change, required this.lang, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    if (change == 0) return const SizedBox.shrink();
    final up = change > 0;
    final color = up ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: onDark ? 0.25 : 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: onDark ? Colors.white : color),
          const SizedBox(width: 2),
          Text(tr(CurrencyService.formatPrice(change.abs(), lang)),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: onDark ? Colors.white : color)),
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
        color: flash ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: flash ? Colors.white : const Color(0xFFF59E0B), shape: BoxShape.circle),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
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
