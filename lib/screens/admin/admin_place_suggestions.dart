// lib/screens/admin/admin_place_suggestions.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/app_settings_service.dart';
import '../../services/places/place_writer.dart';

/// 📥 پێشنیاری شوێنەکانی هاوڵاتیان — چالاک/ناچالاک، پەسەند/ڕەتکردنەوە
class AdminPlaceSuggestionsScreen extends StatefulWidget {
  const AdminPlaceSuggestionsScreen({super.key});

  @override
  State<AdminPlaceSuggestionsScreen> createState() =>
      _AdminPlaceSuggestionsScreenState();
}

class _AdminPlaceSuggestionsScreenState
    extends State<AdminPlaceSuggestionsScreen> {
  SupabaseClient get _db => Supabase.instance.client;

  bool? _enabled;
  bool _toggling = false;
  String _status = 'pending';
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  List<String> _categories = [];
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    AppSettingsService.isOn(AppSettingsService.placeSuggestions, refresh: true)
        .then((v) => mounted ? setState(() => _enabled = v) : null);
    _db.from('main_categories').select('name').order('name').then((res) {
      if (!mounted) return;
      setState(() {
        _categories = {for (final r in res) '${r['name'] ?? ''}'.trim()}
            .where((c) => c.isNotEmpty)
            .toList();
      });
    }).catchError((_) {});
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _db
          .from('place_suggestions')
          .select()
          .eq('status', _status)
          .order('created_at', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rows = [];
        _loading = false;
      });
    }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  Future<void> _toggle(bool on) async {
    setState(() => _toggling = true);
    final ok =
        await AppSettingsService.set(AppSettingsService.placeSuggestions, on);
    if (!mounted) return;
    setState(() {
      _toggling = false;
      if (ok) _enabled = on;
    });
    _snack(
      ok
          ? tr(on ? 'پێشنیاری شوێن چالاک کرا' : 'پێشنیاری شوێن ناچالاک کرا')
          : tr('پاشەکەوتکردن سەرکەوتوو نەبوو، دووبارە هەوڵ بدەرەوە'),
      ok ? AppColors.toneTeal : AppColors.toneRed,
    );
  }

  Future<void> _approve(Map<String, dynamic> s) async {
    final nameCtrl = TextEditingController(text: '${s['name'] ?? ''}');
    String? category =
        _categories.contains(s['category']) ? '${s['category']}' : null;
    bool government = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: AppLang.direction,
          child: AlertDialog(
            title: Text(tr('پەسەندکردنی شوێن')),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: tr('ناوی شوێن'))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('بەش')),
                  items: [
                    for (final c in _categories)
                      DropdownMenuItem(value: c, child: Text(tr(c)))
                  ],
                  onChanged: (v) => setD(() => category = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('حکومی')),
                  value: government,
                  onChanged: (v) => setD(() => government = v),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('پاشگەزبوونەوە'))),
              FilledButton(
                onPressed: category == null || nameCtrl.text.trim().length < 2
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: Text(tr('زیادکردن بۆ ئەپ')),
              ),
            ],
          ),
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || category == null) return;

    final id = (s['id'] as num).toInt();
    setState(() => _busy.add(id));
    try {
      final lat = (s['latitude'] as num).toDouble();
      final lng = (s['longitude'] as num).toDouble();
      final dukanId = await PlaceWriter.insert(PlaceWriter.row(
        name: name,
        category: category!,
        lat: lat,
        lng: lng,
        source: 'suggestion',
        phone: s['phone']?.toString(),
        address: s['address']?.toString(),
        description: s['note']?.toString(),
        government: government,
        neighborhood: await PlaceWriter.neighborhoodOf(lat, lng),
      ));
      await _db.from('place_suggestions').update({
        'status': 'approved',
        'dukan_id': dukanId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      _snack(tr('شوێنەکە زیاد کرا'), AppColors.toneTeal);
      _load();
    } catch (_) {
      _snack(tr('هەڵەیەک ڕوویدا'), AppColors.toneRed);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _reject(Map<String, dynamic> s) async {
    final id = (s['id'] as num).toInt();
    setState(() => _busy.add(id));
    try {
      await _db.from('place_suggestions').update({
        'status': 'rejected',
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      _load();
    } catch (_) {
      _snack(tr('هەڵەیەک ڕوویدا'), AppColors.toneRed);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final hairline =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8EDF3);

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(tr('پێشنیاری شوێنەکان')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
                onPressed: _load, icon: const Icon(Icons.refresh_rounded))
          ],
        ),
        body: Column(
          children: [
            // ── چالاک / ناچالاک ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Material(
                color: card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  secondary: Icon(
                    _enabled == true
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    color: _enabled == true
                        ? AppColors.toneTeal
                        : AppColors.toneSlate,
                    size: 32,
                  ),
                  title: Text(tr('پێشنیاری هاوڵاتیان'),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(tr(_enabled == true
                      ? 'چالاکە — دوگمەی «پێشنیاری شوێن» لە ئەپەکەدا دەردەکەوێت'
                      : 'ناچالاکە — هاوڵاتیان ناتوانن پێشنیار بنێرن')),
                  value: _enabled ?? false,
                  onChanged: _enabled == null || _toggling ? null : _toggle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'pending', label: Text(tr('چاوەڕوان'))),
                  ButtonSegment(
                      value: 'approved', label: Text(tr('پەسەندکراو'))),
                  ButtonSegment(value: 'rejected', label: Text(tr('ڕەتکراوە'))),
                ],
                selected: {_status},
                onSelectionChanged: (v) {
                  setState(() => _status = v.first);
                  _load();
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? Center(child: Text(tr('هیچ پێشنیارێک نییە')))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _tile(_rows[i], card, hairline),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> s, Color card, Color hairline) {
    final id = (s['id'] as num).toInt();
    final busy = _busy.contains(id);
    final lat = (s['latitude'] as num?)?.toDouble();
    final lng = (s['longitude'] as num?)?.toDouble();
    String? txt(String k) {
      final v = '${s[k] ?? ''}'.trim();
      return v.isEmpty ? null : v;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${s['name']}',
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 4),
          if (txt('category') != null) Text('🏷️ ${tr(txt('category')!)}'),
          if (txt('address') != null) Text('📍 ${txt('address')}'),
          if (txt('phone') != null)
            Text('📞 ${txt('phone')}', textDirection: TextDirection.ltr),
          if (txt('note') != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(txt('note')!,
                  style: const TextStyle(color: Color(0xFF64748B))),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (lat != null && lng != null)
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: Text(tr('نەخشە')),
                ),
              const Spacer(),
              if (_status == 'pending') ...[
                TextButton(
                  onPressed: busy ? null : () => _reject(s),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.toneRed),
                  child: Text(tr('ڕەتکردنەوە')),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: busy ? null : () => _approve(s),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(tr('پەسەندکردن')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
