// lib/l10n/tr.dart
//
// 🌍 وەرگێڕانی هەموو دەقەکانی ئەپ
//
// کوردی زمانی سەرەکییە: دەقی کوردی خۆی کلیلەکەیە، بۆیە کۆدەکە
// خوێندنەوەی ئاسانە:  Text(tr('پاشەکەوت'))
// دەقی گۆڕاو:          trf('{0} خولەک ماوە', [minutes])
//
// وەرگێڕانەکان لە lib/l10n/strings/ دان. ئەگەر وەرگێڕانێک نەبوو،
// دەقە کوردییەکە پیشان دەدرێت (هەرگیز بەتاڵ نابێت).
// test/l10n/translations_test.dart پشکنین دەکات کە هەموو دەقەکان
// وەرگێڕدراون.
import 'package:flutter/widgets.dart';

import 'strings/strings_ar.dart';
import 'strings/strings_en.dart';

class AppLang {
  AppLang._();

  static String _code = 'ku';

  /// `ku`, `ar` یان `en`
  static String get code => _code;
  static bool get isKurdish => _code == 'ku';
  static bool get isRtl => _code != 'en';
  static TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;

  static const Map<String, Map<String, String>> tables = {
    'ar': stringsAr,
    'en': stringsEn,
  };

  /// وەرگێڕانی [text] بۆ [lang]؛ سەرەتا ڕێک، پاشان بە شێوەی ئاسایی‌کراو
  /// (بۆ دەقی داتابەیس کە «ي/ك»ی عەرەبی، بۆشایی زیادە یان ZWNJ ی تێدایە).
  static String? lookup(String lang, String text) {
    final table = tables[lang];
    if (table == null) return null;
    final exact = table[text] ?? table[text.trim()];
    if (exact != null) return exact;
    final index = _normalized[lang] ??= {
      for (final e in table.entries) normalizeKey(e.key): e.value,
    };
    return index[normalizeKey(text)];
  }

  static final Map<String, Map<String, String>> _normalized = {};

  static final RegExp _spaces = RegExp(r'\s+');

  /// «بارەگا  حزبيیەکان‌ » → «بارەگا حزبییەکان»
  static String normalizeKey(String s) => s
      .replaceAll('\u200c', '')
      .replaceAll('\u0640', '')
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ة', 'ە')
      .replaceAll(_spaces, ' ')
      .trim();

  /// SettingsProvider بانگی دەکات. true = زمان گۆڕا.
  static bool setCode(String code) {
    final c = (code == 'ar' || code == 'en') ? code : 'ku';
    if (c == _code) return false;
    _code = c;
    return true;
  }

  /// هەموو ویجێتەکان دووبارە دروست دەکاتەوە بێ ئەوەی state بفەوتێت
  /// (بۆ ئەوەی شاشە کراوەکانیش یەکسەر زمانەکەیان بگۆڕێت).
  static void rebuildAll() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}

/// وەرگێڕانی دەقێکی کوردی بۆ زمانی ئێستا.
String tr(String ku) {
  if (AppLang._code == 'ku') return ku;
  return AppLang.lookup(AppLang._code, ku) ?? ku;
}

/// وەرگێڕانی دەقێک کە بەشی گۆڕاوی هەیە: `{0}`, `{1}` ...
String trf(String template, List<Object?> args) {
  var s = tr(template);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
