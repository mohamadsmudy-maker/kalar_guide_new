// lib/services/price_save_result.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/tr.dart';

/// ئەنجامی پاشەکەوتکردنی نرخ (دراو یان سوتەمەنی)
enum PriceSaveResult {
  ok,
  notLoggedIn,
  forbidden,
  notFound,
  invalid,

  /// پەیوەندی یان هەڵەیەکی تر
  failed;

  bool get isOk => this == ok;

  static PriceSaveResult fromServer(Object? status) => switch ('$status') {
        'ok' => ok,
        'not_logged_in' => notLoggedIn,
        'forbidden' => forbidden,
        'not_found' => notFound,
        'invalid' => invalid,
        _ => failed,
      };

  /// پەیامی کوردی (لە شوێنی پیشاندان tr() دەکرێت)
  String get message => switch (this) {
        ok => tr('نرخەکە پاشەکەوت کرا'),
        notLoggedIn => tr('چوونەژوورەوەکەت بەسەرچووە، تکایە دووبارە بچۆ ژوورەوە'),
        forbidden => tr('ڕێگەت پێنەدراوە نرخی ئەم شوێنە بگۆڕیت'),
        notFound => tr('ئەم شوێنە نەدۆزرایەوە'),
        invalid => tr('تکایە نرخێکی دروست بنووسە'),
        failed => tr('پاشەکەوتکردن سەرکەوتوو نەبوو، دووبارە هەوڵ بدەرەوە'),
      };
}

/// true ئەگەر فەنکشنەکە لە Supabase نەبێت (مایگرەیشن هێشتا جێبەجێ نەکراوە)
bool isMissingRpc(Object e) =>
    e is PostgrestException &&
    (e.code == 'PGRST202' ||
        e.code == '42883' ||
        e.message.contains('Could not find the function'));

/// RLS بە بێدەنگی هیچ ڕیزێک نوێ ناکاتەوە — ئەمە بۆ ناسینەوەی ئەوەیە
bool isPermissionError(Object e) =>
    e is PostgrestException &&
    (e.code == '42501' || e.message.contains('row-level security'));

/// «١٥٧٬٠٠٠» / «157,000» / « 1500 » → ژمارە ؛ نادروست → null
double? parsePrice(String raw) {
  const ku = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in raw.trim().split('')) {
    final i = ku.indexOf(ch);
    final j = fa.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else if (ch == '٫') {
      b.write('.');
    } else if (ch != ',' && ch != '٬' && ch != ' ') {
      b.write(ch);
    }
  }
  return double.tryParse(b.toString());
}
