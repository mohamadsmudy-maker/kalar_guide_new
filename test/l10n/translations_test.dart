// test/l10n/translations_test.dart
//
// هەموو tr('...') و trf('...') ی ناو lib/ دەبێت وەرگێڕانی ئینگلیزی و
// عەرەبییان هەبێت. ئەگەر دەقێکی نوێت زیاد کرد، لە
// lib/l10n/strings/strings_en.dart و strings_ar.dart زیادی بکە.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/l10n/strings/strings_ar.dart';
import 'package:kalar_guide_new/l10n/strings/strings_en.dart';
import 'package:kalar_guide_new/l10n/tr.dart';

String _unescape(String s) => s.replaceAllMapped(
      RegExp(r'\\(.)'),
      (m) => switch (m[1]) { 'n' => '\n', 't' => '\t', _ => m[1]! },
    );

Set<String> _sourceKeys() {
  final re = RegExp(r'''\btrf?\(\s*(?:'((?:\\.|[^'\\\n])*)'|"((?:\\.|[^"\\\n])*)")''');
  final keys = <String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains('l10n')) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      keys.add(_unescape(m[1] ?? m[2]!));
    }
  }
  return keys;
}

void main() {
  final keys = _sourceKeys();

  test('دەقەکانی ئەپ دۆزرانەوە', () => expect(keys.length, greaterThan(800)));

  for (final (name, table) in [('English', stringsEn), ('Arabic', stringsAr)]) {
    test('هەموو دەقەکان وەرگێڕانی $name ـیان هەیە', () {
      final missing = keys.where((k) => !table.containsKey(k)).toList()..sort();
      expect(missing, isEmpty, reason: 'بێ وەرگێڕان (${missing.length}):\n${missing.take(30).join('\n')}');
    });

    test('$name: {0} {1} ... وەک دەقە کوردییەکەن', () {
      final ph = RegExp(r'\{\d+\}');
      List<String> p(String s) => ph.allMatches(s).map((m) => m[0]!).toList()..sort();
      final bad = [
        for (final e in table.entries)
          if (p(e.key).join() != p(e.value).join()) e.key,
      ];
      expect(bad, isEmpty);
    });
  }

  group('tr / trf', () {
    tearDown(() => AppLang.setCode('ku'));

    test('کوردی وەک خۆی دەمێنێت', () {
      expect(tr('پاشەکەوت'), 'پاشەکەوت');
      expect(AppLang.isRtl, isTrue);
    });

    test('ئینگلیزی و ئاراستەی چەپ-بۆ-ڕاست', () {
      AppLang.setCode('en');
      expect(tr('پاشەکەوت'), 'Save');
      expect(trf('نوێژی داهاتوو: {0}', ['Fajr']), 'Next prayer: Fajr');
      expect(AppLang.isRtl, isFalse);
    });

    test('عەرەبی', () {
      AppLang.setCode('ar');
      expect(tr('پاشەکەوت'), 'حفظ');
      expect(AppLang.isRtl, isTrue);
    });

    test('دەقی نەناسراو (ناوی شوێن لە داتابەیس) وەک خۆی دەمێنێت', () {
      AppLang.setCode('en');
      expect(tr('دوکانی ئەحمەد'), 'دوکانی ئەحمەد');
    });
  });
}
