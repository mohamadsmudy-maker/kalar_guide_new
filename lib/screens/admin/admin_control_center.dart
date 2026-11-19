import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/admin_stats.dart';
import '../../services/app_control.dart';
import '../../utils/place_display.dart';
import 'admin_live_users.dart';

/// 🎛️ ناوەندی کۆنترۆڵی ئەپ — ئامار، کۆنترۆڵ، و دۆخی سیستەم.
class AdminControlCenterScreen extends StatefulWidget {
  /// بۆ تێست: لەبری سێرڤەر
  final Future<AdminStats> Function(int days)? statsLoader;
  final Future<bool> Function(String key, Object value)? saver;
  final Future<Map<String, bool>> Function()? healthLoader;

  const AdminControlCenterScreen({
    super.key,
    this.statsLoader,
    this.saver,
    this.healthLoader,
  });

  @override
  State<AdminControlCenterScreen> createState() => _AdminControlCenterScreenState();
}

class _AdminControlCenterScreenState extends State<AdminControlCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  AdminStats? _shareable;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1B2E) : AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(tr('ناوەندی کۆنترۆڵ'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
          actions: [
            AnimatedBuilder(
              animation: _tabs,
              builder: (_, __) => _tabs.index == 0
                  ? IconButton(
                      tooltip: tr('هاوبەشکردنی ڕاپۆرت'),
                      icon: const Icon(Icons.ios_share_rounded),
                      onPressed: () {
                        final s = _shareable;
                        if (s != null) Share.share(s.summary(tr));
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            tabs: [
              Tab(icon: const Icon(Icons.insights_rounded, size: 20), text: tr('ئامار')),
              Tab(icon: const Icon(Icons.tune_rounded, size: 20), text: tr('کۆنترۆڵ')),
              Tab(icon: const Icon(Icons.monitor_heart_rounded, size: 20), text: tr('سیستەم')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _StatsTab(
              loader: widget.statsLoader ?? AdminStatsService.fetch,
              onLoaded: (s) => _shareable = s,
            ),
            _ControlsTab(saver: widget.saver ?? AppControl.save),
            _SystemTab(healthLoader: widget.healthLoader),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🧱 بەشە هاوبەشەکان
// ═══════════════════════════════════════════════════════════
const _kPeriods = [7, 30, 90];

Color _cardColor(bool d) => d ? AppColors.darkCard : Colors.white;
Color _fg(bool d) => d ? Colors.white : const Color(0xFF1A1A2E);
Color _sub(bool d) => d ? Colors.white54 : const Color(0xFF8A90A0);

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  final String? trailing;
  const _Card({required this.icon, required this.color, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: d ? 0.25 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      // Material: ListTile/Switch ی ناو کارتەکە پێویستیان پێیەتی (inkwell)
      child: Material(
      color: _cardColor(d),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: _fg(d))),
              ),
              if (trailing != null)
                Text(trailing!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _sub(d))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
      ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Text(tr('ئەم بەشە لەم داتابەیسەدا بەردەست نییە'),
        style: TextStyle(fontSize: 12.5, color: _sub(d)));
  }
}

/// دێڕی بار: ناو، بار، ژمارە
class _BarList extends StatelessWidget {
  final List<NamedCount> items;
  final Color color;
  const _BarList({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    if (items.isEmpty) {
      return Text(tr('هیچ داتایەک نییە'), style: TextStyle(fontSize: 12.5, color: _sub(d)));
    }
    final max = items.map((e) => e.n).fold<int>(1, (a, b) => b > a ? b : a);
    return Column(
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(tr(e.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _fg(d))),
                    ),
                    Text(PlaceDisplay.digits(e.n),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: e.n / max,
                    minHeight: 7,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// هێڵی ڕۆژانە بە fl_chart
class _DailyLine extends StatelessWidget {
  final List<DayPoint> points;
  final Color color;
  const _DailyLine({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    if (points.isEmpty) {
      return SizedBox(height: 60, child: Center(child: Text(tr('هیچ داتایەک نییە'), style: TextStyle(color: _sub(d)))));
    }
    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].n.toDouble())];
    final maxY = points.map((e) => e.n).fold<int>(1, (a, b) => b > a ? b : a).toDouble();
    String label(int i) => PlaceDisplay.digits('${points[i].day.day}/${points[i].day.month}');
    final step = (points.length / 4).ceil().clamp(1, 100);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY * 1.25,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY <= 4 ? 1 : null,
              getDrawingHorizontalLine: (_) => FlLine(color: _sub(d).withValues(alpha: 0.15), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, m) => (v == m.max || v != v.roundToDouble())
                      ? const SizedBox.shrink()
                      : Text(PlaceDisplay.digits(v.toInt()), style: TextStyle(fontSize: 10, color: _sub(d))),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: step.toDouble(),
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length || i % step != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label(i), style: TextStyle(fontSize: 10, color: _sub(d))),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${label(s.x.toInt())}\n${PlaceDisplay.digits(s.y.toInt())}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                color: color,
                barWidth: 3,
                dotData: FlDotData(show: points.length <= 10),
                belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📊 تابی ئامار
// ═══════════════════════════════════════════════════════════
class _StatsTab extends StatefulWidget {
  final Future<AdminStats> Function(int days) loader;
  final ValueChanged<AdminStats> onLoaded;
  const _StatsTab({required this.loader, required this.onLoaded});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  int _days = 30;
  bool _loading = true;
  String? _error;
  AdminStats? _s;

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
      final s = await widget.loader(_days);
      if (!mounted) return;
      widget.onLoaded(s);
      setState(() {
        _s = s;
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

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          Row(
            children: [
              for (final p in _kPeriods)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(trf('{0} ڕۆژ', [PlaceDisplay.digits(p)])),
                    selected: _days == p,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: _days == p ? Colors.white : _fg(d)),
                    showCheckmark: false,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _days = p);
                      _load();
                    },
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: tr('نوێکردنەوە'),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_loading && _s == null)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_error != null && _s == null)
            _errorBox(d)
          else if (_s != null) ..._content(_s!, d),
        ],
      ),
    );
  }

  Widget _errorBox(bool d) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 52, color: _sub(d)),
            const SizedBox(height: 12),
            Text(tr('ئامار نەهات'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _fg(d))),
            const SizedBox(height: 6),
            Text(
              '${tr('ئەگەر مایگرەیشنی 20261119_admin_stats.sql جێبەجێ نەکراوە، لە Supabase جێبەجێی بکە')}\n\n$_error',
              textAlign: TextAlign.center,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.5, color: _sub(d)),
            ),
            TextButton.icon(
                onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: Text(tr('دووبارە هەوڵبدەوە'))),
          ],
        ),
      );

  List<Widget> _content(AdminStats s, bool d) {
    final c = s.complaints;
    final u = s.users;
    final p = s.places;
    final se = s.search;
    return [
      // ── KPI ──
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          _Kpi(icon: Icons.assignment_rounded, color: AppColors.red, label: tr('سکاڵای نوێ'), pair: c, upIsGood: false),
          _Kpi(
              icon: Icons.task_alt_rounded,
              color: AppColors.green,
              label: tr('سکاڵای چارەسەرکراو'),
              valueText: s.resolvedRate == null ? '—' : '${PlaceDisplay.digits(s.resolvedRate!.round())}%'),
          _Kpi(icon: Icons.person_add_alt_1_rounded, color: AppColors.primary, label: tr('بەکارهێنەری نوێ'), pair: u),
          _Kpi(icon: Icons.add_business_rounded, color: AppColors.teal, label: tr('شوێنی نوێ'), pair: p),
          _Kpi(icon: Icons.search_rounded, color: AppColors.purple, label: tr('گەڕانەکان'), pair: se),
          _Kpi(
              icon: Icons.podcasts_rounded,
              color: AppColors.orange,
              label: tr('ئێستا ئۆنڵاین'),
              valueText: s.online == null ? '—' : PlaceDisplay.digits(s.online!)),
        ],
      ),
      const SizedBox(height: 14),

      // ── سکاڵاکان ──
      _Card(
        icon: Icons.assignment_rounded,
        color: AppColors.red,
        title: tr('سکاڵاکان'),
        trailing: c == null ? null : trf('{0} چاوەڕوان', [PlaceDisplay.digits(s.pendingComplaints)]),
        child: c == null
            ? const _Unavailable()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DailyLine(points: s.complaintsDaily, color: AppColors.red),
                  const SizedBox(height: 14),
                  _StatusDonut(status: s.complaintStatus),
                  if (s.avgResolutionHours != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      trf('تێکڕای کاتی چارەسەرکردن: {0}', [_hours(s.avgResolutionHours!)]),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _sub(d)),
                    ),
                  ],
                ],
              ),
      ),
      if (c != null) ...[
        _Card(
          icon: Icons.location_city_rounded,
          color: AppColors.orange,
          title: tr('زۆرترین سکاڵا بەپێی گەڕەک'),
          child: _BarList(items: s.topNeighborhoods, color: AppColors.orange),
        ),
        _Card(
          icon: Icons.account_balance_rounded,
          color: AppColors.primary,
          title: tr('زۆرترین سکاڵا بەپێی فەرمانگە'),
          child: _BarList(items: s.topAuthorities, color: AppColors.primary),
        ),
      ],

      // ── بەکارهێنەران ──
      _Card(
        icon: Icons.people_alt_rounded,
        color: AppColors.primary,
        title: tr('بەکارهێنەران'),
        trailing: s.totals == null ? null : trf('{0} کۆی گشتی', [PlaceDisplay.digits(s.totals!['users'] ?? 0)]),
        child: u == null
            ? const _Unavailable()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DailyLine(points: s.usersDaily, color: AppColors.primary),
                  const SizedBox(height: 14),
                  _Sub(tr('بەپێی ڕۆڵ')),
                  _BarList(
                    items: [for (final e in s.byRole.entries) NamedCount(_role(e.key), e.value)],
                    color: AppColors.primary,
                  ),
                  if (s.byLanguage.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _Sub(tr('زمان')),
                    _BarList(
                      items: [for (final e in s.byLanguage.entries) NamedCount(_lang(e.key), e.value)],
                      color: AppColors.teal,
                    ),
                  ],
                  if (s.byPlatform.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _Sub(tr('پلاتفۆرم')),
                    _BarList(
                      items: [for (final e in s.byPlatform.entries) NamedCount(e.key, e.value)],
                      color: AppColors.purple,
                    ),
                  ],
                ],
              ),
      ),

      // ── شوێنەکان ──
      _Card(
        icon: Icons.storefront_rounded,
        color: AppColors.teal,
        title: tr('شوێنەکان'),
        trailing: s.totals == null ? null : trf('{0} کۆی گشتی', [PlaceDisplay.digits(s.totals!['places'] ?? 0)]),
        child: p == null
            ? const _Unavailable()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Sub(tr('بەپێی بەش')),
                  _BarList(items: s.categories, color: AppColors.teal),
                  if (s.topFavorited.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _Sub(tr('زۆرترین دڵخواز')),
                    _BarList(items: s.topFavorited, color: AppColors.pink),
                  ],
                  if (s.topRated.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _Sub(tr('باشترین هەڵسەنگاندن')),
                    _BarList(items: s.topRated, color: AppColors.yellow),
                  ],
                ],
              ),
      ),

      // ── ناوەڕۆک ──
      if (s.hasContent)
        _Card(
          icon: Icons.visibility_rounded,
          color: AppColors.green,
          title: tr('زۆرترین بینراو'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Sub(tr('هەواڵەکان')),
              _BarList(items: s.topNews, color: AppColors.green),
              const SizedBox(height: 6),
              _Sub(tr('ڕووداوەکان')),
              _BarList(items: s.topEvents, color: AppColors.purple),
            ],
          ),
        ),

      // ── گەڕان ──
      _Card(
        icon: Icons.manage_search_rounded,
        color: AppColors.purple,
        title: tr('گەڕانی خەڵک'),
        trailing: se == null ? null : trf('{0} گەڕان', [PlaceDisplay.digits(se.now)]),
        child: se == null
            ? const _Unavailable()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Sub(tr('گەڕانی بێ ئەنجام — ئەمانە شتێکن کە خەڵک دەیانەوێت و لە ئەپەکەدا نییە')),
                  _Chips(items: s.noResults, color: AppColors.red),
                  const SizedBox(height: 12),
                  _Sub(tr('زۆرترین گەڕان')),
                  _Chips(items: s.topQueries, color: AppColors.purple),
                ],
              ),
      ),

      // ── کۆی گشتی ──
      if (s.totals != null)
        _Card(
          icon: Icons.dashboard_rounded,
          color: AppColors.primary,
          title: tr('کۆی گشتی ئەپ'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in const {
                'places': 'شوێن',
                'departments': 'فەرمانگە',
                'news': 'هەواڵ',
                'events': 'ڕووداو',
                'users': 'بەکارهێنەر',
                'complaints': 'سکاڵا',
              }.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${PlaceDisplay.digits(s.totals![e.key] ?? 0)}  ${tr(e.value)}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _fg(d)),
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  static String _hours(double h) {
    if (h < 24) return trf('{0} کاتژمێر', [PlaceDisplay.digits(h.round())]);
    return trf('{0} ڕۆژ', [PlaceDisplay.digits((h / 24).round())]);
  }

  static String _role(String r) => switch (r) {
        'admin' => tr('ئەدمین'),
        'vendor' => tr('خاوەن شوێن'),
        'department' => tr('فەرمانگە'),
        _ => tr('هاوڵاتی'),
      };

  static String _lang(String l) => switch (l) {
        'ku' => tr('کوردی'),
        'ar' => tr('عەرەبی'),
        'en' => tr('ئینگلیزی'),
        'fa' => tr('فارسی'),
        _ => l,
      };
}

class _Sub extends StatelessWidget {
  final String text;
  const _Sub(this.text);
  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _sub(d))),
    );
  }
}

class _Chips extends StatelessWidget {
  final List<NamedCount> items;
  final Color color;
  const _Chips({required this.items, required this.color});
  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    if (items.isEmpty) {
      return Text(tr('هیچ داتایەک نییە'), style: TextStyle(fontSize: 12.5, color: _sub(d)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text('${e.name}  ${PlaceDisplay.digits(e.n)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _fg(d))),
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final StatPair? pair;
  final String? valueText;
  final bool upIsGood;
  const _Kpi({
    required this.icon,
    required this.color,
    required this.label,
    this.pair,
    this.valueText,
    this.upIsGood = true,
  });

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final value = valueText ?? (pair == null ? '—' : PlaceDisplay.digits(pair!.now));
    final pct = pair?.deltaPct;
    Widget? delta;
    if (pair != null && pct != null && pct != 0) {
      final up = pct > 0;
      final good = up == upIsGood;
      final c = good ? AppColors.green : AppColors.red;
      delta = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 11, color: c),
            Text('${PlaceDisplay.digits(pct.abs().round())}%',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: c)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(d),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: d ? 0.25 : 0.05), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              if (delta != null) delta,
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _fg(d))),
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _sub(d))),
        ],
      ),
    );
  }
}

class _StatusDonut extends StatelessWidget {
  final Map<String, int> status;
  const _StatusDonut({required this.status});

  static const _meta = {
    'pending': ('چاوەڕوان', Color(0xFFD9822B)),
    'approved': ('پەسەندکراو', Color(0xFF0F9D7A)),
    'in_progress': ('لە ئارادایە', Color(0xFF0E8C8C)),
    'completed': ('جێبەجێکرا', Color(0xFF1E88E5)),
    'rejected': ('ڕەتکراو', Color(0xFFDC3545)),
  };

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final entries = [for (final e in _meta.entries) if ((status[e.key] ?? 0) > 0) e];
    final total = entries.fold<int>(0, (a, e) => a + (status[e.key] ?? 0));
    if (total == 0) {
      return Text(tr('هیچ سکاڵایەک لەم ماوەیەدا نییە'), style: TextStyle(fontSize: 12.5, color: _sub(d)));
    }
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: (status[e.key] ?? 0).toDouble(),
                      color: e.value.$2,
                      radius: 18,
                      showTitle: false,
                    ),
                ],
              )),
              Text(PlaceDisplay.digits(total),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _fg(d))),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: e.value.$2, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tr(e.value.$1), style: TextStyle(fontSize: 12.5, color: _fg(d)))),
                      Text(PlaceDisplay.digits(status[e.key] ?? 0),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: e.value.$2)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎚️ تابی کۆنترۆڵ
// ═══════════════════════════════════════════════════════════
class _ControlsTab extends StatefulWidget {
  final Future<bool> Function(String key, Object value) saver;
  const _ControlsTab({required this.saver});

  @override
  State<_ControlsTab> createState() => _ControlsTabState();
}

class _ControlsTabState extends State<_ControlsTab> {
  late AppControlState _initial = AppControl.state.value;

  late bool _maint = _initial.maintenance;
  late final _maintMsg = TextEditingController(text: _initial.maintenanceMessage);

  late bool _annOn = _initial.announcementOn;
  late final _annText = TextEditingController(text: _initial.announcementText);
  late AnnounceLevel _annLevel = _initial.announcementLevel;

  late final _minVer = TextEditingController(text: _initial.minVersion);
  late final _updMsg = TextEditingController(text: _initial.updateMessage);
  late final _updUrl = TextEditingController(text: _initial.updateUrl);

  late bool _wasteOnly = _initial.wasteOnlyComplaints;
  late final _wasteAuthority = TextEditingController(text: _initial.wasteAuthority);
  late bool _official = _initial.official;
  late final _officialOrg = TextEditingController(
      text: _initial.officialOrg.isEmpty ? 'شارەوانیی کەلار' : _initial.officialOrg);

  late final Map<String, bool> _features = {
    for (final k in AppControlState.featureKeys) k: _initial.feature(k),
  };

  String? _busy;

  @override
  void initState() {
    super.initState();
    // ئەگەر ڕێکخستنە نوێیەکان لە سێرڤەر هاتن
    AppControl.instance.refresh(force: true).then((_) {
      if (!mounted) return;
      final s = AppControl.state.value;
      setState(() {
        _initial = s;
        _maint = s.maintenance;
        _maintMsg.text = s.maintenanceMessage;
        _annOn = s.announcementOn;
        _annText.text = s.announcementText;
        _annLevel = s.announcementLevel;
        _minVer.text = s.minVersion;
        _updMsg.text = s.updateMessage;
        _updUrl.text = s.updateUrl;
        _wasteOnly = s.wasteOnlyComplaints;
        _wasteAuthority.text = s.wasteAuthority;
        _official = s.official;
        if (s.officialOrg.isNotEmpty) _officialOrg.text = s.officialOrg;
        for (final k in AppControlState.featureKeys) {
          _features[k] = s.feature(k);
        }
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_maintMsg, _annText, _minVer, _updMsg, _updUrl, _officialOrg, _wasteAuthority]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(String id, String key, Object value) async {
    setState(() => _busy = id);
    HapticFeedback.selectionClick();
    final ok = await widget.saver(key, value);
    if (!mounted) return;
    setState(() => _busy = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? tr('✅ پاشەکەوتکرا') : tr('پاشەکەوت نەکرا — تەنها ئەدمین دەتوانێت')),
      backgroundColor: ok ? AppColors.green : AppColors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _Card(
          icon: Icons.construction_rounded,
          color: AppColors.red,
          title: tr('حالەتی چاککردن'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('کاتێک چالاک بێت، هەموو بەکارهێنەران (جگە لە ئەدمین) شاشەی «ئەپەکە لە چاککردندایە» دەبینن.'),
                  style: TextStyle(fontSize: 12, height: 1.5, color: _sub(d))),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('چالاککردن'), style: const TextStyle(fontWeight: FontWeight.w800)),
                value: _maint,
                activeThumbColor: AppColors.red,
                onChanged: (v) => setState(() => _maint = v),
              ),
              _field(tr('پەیام (ئارەزوومەندانە)'), _maintMsg, maxLines: 2),
              _saveBtn('maint', tr('پاشەکەوتکردن'),
                  () => _save('maint', 'maintenance', {'enabled': _maint, 'message': _maintMsg.text.trim()})),
            ],
          ),
        ),
        _Card(
          icon: Icons.campaign_rounded,
          color: AppColors.primary,
          title: tr('ڕاگەیاندن لە لاپەڕەی سەرەکی'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('پیشاندان'), style: const TextStyle(fontWeight: FontWeight.w800)),
                value: _annOn,
                onChanged: (v) => setState(() => _annOn = v),
              ),
              _field(tr('دەقی ڕاگەیاندن'), _annText, maxLines: 3),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final (lv, label) in [
                    (AnnounceLevel.info, 'زانیاری'),
                    (AnnounceLevel.warning, 'ئاگاداری'),
                    (AnnounceLevel.success, 'مژدە'),
                  ])
                    ChoiceChip(
                      label: Text(tr(label)),
                      selected: _annLevel == lv,
                      onSelected: (_) => setState(() => _annLevel = lv),
                    ),
                ],
              ),
              _saveBtn(
                'ann',
                tr('پاشەکەوتکردن'),
                () => _save('ann', 'announcement',
                    {'enabled': _annOn, 'text': _annText.text.trim(), 'level': _annLevel.name}),
              ),
            ],
          ),
        ),
        _Card(
          icon: Icons.system_update_rounded,
          color: AppColors.orange,
          title: tr('داواکردنی نوێکردنەوە'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trf('وەشانی ئێستای ئەپ: {0}. ئەو بەکارهێنەرانەی وەشانیان لەم ژمارەیە کەمترە، تەنها شاشەی نوێکردنەوە دەبینن. بەتاڵ = بێ سنوور.',
                    [AppControl.currentVersion]),
                style: TextStyle(fontSize: 12, height: 1.5, color: _sub(d)),
              ),
              const SizedBox(height: 10),
              _field(tr('کەمترین وەشان (بۆ نموونە 1.2.0)'), _minVer, ltr: true),
              const SizedBox(height: 10),
              _field(tr('پەیام (ئارەزوومەندانە)'), _updMsg, maxLines: 2),
              const SizedBox(height: 10),
              _field(tr('بەستەری نوێکردنەوە (Play Store)'), _updUrl, ltr: true),
              _saveBtn(
                'upd',
                tr('پاشەکەوتکردن'),
                () => _save('upd', 'min_version',
                    {'version': _minVer.text.trim(), 'message': _updMsg.text.trim(), 'url': _updUrl.text.trim()}),
              ),
            ],
          ),
        ),
        _Card(
          icon: Icons.delete_rounded,
          color: const Color(0xFF0F9D7A),
          title: tr('جۆری سکاڵاکان'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('کاتێک چالاکە، هاوڵاتی تەنها سکاڵای خۆڵ و خاشاک دەنێرێت (بە جۆرە وردەکانییەوە). بیکوژێنەوە بۆ گەڕاندنەوەی هەموو جۆرەکانی تر.'),
                style: TextStyle(fontSize: 12, height: 1.5, color: _sub(d)),
              ),
              SwitchListTile(
                key: const ValueKey('waste-only-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('تەنها خۆڵ و خاشاک'), style: const TextStyle(fontWeight: FontWeight.w800)),
                value: _wasteOnly,
                activeThumbColor: const Color(0xFF0F9D7A),
                onChanged: (v) => setState(() => _wasteOnly = v),
              ),
              _field(tr('ناوی لایەنی وەرگر'), _wasteAuthority),
              _saveBtn('waste', tr('پاشەکەوتکردن'),
                  () => _save('waste', 'complaint_mode', {'waste_only': _wasteOnly, 'authority': _wasteAuthority.text.trim()})),
            ],
          ),
        ),
        _Card(
          icon: Icons.verified_rounded,
          color: const Color(0xFF0F9D7A),
          title: tr('ئەپی فەرمی'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('⚠️ تەنها دوای وەرگرتنی نووسراوی فەرمی (بە مۆر و واژۆ) چالاکی بکە. Google Play ئەپێک کە بێ بەڵگە بڵێت فەرمییە ڕەت دەکاتەوە یان لای دەبات.'),
                style: TextStyle(fontSize: 12, height: 1.5, color: _sub(d)),
              ),
              SwitchListTile(
                key: const ValueKey('official-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('ئەپی فەرمییە'), style: const TextStyle(fontWeight: FontWeight.w800)),
                value: _official,
                activeThumbColor: const Color(0xFF0F9D7A),
                onChanged: (v) => setState(() => _official = v),
              ),
              _field(tr('ناوی دامەزراوە (بۆ نموونە: شارەوانیی کەلار)'), _officialOrg),
              _saveBtn('official', tr('پاشەکەوتکردن'),
                  () => _save('official', 'official_status', {'official': _official, 'org': _officialOrg.text.trim()})),
            ],
          ),
        ),
        _Card(
          icon: Icons.toggle_on_rounded,
          color: AppColors.green,
          title: tr('کردنەوە و داخستنی بەشەکان'),
          child: Column(
            children: [
              for (final (key, label, icon) in [
                ('complaints', 'ناردنی سکاڵا', Icons.campaign_rounded),
                ('suggest_place', 'پێشنیاری شوێن', Icons.add_location_alt_rounded),
                ('gallery', 'گەلەری', Icons.photo_library_rounded),
                ('videos', 'ڤیدیۆکان', Icons.play_circle_rounded),
                ('events', 'ڕووداو و بۆنەکان', Icons.event_rounded),
                ('featured_places', 'شوێنی پێشنیارکراو', Icons.star_rounded),
                ('news', 'هەواڵەکان', Icons.newspaper_rounded),
                ('breaking_news', 'هەواڵی بەپەلە', Icons.bolt_rounded),
                ('fuel_prices', 'نرخی سووتەمەنی', Icons.local_gas_station_rounded),
                ('currency_prices', 'نرخی دراو', Icons.currency_exchange_rounded),
                ('pharmacy_duty', 'دەرمانخانەی ئێشکگر', Icons.local_pharmacy_rounded),
                ('departments', 'فەرمانگە و مامەڵەکان', Icons.account_balance_rounded),
                ('emergency', 'فریاکەوتن', Icons.emergency_rounded),
                ('neighborhood_alerts', 'ئاگاداریی گەڕەکەکان', Icons.notifications_active_rounded),
                ('prayer', 'کاتی نوێژ و قیبلە', Icons.mosque_rounded),
                ('weather', 'کەشوهەوا', Icons.cloud_rounded),
                ('waste_schedule', 'کاتی ئۆتۆمبێلی خۆڵ', Icons.local_shipping_rounded),
                ('sponsored_slides', 'سلایدی ڕیکلام', Icons.campaign_rounded),
              ])
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(icon, color: AppColors.green),
                  title: Text(tr(label), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  value: _features[key] ?? true,
                  onChanged: (v) => setState(() => _features[key] = v),
                ),
              _saveBtn('feat', tr('پاشەکەوتکردن'), () async {
                setState(() => _busy = 'feat');
                final messenger = ScaffoldMessenger.of(context);
                final ok = widget.saver == AppControl.save
                    ? await AppControl.saveFeatures(Map.of(_features))
                    : await widget.saver('features', Map.of(_features));
                if (!mounted) return;
                setState(() => _busy = null);
                messenger.showSnackBar(SnackBar(
                  content: Text(ok ? tr('✅ پاشەکەوتکرا') : tr('پاشەکەوت نەکرا — تەنها ئەدمین دەتوانێت')),
                  backgroundColor: ok ? AppColors.green : AppColors.red,
                ));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, {int maxLines = 1, bool ltr = false}) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: c,
      maxLines: maxLines,
      textDirection: ltr ? TextDirection.ltr : null,
      style: TextStyle(fontSize: 13.5, color: _fg(d)),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: d ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _saveBtn(String id, String label, Future<void> Function() onTap) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: _busy == null ? onTap : null,
            icon: _busy == id
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// 🩺 تابی سیستەم: وەشان + پشکنینی مایگرەیشنەکان
// ═══════════════════════════════════════════════════════════
class _SystemTab extends StatefulWidget {
  final Future<Map<String, bool>> Function()? healthLoader;
  const _SystemTab({this.healthLoader});

  @override
  State<_SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<_SystemTab> {
  Map<String, bool>? _health;
  bool _loading = true;

  /// ناوی پشکنین ← فایلی مایگرەیشنی پێویست
  static const Map<String, String> files = {
    'departments.place_id': '20261117_department_places.sql',
    'price_types': '20261118_price_types.sql',
    'app_admin_stats': '20261119_admin_stats.sql',
    'search_logs': '20261119_admin_stats.sql',
    'place_suggestions': '20261115_places_sources.sql',
    'app_settings': '20261115_places_sources.sql',
    'prayer_times_official': '20261110_prayer_times.sql',
    'text_translations': '20261112_translations_cache.sql',
    'dukan.opening_hours': '20261120_presence_and_hours.sql',
    'get_presence_stats': '20261120_presence_and_hours.sql',
  };

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<Map<String, bool>> _defaultHealth() async {
    final db = Supabase.instance.client;
    Future<bool> ok(Future<dynamic> Function() f) async {
      try {
        await f().timeout(const Duration(seconds: 8));
        return true;
      } catch (_) {
        return false;
      }
    }

    final r = await Future.wait([
      ok(() => db.from('departments').select('place_id').limit(1)),
      ok(() => db.from('price_types').select('id').limit(1)),
      ok(() => db.rpc('app_admin_stats', params: {'p_days': 1})),
      ok(() => db.from('search_logs').select('id').limit(1)),
      ok(() => db.from('place_suggestions').select('id').limit(1)),
      ok(() => db.from('app_settings').select('key').limit(1)),
      ok(() => db.from('prayer_times_official').select('day_month').limit(1)),
      ok(() => db.from('text_translations').select('*').limit(1)),
      ok(() => db.from('dukan').select('opening_hours').limit(1)),
      ok(() => db.rpc('get_presence_stats')),
    ]);
    return {for (var i = 0; i < files.length; i++) files.keys.elementAt(i): r[i]};
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final h = await (widget.healthLoader ?? _defaultHealth)();
    if (!mounted) return;
    setState(() {
      _health = h;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final missing = {
      for (final e in (_health ?? {}).entries)
        if (!e.value && (files[e.key] ?? '').isNotEmpty) files[e.key]!,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _Card(
          icon: Icons.info_rounded,
          color: AppColors.primary,
          title: tr('ئەپەکە'),
          child: Row(
            children: [
              Expanded(
                child: Text(trf('وەشان {0}', [AppControl.currentVersion]),
                    style: TextStyle(fontWeight: FontWeight.w800, color: _fg(d))),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const AdminLiveUsersScreen())),
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: Text(tr('بەکارهێنەرانی چالاک')),
              ),
            ],
          ),
        ),
        _Card(
          icon: Icons.monitor_heart_rounded,
          color: AppColors.green,
          title: tr('پشکنینی داتابەیس'),
          trailing: _loading ? null : (missing.isEmpty ? tr('هەموو باشە') : trf('{0} فایل ماوە', [PlaceDisplay.digits(missing.length)])),
          child: _loading
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in (_health ?? {}).entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(e.value ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                size: 20, color: e.value ? AppColors.green : AppColors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(e.key,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _fg(d))),
                            ),
                            if (!e.value && (files[e.key] ?? '').isNotEmpty)
                              Flexible(
                                child: Text(files[e.key]!,
                                    textDirection: TextDirection.ltr,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.red)),
                              ),
                          ],
                        ),
                      ),
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${tr('ئەم فایلانە لە Supabase جێبەجێ بکە (SQL Editor):')}\n${missing.join('\n')}',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(fontSize: 11.5, height: 1.6, color: _sub(d)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                        onPressed: _run, icon: const Icon(Icons.refresh_rounded), label: Text(tr('دووبارە بپشکنە'))),
                  ],
                ),
        ),
      ],
    );
  }
}
