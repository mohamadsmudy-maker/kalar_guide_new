import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../models/emergency_service.dart';
import '../../models/event.dart';
import '../../models/neighborhood.dart';
import '../../services/emergency_repository.dart';
import '../../services/event_service.dart';
import '../../services/neighborhood_service.dart';
import '../../services/news_service.dart';
import '../../services/search/global_search.dart';
import '../complaints/complaint_instruction_dialog.dart';
import '../currency/currency_rates_screen.dart';
import '../daily/prayer_times_screen.dart';
import '../daily/qibla_finder_screen.dart';
import '../departments/department_service_details.dart';
import '../departments/department_services_screen.dart';
import '../departments/departments_screen.dart';
import '../emergency/emergency_main_screen.dart';
import '../events/event_details_screen.dart';
import '../events/events_screen.dart';
import '../fuel/fuel_types_screen.dart';
import '../gallery/gallery_screen.dart';
import '../map_screen.dart';
import '../neighborhoods/neighborhood_details_screen.dart';
import '../neighborhoods/neighborhoods_screen.dart';
import '../news/news_details.dart';
import '../stores/store_details_dialog.dart';
import '../stores/suggest_place_screen.dart';
import '../videos/user_videos.dart';
import '../weather/weather_screen.dart';

/// 🔎 گەڕانی گشتی — شوێن، فەرمانگە و مامەڵە، گەڕەک، فریاکەوتن، ڕووداو،
/// هەواڵ و بەشەکانی ئەپ لە یەک شوێن.
class GlobalSearchScreen extends StatefulWidget {
  /// بۆ تێست: داتای ئامادە لەبری Supabase
  final Future<List<SearchItem>> Function()? loader;
  final Future<List<SearchItem>> Function(String query)? newsSearch;

  const GlobalSearchScreen({super.key, this.loader, this.newsSearch});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  static const _recentKey = 'global_search_recent';
  static const _maxPerGroup = 5;

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<SearchItem> _items = [];
  List<SearchItem> _news = [];
  List<String> _recent = [];
  bool _loading = true;
  bool _newsLoading = false;
  bool _loadFailed = false;
  String _query = '';
  SearchKind? _only;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 داتا
  // ═══════════════════════════════════════════════════════════
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final remote = await (widget.loader ?? _loadRemote)();
      if (!mounted) return;
      setState(() {
        _items = [..._sections(), ...remote];
        _loadFailed = remote.isEmpty && widget.loader == null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ search load: $e');
      if (!mounted) return;
      setState(() {
        _items = _sections();
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  /// هەر سەرچاوەیەک جیا — ئەگەر یەکێک شکستی هێنا ئەوانی تر دەمێننەوە
  Future<List<SearchItem>> _loadRemote() async {
    final db = Supabase.instance.client;

    Future<List<SearchItem>> safe(Future<List<SearchItem>> Function() f) async {
      try {
        return await f().timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('⚠️ search source: $e');
        return [];
      }
    }

    final parts = await Future.wait([
      safe(() async {
        final res = await db.from('dukan').select().order('name');
        return [
          for (final p in List<Map<String, dynamic>>.from(res))
            SearchItem(
              kind: SearchKind.place,
              title: '${p['name'] ?? ''}',
              subtitle: [p['category'], p['address']]
                  .map((e) => '${e ?? ''}'.trim())
                  .where((e) => e.isNotEmpty)
                  .join(' • '),
              keywords:
                  '${p['sub_category'] ?? ''} ${p['neighborhood_name'] ?? ''} '
                  '${p['description'] ?? ''} ${p['phone'] ?? ''}',
              data: p,
            ),
        ];
      }),
      safe(() async {
        final deps = List<Map<String, dynamic>>.from(
            await db.from('departments').select());
        final svcs = List<Map<String, dynamic>>.from(
            await db.from('department_services').select());
        final byId = {for (final d in deps) '${d['id']}': d};
        return [
          for (final d in deps)
            SearchItem(
              kind: SearchKind.department,
              title: '${d['name_ku'] ?? ''}',
              subtitle: '${d['address'] ?? ''}',
              keywords: '${d['name_ar'] ?? ''} ${d['name_en'] ?? ''}',
              data: d,
            ),
          for (final s in svcs)
            if (byId['${s['department_id']}'] != null)
              SearchItem(
                kind: SearchKind.transaction,
                title: '${s['title_ku'] ?? ''}',
                subtitle: '${byId['${s['department_id']}']!['name_ku'] ?? ''}',
                keywords: '${s['title_ar'] ?? ''} ${s['title_en'] ?? ''} '
                    '${s['description'] ?? ''} ${s['requirements'] ?? ''}',
                data: (s, byId['${s['department_id']}']!),
              ),
        ];
      }),
      safe(() async => [
            for (final n in await NeighborhoodService.getAll())
              SearchItem(
                kind: SearchKind.neighborhood,
                title: n.getName(AppLang.code),
                keywords: '${n.nameKu} ${n.nameAr ?? ''} ${n.nameEn ?? ''}',
                data: n,
              ),
          ]),
      safe(() async => [
            for (final e in await EmergencyServiceRepository.getAll())
              SearchItem(
                kind: SearchKind.emergency,
                title: e.nameKu,
                subtitle: e.phone,
                keywords: '${e.nameAr ?? ''} ${e.nameEn ?? ''} ${e.category} '
                    '${e.address ?? ''}',
                data: e,
              ),
          ]),
      safe(() async => [
            for (final e in await EventService.getUpcoming(days: 365))
              SearchItem(
                kind: SearchKind.event,
                title: e.titleKu,
                subtitle: e.locationName ?? '',
                keywords: '${e.titleAr ?? ''} ${e.titleEn ?? ''} '
                    '${e.descriptionKu ?? ''}',
                data: e,
              ),
          ]),
    ]);
    return [for (final p in parts) ...p];
  }

  Future<List<SearchItem>> _searchNews(String q) async {
    final rows = await NewsService.searchNews(query: q, from: 0, to: 9);
    return [
      for (final n in rows)
        SearchItem(
          kind: SearchKind.news,
          title: '${n['title'] ?? ''}',
          subtitle: '${n['description'] ?? ''}',
          data: n,
        ),
    ];
  }

  /// بەشەکانی ئەپ — بۆ ئەوەی «نوێژ» یان «بەنزین» ڕاستەوخۆ بدۆزرێتەوە
  List<SearchItem> _sections() {
    SearchItem s(String title, String keywords, Widget Function() screen) =>
        SearchItem(
          kind: SearchKind.section,
          title: title,
          keywords: keywords,
          data: screen,
        );
    return [
      s(tr('نەخشە'), 'map خريطة نەخشەی کەلار', () => const MapScreen()),
      s(tr('گەڕەکان'), 'neighborhoods أحياء گەڕەک',
          () => const NeighborhoodsScreen()),
      s(tr('فەرمانگە و مامەڵەکان'),
          'departments دوائر معاملات فەرمانگە مامەڵە مۆڵەت پێداویستی',
          () => const DepartmentsScreen()),
      s(tr('ڕووداو و بۆنەکان'), 'events فعاليات ڕووداو بۆنە',
          () => const EventsScreen()),
      s(tr('گەلەری'), 'gallery photos صور وێنە', () => const GalleryScreen()),
      s(tr('ڤیدیۆکان'), 'videos فيديو ڤیدیۆ', () => const UserVideosScreen()),
      s(tr('فریاکەوتن'),
          'emergency طوارئ پۆلیس ئاگرکوژێنەوە ئەمبولانس فریاگوزاری',
          () => const EmergencyScreen()),
      s(tr('پێشنیاری شوێن'), 'suggest place اقتراح مكان',
          () => const SuggestPlaceScreen()),
      s(tr('کاتەکانی نوێژ'), 'prayer times صلاة نوێژ بانگ ئەزان',
          () => const PrayerTimesScreen()),
      s(tr('قیبلەنما'), 'qibla قبلة قیبلە', () => const QiblaFinderScreen()),
      s(tr('نرخی سووتەمەنی'), 'fuel وقود بەنزین گاز نەوت بەنزینخانە',
          () => const FuelTypesScreen()),
      s(tr('نرخی دراو'), 'currency عملة دۆلار زێڕ دینار',
          () => const CurrencyRatesScreen()),
      s(tr('کەشوهەوا'), 'weather طقس باران گەرما', () => const WeatherScreen()),
      SearchItem(
        kind: SearchKind.section,
        title: tr('ناردنی سکاڵا'),
        keywords: 'complaint شكوى سکاڵا شارەوانی',
        data: 'complaint',
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // 🕘 گەڕانەکانی پێشوو
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadRecent() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) setState(() => _recent = p.getStringList(_recentKey) ?? []);
    } catch (_) {}
  }

  Future<void> _remember(String q) async {
    final v = q.trim();
    if (v.length < 2) return;
    final list = [v, ..._recent.where((e) => e != v)].take(8).toList();
    setState(() => _recent = list);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_recentKey, list);
    } catch (_) {}
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_recentKey);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // ⌨️ گەڕان
  // ═══════════════════════════════════════════════════════════
  void _onChanged(String v) {
    final q = v.trim();
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _only = null;
        _news = [];
      }
    });
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() => _newsLoading = false);
      return;
    }
    setState(() => _newsLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      List<SearchItem> res = [];
      try {
        res = await (widget.newsSearch ?? _searchNews)(q);
      } catch (_) {}
      if (!mounted || _query != q) return;
      setState(() {
        _news = res;
        _newsLoading = false;
      });
    });
  }

  void _setQuery(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    _onChanged(q);
  }

  Future<void> _open(SearchItem it) async {
    HapticFeedback.selectionClick();
    _focus.unfocus();
    if (_query.isNotEmpty) _remember(_query);

    void push(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    final d = it.data;
    switch (it.kind) {
      case SearchKind.section:
        if (d is Widget Function()) {
          push(d());
        } else {
          ComplaintInstructionDialog.show(context);
        }
      case SearchKind.place:
        StoreDetailsDialog.show(context, d as Map<String, dynamic>);
      case SearchKind.department:
        push(DepartmentServicesScreen(department: d as Map<String, dynamic>));
      case SearchKind.transaction:
        final (s, dep) = d as (Map<String, dynamic>, Map<String, dynamic>);
        push(DepartmentServiceDetailsScreen(service: s, department: dep));
      case SearchKind.neighborhood:
        push(NeighborhoodDetailsScreen(neighborhood: d as Neighborhood));
      case SearchKind.emergency:
        final phone = (d as EmergencyService).phone.trim();
        if (phone.isEmpty) return;
        final uri = Uri(scheme: 'tel', path: phone);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      case SearchKind.event:
        push(EventDetailsScreen(event: d as AppEvent));
      case SearchKind.news:
        push(NewsDetailsScreen(newsItem: d as Map<String, dynamic>));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕواڵەت
  // ═══════════════════════════════════════════════════════════
  static (String, IconData, Color) _meta(SearchKind k) => switch (k) {
        SearchKind.section => (tr('بەشەکانی ئەپ'), Icons.apps_rounded, AppColors.primary),
        SearchKind.place => (tr('شوێنەکان'), Icons.place_rounded, const Color(0xFF0F9D7A)),
        SearchKind.department => (
            tr('فەرمانگەکان'),
            Icons.account_balance_rounded,
            AppColors.primary
          ),
        SearchKind.transaction => (
            tr('مامەڵەکان'),
            Icons.fact_check_rounded,
            const Color(0xFF4F5BD5)
          ),
        SearchKind.neighborhood => (
            tr('گەڕەکان'),
            Icons.location_city_rounded,
            const Color(0xFFD9822B)
          ),
        SearchKind.emergency => (tr('فریاکەوتن'), Icons.emergency_rounded, AppColors.red),
        SearchKind.event => (tr('ڕووداوەکان'), Icons.event_rounded, const Color(0xFF4F5BD5)),
        SearchKind.news => (tr('هەواڵەکان'), Icons.article_rounded, const Color(0xFF0F9D7A)),
      };

  static const _order = [
    SearchKind.section,
    SearchKind.transaction,
    SearchKind.department,
    SearchKind.place,
    SearchKind.neighborhood,
    SearchKind.emergency,
    SearchKind.event,
    SearchKind.news,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF4F6FA);
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final sub = isDark ? Colors.white54 : const Color(0xFF8A90A0);

    final all = _query.isEmpty
        ? const <SearchItem>[]
        : [...GlobalSearch.search(_items, _query), ..._news];
    final counts = GlobalSearch.counts(all);
    final shown =
        _only == null ? all : all.where((e) => e.kind == _only).toList();

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          iconTheme: IconThemeData(color: fg),
          title: Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _remember,
              style: TextStyle(fontSize: 15, color: fg),
              decoration: InputDecoration(
                hintText: tr('گەڕان بۆ شوێن، مامەڵە، گەڕەک...'),
                hintStyle: TextStyle(fontSize: 14, color: sub),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr('سڕینەوە'),
                        icon: Icon(Icons.close_rounded, color: sub, size: 20),
                        onPressed: () => _setQuery(''),
                      ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          bottom: _loading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
        body: _query.isEmpty
            ? _buildStart(isDark, fg, sub)
            : Column(
                children: [
                  if (all.isNotEmpty) _buildChips(counts, all.length, isDark),
                  Expanded(
                    child: shown.isEmpty
                        ? _buildNoResults(fg, sub)
                        : _buildResults(shown, isDark, fg, sub),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── پێش نووسین: گەڕانی پێشوو + بەشەکان ───
  Widget _buildStart(bool isDark, Color fg, Color sub) {
    final sections =
        _items.where((e) => e.kind == SearchKind.section).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (_loadFailed)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD9822B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: Color(0xFFD9822B), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('داتاکان نەهێنران — تەنها بەشەکانی ئەپ دەگەڕێن'),
                    style: TextStyle(fontSize: 12.5, color: fg),
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  child: Text(tr('دووبارە هەوڵبدەوە')),
                ),
              ],
            ),
          ),
        if (_recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: _heading(tr('گەڕانەکانی پێشوو'), sub)),
              TextButton(
                onPressed: _clearRecent,
                child: Text(tr('پاککردنەوە'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _recent)
                ActionChip(
                  avatar: Icon(Icons.history_rounded, size: 16, color: sub),
                  label: Text(r, style: const TextStyle(fontSize: 12.5)),
                  onPressed: () => _setQuery(r),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _heading(tr('خێرا بچۆ بۆ'), sub),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in sections)
              ActionChip(
                label: Text(
                  s.title,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                onPressed: () => _open(s),
              ),
          ],
        ),
      ],
    );
  }

  Widget _heading(String text, Color sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          style:
              TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: sub),
        ),
      );

  // ─── چیپی جۆرەکان بە ژمارەوە ───
  Widget _buildChips(Map<SearchKind, int> counts, int total, bool isDark) {
    Widget chip(String label, int n, SearchKind? kind) {
      final selected = _only == kind;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: GestureDetector(
          onTap: () => setState(() => _only = kind),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$label  $n',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        children: [
          chip(tr('هەموو'), total, null),
          for (final k in _order)
            if ((counts[k] ?? 0) > 0) chip(_meta(k).$1, counts[k]!, k),
        ],
      ),
    );
  }

  // ─── ئەنجامەکان بە گرووپ ───
  Widget _buildResults(
      List<SearchItem> shown, bool isDark, Color fg, Color sub) {
    final children = <Widget>[];
    for (final k in _order) {
      final group = shown.where((e) => e.kind == k).toList();
      if (group.isEmpty) continue;
      final (label, icon, color) = _meta(k);
      final limited =
          _only == null ? group.take(_maxPerGroup).toList() : group;

      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900, color: sub),
              ),
            ),
            if (_only == null && group.length > _maxPerGroup)
              GestureDetector(
                onTap: () => setState(() => _only = k),
                child: Text(
                  trf('هەموو ({0})', [group.length]),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ));
      children.add(Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (var i = 0; i < limited.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : const Color(0xFFEEF0F4),
                  ),
                _row(limited[i], icon, color, isDark, fg, sub),
              ],
            ],
          ),
        ),
      ));
    }
    if (_newsLoading) {
      children.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ));
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: children,
    );
  }

  Widget _row(SearchItem it, IconData icon, Color color, bool isDark,
      Color fg, Color sub) {
    final isCall = it.kind == SearchKind.emergency;
    return InkWell(
      onTap: () => _open(it),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlighted(it.title, fg),
                  if (it.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      it.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: sub),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isCall
                  ? Icons.call_rounded
                  : (AppLang.isRtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded),
              size: isCall ? 20 : 22,
              color: isCall ? AppColors.red : sub,
            ),
          ],
        ),
      ),
    );
  }

  /// ناو، بە ڕەنگکردنی ئەو بەشەی لەگەڵ گەڕانەکە دەگونجێت
  Widget _highlighted(String title, Color fg) {
    final base = TextStyle(
        fontSize: 14, fontWeight: FontWeight.w800, color: fg, height: 1.3);
    final i = title.toLowerCase().indexOf(_query.toLowerCase());
    if (i < 0) {
      return Text(title,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: title.substring(0, i)),
          TextSpan(
            text: title.substring(i, i + _query.length),
            style: const TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: title.substring(i + _query.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildNoResults(Color fg, Color sub) {
    if (_loading || _newsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: sub),
            const SizedBox(height: 12),
            Text(
              tr('هیچ ئەنجامێک نەدۆزرایەوە'),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: fg),
            ),
            const SizedBox(height: 6),
            Text(
              tr('وشەیەکی کورتتر یان جیاواز تاقی بکەرەوە'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: sub),
            ),
          ],
        ),
      ),
    );
  }
}
