// lib/screens/admin/admin_translations.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/translation_service.dart';

/// 🌍 وەرگێڕانە هاوبەشەکان (خشتەی translations)
///
/// Gemini ناوی شوێن، هەواڵ و بەشەکان یەکجار وەردەگێڕێت و لێرە هەڵیان
/// دەگرێت. ئەدمین دەتوانێت وەرگێڕانێکی هەڵە ڕاست بکاتەوە (edited = true،
/// ئیتر Gemini دەستی لێ نادات) یان بیسڕێتەوە بۆ ئەوەی دووبارە وەربگێڕدرێت.
class AdminTranslationsScreen extends StatefulWidget {
  const AdminTranslationsScreen({super.key});

  @override
  State<AdminTranslationsScreen> createState() => _AdminTranslationsScreenState();
}

class _AdminTranslationsScreenState extends State<AdminTranslationsScreen> {
  static const _pageSize = 200;

  final _search = TextEditingController();
  Timer? _debounce;
  String _lang = 'en';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

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
      final q = _search.text.trim().replaceAll(RegExp(r'[%,()]'), ' ');
      var query = _db
          .from('translations')
          .select('source, source_hash, translation, edited, updated_at')
          .eq('lang', _lang);
      if (q.isNotEmpty) {
        query = query.or('source.ilike.%$q%,translation.ilike.%$q%');
      }
      final res = await query.order('updated_at', ascending: false).limit(_pageSize);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    child: Text('${row['source']}', style: const TextStyle(height: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: _lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
                  child: TextField(
                    controller: ctrl,
                    minLines: 1,
                    maxLines: 6,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: _lang == 'en' ? 'English' : 'العربية',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('پاشگەزبوونەوە'))),
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

    try {
      final res = await _db
          .from('translations')
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

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('سڕینەوەی وەرگێڕان')),
          content: Text(tr('ئەم دەقە جارێکی تر بە Gemini وەردەگێڕدرێتەوە.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('پاشگەزبوونەوە'))),
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
          .from('translations')
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
    final hairline = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8EDF3);

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(tr('وەرگێڕانەکان')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
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
            tr('خشتەی translations نەدۆزرایەوە. فایلی 20261112_translations_cache.sql لە Supabase جێبەجێ بکە.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(child: Text(tr('هێشتا هیچ وەرگێڕانێک نییە')));
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
              onLongPress: () => _delete(r),
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
                            '${r['translation']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection:
                                _lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
                            style: const TextStyle(color: AppColors.toneSlate),
                          ),
                        ],
                      ),
                    ),
                    if (edited)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(start: 8),
                        child: Icon(Icons.verified_rounded, color: AppColors.toneTeal, size: 18),
                      ),
                    const Icon(Icons.edit_rounded, color: AppColors.toneSlate, size: 18),
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
