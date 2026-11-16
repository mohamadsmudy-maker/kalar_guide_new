// lib/screens/admin/admin_osm_import.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../models/neighborhood.dart';
import '../../services/neighborhood_service.dart';
import '../../services/places/osm_import_filter.dart';
import '../../services/places/osm_import_service.dart';
import '../../services/places/place_writer.dart';
import '../stores/add_store_screen.dart';

/// 🗺️ هێنانی شوێنەکانی کەلار لە OpenStreetMap — ئەدمین هەڵیاندەبژێرێت
class AdminOsmImportScreen extends StatefulWidget {
  const AdminOsmImportScreen({super.key});

  @override
  State<AdminOsmImportScreen> createState() => _AdminOsmImportScreenState();
}

class _AdminOsmImportScreenState extends State<AdminOsmImportScreen> {
  SupabaseClient get _db => Supabase.instance.client;

  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<String> _categories = [];
  List<OsmImportRow> _rows = [];
  OsmImportFilter _f = const OsmImportFilter();
  final TextEditingController _searchCtrl = TextEditingController();
  int _done = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // ١) بەشەکان
    List<String> cats = [];
    try {
      final res = await _db.from('main_categories').select('name').order('name');
      cats = {for (final r in res) '${r['name'] ?? ''}'.trim()}.where((c) => c.isNotEmpty).toList();
    } catch (_) {}

    // ٢) شوێنەکانی ئێستا (بۆ دووبارە نەبوونەوە)
    List<Map<String, dynamic>> existing = [];
    String? schemaNote;
    try {
      existing = List<Map<String, dynamic>>.from(
          await _db.from('dukan').select('name, latitude, longitude, external_id'));
    } catch (e) {
      // ستوونی external_id نییە → 20261115_places_sources.sql جێبەجێ نەکراوە
      schemaNote = tr('فایلی 20261115_places_sources.sql هێشتا لە Supabase جێبەجێ نەکراوە');
      try {
        existing = List<Map<String, dynamic>>.from(
            await _db.from('dukan').select('name, latitude, longitude'));
      } catch (_) {}
    }

    // گەڕەکەکان (بۆ فلتەر؛ ئەگەر نەهاتن، فلتەری گەڕەک دەرناکەوێت)
    List<Neighborhood> hoods = [];
    try {
      hoods = await NeighborhoodService.getAll();
    } catch (_) {}

    // ٣) OpenStreetMap
    List<OsmPlace> places;
    try {
      places = await OsmImportService.fetch();
    } catch (e) {
      if (!mounted) return;
      final msg = '$e';
      setState(() {
        _loading = false;
        _error = msg.length > 300 ? '${msg.substring(0, 300)}…' : msg;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _categories = cats;
      _rows = [
        for (final p in places)
          OsmImportRow(p, OsmImportService.match(p, existing),
              OsmImportService.suggestCategory(p.kind, _categories),
              neighborhood: NeighborhoodService.nameAt(p.lat, p.lng, hoods)),
      ];
      _loading = false;
      _error = schemaNote;
    });
  }

  List<OsmImportRow> get _visible => _f.apply(_rows);

  void _setFilter(OsmImportFilter f) => setState(() => _f = f);

  String _catLabel(String k) => k == OsmImportFilter.none ? tr('بێ بەش') : tr(k);
  String _hoodLabel(String k) =>
      k == OsmImportFilter.none ? tr('دەرەوەی گەڕەکەکان') : tr(k);
  String _kindLabel(String k) => tr(OsmImportService.kindLabel(k));

  /// لیستی هەڵبژاردن لە خوارەوە؛ `null` = هەموو
  Future<void> _pick({
    required String title,
    required List<MapEntry<String, int>> options,
    required String? current,
    required String Function(String) label,
    required void Function(String?) onPicked,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => ListView(
            controller: controller,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              ListTile(
                title: Text(tr('هەموو')),
                trailing: current == null
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final o in options)
                ListTile(
                  title: Text(label(o.key)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${o.value}',
                        style: const TextStyle(color: Color(0xFF94A3B8))),
                    if (current == o.key) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_rounded, color: AppColors.primary),
                    ],
                  ]),
                  onTap: () => Navigator.pop(ctx, o.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    onPicked(picked.isEmpty ? null : picked);
  }

  /// بەشێک بۆ هەموو ئەو شوێنانەی ئێستا پیشان دەدرێن دادەنێت و هەڵیاندەبژێرێت
  Future<void> _setCategoryForVisible(List<OsmImportRow> rows) async {
    await _pick(
      title: tr('دانانی بەش بۆ ئەمانە'),
      options: [for (final c in _categories) MapEntry(c, 0)],
      current: '-',
      label: tr,
      onPicked: (c) {
        if (c == null) return;
        setState(() {
          for (final r in rows) {
            if (r.match == OsmMatch.same) continue;
            r.category = c;
            r.selected = true;
          }
        });
      },
    );
  }

  int get _selectedCount => _rows.where((r) => r.selected && r.category != null).length;

  Future<void> _import() async {
    final todo = _rows.where((r) => r.selected && r.category != null).toList();
    if (todo.isEmpty) return;
    setState(() {
      _saving = true;
      _done = 0;
    });
    var ok = 0, failed = 0;
    for (final r in todo) {
      try {
        final p = r.place;
        await PlaceWriter.insert(PlaceWriter.row(
          name: p.name,
          category: r.category!,
          lat: p.lat,
          lng: p.lng,
          source: 'osm',
          externalId: p.externalId,
          phone: p.phone,
          address: p.address,
          government: p.isGovernment,
          neighborhood: await PlaceWriter.neighborhoodOf(p.lat, p.lng),
        ));
        ok++;
      } on PostgrestException catch (e) {
        // 23505 = پێشتر زیاد کراوە (external_id)
        if (e.code == '23505') {
          ok++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
      if (mounted) setState(() => _done++);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: failed == 0 ? AppColors.toneTeal : AppColors.toneAmber,
      content: Text(trf('{0} شوێن زیاد کرا، {1} سەرکەوتوو نەبوو', [ok, failed])),
    ));
    await _fetch();
  }

  /// شاشەی «زیادکردنی شوێن» بە زانیاری OSM پڕ دەکرێتەوە (وێنە، لۆگۆ، ژێربەش...)
  Future<void> _completeAndAdd(OsmImportRow r) async {
    final p = r.place;
    final id = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddStoreScreen(prefill: {
          'name': p.name,
          'category': r.category,
          'phone': p.phone,
          'address': p.address,
          'latitude': p.lat,
          'longitude': p.lng,
          'type': p.isGovernment ? 'حکومی' : 'ناحکومی',
          'source': 'osm',
          'external_id': p.externalId,
        }),
      ),
    );
    if (id is int && mounted) await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final hairline = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8EDF3);

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(tr('هێنانی شوێن لە OpenStreetMap')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBar: _rows.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _saving || _selectedCount == 0 ? null : _import,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_location_alt_rounded),
                    label: Text(_saving
                        ? trf('زیاد دەکرێت... {0}/{1}', [_done, _selectedCount])
                        : trf('زیادکردنی {0} شوێن', [_selectedCount])),
                  ),
                ),
              ),
        body: _body(card, hairline),
      ),
    );
  }

  Widget _body(Color card, Color hairline) {
    if (_loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(tr('شوێنەکانی کەلار دەهێنرێن... (تا یەک خولەک)')),
        ]),
      );
    }
    if (_rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.travel_explore_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            tr('هەموو ئەو شوێنانەی کەلار کە لە OpenStreetMap هەن دەهێنرێن. پێش زیادکردن خۆت هەڵیاندەبژێریت و بەشەکەیان دیاری دەکەیت. ئەوانەی پێشتر هەن دووبارە نابنەوە.'),
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.7),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(tr('هێنان سەرکەوتوو نەبوو، پەیوەندی ئینتەرنێت بپشکنە و دووبارە هەوڵ بدەرەوە'),
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.toneRed)),
            const SizedBox(height: 6),
            // هۆکاری تەکنیکی — بۆ ناردنی وێنە بۆ گەشەپێدەر
            SelectableText(_error!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.download_rounded),
            label: Text(tr('هێنانی شوێنەکان')),
          ),
          const SizedBox(height: 24),
          const Text('© OpenStreetMap contributors (ODbL)',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      );
    }

    final rows = _visible;
    // ژمارەی هەڵبژێرەکان لەسەر ئەو ڕیزانەیە کە «تەنها نوێکان» دەیانهێڵێتەوە
    final base = OsmImportFilter(onlyNew: _f.onlyNew).apply(_rows);
    final same = _rows.where((r) => r.match == OsmMatch.same).length;
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.toneAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('⚠️ ${_error!}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        // 🔍 گەڕان
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => _setFilter(_f.copyWith(query: v)),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: card,
              hintText: tr('گەڕان بە ناو...'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _f.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _setFilter(_f.copyWith(query: ''));
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hairline),
              ),
            ),
          ),
        ),
        // 🎯 فلتەرەکان
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            children: [
              if (_rows.any((r) => r.neighborhood != null))
                _pickerChip(
                  icon: Icons.location_city_rounded,
                  text: _f.neighborhood == null
                      ? tr('گەڕەک')
                      : _hoodLabel(_f.neighborhood!),
                  active: _f.neighborhood != null,
                  onTap: () => _pick(
                    title: tr('گەڕەک'),
                    options: OsmImportFilter.counts(base, (r) => r.neighborhood),
                    current: _f.neighborhood,
                    label: _hoodLabel,
                    onPicked: (v) => _setFilter(_f.copyWith(neighborhood: () => v)),
                  ),
                ),
              _pickerChip(
                icon: Icons.category_rounded,
                text: _f.category == null ? tr('بەش') : _catLabel(_f.category!),
                active: _f.category != null,
                onTap: () => _pick(
                  title: tr('بەش'),
                  options: OsmImportFilter.counts(base, (r) => r.category),
                  current: _f.category,
                  label: _catLabel,
                  onPicked: (v) => _setFilter(_f.copyWith(category: () => v)),
                ),
              ),
              _pickerChip(
                icon: Icons.sell_rounded,
                text: _f.kind == null ? tr('جۆر') : _kindLabel(_f.kind!),
                active: _f.kind != null,
                onTap: () => _pick(
                  title: tr('جۆر'),
                  options: OsmImportFilter.counts(base, (r) => r.place.kind),
                  current: _f.kind,
                  label: _kindLabel,
                  onPicked: (v) => _setFilter(_f.copyWith(kind: () => v)),
                ),
              ),
              _toggleChip(tr('تەنها نوێکان'), _f.onlyNew,
                  (v) => _setFilter(_f.copyWith(onlyNew: v))),
              _toggleChip(tr('ژمارەی هەیە'), _f.hasPhone,
                  (v) => _setFilter(_f.copyWith(hasPhone: v))),
              _toggleChip(tr('حکومی'), _f.governmentOnly,
                  (v) => _setFilter(_f.copyWith(governmentOnly: v))),
              _toggleChip(tr('هەڵبژێردراوەکان'), _f.selectedOnly,
                  (v) => _setFilter(_f.copyWith(selectedOnly: v))),
            ],
          ),
        ),
        // 📊 ئەنجام + کاری بەکۆمەڵ
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${trf('{0} لە {1} شوێن', [rows.length, _rows.length])} • '
                  '${trf('{0} پێشتر هەن', [same])}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
              if (_f.activeCount > 0)
                TextButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    _setFilter(_f.cleared());
                  },
                  child: Text(tr('پاککردنەوە')),
                ),
              PopupMenuButton<String>(
                enabled: !_saving && rows.isNotEmpty,
                icon: const Icon(Icons.checklist_rounded),
                onSelected: (v) {
                  if (v == 'cat') {
                    _setCategoryForVisible(rows);
                    return;
                  }
                  setState(() {
                    for (final r in rows) {
                      if (r.match == OsmMatch.same) continue;
                      r.selected = v == 'all' && r.category != null;
                    }
                  });
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'all', child: Text(tr('هەڵبژاردنی هەموو ئەمانە'))),
                  PopupMenuItem(value: 'none', child: Text(tr('لابردنی هەڵبژاردنی ئەمانە'))),
                  PopupMenuItem(value: 'cat', child: Text(tr('دانانی بەش بۆ ئەمانە'))),
                ],
              ),
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              tr('هیچ شوێنێک لەگەڵ ئەم فلتەرانە ناگونجێت'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: rows.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == rows.length) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('© OpenStreetMap contributors (ODbL)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                );
              }
              final r = rows[i];
              final added = r.match == OsmMatch.same;
              return Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: hairline),
                ),
                padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: r.selected,
                      onChanged: added || _saving
                          ? null
                          : (v) => setState(() => r.selected = v ?? false),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(r.place.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            _chip(tr(OsmImportService.kindLabel(r.place.kind)), AppColors.toneSlate),
                            if (r.neighborhood != null)
                              _chip('📍 ${tr(r.neighborhood!)}', AppColors.primary),
                            if ((r.place.phone ?? '').trim().isNotEmpty)
                              _chip('📞', AppColors.toneTeal),
                            if (added) _chip(tr('پێشتر زیاد کراوە'), AppColors.toneTeal),
                            if (r.match == OsmMatch.likely)
                              _chip(tr('لەوانەیە پێشتر هەبێت'), AppColors.toneAmber),
                          ]),
                          if (!added) ...[
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: _saving ? null : () => _completeAndAdd(r),
                                icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                                label: Text(tr('تەواوکردن و زیادکردن')),
                              ),
                            ),
                            DropdownButton<String>(
                              isExpanded: true,
                              isDense: true,
                              value: r.category,
                              hint: Text(tr('بەش هەڵبژێرە'),
                                  style: const TextStyle(color: AppColors.toneRed)),
                              items: [
                                for (final c in _categories)
                                  DropdownMenuItem(value: c, child: Text(tr(c))),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() {
                                        r.category = v;
                                        if (v != null) r.selected = true;
                                      }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pickerChip({
    required IconData icon,
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: ActionChip(
          avatar: Icon(icon, size: 16, color: active ? Colors.white : AppColors.primary),
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(text),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: active ? Colors.white : null),
          ]),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : null,
          ),
          backgroundColor: active ? AppColors.primary : null,
          onPressed: onTap,
        ),
      );

  Widget _toggleChip(String text, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: FilterChip(
          label: Text(text),
          selected: value,
          onSelected: onChanged,
        ),
      );

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}
