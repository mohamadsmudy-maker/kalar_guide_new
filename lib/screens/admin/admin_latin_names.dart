// lib/screens/admin/admin_latin_names.dart
//
// 🔤 ئەدمین: ئەو شوێنانەی ناویان بە لاتینییە → ناوی کوردی.
// Gemini پێشنیار دەکات، ئەدمین پێداچوونەوە و دەستکاری دەکات، پاشان پاشەکەوت.

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/place_names_service.dart';

const _purple = Color(0xFF7C3AED);

class _Row {
  _Row(this.id, this.name, this.category);
  final Object id;
  final String name;
  final String category;
  final ctrl = TextEditingController();
  bool selected = false;
}

class AdminLatinNamesScreen extends StatefulWidget {
  const AdminLatinNamesScreen({super.key, this.loader, this.suggest, this.rename});

  // بۆ تاقیکردنەوە
  final Future<List<Map<String, dynamic>>> Function()? loader;
  final Future<List<String>> Function(List<String> names)? suggest;
  final Future<void> Function(Object id, String oldName, String newName)? rename;

  @override
  State<AdminLatinNamesScreen> createState() => _AdminLatinNamesScreenState();
}

class _AdminLatinNamesScreenState extends State<AdminLatinNamesScreen> {
  List<_Row>? _rows;
  bool _error = false;
  bool _busy = false;
  static const _batch = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows ?? const <_Row>[]) {
      r.ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final list = await (widget.loader ?? PlaceNamesService.latinPlaces)();
      if (!mounted) return;
      setState(() => _rows = [
            for (final r in list) _Row(r['id'] as Object, '${r['name'] ?? ''}', '${r['category'] ?? ''}'),
          ]);
    } catch (e) {
      debugPrint('⚠️ latin names: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  /// پێشنیار بۆ ئەوانەی هێشتا خانەکەیان بەتاڵە، ٢٠ بە ٢٠
  Future<void> _suggest() async {
    final todo = _rows!.where((r) => r.ctrl.text.trim().isEmpty).take(_batch).toList();
    if (todo.isEmpty) return;
    setState(() => _busy = true);
    try {
      final out = await (widget.suggest ?? PlaceNamesService.suggestKurdish)([for (final r in todo) r.name]);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < todo.length; i++) {
          if (out[i].isNotEmpty && !PlaceNamesService.isLatinName(out[i])) {
            todo[i].ctrl.text = out[i];
            todo[i].selected = true;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${tr('پێشنیار سەرکەوتوو نەبوو. دواتر هەوڵبدەرەوە (سنووری Gemini).')}\n$e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final chosen = _rows!.where((r) => r.selected && r.ctrl.text.trim().isNotEmpty).toList();
    if (chosen.isEmpty) return;
    setState(() => _busy = true);
    final done = <_Row>[];
    for (final r in chosen) {
      try {
        if (widget.rename != null) {
          await widget.rename!(r.id, r.name, r.ctrl.text.trim());
        } else {
          await PlaceNamesService.rename(r.id, oldName: r.name, newName: r.ctrl.text.trim());
        }
        done.add(r);
      } catch (e) {
        debugPrint('⚠️ rename ${r.id}: $e');
      }
    }
    if (widget.rename == null) PlaceNamesService.refreshTranslations();
    if (!mounted) return;
    setState(() {
      _rows!.removeWhere(done.contains);
      _busy = false;
    });
    for (final r in done) {
      r.ctrl.dispose();
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF0F9D7A),
      content: Text(trf('✅ {0} ناو گۆڕدرا', [AppLang.localDigits('${done.length}')])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final selected = rows?.where((r) => r.selected && r.ctrl.text.trim().isNotEmpty).length ?? 0;
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('ناوە لاتینییەکان'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        bottomNavigationBar: rows == null || rows.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('suggest'),
                        onPressed: _busy ? null : _suggest,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(tr('پێشنیاری کوردی (٢٠)')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('save'),
                        onPressed: _busy || selected == 0 ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: _purple),
                        icon: _busy
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded),
                        label: Text(trf('پاشەکەوت ({0})', [AppLang.localDigits('$selected')])),
                      ),
                    ),
                  ]),
                ),
              ),
        body: _error
            ? Center(
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('دووبارە هەوڵبدەرەوە')),
                ),
              )
            : rows == null
                ? const Center(child: CircularProgressIndicator(color: _purple))
                : rows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(tr('✅ هەموو ناوەکان کوردین'),
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return Text(
                              trf('{0} شوێن ناویان بە لاتینییە. «پێشنیاری کوردی» بکە، پێداچوونەوە بکە، پاشان پاشەکەوت. ناوە ئینگلیزییەکە بۆ زمانی ئینگلیزی دەمێنێتەوە.',
                                  [AppLang.localDigits('${rows.length}')]),
                              style: TextStyle(fontSize: 12.5, height: 1.6, color: Colors.grey.shade700),
                            );
                          }
                          final r = rows[i - 1];
                          return Container(
                            key: ValueKey('latin-${r.id}'),
                            padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(children: [
                              Checkbox(
                                value: r.selected,
                                activeColor: _purple,
                                onChanged: (v) => setState(() => r.selected = v ?? false),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(r.name,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                    TextField(
                                      controller: r.ctrl,
                                      onChanged: (v) => setState(() => r.selected = v.trim().isNotEmpty),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: tr('ناوی کوردی'),
                                      ),
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
      ),
    );
  }
}
