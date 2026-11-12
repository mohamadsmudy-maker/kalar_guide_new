// lib/screens/admin/admin_translations.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/translation_service.dart';

/// 🌍 وەرگێڕانە هاوبەشەکان (خشتەی text_translations)
///
/// Gemini ناوی شوێن، هەواڵ و بەشەکان یەکجار وەردەگێڕێت و لێرە هەڵیان
/// دەگرێت. ئەدمین دەتوانێت وەرگێڕانێکی هەڵە ڕاست بکاتەوە (edited = true،
/// ئیتر Gemini دەستی لێ نادات) یان بیسڕێتەوە بۆ ئەوەی دووبارە وەربگێڕدرێت.
class AdminTranslationsScreen extends StatefulWidget {
  const AdminTranslationsScreen({super.key});

  @override
  State<AdminTranslationsScreen> createState() =>
      _AdminTranslationsScreenState();
}

class _AdminTranslationsScreenState extends State<AdminTranslationsScreen> {
  static const _pageSize = 200;

  final _search = TextEditingController();
  Timer? _debounce;
  String _lang = 'en';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  /// true = لیستی ئەو دەقانەی هێشتا وەرنەگێڕدراون (بۆ نووسینی بە دەست)
  bool _missingMode = false;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_missingMode) {
        final all = await _collectTexts();
        final have = <String>{};
        for (var from = 0;; from += 1000) {
          final page = await _db
              .from('text_translations')
              .select('source')
              .eq('lang', _lang)
              .range(from, from + 999);
          for (final r in page) {
            have.add('${r['source']}'.trim());
          }
          if (page.length < 1000) break;
        }
        final needle = _search.text.trim();
        final missing = all
            .where((t) => !have.contains(t) && AppLang.lookup(_lang, t) == null)
            .where((t) => needle.isEmpty || t.contains(needle))
            .toList()
          ..sort();
        if (!mounted) return;
        setState(() {
          _rows = [
            for (final t in missing)
              {'source': t, 'translation': '', '_new': true}
          ];
          _loading = false;
        });
        return;
      }
      final q = _search.text.trim().replaceAll(RegExp(r'[%,()]'), ' ');
      var query = _db
          .from('text_translations')
          .select('source, source_hash, translation, edited, updated_at')
          .eq('lang', _lang);
      if (q.isNotEmpty) {
        query = query.or('source.ilike.%$q%,translation.ilike.%$q%');
      }
      final res =
          await query.order('updated_at', ascending: false).limit(_pageSize);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(res as List);
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

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _snack(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.toneTeal : AppColors.toneRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final ctrl = TextEditingController(text: '${row['translation'] ?? ''}');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr('ڕاستکردنەوەی وەرگێڕان')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text('${row['source']}',
                        style: const TextStyle(height: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection:
                      _lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
                  child: TextField(
                    controller: ctrl,
                    minLines: 1,
                    maxLines: 6,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: _lang == 'en' ? 'English' : 'العربية',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('پاشگەزبوونەوە'))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(tr('پاشەکەوتکردن')),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (saved == null || saved.isEmpty || saved == row['translation']) return;

    // ➕ وەرگێڕانی نوێ بە دەست (بێ Gemini)
    if (row['_new'] == true) {
      try {
        await _db.from('text_translations').upsert(
          {
            'lang': _lang,
            'source': '${row['source']}',
            'translation': saved,
            'edited': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'lang,source_hash',
        );
        unawaited(TranslationService.syncShared(_lang));
        if (!mounted) return;
        setState(() => _rows.remove(row));
        _snack(tr('پاشەکەوت کرا'));
      } catch (e) {
        _snack('${tr('هەڵەیەک ڕوویدا')}\n$e', ok: false);
      }
      return;
    }

    try {
      final res = await _db
          .from('text_translations')
          .update({
            'translation': saved,
            'edited': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('lang', _lang)
          .eq('source_hash', '${row['source_hash']}')
          .select('source');
      if ((res as List).isEmpty) {
        _snack(tr('ڕێگەت پێنەدراوە'), ok: false);
        return;
      }
      unawaited(TranslationService.syncShared(_lang));
      _snack(tr('پاشەکەوت کرا'));
      _load();
    } catch (e) {
      _snack(tr('هەڵەیەک ڕوویدا'), ok: false);
    }
  }

  /// هەموو ئەو دەقانەی لە داتابەیسەوە دێن و پێویستیان بە وەرگێڕانە
  Future<Set<String>> _collectTexts() async {
    final texts = <String>{};
    Future<void> collect(String table, List<String> cols) async {
      try {
        final rows = await _db.from(table).select(cols.join(', ')).limit(5000);
        for (final r in rows) {
          for (final c in cols) {
            final v = '${r[c] ?? ''}'.trim();
            if (v.isNotEmpty && v != 'null') texts.add(v);
          }
        }
      } catch (_) {}
    }

    await collect('dukan', ['name', 'address', 'category', 'sub_category']);
    await collect('main_categories', ['name']);
    await collect('sub_categories', ['name']);
    await collect('news', ['title']);
    return texts;
  }

  /// هەموو ناوی شوێن، بەش و هەواڵەکان یەکجار وەردەگێڕێت (بە کۆمەڵ، بە
  /// پشوو لە نێوان داواکارییەکاندا بۆ سنووری Gemini ـی بەخۆڕایی). دواتر
  /// هیچ بەکارهێنەرێک چاوەڕێی Gemini ناکات.
  Future<void> _translateAll() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('وەرگێڕانی هەموو شوێنەکان')),
          content: Text(tr(
              'ناوی هەموو شوێن، ناونیشان، بەش و هەواڵەکان بۆ ئینگلیزی و عەرەبی وەردەگێڕدرێن. چەند خولەکێک دەخایەنێت؛ تا تەواو دەبێت ئەم شاشەیە دامەخە.')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('پاشگەزبوونەوە'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('دەستپێکردن'))),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;

    final texts = await _collectTexts();
    texts.removeWhere((t) =>
        AppLang.lookup('en', t) != null); // پێشتر لە ناو ئەپدا وەرگێڕدراون
    if (!mounted) return;

    final progress = ValueNotifier<String>('');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 18),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, v, __) => Text(v),
              ),
            ),
          ]),
        ),
      ),
    );

    var done = 0;
    for (final lang in ['en', 'ar']) {
      done += await TranslationService.translateAllNow(
        texts.toList(),
        lang,
        onProgress: (d, t) =>
            progress.value = '${lang == 'en' ? 'English' : 'العربية'}: $d / $t',
      );
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    final err = TranslationService.lastError;
    if (done == 0 && err != null) {
      // هۆکاری ڕاستەقینە پیشان بدە (بۆ نموونە 429 = سنووری Gemini)
      await showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: AppLang.direction,
          child: AlertDialog(
            title: Text(tr('وەرگێڕان سەرکەوتوو نەبوو')),
            content: Text(
              '${tr(err.contains('429') ? 'سنووری بەخۆڕایی Gemini تەواو بووە. سبەی دووبارە هەوڵ بدەرەوە، یان لە Google AI Studio بیلینگ چالاک بکە.' : err.contains('GEMINI_API_KEY') || err.contains('API key') ? 'کلیلی GEMINI_API_KEY لە Supabase هەڵەیە یان دانەنراوە.' : 'سێرڤەری وەرگێڕان وەڵامی نەدایەوە. لۆگی فەنکشنی translate-text بپشکنە.')}\n\n$err',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: Text(tr('باشە')))
            ],
          ),
        ),
      );
    } else {
      _snack(trf('{0} وەرگێڕانی نوێ پاشەکەوت کرا', [done]));
    }
    _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('سڕینەوەی وەرگێڕان')),
          content: Text(tr('ئەم دەقە جارێکی تر بە Gemini وەردەگێڕدرێتەوە.')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('پاشگەزبوونەوە'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.toneRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _db
          .from('text_translations')
          .delete()
          .eq('lang', _lang)
          .eq('source_hash', '${row['source_hash']}');
      _load();
    } catch (e) {
      _snack(tr('هەڵەیەک ڕوویدا'), ok: false);
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
          title: Text(tr('وەرگێڕانەکان')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: tr('وەرگێڕانی هەموو شوێنەکان'),
              onPressed: _translateAll,
              icon: const Icon(Icons.g_translate_rounded),
            ),
            IconButton(
                onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                ],
                selected: {_lang},
                onSelectionChanged: (v) {
                  setState(() => _lang = v.first);
                  _load();
                },
              ),
            ),
            // وەرگێڕدراو / وەرنەگێڕدراو
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                      value: false,
                      label: Text(tr('وەرگێڕدراو')),
                      icon: const Icon(Icons.check_rounded)),
                  ButtonSegment(
                      value: true,
                      label: Text(tr('وەرنەگێڕدراو')),
                      icon: const Icon(Icons.edit_note_rounded)),
                ],
                showSelectedIcon: false,
                selected: {_missingMode},
                onSelectionChanged: (v) {
                  setState(() => _missingMode = v.first);
                  _load();
                },
              ),
            ),
            if (_missingMode && !_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  trf('{0} دەق ماوە — کرتە لە هەر یەکێک بکە و وەرگێڕانەکەی بنووسە',
                      [_rows.length]),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: tr('گەڕان...'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: card,
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
            Expanded(child: _body(card, hairline)),
          ],
        ),
      ),
    );
  }

  Widget _body(Color card, Color hairline) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr('خشتەی text_translations نەدۆزرایەوە. فایلی 20261112_translations_cache.sql لە Supabase جێبەجێ بکە.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
          child: Text(tr(_missingMode
              ? 'هەموو دەقەکان وەرگێڕدراون ✅'
              : 'هێشتا هیچ وەرگێڕانێک نییە')));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final r = _rows[i];
          final edited = r['edited'] == true;
          return Material(
            color: card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _edit(r),
              onLongPress: r['_new'] == true ? null : () => _delete(r),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['source']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r['_new'] == true
                                ? tr('کرتە بکە بۆ نووسینی وەرگێڕان')
                                : '${r['translation']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: _lang == 'en'
                                ? TextDirection.ltr
                                : TextDirection.rtl,
                            style: const TextStyle(color: AppColors.toneSlate),
                          ),
                        ],
                      ),
                    ),
                    if (edited)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(start: 8),
                        child: Icon(Icons.verified_rounded,
                            color: AppColors.toneTeal, size: 18),
                      ),
                    const Icon(Icons.edit_rounded,
                        color: AppColors.toneSlate, size: 18),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
