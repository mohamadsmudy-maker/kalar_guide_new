import '../../l10n/tr.dart';

/// جۆری ئەنجامی گەڕان
enum SearchKind {
  section,
  place,
  department,
  transaction,
  neighborhood,
  emergency,
  event,
  news,
}

/// یەک شتی گەڕاو (شوێن، گەڕەک، مامەڵە، ...)
class SearchItem {
  final SearchKind kind;
  final String title;
  final String subtitle;

  /// دەقی زیادە بۆ دۆزینەوە (بەش، ناونیشان، ناوی تر) — پیشان نادرێت
  final String keywords;

  /// داتای خاو بۆ کردنەوەی شاشەی وردەکاری
  final Object? data;

  SearchItem({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.keywords = '',
    this.data,
  })  : _title = GlobalSearch.normalize(title),
        _all = GlobalSearch.normalize('$title $subtitle $keywords');

  final String _title;
  final String _all;
}

/// بزوێنەری گەڕان — بێ تۆڕ، بۆیە تێست دەکرێت
class GlobalSearch {
  GlobalSearch._();

  static final RegExp _marks = RegExp('[ً-ٰٟ]');
  static const Map<String, String> _digits = {
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  };

  /// یەکسانکردنی نووسین: ي/ی، ك/ک، ه/ە، ژمارەی کوردی، پیتی گەورە/بچووک
  static String normalize(String s) {
    var t = AppLang.normalizeKey(s)
        .toLowerCase()
        .replaceAll(_marks, '')
        .replaceAll('ە', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و');
    _digits.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  /// نمرەی گونجان؛ 0 = ناگونجێت. هەموو وشەکانی گەڕان دەبێت تێدا بن.
  static int score(SearchItem item, String query) {
    final q = normalize(query);
    if (q.isEmpty) return 0;
    final words = q.split(' ').where((w) => w.isNotEmpty).toList();
    if (!words.every(item._all.contains)) return 0;

    final t = item._title;
    if (t == q) return 100;
    if (t.startsWith(q)) return 80;
    if (t.split(' ').any((w) => w.startsWith(words.first))) return 60;
    if (t.contains(q)) return 50;
    if (words.every(t.contains)) return 40;
    return 20; // تەنها لە وەسف/بەش/ناونیشاندا
  }

  /// ئەنجامەکان بە ڕیزی گونجان، پاشان ناو
  static List<SearchItem> search(
    Iterable<SearchItem> items,
    String query, {
    SearchKind? only,
  }) {
    final scored = <(int, SearchItem)>[];
    for (final it in items) {
      if (only != null && it.kind != only) continue;
      final s = score(it, query);
      if (s > 0) scored.add((s, it));
    }
    scored.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.title.compareTo(b.$2.title);
    });
    return [for (final e in scored) e.$2];
  }

  /// ژمارەی ئەنجام بەپێی جۆر (بۆ چیپەکان)
  static Map<SearchKind, int> counts(Iterable<SearchItem> results) {
    final m = <SearchKind, int>{};
    for (final r in results) {
      m[r.kind] = (m[r.kind] ?? 0) + 1;
    }
    return m;
  }
}
