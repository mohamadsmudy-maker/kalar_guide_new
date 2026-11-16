/// ژمارەی شوێنەکان بەپێی بەش، بۆ فلتەری لیستی شوێنەکانی ئەدمین.
class StoreCategoryCounts {
  StoreCategoryCounts._();

  /// بەهای فلتەر بۆ ئەو شوێنانەی بەشیان نییە
  static const String none = '\u0000none';

  static String _clean(dynamic v) => (v ?? '').toString().trim();

  /// بەشی شوێنێک؛ ئەگەر بەتاڵ بوو [none]
  static String categoryOf(Map<String, dynamic> store, {String field = 'category'}) {
    final c = _clean(store[field]);
    return c.isEmpty ? none : c;
  }

  /// `(بەش، ژمارە)` — زۆرترین لە پێشەوە، پاشان بە ئەلفوبێ؛ «بێ بەش» هەمیشە لە کۆتایی
  static List<MapEntry<String, int>> count(
    Iterable<Map<String, dynamic>> stores, {
    String field = 'category',
  }) {
    final map = <String, int>{};
    for (final s in stores) {
      final c = categoryOf(s, field: field);
      map[c] = (map[c] ?? 0) + 1;
    }
    final list = map.entries.toList()
      ..sort((a, b) {
        if (a.key == none) return 1;
        if (b.key == none) return -1;
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return list;
  }

  /// ئایا شوێنەکە لەگەڵ بەش و ژێربەشی هەڵبژێردراو دەگونجێت؟ (`null` = هەموو)
  static bool matches(
    Map<String, dynamic> store, {
    String? category,
    String? subCategory,
  }) {
    if (category != null && categoryOf(store) != category) return false;
    if (subCategory != null &&
        categoryOf(store, field: 'sub_category') != subCategory) {
      return false;
    }
    return true;
  }
}
