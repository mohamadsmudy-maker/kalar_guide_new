// lib/screens/admin/admin_osm_import.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/places/osm_import_service.dart';
import '../../services/places/place_writer.dart';

/// 🗺️ هێنانی شوێنەکانی کەلار لە OpenStreetMap — ئەدمین هەڵیاندەبژێرێت
class AdminOsmImportScreen extends StatefulWidget {
  const AdminOsmImportScreen({super.key});

  @override
  State<AdminOsmImportScreen> createState() => _AdminOsmImportScreenState();
}

class _Row {
  _Row(this.place, this.match, this.category) : selected = match == OsmMatch.none && category != null;
  final OsmPlace place;
  final OsmMatch match;
  String? category;
  bool selected;
}

class _AdminOsmImportScreenState extends State<AdminOsmImportScreen> {
  SupabaseClient get _db => Supabase.instance.client;

  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<String> _categories = [];
  List<_Row> _rows = [];
  bool _onlyNew = true;
  int _done = 0;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        Future<Object>.value(_db.from('main_categories').select('name').order('name')),
        Future<Object>.value(_db.from('dukan').select('name, latitude, longitude, external_id')),
        OsmImportService.fetch(),
      ]);
      final cats = {
        for (final r in results[0] as List) '${(r as Map)['name'] ?? ''}'.trim(),
      }..remove('');
      final existing = List<Map<String, dynamic>>.from(results[1] as List);
      final places = results[2] as List<OsmPlace>;
      if (!mounted) return;
      setState(() {
        _categories = cats.toList();
        _rows = [
          for (final p in places)
            _Row(p, OsmImportService.match(p, existing),
                OsmImportService.suggestCategory(p.kind, _categories)),
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<_Row> get _visible =>
      _onlyNew ? _rows.where((r) => r.match != OsmMatch.same).toList() : _rows;

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
    final same = _rows.where((r) => r.match == OsmMatch.same).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  trf('{0} شوێن دۆزرایەوە، {1} پێشتر هەن', [_rows.length, same]),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              FilterChip(
                label: Text(tr('تەنها نوێکان')),
                selected: _onlyNew,
                onSelected: (v) => setState(() => _onlyNew = v),
              ),
            ],
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
                            if (added) _chip(tr('پێشتر زیاد کراوە'), AppColors.toneTeal),
                            if (r.match == OsmMatch.likely)
                              _chip(tr('لەوانەیە پێشتر هەبێت'), AppColors.toneAmber),
                          ]),
                          if (!added) ...[
                            const SizedBox(height: 6),
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

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}
