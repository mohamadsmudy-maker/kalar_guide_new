// lib/screens/admin/translate_languages_dialog.dart
//
// پێش وەرگێڕان بە Gemini: ئەدمین هەڵدەبژێرێت بۆ کام زمانەکان (سنووری
// بەخۆڕایی Gemini کەمە، بۆیە پێویست ناکات هەمیشە هەر سێ زمانەکە بنێردرێن).

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';

const translateTargets = ['ar', 'en', 'fa'];

/// زمانە هەڵبژێردراوەکان دەگەڕێنێتەوە؛ null = پاشگەزبوونەوە.
/// [filled] = ئەو زمانانەی پێشتر دەقیان هەیە (بە شێوەی بنەڕەت هەڵنابژێردرێن).
Future<Set<String>?> pickTranslateLanguages(BuildContext context, {required Set<String> filled}) =>
    showDialog<Set<String>>(
      context: context,
      builder: (_) => TranslateLanguagesDialog(filled: filled),
    );

class TranslateLanguagesDialog extends StatefulWidget {
  final Set<String> filled;
  const TranslateLanguagesDialog({super.key, required this.filled});

  @override
  State<TranslateLanguagesDialog> createState() => _TranslateLanguagesDialogState();
}

class _TranslateLanguagesDialogState extends State<TranslateLanguagesDialog> {
  late final Set<String> _selected = {
    for (final l in translateTargets)
      if (!widget.filled.contains(l)) l,
  };

  @override
  Widget build(BuildContext context) {
    final replacing = _selected.intersection(widget.filled).isNotEmpty;
    return Directionality(
      textDirection: AppLang.direction,
      child: AlertDialog(
        title: Text(tr('وەرگێڕان بۆ کام زمان؟')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in translateTargets)
              CheckboxListTile(
                key: ValueKey('lang-$l'),
                value: _selected.contains(l),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(AppLang.nativeName(l)),
                subtitle: widget.filled.contains(l) ? Text(tr('دەقی هەیە')) : null,
                onChanged: (v) => setState(() => v == true ? _selected.add(l) : _selected.remove(l)),
              ),
            if (replacing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr('دەقی ئێستای ئەو زمانانە دەگۆڕدرێت.'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB71C1C)),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('پاشگەزبوونەوە'))),
          FilledButton(
            onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, Set<String>.of(_selected)),
            child: Text(tr('وەرگێڕان')),
          ),
        ],
      ),
    );
  }
}
