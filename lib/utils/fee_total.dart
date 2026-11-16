/// سەرجەمی تێچووی مامەڵەیەک لە دێڕە نووسراوەکانەوە، بۆ نموونە:
/// «پشکنینی چاو: 15000» + «وەسڵی تەرای: 25000» → 40,000.
///
/// دێڕەکان دەقی ئازادن (ئەدمین دەینووسێت)، بۆیە لێرە ژمارەکە دەدۆزرێتەوە:
///  • ژمارەی کوردی/عەرەبی/فارسی (٠-٩) و جیاکەرەوەی هەزار (`,` `،` `.`) دەخوێنرێنەوە
///  • ئەگەر دێڕێک چەند ژمارەی تێدابێت، دوایینیان بڕەکەیە («... : 25000»)
///  • «٢٥ هەزار» ← ٢٥٠٠٠، «٢ ملیۆن» ← ٢٠٠٠٠٠٠
///  • دێڕی دۆلار ($) یان بێ ژمارە ناخرێتە سەرجەمەوە و لە `skipped` دەژمێردرێت
class FeeTotal {
  final int total;

  /// چەند دێڕ لە سەرجەمدا هەژمار کراون
  final int counted;

  /// چەند دێڕ نەهاتوونەتە ناو سەرجەم (بێ ژمارە یان دۆلار)
  final int skipped;

  const FeeTotal(this.total, this.counted, this.skipped);

  /// سەرجەم تەنها کاتێک سوودی هەیە کە لانی کەم دوو بڕ هەبن
  bool get isUseful => counted >= 2;

  static const Map<String, String> _digits = {
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  };

  static final RegExp _dollar =
      RegExp(r'\$|دۆلار|دولار|usd|dollar', caseSensitive: false);
  static final RegExp _token = RegExp(r'\d[\d,،٬.]*\d|\d');
  static final RegExp _dotThousands = RegExp(r'^\d{1,3}(\.\d{3})+$');
  static final RegExp _million = RegExp(r'ملیۆن|مليون|million', caseSensitive: false);
  static final RegExp _thousand = RegExp(r'هەزار|هزار|ألف|الف|thousand', caseSensitive: false);

  static String _latin(String s) {
    var t = s;
    _digits.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  /// بڕی یەک دێڕ، یان null ئەگەر نەدۆزرایەوە
  static int? amountOf(String line) {
    final s = _latin(line);
    final tokens = _token.allMatches(s).toList();
    if (tokens.isEmpty) return null;
    var raw = tokens.last.group(0)!.replaceAll(RegExp(r'[,،٬]'), '');
    double value;
    if (raw.contains('.')) {
      value = _dotThousands.hasMatch(raw)
          ? double.parse(raw.replaceAll('.', ''))
          : (double.tryParse(raw) ?? 0);
    } else {
      value = double.tryParse(raw) ?? 0;
    }
    if (value < 1000) {
      if (_million.hasMatch(s)) {
        value *= 1000000;
      } else if (_thousand.hasMatch(s)) {
        value *= 1000;
      }
    }
    return value.round();
  }

  static FeeTotal of(Iterable<String> fees) {
    var total = 0, counted = 0, skipped = 0;
    for (final f in fees) {
      if (f.trim().isEmpty) continue;
      if (_dollar.hasMatch(f)) {
        skipped++;
        continue;
      }
      final v = amountOf(f);
      if (v == null || v <= 0) {
        skipped++;
        continue;
      }
      total += v;
      counted++;
    }
    return FeeTotal(total, counted, skipped);
  }

  /// «60,000» — بە جیاکەرەوەی هەزار؛ `kurdishDigits` بۆ ٠-٩
  static String format(int n, {bool kurdishDigits = false}) {
    final s = n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        );
    if (!kurdishDigits) return s;
    const ku = '٠١٢٣٤٥٦٧٨٩';
    return s.replaceAllMapped(RegExp(r'\d'), (m) => ku[int.parse(m[0]!)]);
  }

  /// ئایا دێڕەکان ژمارەی کوردی/عەرەبی بەکارهێناوە؟ (بۆ ڕێکخستنی شێوەی سەرجەمەکە)
  static bool usesEasternDigits(Iterable<String> fees) =>
      fees.any((f) => RegExp('[٠-٩۰-۹]').hasMatch(f));
}
